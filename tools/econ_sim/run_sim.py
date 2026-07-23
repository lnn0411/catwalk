"""Command-line entry point for the economy simulator."""

from __future__ import annotations

import argparse
import os
import statistics

from sim.engine import SimEngine, load_params
from sim.profiles import ALL_PROFILE_NAMES


def _output_dir(params: dict) -> str:
    return os.path.abspath(params["simulation"]["output_dir"])


def _pass(condition: bool) -> str:
    return "PASS" if condition else "FAIL"


def _mean(values: list) -> float:
    return statistics.mean(values) if values else 0.0


def _run_assertions(results: list[tuple[str, int, SimEngine]], params: dict) -> list[dict]:
    thresholds = params["assertion_thresholds"]
    rows = []
    _a5b_pool = {"pity": 0, "leg": 0}

    for profile_name, days, engine in results:
        states = engine.states
        love_monthly_cycles = [
            (state.daily_flow.get(days, {}).get("end_love_petals", state.love_petals)
             + sum(day.get("love_petals_out_shop", 0) for day in state.daily_flow.values()))
            / max(1, int(params["shop"]["love_petal_store"]["total_round_petals"]))
            / max(1, days / 30.0)
            for state in states
        ]
        p95_cycles = _percentile(love_monthly_cycles, 95)
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A1_love_petal_monthly_cycles",
                "result": _pass(p95_cycles <= float(thresholds["A1_love_petal_monthly_cycles"]["max_cycles_p95"])),
                "observed": "%.2f cycles/month p95" % p95_cycles,
            }
        )

        min_gold = min((min(day.get("end_gold", state.gold) for day in state.daily_flow.values()) for state in states), default=0)
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A2_gold_non_negative",
                "result": _pass(min_gold >= 0),
                "observed": str(min_gold),
            }
        )

        # R3-2 (A2'): use the day gold was actually spent on expansion, not the pokedex date.
        # P1: 分活跃度区间(总案 B4/裁决); 低活跃 observe-only.
        activity = profile_name.split("_", 1)[0]
        expansion_days = [state.first_gold_expansion_day for state in states if state.first_gold_expansion_day is not None]
        ranges = thresholds["A2_first_expansion_day_range_by_activity"]
        # 零送养画像的扩容节奏不受 GDD D20-40 曲线约束(监控画像), observe-only
        expected = "observe" if profile_name == "medium_no_adopt" else ranges.get(activity)
        expansion_mean = _mean(expansion_days)
        if expected == "observe" or expected is None:
            expansion_result = "PASS"
        else:
            expansion_ok = (not expansion_days) or (int(expected[0]) <= expansion_mean <= int(expected[1]))
            expansion_result = _pass(expansion_ok)
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A2_first_expansion_day_range",
                "result": expansion_result,
                "observed": ("not reached" if not expansion_days else "%.1f" % expansion_mean)
                + (" (observe)" if expected == "observe" else ""),
            }
        )

        ad_energy = sum(state.total_ad_energy for state in states)
        step_energy = sum(state.total_step_energy for state in states)
        ratio = ad_energy / max(1, ad_energy + step_energy)
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A3_ad_energy_ratio_max",
                "result": _pass(ratio <= float(thresholds["A3_ad_energy_ratio_max"])),
                "observed": "%.3f" % ratio,
            }
        )

        # P1/B2: A4 仅在 90 天档、中/高活跃评估(30 天窗口 not-reached 不再判 FAIL)
        if days == 90 and activity in ("medium", "high"):
            orange_days = [state.orange_max_level_day for state in states if state.orange_max_level_day is not None]
            target = int(thresholds["A4_orange_max_level_days"]["target"])
            tolerance = int(thresholds["A4_orange_max_level_days"]["tolerance_days"])
            orange_mean = _mean(orange_days)
            rows.append(
                {
                    "profile": profile_name,
                    "days": days,
                    "assertion": "A4_orange_max_level_days",
                    "result": _pass(bool(orange_days) and abs(orange_mean - target) <= tolerance),
                    "observed": "not reached" if not orange_days else "%.1f" % orange_mean,
                }
            )

        # R3-1 A5a: overall legendary acquisition rate — observe-only, all profiles.
        legendary_rate = [state.legendary_pity_triggers / max(1, state.total_hatches) for state in states]
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A5a_legendary_acquisition_rate",
                "result": "PASS",
                "observed": "%.3f" % _mean(legendary_rate),
            }
        )

        # R3-1 A5b → P1 修订: 保底出货占比是保底模型自身性质、与画像无关,
        # 逐画像断言在 n~100 传说样本下必然抽样波动(σ≈0.04) — 改为跨画像合并断言,
        # 每画像仅记录观察值. miss 计数模型理论保底占比 = 0.99^120 ≈ 0.301.
        a5b = thresholds["A5b_legendary_pity_trigger_ratio"]
        min_hatches = int(a5b["min_hatches"])
        eligible = [state for state in states if state.total_hatches >= min_hatches]
        pity_total = sum(state.legendary_pity_triggers for state in eligible)
        leg_total = sum(getattr(state, "total_legendaries", 0) for state in eligible)
        _a5b_pool["pity"] += pity_total
        _a5b_pool["leg"] += leg_total
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A5b_legendary_pity_trigger_ratio",
                "result": "PASS",
                "observed": "observe %d/%d (pooled assertion at end)" % (pity_total, leg_total),
            }
        )

        # P1/B6: 修复旧 A6 高活跃断言空转 bug(0-1 比例误与 days//7 比较恒 PASS)
        overflows = [sum(day.get("energy_overflow_cutoff", 0) for day in state.daily_flow.values()) for state in states]
        overflow_day_ratios = [
            sum(1 for day in state.daily_flow.values() if day.get("energy_overflow_cutoff", 0) > 0) / float(days)
            for state in states
        ]
        if profile_name == "medium_no_adopt":
            ok = True  # 零送养画像的截断是玩家拒绝循环的既定后果, 观察不判
            name = "A6_overflow_cutoff_no_adopt_observe"
        elif profile_name.startswith("medium"):
            ok = max(overflows or [0]) == 0
            name = "A6_medium_overflow_cutoff"
        elif profile_name.startswith("high"):
            a6_high = thresholds["A6_high_overflow_cutoff"]
            ok = (
                _mean(overflow_day_ratios) <= float(a6_high["max_overflow_day_ratio"])
                and _mean(overflows) / float(days) <= float(a6_high["max_daily_overflow_mean"])
            )
            name = "A6_high_overflow_cutoff"
        else:
            ok = True
            name = "A6_overflow_cutoff_low_observe"
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": name,
                "result": _pass(ok),
                "observed": "%.1f total cutoff, %.1f%% days" % (_mean(overflows), _mean(overflow_day_ratios) * 100),
            }
        )

        # P1 新增 A12: 低活跃(无广告)孵化节奏 ≥1 颗/3 天(30 天档 ≥9 只)
        if days == 30 and profile_name.startswith("low_ad_off"):
            hatch_mean = _mean([state.total_hatches for state in states])
            rows.append(
                {
                    "profile": profile_name,
                    "days": days,
                    "assertion": "A12_low_hatch_pace",
                    "result": _pass(hatch_mean >= int(thresholds["A12_low_hatches_30d_min"])),
                    "observed": "%.1f hatches/30d" % hatch_mean,
                }
            )

        # P1 新增 A13: 中活跃新手 D2 内孵出第二颗蛋(sim 首次孵化)
        if activity == "medium":
            first_days = [state.first_hatch_day for state in states if state.first_hatch_day is not None]
            first_mean = _mean(first_days)
            rows.append(
                {
                    "profile": profile_name,
                    "days": days,
                    "assertion": "A13_second_egg_by_d2",
                    "result": _pass(bool(first_days) and first_mean <= float(thresholds["A13_first_hatch_day_max"])),
                    "observed": "not reached" if not first_days else "D%.1f" % first_mean,
                }
            )

        # P1 新增 A14: 零送养中活跃月花瓣收入 ≥150(总案 B2, 供给=签到宝箱+工坊折算+邮票)
        if profile_name == "medium_no_adopt":
            petal_income = [
                sum(
                    value
                    for day in state.daily_flow.values()
                    for key, value in day.items()
                    if key.startswith("love_petals_in_")
                )
                / max(1.0, days / 30.0)
                for state in states
            ]
            petal_mean = _mean(petal_income)
            rows.append(
                {
                    "profile": profile_name,
                    "days": days,
                    "assertion": "A14_no_adopt_monthly_petals",
                    "result": _pass(petal_mean >= int(thresholds["A14_no_adopt_monthly_petals_min"])),
                    "observed": "%.1f petals/month" % petal_mean,
                }
            )

        ticket_values = []
        for state in states:
            per_day = [day.get("tickets_in_steps", 0) + day.get("tickets_in_login", 0) for day in state.daily_flow.values()]
            ticket_values.extend(per_day)
        ticket_mean = _mean(ticket_values)
        key = "A7_tickets_full_attendance" if "ad_on" in profile_name else "A7_tickets_no_ad_medium"
        # M4 alignment: the old static range only fit the low-activity profile.
        # Expectation derives from TicketManager params per activity tier:
        #   steps tickets = min(daily_limit, daily_steps // steps_per_ticket)
        #   + login 2/day + new-player extra (+1/day for the first 7 days, amortized)
        board = params["board_game"]
        activity = profile_name.split("_", 1)[0]
        profile_steps = {"low": 1500, "medium": 5000, "high": 8000}[activity]
        steps_tickets = min(
            int(board["ticket_daily_limit_by_steps"]),
            profile_steps // int(board["ticket_per_steps_raw"]),
        )
        newbie_extra = (
            int(board["ticket_new_player_days"])
            * (int(board["ticket_login_new_player"]) - int(board["ticket_login_daily"]))
            / float(days)
        )
        expected = steps_tickets + int(board["ticket_login_daily"]) + newbie_extra
        tolerance = 0.35
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": key,
                "result": _pass(abs(ticket_mean - expected) <= tolerance),
                "observed": "%.2f/day (expect %.2f±%.2f)" % (ticket_mean, expected, tolerance),
            }
        )

        b6_values = [
            sum(day.get("gold_in_b6_conversion", 0) for day in state.daily_flow.values()) for state in states
        ]
        conversion = int(params["board_game"]["b6_conversion"]["convert_to_gold"])
        b6_ok = all(value % conversion == 0 for value in b6_values)
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A8_B6_gold_injection_correct",
                "result": _pass(b6_ok),
                "observed": "%.1f mean gold" % _mean(b6_values),
            }
        )

        dead_items = sum(state.dead_items for state in states)
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A8_dead_items_90d",
                "result": _pass(days != 90 or dead_items <= int(thresholds["A8_dead_items_90d"])),
                "observed": str(dead_items),
            }
        )

        monthly_gold_mean = _mean(
            [
                sum(day.get("gold_in_checkin", 0) + day.get("gold_in_monthly_card", 0) + day.get("gold_in_b6_conversion", 0)
                    for day in state.daily_flow.values())
                / max(1, days / 30.0)
                for state in states
            ]
        )
        end_gold_mean = _mean([state.gold for state in states])
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A9_currency_divergence_check",
                "result": _pass(end_gold_mean < max(1.0, monthly_gold_mean * 10.0)),
                "observed": "end %.1f / monthly %.1f" % (end_gold_mean, monthly_gold_mean),
            }
        )

        adopted = sum(state.total_adoptions for state in states)
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A10_adoption_safety_valve",
                "result": "PASS",
                "observed": "%s adoptions observed" % adopted,
            }
        )

    # A5b 全局合并断言(跨画像×跨时长, 传说样本量上千, 统计有效)
    a5b = thresholds["A5b_legendary_pity_trigger_ratio"]
    if _a5b_pool["leg"] > 0:
        share = _a5b_pool["pity"] / float(_a5b_pool["leg"])
        rows.append(
            {
                "profile": "(all pooled)",
                "days": "-",
                "assertion": "A5b_legendary_pity_share_global",
                "result": _pass(abs(share - float(a5b["target"])) <= float(a5b["tolerance_pp"])),
                "observed": "%.3f (%d/%d)" % (share, _a5b_pool["pity"], _a5b_pool["leg"]),
            }
        )
    return rows


