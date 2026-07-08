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
        self.first_expansion_day = None
        self.legendary_pity_triggers = 0
        self.dead_items = 0
        self.orange_max_level_day = None
        self.pokedex = set()
        self.first_exploration_done = False
        self._adoptions_this_week = 0
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
        for index in range(int(self.params["workshop"]["max_slots"])):
            self.workshop_slots.append({"index": index, "progress": 0, "box": None})

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
        capacity = int(self.params["cat_inventory"]["initial_capacity"])
        for tier in self.params["cat_inventory"]["expansion_tiers"]:
            if len(self.pokedex) >= int(tier["unlock_at_pokedex"]):
                capacity = int(tier["new_capacity"])
        return capacity

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
        if self.first_expansion_day is None:
            initial = int(self.params["cat_inventory"]["initial_capacity"])
            if self.inventory_capacity > initial and self.current_day:
                self.first_expansion_day = self.current_day

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
        if day % int(self.params["cat_inventory"]["adoption_reset_day"] or 7) == 1:
            state._adoptions_this_week = 0

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
        self._board_ticket_grants(state, step_count)
        self._ads(state)
        self._energy_routing(state, step_energy)
        self._hatching(state, rng)
        self._adoption(state)
        self._workshop(state, rng)
        self._board_game(state, rng)
        self._shop(state)
        self._exploration(state, rng)
        self._carry_cat_xp(state)
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

    def _ads(self, state: SimState) -> None:
        if not self.profile["ads_enabled"]:
            state.flow("ad_views", 0)
            return
        slot_1 = self.params["ads"]["slot_1"]
        ad_energy = int(slot_1["reward_amount"]) * int(slot_1["daily_limit"])
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
        state.energy_pool += step_energy
        cap = int(self.params["steps"]["max_energy_pool"])
        if state.energy_pool > cap:
            overflow = state.energy_pool - cap
            state.energy_pool = cap
            state.total_overflow_cutoff += overflow
            state.flow("energy_overflow_cutoff", overflow)

    def _hatching(self, state: SimState, rng: random.Random) -> None:
        energy_per_egg = int(self.params["hatching"]["energy_per_egg"])
        for slot in state.hatching_slots:
            if not slot["unlocked"]:
                continue
            if state.energy_pool < energy_per_egg:
                continue
            if len(state.cats) >= state.inventory_capacity:
                break
            state.energy_pool -= energy_per_egg
            state.flow("energy_out_hatching", energy_per_egg)
            state.total_hatches += 1
            rarity = self._roll_rarity(state, rng)
            breed = self._roll_breed(state, rng)
            state._add_cat(breed, rarity)

    def _roll_rarity(self, state: SimState, rng: random.Random) -> str:
        pity = self.params["hatching"]["pity"]
        next_hatch = state.total_hatches + 1
        if next_hatch % int(pity["legendary_every_n"]) == 0:
            state.legendary_pity_triggers += 1
            return "legendary"
        if next_hatch % int(pity["epic_every_n"]) == 0:
            return "epic"
        weights = self.params["hatching"]["rarity_weights"]
        draw = rng.random()
        total = 0.0
        for rarity, weight in weights.items():
            total += float(weight)
            if draw <= total:
                return rarity
        return list(weights.keys())[-1]

    def _roll_breed(self, state: SimState, rng: random.Random) -> str:
        breeds = [cat["breed"] for cat in state.cats]
        chain = self.params["hatching"]["breed_unlock_chain"]
        if breeds.count("british") >= int(chain["british_required_for_siamese"]):
            pool = self.params["hatching"]["breed_pool_weights"]["siamese_unlocked"]
        elif breeds.count("orange") >= int(chain["orange_required_for_british"]):
            pool = self.params["hatching"]["breed_pool_weights"]["british_unlocked"]
        else:
            pool = self.params["hatching"]["breed_pool_weights"]["orange_only"]
        draw = rng.random()
        total = 0.0
        for breed, weight in pool.items():
            total += float(weight)
            if draw <= total:
                return breed
        return list(pool.keys())[-1]

    def _adoption(self, state: SimState) -> None:
        while len(state.cats) > state.inventory_capacity:
            candidate = get_rancher_priority_cats(state)[0]
            revenue = self._adoption_revenue(candidate)
            state.cats.remove(candidate)
            state.love_petals += revenue
            state.total_adoptions += 1
            state._adoptions_this_week += 1
            state.flow("love_petals_in_adoption", revenue)
            state.flow("cats_out_adoption", 1)

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

    def _workshop(self, state: SimState, rng: random.Random) -> None:
        """Workshop only consumes energy when hatching is blocked by inventory.

        Per GDD §2.2.2: workshop activates when cat inventory is full.
        Energy routing priority: incubating_egg > workshop_box > main_pool > cutoff.
        Workshop does NOT drain energy that could be used for hatching — it only
        activates when the player has no room for new cats, regardless of pool level.
        """
        energy_per_box = int(self.params["workshop"]["energy_per_box"])
        if len(state.cats) < state.inventory_capacity:
            # Hatching has room — do NOT let workshop consume energy
            # Energy stays in pool for hatching on future days
            return
        for slot in state.workshop_slots:
            if state.energy_pool < energy_per_box:
                break
            state.energy_pool -= energy_per_box
            category = rng.choice(self.params["workshop"]["box_categories"])
            state.flow("energy_out_workshop", energy_per_box)
            state.flow("workshop_box_" + category, 1)
            if category == "flower_seed":
                state.love_petals += int(self.params["events"]["event_petals_per_10_interactions"])
                state.flow("love_petals_in_workshop", int(self.params["events"]["event_petals_per_10_interactions"]))

    def _board_game(self, state: SimState, rng: random.Random) -> None:
        board = self.params["board_game"]
        clear_rate = float(board["clear_rate"])
        plays = state.board_tickets
        state.board_tickets = 0
        state.total_tickets_spent += plays
        state.flow("tickets_out_board", plays)
        for _ in range(plays):
            if rng.random() <= clear_rate:
                self._board_reward(state, rng)
            else:
                state.flow("board_consolation", 1)

    def _board_reward(self, state: SimState, rng: random.Random) -> None:
        rewards = self.params["board_game"]["reward_probabilities"]
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
            gold = int(self.params["board_game"]["b6_conversion"]["convert_to_gold"])
            state.gold += gold
            state.total_b6_gold += gold
            state.flow("gold_in_b6_conversion", gold)
        elif reward == "cat_can_pack_x3":
            self._apply_affection(state, int(self.params["interaction"]["board_snack_can_affection"]) * 3)
        else:
            self._apply_affection(state, int(self.params["interaction"]["board_snack_affection"]))

    def _apply_affection(self, state: SimState, amount: int) -> None:
        if not state.cats:
            return
        target = state.cats[0]
        target["affection"] += amount
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

        for tier in self.params["cat_inventory"]["expansion_tiers"]:
            cost = int(tier["cost_gold"])
            if cost > 0 and len(state.pokedex) >= int(tier["unlock_at_pokedex"]) and state.gold >= cost:
                state.gold -= cost
                state.flow("gold_out_capacity_expansion", cost)
                if state.first_expansion_day is None:
                    state.first_expansion_day = state.current_day

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
        active = state.cats[0]
        coefficient = float(self.params["carry_cat"]["xp_coefficient_by_breed"].get(active["breed"], 1.0))
        xp_gain = int(int(self.profile["daily_steps"]) * coefficient)
        active["xp"] += xp_gain
        state.flow("cat_xp_gain", xp_gain)
        while active["level"] < max_level and active["xp"] >= int(thresholds[active["level"]]):
            active["level"] += 1
        if active["breed"] == "orange" and active["level"] >= max_level and state.orange_max_level_day is None:
            state.orange_max_level_day = state.current_day

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
