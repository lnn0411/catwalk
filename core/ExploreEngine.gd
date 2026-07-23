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
const WeeklySpotlightS := preload("res://scripts/postcard/WeeklySpotlightManager.gd")
const BREED_LOCATION_PREFERENCES := {
	"orange": {
		"high": ["convenience_store", "park_bench"],
		"medium": ["bookstore", "cafe"],
		"low": ["hospital_corridor", "subway_station", "rainy_day"],
	},
	"british": {
		"high": ["bookstore", "cafe"],
		"medium": ["park_bench"],
		"low": ["convenience_store", "night_market", "rainy_day"],
	},
	"siamese": {
		"high": ["subway_station", "night_market", "playground"],
		"medium": ["convenience_store"],
		"low": ["bookstore", "hospital_corridor", "rainy_day"],
	},
}

# cat_id -> { departure_time, return_time, duration_hours, is_exploring }
static var _explorers: Dictionary = {}
static var _hatched_count: int = 0
static var _collected_postcards: Array = []
# C1 邮票（P3）：明信片池抽干后的替代产出，附带保底金币
const STAMP_FALLBACK_GOLD := 50
static var _travel_stamps: int = 0

# 公开 getter
static func get_collected_postcard_ids() -> Array:
	return _collected_postcards.duplicate()

static func get_travel_stamp_count() -> int:
	return _travel_stamps
static var _first_explore_flags: Dictionary = {}
# cat_id -> 上一次 roll 出的奖励类型，用于「连续 postcard 防重复」。
static var _last_reward_type: Dictionary = {}
# cat_id -> {high, medium, low, pool_date}：每日刷新的地点候选池。
static var _daily_location_pools: Dictionary = {}
# cat_id -> 上一次派遣所选地点。
static var _last_chosen_location: Dictionary = {}
# cat_id -> 上一次所选地点是否命中高偏好（决定返回物 +1）。
static var _last_location_chosen_is_high: Dictionary = {}
static var _spotlight_boost := 0.15
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
	_daily_location_pools = {}
	_last_chosen_location = {}
	_last_location_chosen_is_high = {}
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

# A3 状态矩阵硬校验（UI 侧 CatStateGuard 预检负责文案，此处兜底防绕过）
static func _guard_allows_dispatch(cat_id: String) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return true
	var guard = tree.root.get_node_or_null("/root/CatStateGuard")
	if guard == null:
		return true
	return guard.is_allowed(guard.Action.DISPATCH, cat_id)

static func dispatch(cat_id: String, duration_hours: int) -> bool:
	if not VALID_DURATIONS.has(duration_hours):
		return false
	if is_exploring(cat_id):
		return false
	if not _guard_allows_dispatch(cat_id):
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

# 每天为每只猫随机生成 3 个目的地（1 高偏好 + 1 中 + 1 低偏好），跨天自动刷新。
static func get_location_choices(cat_id: String, cat_species: String) -> Dictionary:
	_check_daily_pool_reset()
	if _daily_location_pools.has(cat_id):
		return _daily_location_pools[cat_id].duplicate()
	var species_key := _normalize_species(cat_species)
	var pref: Dictionary = BREED_LOCATION_PREFERENCES.get(species_key, BREED_LOCATION_PREFERENCES["orange"])
	var pool := {}
	# 每个偏好层随机选 1 个。
	for tier in ["high", "medium", "low"]:
		var options: Array = pref.get(tier, [])
		if options.is_empty():
			continue
		pool[tier] = options[_rng.randi() % options.size()]
	# 去重保障：若 high/medium/low 撞车，重新 roll medium 和 low（最多 3 次）。
	for _attempt in range(3):
		var vals := pool.values()
		var dup := false
		for i in range(vals.size()):
			for j in range(i + 1, vals.size()):
				if vals[i] == vals[j]:
					dup = true
					break
			if dup:
				break
		if not dup:
			break
		for tier in ["medium", "low"]:
			var options: Array = pref.get(tier, [])
			if options.size() > 1:
				pool[tier] = options[_rng.randi() % options.size()]
	pool["pool_date"] = _today_date()
	_daily_location_pools[cat_id] = pool
	_save()
	return pool.duplicate()