def _percentile(values: list, percentile: int) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return float(ordered[0])
    position = (len(ordered) - 1) * percentile / 100.0
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return float(ordered[lower] * (1.0 - weight) + ordered[upper] * weight)


def _write_report(rows: list[dict], path: str) -> None:
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("# Assertion Report\n\n")
        fh.write("| Profile | Days | Assertion | Result | Observed |\n")
        fh.write("|---|---:|---|---|---|\n")
        for row in rows:
            fh.write(
                "| {profile} | {days} | {assertion} | {result} | {observed} |\n".format(**row)
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Monte Carlo economy simulation.")
    parser.add_argument("--profile", choices=ALL_PROFILE_NAMES, help="single profile to run")
    parser.add_argument("--all", action="store_true", help="run all profiles")
    parser.add_argument("--days", type=int, choices=[30, 90], help="duration in days")
    parser.add_argument("--iterations", type=int, help="Monte Carlo iterations")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    params = load_params()
    profiles = ALL_PROFILE_NAMES if args.all else [args.profile or ALL_PROFILE_NAMES[0]]
    if args.days is not None:
        durations = [args.days]
    elif args.all:
        durations = [int(day) for day in params["simulation"]["durations_days"]]
    else:
        durations = [int(params["simulation"]["durations_days"][0])]
    out_dir = _output_dir(params)
    os.makedirs(out_dir, exist_ok=True)

    results = []
    for profile_name in profiles:
        for days in durations:
            iterations = args.iterations or int(params["simulation"]["iterations_per_profile"])
            engine = SimEngine(profile_name, params=params, iterations=iterations, days=days)
            summary = engine.run()
            csv_path = os.path.join(out_dir, "%s_%dd.csv" % (profile_name, days))
            engine.save_csv(csv_path)
            results.append((profile_name, days, engine))
            print(
                "%s %dd iterations=%d gold_p50=%.1f love_petals_p50=%.1f csv=%s"
                % (
                    profile_name,
                    days,
                    iterations,
                    summary["gold"]["p50"],
                    summary["love_petals"]["p50"],
                    csv_path,
                )
            )

    report_rows = _run_assertions(results, params)
    report_path = os.path.join(out_dir, "assertion_report.md")
    _write_report(report_rows, report_path)
    print("assertion_report=%s" % report_path)


if __name__ == "__main__":
    main()
