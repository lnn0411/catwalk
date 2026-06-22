# RelinquishSystem — 爱心送养流转系统 (Autoload)
# GDD v2.17 §2.2.1 · T4-11 SPEC
# 送养公式: 稀有度系数 × (等级 × 10 + 好感 × 2)
extends Node

const WEEKLY_PETAL_CAP := 500

# 稀有度系数 RarityFactor (T4-11 SPEC)
const RARITY_FACTOR := {
	"common": 0.0,
	"rare": 1.0,
	"epic": 2.0,
	"legendary": 5.0,
}

var this_week_petals_gained: int = 0
var week_reset_timestamp: int = 0
var relinquished_event_ids: Array = []

func _ready() -> void:
	pass

# 送养猫咪主方法
# cat_data: Dictionary 含 species/rarity/level/friendship/id
# relinquish_event_id: String UUIDv4 幂等键
# 返回 Dictionary { love_petals: int, gold_coins: int, blocked: bool, reason: String }
func relinquish_cat(cat_data: Dictionary, relinquish_event_id: String) -> Dictionary:
	# 幂等键去重
	if relinquish_event_id in relinquished_event_ids:
		return { "love_petals": 0, "gold_coins": 0, "blocked": true, "reason": "重复送养请求" }

	var rarity := String(cat_data.get("rarity", "common"))
	var level := int(cat_data.get("level", 1))
	var friendship := int(cat_data.get("friendship", 0))
	var rarity_mult := float(RARITY_FACTOR.get(rarity, 0.0))

	# Common 级: 始终返还 200 金币，0 花瓣
	if rarity == "common" or rarity_mult <= 0.0:
		relinquished_event_ids.append(relinquish_event_id)
		return { "love_petals": 0, "gold_coins": 200, "blocked": false, "reason": "Common级仅返还金币" }

	# 稀有度系数 × (等级 × 10 + 好感 × 2)
	var raw_petals := int(rarity_mult * (level * 10 + friendship * 2))
	raw_petals = max(raw_petals, 0)

	# 周上限检查
	if this_week_petals_gained >= WEEKLY_PETAL_CAP:
		relinquished_event_ids.append(relinquish_event_id)
		return { "love_petals": 0, "gold_coins": 100, "blocked": true, "reason": "本周爱心花瓣已达上限" }

	# 周上限截断
	var allowed := raw_petals
	if this_week_petals_gained + raw_petals > WEEKLY_PETAL_CAP:
		allowed = WEEKLY_PETAL_CAP - this_week_petals_gained

	this_week_petals_gained += allowed
	relinquished_event_ids.append(relinquish_event_id)

	# 发放金币（非 Common 送养也送 100 金币）
	if CurrencyManager:
		if allowed > 0:
			CurrencyManager.add_petals(allowed, "relinquish")
		CurrencyManager.add_gold(100, "relinquish_gold")

	return { "love_petals": allowed, "gold_coins": 100, "blocked": false, "reason": "" }

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
