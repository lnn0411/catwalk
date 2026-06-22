extends Node

const CatData := preload("res://core/CatData.gd")
const SAVE_PATH := "user://save.cfg"

var _config := ConfigFile.new()
var _is_applying: bool = false

func _ready() -> void:
	load_and_apply()
	_connect_auto_save()

func save_all() -> void:
	_write_steps()
	_write_energy()
	_write_breed_unlock()
	_write_hatch()
	_write_currency()
	_write_achievements()
	_write_relinquish()
	_write_workshop()
	_write_cat_screen()
	_config.save(SAVE_PATH)

func load_and_apply() -> void:
	_config = ConfigFile.new()
	var err := _config.load(SAVE_PATH)
	if err != OK:
		_config.clear()

	# 周重置：本地周一 00:00 跨越后清空本周心动花瓣累计并顺延重置点。
	_check_week_reset()

	_is_applying = true
	StepEngine.apply_save(_read_steps())
	EnergyEngine.apply_save(_read_energy())
	BreedUnlockEngine.apply_save(_read_breed_unlock())
	HatchEngine.apply_save(_read_hatch())
	var currency_data := _read_currency()
	currency_data["love_petals"] = int(_config.get_value("relinquish", "love_petals", 0))
	CurrencyManager.apply_save(currency_data)
	var rs := get_node_or_null("/root/RelinquishSystem")
	var ps := get_node_or_null("/root/PackageSystem")
	var ms := get_node_or_null("/root/MailSystem")
	if rs and rs.has_method("apply_save"):
		rs.apply_save(_read_relinquish())
	if ps and ps.has_method("apply_save"):
		ps.apply_save(_read_relinquish())
	if ms and ms.has_method("apply_save"):
		ms.apply_save(_read_relinquish())
	AchievementSystem.apply_save(_read_achievements())
	var cs := get_node_or_null("/root/CatScreenManager")
	if cs and cs.has_method("apply_save"):
		cs.apply_save(_read_cat_screen())
	_is_applying = false
	# 存档应用完后，让步数引擎按硬件累计值重新对齐一次，
	# 避免冷启动时"应用关闭期间累积的步数"在首帧丢失。
	if StepEngine and StepEngine.has_method("_refresh_plugin_steps"):
		StepEngine._refresh_plugin_steps()

func reset_all() -> void:
	_config.clear()
	_config.erase_section("relinquish")
	_config.save(SAVE_PATH)
	_is_applying = true
	StepEngine.apply_save({})
	EnergyEngine.apply_save({})
	BreedUnlockEngine.apply_save({})
	HatchEngine.apply_save({})
	CurrencyManager.apply_save({})
	AchievementSystem.reset_all()
	var cs2 := get_node_or_null("/root/CatScreenManager")
	if cs2 and cs2.has_method("apply_save"):
		cs2.apply_save({})
	_is_applying = false
	save_all()

func _connect_auto_save() -> void:
	if EnergyEngine and not EnergyEngine.energy_changed.is_connected(_on_auto_save):
		EnergyEngine.energy_changed.connect(_on_auto_save)
	if HatchEngine and not HatchEngine.hatch_complete.is_connected(_on_hatch_complete_auto_save):
		HatchEngine.hatch_complete.connect(_on_hatch_complete_auto_save)
	if EventBus and not EventBus.currency_changed.is_connected(_on_currency_changed_auto_save):
		EventBus.currency_changed.connect(_on_currency_changed_auto_save)

func _on_auto_save(_current = null, _pool_max = null, _backup = null) -> void:
	if _is_applying:
		return
	save_all()

func _on_hatch_complete_auto_save(_cat_data) -> void:
	if _is_applying:
		return
	save_all()

func _on_currency_changed_auto_save(_gold = null, _diamonds = null, _petals = null) -> void:
	if _is_applying:
		return
	save_all()

