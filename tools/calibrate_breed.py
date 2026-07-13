#!/usr/bin/env python3
"""
一键校准新品种序列帧，输出 CatSprite.gd 常量代码。
用法: python3 tools/calibrate_breed.py <品种目录名>
示例: python3 tools/calibrate_breed.py british
      python3 tools/calibrate_breed.py siamese
"""
import os, sys, json
from PIL import Image

BREED = sys.argv[1] if len(sys.argv) > 1 else 'british'
BASE = f'/home/agentuser/catwalk/assets/art/cats/{BREED}'
TARGET_SCREEN_H = 76.0

ANIM_GROUPS = {
    'walk_right':        ('side_right',),
    'walk_up_right':     ('back_right',),
    'walk_up':           ('back',),
    'walk_down_right':   ('front_right',),
    'walk_down':         ('front',),
    'idle':              ('idle_front',),
    'idle_side_right':   ('idle_side_right',),
    'idle_front_right':  ('idle_front_right',),
    'idle_back_right':   ('idle_back_right',),
    'idle_back':         ('idle_back',),
    'turn':              ('turn',),
    'move_turn':         ('turn',),
}

def measure_frame(path):
    img = Image.open(path)
    w, h = img.size
    lo, hi = h, 0
    le, ri = w, 0
    for y in range(h):
        for x in range(w):
            px = img.getpixel((x, y))
            if len(px) >= 4 and px[3] > 10:
                lo = min(lo, y); hi = max(hi, y)
                le = min(le, x); ri = max(ri, x)
    return {'w': w, 'h': h, 'vis_h': hi - lo, 'vis_w': ri - le, 'foot_y': hi, 'x_center': 0.0}

def get_x_center(img, w, h):
    sum_x = 0; count = 0
    for y in range(h):
        for x in range(w):
            px = img.getpixel((x, y))
            if len(px) >= 4 and px[3] > 10:
                sum_x += x; count += 1
    return sum_x / count - w * 0.5 if count > 0 else 0.0

# === Measure ===
results = {}
metrics_code = {}
scale_entries = {}

for anim_name, prefixes in ANIM_GROUPS.items():
    prefix = prefixes[0]
    frames_data = []
    for i in range(8):
        path = os.path.join(BASE, f'{prefix}_frame_0{i}.png')
        if not os.path.exists(path):
            break
        raw = measure_frame(path)
        img = Image.open(path)
        xc = get_x_center(img, raw['w'], raw['h'])
        frames_data.append({'foot_y': raw['foot_y'], 'x_center': round(xc, 2)})
    
    if not frames_data:
        continue
    
    heights = []
    for i in range(8):
        path = os.path.join(BASE, f'{prefix}_frame_0{i}.png')
        if not os.path.exists(path):
            break
        raw = measure_frame(path)
        heights.append(raw['vis_h'])
    
    avg_vis_h = sum(heights) / len(heights) if heights else 0
    scale = TARGET_SCREEN_H / avg_vis_h if avg_vis_h > 0 else 1.0
    
    results[anim_name] = {'n': len(frames_data), 'avg_h': avg_vis_h, 'scale': round(scale, 4)}
    metrics_code[prefix] = [{'f': f['foot_y'], 'x': f['x_center']} for f in frames_data]

# === Output ===
print(f'// 由 tools/calibrate_breed.py 自动生成 — 品种: {BREED}')
print(f'// 目标屏幕高度: {TARGET_SCREEN_H}px')
print(f'// 扫描帧数: {sum(r["n"] for r in results.values())}')
print()
print('PER_ANIM_SCALE[' + f'"{BREED}"] = ' + '{')
for anim_name, d in sorted(results.items()):
    print(f'    "{anim_name}": {d["scale"]:>.4f},')
print('}')
print()
print(f'const {BREED.upper()}_FRAME_METRICS := ' + '{')
for prefix, data in sorted(metrics_code.items()):
    js = json.dumps(data)
    print(f'    "{prefix}": {js},')
print('}')
print()

# Validation
print('=== 验证 ===')
print(f'{"动画":<20} {"可见高":>6} {"缩放":>8} {"屏幕高":>7}')
print('-' * 44)
for anim_name, d in sorted(results.items()):
    screen_h = d['avg_h'] * d['scale']
    ok = '✓' if abs(screen_h - TARGET_SCREEN_H) < 0.5 else '✗'
    print(f'{ok} {anim_name:<18} {d["avg_h"]:>6.0f} {d["scale"]:>8.4f} {screen_h:>7.1f}')
