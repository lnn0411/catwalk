"""P4 收养花瓣 A vs B 对照报告生成脚本。

从 A 组 (output/) 和 B 组 (output/b_group/) 的 CSV 中提取
love_petals_in_adoption 数据，生成 A vs B 对照表。
"""

import csv, json, os, statistics

A_DIR = os.path.join(os.path.dirname(__file__), "output")
B_DIR = os.path.join(os.path.dirname(__file__), "output", "b_group")
OUT_PATH = os.path.join(os.path.dirname(__file__), "output", "P4_adoption_comparison.md")

PROFILE_ORDER = [
    "low_ad_off_nocard", "low_ad_off_card", "low_ad_on_nocard", "low_ad_on_card",
    "medium_ad_off_nocard", "medium_ad_off_card", "medium_ad_on_nocard", "medium_ad_on_card",
    "high_ad_off_nocard", "high_ad_off_card", "high_ad_on_nocard", "high_ad_on_card",
]


def load_adoption_data(csv_dir: str) -> dict:
    """{profile_name: {30: (cats_mean, petals_mean), 90: (cats_mean, petals_mean)}}"""
    results = {}
    for fname in sorted(os.listdir(csv_dir)):
        if not fname.endswith(".csv"):
            continue
        base = fname.replace(".csv", "")
        parts = base.rsplit("_", 1)
        if len(parts) != 2:
            continue
        profile = parts[0]
        days = int(parts[1].replace("d", ""))

        with open(os.path.join(csv_dir, fname), "r") as f:
            reader = csv.DictReader(f)
            rows = list(reader)

        cats_values = []
        petals_values = []
        for row in rows:
            try:
                cats_values.append(float(row.get("cats_out_adoption_mean", 0)))
                petals_values.append(float(row.get("love_petals_in_adoption_mean", 0)))
            except (ValueError, TypeError):
                continue

        if profile not in results:
            results[profile] = {}
        results[profile][days] = (
            statistics.mean(cats_values) if cats_values else 0,
            statistics.mean(petals_values) if petals_values else 0,
        )
    return results


def main():
    a_data = load_adoption_data(A_DIR)
    b_data = load_adoption_data(B_DIR)

    lines = []
    lines.append("# P4 收养花瓣 A vs B 对照报告")
    lines.append("")
    lines.append("## 30天数据")
    lines.append("")
    lines.append("| Profile | A 收养数 | B 收养数 | A 花瓣 | B 花瓣 | 花瓣倍数 |")
    lines.append("|---|---:|---:|---:|---:|---:|")

    for profile in PROFILE_ORDER:
        a = a_data.get(profile, {}).get(30, (0, 0))
        b = b_data.get(profile, {}).get(30, (0, 0))
        ratio = b[1] / a[1] if a[1] > 0 else 0
        lines.append(
            f"| {profile} | {a[0]:.1f} | {b[0]:.1f} | {a[1]:.1f} | {b[1]:.1f} | {ratio:.2f}x |"
        )

    lines.append("")
    lines.append("## 90天数据")
    lines.append("")
    lines.append("| Profile | A 收养数 | B 收养数 | A 花瓣 | B 花瓣 | 花瓣倍数 |")
    lines.append("|---|---:|---:|---:|---:|---:|")

    for profile in PROFILE_ORDER:
        a = a_data.get(profile, {}).get(90, (0, 0))
        b = b_data.get(profile, {}).get(90, (0, 0))
        ratio = b[1] / a[1] if a[1] > 0 else 0
        lines.append(
            f"| {profile} | {a[0]:.1f} | {b[0]:.1f} | {a[1]:.1f} | {b[1]:.1f} | {ratio:.2f}x |"
        )

    # Summary
    all_ratios_30 = []
    all_ratios_90 = []
    for profile in PROFILE_ORDER:
        a30 = a_data.get(profile, {}).get(30, (0, 0))
        b30 = b_data.get(profile, {}).get(30, (0, 0))
        a90 = a_data.get(profile, {}).get(90, (0, 0))
        b90 = b_data.get(profile, {}).get(90, (0, 0))
        if a30[1] > 0:
            all_ratios_30.append(b30[1] / a30[1])
        if a90[1] > 0:
            all_ratios_90.append(b90[1] / a90[1])

    lines.append("")
    lines.append("## 汇总")
    lines.append("")
    lines.append(f"- 30d 花瓣倍数均值: {statistics.mean(all_ratios_30):.2f}x (n={len(all_ratios_30)})")
    lines.append(f"- 90d 花瓣倍数均值: {statistics.mean(all_ratios_90):.2f}x (n={len(all_ratios_90)})")
    lines.append("")
    lines.append("**预期**: P4 base×3 → 花瓣输出约 3×。实际倍数反映收养猫的品种/稀有度/等级/好感分布。")
    lines.append("")
    lines.append("**结论**: 花瓣倍数为 3× 则 P4 生效正常。低于 3× 可能是因为收养触发频率不变（由容量压力驱动），")
    lines.append("  但每次收养的收益因 base×3 而翻倍，实际总花瓣输出取决于收养次数。")

    content = "\n".join(lines)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write(content)

    print(content)
    print(f"\n报告已写入: {OUT_PATH}")


if __name__ == "__main__":
    main()
