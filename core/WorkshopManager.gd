extends Node

signal slot_energy_changed(slot_idx: int, current: float, max: float)
signal slot_box_ready(slot_idx: int)
signal slot_box_opened(slot_idx: int, gift_id: String)

const MAX_SLOTS := 4
const ENERGY_PER_SLOT := 3000.0
const SAVE_PATH := "user://workshop.cfg"

var slots: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_slots()


func _ensure_slots() -> void:
	if slots.is_empty():
		for i in range(MAX_SLOTS):
			slots.append({
				"index": i,
				"energy": 0.0,
				"status": "filling",
				"gift_id": "",
			})


func allocate_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	var remaining := amount
	for i in range(MAX_SLOTS):
		var slot: Dictionary = slots[i]
		if slot.get("status", "") != "filling":
			continue
		var need: float = ENERGY_PER_SLOT - float(slot.get("energy", 0.0))
		if need <= 0.0:
			continue
		var added := minf(remaining, need)
		slot["energy"] = float(slot.get("energy", 0.0)) + added
		remaining -= added
		slots[i] = slot
		slot_energy_changed.emit(i, slot["energy"], ENERGY_PER_SLOT)
		if float(slot["energy"]) >= ENERGY_PER_SLOT:
			slot["status"] = "box_ready"
			slots[i] = slot
			slot_box_ready.emit(i)
		if remaining <= 0.0:
			break


func open_box(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= MAX_SLOTS:
		return {"success": false, "gift_id": ""}
	var slot: Dictionary = slots[slot_idx]
	if slot.get("status", "") != "box_ready":
		return {"success": false, "gift_id": ""}

	var gift_id := ""
	if has_node("/root/WorkshopData"):
		gift_id = String(get_node("/root/WorkshopData").roll_gift())
	else:
		gift_id = "toy_yarn"

	slot["status"] = "box_opened"
	slot["gift_id"] = gift_id
	slots[slot_idx] = slot
	slot_box_opened.emit(slot_idx, gift_id)

	if gift_id != "" and has_node("/root/GiftInventory"):
		get_node("/root/GiftInventory").add_gift(gift_id)

	return {"success": true, "gift_id": gift_id}


func reset_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= MAX_SLOTS:
		return
	slots[slot_idx] = {
		"index": slot_idx,
		"energy": 0.0,
		"status": "filling",
		"gift_id": "",
	}
	slot_energy_changed.emit(slot_idx, 0.0, ENERGY_PER_SLOT)


func get_slots() -> Array:
	var result: Array = []
	for s in slots:
		result.append(s.duplicate(true))
	return result


func is_workshop_active() -> bool:
	for s in slots:
		if s.get("status", "") == "filling" and float(s.get("energy", 0.0)) > 0.0:
			return true
		if s.get("status", "") == "box_ready":
			return true
	return false


func get_save_data() -> Dictionary:
	return {"slots": slots.duplicate(true)}


func apply_save(data: Dictionary) -> void:
	slots = Array(data.get("slots", []))
	_ensure_slots()
