extends SceneTree

const WeeklyS := preload("res://scripts/postcard/WeeklySpotlightManager.gd")
const ExploreS := preload("res://core/ExploreEngine.gd")
const PostcardS := preload("res://scripts/collect_book/postcard_data.gd")

var _pass := 0
var _fail := 0
var _log: Array[String] = []
var _saved_spotlight := {}


func _init() -> void:
	print("\n===== Weekly Spotlight 自检 开始 =====\n")
	_backup_spotlight_config()
	_reset_test_state()
	_t_rotation_by_iso_week()
	_t_pick_postcard_boost()
	_t_pick_postcard_no_boost()
	_t_override()
	_t_override_expiry()
	_t_auto_rotation_signal()
	_restore_spotlight_config()
	_report()
	quit(1 if _fail > 0 else 0)


func check(name: String, cond: bool, detail := "") -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		_log.append("[FAIL] %s  %s" % [name, detail])


func check_eq(name: String, got, exp) -> void:
	check(name, got == exp, "got=%s exp=%s" % [str(got), str(exp)])


func _t_rotation_by_iso_week() -> void:
	check_eq("TC-48-1 week 1 -> first location",
		WeeklyS.get_location_for_week_number(1), "convenience_store")
	check_eq("TC-48-1 week 11 -> first location again",
		WeeklyS.get_location_for_week_number(11), "convenience_store")


func _t_pick_postcard_boost() -> void:
	_reset_test_state()
	WeeklyS.set_override("sky_bridge", 0)
	ExploreS._mock_collected_postcards([])
	ExploreS._spotlight_boost = 0.15
	ExploreS._rng.seed = 271828
	var spotlight_hits := 0
	var iterations := 1000
	for _i in range(iterations):
		var postcard_id := ExploreS._pick_postcard_for_cat("orange")
		var postcard = PostcardS.get_by_id(postcard_id)
		if postcard != null and String(postcard.location_type) == "sky_bridge":
			spotlight_hits += 1
	var ratio := float(spotlight_hits) / float(iterations)
	check("TC-48-2 spotlight boost roughly 15%",
		ratio >= 0.10 and ratio <= 0.20,
		"hits=%d ratio=%.3f" % [spotlight_hits, ratio])


func _t_pick_postcard_no_boost() -> void:
	_reset_test_state()
	WeeklyS.set_override("sky_bridge", 0)
	ExploreS._mock_collected_postcards([])
	ExploreS._spotlight_boost = 0.0
	ExploreS._rng.seed = 271828
	var spotlight_hits := 0
	var iterations := 1000
	for _i in range(iterations):
		var postcard_id := ExploreS._pick_postcard_for_cat("orange")
		var postcard = PostcardS.get_by_id(postcard_id)
		if postcard != null and String(postcard.location_type) == "sky_bridge":
			spotlight_hits += 1
	check("TC-48-2b no spotlight boost has no sky bridge hits",
		spotlight_hits == 0,
		"hits=%d" % spotlight_hits)


func _t_override() -> void:
	_reset_test_state()
	WeeklyS._test_week_number = 1
	WeeklyS.set_override("cafe", 0)
	check_eq("TC-48-3 config override location",
		WeeklyS.get_current_spotlight_location(), "cafe")


func _t_override_expiry() -> void:
	_reset_test_state()
	WeeklyS._test_week_number = 2
	WeeklyS._test_unix_time = 2000
	WeeklyS.set_override("cafe", 1000)
	check_eq("TC-48-4 expired override falls back to rotation",
		WeeklyS.get_current_spotlight_location(), "park_bench")


func _t_auto_rotation_signal() -> void:
	_reset_test_state()
	WeeklyS._test_week_number = 3
	WeeklyS._test_week_key = 202603
	WeeklyS._save_config({
		"last_checked_week": 202602,
		"override_location": "",
		"override_until": 0,
	})
	var manager = WeeklyS.new()
	var emitted := []
	manager.spotlight_changed.connect(func(location_type: String) -> void:
		emitted.append(location_type)
	)
	manager.schedule_rotation_check()
	check_eq("TC-48-5 auto rotation emits signal count", emitted.size(), 1)
	check_eq("TC-48-5 auto rotation emits current location", emitted[0], "subway_station")
	manager.free()


func _backup_spotlight_config() -> void:
	var cfg := ConfigFile.new()
	cfg.load(WeeklyS.CFG_PATH)
	_saved_spotlight = {
		"last_checked_week": int(cfg.get_value(WeeklyS.SECTION, "last_checked_week", -1)),
		"override_location": String(cfg.get_value(WeeklyS.SECTION, "override_location", "")),
		"override_until": int(cfg.get_value(WeeklyS.SECTION, "override_until", 0)),
	}


func _restore_spotlight_config() -> void:
	WeeklyS._save_config(_saved_spotlight)
	_reset_test_state()


func _reset_test_state() -> void:
	WeeklyS._test_week_number = -1
	WeeklyS._test_week_key = -1
	WeeklyS._test_unix_time = -1
	WeeklyS.clear_override()
	ExploreS._spotlight_boost = 0.15


func _report() -> void:
	for line in _log:
		print(line)
	print("\nWeekly Spotlight: PASS=%d FAIL=%d" % [_pass, _fail])
