extends Node

const CatData := preload("res://core/CatData.gd")
const SAVE_PATH := "user://save.cfg"
const SAVE_SCHEMA_VERSION := 2

var _config := ConfigFile.new()
var _is_applying: bool = false
var _is_saving: bool = false
var _feed_daily_state: Dictionary = {}

func _ready() -> void:
	load_and_apply()
	_connect_auto_save()

func save_all() -> bool:
	if _is_saving or _is_applying:
		return false
	_is_saving = true
	_write_steps()
	_write_energy()
	_write_breed_unlock()
	_write_hatch()
	_write_currency()
	_write_achievements()
	_write_relinquish()
	_write_package()
	_write_mail()
	_write_workshop()
	_write_inventory()
	_write_explore()
	_write_interaction()
	_write_board()
	_write_signin()
	_write_cat_screen()
	_write_iap()
	_write_walk_companion()
	_write_tickets()
	_write_feed_daily()
	_config.set_value("meta", "schema_version", SAVE_SCHEMA_VERSION)
	_config.set_value("meta", "updated_at", float(Time.get_unix_time_from_system()))
	var err := _config.save(SAVE_PATH)
	_is_saving = false
	if err != OK:
		push_error("[SaveManager] Save failed: %s (%d)" % [SAVE_PATH, err])
		return false
	return true

func load_and_apply() -> void:
	_config = ConfigFile.new()
	var err := _config.load(SAVE_PATH)
	if err != OK:
		_config.clear()
	_feed_daily_state = _read_feed_daily()

	# 周重置：本地周一 00:00 跨越后清空本周心动花瓣累计并顺延重置点。
	_check_week_reset()

	_is_applying = true
	StepEngine.apply_save(_read_steps())
	EnergyEngine.apply_save(_read_energy())
	BreedUnlockEngine.apply_save(_read_breed_unlock())
	HatchEngine.apply_save(_read_hatch())
	var currency_data := _read_currency()
	CurrencyManager.apply_save(currency_data)
	var rs := get_node_or_null("/root/RelinquishSystem")
	var ps := get_node_or_null("/root/PackageSystem")
	var ms := get_node_or_null("/root/MailSystem")
	if rs and rs.has_method("apply_save"):
		rs.apply_save(_read_relinquish())
	if ps and ps.has_method("apply_save"):
		ps.apply_save(_read_package())
	if ms and ms.has_method("apply_save"):
		ms.apply_save(_read_mail())
	var wd := get_node_or_null("/root/WorkshopData")
	if wd and wd.has_method("apply_save"):
		wd.apply_save(_read_workshop().get("workshop_data", {}))
	var wm := get_node_or_null("/root/WorkshopManager")
	if wm and wm.has_method("apply_save"):
		wm.apply_save(_read_workshop().get("workshop_manager", {}))
	var gi := get_node_or_null("/root/GiftInventory")
	if gi and gi.has_method("apply_save"):
		gi.apply_save(_read_workshop().get("workshop_inventory", {}))
	var inv := get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("apply_save"):
		inv.apply_save(_read_inventory())
	if ExploreEngine and ExploreEngine.has_method("apply_save"):
		ExploreEngine.apply_save(_read_explore())
	var interaction := get_node_or_null("/root/InteractionSystem")
	if interaction and interaction.has_method("apply_save"):
		interaction.apply_save(_read_interaction())
	AchievementSystem.apply_save(_read_achievements())
	var cs := get_node_or_null("/root/CatScreenManager")
	if cs and cs.has_method("apply_save"):
		cs.apply_save(_read_cat_screen())
	var iap := get_node_or_null("/root/IAPProvider")
	if iap and iap.has_method("apply_save"):
		iap.apply_save(_read_iap())
	var wc := get_node_or_null("/root/WalkCompanion")
	if wc and wc.has_method("apply_save"):
		wc.apply_save(_read_walk_companion())
	var tm := get_node_or_null("/root/TicketManager")
	if tm and tm.has_method("apply_save"):
		tm.apply_save(_read_tickets())
	var board := get_node_or_null("/root/LevelStateManager")
	if board and board.has_method("apply_save"):
		board.apply_save(_read_board())
	if SigninSystem and SigninSystem.has_method("apply_save"):
		SigninSystem.apply_save(_read_signin())
	_is_applying = false
	# 存档应用完后，让步数引擎按硬件累计值重新对齐一次，
	# 避免冷启动时"应用关闭期间累积的步数"在首帧丢失。
	if StepEngine and StepEngine.has_method("_refresh_plugin_steps"):
		StepEngine._refresh_plugin_steps()
	# 首次登录发放门票奖励（跨天自动触发）。
	# 新手期判定用账号创建时间（EnergyEngine.created_at），7天内每日3张
	if tm and tm.has_method("add_login_bonus"):
		var is_new_player := false
		if EnergyEngine != null and float(EnergyEngine.created_at) > 0.0:
			var days_since_install := (Time.get_unix_time_from_system() - float(EnergyEngine.created_at)) / 86400.0
			is_new_player = days_since_install < float(tm.NEW_PLAYER_DAYS)
		tm.add_login_bonus(is_new_player)
	# 首次启动及旧独立存档迁移都在这里固化为完整主快照。
	save_all()

