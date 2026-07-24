#!/usr/bin/env python3
"""美术资产入库预检 — 对照 art_manifest.json 校验交付目录。

用法:
    python3 tools/art_check/check_art.py <交付目录> [--class A1_gift_icons ...] [--manifest 路径]

校验项（任一 ERROR 即退出码 1，资产不得入库）:
    1. 清单齐全性: 缺失文件 / 清单外多余文件（多余为 WARN）
    2. 文件名: 全小写 snake_case，仅 [a-z0-9_].png
    3. PNG 头: 真 PNG、8bit、RGBA(color_type=6)、非隔行扫描
    4. 尺寸: 与清单逐像素一致
    5. 内容: 非全透明空图；非 full_bleed 类须四边留 >=3% 透明安全边距
       （防 AI 出图主体出血/贴边，导入后被 fix_alpha_border 裁出毛边）
    6. iCCP 色彩配置块: 存在则 WARN（建议导出时剥离，避免跨平台色偏）

纯标准库实现（含 PNG 解码/反滤波），无第三方依赖。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import struct
import sys
import zlib

NAME_RE = re.compile(r"^[a-z0-9_]+\.png$")


def parse_png(path: str) -> dict:
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return {"error": "不是有效 PNG 文件"}
    pos = 8
    info = {"iccp": False, "idat": b""}
    while pos + 8 <= len(data):
        length, ctype = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        if ctype == b"IHDR":
            w, h, bd, ct, _, _, inter = struct.unpack(">IIBBBBB", chunk)
            info.update(w=w, h=h, bit_depth=bd, color_type=ct, interlace=inter)
        elif ctype == b"IDAT":
            info["idat"] += chunk
        elif ctype == b"iCCP":
            info["iccp"] = True
        elif ctype == b"IEND":
            break
        pos += 12 + length
    if "w" not in info:
        return {"error": "缺少 IHDR 块"}
    return info


def alpha_bbox(info: dict, threshold: int) -> dict:
    """解码 RGBA8 非隔行 PNG，返回 alpha>threshold 的内容包围盒。"""
    w, h = info["w"], info["h"]
    raw = zlib.decompress(info["idat"])
    bpp = 4
    stride = w * bpp
    prev = bytearray(stride)
    min_x, min_y, max_x, max_y = w, h, -1, -1
    pos = 0
    for y in range(h):
        ftype = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if ftype == 1:  # Sub
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif ftype == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ftype == 3:  # Average
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:  # Paeth
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        for x in range(w):
            if line[x * bpp + 3] > threshold:
                if x < min_x:
                    min_x = x
                if x > max_x:
                    max_x = x
                if y < min_y:
                    min_y = y
                if y > max_y:
                    max_y = y
        prev = line
    if max_x < 0:
        return {"empty": True}
    return {"empty": False, "min_x": min_x, "min_y": min_y,
            "max_x": max_x, "max_y": max_y}


def check_file(path: str, spec: dict, defaults: dict) -> tuple[list, list]:
    errors: list[str] = []
    warns: list[str] = []
    base = os.path.basename(path)
    if not NAME_RE.match(base):
        errors.append("文件名不合规（仅允许小写 a-z 0-9 下划线）")
    info = parse_png(path)
    if "error" in info:
        return [info["error"]], warns
    if (info["w"], info["h"]) != (spec["w"], spec["h"]):
        errors.append("尺寸 %dx%d，要求 %dx%d" % (info["w"], info["h"], spec["w"], spec["h"]))
    if info["bit_depth"] != 8:
        errors.append("位深 %d，要求 8bit" % info["bit_depth"])
    if info["color_type"] != 6:
        errors.append("color_type=%d，要求 RGBA(6)——透明底必须带 alpha 通道" % info["color_type"])
    if info.get("interlace"):
        errors.append("隔行扫描 PNG，导出时须关闭 interlace")
    if info["iccp"]:
        warns.append("含 iCCP 色彩配置块，建议导出时剥离（防跨平台色偏）")
    if errors:
        return errors, warns  # 头部不合规就不再解码内容

    box = alpha_bbox(info, int(defaults.get("alpha_threshold", 8)))
    if box["empty"]:
        errors.append("全透明空图（无可见内容）")
        return errors, warns
    if not spec.get("full_bleed", False):
        min_ratio = float(defaults.get("min_margin_ratio", 0.03))
        w, h = info["w"], info["h"]
        margins = {
            "左": box["min_x"] / w,
            "右": (w - 1 - box["max_x"]) / w,
            "上": box["min_y"] / h,
            "下": (h - 1 - box["max_y"]) / h,
        }
        bad = ["%s%.1f%%" % (k, v * 100) for k, v in margins.items() if v < min_ratio]
        if bad:
            errors.append("内容贴边/出血：安全边距不足 %d%%（%s）"
                          % (min_ratio * 100, " ".join(bad)))
    return errors, warns


def main() -> int:
    ap = argparse.ArgumentParser(description="美术资产入库预检")
    ap.add_argument("delivery_dir", help="美术交付目录（递归扫描 *.png）")
    ap.add_argument("--class", dest="classes", action="append", default=None,
                    help="只检查指定类（可多次），默认全部")
    ap.add_argument("--manifest", default=os.path.join(os.path.dirname(__file__), "art_manifest.json"))
    args = ap.parse_args()

    with open(args.manifest, "r", encoding="utf-8") as fh:
        manifest = json.load(fh)
    defaults = manifest.get("defaults", {})
    classes = manifest["classes"]
    if args.classes:
        unknown = [c for c in args.classes if c not in classes]
        if unknown:
            print("未知类: %s\n可用: %s" % (unknown, ", ".join(classes)))
            return 2
        classes = {k: v for k, v in classes.items() if k in args.classes}

    found: dict[str, str] = {}
    for root, _dirs, fnames in os.walk(args.delivery_dir):
        for fn in fnames:
            if fn.lower().endswith(".png"):
                if fn in found:
                    print("ERROR  重名文件出现两次: %s" % fn)
                found[fn] = os.path.join(root, fn)

    n_err = n_warn = n_ok = 0
    missing: list[str] = []
    expected_names = set()
    for cname, spec in classes.items():
        for fn in spec["files"]:
            expected_names.add(fn)
            path = found.get(fn)
            if path is None:
                missing.append("%s (%s → %s)" % (fn, cname, spec["target"]))
                continue
            errors, warns = check_file(path, spec, defaults)
            for e in errors:
                print("ERROR  %-42s %s" % (fn, e))
                n_err += 1
            for w in warns:
                print("WARN   %-42s %s" % (fn, w))
                n_warn += 1
            if not errors:
                n_ok += 1

    for fn in missing:
        print("ERROR  缺失 %s" % fn)
        n_err += 1
    extras = sorted(set(found) - expected_names)
    for fn in extras:
        print("WARN   清单外文件: %s（确认是否命名错误）" % fn)
        n_warn += 1

    total = sum(len(s["files"]) for s in classes.values())
    print("\n—— 预检结果：%d/%d 通过，%d 错误，%d 警告 ——" % (n_ok, total, n_err, n_warn))
    if n_err:
        print("存在 ERROR，资产不得入库。修复后重跑本脚本。")
        return 1
    print("全部通过。可移入清单 target 路径，由 Godot 编辑器扫描生成 .import 并一并提交。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