# 带地点选择的派遣：记录所选地点并标记是否命中高偏好。
static func dispatch_with_location(cat_id: String, duration_hours: int, chosen_location: String) -> bool:
	if not VALID_DURATIONS.has(duration_hours):
		return false
	if is_exploring(cat_id):
		return false
	if not _guard_allows_dispatch(cat_id):
		return false
	if _active_count() >= _available_slot_count():
		return false
	var now := _safe_unix_time()
	_explorers[cat_id] = {
		"departure_time": now,
		"return_time": now + duration_hours * SECONDS_PER_HOUR,
		"duration_hours": duration_hours,
		"is_exploring": true,
		"chosen_location": chosen_location,
	}
	var pool := get_location_choices(cat_id, _get_cat_species(cat_id))
	_last_chosen_location[cat_id] = chosen_location
	_last_location_chosen_is_high[cat_id] = (String(pool.get("high", "")) == chosen_location)
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
	var reward_type := _roll_reward_type(cat_id, int(entry.get("duration_hours", 0)))
	var postcard_id := ""
	if reward_type == "postcard":
		var species_of_cat := cat_species if cat_species != "" else _get_cat_species(cat_id)
		postcard_id = _pick_postcard_for_cat(species_of_cat)
		if postcard_id != "":
			_collected_postcards.append(postcard_id)
			var postcard = PostcardData.get_by_id(postcard_id)
			var location_type := String(postcard.location_type) if postcard != null else ""
			if Engine.has_singleton("EventBus"):
				Engine.get_singleton("EventBus").emit_postcard_obtained(postcard_id, location_type)
		else:
			# C1 邮票裁决（P3）：明信片池抽干时不再静默降级为食材——
			# 改发「旅行邮票」+ 50 金币，保住"猫带回礼物"的期待价值。
			reward_type = "stamp"
			_travel_stamps += 1
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null and tree.root != null:
				var cm = tree.root.get_node_or_null("/root/CurrencyManager")
				if cm != null:
					cm.add_gold(STAMP_FALLBACK_GOLD, "travel_stamp")
	elif reward_type == "frame_variant" or reward_type == "food_fragment":
		# N10 新类型：仅记录 reward_type，本版本不做额外产出处理（相框/碎片系统另行结算）。
		pass
	entry["reward_type"] = reward_type
	entry["postcard_id"] = postcard_id
	# 偏好命中奖励：所选地点为高偏好时，返回物 +1（bonus_reward）。
	var bonus_reward: bool = bool(_last_location_chosen_is_high.get(cat_id, false))
	entry["bonus_reward"] = bonus_reward
	entry["chosen_location"] = String(entry.get("chosen_location", _last_chosen_location.get(cat_id, "")))
	_last_chosen_location.erase(cat_id)
	_last_location_chosen_is_high.erase(cat_id)
	_save()
	return entry

# ---- 奖励 ----
static func _roll_reward_type(cat_id: String, duration_hours: int = 0) -> String:
	if not _first_explore_flags.has(cat_id):
		_first_explore_flags[cat_id] = true
		_last_reward_type[cat_id] = "postcard"
		return "postcard"
	# N10：首发 30 张城市明信片集齐后，60% 明信片概率质量重分配给相框变体与食材碎片。
	var all_collected := _all_city_postcards_collected()
	# 基础概率（GDD §14.3 / N10）。所有修正一律从 ingredient 扣除，保证总和恒为 1.0。
	var postcard := 0.0 if all_collected else 0.60
	var ingredient := 0.25
	var decoration := 0.10
	var hidden := 0.05
	# 集齐后启用：周主题相框变体 30% + 食材碎片 30%（未集齐时为 0）。
	var frame_variant := 0.30 if all_collected else 0.0
	var food_fragment := 0.30 if all_collected else 0.0
	# 雨天：postcard +10pp，ingredient -10pp（WeatherTimeManager 不可用则降级为基础概率）。
	if Engine.has_singleton("WeatherTimeManager"):
		var wtm = Engine.get_singleton("WeatherTimeManager")
		if wtm != null and int(wtm.current_weather) == wtm.WeatherType.RAIN:
			postcard += 0.10
			ingredient -= 0.10
	# 4 小时探索：decoration +5pp，ingredient -5pp（可与雨天叠加）。
	if duration_hours == 4:
		decoration += 0.05
		ingredient -= 0.05
	var r := _rng.randf()
	var t: String
	if all_collected:
		# 集齐后：不再产出 postcard，60% 质量由 frame_variant/food_fragment 承接。
		if r < frame_variant:
			t = "frame_variant"
		elif r < frame_variant + food_fragment:
			t = "food_fragment"
		elif r < frame_variant + food_fragment + ingredient:
			t = "ingredient"
		elif r < frame_variant + food_fragment + ingredient + decoration:
			t = "decoration"
		else:
			t = "hidden"
	else:
		if r < postcard:
			t = "postcard"
		elif r < postcard + ingredient:
			t = "ingredient"
		elif r < postcard + ingredient + decoration:
			t = "decoration"
		else:
			t = "hidden"
	# 防重复：同一猫连续 postcard 时改为 ingredient（集齐后 postcard=0，不会命中）。
	if t == "postcard" and String(_last_reward_type.get(cat_id, "")) == "postcard":
		t = "ingredient"
	_last_reward_type[cat_id] = t
	return t