func reset_all() -> void:
	_config.clear()
	_config.save(SAVE_PATH)
	_is_applying = true
	_feed_daily_state = {"date": "", "counts": {}}
	StepEngine.apply_save({})
	EnergyEngine.apply_save({})
	BreedUnlockEngine.apply_save({})
	HatchEngine.apply_save({})
	CurrencyManager.apply_save({})
	AchievementSystem.reset_all()
	var rs2 := get_node_or_null("/root/RelinquishSystem")
	if rs2 and rs2.has_method("reset_all"):
		rs2.reset_all()
	var ps2 := get_node_or_null("/root/PackageSystem")
	if ps2 and ps2.has_method("reset_all"):
		ps2.reset_all()
	var ms2 := get_node_or_null("/root/MailSystem")
	if ms2 and ms2.has_method("reset_all"):
		ms2.reset_all()
	var wd2 := get_node_or_null("/root/WorkshopData")
	if wd2 and wd2.has_method("reset_all"):
		wd2.reset_all()
	var wm2 := get_node_or_null("/root/WorkshopManager")
	if wm2 and wm2.has_method("reset_all"):
		wm2.reset_all()
	var gi2 := get_node_or_null("/root/GiftInventory")
	if gi2 and gi2.has_method("clear"):
		gi2.clear()
	var inv2 := get_node_or_null("/root/InventoryManager")
	if inv2 and inv2.has_method("reset_all"):
		inv2.reset_all()
	if ExploreEngine and ExploreEngine.has_method("reset_all"):
		ExploreEngine.reset_all()
	var interaction2 := get_node_or_null("/root/InteractionSystem")
	if interaction2 and interaction2.has_method("reset_all"):
		interaction2.reset_all()
	var board2 := get_node_or_null("/root/LevelStateManager")
	if board2 and board2.has_method("reset_all"):
		board2.reset_all()
	if SigninSystem and SigninSystem.has_method("reset_all"):
		SigninSystem.reset_all()
	var cs2 := get_node_or_null("/root/CatScreenManager")
	if cs2 and cs2.has_method("apply_save"):
		cs2.apply_save({})
	var wc2 := get_node_or_null("/root/WalkCompanion")
	if wc2 and wc2.has_method("apply_save"):
		wc2.apply_save({})
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
		"chest_claimed_today": Array(_config.get_value("steps", "chest_claimed_today", [false, false, false])),
		"chest_date": String(_config.get_value("steps", "chest_date", "")),
	}

func _write_steps() -> void:
	var data := StepEngine.get_save_data()
	_config.set_value("steps", "today_steps", int(data.get("today_steps", 0)))
	_config.set_value("steps", "total_steps", int(data.get("total_steps", 0)))
	_config.set_value("steps", "last_plugin_steps", int(data.get("last_plugin_steps", 0)))
	_config.set_value("steps", "last_step_date", String(data.get("last_step_date", "")))
	_config.set_value("steps", "chest_claimed_today", Array(data.get("chest_claimed_today", [false, false, false])))
	_config.set_value("steps", "chest_date", String(data.get("chest_date", "")))

