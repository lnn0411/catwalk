extends Control
# ============================================================
# Catwalk full runtime self-check
#
# Run:
#   godot --headless res://tests/catwalk_full_self_check.tscn
#
# Exit code = failure count.
# ============================================================

const CatDataScript := preload("res://core/CatData.gd")

var _pass := 0
var _fail := 0
var _fail_tags: Array[String] = []


func _ready() -> void:
	print("==================================================")
	print("Catwalk Full Self-Check")
	print("==================================================")

	_section_compile_guard()
	_section_scene_load()
	_section_core_systems()
	_section_scene_validation()
	_section_core_loop()
	_section_color_validation()

	_summary()


# -- Test helpers ------------------------------------------------------------

func _ok(tag: String, msg: String) -> void:
	_pass += 1
	print("[OK] %s — %s" % [tag, msg])


func _xx(tag: String, msg: String) -> void:
	_fail += 1
	_fail_tags.append(tag)
	print("[XX] %s — %s" % [tag, msg])


func _check(tag: String, condition: bool, desc: String) -> void:
	if condition:
		_ok(tag, desc)
	else:
		_xx(tag, desc)


func _check_load(tag: String, path: String) -> void:
	_check(tag, _load_script(path), "load %s" % path)


func _node(singleton_name: String) -> Node:
	return get_node_or_null("/root/" + singleton_name)


func _summary() -> void:
	var total := _pass + _fail
	print("==================================================")
	print("Catwalk Full Self-Check: %d/%d PASS, %d FAIL" % [_pass, total, _fail])
	if _fail == 0:
		print("✅ ALL PASS")
	else:
		print("❌ FAIL: " + ", ".join(_fail_tags))
	print("==================================================")
	get_tree().quit(_fail)


