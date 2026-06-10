extends Node

signal hatch_started(slot: int)
signal hatch_progress(slot: int, progress: float)
signal hatch_complete(cat_data)

const CatData := preload("res://core/CatData.gd")
const SLOT_COUNT := 4
const SLOT_UNLOCK_HATCH_COUNTS := [0, 1, 3, 10]

var slots: Array = []
var cats: Array = []
var hatched_count: int = 0
# 稀有度保底（两层独立计数）：epic 连续40次未出必出，legendary 连续120次未出必出
const EPIC_PITY := 40
const LEGENDARY_PITY := 120
var epic_pity_count: int = 0
var legendary_pity_count: int = 0
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

		# 满能量 → ready 态（震动+发光，等玩家点击孵化），不自动完成。
		# slot 变 ready 后不再是 incubating，循环会让能量继续流向下一槽（串行填充）。
		if float(slot["energy"]) >= float(slot["max_energy"]):
			slot["status"] = "ready"
			slots[slot_id] = slot
			_emit_slot_progress(slot_id)

	_assign_next_empty_slots()

# 玩家点击 ready 蛋时调用：完成孵化、生成猫、发出 hatch_complete（触发演出）。
# 返回孵出的 CatData；非 ready 槽返回 null。
func collect_ready_slot(slot_id: int):
	if slot_id < 0 or slot_id >= slots.size():
		return null
	var slot: Dictionary = slots[slot_id]
	if String(slot.get("status", "")) != "ready":
		return null
	var cat = _complete_hatch(slot_id)
	_assign_next_empty_slots()
	return cat

func apply_save(data: Dictionary) -> void:
	slots = Array(data.get("slots", []))
	cats.clear()
	for cat_data in Array(data.get("cats", [])):
		if cat_data is CatData:
			cats.append(cat_data)
		elif cat_data is Dictionary:
			cats.append(CatData.deserialize(cat_data))
	hatched_count = max(int(data.get("hatched_count", cats.size())), cats.size())
	epic_pity_count = max(int(data.get("epic_pity_count", 0)), 0)
	legendary_pity_count = max(int(data.get("legendary_pity_count", 0)), 0)
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
		"epic_pity_count": epic_pity_count,
		"legendary_pity_count": legendary_pity_count,
	}

func get_unlocked_species() -> Array:
	var total: float = _get_total_energy_produced()
	var species: Array = [CatData.BREED_ORANGE]
	if total >= 15000.0:
		species.append(CatData.BREED_BRITISH)
	if total >= 30000.0:
		species.append(CatData.BREED_SIAMESE)
	return species

func _on_steps_updated(delta: int, _total: int) -> void:
	if EnergyEngine == null:
		return
	# 步数 → 能量，存进 pool/reserve（process_steps 内部已完成）
	var produced: float = EnergyEngine.process_steps(delta)
	# 孵化从主池扣能量（不再用 produced 重复喂蛋）
	_fill_slots_from_pool()
	if produced > 0.0 and SaveManager:
		SaveManager.save_all()

# 把主能量池里的能量灌进正在孵化的蛋：
# 只在池能"完整孵化一颗蛋"时才扣，余额留在池里（避免清零，对齐 HUD 余量显示）。
func _fill_slots_from_pool() -> void:
	if EnergyEngine == null:
		return
	while true:
		var slot_id: int = _get_active_filling_slot()
		if slot_id == -1:
			break
		var slot: Dictionary = slots[slot_id]
		var need: float = float(slot["max_energy"]) - float(slot["energy"])
		if need <= 0.0:
			break
		if EnergyEngine.energy_pool < need:
			break
		EnergyEngine.spend_pool(need)
		feed_energy(need)

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
			slot["status"] = "incubating"
			slot["energy"] = 0.0
			slot["max_energy"] = float(CatData.get_hatch_cost(species))
			slot["species"] = species
			slots[i] = slot
			hatch_started.emit(i)
			_emit_slot_progress(i)

func _get_active_filling_slot() -> int:
	# 串行填充：始终优先填最低索引的 incubating 槽（GDD §2.2）
	for i in range(SLOT_COUNT):
		var slot: Dictionary = slots[i]
		if bool(slot.get("unlocked", false)) and String(slot.get("status", "")) == "incubating":
			return i
	return -1

func _complete_hatch(slot_id: int):
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
	return cat

func _roll_next_species() -> String:
	var species: Array = get_unlocked_species()
	if hatched_count == 0:
		return CatData.BREED_ORANGE
	return String(species[rng.randi_range(0, species.size() - 1)])

func _roll_rarity() -> String:
	var result: String = _base_roll_rarity()

	# 应用保底：已连续 miss 达阈值则强制（legendary 优先级更高，先判）
	if legendary_pity_count >= LEGENDARY_PITY:
		result = CatData.RARITY_LEGENDARY
	elif epic_pity_count >= EPIC_PITY and _rarity_rank(result) < _rarity_rank(CatData.RARITY_EPIC):
		result = CatData.RARITY_EPIC

	_update_pity_counters(result)
	return result

func _base_roll_rarity() -> String:
	var roll: int = rng.randi_range(0, 99)
	if roll <= 67:
		return CatData.RARITY_COMMON
	if roll <= 91:
		return CatData.RARITY_RARE
	if roll <= 98:
		return CatData.RARITY_EPIC
	return CatData.RARITY_LEGENDARY

func _update_pity_counters(result: String) -> void:
	# legendary 计数：只有出 legendary 才归零，否则 +1
	if result == CatData.RARITY_LEGENDARY:
		legendary_pity_count = 0
	else:
		legendary_pity_count += 1
	# epic 计数：出 epic 或 legendary 都归零，否则 +1
	if _rarity_rank(result) >= _rarity_rank(CatData.RARITY_EPIC):
		epic_pity_count = 0
	else:
		epic_pity_count += 1

func _rarity_rank(r: String) -> int:
	match r:
		CatData.RARITY_LEGENDARY:
			return 3
		CatData.RARITY_EPIC:
			return 2
		CatData.RARITY_RARE:
			return 1
		_:
			return 0

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