func _read_walk_companion() -> Dictionary:
	return {
		"last_milestone_count": int(_config.get_value("walk_companion", "last_milestone_count", 0)),
		"chatter_count_today": int(_config.get_value("walk_companion", "chatter_count_today", 0)),
		"chatter_date": String(_config.get_value("walk_companion", "chatter_date", "")),
		"last_chatter_index": int(_config.get_value("walk_companion", "last_chatter_index", -1)),
		"last_summary_date": String(_config.get_value("walk_companion", "last_summary_date", "")),
	}

func _write_walk_companion() -> void:
	var wc := get_node_or_null("/root/WalkCompanion")
	if wc == null or not wc.has_method("get_save_data"):
		return
	var data: Dictionary = wc.get_save_data()
	_config.set_value("walk_companion", "last_milestone_count", int(data.get("last_milestone_count", 0)))
	_config.set_value("walk_companion", "chatter_count_today", int(data.get("chatter_count_today", 0)))
	_config.set_value("walk_companion", "chatter_date", String(data.get("chatter_date", "")))
	_config.set_value("walk_companion", "last_chatter_index", int(data.get("last_chatter_index", -1)))
	_config.set_value("walk_companion", "last_summary_date", String(data.get("last_summary_date", "")))

func _read_energy() -> Dictionary:
	return {
		"energy_pool": float(_config.get_value("energy", "energy_pool", 0.0)),
		"total_energy_produced": float(_config.get_value("energy", "total_energy_produced", 0.0)),
		"today_energy": float(_config.get_value("energy", "today_energy", 0.0)),
		"today_steps_processed": int(_config.get_value("energy", "today_steps_processed", 0)),
		"created_at": float(_config.get_value("energy", "created_at", Time.get_unix_time_from_system())),
		"last_energy_date": String(_config.get_value("energy", "last_energy_date", "")),
		"pool_full_toast_date": String(_config.get_value("energy", "pool_full_toast_date", "")),
	}

func _write_energy() -> void:
	var data := EnergyEngine.get_save_data()
	_config.set_value("energy", "energy_pool", float(data.get("energy_pool", 0.0)))
	# reserve_tank removed in GDD v3.1 R8
	_config.set_value("energy", "total_energy_produced", float(data.get("total_energy_produced", 0.0)))
	_config.set_value("energy", "today_energy", float(data.get("today_energy", 0.0)))
	_config.set_value("energy", "today_steps_processed", int(data.get("today_steps_processed", 0)))
	_config.set_value("energy", "created_at", float(data.get("created_at", Time.get_unix_time_from_system())))
	_config.set_value("energy", "last_energy_date", String(data.get("last_energy_date", "")))
	_config.set_value("energy", "pool_full_toast_date", String(data.get("pool_full_toast_date", "")))

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
		"love_petals": int(_config.get_value("currency", "love_petals", 0)),
	}

func _write_currency() -> void:
	var data := CurrencyManager.get_save_data()
	_config.set_value("currency", "gold_coins", int(data.get("gold_coins", 0)))
	_config.set_value("currency", "diamonds", int(data.get("diamonds", 0)))
	_config.set_value("currency", "flower_petals", int(data.get("flower_petals", 0)))
	_config.set_value("currency", "love_petals", int(data.get("love_petals", 0)))

func _read_hatch() -> Dictionary:
	var cat_count := int(_config.get_value("hatch", "cat_count", 0))
	var cats: Array = []
	for i in range(cat_count):
		cats.append(_read_cat("cat_%d" % i))
	for i in range(cats.size()):
		if not _config.has_section_key("cat_%d" % i, "diary_picks"):
			var diary_picks: Array = Array(cats[i].get("diary_picks", [-1, -1, -1, -1, -1]))
			diary_picks[0] = 0
			cats[i]["diary_picks"] = diary_picks

	return {
		"slots": Array(_config.get_value("hatch", "slots", [])),
		"cats": cats,
		"hatched_count": int(_config.get_value("hatch", "hatched_count", cat_count)),
		"epic_pity_count": int(_config.get_value("hatch", "epic_pity_count", 0)),
		"legendary_pity_count": int(_config.get_value("hatch", "legendary_pity_count", 0)),
		"eggs_assigned_total": int(_config.get_value("hatch", "eggs_assigned_total", -1)),
		"bond_gained_today": int(_config.get_value("hatch", "bond_gained_today", 0)),
		"bond_date": String(_config.get_value("hatch", "bond_date", "")),
		"ad_speedup_count": int(_config.get_value("hatch", "ad_speedup_count", 0)),
		"ad_speedup_date": String(_config.get_value("hatch", "ad_speedup_date", "")),
		"has_tutorial_first_egg": bool(_config.get_value("hatch", "has_tutorial_first_egg", false)),
		"current_companion_cat_id": String(_config.get_value("hatch", "current_companion_cat_id", "")),
		"garden_expand_purchased": bool(_config.get_value("hatch", "garden_expand_purchased", false)),
	}

