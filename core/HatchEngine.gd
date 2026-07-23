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
# P1 孵化成本成长曲线：累计已落蛋数（含教学蛋），决定下一颗蛋的成本档位。
# 旧档缺省时以 hatched_count + 当前在孵/待收槽数兜底回填。
var eggs_assigned_total: int = 0
# 稀有度保底（两层独立计数）：epic 连续40次未出必出，legendary 连续120次未出必出
const EPIC_PITY := 40
const LEGENDARY_PITY := 120
var epic_pity_count: int = 0
var legendary_pity_count: int = 0
# N12 羁绊转化（v3.3 已签署）：Lv10 后携带经验 1000:1 转羁绊点，日上限+5，
# 总量封顶（星级阈值[待定]，演出接 v1.1）。日计数随本地日期重置。
const BOND_EXP_PER_POINT := 1000
const BOND_DAILY_CAP := 5
const BOND_TOTAL_CAP := 300
var bond_gained_today: int = 0
var bond_date: String = ""
var rng := RandomNumberGenerator.new()
var _fill_timer: Timer  # 填蛋定时兜底（步数静止时池能量也能流进蛋）
var _assign_timer: Timer  # 0.5s 自动落蛋延迟（检测到空槽后延迟装填）

func _get_max_capacity() -> int:
	if PackageSystem:
		return PackageSystem.get_max_capacity()
	return 24

var has_tutorial_first_egg: bool = false  # 是否已触发新手首蛋
var current_companion_cat_id: String = ""
var garden_expand_purchased: bool = false

# GDD §2.6: 设置携带猫，继承当日步数经验
func set_companion_cat_id(cat_id: String) -> void:
	# A3 状态矩阵：外出探索中的猫不可设为携带（叙事底线：不能同时陪走+进城）
	if CatStateGuard and cat_id != "" and not CatStateGuard.is_allowed(CatStateGuard.Action.SET_COMPANION, cat_id):
		return
	current_companion_cat_id = cat_id
	_recalc_companion_exp()
	if SaveManager:
		SaveManager.save_all()

# 看广告加速 → P1 改「今日步行加成」（广告步行放大器，总案 §2.4）：
# 单次 = min(3000, 0.3 × 当日步数能量)，每日 3 次；<1000 步 UI 置灰。
# 广告从"替代走路"变为"放大走路"，占比结构性 ≤47.4%（A3）。
const AD_SPEEDUP_ENERGY := 3000.0
const AD_SPEEDUP_COEFFICIENT := 0.3
const AD_SPEEDUP_DAILY_LIMIT := 3
const AD_MIN_STEPS_FOR_BUTTON := 1000
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
	hatch_complete.connect(_on_hatch_complete)
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

func reduce_hatch_time(factor: float) -> bool:
	var slot_id: int = _get_active_filling_slot()
	if slot_id == -1:
		return false
	var slot: Dictionary = slots[slot_id]
	var remaining: float = float(slot["max_energy"]) - float(slot["energy"])
	var energy_to_add: float = remaining * (1.0 - factor)
	slot["energy"] = float(slot["energy"]) + energy_to_add
	if float(slot["energy"]) >= float(slot["max_energy"]):
		slot["status"] = "ready"
	slots[slot_id] = slot
	_emit_slot_progress(slot_id)
	if String(slot.get("status", "")) == "ready":
		_assign_next_empty_slots()
	return true

func _force_hatch_complete() -> Variant:
	var slot_id: int = _get_active_filling_slot()
	if slot_id == -1:
		return null
	return _complete_hatch(slot_id)

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

