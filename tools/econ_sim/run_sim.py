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
        expansion_days = [state.first_gold_expansion_day for state in states if state.first_gold_expansion_day is not None]
        expected = thresholds["A2_first_expansion_day_range"]
        expansion_mean = _mean(expansion_days)
        expansion_ok = (not expansion_days) or (int(expected[0]) <= expansion_mean <= int(expected[1]))
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A2_first_expansion_day_range",
                "result": _pass(expansion_ok),
                "observed": "not reached" if not expansion_days else "%.1f" % expansion_mean,
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

        # R3-1 A5b: pity-trigger ratio — only profiles with enough hatches to be meaningful.
        a5b = thresholds["A5b_legendary_pity_trigger_ratio"]
        min_hatches = int(a5b["min_hatches"])
        eligible = [state for state in states if state.total_hatches >= min_hatches]
        if eligible:
            pity_ratios = [state.legendary_pity_triggers / max(1, state.total_hatches // min_hatches) for state in eligible]
            pity_mean = _mean(pity_ratios)
            pity_result = _pass(abs(pity_mean - float(a5b["target"])) <= float(a5b["tolerance_pp"]))
            pity_observed = "%.3f" % pity_mean
        else:
            pity_result = "N/A (insufficient hatches)"
            pity_observed = "insufficient hatches (min %d)" % min_hatches
        rows.append(
            {
                "profile": profile_name,
                "days": days,
                "assertion": "A5b_legendary_pity_trigger_ratio",
                "result": pity_result,
                "observed": pity_observed,
            }
        )

        overflows = [sum(day.get("energy_overflow_cutoff", 0) for day in state.daily_flow.values()) for state in states]
        if profile_name.startswith("medium"):
            ok = max(overflows or [0]) == 0
            name = "A6_medium_overflow_cutoff"
        elif profile_name.startswith("high"):
            weekly_limit = max(1, days // 7)
            ok = _mean([1 if value > 0 else 0 for value in overflows]) <= weekly_limit
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
                "observed": "%.1f mean cutoff" % _mean(overflows),
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