func _write_hatch() -> void:
	var data: Dictionary = HatchEngine.get_save_data()
	var cats: Array = Array(data.get("cats", []))
	_clear_cat_sections()
	_config.set_value("hatch", "slots", Array(data.get("slots", [])))
	_config.set_value("hatch", "hatched_count", int(data.get("hatched_count", cats.size())))
	_config.set_value("hatch", "epic_pity_count", int(data.get("epic_pity_count", 0)))
	_config.set_value("hatch", "legendary_pity_count", int(data.get("legendary_pity_count", 0)))
	_config.set_value("hatch", "eggs_assigned_total", int(data.get("eggs_assigned_total", -1)))
	_config.set_value("hatch", "bond_gained_today", int(data.get("bond_gained_today", 0)))
	_config.set_value("hatch", "bond_date", String(data.get("bond_date", "")))
	_config.set_value("hatch", "ad_speedup_count", int(data.get("ad_speedup_count", 0)))
	_config.set_value("hatch", "ad_speedup_date", String(data.get("ad_speedup_date", "")))
	_config.set_value("hatch", "has_tutorial_first_egg", bool(data.get("has_tutorial_first_egg", false)))
	_config.set_value("hatch", "current_companion_cat_id", String(data.get("current_companion_cat_id", "")))
	_config.set_value("hatch", "garden_expand_purchased", bool(data.get("garden_expand_purchased", false)))
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
		"bond_points": int(_config.get_value(section, "bond_points", 0)),
		"friendship": int(_config.get_value(section, "friendship", 0)),
		"created_at": float(_config.get_value(section, "created_at", Time.get_unix_time_from_system())),
		"diary_picks": _config.get_value(section, "diary_picks", [-1, -1, -1, -1, -1]),
		"diary_has_unread": bool(_config.get_value(section, "diary_has_unread", false)),
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
	_config.set_value(section, "bond_points", int(data.get("bond_points", 0)))
	_config.set_value(section, "friendship", int(data.get("friendship", 0)))
	_config.set_value(section, "created_at", float(data.get("created_at", Time.get_unix_time_from_system())))
	_config.set_value(section, "diary_picks", Array(data.get("diary_picks", [-1, -1, -1, -1, -1])))
	_config.set_value(section, "diary_has_unread", bool(data.get("diary_has_unread", false)))

func _clear_cat_sections() -> void:
	for section in _config.get_sections():
		if String(section).begins_with("cat_"):
			_config.erase_section(section)

func _read_achievements() -> Dictionary:
	return {
		"unlocked": _config.get_value("achievements", "unlocked", []),
		"hatch_count": _config.get_value("achievements", "hatch_count", 0),
		"album_entry_count": _config.get_value("achievements", "album_entry_count", 0),
		"collected_breeds": _config.get_value("achievements", "collected_breeds", []),
		"postcard_count": _config.get_value("achievements", "postcard_count", 0),
		"city_postcard_count": _config.get_value("achievements", "city_postcard_count", 0),
		"collected_city_postcards": _config.get_value("achievements", "collected_city_postcards", []),
		"max_level": _config.get_value("achievements", "max_level", 0),
		"max_affection": _config.get_value("achievements", "max_affection", 0),
		"total_steps": _config.get_value("achievements", "total_steps", 0),
		"step_streak": _config.get_value("achievements", "step_streak", 0),
		"daily_step_accumulator": _config.get_value("achievements", "daily_step_accumulator", 0),
		"step_streak_checked_today": _config.get_value("achievements", "step_streak_checked_today", ""),
		"cat_streak": _config.get_value("achievements", "cat_streak", {}),
		"cat_daily_interaction_count": _config.get_value("achievements", "cat_daily_interaction_count", {}),
		"cat_streak_checked_today": _config.get_value("achievements", "cat_streak_checked_today", ""),
		"midnight_accessed": _config.get_value("achievements", "midnight_accessed", false),
	}