func _load_script(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var script = load(path)
	return script != null


func _load_resource(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


func _script_constants(path: String) -> Dictionary:
	var script := _load_resource(path)
	if script != null and script.has_method("get_script_constant_map"):
		return script.get_script_constant_map()
	return {}


func _script_has_method(path: String, method_name: String) -> bool:
	var script := _load_resource(path)
	if script == null:
		return false
	if script.has_method(method_name):
		return true
	if script.has_method("get_script_method_list"):
		for item in script.get_script_method_list():
			if String(item.get("name", "")) == method_name:
				return true
	return false


func _has_const(path: String, const_name: String) -> bool:
	return _script_constants(path).has(const_name)


func _const_value(path: String, const_name: String, fallback = null):
	return _script_constants(path).get(const_name, fallback)


func _check_singleton(tag: String, singleton_name: String) -> Node:
	var n := _node(singleton_name)
	_check(tag, n != null, "%s registered at /root/%s" % [singleton_name, singleton_name])
	return n


func _check_methods(tag: String, n: Object, method_names: Array[String], label: String) -> void:
	if n == null:
		_xx(tag, "%s methods exist: %s" % [label, ", ".join(method_names)])
		return
	var missing: Array[String] = []
	for method_name in method_names:
		if not n.has_method(method_name):
			missing.append(method_name)
	_check(tag, missing.is_empty(), "%s methods exist: %s" % [label, ", ".join(method_names)] + ("" if missing.is_empty() else " (missing: %s)" % ", ".join(missing)))


func _check_signal(tag: String, n: Object, signal_name: String, label: String) -> void:
	_check(tag, n != null and n.has_signal(signal_name), "%s signal %s exists" % [label, signal_name])


func _find_child_recursive(root: Node, child_name: String) -> Node:
	if root == null:
		return null
	if root.name == child_name:
		return root
	for child in root.get_children():
		var found := _find_child_recursive(child, child_name)
		if found != null:
			return found
	return null


func _scene_instance(path: String) -> Node:
	var res := _load_resource(path)
	if res == null or not (res is PackedScene):
		return null
	return (res as PackedScene).instantiate()


func _check_scene_shape(path: String, expected_base: String) -> Node:
	var tag := "SCENE_LOAD"
	_check(tag, ResourceLoader.exists(path), "%s exists" % path)
	var res := _load_resource(path)
	_check(tag, res != null, "%s loads" % path)
	var inst: Node = null
	if res is PackedScene:
		inst = (res as PackedScene).instantiate()
	_check(tag, inst != null, "%s instantiates" % path)
	var type_ok := false
	if inst != null:
		match expected_base:
			"Control":
				type_ok = inst is Control
			"Node2D":
				type_ok = inst is Node2D
			"CharacterBody2D":
				type_ok = inst is CharacterBody2D
			"CanvasLayer":
				type_ok = inst is CanvasLayer
			"Node":
				type_ok = inst is Node
			_:
				type_ok = inst.is_class(expected_base)
	_check(tag, type_ok, "%s root is %s" % [path, expected_base])
	if inst != null:
		inst.queue_free()
	return inst


func _collect_gd_files() -> Array[String]:
	var paths: Array[String] = []
	_add_gd_files(paths, "res://autoload", false)
	_add_gd_files(paths, "res://core", false)
	_add_gd_files(paths, "res://characters", false)
	_add_gd_files(paths, "res://items", false)
	_add_gd_files(paths, "res://ui", true)
	_add_gd_files(paths, "res://scenes", false)
	_add_gd_files(paths, "res://scenes/ui", false)
	_add_gd_files(paths, "res://scenes/components", false)
	paths.sort()
	return paths


func _add_gd_files(out: Array[String], dir_path: String, recursive: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if recursive:
				_add_gd_files(out, full_path, recursive)
		elif entry.ends_with(".gd"):
			if not out.has(full_path):
				out.append(full_path)
	dir.list_dir_end()


# 1. COMPILE_GUARD ----------------------------------------------------------

func _section_compile_guard() -> void:
	print("-- 1. COMPILE_GUARD --")
	var paths := _collect_gd_files()
	_check("COMPILE_GUARD", paths.size() > 0, "found .gd files in requested folders")
	for path in paths:
		_check_load("COMPILE_GUARD", path)


# 2. SCENE_LOAD -------------------------------------------------------------

func _section_scene_load() -> void:
	print("-- 2. SCENE_LOAD --")
	var scenes := [
		["res://scenes/S00_Splash.tscn", "Control"],
		["res://scenes/S01_Onboarding.tscn", "Control"],
		["res://scenes/S02_Loading.tscn", "Control"],
		["res://scenes/S03_Permission.tscn", "Control"],
		["res://scenes/S04_GardenMain.tscn", "Control"],
		["res://scenes/S05_ReadOnlyGarden.tscn", "Control"],
		["res://scenes/S06_HatchPage.tscn", "Control"],
		["res://scenes/S06_NamePopup.tscn", "Control"],
		["res://scenes/S08_HatchShow.tscn", "Control"],
		["res://scenes/S10_Album.tscn", "Control"],
		["res://scenes/S10_CatDetail.tscn", "Control"],
		["res://scenes/S11_Settings.tscn", "Control"],
		["res://scenes/S12_Shop.tscn", "Control"],
		["res://scenes/S13_Friends.tscn", "Control"],
		["res://scenes/S90_NetworkError.tscn", "Control"],
		["res://scenes/S91_PermDenied.tscn", "Control"],
		["res://scenes/S92_SleepReturn.tscn", "Control"],
		["res://scenes/ArtSelfTest.tscn", "Node2D"],
		["res://scenes/main.tscn", "Control"],
		["res://scenes/CatSprite.tscn", "CharacterBody2D"],
		["res://scenes/CatInfoPopup.tscn", "CanvasLayer"],
		["res://scenes/components/HatchSlot.tscn", "Control"],
	]
	for scene in scenes:
		_check_scene_shape(String(scene[0]), String(scene[1]))


# 3. CORE_SYSTEMS -----------------------------------------------------------

func _section_core_systems() -> void:
	print("-- 3. CORE_SYSTEMS --")
	_check_step_engine()
	_check_energy_engine()
	_check_hatch_engine()
	_check_explore_engine()
	_check_save_manager()
	_check_event_bus()
	_check_currency_manager()
	_check_interaction_system()
	_check_level_system()
	_check_emotion_state_machine()
	_check_cat_spawner()
	_check_cat_schedule()
	_check_cat_data()
	_check_inventory_manager()
	_check_time_guard()
	_check_achievement_system()
	_check_mail_system()
	_check_relinquish_system()
	_check_signin_system()
	_check_package_system()
	_check_tutorial_manager()
	_check_workshop_data()
	_check_workshop_manager()


func _check_step_engine() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "StepEngine")
	_check_signal("CORE_SYSTEMS", n, "steps_updated", "StepEngine")
	_check_methods("CORE_SYSTEMS", n, ["add_mock_steps", "apply_save", "get_today_steps", "get_total_steps", "get_save_data"], "StepEngine")


func _check_energy_engine() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "EnergyEngine")
	_check_methods("CORE_SYSTEMS", n, ["calc_energy", "process_steps", "spend_pool", "get_save_data", "apply_save"], "EnergyEngine")
	_check("CORE_SYSTEMS", n != null and n.get("energy_pool") != null, "EnergyEngine.energy_pool exists")
	_check("CORE_SYSTEMS", n != null and n.get("total_energy_produced") != null, "EnergyEngine.total_energy_produced exists")
	_check("CORE_SYSTEMS", _const_value("res://core/EnergyEngine.gd", "MAX_ENERGY_POOL", 0.0) == 15000.0, "EnergyEngine.MAX_ENERGY_POOL = 15000")
	# MAX_RESERVE_TANK removed in GDD v3.1 R8


func _check_hatch_engine() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "HatchEngine")
	_check_methods("CORE_SYSTEMS", n, ["get_unlocked_species", "get_hatched_count", "collect_ready_slot", "get_save_data", "get_slots", "feed_energy"], "HatchEngine")
	_check("CORE_SYSTEMS", n != null and n.get("slots") is Array, "HatchEngine.slots exists")
	_check("CORE_SYSTEMS", _const_value("res://core/HatchEngine.gd", "SLOT_COUNT", 0) == 4, "HatchEngine.SLOT_COUNT = 4")


