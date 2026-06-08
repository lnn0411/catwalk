extends Node

signal hatch_started(slot: int)
signal hatch_progress(slot: int, progress: float)
signal hatch_complete(cat_data)


const SLOT_COUNT := 4
const SLOT_UNLOCK_HATCH_COUNTS := [0, 1, 3, 10]

var slots: Array = []
var cats: Array = []
var hatched_count: int = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_ensure_slots()
	_update_unlocks()
	_assign_next_empty_slots()
	if StepEngine and not StepEngine.steps_updated.is_connected(_on_steps_updated):
		StepEngine.steps_updated.connect(_on_steps_updated)
	_emit_all_progress()

func feed_energy(amount: float) -> void:
	var remaining: float = max(amount, 0.0)
	if remaining <= 0.0:
		return

	while remaining > 0.0:
		var slot_id: int = _get_active_filling_slot()
		if slot_id == -1:
			break

		var slot: Dictionary = slots[slot_id]
		var need: float = float(slot["max_energy"]) - float(slot["energy"])
		var added: float = min(remaining, need)
		slot["energy"] = float(slot["energy"]) + added
		remaining -= added
		slots[slot_id] = slot
		_emit_slot_progress(slot_id)

		if float(slot["energy"]) >= float(slot["max_energy"]):
			_complete_hatch(slot_id)
			_assign_next_empty_slots()

func apply_save(data: Dictionary) -> void:
	slots = Array(data.get("slots", []))
	cats.clear()
	for cat_data in Array(data.get("cats", [])):
		if cat_data is CatData:
			cats.append(cat_data)
		elif cat_data is Dictionary:
			cats.append(CatData.deserialize(cat_data))
	hatched_count = max(int(data.get("hatched_count", cats.size())), cats.size())
	_ensure_slots()
	_update_unlocks()
	_assign_next_empty_slots()
	_emit_all_progress()

func get_slots() -> Array:
	return slots.duplicate(true)

func get_cats() -> Array:
	return cats.duplicate(true)

func get_hatched_count() -> int:
	return hatched_count

func get_save_data() -> Dictionary:
	return {
		"slots": slots.duplicate(true),
		"cats": cats.duplicate(true),
		"hatched_count": hatched_count,
	}

func get_unlocked_species() -> Array:
	var total: float = _get_total_energy_produced()
	var species: Array = [CatData.BREED_ORANGE]
	for cat in cats:
		var cat_species: String = CatData.BREED_ORANGE
		if cat is CatData:
			cat_species = String(cat.species)
		elif cat is Dictionary:
			cat_species = String(cat.get("species", CatData.BREED_ORANGE))
		if not species.has(cat_species):
			species.append(cat_species)
	if total >= 15000.0 and not species.has(CatData.BREED_BRITISH):
		species.append(CatData.BREED_BRITISH)
	if total >= 30000.0 and not species.has(CatData.BREED_SIAMESE):
		species.append(CatData.BREED_SIAMESE)
	return species

func _on_steps_updated(delta: int, _total: int) -> void:
	if EnergyEngine == null:
		return
	var produced: float = EnergyEngine.process_steps(delta)
	if produced > 0.0:
		feed_energy(produced)
		if SaveManager:
			SaveManager.save_all()

func _ensure_slots() -> void:
	while slots.size() < SLOT_COUNT:
		var index: int = slots.size()
		slots.append({
			"id": index,
			"unlocked": index == 0,
			"status": "empty" if index == 0 else "locked",
			"energy": 0.0,
			"max_energy": 0.0,
			"species": "",
		})

	if slots.size() > SLOT_COUNT:
		slots.resize(SLOT_COUNT)

	for i in range(SLOT_COUNT):
		var slot: Dictionary = Dictionary(slots[i])
		slot["id"] = i
		slot["unlocked"] = bool(slot.get("unlocked", i == 0))
		slot["status"] = String(slot.get("status", "empty" if i == 0 else "locked"))
		slot["energy"] = float(slot.get("energy", 0.0))
		slot["max_energy"] = float(slot.get("max_energy", 0.0))
		slot["species"] = String(slot.get("species", ""))
		slots[i] = slot

func _update_unlocks() -> void:
	for i in range(SLOT_COUNT):
		var slot: Dictionary = slots[i]
		var unlocked: bool = hatched_count >= int(SLOT_UNLOCK_HATCH_COUNTS[i])
		slot["unlocked"] = unlocked
		if not unlocked:
			slot["status"] = "locked"
			slot["energy"] = 0.0
			slot["max_energy"] = 0.0
			slot["species"] = ""
		elif String(slot.get("status", "locked")) == "locked":
			slot["status"] = "empty"
		slots[i] = slot

func _assign_next_empty_slots() -> void:
	for i in range(SLOT_COUNT):
		var slot: Dictionary = slots[i]
		if bool(slot.get("unlocked", false)) and String(slot.get("status", "")) == "empty":
			var species: String = _roll_next_species()
			slot["status"] = "filling"
			slot["energy"] = 0.0
			slot["max_energy"] = float(CatData.get_hatch_cost(species))
			slot["species"] = species
			slots[i] = slot
			hatch_started.emit(i)
			_emit_slot_progress(i)

func _get_active_filling_slot() -> int:
	for i in range(SLOT_COUNT):
		var slot: Dictionary = slots[i]
		if bool(slot.get("unlocked", false)) and String(slot.get("status", "")) == "filling":
			return i
	return -1

func _complete_hatch(slot_id: int) -> void:
	if slot_id < 0 or slot_id >= slots.size():
		return

	var slot: Dictionary = slots[slot_id]
	var species: String = String(slot.get("species", CatData.BREED_ORANGE))
	var rarity: String = _roll_rarity()
	hatched_count += 1
	var cat = CatData.create("cat_%d" % hatched_count, species, rarity, hatched_count)
	cats.append(cat)

	slot["status"] = "empty"
	slot["energy"] = 0.0
	slot["max_energy"] = 0.0
	slot["species"] = ""
	slots[slot_id] = slot

	_update_unlocks()
	hatch_complete.emit(cat)

func _roll_next_species() -> String:
	var species: Array = get_unlocked_species()
	if hatched_count == 0:
		return CatData.BREED_ORANGE
	return String(species[rng.randi_range(0, species.size() - 1)])

func _roll_rarity() -> String:
	var roll: int = rng.randi_range(0, 99)
	if roll <= 67:
		return CatData.RARITY_COMMON
	if roll <= 91:
		return CatData.RARITY_RARE
	if roll <= 98:
		return CatData.RARITY_EPIC
	return CatData.RARITY_LEGENDARY

func _get_total_energy_produced() -> float:
	if EnergyEngine:
		return EnergyEngine.total_energy_produced
	return 0.0

func _emit_slot_progress(slot_id: int) -> void:
	if slot_id < 0 or slot_id >= slots.size():
		return
	var slot: Dictionary = slots[slot_id]
	var max_energy: float = float(slot.get("max_energy", 0.0))
	var progress: float = 0.0
	if max_energy > 0.0:
		progress = clamp(float(slot.get("energy", 0.0)) / max_energy, 0.0, 1.0)
	hatch_progress.emit(slot_id, progress)

func _emit_all_progress() -> void:
	for i in range(slots.size()):
		_emit_slot_progress(i)
