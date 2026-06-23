extends Node
# ============================================================
# T4 全系列自检（深度版）—— 基于 2026-06-22 提交（T4-01 ~ T4-15）
#
# 与现有 tests/t4_self_check.gd（浅检：仅查文件/方法存在）互补：
# 本脚本额外做两件事——
#   1) 加载今天新增的每个脚本/场景 → 捕获“编译错误”类问题
#      （例如 20:26 那次 BottomNav.TABS NotFound 编译错误，浅检抓不到）。
#   2) 对各引擎跑真实行为断言（数值/逻辑），而非只看 has_method。
#
# 运行方式（headless，退出码=失败数，可接 CI）：
#   godot --headless res://tests/t4_full_self_check.tscn
#
# 注意：少数行为用例会以独立 dummy id 写入并在用例结束后 reset，
#   尽量不污染真实存档；建议在干净 profile 上跑最干净。
# ============================================================

const CatData := preload("res://core/CatData.gd")

var _pass := 0
var _fail := 0
var _fail_tags: Array[String] = []


func _ready() -> void:
	print("==================================================")
	print("  T4 全系列自检（深度版） 2026-06-22")
	print("==================================================")

	_section_compile_guard()   # 编译错误总闸（最高价值）
	_t4_01_naming_carry()
	_t4_02_tutorial()
	_t4_03_garden_zoom()
	_t4_04_cat_interact()
	_t4_05_annoyed()
	_t4_06_explore()
	_t4_07_hatch_show()
	_t4_08_shop()
	_t4_09_friends()
	_t4_10_workshop()
	_t4_11_relinquish()
	_t4_12_album_postcard()
	_t4_13_weather_time()
	_t4_14_cat_screen()
	_t4_15_breed_unlock()
	await _t4_16_companion_exp()
	_t4_17_common_no_petals()
	_t4_18_weekly_cap()

	_summary()


# ── 测试原语 ──────────────────────────────────────────────

func _ok(tag: String, msg: String) -> void:
	_pass += 1
	print("  [OK] %s — %s" % [tag, msg])

func _xx(tag: String, msg: String) -> void:
	_fail += 1
	_fail_tags.append(tag)
	print("  [XX] %s — %s" % [tag, msg])

func _check(tag: String, cond: bool, msg: String) -> void:
	if cond:
		_ok(tag, msg)
	else:
		_xx(tag, msg)