func _check_explore_engine() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "ExploreEngine")
	_check_methods("CORE_SYSTEMS", n, ["get_slot_count", "is_slot_available", "dispatch", "collect"], "ExploreEngine")
	_check("CORE_SYSTEMS", _const_value("res://core/ExploreEngine.gd", "SLOT_COUNT", 0) == 2, "ExploreEngine.SLOT_COUNT = 2")
	_check("CORE_SYSTEMS", _const_value("res://core/ExploreEngine.gd", "SLOT1_HATCH_REQ", 0) == 5, "ExploreEngine.SLOT1_HATCH_REQ = 5")
	_check("CORE_SYSTEMS", _const_value("res://core/ExploreEngine.gd", "VALID_DURATIONS", []) == [1, 2, 4], "ExploreEngine durations 1/2/4")


func _check_save_manager() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "SaveManager")
	_check_methods("CORE_SYSTEMS", n, ["save_all", "load_and_apply", "reset_all"], "SaveManager")


func _check_event_bus() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "EventBus")
	_check_methods("CORE_SYSTEMS", n, ["safe_emit", "has_listeners"], "EventBus")
	_check_signal("CORE_SYSTEMS", n, "step_updated", "EventBus")
	_check_signal("CORE_SYSTEMS", n, "hatch_completed", "EventBus")


func _check_currency_manager() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "CurrencyManager")
	_check_methods("CORE_SYSTEMS", n, ["add_gold", "spend_gold", "get_gold", "add_diamonds", "spend_diamonds", "get_diamonds", "add_petals", "spend_petals", "get_petals", "can_afford", "get_save_data", "apply_save"], "CurrencyManager")


func _check_interaction_system() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "InteractionSystem")
	_check_methods("CORE_SYSTEMS", n, ["do_interact", "try_interact", "can_interact", "get_affection", "get_cooldown_remaining"], "InteractionSystem")


func _check_level_system() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "LevelSystem")
	_check_methods("CORE_SYSTEMS", n, ["get_breed_multiplier", "calc_exp", "get_level", "is_max_level", "get_exp_to_next"], "LevelSystem")
	_check("CORE_SYSTEMS", _const_value("res://core/LevelSystem.gd", "MAX_EXP", 0) == 150000, "LevelSystem.MAX_EXP = 150000")


