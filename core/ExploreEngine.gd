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
const CITY_LOCATION_TYPES := [
	"convenience_store", "park_bench", "subway_station", "bookstore", "cafe",
	"hospital_corridor", "sky_bridge", "night_market", "playground", "rainy_day",
]
const BREED_LOCATION_PREFERENCES := {
	"orange": {
		"high": ["convenience_store", "park_bench"],
		"medium": ["bookstore", "cafe"],
		"low": ["hospital_corridor", "subway_station"],
	},
	"british": {
		"high": ["bookstore", "cafe"],
		"medium": ["park_bench", "cafe"],
		"low": ["convenience_store", "night_market"],
	},
	"siamese": {
		"high": ["subway_station", "night_market", "playground"],
		"medium": ["convenience_store"],
		"low": ["bookstore", "hospital_corridor"],
	},
}

# cat_id -> { departure_time, return_time, duration_hours, is_exploring }
static var _explorers: Dictionary = {}
static var _hatched_count: int = 0
static var _collected_postcards: Array = []
static var _first_explore_flags: Dictionary = {}
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
	_first_explore_flags = {}
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
static func on_hatch() -> void:
	_hatched_count += 1
	_save()

static func dispatch(cat_id: String, duration_hours: int) -> bool:
	if not VALID_DURATIONS.has(duration_hours):
		return false
	if is_exploring(cat_id):
		return false
	if _active_count() >= _available_slot_count():
		return false
	var now := _safe_unix_time()
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
	return _safe_unix_time() >= return_time

static func collect(cat_id: String, cat_species: String = "") -> Dictionary:
	if not _explorers.has(cat_id):
		return {}
	if not is_returned(cat_id):
		return {}
	var entry: Dictionary = _explorers[cat_id].duplicate()
	_explorers.erase(cat_id)
	var reward_type := _roll_reward_type(cat_id)
	var postcard_id := ""
	if reward_type == "postcard":
		var species_of_cat := cat_species if cat_species != "" else _get_cat_species(cat_id)
		postcard_id = _pick_postcard_for_cat(species_of_cat)
		if postcard_id != "":
			_collected_postcards.append(postcard_id)
			var postcard = PostcardData.get_by_id(postcard_id)
			var location_type := String(postcard.location_type) if postcard != null else ""
			if EventBus:
				EventBus.emit_postcard_obtained(postcard_id, location_type)
		else:
			reward_type = "ingredient"
	entry["reward_type"] = reward_type
	entry["postcard_id"] = postcard_id
	_save()
	return entry

# ---- 奖励 ----
static func _roll_reward_type(cat_id: String) -> String:
	if not _first_explore_flags.has(cat_id):
		_first_explore_flags[cat_id] = true
		_last_reward_type[cat_id] = "postcard"
		return "postcard"
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


static func _pick_postcard_for_cat(cat_species: String) -> String:
	# High probability locations per breed (GDD §14.4)
	var pref_map = {
		"orange": {"high": ["convenience_store", "park_bench"], "medium": ["bookstore", "cafe"], "low": ["hospital_corridor", "subway_station"]},
		"british": {"high": ["bookstore", "cafe"], "medium": ["park_bench"], "low": ["convenience_store", "night_market"]},
		"siamese": {"high": ["subway_station", "night_market", "playground"], "medium": ["convenience_store"], "low": ["bookstore", "hospital_corridor"]}
	}
	var pref = pref_map.get(cat_species, pref_map["orange"])
	# Get PostcardData class
	var PD = load("res://scripts/collect_book/postcard_data.gd")
	var all_ids = PD.get_all_ids()
	# Filter already collected
	var available = []
	for pid in all_ids:
		if pid not in _collected_postcards:
			available.append(pid)
	if available.is_empty():
		return ""
	# Try by breed preference tiers
	for tier in ["high", "medium", "low"]:
		var preferred = pref[tier]
		var candidates = []
		for pid in available:
			var pd = PD.get_by_id(pid)
			if pd and pd.sender_cat_species == cat_species and pd.location_type in preferred:
				candidates.append(pid)
		if not candidates.is_empty():
			return candidates[_rng.randi() % candidates.size()]
	# Fallback: any uncollected for this breed
	var breed_candidates = []
	for pid in available:
		var pd = PD.get_by_id(pid)
		if pd and pd.sender_cat_species == cat_species:
			breed_candidates.append(pid)
	if not breed_candidates.is_empty():
		return breed_candidates[_rng.randi() % breed_candidates.size()]
	# Last fallback: any postcard
	return available[_rng.randi() % available.size()]

# ---- 测试辅助 ----
static func get_remaining_seconds(cat_id: String) -> int:
	if not _explorers.has(cat_id):
		return 0
	var return_time := float(_explorers[cat_id].get("return_time", 0.0))
	var now := _safe_unix_time()
	var remaining := return_time - now
	return int(ceil(max(remaining, 0.0)))

static func get_exploring_count() -> int:
	return _active_count()

static func get_active_cat_ids() -> Array:
	var ids := []
	for cat_id in _explorers:
		if bool(_explorers[cat_id].get("is_exploring", false)):
			ids.append(cat_id)
	return ids

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


static func _get_cat_species(cat_id: String) -> String:
	if HatchEngine and HatchEngine.has_method("get_cat_by_id"):
		var cat = HatchEngine.get_cat_by_id(cat_id)
		if cat is Dictionary:
			return _normalize_species(String(cat.get("species", cat.get("breed", "orange"))))
		if cat != null and "species" in cat:
			return _normalize_species(String(cat.species))
	return "orange"


static func _normalize_species(cat_species: String) -> String:
	if cat_species == "british_shorthair":
		return "british"
	if cat_species in BREED_LOCATION_PREFERENCES:
		return cat_species
	return "orange"

static func _safe_unix_time() -> float:
	if Engine.has_singleton("TimeGuard") and Engine.get_singleton("TimeGuard").has_method("get_safe_unix_time"):
		return Engine.get_singleton("TimeGuard").get_safe_unix_time()
	return Time.get_unix_time_from_system()

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "explorers", _explorers)
	cfg.set_value(SECTION, "hatched_count", _hatched_count)
	cfg.set_value(SECTION, "collected_postcards", _collected_postcards)
	cfg.set_value(SECTION, "first_explore_flags", _first_explore_flags)
	if cfg.save(CFG_PATH) != OK:
		push_error("[ExploreEngine] Save failed: %s" % CFG_PATH)

static func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	_explorers = cfg.get_value(SECTION, "explorers", {})
	_hatched_count = int(cfg.get_value(SECTION, "hatched_count", 0))
	_collected_postcards = cfg.get_value(SECTION, "collected_postcards", [])
	_first_explore_flags = cfg.get_value(SECTION, "first_explore_flags", {})