# ── GDD v2.17 Relinquish section ──

func _read_relinquish() -> Dictionary:
	return {
		"this_week_petals_gained": int(_config.get_value("relinquish", "this_week_petals_gained", 0)),
		"emergency_exemptions_used": int(_config.get_value("relinquish", "emergency_exemptions_used", 0)),
		"week_reset_timestamp": int(_config.get_value("relinquish", "week_reset_timestamp", 0)),
		"relinquished_event_ids": Array(_config.get_value("relinquish", "relinquished_event_ids", [])),
	}

func _write_relinquish() -> void:
	var rs := get_node_or_null("/root/RelinquishSystem")
	if rs and rs.has_method("get_save_data"):
		var data: Dictionary = rs.get_save_data()
		_config.set_value("relinquish", "this_week_petals_gained", int(data.get("this_week_petals_gained", 0)))
		_config.set_value("relinquish", "emergency_exemptions_used", int(data.get("emergency_exemptions_used", 0)))
		_config.set_value("relinquish", "week_reset_timestamp", int(data.get("week_reset_timestamp", 0)))
		_config.set_value("relinquish", "relinquished_event_ids", Array(data.get("relinquished_event_ids", [])))

func _read_package() -> Dictionary:
	var data := {
		"backpack_max_capacity": int(_config.get_value("package", "backpack_max_capacity", -1)),
	}
	# 兼容旧版 SaveManager 把猫包容量写在 relinquish section 的存档。
	if int(data["backpack_max_capacity"]) < 0:
		data["backpack_max_capacity"] = int(_config.get_value("relinquish", "backpack_max_capacity", 24))
	return data

func _write_package() -> void:
	var ps := get_node_or_null("/root/PackageSystem")
	if ps == null or not ps.has_method("get_save_data"):
		return
	var data: Dictionary = ps.get_save_data()
	_config.set_value("package", "backpack_max_capacity", int(data.get("backpack_max_capacity", 24)))

func _read_mail() -> Dictionary:
	return {
		"last_mail_check_date": String(_config.get_value("mail", "last_mail_check_date", "")),
		"mailed_holidays": Array(_config.get_value("mail", "mailed_holidays", [])),
	}

func _write_mail() -> void:
	var ms := get_node_or_null("/root/MailSystem")
	if ms == null or not ms.has_method("get_save_data"):
		return
	var data: Dictionary = ms.get_save_data()
	_config.set_value("mail", "last_mail_check_date", String(data.get("last_mail_check_date", "")))
	_config.set_value("mail", "mailed_holidays", Array(data.get("mailed_holidays", [])))

func _check_week_reset() -> void:
	var now_unix: int = int(Time.get_unix_time_from_system())
	var stored: int = int(_config.get_value("relinquish", "week_reset_timestamp", 0))
	if stored == 0 or now_unix >= stored:
		var next_monday: int = _next_monday_midnight_unix()
		_config.set_value("relinquish", "week_reset_timestamp", next_monday)
		if stored != 0:
			_config.set_value("relinquish", "this_week_petals_gained", 0)
			_config.set_value("relinquish", "emergency_exemptions_used", 0)

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
	_config.set_value("achievements", "album_entry_count", data.get("album_entry_count", 0))
	_config.set_value("achievements", "collected_breeds", data.get("collected_breeds", []))
	_config.set_value("achievements", "postcard_count", data.get("postcard_count", 0))
	_config.set_value("achievements", "city_postcard_count", data.get("city_postcard_count", 0))
	_config.set_value("achievements", "collected_city_postcards", data.get("collected_city_postcards", []))
	_config.set_value("achievements", "max_level", data.get("max_level", 0))
	_config.set_value("achievements", "max_affection", data.get("max_affection", 0))
	_config.set_value("achievements", "total_steps", data.get("total_steps", 0))
	_config.set_value("achievements", "step_streak", data.get("step_streak", 0))
	_config.set_value("achievements", "daily_step_accumulator", data.get("daily_step_accumulator", 0))
	_config.set_value("achievements", "step_streak_checked_today", data.get("step_streak_checked_today", ""))
	_config.set_value("achievements", "cat_streak", data.get("cat_streak", {}))
	_config.set_value("achievements", "cat_daily_interaction_count", data.get("cat_daily_interaction_count", {}))
	_config.set_value("achievements", "cat_streak_checked_today", data.get("cat_streak_checked_today", ""))
	_config.set_value("achievements", "midnight_accessed", data.get("midnight_accessed", false))