func _check_emotion_state_machine() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "EmotionStateMachine")
	_check_methods("CORE_SYSTEMS", n, ["register_interaction", "get_state", "is_annoyed", "reset_cat", "get_emotion", "is_sleeping", "record_interaction"], "EmotionStateMachine")
	_check_signal("CORE_SYSTEMS", n, "state_changed", "EmotionStateMachine")
	_check("CORE_SYSTEMS", _const_value("res://core/EmotionStateMachine.gd", "INTERACTION_THRESHOLD", 0) == 5, "EmotionStateMachine.INTERACTION_THRESHOLD = 5")


func _check_cat_spawner() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "CatSpawner")
	_check_methods("CORE_SYSTEMS", n, ["set_cat_container", "get_cat_node", "instance_cat", "get_cat_world_position"], "CatSpawner")
	_check_signal("CORE_SYSTEMS", n, "cat_spawned", "CatSpawner")


func _check_cat_schedule() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "CatSchedule")
	_check_methods("CORE_SYSTEMS", n, ["get_period", "get_state", "is_night_patrol", "can_wake", "set_time_override", "reset_all"], "CatSchedule")


func _check_cat_data() -> void:
	var path := "res://core/CatData.gd"
	_check("CORE_SYSTEMS", CatDataScript.BREED_ORANGE == "orange", "CatData.BREED_ORANGE = orange")
	_check("CORE_SYSTEMS", CatDataScript.BREED_BRITISH == "british", "CatData.BREED_BRITISH = british")
	_check("CORE_SYSTEMS", CatDataScript.BREED_SIAMESE == "siamese", "CatData.BREED_SIAMESE = siamese")
	_check("CORE_SYSTEMS", CatDataScript.RARITY_COMMON == "common", "CatData.RARITY_COMMON = common")
	_check("CORE_SYSTEMS", CatDataScript.RARITY_RARE == "rare", "CatData.RARITY_RARE = rare")
	_check("CORE_SYSTEMS", CatDataScript.RARITY_EPIC == "epic", "CatData.RARITY_EPIC = epic")
	_check("CORE_SYSTEMS", CatDataScript.RARITY_LEGENDARY == "legendary", "CatData.RARITY_LEGENDARY = legendary")
	_check("CORE_SYSTEMS", CatDataScript.HATCH_ENERGY_REQUIRED == 4250, "CatData.HATCH_ENERGY_REQUIRED = 4250")
	_check("CORE_SYSTEMS", _has_const(path, "BREED_COSTS"), "CatData.BREED_COSTS exists")
	_check("CORE_SYSTEMS", _script_has_method(path, "create"), "CatData.create exists")
	_check("CORE_SYSTEMS", _script_has_method(path, "serialize"), "CatData.serialize exists")
	_check("CORE_SYSTEMS", _script_has_method(path, "deserialize"), "CatData.deserialize exists")


func _check_inventory_manager() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "InventoryManager")
	_check_methods("CORE_SYSTEMS", n, ["add_item", "has_item", "consume_item", "get_count", "synthesize"], "InventoryManager")
	_check("CORE_SYSTEMS", _has_const("res://core/InventoryManager.gd", "ITEM_SNACK"), "InventoryManager.ITEM_SNACK exists")


func _check_time_guard() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "TimeGuard")
	_check_methods("CORE_SYSTEMS", n, ["is_valid_time", "get_safe_unix_time", "days_since_last", "record_action"], "TimeGuard")
	_check("CORE_SYSTEMS", _const_value("res://core/TimeGuard.gd", "SECONDS_PER_DAY", 0.0) == 86400.0, "TimeGuard.SECONDS_PER_DAY = 86400")


func _check_achievement_system() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "AchievementSystem")
	_check_methods("CORE_SYSTEMS", n, ["is_unlocked", "get_progress", "get_unlocked_count", "get_total_count", "get_definitions", "get_save_data", "apply_save", "check", "get_reward"], "AchievementSystem")
	_check_signal("CORE_SYSTEMS", n, "achievement_unlocked", "AchievementSystem")


