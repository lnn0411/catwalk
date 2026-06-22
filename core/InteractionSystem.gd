extends Node

const SAVE_PATH: String = "user://interaction.cfg"

signal interaction_performed(cat_id: String, type: String)

var _global_cooldowns := {}

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

func _ready() -> void:
	pass

func can_interact_global(type: String) -> bool:
	if type == "pet":
		return true
	var next_time: float = _global_cooldowns.get(type, 0.0)
	return Time.get_unix_time_from_system() >= next_time

func do_interact_global(cat_id: String, type: String) -> bool:
	if not can_interact_global(type):
		return false
	if is_interaction_blocked(cat_id, type):
		return false

	var cooldown := 30.0 if type == "feed" else 60.0 if type == "play" else 0.0
	if cooldown > 0.0:
		_global_cooldowns[type] = Time.get_unix_time_from_system() + cooldown

	InteractionSystem.do_interact(cat_id, type)

	var esm = get_node_or_null("/root/EmotionStateMachine")
	if esm != null and esm.has_method("register_interaction"):
		esm.register_interaction(cat_id)

	interaction_performed.emit(cat_id, type)
	return true

func get_global_cooldown_remaining(type: String) -> float:
	if type == "pet":
		return 0.0
	var next_time: float = _global_cooldowns.get(type, 0.0)
	return maxf(0.0, next_time - Time.get_unix_time_from_system())

func is_interaction_blocked(cat_id: String, type: String) -> bool:
	var esm = get_node_or_null("/root/EmotionStateMachine")
	if esm != null and esm.has_method("is_annoyed") and esm.is_annoyed(cat_id):
		if type != "pet":
			return true
	if esm != null and esm.has_method("is_sleeping") and esm.is_sleeping(cat_id):
		if type == "pet":
			return false
		return true
	return false

func get_affection_gain_global(type: String) -> int:
	return get_affection_gain(type)

func get_feed_cooldown() -> float:
	return 30.0

func get_play_cooldown() -> float:
	return 60.0
