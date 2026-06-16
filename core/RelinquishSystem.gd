# RelinquishSystem — 爱心送养流转系统 (Autoload)
# GDD v2.17 §2.2.1 · T3-4 §5.3
# 送养公式、每周限流 500 花瓣、Common 级零收益阻断、幂等键去重
extends Node

const WEEKLY_PETAL_CAP := 500

# 品种基础值 Base(Breed)
const BREED_BASE := {
	"orange": 5,
	"british": 10,
	"siamese": 15,
}

# 稀有度系数 RarityFactor
const RARITY_FACTOR := {
	"common": 1.0,
	"rare": 1.5,
	"epic": 2.0,
	"legendary": 3.0,
}

# 等级权重 LevelFactor
static func _level_factor(level: int) -> float:
	if level <= 1:
		return 0.0    # Lv.1 公式断路
	if level <= 3:
		return 1.0
	if level <= 6:
		return 1.5
	if level <= 9:
		return 2.0
	return 3.0        # Lv.10 满级

# 好感度权重 AffectionFactor
static func _affection_factor(friendship: int) -> float:
	if friendship < 100:
		return 0.0    # 好感值 < 100 公式断路
	if friendship < 500:
		return 1.0
	if friendship < 1500:
		return 1.5
	return 2.0

var this_week_petals_gained: int = 0
var week_reset_timestamp: int = 0
var relinquished_event_ids: Array = []

func _ready() -> void:
	pass

# 送养猫咪主方法
# cat_data: Dictionary 含 species/rarity/level/friendship
# relinquish_event_id: String UUIDv4 幂等键
# 返回 Dictionary { love_petals: int, gold_coins: int, blocked: bool, reason: String }
func relinquish_cat(cat_data: Dictionary, relinquish_event_id: String) -> Dictionary:
	# 幂等键去重
	if relinquish_event_id in relinquished_event_ids:
		return {
			"love_petals": 0,
			"gold_coins": 0,
			"blocked": true,
			"reason": "重复送养请求（幂等键已存在）",
		}

	# 周上限已达
	if this_week_petals_gained >= WEEKLY_PETAL_CAP:
		relinquished_event_ids.append(relinquish_event_id)
		return {
			"love_petals": 0,
			"gold_coins": 100,
			"blocked": true,
			"reason": "本周爱心花瓣获取已达 500 颗上限！",
		}

	var species := String(cat_data.get("species", "orange"))
	var rarity := String(cat_data.get("rarity", "common"))
	var level := int(cat_data.get("level", 1))
	var friendship := int(cat_data.get("friendship", 0))

	var base := int(BREED_BASE.get(species, 5))
	var rarity_mult := float(RARITY_FACTOR.get(rarity, 1.0))
	var level_mult := _level_factor(level)
	var affection_mult := _affection_factor(friendship)

	# 等级或好感断路 → 0 花瓣
	if level_mult <= 0.0 or affection_mult <= 0.0:
		relinquished_event_ids.append(relinquish_event_id)
		return {
			"love_petals": 0,
			"gold_coins": 200 if rarity == "common" else 50,
			"blocked": true,
			"reason": "等级太低或好感不足，无法获得爱心花瓣",
		}

	# 计算花瓣奖励
	var raw_petals: int = int(round(float(base) * rarity_mult * level_mult * affection_mult))

	# Common 级 Lv.1 零收益阻断
	if rarity == "common" and raw_petals <= 0:
		relinquished_event_ids.append(relinquish_event_id)
		return {
			"love_petals": 0,
			"gold_coins": 200,
			"blocked": false,
			"reason": "Common 级猫咪送养仅返还金币",
		}

	# 周上限截断
	var allowed: int = raw_petals
	if this_week_petals_gained + raw_petals > WEEKLY_PETAL_CAP:
		allowed = WEEKLY_PETAL_CAP - this_week_petals_gained

	this_week_petals_gained += allowed
	relinquished_event_ids.append(relinquish_event_id)

	# 实际发放爱心花瓣
	if CurrencyManager and allowed > 0:
		CurrencyManager.add_love_petals(allowed, "relinquish_cat")

	return {
		"love_petals": allowed,
		"gold_coins": 200 if rarity == "common" else 100,
		"blocked": false,
		"reason": "",
	}

# 存档读写
func apply_save(data: Dictionary) -> void:
	this_week_petals_gained = max(int(data.get("this_week_petals_gained", 0)), 0)
	week_reset_timestamp = int(data.get("week_reset_timestamp", 0))
	relinquished_event_ids = Array(data.get("relinquished_event_ids", []))

func get_save_data() -> Dictionary:
	return {
		"this_week_petals_gained": this_week_petals_gained,
		"week_reset_timestamp": week_reset_timestamp,
		"relinquished_event_ids": relinquished_event_ids.duplicate(true),
	}
