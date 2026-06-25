extends Node

# ============================================================
# 猫步天下 · 全局色板 v1.0
# 唯一基准：Style Bible v2.2 §3.1
# 基准色（bible 权威）→ 扩展色（bible 未定义，待补录）
# 更新路径：bible → 本文档 → 代码与原型（单向，杜绝漂移）
# ============================================================

# ===== 基准色：Style Bible v2.2 §3.1（唯一权威）=====
const PAPER_CREAM     := Color("F6EFE2")  # 背景/卡片/留白 50-60%
const AMBER           := Color("F2C572")  # 主色：能量/奖励/按钮/孵化反馈 10-15%
const SOFT_SAGE       := Color("A6BE84")  # 花园/植物 10-15%
const TEXT_PRIMARY    := Color("4F453C")  # 文字 & 亮色填充上的字
const AMBER_PRESS     := Color("C4894A")  # 按钮按下态/深描边（非主色）

# ===== 扩展色：bible 未定义，暂用，待补录 =====
const TEXT_SECONDARY  := Color("A2978C")  # 次级文字、说明
const BORDER          := Color("EFE4D6")  # 卡片描边、分隔
const MOSS            := Color("7A9E6E")  # 成功/随行/生机强调

# 货币色
const COIN            := Color("EAB94F")  # 金币 🪙
const DIAMOND         := Color("86C0DC")  # 钻石 💎
const SPRING_PETAL    := Color("F2A8BE")  # 春日花瓣 🌸（活动货币）
const LOVE_PETAL      := Color("E58AA8")  # 爱心花瓣 💗（送养硬货币）

const BRICK           := Color("B5553C")  # 冷却/警示
const MIST            := Color("D2E4EC")  # 夜间/雨天氛围

# 别名（兼容旧引用，逐步迁移到新命名后清理）
const BORDER_ACTIVE   = Color("C4894A")
const BG_WARM_WHITE   = Color("F6EFE2")   # → 新 PAPER_CREAM
const BG_CEMENT       = Color("F2EDE4")   # 略深于 PAPER_CREAM
const BORDER_DEFAULT  = Color("EFE4D6")   # → 新 BORDER
const TEXT_ON_AMBER   = Color("4F453C")   # → 新 TEXT_PRIMARY
const CITY_GRAY       = Color("A2978C")   # → 新 TEXT_SECONDARY
const MIST_BLUE       = Color("D2E4EC")   # → 新 MIST
const BRICK_RED       = Color("B5553C")   # → 新 BRICK
const MOSS_GREEN      = Color("7A9E6E")   # → 新 MOSS
# 猫毛色（旧临时值，暂保留兼容）
const CAT_ORANGE_MID  = Color("D4834A")
const CAT_BRIT_MID    = Color("9AA0A8")
const CAT_SIAM_BODY   = Color("E8D5C0")

# ===== 阴影（暖棕层级）=====
const UI_SHADOW       := Color("4F453C14")  # 8%  低层 卡片
const UI_SHADOW_MID   := Color("4F453C1F")  # 12% 中层 浮层/抽屉

# ===== 规则 =====
# AMBER/SOFT_SAGE 等亮色填充上的文字一律 TEXT_PRIMARY，禁止白字。
# 按钮样式走 UITheme 的 StyleBoxFlat，禁止在各 .gd 里硬编码颜色。
const UI_PRESSED_AMBER = Color("#B77A3E")    # 主按钮按下态

# --- 稀有度光效 ---
const RARITY_RARE      = Color("#9BB8D4")
const RARITY_EPIC      = Color("#8E6FA8")
const RARITY_LEG_A     = Color("#D6E4EC")
const RARITY_LEG_B     = Color("#E8D5C0")
