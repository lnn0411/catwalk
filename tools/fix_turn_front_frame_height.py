#!/usr/bin/env python3
"""Step R2: Compress turn_02 / move_turn_02 front-face frame heights.

Goal: Reduce used_h so front-facing frames aren't dramatically taller than
side-facing frames in the same animation group. Keeps bottom_y = 131."""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CAT_ROOT = ROOT / "assets" / "art" / "cats"

BREEDS = ["orange_tabby", "british", "siamese"]
TARGET_FRAMES = ["turn_02.png", "move_turn_02.png"]

ALPHA_THRESHOLD = 8
TARGET_BOTTOM_Y = 131

TARGET_USED_H = {
    "orange_tabby": 96,
    "british": 96,
    "siamese": 100,
}


def get_used_rect(img):
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size

    min_x, min_y = w, h
    max_x, max_y = -1, -1

    for y in range(h):
        for x in range(w):
            if px[x, y][3] > ALPHA_THRESHOLD:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    if max_x < 0:
        return None

    return min_x, min_y, max_x, max_y


def fix_one(path: Path, target_h: int):
    img = Image.open(path).convert("RGBA")
    canvas_w, canvas_h = img.size

    rect = get_used_rect(img)
    if rect is None:
        print(f"  skip empty: {path.name}")
        return

    min_x, min_y, max_x, max_y = rect
    used_w = max_x - min_x + 1
    used_h = max_y - min_y + 1

    if used_h <= target_h:
        print(f"  skip already ok: {path.name} used_h={used_h} ≤ {target_h}")
        return

    body = img.crop((min_x, min_y, max_x + 1, max_y + 1))
    new_h = target_h
    new_w = used_w
    body = body.resize((new_w, new_h), Image.Resampling.LANCZOS)

    new_img = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    paste_x = int((canvas_w - new_w) / 2)
    paste_y = TARGET_BOTTOM_Y - new_h + 1
    new_img.alpha_composite(body, (paste_x, paste_y))

    backup = path.with_suffix(".png.bak")
    if not backup.exists():
        path.rename(backup)

    new_img.save(path)
    print(f"  fixed: {path.name} used_h {used_h} → {new_h}")


def main():
    for breed in BREEDS:
        target_h = TARGET_USED_H[breed]
        print(f"\n--- {breed} (target ≤ {target_h}) ---")
        for frame in TARGET_FRAMES:
            path = CAT_ROOT / breed / frame
            if not path.exists():
                print(f"  missing: {path}")
                continue
            fix_one(path, target_h)


if __name__ == "__main__":
    main()