# 当前单次广告加成值（随当日已产步数能量实时变化，供按钮显值与结算共用）。
func get_ad_speedup_energy() -> float:
	var today_energy: float = EnergyEngine.today_energy if EnergyEngine else 0.0
	return minf(AD_SPEEDUP_ENERGY, AD_SPEEDUP_COEFFICIENT * today_energy)

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
	if cats.size() >= _get_max_capacity():
		print("[HatchEngine] Backpack full, cannot collect ready slot ", slot_id)
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
	eggs_assigned_total = int(data.get("eggs_assigned_total", -1))
	epic_pity_count = max(int(data.get("epic_pity_count", 0)), 0)
	legendary_pity_count = max(int(data.get("legendary_pity_count", 0)), 0)
	ad_speedup_count = max(int(data.get("ad_speedup_count", 0)), 0)
	ad_speedup_date = String(data.get("ad_speedup_date", ""))
	bond_gained_today = max(int(data.get("bond_gained_today", 0)), 0)
	bond_date = String(data.get("bond_date", ""))
	has_tutorial_first_egg = bool(data.get("has_tutorial_first_egg", false))
	current_companion_cat_id = String(data.get("current_companion_cat_id", ""))
	garden_expand_purchased = bool(data.get("garden_expand_purchased", false))
	# 旧档 manual_workshop_override 字段读入即弃（C1 工坊态已移除）
	_ensure_slots()
	if eggs_assigned_total < 0:
		# 旧档兜底：已孵数 + 当前占用中的蛋槽数
		var occupied: int = 0
		for slot in slots:
			var status := String(Dictionary(slot).get("status", ""))
			if status == "incubating" or status == "ready":
				occupied += 1
		eggs_assigned_total = hatched_count + occupied
	_update_unlocks()
	_assign_next_empty_slots()
	_emit_all_progress()

func get_slots() -> Array:
	return slots.duplicate(true)

func get_cats() -> Array:
	return cats.duplicate(true)

func get_hatched_count() -> int:
	return hatched_count

# 送养移除猫咪（T4-11）
# 返回 true 表示移除成功
func remove_cat(cat_id: String) -> bool:
	var idx := -1
	for i in range(cats.size()):
		var c = cats[i]
		var cid = c.id if c is CatData else (c.get("id", "") if c is Dictionary else "")
		if cid == cat_id:
			idx = i
			break
	if idx == -1:
		return false
	# 不能移除最后一只猫
	if cats.size() <= 1:
		return false
	cats.remove_at(idx)
	# 如果移除了随行猫，自动切换到另一只
	if current_companion_cat_id == cat_id and cats.size() > 0:
		var new_companion = cats[0]
		current_companion_cat_id = new_companion.id if new_companion is CatData else (new_companion.get("id", "") if new_companion is Dictionary else "")
	_update_unlocks()
	return true

func get_cat_by_id(cat_id: String) -> Variant:
	for c in cats:
		var cid = c.id if c is CatData else (c.get("id", "") if c is Dictionary else "")
		if cid == cat_id:
			return c
	return null

func get_unique_species_count() -> int:
	var species_set := {}
	for c in cats:
		var s: String = ""
		if c is CatData:
			s = c.species
		elif c is Dictionary:
			s = String(c.get("species", ""))
		if s != "":
			species_set[s] = true
	return species_set.size()

func get_save_data() -> Dictionary:
	return {
		"slots": slots.duplicate(true),
		"cats": cats.duplicate(true),
		"hatched_count": hatched_count,
		"eggs_assigned_total": eggs_assigned_total,
		"bond_gained_today": bond_gained_today,
		"bond_date": bond_date,
		"epic_pity_count": epic_pity_count,
		"legendary_pity_count": legendary_pity_count,
		"ad_speedup_count": ad_speedup_count,
		"ad_speedup_date": ad_speedup_date,
		"has_tutorial_first_egg": has_tutorial_first_egg,
		"current_companion_cat_id": current_companion_cat_id,
		"garden_expand_purchased": garden_expand_purchased,
	}

func get_unlocked_species() -> Array:
	if BreedUnlockEngine:
		return BreedUnlockEngine.get_unlocked_breeds()
	return [CatData.BREED_ORANGE]

