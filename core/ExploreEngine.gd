# ExploreEngine — 猫咪探索系统 (Autoload)
# 不要加 class_name：已注册为同名 autoload，class_name 会与单例命名冲突。
# 用独立的 user://explore.cfg 存档，不参与 SaveManager 的 save.cfg。
# 测试以 load("res://core/ExploreEngine.gd") 直接驱动脚本资源，故 API 全为 static。
extends Node

const CFG_PATH := "user://explore.cfg"
const SECTION := "explore"
const SLOT_COUNT := 2
# slot1 解锁所需的累计孵化数。
const SLOT1_HATCH_REQ := 5
const SECONDS_PER_HOUR := 3600
const VALID_DURATIONS := [1, 2, 4]

# cat_id -> { departure_time, return_time, duration_hours, is_exploring }
static var _explorers: Dictionary = {}
static var _hatched_count: int = 0
static var _collected_postcards: Array = []
# cat_id -> 上一次 roll 出的奖励类型，用于「连续 postcard 防重复」。
static var _last_reward_type: Dictionary = {}
static var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_load()

# ---- 状态 ----
static func reset_all() -> void:
	_explorers = {}
	_hatched_count = 0
	_collected_postcards = []
	_last_reward_type = {}
	_rng.randomize()
	_save()

static func get_slot_count() -> int:
	return SLOT_COUNT

static func is_slot_available(slot_index: int) -> bool:
	if slot_index == 0:
		return true
	if slot_index == 1:
		return _hatched_count >= SLOT1_HATCH_REQ
	return false

# ---- 派遣 ----
static func dispatch(cat_id: String, duration_hours: int) -> bool:
	if not VALID_DURATIONS.has(duration_hours):
		return false
	if is_exploring(cat_id):
		return false
	if _active_count() >= _available_slot_count():
		return false
	var now := Time.get_unix_time_from_system()
	_explorers[cat_id] = {
		"departure_time": now,
		"return_time": now + duration_hours * SECONDS_PER_HOUR,
		"duration_hours": duration_hours,
		"is_exploring": true,
	}
	_save()
	return true

static func is_exploring(cat_id: String) -> bool:
	return _explorers.has(cat_id) and bool(_explorers[cat_id].get("is_exploring", false))

static func is_returned(cat_id: String) -> bool:
	if not _explorers.has(cat_id):
		return false
	var return_time := float(_explorers[cat_id].get("return_time", 0.0))
	return Time.get_unix_time_from_system() >= return_time

# ---- 奖励 ----
static func _roll_reward_type(cat_id: String) -> String:
	var r := _rng.randf()
	var t: String
	if r < 0.60:
		t = "postcard"
	elif r < 0.85:
		t = "ingredient"
	elif r < 0.95:
		t = "decoration"
	else:
		t = "hidden"
	# 防重复：同一猫连续 postcard 时改为 ingredient。
	if t == "postcard" and String(_last_reward_type.get(cat_id, "")) == "postcard":
		t = "ingredient"
	_last_reward_type[cat_id] = t
	return t

# ---- 测试辅助 ----
static func _override_hatched_count(count: int) -> void:
	_hatched_count = max(count, 0)

static func _override_return_time(cat_id: String, unix_time: float) -> void:
	if _explorers.has(cat_id):
		_explorers[cat_id]["return_time"] = unix_time

static func _mock_collected_postcards(ids: Array) -> void:
	_collected_postcards = ids.duplicate()

# ---- 内部 ----
static func _available_slot_count() -> int:
	var n := 0
	for i in range(SLOT_COUNT):
		if is_slot_available(i):
			n += 1
	return n

static func _active_count() -> int:
	var n := 0
	for cat_id in _explorers:
		if bool(_explorers[cat_id].get("is_exploring", false)):
			n += 1
	return n

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "explorers", _explorers)
	cfg.set_value(SECTION, "hatched_count", _hatched_count)
	cfg.set_value(SECTION, "collected_postcards", _collected_postcards)
	if cfg.save(CFG_PATH) != OK:
		push_error("[ExploreEngine] Save failed: %s" % CFG_PATH)

static func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	_explorers = cfg.get_value(SECTION, "explorers", {})
	_hatched_count = int(cfg.get_value(SECTION, "hatched_count", 0))
	_collected_postcards = cfg.get_value(SECTION, "collected_postcards", [])