func _check_mail_system() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "MailSystem")
	_check_methods("CORE_SYSTEMS", n, ["check_day_boundary", "get_save_data", "apply_save"], "MailSystem")
	_check_signal("CORE_SYSTEMS", n, "mail_delivered", "MailSystem")
	_check("CORE_SYSTEMS", _has_const("res://core/MailSystem.gd", "HOLIDAYS"), "MailSystem.HOLIDAYS exists")


func _check_relinquish_system() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "RelinquishSystem")
	_check_methods("CORE_SYSTEMS", n, ["relinquish_cat", "get_save_data", "apply_save"], "RelinquishSystem")
	_check("CORE_SYSTEMS", _const_value("res://core/RelinquishSystem.gd", "WEEKLY_PETAL_CAP", 0) == 500, "RelinquishSystem.WEEKLY_PETAL_CAP = 500")


func _check_signin_system() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "SigninSystem")
	_check_methods("CORE_SYSTEMS", n, ["signin", "get_current_day", "get_streak", "use_makeup_card", "reset_all"], "SigninSystem")
	_check("CORE_SYSTEMS", _const_value("res://core/SigninSystem.gd", "CYCLE_LENGTH", 0) == 7, "SigninSystem.CYCLE_LENGTH = 7")


func _check_package_system() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "PackageSystem")
	_check_methods("CORE_SYSTEMS", n, ["get_max_capacity", "get_capacity", "check_expansion", "get_expansion_milestones", "get_save_data", "apply_save"], "PackageSystem")
	_check_signal("CORE_SYSTEMS", n, "backpack_capacity_expanded", "PackageSystem")


func _check_tutorial_manager() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "TutorialManager")
	_check_methods("CORE_SYSTEMS", n, ["is_running", "start", "notify_hatch_requested", "is_blocking_garden_input"], "TutorialManager")
	_check_signal("CORE_SYSTEMS", n, "tutorial_step_changed", "TutorialManager")


func _check_workshop_data() -> void:
	var n := _check_singleton("CORE_SYSTEMS", "WorkshopData")
	_check_methods("CORE_SYSTEMS", n, ["roll_gift", "get_gift_data", "has_gift", "get_all_gift_ids", "get_save_data", "apply_save"], "WorkshopData")
	_check("CORE_SYSTEMS", _has_const("res://core/WorkshopData.gd", "GIFT_CATALOG"), "WorkshopData.GIFT_CATALOG exists")


func _check_workshop_manager() -> void:
	# C1 步数礼盒模型（P2）：旧能量槽 API 已移除
	var n := _check_singleton("CORE_SYSTEMS", "WorkshopManager")
	_check_methods("CORE_SYSTEMS", n, ["open_box", "get_unopened_count", "get_progress", "get_save_data", "apply_save"], "WorkshopManager")
	_check("CORE_SYSTEMS", _const_value("res://core/WorkshopManager.gd", "BOX_STEPS", 0) == 3000, "WorkshopManager.BOX_STEPS = 3000")
	_check("CORE_SYSTEMS", _const_value("res://core/WorkshopManager.gd", "DAILY_BOX_CAP", 0) == 3, "WorkshopManager.DAILY_BOX_CAP = 3")
	_check("CORE_SYSTEMS", _const_value("res://core/WorkshopManager.gd", "UNOPENED_CAP", 0) == 5, "WorkshopManager.UNOPENED_CAP = 5")


# 4. SCENE_VALIDATION -------------------------------------------------------

func _section_scene_validation() -> void:
	print("-- 4. SCENE_VALIDATION --")
	_validate_splash()
	_validate_onboarding()
	_validate_loading()
	_validate_permission()
	_validate_garden_main()
	_validate_hatch_page()
	_validate_hatch_show()
	_validate_album()
	_validate_cat_detail()
	_validate_shop()
	_validate_friends()
	_validate_sleep_return()