# ── Workshop section ──

func _read_workshop() -> Dictionary:
	var data := {
		"workshop_manager": _config.get_value("workshop", "manager_data", {}),
		"workshop_data": _config.get_value("workshop", "workshop_data", {}),
		"workshop_inventory": _config.get_value("workshop", "inventory_data", {}),
	}
	if (
		(data["workshop_manager"] is Dictionary and not Dictionary(data["workshop_manager"]).is_empty())
		or (data["workshop_data"] is Dictionary and not Dictionary(data["workshop_data"]).is_empty())
		or (data["workshop_inventory"] is Dictionary and not Dictionary(data["workshop_inventory"]).is_empty())
	):
		return data
	var legacy := ConfigFile.new()
	if legacy.load("user://workshop.cfg") == OK:
		data["workshop_manager"] = legacy.get_value("workshop", "manager_data", legacy.get_value("state", "manager_data", {}))
		data["workshop_data"] = legacy.get_value("workshop", "workshop_data", legacy.get_value("state", "workshop_data", {}))
		data["workshop_inventory"] = legacy.get_value("workshop", "inventory_data", legacy.get_value("state", "inventory_data", {}))
	return data

func _write_workshop() -> void:
	var wm := get_node_or_null("/root/WorkshopManager")
	if wm and wm.has_method("get_save_data"):
		_config.set_value("workshop", "manager_data", wm.get_save_data())
	var wd := get_node_or_null("/root/WorkshopData")
	if wd and wd.has_method("get_save_data"):
		_config.set_value("workshop", "workshop_data", wd.get_save_data())
	var gi := get_node_or_null("/root/GiftInventory")
	if gi and gi.has_method("get_save_data"):
		_config.set_value("workshop", "inventory_data", gi.get_save_data())

func _read_inventory() -> Dictionary:
	var data: Dictionary = Dictionary(_config.get_value("inventory", "state", {}))
	if not data.is_empty():
		return data
	# 从旧版独立 inventory.cfg 迁移一次，之后由主存档接管。
	var legacy := ConfigFile.new()
	if legacy.load("user://inventory.cfg") == OK:
		var counts: Dictionary = {}
		for item_type in ["ingredient_shard", "decoration_shard", "snack", "hidden_item", "treasure_box", "decor"]:
			counts[item_type] = int(legacy.get_value("inventory", item_type, 0))
		var parsed = JSON.parse_string(str(legacy.get_value("inventory", "idempotency", "[]")))
		data = {"counts": counts, "processed_ids": parsed if parsed is Array else []}
	return data

func _write_inventory() -> void:
	var inv := get_node_or_null("/root/InventoryManager")
	if inv == null or not inv.has_method("get_save_data"):
		return
	_config.set_value("inventory", "state", inv.get_save_data())

func _read_explore() -> Dictionary:
	var data: Dictionary = Dictionary(_config.get_value("explore", "state", {}))
	if not data.is_empty():
		return data
	var legacy := ConfigFile.new()
	if legacy.load("user://explore.cfg") == OK:
		data = Dictionary(legacy.get_value("explore", "state", {}))
		if data.is_empty():
			data = {
				"explorers": legacy.get_value("explore", "explorers", {}),
				"hatched_count": legacy.get_value("explore", "hatched_count", 0),
				"collected_postcards": legacy.get_value("explore", "collected_postcards", []),
				"travel_stamps": legacy.get_value("explore", "travel_stamps", 0),
				"first_explore_flags": legacy.get_value("explore", "first_explore_flags", {}),
				"last_reward_type": legacy.get_value("explore", "last_reward_type", {}),
				"daily_location_pools": legacy.get_value("explore", "daily_location_pools", {}),
				"last_chosen_location": legacy.get_value("explore", "last_chosen_location", {}),
				"last_location_chosen_is_high": legacy.get_value("explore", "last_location_chosen_is_high", {}),
			}
	return data