# N10：判断首发 30 张城市明信片（CITY_LOCATION_TYPES）是否已全部收集。
static func _all_city_postcards_collected() -> bool:
	var city_ids := PostcardData.get_city_postcard_ids()
	if city_ids.is_empty():
		return false
	for pid in city_ids:
		if pid not in _collected_postcards:
			return false
	return true


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
	var spotlight_location := _get_spotlight_location()
	if spotlight_location != "" and _rng.randf() < _spotlight_boost:
		var spotlight_candidates := []
		for pid in available:
			var pd = PD.get_by_id(pid)
			if pd and pd.sender_cat_species == cat_species and pd.location_type == spotlight_location:
				spotlight_candidates.append(pid)
		if not spotlight_candidates.is_empty():
			return spotlight_candidates[_rng.randi() % spotlight_candidates.size()]
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

# 返回高偏好地点的推荐提示（供 UI 展示），无池时返回空串。
static func get_bonus_hint(cat_id: String) -> String:
	var pool: Dictionary = _daily_location_pools.get(cat_id, {})
	var high_loc := String(pool.get("high", ""))
	if high_loc == "":
		return ""
	var location_names := {
		"convenience_store": "便利店", "park_bench": "公园长椅",
		"subway_station": "地铁站", "bookstore": "书店",
		"cafe": "咖啡馆", "hospital_corridor": "医院走廊",
		"sky_bridge": "天桥", "night_market": "夜市",
		"playground": "游乐场", "rainy_day": "雨天",
	}
	return "❤️ 建议：%s（命中返回物+1）" % location_names.get(high_loc, high_loc)

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
	if Engine.has_singleton("HatchEngine") and Engine.get_singleton("HatchEngine").has_method("get_cat_by_id"):
		var cat = Engine.get_singleton("HatchEngine").get_cat_by_id(cat_id)
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

# 跨天则清空全部地点池，令下一次 get_location_choices 重新生成。
static func _check_daily_pool_reset() -> void:
	var today := _today_date()
	for cat_id in _daily_location_pools:
		if String(_daily_location_pools[cat_id].get("pool_date", "")) != today:
			_daily_location_pools.clear()
			return

static func _today_date() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]

static func _safe_unix_time() -> float:
	if Engine.has_singleton("TimeGuard") and Engine.get_singleton("TimeGuard").has_method("get_safe_unix_time"):
		return Engine.get_singleton("TimeGuard").get_safe_unix_time()
	return Time.get_unix_time_from_system()

static func _get_spotlight_location() -> String:
	return WeeklySpotlightS.get_current_spotlight_location()

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SECTION, "explorers", _explorers)
	cfg.set_value(SECTION, "hatched_count", _hatched_count)
	cfg.set_value(SECTION, "collected_postcards", _collected_postcards)
	cfg.set_value(SECTION, "travel_stamps", _travel_stamps)
	cfg.set_value(SECTION, "first_explore_flags", _first_explore_flags)
	cfg.set_value(SECTION, "daily_location_pools", _daily_location_pools)
	cfg.set_value(SECTION, "last_chosen_location", _last_chosen_location)
	cfg.set_value(SECTION, "last_location_chosen_is_high", _last_location_chosen_is_high)
	if cfg.save(CFG_PATH) != OK:
		push_error("[ExploreEngine] Save failed: %s" % CFG_PATH)

static func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	_explorers = cfg.get_value(SECTION, "explorers", {})
	_hatched_count = int(cfg.get_value(SECTION, "hatched_count", 0))
	_collected_postcards = cfg.get_value(SECTION, "collected_postcards", [])
	_travel_stamps = int(cfg.get_value(SECTION, "travel_stamps", 0))
	_first_explore_flags = cfg.get_value(SECTION, "first_explore_flags", {})
	_daily_location_pools = cfg.get_value(SECTION, "daily_location_pools", {})
	_last_chosen_location = cfg.get_value(SECTION, "last_chosen_location", {})
	_last_location_chosen_is_high = cfg.get_value(SECTION, "last_location_chosen_is_high", {})