func _validate_script_api(tag: String, path: String, methods: Array[String], constants: Array[String]) -> void:
	var script := _load_resource(path)
	_check(tag, script != null, "%s script loads" % path)
	if script == null:
		return
	var missing_methods: Array[String] = []
	for method_name in methods:
		if not _script_has_method(path, method_name):
			missing_methods.append(method_name)
	_check(tag, missing_methods.is_empty(), "%s has methods: %s" % [path.get_file(), ", ".join(methods)] + ("" if missing_methods.is_empty() else " (missing: %s)" % ", ".join(missing_methods)))
	var missing_consts: Array[String] = []
	for const_name in constants:
		if not _has_const(path, const_name):
			missing_consts.append(const_name)
	if constants.size() > 0:
		_check(tag, missing_consts.is_empty(), "%s has constants: %s" % [path.get_file(), ", ".join(constants)] + ("" if missing_consts.is_empty() else " (missing: %s)" % ", ".join(missing_consts)))


func _validate_splash() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S00_Splash.gd", ["_is_first_time"], ["SPLASH_SECONDS", "FIRST_TIME_SECONDS"])
	var inst := _scene_instance("res://scenes/S00_Splash.tscn")
	_check("SCENE_VALIDATION", inst is Control, "S00_Splash instantiates as Control")
	if inst != null:
		inst.queue_free()


func _validate_onboarding() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S01_Onboarding.gd", ["handle_back", "_build_pages", "_on_skip_pressed", "_on_start_pressed"], ["PAGE_COUNT", "AUTO_ADVANCE_INTERVAL"])
	_check("SCENE_VALIDATION", _const_value("res://scenes/S01_Onboarding.gd", "PAGE_COUNT", 0) == 3, "S01_Onboarding has 3 pages")


func _validate_loading() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S02_Loading.gd", ["_start_timeout", "_restore_save", "_days_since_last_open"], ["LOAD_DELAY_SECONDS", "LOAD_TIMEOUT_SECONDS"])
	_check("SCENE_VALIDATION", float(_const_value("res://scenes/S02_Loading.gd", "LOAD_TIMEOUT_SECONDS", 0.0)) > 0.0, "S02_Loading timeout configured")


func _validate_permission() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S03_Permission.gd", ["handle_authorize", "handle_skip", "_open_settings", "_check_permission"], [])
	var inst := _scene_instance("res://scenes/S03_Permission.tscn")
	_check("SCENE_VALIDATION", (inst != null and _find_child_recursive(inst, "AuthorizeBtn") != null) or _script_has_method("res://scenes/S03_Permission.gd", "handle_authorize"), "S03_Permission has authorize path")
	_check("SCENE_VALIDATION", (inst != null and _find_child_recursive(inst, "SkipBtn") != null) or _script_has_method("res://scenes/S03_Permission.gd", "handle_skip"), "S03_Permission has skip path")
	if inst != null:
		inst.queue_free()


func _validate_garden_main() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S04_GardenMain.gd", ["_build_garden_layer", "_build_hud", "_connect_data", "_refresh_all", "_on_bottom_nav_tab_selected"], ["GARDEN_ZOOM_LEVELS", "WORLD_WIDTH", "WORLD_HEIGHT"])
	var inst := _scene_instance("res://scenes/S04_GardenMain.tscn")
	_check("SCENE_VALIDATION", inst is Control, "S04_GardenMain instantiates without errors")
	_check("SCENE_VALIDATION", inst != null and _find_child_recursive(inst, "GardenView") != null, "S04_GardenMain has GardenView")
	_check("SCENE_VALIDATION", _script_has_method("res://scenes/S04_GardenMain.gd", "_build_garden_layer"), "S04_GardenMain builds garden_layer")
	_check("SCENE_VALIDATION", _script_has_method("res://scenes/S04_GardenMain.gd", "_build_hud"), "S04_GardenMain builds HUD/nav")
	_check("SCENE_VALIDATION", _script_has_method("res://scenes/S04_GardenMain.gd", "_refresh_cat_state"), "S04_GardenMain refreshes cat_container state")
	if inst != null:
		inst.queue_free()