func _write_explore() -> void:
	if ExploreEngine and ExploreEngine.has_method("get_save_data"):
		_config.set_value("explore", "state", ExploreEngine.get_save_data())

func _read_interaction() -> Dictionary:
	var data: Dictionary = Dictionary(_config.get_value("interaction", "state", {}))
	if not data.is_empty():
		return data
	var legacy := ConfigFile.new()
	if legacy.load("user://interaction.cfg") == OK and legacy.has_section("cooldowns"):
		var cooldowns: Dictionary = {}
		for cat_id in legacy.get_section_keys("cooldowns"):
			var per_type: Dictionary = {}
			for pair in String(legacy.get_value("cooldowns", cat_id, "")).split(",", false):
				var kv := pair.split(":", false)
				if kv.size() == 2:
					per_type[kv[0]] = float(kv[1])
			if not per_type.is_empty():
				cooldowns[cat_id] = per_type
		data = {"cat_cooldowns": cooldowns, "affection": {}}
	return data

func _write_interaction() -> void:
	var interaction := get_node_or_null("/root/InteractionSystem")
	if interaction and interaction.has_method("get_save_data"):
		_config.set_value("interaction", "state", interaction.get_save_data())

func _read_board() -> Dictionary:
	var data: Dictionary = Dictionary(_config.get_value("board", "state", {}))
	if not data.is_empty():
		return data
	var legacy := ConfigFile.new()
	if legacy.load("user://cat_merge_save.cfg") == OK:
		data = {
			"has_session": legacy.has_section_key("session", "state"),
			"state": legacy.get_value("session", "state", {}),
			"total_wins": legacy.get_value("meta", "total_wins", 0),
			"board_level": legacy.get_value("meta", "board_level", 1),
			"first_three_star_claimed": legacy.get_value("meta", "first_three_star_claimed", false),
			"claimed_milestones": legacy.get_value("meta", "claimed_milestones", []),
			"earned_titles": legacy.get_value("meta", "earned_titles", []),
			"board_decor_counts": legacy.get_value("meta", "board_decor_counts", {}),
		}
	return data

func _write_board() -> void:
	var board := get_node_or_null("/root/LevelStateManager")
	if board and board.has_method("get_save_data"):
		_config.set_value("board", "state", board.get_save_data())

func _read_signin() -> Dictionary:
	var data: Dictionary = Dictionary(_config.get_value("signin", "state", {}))
	if not data.is_empty():
		return data
	if SigninSystem and SigninSystem.has_method("get_save_data"):
		return SigninSystem.get_save_data()
	return {}

func _write_signin() -> void:
	if SigninSystem and SigninSystem.has_method("get_save_data"):
		_config.set_value("signin", "state", SigninSystem.get_save_data())

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

# ── IAPProvider section ──

func _read_iap() -> Dictionary:
	return {
		"ads_removed": bool(_config.get_value("iap_store", "ads_removed", false)),
		"garden_expand_purchased": bool(_config.get_value("iap_store", "garden_expand_purchased", false)),
		"breed_fast_unlock": bool(_config.get_value("iap_store", "breed_fast_unlock", false)),
		"newbie_pack_purchased": bool(_config.get_value("iap_store", "newbie_pack_purchased", false)),
		"limited_skin_owned": bool(_config.get_value("iap_store", "limited_skin_owned", false)),
		"monthly_card_end_time": float(_config.get_value("iap_store", "monthly_card_end_time", 0.0)),
		"monthly_card_last_grant_date": String(_config.get_value("iap_store", "monthly_card_last_grant_date", "")),
		"makeup_cards": max(int(_config.get_value("iap_store", "makeup_cards", 0)), 0),
	}