func _recalc_companion_exp() -> void:
	# GDD §2.6: 当日完整步数 × 品种系数
	if current_companion_cat_id == "" or StepEngine == null:
		return
	var today_steps: int = StepEngine.get_today_steps()
	if today_steps <= 0:
		return
	var companion = null
	for c in cats:
		var cid: String = ""
		if typeof(c) == TYPE_DICTIONARY:
			cid = String(c.get("id", ""))
		elif c != null and "id" in c:
			cid = String(c.id)
		if cid == current_companion_cat_id:
			companion = c
			break
	if companion == null:
		return
	var species: String = ""
	if typeof(companion) == TYPE_DICTIONARY:
		species = String(companion.get("species", "orange"))
	elif companion != null and "species" in companion:
		species = String(companion.species)
	var multiplier: float = LevelSystem.get_breed_multiplier(species)
	# P1 软拐点：切换携带猫时按当日累计步数的拐点曲线继承（封顶满级）
	var new_exp: int = mini(LevelSystem.calc_daily_exp(today_steps, multiplier), LevelSystem.MAX_EXP)
	var old_exp: int = 0
	if typeof(companion) == TYPE_DICTIONARY:
		old_exp = int(companion.get("exp", 0))
	elif companion != null and "exp" in companion:
		old_exp = int(companion.exp)
	if new_exp > old_exp:
		var old_level: int = LevelSystem.get_level(old_exp)
		var new_level: int = LevelSystem.get_level(new_exp)
		if typeof(companion) == TYPE_DICTIONARY:
			companion["exp"] = new_exp
			companion["level"] = new_level
		else:
			companion.exp = new_exp
			companion.level = new_level
		if new_level > old_level and EventBus:
			EventBus.emit_level_up(current_companion_cat_id, old_level, new_level)

# N12：满级溢出经验转羁绊点入账（companion 为 CatData 或 Dictionary）。
func _grant_bond_points(companion, overflow_exp: int) -> void:
	var today: String = _ad_today_key()
	if bond_date != today:
		bond_date = today
		bond_gained_today = 0
	var current: int = 0
	if companion is CatData:
		current = companion.bond_points
	elif companion is Dictionary:
		current = int(companion.get("bond_points", 0))
	var by_exp: int = int(floor(float(overflow_exp) / float(BOND_EXP_PER_POINT)))
	var gain: int = mini(by_exp, mini(BOND_DAILY_CAP - bond_gained_today, BOND_TOTAL_CAP - current))
	if gain <= 0:
		return
	bond_gained_today += gain
	if companion is CatData:
		companion.bond_points = current + gain
	elif companion is Dictionary:
		companion["bond_points"] = current + gain

func _on_steps_updated(delta: int, _total: int) -> void:
	if EnergyEngine == null:
		return
	# 步数 → 能量，存进主池（process_steps 内部已完成）
	var produced: float = EnergyEngine.process_steps(delta)
	# 孵化从主池扣能量（不再用 produced 重复喂蛋）。
	# 此处保留同帧填蛋（走路时即时响应）；_fill_timer 每 0.2s 兜底
	# 覆盖步数静止的场景。函数幂等，双触发无害。
	_fill_slots_from_pool()
	var companion_exp_changed := false
	if delta > 0 and current_companion_cat_id != "":
		var companion = get_cat_by_id(current_companion_cat_id)
		if companion != null:
			var can_apply_exp := false
			var species := ""
			var old_exp := 0
			var old_level := 1
			if companion is CatData:
				can_apply_exp = true
				species = companion.species
				old_exp = companion.exp
				old_level = companion.level
			elif companion is Dictionary:
				can_apply_exp = true
				species = String(companion.get("species", ""))
				old_exp = int(companion.get("exp", 0))
				old_level = int(companion.get("level", 1))

			# P1 软拐点必须按「当日累计的边际值」结算，不能对 delta 直接套拐点
			var exp_gain: int = 0
			if LevelSystem and StepEngine:
				var today_total: int = StepEngine.get_today_steps()
				var prev_total: int = max(today_total - delta, 0)
				var mult: float = LevelSystem.get_breed_multiplier(species)
				exp_gain = LevelSystem.calc_daily_exp(today_total, mult) - LevelSystem.calc_daily_exp(prev_total, mult)
			if can_apply_exp and exp_gain > 0:
				var new_exp: int = min(old_exp + exp_gain, LevelSystem.MAX_EXP)
				# N12：满级后的溢出经验 1000:1 转羁绊点
				var overflow_exp: int = max(old_exp + exp_gain - LevelSystem.MAX_EXP, 0)
				if overflow_exp > 0:
					_grant_bond_points(companion, overflow_exp)
				var new_level: int = LevelSystem.get_level(new_exp)
				if new_exp != old_exp or new_level != old_level:
					companion_exp_changed = true
					if companion is CatData:
						companion.exp = new_exp
						companion.level = new_level
					elif companion is Dictionary:
						companion["exp"] = new_exp
						companion["level"] = new_level
					if new_level > old_level and EventBus:
						EventBus.emit_level_up(current_companion_cat_id, old_level, new_level)
	if (produced > 0.0 or companion_exp_changed) and SaveManager:
		SaveManager.save_all()

