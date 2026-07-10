# P4 收养花瓣 A vs B 对照报告

## 30天数据

| Profile | A 收养数 | B 收养数 | A 花瓣 | B 花瓣 | 花瓣倍数 |
|---|---:|---:|---:|---:|---:|
| low_ad_off_nocard | 0.1 | 0.1 | 0.4 | 1.1 | 3.10x |
| low_ad_off_card | 0.1 | 0.1 | 0.6 | 1.9 | 3.00x |
| low_ad_on_nocard | 0.0 | 0.1 | 0.0 | 1.6 | 0.00x |
| low_ad_on_card | 0.0 | 0.2 | 0.0 | 3.1 | 0.00x |
| medium_ad_off_nocard | 0.0 | 0.0 | 0.0 | 0.0 | 0.00x |
| medium_ad_off_card | 0.0 | 0.0 | 0.0 | 0.0 | 0.00x |
| medium_ad_on_nocard | 0.0 | 0.0 | 0.0 | 0.0 | 0.00x |
| medium_ad_on_card | 0.0 | 0.0 | 0.0 | 0.0 | 0.00x |
| high_ad_off_nocard | 0.0 | 0.0 | 0.0 | 0.0 | 0.00x |
| high_ad_off_card | 0.0 | 0.0 | 0.0 | 0.0 | 0.00x |
| high_ad_on_nocard | 0.0 | 0.0 | 0.0 | 0.0 | 0.00x |
| high_ad_on_card | 0.0 | 0.0 | 0.0 | 0.0 | 0.00x |

## 90天数据

| Profile | A 收养数 | B 收养数 | A 花瓣 | B 花瓣 | 花瓣倍数 |
|---|---:|---:|---:|---:|---:|
| low_ad_off_nocard | 0.1 | 0.1 | 0.3 | 1.0 | 3.10x |
| low_ad_off_card | 0.1 | 0.1 | 0.6 | 1.9 | 3.00x |
| low_ad_on_nocard | 0.0 | 0.1 | 0.0 | 1.3 | 0.00x |
| low_ad_on_card | 0.0 | 0.2 | 0.1 | 3.1 | 27.84x |
| medium_ad_off_nocard | 0.1 | 0.1 | 1.3 | 4.2 | 3.20x |
| medium_ad_off_card | 0.1 | 0.1 | 1.1 | 3.5 | 3.13x |
| medium_ad_on_nocard | 0.1 | 0.1 | 1.4 | 4.0 | 2.78x |
| medium_ad_on_card | 0.1 | 0.1 | 1.7 | 5.0 | 3.00x |
| high_ad_off_nocard | 0.1 | 0.1 | 2.6 | 6.4 | 2.47x |
| high_ad_off_card | 0.1 | 0.1 | 1.4 | 3.9 | 2.83x |
| high_ad_on_nocard | 0.1 | 0.1 | 1.9 | 5.6 | 2.96x |
| high_ad_on_card | 0.1 | 0.1 | 1.9 | 5.3 | 2.74x |

## 汇总

- 30d 花瓣倍数均值: 3.05x (n=2)
- 90d 花瓣倍数均值: 5.19x (n=11)

**预期**: P4 base×3 → 花瓣输出约 3×。实际倍数反映收养猫的品种/稀有度/等级/好感分布。

**结论**: 花瓣倍数为 3× 则 P4 生效正常。低于 3× 可能是因为收养触发频率不变（由容量压力驱动），
  但每次收养的收益因 base×3 而翻倍，实际总花瓣输出取决于收养次数。