func _write_iap() -> void:
	var iap := get_node_or_null("/root/IAPProvider")
	if iap == null or not iap.has_method("get_save_data"):
		return
	var data: Dictionary = iap.get_save_data()
	_config.set_value("iap_store", "ads_removed", bool(data.get("ads_removed", false)))
	_config.set_value("iap_store", "garden_expand_purchased", bool(data.get("garden_expand_purchased", false)))
	_config.set_value("iap_store", "breed_fast_unlock", bool(data.get("breed_fast_unlock", false)))
	_config.set_value("iap_store", "newbie_pack_purchased", bool(data.get("newbie_pack_purchased", false)))
	_config.set_value("iap_store", "limited_skin_owned", bool(data.get("limited_skin_owned", false)))
	_config.set_value("iap_store", "monthly_card_end_time", float(data.get("monthly_card_end_time", 0.0)))
	_config.set_value("iap_store", "monthly_card_last_grant_date", String(data.get("monthly_card_last_grant_date", "")))
	_config.set_value("iap_store", "makeup_cards", max(int(data.get("makeup_cards", 0)), 0))

# ── TicketManager section ──

func _read_tickets() -> Dictionary:
	return {
		"tickets": int(_config.get_value("tickets", "tickets", 0)),
		"daily_step_progress": int(_config.get_value("tickets", "daily_step_progress", 0)),
		"daily_step_tickets": int(_config.get_value("tickets", "daily_step_tickets", 0)),
		"daily_interaction_count": int(_config.get_value("tickets", "daily_interaction_count", 0)),
		"daily_interaction_tickets": int(_config.get_value("tickets", "daily_interaction_tickets", 0)),
		"daily_ad_tickets": int(_config.get_value("tickets", "daily_ad_tickets", 0)),
		"daily_coin_tickets": int(_config.get_value("tickets", "daily_coin_tickets", 0)),
		"last_ticket_date": String(_config.get_value("tickets", "last_ticket_date", "")),
		"login_claimed_today": bool(_config.get_value("tickets", "login_claimed_today", false)),
	}

func _write_tickets() -> void:
	var tm := get_node_or_null("/root/TicketManager")
	if tm == null or not tm.has_method("get_save_data"):
		return
	var data: Dictionary = tm.get_save_data()
	_config.set_value("tickets", "tickets", int(data.get("tickets", 0)))
	_config.set_value("tickets", "daily_step_progress", int(data.get("daily_step_progress", 0)))
	_config.set_value("tickets", "daily_step_tickets", int(data.get("daily_step_tickets", 0)))
	_config.set_value("tickets", "daily_interaction_count", int(data.get("daily_interaction_count", 0)))
	_config.set_value("tickets", "daily_interaction_tickets", int(data.get("daily_interaction_tickets", 0)))
	_config.set_value("tickets", "daily_ad_tickets", int(data.get("daily_ad_tickets", 0)))
	_config.set_value("tickets", "daily_coin_tickets", int(data.get("daily_coin_tickets", 0)))
	_config.set_value("tickets", "last_ticket_date", String(data.get("last_ticket_date", "")))
	_config.set_value("tickets", "login_claimed_today", bool(data.get("login_claimed_today", false)))

# ── Backpack daily feed section ──

func get_feed_daily_data() -> Dictionary:
	if _feed_daily_state.is_empty():
		_feed_daily_state = _read_feed_daily()
	return _feed_daily_state.duplicate(true)

func set_feed_daily_data(data: Dictionary) -> void:
	_feed_daily_state = {
		"date": String(data.get("date", "")),
		"counts": Dictionary(data.get("counts", {})).duplicate(true),
	}

func _read_feed_daily() -> Dictionary:
	var data: Dictionary = Dictionary(_config.get_value("backpack_feed", "state", {}))
	if not data.is_empty():
		return {
			"date": String(data.get("date", "")),
			"counts": Dictionary(data.get("counts", {})).duplicate(true),
		}
	# 兼容旧版背包页的 backpack.cfg，首次保存后迁入主存档。
	var legacy := ConfigFile.new()
	if legacy.load("user://backpack.cfg") == OK and legacy.has_section("feed_daily"):
		var counts: Dictionary = {}
		for cat_id in legacy.get_section_keys("feed_daily"):
			if cat_id != "date":
				counts[cat_id] = int(legacy.get_value("feed_daily", cat_id, 0))
		return {
			"date": String(legacy.get_value("feed_daily", "date", "")),
			"counts": counts,
		}
	return {"date": "", "counts": {}}

func _write_feed_daily() -> void:
	var data := get_feed_daily_data()
	_config.set_value("backpack_feed", "state", data)