func _validate_hatch_page() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S06_HatchPage.gd", ["_refresh_slots", "_inject_energy", "_speed_up", "_on_slot_pressed"], [])
	var inst := _scene_instance("res://scenes/S06_HatchPage.tscn")
	var count := 0
	if inst != null:
		for i in range(4):
			if _find_child_recursive(inst, "Slot%d" % i) != null:
				count += 1
	_check("SCENE_VALIDATION", count == 4, "S06_HatchPage has 4 hatch slots")
	_check("SCENE_VALIDATION", inst != null and _find_child_recursive(inst, "InjectBtn") != null, "S06_HatchPage has inject button")
	_check("SCENE_VALIDATION", inst != null and _find_child_recursive(inst, "AdBtn") != null, "S06_HatchPage has ad speed-up button")
	if inst != null:
		inst.queue_free()


func _validate_hatch_show() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S08_HatchShow.gd", ["_update_phase", "_draw_cracking_egg", "_draw_flash_silhouette", "_draw_reveal", "resume_after_name_popup"], ["ART_BG_PATH", "ART_EGG_CRACK_SHEET", "ART_LIGHT_SHEET"])
	_check("SCENE_VALIDATION", _script_has_method("res://scenes/S08_HatchShow.gd", "_phase4_start"), "S08_HatchShow has phase timing")


func _validate_album() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S10_Album.gd", ["_draw_tabs", "_draw_content", "_draw_postcard_grid", "_open_cat", "_open_postcard_detail"], ["POSTCARDS"])
	var inst := _scene_instance("res://scenes/S10_Album.tscn")
	_check("SCENE_VALIDATION", inst is Control, "S10_Album instantiates")
	_check("SCENE_VALIDATION", _script_has_method("res://scenes/S10_Album.gd", "_draw_tabs"), "S10_Album draws cats/postcards/achievements tabs")
	if inst != null:
		inst.queue_free()


func _validate_cat_detail() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S10_CatDetail.gd", ["_draw_cat_panel", "_draw_stats", "_heart_text", "_cat_level", "_cat_friendship"], ["DESIGN_SIZE"])
	var inst := _scene_instance("res://scenes/S10_CatDetail.tscn")
	_check("SCENE_VALIDATION", inst != null and _find_child_recursive(inst, "FeedBtn") != null, "S10_CatDetail has feed interaction control")
	_check("SCENE_VALIDATION", inst != null and _find_child_recursive(inst, "PlayBtn") != null, "S10_CatDetail has play interaction control")
	if inst != null:
		inst.queue_free()


func _validate_shop() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S12_Shop.gd", ["_build_product_list", "_on_buy_pressed", "_refresh_all_buttons", "_on_purchase_completed", "_get_button_state"], ["GARDEN_PATH", "EXCHANGE_PATH"])
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S15_ExchangeShop.gd", ["_build_product_list", "_on_buy_pressed", "_grant_product", "_refresh_all_buttons"], ["PRODUCTS"])


func _validate_friends() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S13_Friends.gd", ["_section_friends", "_refresh_list", "_add_friend", "_send_gift", "_claim_gift"], ["DEFAULT_FRIENDS", "INVITE_PREFIX"])
	var defaults = _const_value("res://scenes/S13_Friends.gd", "DEFAULT_FRIENDS", [])
	_check("SCENE_VALIDATION", defaults is Array and defaults.size() > 0, "S13_Friends has friends list data")


func _validate_sleep_return() -> void:
	_validate_script_api("SCENE_VALIDATION", "res://scenes/S92_SleepReturn.gd", ["_on_continue_pressed", "_on_page_setup", "_days_since_last_open", "_draw_text_in_rect"], ["BTN_CONTINUE_PATH"])
	var inst := _scene_instance("res://scenes/S92_SleepReturn.tscn")
	_check("SCENE_VALIDATION", inst != null and _find_child_recursive(inst, "ContinueBtn") != null, "S92_SleepReturn has continue button")
	_check("SCENE_VALIDATION", _script_has_method("res://scenes/S92_SleepReturn.gd", "_draw_text_in_rect"), "S92_SleepReturn has welcome-back text drawing")
	if inst != null:
		inst.queue_free()


# 5. CORE_LOOP --------------------------------------------------------------

