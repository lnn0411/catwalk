"""Core Monte Carlo economy simulator."""

from __future__ import annotations

import copy
import csv
import json
import math
import os
import random
import statistics

from sim.profiles import PROFILES, get_rancher_priority_cats
from sim.systems.steps import calc_energy


def _project_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))


def load_params(path: str | None = None) -> dict:
    with open(path or os.path.join(_project_root(), "config", "params.json"), "r", encoding="utf-8") as fh:
        return json.load(fh)


def _percentile(values: list, percentile: int) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return float(ordered[0])
    rank = (len(ordered) - 1) * (percentile / 100.0)
    lower = int(math.floor(rank))
    upper = int(math.ceil(rank))
    if lower == upper:
        return float(ordered[lower])
    weight = rank - lower
    return float(ordered[lower] * (1.0 - weight) + ordered[upper] * weight)


class SimState:
    """Mutable state for one simulator run."""

    def __init__(self, params: dict):
        self.params = params
        self.gold = 0
        self.diamonds = 0
        self.love_petals = 0
        self.spring_petals = 0
        self.energy_pool = 0
        self.board_tickets = 0
        self.cats = []
        self.hatching_slots = []
        self.workshop_slots = []
        self.current_day = 0
        self.new_player_days_remaining = int(params["steps"]["new_player_protection_days"])
        self.daily_flow = {}
        self.total_steps = 0
        self.total_hatches = 0
        self.total_adoptions = 0
        self.total_overflow_cutoff = 0
        self.total_ad_energy = 0
        self.total_step_energy = 0
        self.total_tickets_earned = 0
        self.total_tickets_spent = 0
        self.total_b6_gold = 0
        # M4 alignment: board wins accumulate for level tiers + win milestones
        self.board_total_wins = 0
        self.board_milestones_claimed = set()
        # B6 alignment: decor kept while under cap; only overflow converts to gold
        self.board_decor_counts = {}
        self.first_expansion_day = None
        self.legendary_pity_triggers = 0
        self.dead_items = 0
        self.orange_max_level_day = None
        self.pokedex = set()
        self.first_exploration_done = False
        self._adoptions_this_week = 0
        # P1/A4 落地口径: 花瓣周限 500 对全部送养生效, 超限转保底金币
        self.adoption_petals_this_week = 0
        # 孵化稀有度保底: 连续 miss 计数(与客户端 HatchEngine 同构)
        self.hatch_epic_miss = 0
        self.hatch_leg_miss = 0
        self.total_legendaries = 0
        # 品种解锁: 累计孵化计数 + 5 次未出保底(与客户端 BreedUnlockEngine 同构)
        self.breed_hatch_counts = {}
        self.breed_pity = {}
        # P1/A13: 第一次孵化(=客户端第二颗蛋)发生日
        self.first_hatch_day = None
        # C1 工坊步数礼盒模型 (P1 sim 先行口径)
        self.workshop_counter = 0
        self.workshop_unopened = 0
        self.owned_accessories = set()
        self.workshop_epic_miss = 0
        self.workshop_leg_miss = 0
        # N12 羁绊点 (满级携带经验 1000:1)
        self.bond_points = 0
        self.bond_gained_today = 0
        # R1-3: achievements are granted once, on the day the milestone is reached
        self.claimed_achievements = set()
        # R1-4: capacity is gated by real gold payment, not pokedex size
        self.expansion_tier_unlocked = 0  # 0=24, 1=28, 2=32, 3=36
        self.gold_spent_on_capacity = 0
        self.first_gold_expansion_day = None
        self._init_slots()
        self._add_cat(
            params["hatching"]["first_cat_breed"],
            "common",
            is_active=True,
            level=1,
            xp=0,
            affection=0,
        )

    def _init_slots(self) -> None:
        for index in range(int(self.params["hatching"]["slots"])):
            self.hatching_slots.append({"index": index, "unlocked": index == 0, "progress": 0, "egg": None})
        # C1: 工坊改独立步数计数器, 不再有能量槽位

    def _add_cat(
        self,
        breed: str,
        rarity: str,
        is_active: bool = False,
        level: int = 1,
        xp: int = 0,
        affection: int = 0,
    ) -> dict:
        cat = {
            "breed": breed,
            "rarity": rarity,
            "level": int(level),
            "xp": int(xp),
            "affection": int(affection),
            "is_active": bool(is_active),
            "is_exploring": False,
        }
        self.cats.append(cat)
        self.pokedex.add((breed, rarity))
        self._unlock_slots_and_capacity()
        return cat

    @property
    def inventory_capacity(self) -> int:
        # R1-4: capacity is a function of tiers actually paid for, not pokedex size.
        caps = [24, 28, 32, 36]
        return caps[min(self.expansion_tier_unlocked, 3)]

    def _unlock_slots_and_capacity(self) -> None:
        total = len(self.cats) + self.total_adoptions
        for slot in self.hatching_slots:
            index = slot["index"]
            if index == 1 and total >= 1:
                slot["unlocked"] = True
            elif index == 2 and total >= 3:
                slot["unlocked"] = True
            elif index == 3 and total >= 10:
                slot["unlocked"] = True
        # R1-4: expand capacity only when the pokedex gate AND the gold cost are met.
        # Tiers must be unlocked in order; deduct gold and record the real payment day.
        tiers = self.params["cat_inventory"]["expansion_tiers"]
        for i, tier in enumerate(tiers):
            if i < self.expansion_tier_unlocked:
                continue  # already unlocked
            if i != self.expansion_tier_unlocked:
                break  # only the next tier in sequence is eligible
            if len(self.pokedex) >= int(tier["unlock_at_pokedex"]) and self.gold >= int(tier["cost_gold"]):
                self.gold -= int(tier["cost_gold"])
                self.gold_spent_on_capacity += int(tier["cost_gold"])
                self.flow("gold_out_capacity_expansion", int(tier["cost_gold"]))
                self.expansion_tier_unlocked = i + 1
                if self.first_gold_expansion_day is None and self.current_day:
                    self.first_gold_expansion_day = self.current_day
            else:
                break  # next tier not yet affordable/unlocked

    def flow(self, name: str, amount: int | float) -> None:
        self.daily_flow.setdefault(self.current_day, {})
        self.daily_flow[self.current_day][name] = self.daily_flow[self.current_day].get(name, 0) + amount