func _read_steps() -> Dictionary:
	return {
		"today_steps": int(_config.get_value("steps", "today_steps", 0)),
		"total_steps": int(_config.get_value("steps", "total_steps", 0)),
		"last_plugin_steps": int(_config.get_value("steps", "last_plugin_steps", 0)),
		"last_step_date": String(_config.get_value("steps", "last_step_date", "")),
	}

func _write_steps() -> void:
	var data := StepEngine.get_save_data()
	_config.set_value("steps", "today_steps", int(data.get("today_steps", 0)))
	_config.set_value("steps", "total_steps", int(data.get("total_steps", 0)))
	_config.set_value("steps", "last_plugin_steps", int(data.get("last_plugin_steps", 0)))
	_config.set_value("steps", "last_step_date", String(data.get("last_step_date", "")))

func _read_energy() -> Dictionary:
	return {
		"energy_pool": float(_config.get_value("energy", "energy_pool", 0.0)),
		"reserve_tank": float(_config.get_value("energy", "reserve_tank", 0.0)),
		"total_energy_produced": float(_config.get_value("energy", "total_energy_produced", 0.0)),
		"today_energy": float(_config.get_value("energy", "today_energy", 0.0)),
		"today_steps_processed": int(_config.get_value("energy", "today_steps_processed", 0)),
		"created_at": float(_config.get_value("energy", "created_at", Time.get_unix_time_from_system())),
		"last_energy_date": String(_config.get_value("energy", "last_energy_date", "")),
	}

func _write_energy() -> void:
	var data := EnergyEngine.get_save_data()
	_config.set_value("energy", "energy_pool", float(data.get("energy_pool", 0.0)))
	_config.set_value("energy", "reserve_tank", float(data.get("reserve_tank", 0.0)))
	_config.set_value("energy", "total_energy_produced", float(data.get("total_energy_produced", 0.0)))
	_config.set_value("energy", "today_energy", float(data.get("today_energy", 0.0)))
	_config.set_value("energy", "today_steps_processed", int(data.get("today_steps_processed", 0)))
	_config.set_value("energy", "created_at", float(data.get("created_at", Time.get_unix_time_from_system())))
	_config.set_value("energy", "last_energy_date", String(data.get("last_energy_date", "")))

func _read_breed_unlock() -> Dictionary:
	return {
		"unlocked": Array(_config.get_value("breed_unlock", "unlocked", ["orange"])),
		"hatch_counts": Dictionary(_config.get_value("breed_unlock", "hatch_counts", {})),
		"pity_counters": Dictionary(_config.get_value("breed_unlock", "pity_counters", {})),
	}

func _write_breed_unlock() -> void:
	var data = BreedUnlockEngine.get_save_data()
	_config.set_value("breed_unlock", "unlocked", Array(data.get("unlocked", ["orange"])))
	_config.set_value("breed_unlock", "hatch_counts", Dictionary(data.get("hatch_counts", {})))
	_config.set_value("breed_unlock", "pity_counters", Dictionary(data.get("pity_counters", {})))

func _read_currency() -> Dictionary:
	return {
		"gold_coins": int(_config.get_value("currency", "gold_coins", 0)),
		"diamonds": int(_config.get_value("currency", "diamonds", 0)),
		"flower_petals": int(_config.get_value("currency", "flower_petals", 0)),
	}

func _write_currency() -> void:
	var data := CurrencyManager.get_save_data()
	_config.set_value("currency", "gold_coins", int(data.get("gold_coins", 0)))
	_config.set_value("currency", "diamonds", int(data.get("diamonds", 0)))
	_config.set_value("currency", "flower_petals", int(data.get("flower_petals", 0)))

func _read_hatch() -> Dictionary:
	var cat_count := int(_config.get_value("hatch", "cat_count", 0))
	var cats: Array = []
	for i in range(cat_count):
		cats.append(_read_cat("cat_%d" % i))

	return {
		"slots": Array(_config.get_value("hatch", "slots", [])),
		"cats": cats,
		"hatched_count": int(_config.get_value("hatch", "hatched_count", cat_count)),
		"epic_pity_count": int(_config.get_value("hatch", "epic_pity_count", 0)),
		"legendary_pity_count": int(_config.get_value("hatch", "legendary_pity_count", 0)),
		"ad_speedup_count": int(_config.get_value("hatch", "ad_speedup_count", 0)),
		"ad_speedup_date": String(_config.get_value("hatch", "ad_speedup_date", "")),
		"has_tutorial_first_egg": bool(_config.get_value("hatch", "has_tutorial_first_egg", false)),
		"current_companion_cat_id": String(_config.get_value("hatch", "current_companion_cat_id", "")),
	}

