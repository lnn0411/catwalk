extends Node

const SAVE_PATH: String = "user://interaction.cfg"

static func get_cooldown_minutes(type: String) -> int:
	match type:
		"feed":
			return 240
		"pet":
			return 120
		"play":
			return 360
		"photo":
			return 60
		_:
			return 0

static func get_affection_gain(type: String) -> int:
	match type:
		"feed":
			return 5
		"pet":
			return 3
		"play":
			return 4
		"photo":
			return 2
		_:
			return 0

static func _load() -> ConfigFile:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg

static func _save(cfg: ConfigFile) -> void:
	cfg.save(SAVE_PATH)

static func can_interact(cat_id: String, type: String) -> bool:
	var cfg: ConfigFile = _load()
	var last: float = cfg.get_value("last", cat_id + "_" + type, -1.0)
	if last < 0.0:
		return true
	var now: float = Time.get_unix_time_from_system()
	var cooldown: float = get_cooldown_minutes(type) * 60.0
	return (now - last) >= cooldown

static func do_interact(cat_id: String, type: String) -> int:
	if not can_interact(cat_id, type):
		return 0
	var cfg: ConfigFile = _load()
	var now: float = Time.get_unix_time_from_system()
	cfg.set_value("last", cat_id + "_" + type, now)
	var gain: int = get_affection_gain(type)
	var current: int = cfg.get_value("affection", cat_id, 0)
	cfg.set_value("affection", cat_id, current + gain)
	_save(cfg)
	return gain

static func get_affection(cat_id: String) -> int:
	var cfg: ConfigFile = _load()
	return cfg.get_value("affection", cat_id, 0)

static func _override_last_interact(cat_id: String, type: String, seconds_ago: float) -> void:
	var cfg: ConfigFile = _load()
	var now: float = Time.get_unix_time_from_system()
	cfg.set_value("last", cat_id + "_" + type, now - seconds_ago)
	_save(cfg)

static func reset_all() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.save(SAVE_PATH)