# 把主能量池里的能量灌进正在孵化的蛋：
# 只在池能"完整孵化一颗蛋"时才扣，余额留在池里（避免清零，对齐 HUD 余量显示）。
func _fill_slots_from_pool() -> void:
	if EnergyEngine == null:
		return
	# 渐进灌注（设计决策 2026-06-12）：池里有多少灌多少，蛋随走路实时增长，
	# GDD §8.2 蛋壳 4 阶段渐进视觉得以生效。
	# C1（P2）：能量路由只剩一条——灌蛋 > 主池 > 截断。工坊改独立步数驱动，
	# 不再承接能量；池满截断由 EnergyEngine 温和提示（当日仅一次）。
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
	if BreedUnlockEngine:
		BreedUnlockEngine.record_hatch(species)

	slot["status"] = "empty"
	slot["energy"] = 0.0
	slot["max_energy"] = 0.0
	slot["species"] = ""
	slots[slot_id] = slot

	_update_unlocks()
	hatch_complete.emit(cat)
	return cat

func _roll_next_species() -> String:
	if BreedUnlockEngine:
		return BreedUnlockEngine.determine_breed()
	return CatData.BREED_ORANGE

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

func _on_hatch_complete(_cat_data) -> void:
	if PackageSystem:
		PackageSystem.check_expansion(get_unique_species_count())

# 包满判定（B3 包满引导弹窗与池满提示分支共用）
func is_bag_full() -> bool:
	return cats.size() >= _get_max_capacity()

# ── C2 保底可视化（P3）：剩 0 = 下一颗必出 ──
func get_epic_pity_remaining() -> int:
	return max(EPIC_PITY - epic_pity_count, 0)

func get_legendary_pity_remaining() -> int:
	return max(LEGENDARY_PITY - legendary_pity_count, 0)

# ── GDD v2.17 0.5s 自动落蛋 + 新手首蛋 ──

func _do_assign_empty_slots() -> void:
	# 0.5s Timer 回调：执行实际的蛋装填
	if cats.size() >= _get_max_capacity():
		return
	for i in range(SLOT_COUNT):
		var slot: Dictionary = slots[i]
		if bool(slot.get("unlocked", false)) and String(slot.get("status", "")) == "empty":
			var species: String = _roll_next_species()
			# P1 成本曲线：按累计落蛋序号取档（教学蛋为 #1，此处从 #2 起）
			eggs_assigned_total += 1
			slot["status"] = "incubating"
			slot["energy"] = 0.0
			slot["max_energy"] = float(CatData.get_hatch_cost_for_egg(eggs_assigned_total))
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
	eggs_assigned_total = max(eggs_assigned_total, 1)  # 教学蛋 = 第 1 颗
	hatch_started.emit(0)
	_emit_slot_progress(0)