func _write_hatch() -> void:
	var data: Dictionary = HatchEngine.get_save_data()
	var cats: Array = Array(data.get("cats", []))
	_clear_cat_sections()
	_config.set_value("hatch", "slots", Array(data.get("slots", [])))
	_config.set_value("hatch", "hatched_count", int(data.get("hatched_count", cats.size())))
	_config.set_value("hatch", "epic_pity_count", int(data.get("epic_pity_count", 0)))
	_config.set_value("hatch", "legendary_pity_count", int(data.get("legendary_pity_count", 0)))
	_config.set_value("hatch", "ad_speedup_count", int(data.get("ad_speedup_count", 0)))
	_config.set_value("hatch", "ad_speedup_date", String(data.get("ad_speedup_date", "")))
	_config.set_value("hatch", "has_tutorial_first_egg", bool(data.get("has_tutorial_first_egg", false)))
	_config.set_value("hatch", "current_companion_cat_id", String(data.get("current_companion_cat_id", "")))
	_config.set_value("hatch", "cat_count", cats.size())
	for i in range(cats.size()):
		_write_cat("cat_%d" % i, cats[i])

func _read_cat(section: String) -> Dictionary:
	return {
		"id": String(_config.get_value(section, "id", "")),
		"species": String(_config.get_value(section, "species", CatData.BREED_ORANGE)),
		"rarity": String(_config.get_value(section, "rarity", CatData.RARITY_COMMON)),
		"hatch_index": int(_config.get_value(section, "hatch_index", 1)),
		"display_name": String(_config.get_value(section, "display_name", "")),
		"level": int(_config.get_value(section, "level", 1)),
		"exp": int(_config.get_value(section, "exp", 0)),
		"friendship": int(_config.get_value(section, "friendship", 0)),
		"created_at": float(_config.get_value(section, "created_at", Time.get_unix_time_from_system())),
	}

func _write_cat(section: String, cat_value) -> void:
	var data: Dictionary = CatData.serialize(cat_value) if cat_value is CatData else Dictionary(cat_value)
	_config.set_value(section, "id", String(data.get("id", "")))
	_config.set_value(section, "species", String(data.get("species", CatData.BREED_ORANGE)))
	_config.set_value(section, "rarity", String(data.get("rarity", CatData.RARITY_COMMON)))
	_config.set_value(section, "hatch_index", int(data.get("hatch_index", 1)))
	_config.set_value(section, "display_name", String(data.get("display_name", "")))
	_config.set_value(section, "level", int(data.get("level", 1)))
	_config.set_value(section, "exp", int(data.get("exp", 0)))
	_config.set_value(section, "friendship", int(data.get("friendship", 0)))
	_config.set_value(section, "created_at", float(data.get("created_at", Time.get_unix_time_from_system())))

func _clear_cat_sections() -> void:
	for section in _config.get_sections():
		if String(section).begins_with("cat_"):
			_config.erase_section(section)

func _read_achievements() -> Dictionary:
	return {
		"unlocked": _config.get_value("achievements", "unlocked", []),
		"hatch_count": _config.get_value("achievements", "hatch_count", 0),
		"collected_breeds": _config.get_value("achievements", "collected_breeds", []),
		"postcard_count": _config.get_value("achievements", "postcard_count", 0),
		"max_level": _config.get_value("achievements", "max_level", 0),
		"total_steps": _config.get_value("achievements", "total_steps", 0),
		"daily_step_met": _config.get_value("achievements", "daily_step_met", {}),
		"step_streak": _config.get_value("achievements", "step_streak", 0),
		"daily_step_accumulator": _config.get_value("achievements", "daily_step_accumulator", 0),
		"step_streak_checked_today": _config.get_value("achievements", "step_streak_checked_today", ""),
		"cat_interactions": _config.get_value("achievements", "cat_interactions", {}),
		"cat_streak": _config.get_value("achievements", "cat_streak", {}),
		"cat_streak_checked_today": _config.get_value("achievements", "cat_streak_checked_today", ""),
		"midnight_accessed": _config.get_value("achievements", "midnight_accessed", false),
	}