func _section_core_loop() -> void:
	print("-- 5. CORE_LOOP --")
	var energy := _node("EnergyEngine")
	if energy == null:
		_xx("CORE_LOOP", "EnergyEngine unavailable")
	else:
		_check("CORE_LOOP", energy.calc_energy(0, false) == 0, "calc_energy 0 steps = 0")
		_check("CORE_LOOP", energy.calc_energy(1000, false) == 1100, "calc_energy 1000 old-player steps = 1100")
		_check("CORE_LOOP", energy.calc_energy(1000, true) == 1320, "calc_energy 1000 new-player steps = 1320")
		_check("CORE_LOOP", energy.calc_energy(3000, false) == 3150, "calc_energy 3000 old-player steps = 3150")
		_check("CORE_LOOP", energy.calc_energy(5000, false) == 4950, "calc_energy 5000 old-player steps = 4950")
		_check("CORE_LOOP", energy.calc_energy(6000, false) == 5750, "calc_energy 6000 old-player steps = 5750")

		var before_data: Dictionary = energy.get_save_data() if energy.has_method("get_save_data") else {}
		energy.apply_save({
			"energy_pool": 0.0,
			"total_energy_produced": 0.0,
			"today_energy": 0.0,
			"today_steps_processed": 0,
			"created_at": Time.get_unix_time_from_system() - 10.0 * 24.0 * 60.0 * 60.0,
			"last_energy_date": _today_key(),
		})
		var produced = energy.process_steps(1000)
		# P1 费率翻转：1000 步 ×1.1 = 1100（非新手）
		_check("CORE_LOOP", produced == 1100.0, "process_steps produced expected energy")
		_check("CORE_LOOP", energy.energy_pool == 1100.0, "process_steps increases energy_pool")
		var spent = energy.spend_pool(125.0)
		_check("CORE_LOOP", spent == 125.0, "spend_pool returns spent amount")
		_check("CORE_LOOP", energy.energy_pool == 975.0, "spend_pool decreases energy_pool")
		if before_data.size() > 0:
			energy.apply_save(before_data)

	var hatch := _node("HatchEngine")
	if hatch == null:
		_xx("CORE_LOOP", "HatchEngine unavailable")
	else:
		var slots: Array = hatch.get_slots() if hatch.has_method("get_slots") else []
		_check("CORE_LOOP", slots.size() == 4, "HatchEngine has 4 slots")
		for i in range(min(slots.size(), 4)):
			var slot: Dictionary = slots[i]
			_check("CORE_LOOP", slot.has("id"), "slot %d has id" % i)
			_check("CORE_LOOP", slot.has("unlocked"), "slot %d has unlocked" % i)
			_check("CORE_LOOP", slot.has("status"), "slot %d has status" % i)
			_check("CORE_LOOP", slot.has("energy"), "slot %d has energy" % i)
			_check("CORE_LOOP", slot.has("max_energy"), "slot %d has max_energy" % i)
			_check("CORE_LOOP", slot.has("species"), "slot %d has species" % i)


func _today_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]


# 6. COLOR_VALIDATION -------------------------------------------------------

func _section_color_validation() -> void:
	print("-- 6. COLOR_VALIDATION --")
	var palette := _check_singleton("COLOR_VALIDATION", "Palette")
	var path := "res://autoload/Palette.gd"
	var names := [
		"BG_WARM_WHITE",
		"TEXT_PRIMARY",
		"TEXT_SECONDARY",
		"AMBER",
		"CITY_GRAY",
		"MOSS_GREEN",
		"BRICK_RED",
		"MIST_BLUE",
		"MILK_WHITE",
		"BORDER_DEFAULT",
		"BORDER_ACTIVE",
		"RARITY_RARE",
		"RARITY_EPIC",
		"RARITY_LEG_A",
		"RARITY_LEG_B",
	]
	for name in names:
		_check("COLOR_VALIDATION", _has_const(path, name), "Palette.%s exists" % name)
		var value = _const_value(path, name, null)
		_check("COLOR_VALIDATION", value is Color, "Palette.%s is Color" % name)
	_check("COLOR_VALIDATION", palette != null, "Palette autoload available")
