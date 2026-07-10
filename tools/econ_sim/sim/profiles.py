"""Player profile definitions and adoption sorting helpers."""

from __future__ import annotations

import json
import os


def _params_path() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir, "config", "params.json"))


def _load_params() -> dict:
    with open(_params_path(), "r", encoding="utf-8") as fh:
        return json.load(fh)


def _step_value(params: dict, activity: str) -> int:
    references = params["steps"]["_steps_energy_reference"]
    key_prefix = {"low": "low_", "medium": "medium_", "high": "high_"}[activity]
    for key in references:
        if key.startswith(key_prefix):
            return int(key.rsplit("_", 1)[1])
    raise KeyError("missing daily step reference for activity: %s" % activity)


def _attendance_value(params: dict, activity: str) -> float:
    attendance = params["checkin"]["attendance_rate"]
    key = {"low": "low_activity", "medium": "medium_activity", "high": "high_activity"}[activity]
    return float(attendance[key])


def _profile(activity: str, ads_enabled: bool, has_monthly_card: bool, params: dict) -> dict:
    return {
        "daily_steps": _step_value(params, activity),
        "activity": activity,
        "ads_enabled": bool(ads_enabled),
        "has_monthly_card": bool(has_monthly_card),
        "checkin_attendance_rate": _attendance_value(params, activity),
        "default_behavior": {
            "hatching_priority": "incubate_first",
            "inventory_full_priority": "adopt_common_level_2_affection_100_first",
            "board_game": "play_when_ticket_available",
            "shop": "buy_highest_tier_when_petals_or_gold_enough",
            # R1-2: idealized daily interaction count feeds the ticket-per-interaction path
            "daily_interactions": int(params["interaction"]["daily_interactions_idealized"]),
        },
    }


_PARAMS = _load_params()
PROFILES = {}
for _activity in ("low", "medium", "high"):
    for _ads_label, _ads_enabled in (("ad_off", False), ("ad_on", True)):
        for _card_label, _has_card in (("nocard", False), ("card", True)):
            PROFILES["%s_%s_%s" % (_activity, _ads_label, _card_label)] = _profile(
                _activity, _ads_enabled, _has_card, _PARAMS
            )

ALL_PROFILE_NAMES = list(PROFILES.keys())


def _rarity_rank(rarity: str) -> int:
    order = {"common": 0, "rare": 1, "epic": 2, "legendary": 3}
    return order.get(str(rarity).lower(), 99)


def get_rancher_priority_cats(state) -> list:
    """Return cats sorted by the default adoption priority.

    Common cats with level >= 2 and affection >= 100 are preferred. Within that
    set, lower rarity and less-progressed cats are selected before valuable or
    more developed cats.
    """
    cats = list(getattr(state, "cats", []))

    def key(cat: dict) -> tuple:
        eligible = (
            str(cat.get("rarity", "")).lower() == "common"
            and int(cat.get("level", 0)) >= 2
            and int(cat.get("affection", 0)) >= 100
        )
        return (
            0 if eligible else 1,
            _rarity_rank(cat.get("rarity", "")),
            int(cat.get("level", 0)),
            int(cat.get("affection", 0)),
            str(cat.get("breed", "")),
        )

    return sorted(cats, key=key)
