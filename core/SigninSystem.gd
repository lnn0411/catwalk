extends Node

const SAVE_PATH: String = "user://signin.cfg"
const CYCLE_LENGTH: int = 7
const MAX_MAKEUP: int = 2

static var _date_override: String = ""

static func _today() -> String:
	if _date_override != "":
		return _date_override
	return Time.get_date_string_from_system()

static func _to_days(date_str: String) -> int:
	var dt := Time.get_datetime_dict_from_datetime_string(date_str + "T12:00:00", false)
	if dt.is_empty():
		return 0
	return int(Time.get_unix_time_from_datetime_dict(dt) / 86400)

static func _shift_date(date_str: String, days: int) -> String:
	var parts := date_str.split("-", false)
	var year: int = int(parts[0])
	var month: int = int(parts[1])
	var day: int = int(parts[2])
	day += int(days)
	while day > 30:
		day -= 30
		month += 1
	while month > 12:
		month -= 12
		year += 1
	while day <= 0:
		month -= 1
		if month <= 0:
			month = 12
			year -= 1
		day += 30
	return "%04d-%02d-%02d" % [year, month, day]

static func _load() -> ConfigFile:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg

static func _save(cfg: ConfigFile) -> void:
	cfg.save(SAVE_PATH)

static func _reward_for(day: int) -> String:
	match day:
		1: return "金币100"
		2: return "金币200"
		3: return "金币150"
		4: return "金币200"
		5: return "金币100"
		6: return "金币150"
		7: return "宝箱"
		_: return "金币100"

static func signin() -> Dictionary:
	var cfg: ConfigFile = _load()
	var today: String = _today()
	var last: String = cfg.get_value("state", "last_date", "")
	var day: int = cfg.get_value("state", "day", 0)
	var streak: int = cfg.get_value("state", "streak", 0)
	var makeup_used: int = cfg.get_value("state", "makeup_used", 0)

	if last == "":
		day = 1
		streak = 1
		makeup_used = 0
	else:
		var gap: int = _to_days(today) - _to_days(last)
		if gap <= 0:
			return {"day": day, "reward": _reward_for(day)}
		elif gap == 1:
			if day >= CYCLE_LENGTH:
				day = 1
				makeup_used = 0
			else:
				day += 1
			streak += 1
		elif gap >= 2:
			day = max(1, day - gap)
			streak = 1
			if gap >= 3:
				makeup_used = 0

	var reward: String = _reward_for(day)
	cfg.set_value("state", "last_date", today)
	cfg.set_value("state", "day", day)
	cfg.set_value("state", "streak", streak)
	cfg.set_value("state", "makeup_used", makeup_used)
	_save(cfg)
	return {"day": day, "reward": reward}

static func get_current_day() -> int:
	var cfg: ConfigFile = _load()
	return cfg.get_value("state", "day", 0)

static func get_streak() -> int:
	var cfg: ConfigFile = _load()
	return cfg.get_value("state", "streak", 0)

static func set_date_override(date_str: String) -> void:
	_date_override = date_str

static func set_last_signin_days_ago(n: int) -> void:
	var cfg: ConfigFile = _load()
	cfg.set_value("state", "last_date", _shift_date(_today(), -n))
	_save(cfg)

static func use_makeup_card() -> bool:
	var cfg: ConfigFile = _load()
	var makeup_used: int = cfg.get_value("state", "makeup_used", 0)
	if makeup_used >= MAX_MAKEUP:
		return false
	var day: int = cfg.get_value("state", "day", 0)
	day = min(day + 1, CYCLE_LENGTH)
	cfg.set_value("state", "day", day)
	cfg.set_value("state", "makeup_used", makeup_used + 1)
	_save(cfg)
	return true

static func _simulate_next_day() -> void:
	_date_override = _shift_date(_today(), 1)

static func reset_all() -> void:
	_date_override = ""
	var cfg: ConfigFile = ConfigFile.new()
	cfg.save(SAVE_PATH)
