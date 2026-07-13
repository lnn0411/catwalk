#!/usr/bin/env python3
"""
Systematic calibration of british cat animation sizes.

Measures the visible (opaque) pixel bounding box of every british cat frame,
averages per animation, and computes a per-animation scale factor that makes
each animation display at exactly TARGET_H px screen height.

The PER_ANIM_SCALE key -> file-prefix mapping mirrors CatSprite.gd's
_anim_to_file_prefix() exactly, so the computed scales line up 1:1 with the
const in scenes/CatSprite.gd.

Alpha threshold matches the engine: CatSprite._get_foot_offset_full uses
alpha > 0.05 (i.e. > 12.75/255) to decide "opaque".
"""

import glob
import os

import numpy as np
from PIL import Image

BREED_DIR = "assets/art/cats/british"
TARGET_H = 76.0
ALPHA_THRESH = 0.05 * 255  # 12.75, matches engine's alpha > 0.05

# PER_ANIM_SCALE key -> file prefix, mirroring CatSprite._anim_to_file_prefix().
# turn/move_turn share the same 'turn' frames.
ANIM_TO_PREFIX = {
    # direction-paired: walk animations
    "walk_right":       "side_right",
    "walk_up_right":    "back_right",
    "walk_up":          "back",
    "walk_down_right":  "front_right",
    "walk_down":        "front",
    # direction-paired: idle animations
    "idle":             "idle_front",       # front idle (ANIM_IDLE)
    "idle_side_right":  "idle_side_right",   # pairs with walk_right
    "idle_back_right":  "idle_back_right",   # pairs with walk_up_right
    "idle_back":        "idle_back",         # pairs with walk_up
    "idle_front_right": "idle_front_right",  # pairs with walk_down_right
    # note: idle_front (pairs with walk_down) == same frames as ANIM_IDLE
    # turn (independent, not direction-paired)
    "turn":             "turn",
    "move_turn":        "turn",
}

# Direction pairs (walk anim, idle anim) sharing one on-screen direction.
DIRECTION_PAIRS = [
    ("RIGHT (向右)",       "walk_right",      "idle_side_right"),
    ("UP_RIGHT (右上)",    "walk_up_right",   "idle_back_right"),
    ("UP (向上)",          "walk_up",         "idle_back"),
    ("DOWN_RIGHT (右下)",  "walk_down_right", "idle_front_right"),
    ("DOWN (向下)",        "walk_down",       "idle"),  # idle_front == ANIM_IDLE
]


def visible_bbox(path):
    """Return (visible_height, visible_width) of the opaque region of one frame.

    Height = lowest_opaque_y - highest_opaque_y + 1 (inclusive span of rows
    containing any opaque pixel). Width computed the same way over columns.
    """
    im = Image.open(path).convert("RGBA")
    alpha = np.asarray(im)[:, :, 3]
    opaque = alpha > ALPHA_THRESH
    rows = np.where(opaque.any(axis=1))[0]
    cols = np.where(opaque.any(axis=0))[0]
    if rows.size == 0 or cols.size == 0:
        return 0.0, 0.0
    h = float(rows[-1] - rows[0] + 1)
    w = float(cols[-1] - cols[0] + 1)
    return h, w


def measure_anim(prefix):
    """Load all {prefix}_frame_NN.png, return (n, avg_h, avg_w, per_frame)."""
    files = sorted(glob.glob(os.path.join(BREED_DIR, f"{prefix}_frame_*.png")))
    heights, widths = [], []
    for f in files:
        h, w = visible_bbox(f)
        heights.append(h)
        widths.append(w)
    if not heights:
        return 0, 0.0, 0.0, []
    return len(heights), float(np.mean(heights)), float(np.mean(widths)), heights


def main():
    print("=" * 78)
    print("TASK 1: Measure every frame file (alpha-bbox visible size, per animation)")
    print("=" * 78)
    print(f"{'anim (PER_ANIM_SCALE key)':<20} {'prefix':<18} {'frames':>6} "
          f"{'avg_h':>8} {'avg_w':>8}")
    print("-" * 78)

    measured = {}  # anim key -> (n, avg_h, avg_w)
    for anim, prefix in ANIM_TO_PREFIX.items():
        n, avg_h, avg_w, _ = measure_anim(prefix)
        measured[anim] = (n, avg_h, avg_w)
        print(f"{anim:<20} {prefix:<18} {n:>6} {avg_h:>8.2f} {avg_w:>8.2f}")

    print()
    print("=" * 78)
    print(f"TASK 2: Compute scale factors  (scale = {TARGET_H:g} / avg_visible_height)")
    print("=" * 78)
    print(f"{'direction':<20} {'walk anim':<16} {'walk_scale':>11}   "
          f"{'idle anim':<18} {'idle_scale':>11}")
    print("-" * 78)

    scales = {}  # anim key -> scale factor (4 dp)
    for label, walk_anim, idle_anim in DIRECTION_PAIRS:
        wn, wh, _ = measured[walk_anim]
        inn, ih, _ = measured[idle_anim]
        ws = round(TARGET_H / wh, 4)
        is_ = round(TARGET_H / ih, 4)
        scales[walk_anim] = ws
        scales[idle_anim] = is_
        print(f"{label:<20} {walk_anim:<16} {ws:>11.4f}   "
              f"{idle_anim:<18} {is_:>11.4f}")

    # turn / move_turn (independent, not direction-paired)
    for anim in ("turn", "move_turn"):
        n, h, _ = measured[anim]
        scales[anim] = round(TARGET_H / h, 4)
    print(f"\n{'turn (independent)':<20} {'turn':<16} {scales['turn']:>11.4f}   "
          f"{'move_turn':<18} {scales['move_turn']:>11.4f}")

    print()
    print("=" * 78)
    print("PER_ANIM_SCALE values for scenes/CatSprite.gd (british):")
    print("=" * 78)
    # Emit in the order the const lists them.
    order = ["walk_right", "walk_up_right", "walk_up", "walk_down_right",
             "walk_down", "idle", "idle_side_right", "idle_front_right",
             "idle_back_right", "idle_back", "turn", "move_turn"]
    for anim in order:
        print(f'        "{anim}": {scales[anim]:.4f},')

    print()
    print("=" * 78)
    print("TASK 4: Validate  (avg_visible_height * scale should equal 76.0 px)")
    print("=" * 78)
    print(f"{'anim':<20} {'avg_h':>8} {'scale':>9} {'screen_h':>9}  status")
    print("-" * 78)
    all_ok = True
    for anim in order:
        n, h, _ = measured[anim]
        s = scales[anim]
        screen_h = h * s
        ok = abs(screen_h - TARGET_H) < 0.5  # within 4-dp rounding tolerance
        all_ok = all_ok and ok
        print(f"{anim:<20} {h:>8.2f} {s:>9.4f} {screen_h:>9.2f}  "
              f"{'OK' if ok else 'FAIL'}")
    print("-" * 78)
    print("ALL ANIMATIONS AT 76px:" , "YES" if all_ok else "NO")


if __name__ == "__main__":
    main()