# 资源能否加载（.gd/.tscn/.gdshader）——load 失败=编译错误/缺失
func _loadable(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	return load(path) != null

func _check_load(tag: String, path: String) -> void:
	_check(tag, _loadable(path), "load %s" % path.get_file())

# 安全取 autoload 单例（不存在返回 null，不崩）
func _node(singleton_name: String) -> Node:
	return get_node_or_null("/root/" + singleton_name)

func _script_constants(path: String) -> Dictionary:
	var script: Script = load(path)
	if script != null and script.has_method("get_script_constant_map"):
		return script.get_script_constant_map()
	return {}

func _cat_id(cat: Variant) -> String:
	if cat is CatData:
		return cat.id
	if cat is Dictionary:
		return String(cat.get("id", ""))
	return ""

func _cat_species(cat: Variant) -> String:
	if cat is CatData:
		return cat.species
	if cat is Dictionary:
		return String(cat.get("species", ""))
	return CatData.BREED_ORANGE

func _cat_exp(cat: Variant) -> int:
	if cat is CatData:
		return cat.exp
	if cat is Dictionary:
		return int(cat.get("exp", 0))
	return 0

func _cat_level(cat: Variant) -> int:
	if cat is CatData:
		return cat.level
	if cat is Dictionary:
		return int(cat.get("level", 1))
	return 1

func _make_selfcheck_cat(cat_id: String, species: String, rarity: String, level: int = 1, exp: int = 0, friendship: int = 0) -> CatData:
	var cat: CatData = CatData.create(cat_id, species, rarity, 1)
	cat.level = level
	cat.exp = exp
	cat.friendship = friendship
	return cat


# ── 编译错误总闸：加载今天新增的全部脚本/场景 ──────────────

func _section_compile_guard() -> void:
	print("-- [编译总闸] 今天新增脚本/场景能否全部加载 --")
	var paths := [
		"res://autoload/cat_screen_manager.gd",
		"res://core/BreedUnlockEngine.gd",
		"res://core/GiftInventory.gd",
		"res://core/TutorialManager.gd",
		"res://core/WeatherTimeManager.gd",
		"res://core/WorkshopData.gd",
		"res://core/WorkshopManager.gd",
		"res://scenes/S07_CarryCatSelect.gd",
		"res://scenes/WorkshopPage.gd",
		"res://scenes/ui/AngrySymbol.gd",
		"res://scenes/ui/CatCard.gd",
		"res://scenes/ui/explore_confirm_dialog.gd",
		"res://scenes/ui/explore_duration_picker.gd",
		"res://scenes/ui/explore_return_animation.gd",
		"res://scenes/ui/postcard_reveal.gd",
		"res://scenes/ui/relinquish_confirm_dialog.gd",
		"res://scenes/ui/shop_confirm_dialog.gd",
		"res://shaders/weather_color_grade.gdshader",
		"res://ui/BoxOpenAnimation.gd",
		"res://ui/GiftInventoryGrid.gd",
		"res://ui/GiftItemView.gd",
		"res://ui/WorkshopSlotView.gd",
		# 今天被改动的关键场景脚本（捕获改坏的编译错误）
		"res://scenes/S04_GardenMain.gd",
		"res://scenes/S08_HatchShow.gd",
		"res://scenes/S10_Album.gd",
		"res://scenes/S10_CatDetail.gd",
		"res://scenes/S12_Shop.gd",
		"res://scenes/S13_Friends.gd",
		"res://core/HatchEngine.gd",
	]
	var bad := 0
	for p in paths:
		if not _loadable(p):
			bad += 1
			_xx("COMPILE", "无法加载 " + p)
	if bad == 0:
		_ok("COMPILE", "全部 %d 个脚本/场景加载通过（无编译错误）" % paths.size())


# ── T4-01 命名链 + S07 携带猫选择页 ──────────────────────

func _t4_01_naming_carry() -> void:
	print("-- T4-01 命名链 + S07 携带猫 --")
	_check_load("T4-01", "res://scenes/S07_CarryCatSelect.gd")
	# 命名链：HatchEngine 应能产出待命名猫
	_check("T4-01", HatchEngine.has_method("collect_ready_slot"), "孵化→命名链入口 collect_ready_slot 存在")


# ── T4-02 首次花园引导（五步）TutorialManager ─────────────

func _t4_02_tutorial() -> void:
	print("-- T4-02 新手引导 TutorialManager --")
	var tm := _node("TutorialManager")
	if tm == null:
		_xx("T4-02", "TutorialManager 未注册为 autoload")
		return
	_check("T4-02", tm.has_method("start") and tm.has_method("is_running") and tm.has_method("is_blocking_garden_input"), "核心 API 完整")
	# 五步枚举 OFF=-1 … DONE=5
	_check("T4-02", int(TutorialManager.Step.SCAN) == 0 and int(TutorialManager.Step.EXPLORE) == 4 and int(TutorialManager.Step.DONE) == 5, "Step 枚举（SCAN0…EXPLORE4…DONE5）")
	_check("T4-02", not tm.is_running(), "未启动时 is_running=false")


# ── T4-03 花园三级缩放 ───────────────────────────────────

func _t4_03_garden_zoom() -> void:
	print("-- T4-03 花园缩放 --")
	_check_load("T4-03", "res://scenes/S04_GardenMain.gd")


# ── T4-04 猫咪互动 CatCard ───────────────────────────────

func _t4_04_cat_interact() -> void:
	print("-- T4-04 猫咪互动 CatCard --")
	_check_load("T4-04", "res://scenes/ui/CatCard.gd")
	# 互动加好感/冷却仍由 InteractionSystem 提供
	_check("T4-04", InteractionSystem.has_method("do_interact"), "InteractionSystem.do_interact 存在")


# ── T4-05 annoyed 情绪状态机 ─────────────────────────────

func _t4_05_annoyed() -> void:
	print("-- T4-05 annoyed 情绪状态机 --")
	var esm := _node("EmotionStateMachine")
	if esm == null:
		_xx("T4-05", "EmotionStateMachine 未注册")
		return
	_check("T4-05", int(EmotionStateMachine.INTERACTION_THRESHOLD) == 4, "阈值=4（GDD：1h 内累计≥4 触发）")
	# 行为：dummy 猫连续注册到阈值 → 应进入 annoyed
	var cid := "selfcheck_emotion_dummy"
	EmotionStateMachine.reset_cat(cid)
	for i in range(int(EmotionStateMachine.INTERACTION_THRESHOLD)):
		EmotionStateMachine.register_interaction(cid)
	_check("T4-05", EmotionStateMachine.is_annoyed(cid), "连续 %d 次互动 → annoyed" % int(EmotionStateMachine.INTERACTION_THRESHOLD))
	EmotionStateMachine.reset_cat(cid)
	_check("T4-05", not EmotionStateMachine.is_annoyed(cid), "reset 后退出 annoyed")


# ── T4-06 探索派遣 ExploreEngine ─────────────────────────

func _t4_06_explore() -> void:
	print("-- T4-06 探索派遣 --")
	var ee := _node("ExploreEngine")
	if ee == null:
		_xx("T4-06", "ExploreEngine 未注册")
		return
	_check("T4-06", ExploreEngine.get_slot_count() == 2, "探索槽=2")
	_check("T4-06", ExploreEngine.VALID_DURATIONS == [1, 2, 4], "时长选项 1/2/4h")
	_check("T4-06", int(ExploreEngine.SLOT1_HATCH_REQ) == 5, "slot1 解锁=累计孵化5只")
	_check_load("T4-06", "res://scenes/ui/explore_duration_picker.gd")
	_check_load("T4-06", "res://scenes/ui/explore_return_animation.gd")


# ── T4-07 S08 孵化演出修复 ───────────────────────────────

func _t4_07_hatch_show() -> void:
	print("-- T4-07 孵化演出 --")
	_check_load("T4-07", "res://scenes/S08_HatchShow.gd")


# ── T4-08 商店页 + HatchEngine 新增 ──────────────────────

func _t4_08_shop() -> void:
	print("-- T4-08 商店页 --")
	_check_load("T4-08", "res://scenes/S12_Shop.gd")
	_check_load("T4-08", "res://scenes/ui/shop_confirm_dialog.gd")
	_check("T4-08", HatchEngine.has_method("reduce_hatch_time"), "reduce_hatch_time 存在（能量加速器）")
	_check("T4-08", HatchEngine.has_method("_force_hatch_complete"), "_force_hatch_complete 存在")
	_check("T4-08", "garden_expand_purchased" in HatchEngine, "garden_expand_purchased 字段持久化")


# ── T4-09 好友邀请页 ─────────────────────────────────────

func _t4_09_friends() -> void:
	print("-- T4-09 好友邀请页 --")
	_check_load("T4-09", "res://scenes/S13_Friends.gd")


# ── T4-10 爱意工坊 WorkshopData/Manager ──────────────────

func _t4_10_workshop() -> void:
	print("-- T4-10 爱意工坊 --")
	var wd := _node("WorkshopData")
	var wm := _node("WorkshopManager")
	_check("T4-10", wd != null and wm != null, "WorkshopData/Manager 已注册")
	if wd == null or wm == null:
		return
	_check("T4-10", int(WorkshopManager.MAX_SLOTS) == 3 and float(WorkshopManager.ENERGY_PER_SLOT) == 3000.0, "3槽 × 3000能量")
	# 礼物目录非空 + roll 命中目录
	var ids: Array = WorkshopData.get_all_gift_ids()
	_check("T4-10", ids.size() > 0, "礼物目录 %d 项" % ids.size())
	var g: String = WorkshopData.roll_gift()
	_check("T4-10", WorkshopData.has_gift(g), "roll_gift → %s（命中目录）" % g)
	WorkshopData.reset_pity()  # 清掉自检产生的保底计数
	_check("T4-10", typeof(WorkshopManager.get_slots()) == TYPE_ARRAY, "get_slots 返回数组")
	_check("T4-10", typeof(WorkshopManager.is_workshop_active()) == TYPE_BOOL, "is_workshop_active 返回 bool")
	_check_load("T4-10", "res://scenes/WorkshopPage.gd")


# ── T4-11 爱心送养 RelinquishSystem ──────────────────────

func _t4_11_relinquish() -> void:
	print("-- T4-11 爱心送养 --")
	var rs := _node("RelinquishSystem")
	if rs == null:
		_xx("T4-11", "RelinquishSystem 未注册")
		return
	_check("T4-11", rs.has_method("relinquish_cat"), "relinquish_cat 存在")
	_check("T4-11", int(RelinquishSystem.WEEKLY_PETAL_CAP) == 500, "周花瓣上限=500")
	var constants: Dictionary = _script_constants("res://core/RelinquishSystem.gd")
	var base_values: Dictionary = Dictionary(constants.get("SPECIES_BASE", {}))
	_check("T4-11", int(base_values.get("orange", -1)) == 10 and int(base_values.get("british", -1)) == 20 \
		and int(base_values.get("siamese", -1)) == 30, "SPECIES_BASE orange=10 british=20 siamese=30")
	var rarity_factor: Dictionary = RelinquishSystem.RARITY_FACTOR
	_check("T4-11", float(rarity_factor.get("common", -1.0)) == 0.0 and float(rarity_factor.get("rare", -1.0)) == 1.5 \
		and float(rarity_factor.get("epic", -1.0)) == 2.0 and float(rarity_factor.get("legendary", -1.0)) == 3.0, \
		"RARITY_FACTOR common=0 rare=1.5 epic=2.0 legendary=3.0")
	_check_load("T4-11", "res://scenes/ui/relinquish_confirm_dialog.gd")


# ── T4-12 图鉴：明信片 Tab ───────────────────────────────

func _t4_12_album_postcard() -> void:
	print("-- T4-12 明信片图鉴 --")
	_check_load("T4-12", "res://scenes/S10_Album.gd")
	_check_load("T4-12", "res://scenes/S10_CatDetail.gd")
	_check_load("T4-12", "res://scenes/ui/postcard_reveal.gd")


# ── T4-13 天气/时段 WeatherTimeManager + shader ──────────

func _t4_13_weather_time() -> void:
	print("-- T4-13 天气/时段 --")
	var wt := _node("WeatherTimeManager")
	if wt == null:
		_xx("T4-13", "WeatherTimeManager 未注册")
		return
	_check("T4-13", wt.has_method("get_weather_bonus_data"), "get_weather_bonus_data 存在")
	_check("T4-13", typeof(WeatherTimeManager.get_weather_bonus_data()) == TYPE_DICTIONARY, "天气加成返回字典")
	_check("T4-13", WeatherTimeManager.get_period_name() != "", "时段名非空（%s）" % WeatherTimeManager.get_period_name())
	_check("T4-13", abs(float(WeatherTimeManager.RAIN_PROBABILITY) - 0.15) < 0.001, "雨天概率=15%（GDD一致）")
	_check_load("T4-13", "res://shaders/weather_color_grade.gdshader")


# ── T4-14 屏显猫筛选 CatScreenManager（+14b CatSpawner）──

func _t4_14_cat_screen() -> void:
	print("-- T4-14 屏显猫筛选 --")
	var csm := _node("CatScreenManager")
	if csm == null:
		_xx("T4-14", "CatScreenManager 未注册")
		return
	_check("T4-14", int(CatScreenManager.MAX_PINNED) == 4 and int(CatScreenManager.MAX_ROTATING_BASE) == 2, "固定4 + 轮换2")
	_check("T4-14", typeof(CatScreenManager.get_visible_cats()) == TYPE_ARRAY, "get_visible_cats 返回数组")
	_check("T4-14", csm.has_method("pin_cat") and csm.has_method("unpin_cat") and csm.has_method("force_debut"), "pin/unpin/force_debut 完整")
	# T4-14b
	_check_load("T4-14b", "res://core/CatSpawner.gd")


# ── T4-15 品种解锁 BreedUnlockEngine ─────────────────────

func _t4_15_breed_unlock() -> void:
	print("-- T4-15 品种解锁 --")
	var be := _node("BreedUnlockEngine")
	if be == null:
		_xx("T4-15", "BreedUnlockEngine 未注册")
		return
	_check("T4-15", int(BreedUnlockEngine.UNLOCK_CHAIN_COUNT) == 2 and int(BreedUnlockEngine.PITY_THRESHOLD) == 5, "解锁链=每品种3只(chain2) + 保底5")
	var b: String = BreedUnlockEngine.determine_breed()
	var valid := [CatData.BREED_ORANGE, CatData.BREED_BRITISH, CatData.BREED_SIAMESE]
	_check("T4-15", b in valid, "determine_breed → %s（合法品种）" % b)
	var unlocked: Array = BreedUnlockEngine.get_unlocked_breeds()
	_check("T4-15", unlocked.has(CatData.BREED_ORANGE), "初始已解锁橘猫")


# ── T4-16 随行猫经验 ─────────────────────

func _t4_16_companion_exp() -> void:
	print("-- T4-16 随行猫经验 --")
	var he := _node("HatchEngine")
	if he == null:
		_xx("T4-16", "HatchEngine 未注册")
		return
	var original_hatch_save: Dictionary = HatchEngine.get_save_data()
	var original_step_save: Dictionary = StepEngine.get_save_data() if StepEngine.has_method("get_save_data") else {}
	var selfcheck_cats: Array = [
		_make_selfcheck_cat("selfcheck_companion_first", CatData.BREED_ORANGE, CatData.RARITY_COMMON),
		_make_selfcheck_cat("selfcheck_companion_second", CatData.BREED_SIAMESE, CatData.RARITY_RARE),
	]
	var selfcheck_save: Dictionary = HatchEngine.get_save_data()
	selfcheck_save["cats"] = selfcheck_cats
	selfcheck_save["current_companion_cat_id"] = ""
	HatchEngine.apply_save(selfcheck_save)
	StepEngine.apply_save({})
	var cats: Array = he.get_cats()
	var cat: Variant = cats[0]
	var cid: String = _cat_id(cat)
	var old_exp: int = _cat_exp(cat)
	var old_lv: int = _cat_level(cat)
	# 设为携带猫 + 加步数
	he.current_companion_cat_id = cid
	StepEngine.add_mock_steps(6000)
	await get_tree().process_frame
	var updated_cat: Variant = he.get_cat_by_id(cid)
	var new_exp: int = _cat_exp(updated_cat)
	var new_lv: int = _cat_level(updated_cat)
	# 校验：经验应增长，等级应≥1
	_check("T4-16", new_exp > old_exp, "步数→经验增长: %d→%d" % [old_exp, new_exp])
	_check("T4-16", new_lv >= old_lv, "等级不降: Lv.%d→Lv.%d" % [old_lv, new_lv])
	var first_cat_exp: int = new_exp

	# T-1303：切换随行猫时，新随行猫继承今日步数计算经验。
	var second_cat: Variant = cats[1]
	for candidate: Variant in he.get_cats():
		if _cat_id(candidate) != cid:
			second_cat = candidate
			break

	var second_id: String = _cat_id(second_cat)
	he.current_companion_cat_id = ""
	StepEngine.apply_save({})
	StepEngine.add_mock_steps(5000)
	await get_tree().process_frame
	HatchEngine.set_companion_cat_id(second_id)
	await get_tree().process_frame
	var switched_cat: Variant = he.get_cat_by_id(second_id)
	var today_steps: int = StepEngine.get_today_steps()
	var expected_exp: int = LevelSystem.calc_exp(today_steps, LevelSystem.get_breed_multiplier(_cat_species(switched_cat))) if LevelSystem else 0
	var switched_exp: int = _cat_exp(switched_cat)
	_check("T4-16", first_cat_exp == _cat_exp(he.get_cat_by_id(cid)), "切换后首只猫经验保持: %d" % first_cat_exp)
	_check("T4-16", switched_exp == expected_exp, "切换猫继承今日步数: %d步 → %d exp" % [today_steps, expected_exp])
	# 清理
	HatchEngine.apply_save(original_hatch_save)
	if StepEngine.has_method("apply_save"):
		StepEngine.apply_save(original_step_save)


# ── T4-17 Common只返金币 ─────────────────────

func _t4_17_common_no_petals() -> void:
	print("-- T4-17 Common只返金币 --")
	var rs := _node("RelinquishSystem")
	var he := _node("HatchEngine")
	if rs == null or he == null:
		_xx("T4-17", "RelinquishSystem/HatchEngine 未注册")
		return
	var original_hatch_save: Dictionary = HatchEngine.get_save_data()
	var original_relinquish_save: Dictionary = RelinquishSystem.get_save_data()
	var selfcheck_cats: Array = [
		_make_selfcheck_cat("selfcheck_relinquish_common", CatData.BREED_ORANGE, CatData.RARITY_COMMON),
		_make_selfcheck_cat("selfcheck_relinquish_rare", CatData.BREED_ORANGE, CatData.RARITY_RARE, 1, 0, 200),
	]
	var patched_save: Dictionary = HatchEngine.get_save_data()
	patched_save["cats"] = selfcheck_cats
	HatchEngine.apply_save(patched_save)
	RelinquishSystem.reset_all()

	var common_cat: Dictionary = {
		"id": "selfcheck_relinquish_common",
		"species": CatData.BREED_ORANGE,
		"rarity": CatData.RARITY_COMMON,
		"level": 1,
		"affection": 200,
	}
	var common_result: Dictionary = RelinquishSystem.relinquish_cat(common_cat, "selfcheck_common_no_petals")
	_check("T4-17", int(common_result.get("love_petals", -1)) == 0 and int(common_result.get("gold_coins", -1)) == 50, "common → 0花瓣 + 50金币")

	var rare_cat: Dictionary = {
		"id": "selfcheck_relinquish_rare",
		"species": CatData.BREED_ORANGE,
		"rarity": CatData.RARITY_RARE,
		"level": 1,
		"affection": 200,
	}
	var rare_result: Dictionary = RelinquishSystem.relinquish_cat(rare_cat, "selfcheck_rare_petals")
	_check("T4-17", int(rare_result.get("love_petals", 0)) > 0, "Rare Lv.1 好感200 → 花瓣>0")

	HatchEngine.apply_save(original_hatch_save)
	RelinquishSystem.apply_save(original_relinquish_save)


# ── T4-18 周上限截断 ─────────────────────

func _t4_18_weekly_cap() -> void:
	print("-- T4-18 周上限截断 --")
	_check("T4-18", int(RelinquishSystem.WEEKLY_PETAL_CAP) == 500, "WEEKLY_PETAL_CAP=500")


# ── 汇总 ─────────────────────────────────────────────────

func _summary() -> void:
	var total := _pass + _fail
	print("==================================================")
	print("  T4 全系列自检结果： %d/%d PASS，%d FAIL" % [_pass, total, _fail])
	if _fail == 0:
		print("  ✅ ALL PASS")
	else:
		print("  ❌ FAIL 项： " + ", ".join(_fail_tags))
	print("==================================================")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(_fail)
