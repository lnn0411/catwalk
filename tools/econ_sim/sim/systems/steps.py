"""Step-to-energy conversion for the economy simulator.

The numeric tier configuration is loaded from ``config/params.json`` by callers
and passed in. A small local loader is provided for direct use and smoke tests.
"""

from __future__ import annotations

import json
import os


def _default_params_path() -> str:
    return os.path.abspath(
        os.path.join(os.path.dirname(__file__), os.pardir, os.pardir, "config", "params.json")
    )


def load_params(path: str | None = None) -> dict:
    """Load simulator parameters from JSON."""
    with open(path or _default_params_path(), "r", encoding="utf-8") as fh:
        return json.load(fh)


def calc_energy(steps: int, is_new_player: bool, params: dict | None = None) -> int:
    """Convert raw daily steps into energy using tier coefficients.

    The raw step count remains independent for ticket counting and is therefore
    not returned here; callers should pass the original ``steps`` to board-game
    ticket logic.
    """
    if params is None:
        params = load_params()

    steps_cfg = params["steps"]
    thresholds = list(steps_cfg["tier_thresholds"])
    coefficients = list(steps_cfg["tier_coefficients"])
    new_t1 = steps_cfg["new_player_t1_coefficient"]

    remaining = max(0, int(steps))
    previous = 0
    total = 0.0

    tier_limits = thresholds + [None]
    for index, upper in enumerate(tier_limits):
        if remaining <= 0:
            break

        if upper is None:
            segment = remaining
        else:
            width = max(0, upper - previous)
            segment = min(remaining, width)

        coefficient = coefficients[index]
        if index == 0 and is_new_player:
            coefficient = new_t1

        total += segment * coefficient
        remaining -= segment
        if upper is not None:
            previous = upper

    return int(total)