# ── GDD v2.17 Relinquish section ──

func _read_relinquish() -> Dictionary:
	return {
		"love_petals": int(_config.get_value("relinquish", "love_petals", 0)),
		"backpack_max_capacity": int(_config.get_value("relinquish", "backpack_max_capacity", 24)),
		"workshop_cached_energy": int(_config.get_value("relinquish", "workshop_cached_energy", 0)),
		"surprise_box_ready": bool(_config.get_value("relinquish", "surprise_box_ready", false)),
		"this_week_petals_gained": int(_config.get_value("relinquish", "this_week_petals_gained", 0)),
		"week_reset_timestamp": int(_config.get_value("relinquish", "week_reset_timestamp", 0)),
		"relinquished_event_ids": Array(_config.get_value("relinquish", "relinquished_event_ids", [])),
	}

func _write_relinquish() -> void:
	# love_petals 对齐 CurrencyManager.flower_petals
	if CurrencyManager:
		_config.set_value("relinquish", "love_petals", CurrencyManager.flower_petals)
	# 背包容量由 PackageSystem 管理
	var _ps := get_node_or_null("/root/PackageSystem")
	if _ps and _ps.has_method("get_capacity"):
		_config.set_value("relinquish", "backpack_max_capacity", _ps.get_capacity())
	elif not _config.has_section_key("relinquish", "backpack_max_capacity"):
		_config.set_value("relinquish", "backpack_max_capacity", 24)
	# 工坊缓存由 HatchEngine 管理
	if HatchEngine:
		_config.set_value("relinquish", "workshop_cached_energy", int(HatchEngine.workshop_cached_energy))
		_config.set_value("relinquish", "surprise_box_ready", HatchEngine.surprise_box_ready)
	# 送养周计数与幂等键由 RelinquishSystem 管理
	var _rs2 := get_node_or_null("/root/RelinquishSystem")
	if _rs2 and _rs2.has_method("get_save_data"):
		var rd: Dictionary = _rs2.get_save_data()
		_config.set_value("relinquish", "this_week_petals_gained", int(rd.get("this_week_petals_gained", 0)))
		_config.set_value("relinquish", "week_reset_timestamp", int(rd.get("week_reset_timestamp", 0)))
		_config.set_value("relinquish", "relinquished_event_ids", Array(rd.get("relinquished_event_ids", [])))

func _check_week_reset() -> void:
	var now_unix: int = int(Time.get_unix_time_from_system())
	var stored: int = int(_config.get_value("relinquish", "week_reset_timestamp", 0))
	if stored == 0 or now_unix >= stored:
		var next_monday: int = _next_monday_midnight_unix()
		_config.set_value("relinquish", "week_reset_timestamp", next_monday)
		if stored != 0:
			_config.set_value("relinquish", "this_week_petals_gained", 0)

func _next_monday_midnight_unix() -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	# weekday: 0=Sunday,...,6=Saturday → 下周一 = (8 - weekday) % 7 天后
	# 但 Godot 的 weekday 是 0=Sun,...,6=Sat。周一 = weekday 1。
	var weekday: int = int(dt["weekday"])
	var days_until_monday: int = (8 - weekday) % 7
	if days_until_monday == 0:
		days_until_monday = 7  # 如果今天是周一，下一个周一是 7 天后
	var dt_dict: Dictionary = {
		"year": int(dt["year"]),
		"month": int(dt["month"]),
		"day": int(dt["day"]),
		"hour": 0,
		"minute": 0,
		"second": 0,
	}
	var today_start: int = int(Time.get_unix_time_from_datetime_dict(dt_dict))
	return today_start + days_until_monday * 86400

