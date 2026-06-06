extends Node

signal slots_changed(slots: Array)
signal hatch_completed(cat: Dictionary, slot_id: int)

const CatData := preload("res://core/CatData.gd")
const SLOT_COUNT := 4
const SLOT_UNLOCK_HATCH_COUNTS := [0, 1, 3, 10]

var slots: Array = []
var cats: Array = []
var hatched_count: int = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_load_state()
	_ensure_slots()
	_update_unlocks()
	_assign_next_empty_slot()
	_emit_slots_changed()

func add_energy(amount: int) -> void:
	var remaining: int = max(amount, 0)
	if remaining <= 0:
		return

	while remaining > 0:
		var slot_id: int = _get_active_filling_slot()
		if slot_id == -1:
			break

		var slot: Dictionary = slots[slot_id]
		var need: int = int(slot["max_energy"]) - int(slot["energy"])
		var added: int = min(remaining, need)
		slot["energy"] = int(slot["energy"]) + added
		remaining -= added
		if int(slot["energy"]) >= int(slot["max_energy"]):
			slot["status"] = "complete"
		slots[slot_id] = slot

	_save_state()
	_emit_slots_changed()

func hatch(slot_id: int) -> Dictionary:
	if slot_id < 0 or slot_id >= slots.size():
		return {}

	var slot: Dictionary = slots[slot_id]
	if String(slot.get("status", "")) != "complete":
		return {}

	var breed: String = String(slot.get("species", CatData.BREED_ORANGE))
	var rarity: String = _roll_rarity()
	hatched_count += 1
	var cat: Dictionary = CatData.create_cat("cat_%d" % hatched_count, breed, rarity, hatched_count)
	cats.append(cat)

	slot["status"] = "empty"
	slot["energy"] = 0
	slot["max_energy"] = 0
	slot["species"] = ""
	slots[slot_id] = slot

	_update_unlocks()
	_assign_next_empty_slot()
	_save_state()
	_emit_slots_changed()
	hatch_completed.emit(cat, slot_id)
	return cat

func get_slots() -> Array:
	return slots.duplicate(true)

func get_cats() -> Array:
	return cats.duplicate(true)

func get_hatched_count() -> int:
	return hatched_count

func get_unlocked_species() -> Array:
	var total: int = _get_total_energy_produced()
	var species: Array = [CatData.BREED_ORANGE]
	if total >= 15000:
		species.append(CatData.BREED_BRITISH)
	if total >= 30000:
		species.append(CatData.BREED_SIAMESE)
	return species

func _ensure_slots() -> void:
	while slots.size() < SLOT_COUNT:
		var index: int = slots.size()
		slots.append({
			"id": index,
			"unlocked": index == 0,
			"status": "empty" if index == 0 else "locked",
			"energy": 0,
			"max_energy": 0,
			"species": "",
		})

func _update_unlocks() -> void:
	for i in range(SLOT_COUNT):
		var slot: Dictionary = slots[i]
		var unlocked: bool = hatched_count >= int(SLOT_UNLOCK_HATCH_COUNTS[i])
		slot["unlocked"] = unlocked
		if not unlocked:
			slot["status"] = "locked"
			slot["energy"] = 0
			slot["max_energy"] = 0
			slot["species"] = ""
		elif String(slot.get("status", "locked")) == "locked":
			slot["status"] = "empty"
		slots[i] = slot

func _assign_next_empty_slot() -> void:
	for i in range(SLOT_COUNT):
		var slot: Dictionary = slots[i]
		if bool(slot.get("unlocked", false)) and String(slot.get("status", "")) == "empty":
			var species: String = _roll_next_species()
			slot["status"] = "filling"
			slot["energy"] = 0
			slot["max_energy"] = CatData.get_hatch_cost(species)
			slot["species"] = species
			slots[i] = slot
			return

func _get_active_filling_slot() -> int:
	for i in range(SLOT_COUNT):
		var slot: Dictionary = slots[i]
		if bool(slot.get("unlocked", false)) and String(slot.get("status", "")) == "filling":
			return i
	return -1

func _roll_next_species() -> String:
	var species: Array = get_unlocked_species()
	if hatched_count == 0:
		return CatData.BREED_ORANGE
	return String(species[rng.randi_range(0, species.size() - 1)])

func _roll_rarity() -> String:
	var roll: float = rng.randf()
	if roll < 0.01:
		return CatData.RARITY_LEGENDARY
	if roll < 0.06:
		return CatData.RARITY_EPIC
	if roll < 0.30:
		return CatData.RARITY_RARE
	return CatData.RARITY_COMMON

func _get_total_energy_produced() -> int:
	if EnergyEngine:
		return EnergyEngine.total_energy_produced
	return 0

func _emit_slots_changed() -> void:
	slots_changed.emit(get_slots())

func _load_state() -> void:
	if SaveManager:
		var state: Dictionary = SaveManager.get_hatch_state()
		slots = Array(state.get("slots", []))
		cats = Array(state.get("cats", []))
		hatched_count = int(state.get("hatched_count", cats.size()))

func _save_state() -> void:
	if SaveManager:
		SaveManager.set_hatch_state({
			"slots": slots,
			"cats": cats,
			"hatched_count": hatched_count,
		})
