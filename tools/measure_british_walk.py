#!/usr/bin/env python3
"""Measure visible pixel extents of british walk frames per direction.

For each of the 5 walk directions we open all 4 frames, compute the
non-transparent bounding box, and report width/height/foot_y/x-center.
The Godot sprite applies a single uniform BREED_VISUAL_SCALE (0.45) to
every direction, so any variation in visible pixel size here translates
directly into the cat appearing to grow/shrink on screen.
"""

import glob
import os
from PIL import Image

BASE = "/home/agentuser/catwalk/assets/art/cats/british"
ALPHA_THRESH = 13  # ~0.05 * 255, matches the a > 0.05 test in CatSprite.gd

DIRECTIONS = [
    ("walk_right",     "side_right"),
    ("walk_up_right",  "back_right"),
    ("walk_up",        "back"),
    ("walk_down_right","front_right"),
    ("walk_down",      "front"),
]


def measure(path):
    im = Image.open(path).convert("RGBA")
    W, H = im.size
    px = im.load()
    minx, miny, maxx, maxy = W, H, -1, -1
    sum_x = 0
    count = 0
    for y in range(H):
        for x in range(W):
            if px[x, y][3] > ALPHA_THRESH:
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
                sum_x += x
                count += 1
    if count == 0:
        return None
    width = maxx - minx + 1
    height = maxy - miny + 1
    x_center = sum_x / count            # centroid x (absolute canvas coord)
    x_center_off = x_center - W * 0.5   # centroid relative to canvas center
    bbox_cx = (minx + maxx) / 2.0
    return {
        "W": W, "H": H,
        "width": width, "height": height,
        "minx": minx, "maxx": maxx,
        "miny": miny, "maxy": maxy,
        "foot_y": maxy,                 # lowest opaque pixel = foot
        "top_y": miny,
        "centroid_x": x_center,
        "x_center_off": x_center_off,
        "bbox_cx": bbox_cx,
        "count": count,
    }


def frames_for(prefix):
    return sorted(glob.glob(os.path.join(BASE, f"{prefix}_frame_*.png")))


SCALE = 0.45  # BREED_VISUAL_SCALE["british"]

print(f"{'direction':<16}{'prefix':<13}{'W':>4}{'H':>5}{'footY':>7}{'topY':>6}{'cx_off':>8}   (frame00)")
print("-" * 78)

first_frame = {}
per_dir_stats = {}
for anim, prefix in DIRECTIONS:
    files = frames_for(prefix)
    ms = [measure(f) for f in files]
    ms = [m for m in ms if m]
    first_frame[anim] = ms[0]
    per_dir_stats[anim] = ms
    m = ms[0]
    print(f"{anim:<16}{prefix:<13}{m['width']:>4}{m['height']:>5}"
          f"{m['foot_y']:>7}{m['top_y']:>6}{m['x_center_off']:>8.1f}")

print()
print("=== First-frame comparison (raw pixels, then * scale 0.45) ===")
print(f"{'direction':<16}{'W_px':>6}{'H_px':>6}   {'W*0.45':>8}{'H*0.45':>8}{'footY':>7}{'foot*0.45':>10}")
for anim, _ in DIRECTIONS:
    m = first_frame[anim]
    print(f"{anim:<16}{m['width']:>6}{m['height']:>6}   "
          f"{m['width']*SCALE:>8.1f}{m['height']*SCALE:>8.1f}"
          f"{m['foot_y']:>7}{m['foot_y']*SCALE:>10.1f}")

# Spread analysis across the first frame of each direction
widths = [first_frame[a]['width'] for a, _ in DIRECTIONS]
heights = [first_frame[a]['height'] for a, _ in DIRECTIONS]
foots = [first_frame[a]['foot_y'] for a, _ in DIRECTIONS]
cxs = [first_frame[a]['x_center_off'] for a, _ in DIRECTIONS]


def spread(vals):
    lo, hi = min(vals), max(vals)
    return lo, hi, hi - lo, (hi - lo) / (sum(vals) / len(vals)) * 100.0


print()
print("=== Spread across directions (first frame) ===")
for label, vals in [("width", widths), ("height", heights),
                    ("foot_y", foots)]:
    lo, hi, rng, pct = spread(vals)
    print(f"{label:<10} min={lo:>5}  max={hi:>5}  range={rng:>5}  "
          f"variation={pct:>5.1f}% of mean")
lo, hi = min(cxs), max(cxs)
print(f"{'x_cen_off':<10} min={lo:>6.1f}  max={hi:>6.1f}  range={hi-lo:>5.1f} px "
      f"(*0.45 = {(hi-lo)*SCALE:.1f} screen px)")

# Per-direction frame-to-frame jitter (does size wobble within a walk cycle?)
print()
print("=== Within-direction frame-to-frame variation (all 4 frames) ===")
print(f"{'direction':<16}{'W min..max':>14}{'H min..max':>14}{'footY min..max':>18}")
for anim, _ in DIRECTIONS:
    ms = per_dir_stats[anim]
    ws = [m['width'] for m in ms]
    hs = [m['height'] for m in ms]
    fs = [m['foot_y'] for m in ms]
    print(f"{anim:<16}{f'{min(ws)}..{max(ws)}':>14}"
          f"{f'{min(hs)}..{max(hs)}':>14}{f'{min(fs)}..{max(fs)}':>18}")
