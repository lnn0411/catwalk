extends Node

class_name GiftInventory

signal inventory_changed(gift_id: String, count: int)

var gifts: Dictionary = {}

func add_gift(gift_id: String) -> int:
	var current: int = int(gifts.get(gift_id, 0))
	current += 1
	gifts[gift_id] = current
	inventory_changed.emit(gift_id, current)
	_save_state()
	return current

func get_count(gift_id: String) -> int:
	return int(gifts.get(gift_id, 0))

func get_all_gifts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for gift_id in gifts.keys():
		var c: int = int(gifts[gift_id])
		if c <= 0:
			continue
		var wd := _get_workshop_data()
		var item_data: Dictionary = {}
		if wd != null and wd.has_method("get_gift_data"):
			item_data = wd.get_gift_data(String(gift_id))
		result.append({ "gift_id": String(gift_id), "count": c, "item_data": item_data.duplicate(true) })
	result.sort_custom(_sort_by_rarity)
	return result

func has_gift(gift_id: String) -> bool:
	return int(gifts.get(gift_id, 0)) > 0

func remove_gift(gift_id: String, count_to_remove: int = 1) -> bool:
	var current: int = int(gifts.get(gift_id, 0))
	if current < count_to_remove:
		return false
	current -= count_to_remove
	if current <= 0:
		gifts.erase(gift_id)
	else:
		gifts[gift_id] = current
	inventory_changed.emit(gift_id, current)
	_save_state()
	return true

func get_total_gift_count() -> int:
	var total := 0
	for c in gifts.values():
		total += int(c)
	return total

func clear() -> void:
	gifts.clear()
	_save_state()

func get_save_data() -> Dictionary:
	return { "gifts": gifts.duplicate(true) }

func apply_save(data: Dictionary) -> void:
	gifts.clear()
	var saved_gifts: Dictionary = Dictionary(data.get("gifts", {}))
	for gift_id in saved_gifts.keys():
		var c: int = int(saved_gifts[gift_id])
		if c > 0:
			gifts[String(gift_id)] = c

func _get_workshop_data() -> Node:
	if has_node("/root/WorkshopData"):
		return get_node("/root/WorkshopData")
	return null

func _sort_by_rarity(a: Dictionary, b: Dictionary) -> bool:
	var rank_a := _rarity_rank(a.get("item_data", {}).get("rarity", "common"))
	var rank_b := _rarity_rank(b.get("item_data", {}).get("rarity", "common"))
	if rank_a != rank_b:
		return rank_a > rank_b
	return String(a.get("gift_id", "")) < String(b.get("gift_id", ""))

func _rarity_rank(rarity) -> int:
	var r: String = String(rarity)
	match r:
		CatData.RARITY_LEGENDARY:
			return 3
		CatData.RARITY_EPIC:
			return 2
		CatData.RARITY_RARE:
			return 1
		_:
			return 0

func _save_state() -> void:
	if has_node("/root/SaveManager"):
		var sm := get_node("/root/SaveManager")
		if sm.has_method("save_all"):
			sm.save_all()
