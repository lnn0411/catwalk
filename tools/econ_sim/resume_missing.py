"""Resume B-group: run ONLY missing profile+duration combos, save CSVs."""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from sim.engine import SimEngine
from sim.profiles import ALL_PROFILE_NAMES

_PARAMS_PATH = os.path.join(os.path.dirname(__file__), "config", "params_B.json")
_OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "output", "b_group")


def main() -> None:
    with open(_PARAMS_PATH, "r", encoding="utf-8") as fh:
        params = json.load(fh)

    os.makedirs(_OUTPUT_DIR, exist_ok=True)
    existing = set(os.listdir(_OUTPUT_DIR))
    durations = [int(d) for d in params["simulation"]["durations_days"]]
    iterations = int(params["simulation"]["iterations_per_profile"])

    missing = []
    for profile_name in ALL_PROFILE_NAMES:
        for days in durations:
            fname = "%s_%dd.csv" % (profile_name, days)
            if fname not in existing:
                missing.append((profile_name, days))

    print("Missing: %d combos to run" % len(missing))

    for i, (profile_name, days) in enumerate(missing):
        print("[%d/%d] %s %dd ..." % (i + 1, len(missing), profile_name, days), flush=True)
        engine = SimEngine(profile_name, params=params, iterations=iterations, days=days)
        summary = engine.run()
        csv_path = os.path.join(_OUTPUT_DIR, "%s_%dd.csv" % (profile_name, days))
        engine.save_csv(csv_path)
        # Free memory
        del engine
        print("  gold_p50=%.1f love_petals_p50=%.1f" % (summary["gold"]["p50"], summary["love_petals"]["p50"]), flush=True)

    # Verify
    final = set(os.listdir(_OUTPUT_DIR))
    csv_count = sum(1 for f in final if f.endswith(".csv"))
    print("\nDone. %d CSVs in output/b_group/" % csv_count)


if __name__ == "__main__":
    main()
