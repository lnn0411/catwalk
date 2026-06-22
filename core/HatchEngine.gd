extends Node

signal hatch_started(slot: int)
signal hatch_progress(slot: int, progress: float)
signal hatch_complete(cat_data)
signal workshop_activated()
signal hatched_activated()

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
var _fill_timer: Timer  # 填蛋定时兜底（步数静止时池能量也能流进蛋）
var _assign_timer: Timer  # 0.5s 自动落蛋延迟（检测到空槽后延迟装填）
var _was_workshop_mode: bool = false  # 工坊/孵化态切换的去抖：仅在跨态时派发信号

# GDD v2.17：工坊态/孵化态双轨切换 + 能量溢出链
const WORKSHOP_CACHE_CAP := 3000.0
var workshop_cached_energy: float = 0.0   # 工坊态半满能量冻结缓存（切回孵化态保留不丢）
var surprise_box_ready: bool = false      # 惊喜礼盒是否 Ready（工坊缓存灌满触发）
var backpack_max_capacity: int = 24       # 当前猫包上限
var has_tutorial_first_egg: bool = false  # 是否已触发新手首蛋
var current_companion_cat_id: String = ""

# 看广告加速（GDD v2.14 §3.7/§12.2）：每次补 3000 能量（≈30分钟步行），每日 3 次。
# v1.0 纯客户端计数器，跨天按本地日期重置。
const AD_SPEEDUP_ENERGY := 3000.0
const AD_SPEEDUP_DAILY_LIMIT := 3
var ad_speedup_count: int = 0      # 今日已用次数
var ad_speedup_date: String = ""   # 上次使用日期（跨天重置）

func _ready() -> void:
	rng.randomize()
	_ensure_slots()
	_update_unlocks()
	# 自动落蛋定时（0.5s 一次性）：_assign_next_empty_slots 检测到空槽后延迟装填。
	_assign_timer = Timer.new()
	_assign_timer.wait_time = 0.5
	_assign_timer.one_shot = true
	_assign_timer.timeout.connect(_do_assign_empty_slots)
	add_child(_assign_timer)
	_was_workshop_mode = is_workshop_mode()
	_assign_next_empty_slots()
	if StepEngine and not StepEngine.steps_updated.is_connected(_on_steps_updated):
		StepEngine.steps_updated.connect(_on_steps_updated)
	# 填蛋定时兜底：_fill_slots_from_pool 原本只挂在步数信号上，
	# 步数不变时（坐着不动/计步器无新数据）池里的能量永远流不进蛋。
	# Timer 每 0.2s 兜底一次；函数自带早退守卫（无蛋/池不足即 break），开销可忽略。
	_fill_timer = Timer.new()
	_fill_timer.wait_time = 0.2
	_fill_timer.one_shot = false
	_fill_timer.timeout.connect(_fill_slots_from_pool)
	add_child(_fill_timer)
	_fill_timer.start()
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

# 是否存在正在填充的蛋（最低索引的 incubating 槽）。供注入/加速按钮判断。
func has_filling_egg() -> bool:
	return _get_active_filling_slot() != -1

# 定向给"当前正在填充的蛋"喂能量（GDD §S06：注入当前蛋）。
# 封顶到该蛋孵化所需为止，绝不溢出到其他蛋；满则置 ready。
# 返回实际喂入的能量，未用完的部分由调用方决定如何处理（不会自动流向下一个蛋）。
func feed_current_egg(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var slot_id: int = _get_active_filling_slot()
	if slot_id == -1:
		return 0.0
	var slot: Dictionary = slots[slot_id]
	var need: float = float(slot["max_energy"]) - float(slot["energy"])
	var added: float = min(amount, max(need, 0.0))
	if added <= 0.0:
		return 0.0
	slot["energy"] = float(slot["energy"]) + added
	slots[slot_id] = slot
	_emit_slot_progress(slot_id)
	if float(slot["energy"]) >= float(slot["max_energy"]):
		slot["status"] = "ready"
		slots[slot_id] = slot
		_emit_slot_progress(slot_id)
		_assign_next_empty_slots()
	return added

# ── 看广告加速：每日次数计数（纯客户端，跨天本地日期重置）──
func _ad_today_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]

func _check_ad_daily_reset() -> void:
	var today: String = _ad_today_key()
	if ad_speedup_date != today:
		ad_speedup_date = today
		ad_speedup_count = 0

func ad_speedup_remaining() -> int:
	_check_ad_daily_reset()
	return max(AD_SPEEDUP_DAILY_LIMIT - ad_speedup_count, 0)

func can_ad_speedup() -> bool:
	return ad_speedup_remaining() > 0

func consume_ad_speedup() -> void:
	_check_ad_daily_reset()
	ad_speedup_count += 1

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
	ad_speedup_count = max(int(data.get("ad_speedup_count", 0)), 0)
	ad_speedup_date = String(data.get("ad_speedup_date", ""))
	workshop_cached_energy = clamp(float(data.get("workshop_cached_energy", 0.0)), 0.0, WORKSHOP_CACHE_CAP)
	surprise_box_ready = bool(data.get("surprise_box_ready", false))
	backpack_max_capacity = max(int(data.get("backpack_max_capacity", backpack_max_capacity)), 1)
	has_tutorial_first_egg = bool(data.get("has_tutorial_first_egg", false))
	current_companion_cat_id = String(data.get("current_companion_cat_id", ""))
	_ensure_slots()
	_update_unlocks()
	_was_workshop_mode = is_workshop_mode()
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
		"ad_speedup_count": ad_speedup_count,
		"ad_speedup_date": ad_speedup_date,
		"workshop_cached_energy": workshop_cached_energy,
		"surprise_box_ready": surprise_box_ready,
		"backpack_max_capacity": backpack_max_capacity,
		"has_tutorial_first_egg": has_tutorial_first_egg,
		"current_companion_cat_id": current_companion_cat_id,
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
	# 孵化从主池扣能量（不再用 produced 重复喂蛋）。
	# 此处保留同帧填蛋（走路时即时响应）；_fill_timer 每 0.2s 兜底
	# 覆盖步数静止的场景。函数幂等，双触发无害。
	_fill_slots_from_pool()
	if produced > 0.0 and SaveManager:
		SaveManager.save_all()