func _write_achievements() -> void:
	var data: Dictionary = AchievementSystem.get_save_data()
	_config.set_value("achievements", "unlocked", data.get("unlocked", []))
	_config.set_value("achievements", "hatch_count", data.get("hatch_count", 0))
	_config.set_value("achievements", "collected_breeds", data.get("collected_breeds", []))
	_config.set_value("achievements", "postcard_count", data.get("postcard_count", 0))
	_config.set_value("achievements", "max_level", data.get("max_level", 0))
	_config.set_value("achievements", "total_steps", data.get("total_steps", 0))
	_config.set_value("achievements", "daily_step_met", data.get("daily_step_met", {}))
	_config.set_value("achievements", "step_streak", data.get("step_streak", 0))
	_config.set_value("achievements", "daily_step_accumulator", data.get("daily_step_accumulator", 0))
	_config.set_value("achievements", "step_streak_checked_today", data.get("step_streak_checked_today", ""))
	_config.set_value("achievements", "cat_interactions", data.get("cat_interactions", {}))
	_config.set_value("achievements", "cat_streak", data.get("cat_streak", {}))
	_config.set_value("achievements", "cat_streak_checked_today", data.get("cat_streak_checked_today", ""))
	_config.set_value("achievements", "midnight_accessed", data.get("midnight_accessed", false))

# ── Workshop section ──

func _read_workshop() -> Dictionary:
	return {
		"workshop_manager": _config.get_value("workshop", "manager_data", {}),
		"workshop_data": _config.get_value("workshop", "workshop_data", {}),
		"workshop_inventory": _config.get_value("workshop", "inventory_data", {}),
	}

func _write_workshop() -> void:
	pass

# ── CatScreenManager section ──

func _read_cat_screen() -> Dictionary:
	return {
		"max_cats": int(_config.get_value("cat_screen", "max_cats", 6)),
		"max_rotating": int(_config.get_value("cat_screen", "max_rotating", 2)),
		"pinned_cats": Array(_config.get_value("cat_screen", "pinned_cats", [])),
		"rotating_cats": Array(_config.get_value("cat_screen", "rotating_cats", [])),
		"last_rotation_time": int(_config.get_value("cat_screen", "last_rotation_time", 0)),
		"next_rotation_time": int(_config.get_value("cat_screen", "next_rotation_time", 0)),
		"cat_debut_times": Dictionary(_config.get_value("cat_screen", "cat_debut_times", {})),
		"cat_cooldowns": Dictionary(_config.get_value("cat_screen", "cat_cooldowns", {})),
		"cat_weight_bonus": Dictionary(_config.get_value("cat_screen", "cat_weight_bonus", {})),
	}

func _write_cat_screen() -> void:
	var cs := get_node_or_null("/root/CatScreenManager")
	if cs == null or not cs.has_method("get_save_data"):
		return
	var data: Dictionary = cs.get_save_data()
	_config.set_value("cat_screen", "max_cats", int(data.get("max_cats", 6)))
	_config.set_value("cat_screen", "max_rotating", int(data.get("max_rotating", 2)))
	_config.set_value("cat_screen", "pinned_cats", Array(data.get("pinned_cats", [])))
	_config.set_value("cat_screen", "rotating_cats", Array(data.get("rotating_cats", [])))
	_config.set_value("cat_screen", "last_rotation_time", int(data.get("last_rotation_time", 0)))
	_config.set_value("cat_screen", "next_rotation_time", int(data.get("next_rotation_time", 0)))
	_config.set_value("cat_screen", "cat_debut_times", Dictionary(data.get("cat_debut_times", {})))
	_config.set_value("cat_screen", "cat_cooldowns", Dictionary(data.get("cat_cooldowns", {})))
	_config.set_value("cat_screen", "cat_weight_bonus", Dictionary(data.get("cat_weight_bonus", {})))
