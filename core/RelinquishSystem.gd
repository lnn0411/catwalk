# RelinquishSystem — 爱心送养流转系统 (Autoload)
# GDD §2.2.1: LovePetals = Base × RarityFactor × LevelFactor × AffectionFactor
extends Node

const WEEKLY_PETAL_CAP := 500
const GOLD_REWARD := 50

const SPECIES_BASE := {
	"orange": 5,
	"british": 10,
	"siamese": 15,
	"橘猫": 5,
	"英短": 10,
	"暹罗": 15,
}

const RARITY_FACTOR := {
	"common": 0.0,
	"rare": 1.5,
	"epic": 2.0,
	"legendary": 3.0,
}

var this_week_petals_gained: int = 0
var week_reset_timestamp: int = 0
var relinquished_event_ids: Array = []


func _ready() -> void:
	pass


# cat_data: Dictionary 含 species/rarity/level/friendship/id
# relinquish_event_id: String UUIDv4 幂等键
# 返回 Dictionary { love_petals: int, gold_coins: int, blocked: bool, reason: String }
func relinquish_cat(cat_data: Dictionary, relinquish_event_id: String) -> Dictionary:
	if relinquish_event_id in relinquished_event_ids:
		return {"love_petals": 0, "gold_coins": 0, "blocked": true, "reason": "重复送养请求"}

	if HatchEngine == null or HatchEngine.get_cats().size() <= 1:
		return {"love_petals": 0, "gold_coins": 0, "blocked": true, "reason": "不可送走最后一只猫"}

	var rarity := String(cat_data.get("rarity", "common"))
	var petals := _calculate_love_petals(cat_data)
	var awarded_petals := 0

	if rarity != "common" and petals > 0 and this_week_petals_gained < WEEKLY_PETAL_CAP:
		awarded_petals = min(petals, WEEKLY_PETAL_CAP - this_week_petals_gained)
		this_week_petals_gained += awarded_petals
		if CurrencyManager:
			CurrencyManager.add_love_petals(awarded_petals, "relinquish")
		if EventBus:
			EventBus.emit_love_petals_changed(awarded_petals, this_week_petals_gained)

	relinquished_event_ids.append(relinquish_event_id)
	return {"love_petals": awarded_petals, "gold_coins": GOLD_REWARD, "blocked": false, "reason": ""}


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


func reset_all() -> void:
	this_week_petals_gained = 0
	week_reset_timestamp = 0
	relinquished_event_ids = []


func _calculate_love_petals(cat_data: Dictionary) -> int:
	var rarity := String(cat_data.get("rarity", "common"))
	if rarity == "common":
		return 0

	var level_factor := _level_factor(int(cat_data.get("level", 1)))
	var affection_factor := _affection_factor(int(cat_data.get("friendship", cat_data.get("affection", 0))))
	if level_factor <= 0.0 or affection_factor <= 0.0:
		return 0

	var species := String(cat_data.get("species", "orange"))
	var base := int(SPECIES_BASE.get(species, SPECIES_BASE["orange"]))
	var rarity_factor := float(RARITY_FACTOR.get(rarity, 0.0))
	return int(round(float(base) * rarity_factor * level_factor * affection_factor))


func _level_factor(level: int) -> float:
	if level <= 1:
		return 0.0
	if level <= 3:
		return 1.0
	if level <= 6:
		return 1.5
	if level <= 9:
		return 2.0
	return 3.0


func _affection_factor(affection: int) -> float:
	if affection < 100:
		return 0.0
	if affection <= 500:
		return 1.0
	if affection < 1500:
		return 1.5
	return 2.0