# 把主能量池里的能量灌进正在孵化的蛋：
# 只在池能"完整孵化一颗蛋"时才扣，余额留在池里（避免清零，对齐 HUD 余量显示）。
func _fill_slots_from_pool() -> void:
	if EnergyEngine == null:
		return
	_update_mode()
	# 工坊态（背包已满且无蛋在孵）：能量转入工坊缓存，不再灌蛋（GDD v2.17 能量溢出链）。
	if is_workshop_mode():
		_fill_workshop_cache()
		return
	# 渐进灌注（设计决策 2026-06-12）：池里有多少灌多少，蛋随走路实时增长，
	# GDD §8.2 蛋壳 4 阶段渐进视觉得以生效。
	# 连带语义：有蛋在孵时主池常态趋近 0（能量都在蛋里干活）；
	# 蛋全 ready/无蛋可孵时能量才积在池里 → 池满溢出 → 备用槽充能。
	# 备用槽机制不变：只接池溢出、只手动注入。
	while true:
		var slot_id: int = _get_active_filling_slot()
		if slot_id == -1:
			break
		var slot: Dictionary = slots[slot_id]
		var need: float = float(slot["max_energy"]) - float(slot["energy"])
		if need <= 0.0:
			break
		var available: float = EnergyEngine.energy_pool
		if available <= 0.0:
			break
		var amount: float = minf(available, need)
		EnergyEngine.spend_pool(amount)
		feed_energy(amount)
		if amount < need:
			break  # 池已抽干、蛋未满 → 等下一轮产出/Timer

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

# ── GDD v2.17 工坊态/孵化态双轨切换 ──

func is_workshop_mode() -> bool:
	# 工坊态条件：猫包已满（cats.size() >= backpack_max_capacity）且无 incubating 槽
	return cats.size() >= backpack_max_capacity and _get_active_filling_slot() == -1

func _update_mode() -> void:
	var workshop_now: bool = is_workshop_mode()
	if workshop_now and not _was_workshop_mode:
		workshop_activated.emit()
	elif not workshop_now and _was_workshop_mode:
		hatched_activated.emit()
	_was_workshop_mode = workshop_now

# ── GDD v2.17 能量溢出链（工坊态）──

func _fill_workshop_cache() -> void:
	if EnergyEngine == null:
		return
	if surprise_box_ready:
		# 礼盒 Ready 未拆 → 溢出链：主池(15000) → 备用槽(6000) → 硬截断
		# 能量已在池中积累，不再流入工坊
		return
	var missing: float = WORKSHOP_CACHE_CAP - workshop_cached_energy
	if missing <= 0.0:
		return
	# 从主池取能量注入工坊缓存
	while missing > 0.0:
		var available: float = EnergyEngine.energy_pool
		if available <= 0.0:
			break
		var amount: float = minf(available, missing)
		EnergyEngine.spend_pool(amount)
		workshop_cached_energy += amount
		missing -= amount
	if workshop_cached_energy >= WORKSHOP_CACHE_CAP:
		workshop_cached_energy = WORKSHOP_CACHE_CAP
		surprise_box_ready = true

func is_energy_overflowing() -> bool:
	# 主池满 + 备用槽满 + 礼盒 Ready 未拆 → 硬截断预警
	return surprise_box_ready \
		and (EnergyEngine == null or EnergyEngine.energy_pool >= EnergyEngine.MAX_ENERGY_POOL) \
		and (EnergyEngine == null or EnergyEngine.reserve_tank >= EnergyEngine.MAX_RESERVE_TANK)

# ── GDD v2.17 0.5s 自动落蛋 + 新手首蛋 ──

func _do_assign_empty_slots() -> void:
	# 0.5s Timer 回调：执行实际的蛋装填
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

func _assign_next_empty_slots() -> void:
	if hatched_count == 0 and not has_tutorial_first_egg:
		_assign_tutorial_first_egg()
		return
	# 检测是否有空槽，有则启动 0.5s Timer
	var any_empty: bool = false
	for i in range(SLOT_COUNT):
		var slot: Dictionary = slots[i]
		if bool(slot.get("unlocked", false)) and String(slot.get("status", "")) == "empty":
			any_empty = true
			break
	if any_empty and _assign_timer.is_stopped():
		_assign_timer.start()

func _assign_tutorial_first_egg() -> void:
	# 新手首蛋：slot[0] 自动落入橘猫蛋，直接灌满 4250 能量 → Ready 态
	if slots.size() < 1:
		return
	var slot: Dictionary = slots[0]
	slot["status"] = "ready"
	slot["energy"] = float(CatData.HATCH_ENERGY_REQUIRED)
	slot["max_energy"] = float(CatData.HATCH_ENERGY_REQUIRED)
	slot["species"] = CatData.BREED_ORANGE
	slots[0] = slot
	has_tutorial_first_egg = true
	hatch_started.emit(0)
	_emit_slot_progress(0)