class SimEngine:
    """Monte Carlo simulator front-end."""

    def __init__(self, profile_name: str, params: dict | None = None, iterations: int | None = None, days: int = 30):
        if profile_name not in PROFILES:
            raise ValueError("unknown profile: %s" % profile_name)
        self.profile_name = profile_name
        self.profile = copy.deepcopy(PROFILES[profile_name])
        self.params = copy.deepcopy(params) if params is not None else load_params()
        self.iterations = int(iterations or self.params["simulation"]["iterations_per_profile"])
        self.days = int(days)
        self.seed = int(self.params["simulation"]["random_seed"])
        self.states = []
        self.summary = {}

    @staticmethod
    def load_params(path: str | None = None) -> dict:
        return load_params(path)

    def run_single(self, seed: int | None = None) -> SimState:
        rng = random.Random(self.seed if seed is None else seed)
        state = SimState(self.params)
        for day in range(1, self.days + 1):
            step_count = int(self.profile["daily_steps"])
            self.tick(state, day, step_count, rng)
        return state

    def run(self) -> dict:
        self.states = []
        for index in range(self.iterations):
            self.states.append(self.run_single(self.seed + index))
        self.summary = self._aggregate(self.states)
        return self.summary

    def _aggregate(self, states: list[SimState]) -> dict:
        fields = [
            "gold",
            "diamonds",
            "love_petals",
            "spring_petals",
            "energy_pool",
            "board_tickets",
            "total_hatches",
            "total_adoptions",
            "total_overflow_cutoff",
            "total_ad_energy",
            "total_step_energy",
            "total_tickets_earned",
            "total_tickets_spent",
            "total_b6_gold",
            "legendary_pity_triggers",
            "dead_items",
        ]
        result = {"profile": self.profile_name, "days": self.days, "iterations": self.iterations}
        for field in fields:
            values = [getattr(state, field) for state in states]
            result[field] = {
                "p50": _percentile(values, 50),
                "p95": _percentile(values, 95),
                "mean": statistics.mean(values) if values else 0,
            }
        return result

    def save_csv(self, path: str) -> None:
        if not self.states:
            self.run()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        rows_by_day = []
        for day in range(1, self.days + 1):
            day_rows = [state.daily_flow.get(day, {}) for state in self.states]
            keys = sorted({key for row in day_rows for key in row})
            row = {"day": day}
            for key in keys:
                values = [daily.get(key, 0) for daily in day_rows]
                row[key + "_p50"] = _percentile(values, 50)
                row[key + "_p95"] = _percentile(values, 95)
                row[key + "_mean"] = statistics.mean(values) if values else 0
            rows_by_day.append(row)

        headers = ["day"]
        for row in rows_by_day:
            for key in row:
                if key not in headers:
                    headers.append(key)

        with open(path, "w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=headers)
            writer.writeheader()
            for row in rows_by_day:
                writer.writerow(row)

    def tick(self, state: SimState, day: int, step_count: int, rng: random.Random) -> None:
        state.current_day = day
        state.daily_flow[day] = {}
        state.bond_gained_today = 0
        if day % int(self.params["cat_inventory"]["adoption_reset_day"] or 7) == 1:
            state._adoptions_this_week = 0
            state.adoption_petals_this_week = 0

        step_energy = calc_energy(
            step_count,
            state.new_player_days_remaining > 0,
            self.params,
        )
        state.total_steps += step_count
        state.total_step_energy += step_energy
        state.flow("steps_raw", step_count)
        state.flow("energy_from_steps", step_energy)

        self._checkin(state, rng)
        self._monthly_card(state)
        self._daily_newbie_goals(state)
        self._step_chests(state, step_count)
        self._board_ticket_grants(state, step_count)
        self._interaction_grants(state)
        self._ads(state, step_energy)
        self._energy_routing(state, step_energy)
        self._hatching(state, rng)
        self._apply_pool_cap(state)
        self._adoption(state)
        self._workshop(state, rng, step_count)
        self._gold_ticket_purchase(state)
        self._board_game(state, rng)
        self._shop(state)
        # P1-2: re-run capacity/slot unlock after all gold income is settled, so a
        # full bag (which skips hatching → _add_cat) can't deadlock expansion.
        state._unlock_slots_and_capacity()
        self._exploration(state, rng)
        self._carry_cat_xp(state)
        self._achievement_grant(state)
        self._events(state, step_count)
        self._record_daily_stats(state)

        if state.new_player_days_remaining > 0:
            state.new_player_days_remaining -= 1

    def _checkin(self, state: SimState, rng: random.Random) -> None:
        if rng.random() > float(self.profile["checkin_attendance_rate"]):
            state.flow("checkin_missed", 1)
            return
        rewards = self.params["checkin"]["daily_rewards"]
        reward = rewards[(state.current_day - 1) % int(self.params["checkin"]["cycle_length"])]
        gold = int(reward.get("gold", 0))
        diamonds = int(reward.get("diamond", 0))
        state.gold += gold
        state.diamonds += diamonds
        state.flow("gold_in_checkin", gold)
        state.flow("diamonds_in_checkin", diamonds)
        if reward.get("chest"):
            state.love_petals += int(self.params["ads"]["slot_3"]["reward_amount"])
            state.flow("love_petals_in_checkin_chest", int(self.params["ads"]["slot_3"]["reward_amount"]))

    def _monthly_card(self, state: SimState) -> None:
        if not self.profile["has_monthly_card"]:
            return
        card = self.params["economy"]["monthly_card"]
        state.gold += int(card["daily_gold"])
        state.diamonds += int(card["daily_diamond"])
        state.love_petals += int(card["daily_love_petals"])
        state.flow("gold_in_monthly_card", int(card["daily_gold"]))
        state.flow("diamonds_in_monthly_card", int(card["daily_diamond"]))
        state.flow("love_petals_in_monthly_card", int(card["daily_love_petals"]))

    def _board_ticket_grants(self, state: SimState, step_count: int) -> None:
        board = self.params["board_game"]
        step_tickets = min(
            int(board["ticket_daily_limit_by_steps"]),
            int(step_count // int(board["ticket_per_steps_raw"])),
        )
        login_tickets = int(board["ticket_login_new_player"] if state.new_player_days_remaining > 0 else board["ticket_login_daily"])
        earned = step_tickets + login_tickets
        state.board_tickets += earned
        state.total_tickets_earned += earned
        state.flow("tickets_in_steps", step_tickets)
        state.flow("tickets_in_login", login_tickets)

    def _interaction_grants(self, state: SimState) -> None:
        """R1-2: interaction pathway — every N interactions grants a board ticket."""
        board = self.params["board_game"]
        interactions = int(self.profile["default_behavior"]["daily_interactions"])
        per = int(board["ticket_per_interactions"])
        limit = int(board["ticket_daily_limit_by_interaction"])
        earned = min(limit, interactions // per) if per > 0 else 0
        state.board_tickets += earned
        state.total_tickets_earned += earned
        state.flow("tickets_in_interaction", earned)

    def _gold_ticket_purchase(self, state: SimState) -> None:
        """R1-2: gold pathway — auto-buy board tickets with spare gold, daily-capped."""
        board = self.params["board_game"]
        cost = int(board["ticket_gold_cost"])
        limit = int(board["ticket_gold_daily_limit"])
        bought = 0
        while bought < limit and cost > 0 and state.gold >= cost:
            state.gold -= cost
            state.board_tickets += 1
            state.total_tickets_earned += 1
            bought += 1
            state.flow("gold_out_ticket_purchase", cost)
            state.flow("tickets_in_gold", 1)

    def _step_chests(self, state: SimState, step_count: int) -> None:
        """P1 今日步数宝箱: 3000/6000/10000 各一箱, 内容暂为小额金币 [待sim校准]."""
        chests = self.params["steps"].get("step_chests", {})
        thresholds = list(chests.get("thresholds", []))
        gold_values = list(chests.get("gold", []))
        for i, threshold in enumerate(thresholds):
            if step_count >= int(threshold):
                gold = int(gold_values[i]) if i < len(gold_values) else 0
                state.gold += gold
                state.flow("gold_in_step_chest", gold)
                state.flow("step_chests_opened", 1)

    def _ads(self, state: SimState, step_energy: int) -> None:
        if not self.profile["ads_enabled"]:
            state.flow("ad_views", 0)
            return
        # P1 广告步行放大器: 单次 = min(cap, coefficient × 当日步数能量)
        slot_1 = self.params["ads"]["slot_1"]
        per_view = min(
            int(slot_1["cap_per_view"]),
            int(float(slot_1["coefficient"]) * step_energy),
        )
        ad_energy = per_view * int(slot_1["daily_limit"])
        state.energy_pool += ad_energy
        state.total_ad_energy += ad_energy
        state.flow("energy_in_ads", ad_energy)
        state.flow("ad_views", int(slot_1["daily_limit"]))

        slot_3 = self.params["ads"]["slot_3"]
        if state.current_day <= int(slot_3["limit_per_event_period"]):
            petals = int(slot_3["reward_amount"])
            state.love_petals += petals
            state.flow("love_petals_in_ads", petals)

        board = self.params["board_game"]
        tickets = min(int(board["ticket_ad_daily_limit"]), int(board["ticket_ad_daily_limit"]))
        state.board_tickets += tickets
        state.total_tickets_earned += tickets
        state.flow("tickets_in_ads", tickets)

    def _energy_routing(self, state: SimState, step_energy: int) -> None:
        # P1 保真修正: 客户端能量是边产边灌蛋的连续流, 日粒度下若「先封顶后孵化」
        # 会制造真实中不存在的截断假象. 封顶移至孵化消耗之后(_apply_pool_cap).
        state.energy_pool += step_energy

    def _apply_pool_cap(self, state: SimState) -> None:
        cap = int(self.params["steps"]["max_energy_pool"])
        if state.energy_pool > cap:
            overflow = state.energy_pool - cap
            state.energy_pool = cap
            state.total_overflow_cutoff += overflow
            state.flow("energy_overflow_cutoff", overflow)

    def _egg_cost(self, state: SimState) -> int:
        """P1 孵化成本成长曲线. sim 第 k 次孵化 = 客户端第 k+1 颗蛋(#1 为教学蛋)."""
        curve = self.params["hatching"].get("egg_cost_curve")
        if not curve:
            return int(self.params["hatching"]["energy_per_egg"])
        egg_number = state.total_hatches + 2
        early = curve.get("early", {})
        if str(egg_number) in early:
            return int(early[str(egg_number)])
        base = int(curve.get("base", 4250))
        late_from = int(curve.get("late_from_egg", 20))
        if egg_number < late_from:
            return base
        step_every = int(curve.get("late_step_every", 10))
        step_amount = int(curve.get("late_step_amount", 250))
        cost = base + step_amount * (1 + (egg_number - late_from) // step_every)
        return min(cost, int(curve.get("late_cap", 6000)))

    def _hatching(self, state: SimState, rng: random.Random) -> None:
        for slot in state.hatching_slots:
            if not slot["unlocked"]:
                continue
            cost = self._egg_cost(state)
            if state.energy_pool < cost:
                continue
            if len(state.cats) >= state.inventory_capacity:
                # B3 包满引导弹窗行为模型: 玩家送养一只以继续孵化.
                # A4 落地口径(实测修正裁决): 不再单设次数兜底 — 周限内正常发花瓣、
                # 超限/未养成转保底金币 50, 数学上无套利(养成成本>50金), 消耗端不掐死.
                if not (
                    self.profile.get("adoption_enabled", True)
                    and self._guided_adopt_one(state)
                ):
                    break
            state.energy_pool -= cost
            state.flow("energy_out_hatching", cost)
            state.total_hatches += 1
            if state.first_hatch_day is None:
                state.first_hatch_day = state.current_day
            rarity = self._roll_rarity(state, rng)
            breed = self._roll_breed(state, rng)
            state._add_cat(breed, rarity)

    def _roll_rarity(self, state: SimState, rng: random.Random) -> str:
        """P1 sim 保真修正: 保底从「逢 N 必出」改为客户端同构的「连续 miss 计数」
        (HatchEngine.EPIC_PITY/LEGENDARY_PITY 语义). 旧模型使 A5b 恒为 1.0."""
        pity = self.params["hatching"]["pity"]
        forced = None
        if state.hatch_leg_miss >= int(pity["legendary_every_n"]):
            forced = "legendary"
            state.legendary_pity_triggers += 1
        elif state.hatch_epic_miss >= int(pity["epic_every_n"]):
            forced = "epic"
        if forced is None:
            weights = self.params["hatching"]["rarity_weights"]
            draw = rng.random()
            total = 0.0
            forced = list(weights.keys())[-1]
            for rarity, weight in weights.items():
                total += float(weight)
                if draw <= total:
                    forced = rarity
                    break
        if forced == "legendary":
            state.total_legendaries += 1
            state.hatch_leg_miss = 0
            state.hatch_epic_miss = 0
        elif forced == "epic":
            state.hatch_epic_miss = 0
            state.hatch_leg_miss += 1
        else:
            state.hatch_epic_miss += 1
            state.hatch_leg_miss += 1
        return forced

    def _roll_breed(self, state: SimState, rng: random.Random) -> str:
        """P5 漂移对齐(以客户端 BreedUnlockEngine 为权威):
        解锁计数用累计孵化数(送养不减); 抽取为已解锁品种均匀随机 +
        连续 5 次未出的品种保底排除. 旧 breed_pool_weights 加权表废弃."""
        chain = self.params["hatching"]["breed_unlock_chain"]
        counts = state.breed_hatch_counts
        unlocked = ["orange"]
        if counts.get("orange", 0) >= int(chain["orange_required_for_british"]):
            unlocked.append("british")
        if counts.get("british", 0) >= int(chain["british_required_for_siamese"]):
            unlocked.append("siamese")
        choices = list(unlocked)
        pity_breed = next((b for b in choices if state.breed_pity.get(b, 0) >= 5), "")
        if pity_breed and len(choices) > 1:
            choices.remove(pity_breed)
        breed = choices[rng.randrange(len(choices))]
        counts[breed] = counts.get(breed, 0) + 1
        for known in unlocked:
            if pity_breed and known == pity_breed:
                state.breed_pity[known] = 0
            elif known == breed and pity_breed != breed:
                state.breed_pity[known] = state.breed_pity.get(known, 0) + 1
        return breed

    def _guided_adopt_one(self, state: SimState) -> bool:
        """包满弹窗引导的单只送养(携带猫豁免). 返回是否送出."""
        priority = [c for c in get_rancher_priority_cats(state) if not c.get("is_active")]
        if not priority:
            return False
        self._settle_adoption(state, priority[0])
        return True

    def _settle_adoption(self, state: SimState, cat: dict) -> None:
        state.cats.remove(cat)
        state.total_adoptions += 1
        state._adoptions_this_week += 1
        state.flow("cats_out_adoption", 1)
        # P4 对齐客户端权威(RelinquishSystem): 每次送养固定 +50 金(GOLD_REWARD),
        # A4 的"零回报"由此消除; 花瓣按公式发放、周限 500 截断(超限部分不发).
        base_gold = int(self.params["cat_inventory"]["adoption_lv1_fallback_gold"])
        state.gold += base_gold
        state.flow("gold_in_adoption", base_gold)
        if int(cat["level"]) <= 1:
            return
        revenue = self._adoption_revenue_petals(cat)
        weekly_cap = int(self.params["cat_inventory"]["adoption_weekly_limit"])
        room = max(0, weekly_cap - state.adoption_petals_this_week)
        granted = min(revenue, room)
        state.adoption_petals_this_week += granted
        if granted > 0:
            state.love_petals += granted
            state.flow("love_petals_in_adoption", granted)

    def _adoption_revenue_petals(self, cat: dict) -> int:
        """花瓣公式(好感<100 时 affection_factor=0 → 自然为 0, 与客户端一致)."""
        if int(cat["affection"]) < 100:
            return 0
        return self._adoption_revenue(cat)

    def _adoption(self, state: SimState) -> None:
        # R2: adopt when the bag is full OR a nurtured cat has reached the gate.
        if not self.profile.get("adoption_enabled", True):
            return
        guard = 0
        while len(state.cats) > state.inventory_capacity or self._nurtured_cats_ready(state):
            guard += 1
            if guard > 1000:  # safety valve against an unexpected non-terminating loop
                break
            ready = self._nurtured_cats_ready(state)
            if ready:
                candidate = ready[0]  # groomed cats first
            else:
                priority = [c for c in get_rancher_priority_cats(state) if not c.get("is_active")]
                if not priority:
                    break
                candidate = priority[0]  # fallback: over-capacity trim
            if candidate not in state.cats:
                break
            self._settle_adoption(state, candidate)

    def _adoption_revenue(self, cat: dict) -> int:
        formula = self.params["cat_inventory"]["adoption_revenue_formula"]
        if int(cat["level"]) <= 1:
            return int(self.params["cat_inventory"]["adoption_lv1_fallback_gold"])
        base = float(formula["base_by_breed"].get(cat["breed"], 0))
        rarity = float(formula["rarity_factor"].get(cat["rarity"], 1))
        level_factor = 0.0
        for tier in formula["level_factor_tiers"]:
            if int(tier["min_lv"]) <= int(cat["level"]) <= int(tier["max_lv"]):
                level_factor = float(tier["factor"])
                break
        affection_factor = 0.0
        for tier in formula["affection_factor_tiers"]:
            if int(tier["min_affection"]) <= int(cat["affection"]) <= int(tier["max_affection"]):
                affection_factor = float(tier["factor"])
                break
        revenue = int(base * rarity * level_factor * affection_factor)
        if revenue <= 0:
            return int(self.params["cat_inventory"]["adoption_under_threshold_fallback_gold"])
        return revenue

    def _workshop_roll_rarity(self, state: SimState, rng: random.Random) -> str:
        """礼盒稀有度: 权重 roll + miss 连续计数双保底(与客户端 C1 规格同构)."""
        pity = self.params["workshop"]["pity"]
        if state.workshop_leg_miss >= int(pity["legendary_miss_max"]):
            rarity = "legendary"
        elif state.workshop_epic_miss >= int(pity["epic_miss_max"]):
            rarity = "epic"
        else:
            weights = self.params["workshop"]["rarity_weights"]
            draw = rng.random()
            total = 0.0
            rarity = list(weights.keys())[-1]
            for name, weight in weights.items():
                total += float(weight)
                if draw <= total:
                    rarity = name
                    break
        if rarity == "legendary":
            state.workshop_leg_miss = 0
            state.workshop_epic_miss = 0
        elif rarity == "epic":
            state.workshop_epic_miss = 0
            state.workshop_leg_miss += 1
        else:
            state.workshop_epic_miss += 1
            state.workshop_leg_miss += 1
        return rarity

    def _workshop(self, state: SimState, rng: random.Random, step_count: int) -> None:
        """C1 独立步数礼盒模型(P1 sim 先行口径, 客户端 P2 实装).

        原始步数计数器 → 每 box_steps 一盒, 日上限/未开上限; 当日全部拆开.
        配饰重复折爱心花瓣(A14 零送养画像的花瓣来源之一); 花卉可重复持有.
        不再消耗能量池 — A6 回归即验证水槽移除后的截断水位.
        """
        cfg = self.params["workshop"]
        box_steps = int(cfg["box_steps"])
        state.workshop_counter += step_count
        boxes_today = 0
        while (
            state.workshop_counter >= box_steps
            and boxes_today < int(cfg["daily_box_cap"])
            and state.workshop_unopened < int(cfg["unopened_cap"])
        ):
            state.workshop_counter -= box_steps
            state.workshop_unopened += 1
            boxes_today += 1
        while state.workshop_unopened > 0:
            state.workshop_unopened -= 1
            state.flow("workshop_box_opened", 1)
            rarity = self._workshop_roll_rarity(state, rng)
            pool = cfg["gift_pool"]
            acc_count = int(pool["accessories"].get(rarity, 0))
            flower_count = int(pool["flowers"].get(rarity, 0))
            index = rng.randrange(acc_count + flower_count)
            if index < acc_count:
                item = "acc_%s_%d" % (rarity, index)
                if item in state.owned_accessories:
                    petals = int(cfg["dupe_accessory_petals"][rarity])
                    state.love_petals += petals
                    state.flow("love_petals_in_workshop_dupe", petals)
                else:
                    state.owned_accessories.add(item)
                    state.flow("workshop_gift_accessory", 1)
            else:
                state.flow("workshop_gift_flower", 1)

    def _board_game(self, state: SimState, rng: random.Random) -> None:
        board = self.params["board_game"]
        # M4 alignment: the shipped game (S14/TicketManager) charges 1 ticket per game,
        # not the 2 the old GDD assumed; configurable for future tuning.
        tickets_per_game = int(board.get("ticket_cost_per_game", 1))
        games = state.board_tickets // tickets_per_game
        state.board_tickets -= games * tickets_per_game
        state.total_tickets_spent += games * tickets_per_game
        state.flow("tickets_out_board", games * tickets_per_game)
        for _ in range(games):
            level = self._board_level(state)
            clear_rate = float(
                board.get("clear_rate_by_level", {}).get(str(level), board["clear_rate"])
            )
            if rng.random() <= clear_rate:
                state.board_total_wins += 1
                self._board_win_milestones(state)
                self._board_reward(state, rng, level)
            else:
                state.flow("board_consolation", 1)

    def _board_level(self, state: SimState) -> int:
        tiers = self.params["board_game"].get("level_up_wins", {"lv2": 5, "lv3": 15})
        if state.board_total_wins >= int(tiers["lv3"]):
            return 3
        if state.board_total_wins >= int(tiers["lv2"]):
            return 2
        return 1

    def _board_win_milestones(self, state: SimState) -> None:
        """M3-3.1 alignment: fixed milestones + 300/100-step diamond cycle."""
        board = self.params["board_game"]
        for milestone in board.get("win_milestones", []):
            wins = int(milestone["wins"])
            if state.board_total_wins >= wins and wins not in state.board_milestones_claimed:
                state.board_milestones_claimed.add(wins)
                diamonds = int(milestone.get("diamonds", 0))
                if diamonds > 0:
                    state.diamonds += diamonds
                    state.flow("diamonds_in_board_milestone", diamonds)
        cycle = board.get("win_milestone_cycle", {})
        if cycle:
            point = int(cycle["start"])
            while point <= state.board_total_wins:
                if point not in state.board_milestones_claimed:
                    state.board_milestones_claimed.add(point)
                    diamonds = int(cycle["diamonds"])
                    state.diamonds += diamonds
                    state.flow("diamonds_in_board_milestone", diamonds)
                point += int(cycle["step"])

    def _board_reward(self, state: SimState, rng: random.Random, level: int = 1) -> None:
        by_level = self.params["board_game"].get("reward_probabilities_by_level", {})
        rewards = by_level.get(str(level), self.params["board_game"]["reward_probabilities"])
        draw = rng.random()
        total = 0.0
        reward = None
        for name, weight in rewards.items():
            total += float(weight)
            if draw <= total:
                reward = name
                break
        reward = reward or list(rewards.keys())[-1]
        state.flow("board_reward_" + reward, 1)
        if reward in ("cat_tree_x1", "cherry_tree_x1"):
            # B6 alignment with client (LevelStateManager.process_board_decor):
            # decor is kept while under its cap; only overflow converts to gold.
            b6 = self.params["board_game"]["b6_conversion"]
            decor_key = "cat_tree" if reward == "cat_tree_x1" else "cherry_tree"
            cap = int(b6["%s_max" % decor_key])
            held = int(state.board_decor_counts.get(decor_key, 0))
            if held < cap:
                state.board_decor_counts[decor_key] = held + 1
                state.flow("board_decor_kept_" + decor_key, 1)
            else:
                gold = int(b6["convert_to_gold"])
                state.gold += gold
                state.total_b6_gold += gold
                state.flow("gold_in_b6_conversion", gold)
        elif reward == "cat_can_pack_x3":
            self._apply_affection(state, int(self.params["interaction"]["board_snack_can_affection"]) * 3)
        else:
            self._apply_affection(state, int(self.params["interaction"]["board_snack_affection"]))

    def _nurtured_cats_ready(self, state: SimState) -> list:
        """R2: common cats groomed to the adoption gate (Lv>=2 and affection>=100)."""
        return [
            cat
            for cat in state.cats
            if str(cat["rarity"]).lower() == "common"
            and int(cat["level"]) >= 2
            and int(cat["affection"]) >= 100
            and not cat.get("is_active")  # 携带猫不送养(状态矩阵 A3)
        ]

    def _nurture_pool(self, state: SimState) -> list:
        """R2: the 3-5 cats actively groomed — high level first, low affection first."""
        sorted_cats = sorted(state.cats, key=lambda c: (-int(c["level"]), int(c["affection"])))
        return sorted_cats[: min(5, len(sorted_cats))]

    def _apply_affection(self, state: SimState, amount: int) -> None:
        # R2: spread affection across the nurture pool instead of only cats[0].
        if not state.cats or amount <= 0:
            return
        pool = self._nurture_pool(state)
        per_cat = amount // len(pool)
        remainder = amount - per_cat * len(pool)
        for i, cat in enumerate(pool):
            bonus = 1 if i < remainder else 0  # distribute the remainder to the first few
            cat["affection"] += per_cat + bonus
        state.flow("cat_affection_gain", amount)

    def _shop(self, state: SimState) -> None:
        tiers = self.params["shop"]["love_petal_store"]["tiers"]
        for tier in reversed(tiers):
            price = int(tier["price_petals"])
            while state.love_petals >= price:
                state.love_petals -= price
                state.flow("love_petals_out_shop", price)
                self._apply_affection(state, int(self.params["interaction"]["feed_affection"]))
                break
        # R1-4: capacity expansion (gold-gated) is now handled centrally in
        # SimState._unlock_slots_and_capacity; the old shop-side charge is removed
        # to avoid double-charging the player.

    def _daily_newbie_goals(self, state: SimState) -> None:
        """R1-3: newbie goals grant flat daily gold for the first N days."""
        newbie = self.params.get("newbie_goals", {})
        duration = int(newbie.get("duration_days", 7))
        daily_gold = int(newbie.get("daily_gold", 50))
        if state.current_day <= duration:
            state.gold += daily_gold
            state.flow("gold_in_newbie_goal", daily_gold)

    def _achievement_grant(self, state: SimState) -> None:
        """R1-3: achievements pay out once, on the day the milestone is first met."""

        def claim(key: str) -> bool:
            if key in state.claimed_achievements:
                return False
            state.claimed_achievements.add(key)
            return True

        # Step milestones
        if state.total_steps >= 1000 and claim("steps_1000"):
            state.gold += 100
            state.flow("gold_in_achievement", 100)
        if state.total_steps >= 10000 and claim("steps_10000"):
            state.gold += 200
            state.flow("gold_in_achievement", 200)
        if state.total_steps >= 42195 and claim("steps_42195"):
            state.diamonds += 30
            state.flow("diamonds_in_achievement", 30)
        # Pokedex milestones
        if len(state.pokedex) >= 1 and claim("pokedex_1"):
            state.gold += 200
            state.flow("gold_in_achievement", 200)
        if len(state.pokedex) >= 4 and claim("pokedex_4"):
            state.diamonds += 30
            state.flow("diamonds_in_achievement", 30)
        if len(state.pokedex) >= 8 and claim("pokedex_8"):
            state.diamonds += 50
            state.flow("diamonds_in_achievement", 50)
        # Growth milestone
        if any(int(cat["level"]) >= 3 for cat in state.cats) and claim("cat_level_3"):
            state.gold += 300
            state.flow("gold_in_achievement", 300)

    def _exploration(self, state: SimState, rng: random.Random) -> None:
        slots = int(self.params["exploration"]["slots"])
        returns = min(slots, len(state.cats), int(self.params["exploration"]["exploration_per_day"]))
        probabilities = self.params["exploration"]["return_probabilities"]
        for _ in range(returns):
            if not state.first_exploration_done and self.params["exploration"]["first_exploration_guaranteed_postcard"]:
                reward = "postcard"
                state.first_exploration_done = True
            else:
                draw = rng.random()
                total = 0.0
                reward = "postcard"
                for name, weight in probabilities.items():
                    total += float(weight)
                    if draw <= total:
                        reward = name
                        break
            state.flow("exploration_" + reward, 1)
            if reward == "food_fragment":
                self._apply_affection(state, int(self.params["interaction"]["feed_affection"]))

    def _carry_cat_xp(self, state: SimState) -> None:
        if not state.cats:
            return
        thresholds = self.params["carry_cat"]["level_thresholds"]
        max_level = int(self.params["carry_cat"]["max_level"])
        max_xp = int(self.params["carry_cat"]["total_xp_to_max"])
        # P1/B2 sim 保真修正: 固定主力随行猫(对齐客户端 current_companion_cat_id 语义),
        # 不再轮换 — 旧轮换模型导致 A4 以 not-reached 假失败.
        active = next((c for c in state.cats if c.get("is_active")), state.cats[0])
        # P1 经验软拐点: 日步数 ≤4000 全额, 超出 50%; 品种系数在拐点后乘.
        knee = self.params["carry_cat"].get("xp_soft_knee", {})
        full_steps = int(knee.get("full_amount_steps", 4000))
        over_ratio = float(knee.get("over_ratio", 0.5))
        steps = int(self.profile["daily_steps"])
        effective = min(steps, full_steps) + max(0, steps - full_steps) * over_ratio
        coefficient = float(self.params["carry_cat"]["xp_coefficient_by_breed"].get(active["breed"], 1.0))
        xp_gain = int(effective * coefficient)
        space = max(0, max_xp - int(active["xp"]))
        applied = min(xp_gain, space)
        active["xp"] += applied
        state.flow("cat_xp_gain", applied)
        while active["level"] < max_level and active["xp"] >= int(thresholds[active["level"]]):
            active["level"] += 1
        if active["breed"] == "orange" and active["level"] >= max_level and state.orange_max_level_day is None:
            state.orange_max_level_day = state.current_day
        # N12: 满级溢出经验 1000:1 转羁绊点, 日上限 +5, 总量封顶
        overflow = xp_gain - applied
        if overflow > 0:
            bond_cfg = self.params["carry_cat"].get("bond", {})
            per_point = int(bond_cfg.get("exp_per_point", 1000))
            daily_cap = int(bond_cfg.get("daily_cap", 5))
            total_cap = int(bond_cfg.get("total_cap", 300))
            gain = min(overflow // per_point, daily_cap - state.bond_gained_today,
                       total_cap - state.bond_points)
            if gain > 0:
                state.bond_points += gain
                state.bond_gained_today += gain
                state.flow("bond_points_gain", gain)

    def _events(self, state: SimState, step_count: int) -> None:
        frequency = int(self.params["events"]["event_frequency_per_month"])
        if frequency <= 0:
            return
        duration = int(self.params["events"]["event_duration_days"])
        cycle = max(1, int(30 / frequency))
        if (state.current_day - 1) % cycle < duration:
            petals = int(step_count // 1000) * int(self.params["events"]["event_petals_per_1000_steps"])
            state.spring_petals += petals
            state.flow("spring_petals_in_event", petals)
            if state.current_day % duration == 0:
                gold = state.spring_petals * int(self.params["events"]["event_petals_conversion_rate"])
                state.gold += gold
                state.flow("gold_in_spring_conversion", gold)
                state.spring_petals = 0

    def _record_daily_stats(self, state: SimState) -> None:
        state.flow("end_gold", state.gold)
        state.flow("end_diamonds", state.diamonds)
        state.flow("end_love_petals", state.love_petals)
        state.flow("end_spring_petals", state.spring_petals)
        state.flow("end_energy_pool", state.energy_pool)
        state.flow("end_board_tickets", state.board_tickets)
        state.flow("end_cat_count", len(state.cats))
        state.flow("inventory_capacity", state.inventory_capacity)
