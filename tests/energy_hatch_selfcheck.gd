extends Node

# P2 验收自检（launch_overhaul_master_plan / v2.2 §6.6）：
# 工坊步数礼盒 W-1/W-2/W-5/W-6、旧档迁移 H-9、包满锁蛋 H-1、
# 旧工坊态移除 H-8、池满提示当日仅一次 E-1。
# 运行：godot --headless res://tests/energy_hatch_selfcheck.tscn

const WorkshopS := preload("res://core/WorkshopManager.gd")
const HatchS := preload("res://core/HatchEngine.gd")
const EnergyS := preload("res://core/EnergyEngine.gd")

var _pass := 0
var _fail := 0


func _check(name: String, condition: bool, hint: String = "") -> void:
	if condition:
		_pass += 1
		print("  PASS: %s" % name)
	else:
		_fail += 1
		print("  FAIL: %s  %s" % [name, hint])


func _ready() -> void:
	_t_workshop_mint()
	_t_workshop_caps_and_carryover()
	_t_workshop_open_and_dupes()
	_t_workshop_migration()
	_t_bag_full_lock()
	_t_pool_full_once_per_day()
	_t_state_guard_matrix()
	_t_flower_hold_cap()
	_t_snack_channel()
	print("结果: %d 通过 / %d 失败" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


# A3 状态矩阵（P4）：携带×派遣/送养互斥、外出×携带互斥
func _t_state_guard_matrix() -> void:
	print("-- A3 状态矩阵 --")
	if CatStateGuard == null or HatchEngine == null:
		_check("CatStateGuard 可用", false)
		return
	var saved_companion: String = HatchEngine.current_companion_cat_id
	HatchEngine.current_companion_cat_id = "guard_test_cat"
	_check("携带中不可派遣", not CatStateGuard.is_allowed(CatStateGuard.Action.DISPATCH, "guard_test_cat"))
	_check("携带中不可送养", not CatStateGuard.is_allowed(CatStateGuard.Action.RELINQUISH, "guard_test_cat"))
	_check("非携带猫可派遣", CatStateGuard.is_allowed(CatStateGuard.Action.DISPATCH, "other_cat"))
	HatchEngine.current_companion_cat_id = saved_companion
	# 外出中不可设为携带（借 ExploreEngine 静态表构造外出态）
	var ExploreS := preload("res://core/ExploreEngine.gd")
	ExploreS._explorers["guard_explore_cat"] = {"departure_time": 0.0, "return_time": 9e18, "duration_hours": 1, "is_exploring": true}
	_check("外出中不可设携带", not CatStateGuard.is_allowed(CatStateGuard.Action.SET_COMPANION, "guard_explore_cat"))
	var before: String = HatchEngine.current_companion_cat_id
	HatchEngine.set_companion_cat_id("guard_explore_cat")
	_check("set_companion 被守卫拦截", HatchEngine.current_companion_cat_id == before)
	_check("外出中不可喂零食", not CatStateGuard.is_allowed(CatStateGuard.Action.FEED_SNACK, "guard_explore_cat"))
	ExploreS._explorers.erase("guard_explore_cat")


# C3 花卉持有上限：每种 5，超限折 10 花瓣
func _t_flower_hold_cap() -> void:
	print("-- C3 花卉持有上限 --")
	if GiftInventory == null:
		_check("GiftInventory 可用", false)
		return
	var WorkshopS2 := preload("res://core/WorkshopManager.gd")
	var wm = WorkshopS2.new()
	while GiftInventory.get_count("flower_daisy") < WorkshopS2.FLOWER_HOLD_CAP:
		GiftInventory.add_gift("flower_daisy")
	var petals: int = wm._grant_gift("flower_daisy")
	_check("满 5 株后折 10 花瓣", petals == WorkshopS2.FLOWER_OVERFLOW_PETALS, "got %d" % petals)
	_check("持有数不再增长", GiftInventory.get_count("flower_daisy") == WorkshopS2.FLOWER_HOLD_CAP)
	var dupe: int = wm._grant_gift("deco_scarf")
	_check("配饰重复仍按稀有度折算", dupe == 10, "got %d" % dupe)
	wm.free()


# C2 零食统一通道：日 ≤3/猫、annoyed 期间可喂（不计打扰）
func _t_snack_channel() -> void:
	print("-- C2 零食通道 --")
	if InteractionSystem == null:
		_check("InteractionSystem 可用", false)
		return
	var cat := "snack_test_cat"
	for i in range(3):
		var r: Dictionary = InteractionSystem.feed_snack(cat, "fish_treat")
		_check("第 %d 次投喂成功" % (i + 1), bool(r.get("success", false)))
	var r4: Dictionary = InteractionSystem.feed_snack(cat, "cat_can")
	_check("第 4 次被日限拦截", not bool(r4.get("success", true)))
	# annoyed 期间零食仍可喂（道歉零食）
	var annoyed_cat := "snack_annoyed_cat"
	for i in range(6):
		EmotionStateMachine.register_interaction(annoyed_cat)
	_check("前置：猫已 annoyed", EmotionStateMachine.is_annoyed(annoyed_cat))
	var ra: Dictionary = InteractionSystem.feed_snack(annoyed_cat, "cat_can")
	_check("annoyed 期间零食可喂", bool(ra.get("success", false)))
	EmotionStateMachine.reset_cat(annoyed_cat)


# W-1: 每 3000 原始步产一盒，独立计数不经能量池
func _t_workshop_mint() -> void:
	print("-- W-1 铸盒节奏 --")
	var wm = WorkshopS.new()
	wm._on_steps_updated(2999, 0)
	_check("2999 步不出盒", wm.get_unopened_count() == 0)
	wm._on_steps_updated(1, 0)
	_check("满 3000 步出 1 盒", wm.get_unopened_count() == 1)
	_check("计数器归零", wm.box_step_counter == 0)
	wm.free()


# W-2 日上限 3 / W-5 未开上限 5 + 计数照走
func _t_workshop_caps_and_carryover() -> void:
	print("-- W-2/W-5 上限与结转 --")
	var wm = WorkshopS.new()
	wm._on_steps_updated(12000, 0)
	_check("W-2 日上限 3 盒", wm.get_unopened_count() == 3, "got %d" % wm.get_unopened_count())
	_check("超出部分计数照走", wm.box_step_counter == 3000, "got %d" % wm.box_step_counter)
	# 模拟跨天：日期置旧触发跨天重置后继续铸
	wm.boxes_date = "1970-01-01"
	wm._on_steps_updated(9000, 0)
	_check("W-5 未开上限 5 盒", wm.get_unopened_count() == 5, "got %d" % wm.get_unopened_count())
	_check("达上限计数继续累计", wm.box_step_counter >= 3000, "got %d" % wm.box_step_counter)
	wm.free()


# W-6: 拆盒 → 配饰重复折花瓣、花卉不折；拆盒后补铸
func _t_workshop_open_and_dupes() -> void:
	print("-- W-6 拆盒与重复折算 --")
	if GiftInventory == null or WorkshopData == null:
		_check("依赖单例可用", false, "GiftInventory/WorkshopData 缺失")
		return
	# 预填全部 16 件配饰 → 任何配饰产出必为重复
	for gift_id in WorkshopData.get_gift_ids_by_category("deco"):
		if GiftInventory.get_count(gift_id) == 0:
			GiftInventory.add_gift(gift_id)
	var wm = WorkshopS.new()
	wm.unopened_boxes = 5
	var opened := 0
	while wm.unopened_boxes > 0:
		var result: Dictionary = wm.open_box()
		if not bool(result.get("success", false)):
			break
		opened += 1
		var gift: Dictionary = WorkshopData.get_gift_data(String(result.get("gift_id", "")))
		var category := String(gift.get("category", ""))
		var petals := int(result.get("dupe_petals", 0))
		if category == "deco":
			_check("配饰重复折花瓣>0 (%s)" % gift.get("id"), petals > 0)
			var expected := int(WorkshopS.DUPE_PETALS.get(String(gift.get("rarity", "")), -1))
			_check("折算值按稀有度表", petals == expected, "%d vs %d" % [petals, expected])
		else:
			_check("花卉不折算 (%s)" % gift.get("id"), petals == 0)
	_check("5 盒全部可拆", opened == 5, "opened=%d" % opened)
	wm.free()


# H-9: 旧档槽位能量迁移 ⌊Σ/3000⌋ 折盒 + 余量折计数器；box_ready 即一盒
func _t_workshop_migration() -> void:
	print("-- H-9 旧档迁移 --")
	var wm = WorkshopS.new()
	wm.apply_save({"slots": [
		{"index": 0, "status": "filling", "energy": 4500.0, "gift_id": ""},
		{"index": 1, "status": "box_ready", "energy": 3000.0, "gift_id": ""},
		{"index": 2, "status": "filling", "energy": 2000.0, "gift_id": ""},
	]})
	_check("6500 能量+1 ready → 3 盒", wm.get_unopened_count() == 3, "got %d" % wm.get_unopened_count())
	_check("余量 500 入计数器", wm.box_step_counter == 500, "got %d" % wm.box_step_counter)
	var wm2 = WorkshopS.new()
	wm2.apply_save({"box_step_counter": 1200, "unopened_boxes": 2, "boxes_today": 1, "boxes_date": ""})
	_check("新档字段正常读取", wm2.box_step_counter == 1200 and wm2.get_unopened_count() == 2)
	wm.free()
	wm2.free()


# H-1: 包满时 collect 返回 null、蛋保持 ready；H-8: 旧 API 不存在
func _t_bag_full_lock() -> void:
	print("-- H-1/H-8 包满锁蛋 --")
	var he = HatchS.new()
	he._ensure_slots()
	var cats: Array = []
	for i in range(24):
		cats.append({"id": "dummy_%d" % i, "species": "orange", "exp": 0, "level": 1})
	he.cats = cats
	he.slots[0]["unlocked"] = true
	he.slots[0]["status"] = "ready"
	he.slots[0]["energy"] = 4250.0
	he.slots[0]["max_energy"] = 4250.0
	he.slots[0]["species"] = "orange"
	var result = he.collect_ready_slot(0)
	_check("H-1 包满 collect 返回 null", result == null)
	_check("H-1 蛋保持 ready", String(he.slots[0].get("status", "")) == "ready")
	_check("H-1 is_bag_full", he.is_bag_full())
	_check("H-8 is_workshop_mode 已移除", not he.has_method("is_workshop_mode"))
	_check("H-8 toggle_workshop_override 已移除", not he.has_method("toggle_workshop_override"))
	he.free()


# E-1: 池满提示每自然日仅第一次
func _t_pool_full_once_per_day() -> void:
	print("-- E-1 池满提示当日仅一次 --")
	var ee = EnergyS.new()
	ee.last_energy_date = ee._today_key()
	var fired: Array = []
	ee.pool_became_full.connect(func() -> void: fired.append(true))
	ee.energy_pool = EnergyS.MAX_ENERGY_POOL
	ee.add_pool_with_overflow(100.0)
	_check("首次溢出发信号", fired.size() == 1, "fired=%d" % fired.size())
	ee.add_pool_with_overflow(100.0)
	_check("同日再溢不重复发", fired.size() == 1, "fired=%d" % fired.size())
	ee.pool_full_toast_date = "1970-01-01"
	ee.add_pool_with_overflow(100.0)
	_check("跨天后重新发", fired.size() == 2, "fired=%d" % fired.size())
	ee.free()
