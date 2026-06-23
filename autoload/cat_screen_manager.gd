extends Node

signal screen_cats_changed(visible_cats: Array)
signal cat_pinned(cat_id: String)
signal cat_unpinned(cat_id: String)
signal cat_debut_started(cat_id: String)
signal cat_debut_ended(cat_id: String)
signal cat_cooldown_started(cat_id: String)
signal rotation_performed(new_rotating: Array)
signal rotation_timer_tick(seconds_remaining: int)
signal max_cats_changed(new_max: int)

const MAX_PINNED := 4
const MAX_ROTATING_BASE := 2
const MAX_ROTATING_EXTENDED := 4
const ROTATION_INTERVAL_SECONDS := 1800
const DEBUT_DURATION_SECONDS := 1800
const COOLDOWN_SECONDS := 1800
const TIME_BONUS_MAX := 2.0
const TIME_BONUS_GROWTH_RATE := 0.1
const RARITY_WEIGHTS := {
	"common": 1.0,
	"rare": 0.8,
	"epic": 0.5,
	"legendary": 0.3,
}

var max_cats: int = 6
var max_rotating: int = 2
var pinned_cats: Array[String] = []
var rotating_cats: Array[String] = []
var last_rotation_time: int = 0
var next_rotation_time: int = 0
var cat_debut_times: Dictionary = {}
var cat_cooldowns: Dictionary = {}
var cat_weight_bonus: Dictionary = {}
var _cached_visible: Array[String] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tick_timer: Timer


func _ready() -> void:
	_rng.randomize()
	if last_rotation_time == 0:
		last_rotation_time = _now()
	next_rotation_time = last_rotation_time + ROTATION_INTERVAL_SECONDS
	_sync_visible()
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.one_shot = false
	_tick_timer.timeout.connect(_on_tick_timer_timeout)
	add_child(_tick_timer)
	_tick_timer.start()


func get_visible_cats() -> Array[String]:
	return _cached_visible.duplicate()


func pin_cat(cat_id: String, pin_order: int = -1) -> bool:
	if pinned_cats.size() >= MAX_PINNED:
		push_warning("[CatScreenManager] pinned cats are full")
		return false
	if not _cat_exists(cat_id):
		push_warning("[CatScreenManager] invalid cat_id: %s" % cat_id)
		return false
	if pinned_cats.has(cat_id):
		return false
	if pin_order == -1:
		pinned_cats.append(cat_id)
	else:
		pinned_cats.insert(clamp(pin_order, 0, pinned_cats.size()), cat_id)
	rotating_cats.erase(cat_id)
	cat_debut_times.erase(cat_id)
	cat_pinned.emit(cat_id)
	_fill_rotating_gaps()
	_sync_visible()
	_save_state()
	return true


func unpin_cat(cat_id: String) -> bool:
	if not pinned_cats.has(cat_id):
		push_warning("[CatScreenManager] cat is not pinned: %s" % cat_id)
		return false
	pinned_cats.erase(cat_id)
	cat_unpinned.emit(cat_id)
	_fill_rotating_gaps()
	_sync_visible()
	_save_state()
	return true


func force_debut(cat_id: String) -> bool:
	if not _cat_exists(cat_id):
		push_warning("[CatScreenManager] invalid cat_id: %s" % cat_id)
		return false
	var now := _now()
	cat_debut_times[cat_id] = now + DEBUT_DURATION_SECONDS
	cat_debut_started.emit(cat_id)
	if pinned_cats.has(cat_id):
		return true
	if rotating_cats.has(cat_id):
		_sync_visible()
		return true
	if rotating_cats.size() < max_rotating:
		rotating_cats.append(cat_id)
	else:
		var replace_index := _find_debut_replacement_index(now)
		if replace_index >= 0:
			var old_id := rotating_cats[replace_index]
			cat_cooldowns[old_id] = now + COOLDOWN_SECONDS
			cat_weight_bonus[old_id] = 0.0
			cat_cooldown_started.emit(old_id)
			rotating_cats[replace_index] = cat_id
	cat_weight_bonus[cat_id] = 0.0
	_sync_visible()
	_save_state()
	return true


func is_rotation_due() -> bool:
	return _now() >= next_rotation_time


func perform_rotation() -> Array[String]:
	var now := _now()
	last_rotation_time = now
	next_rotation_time = now + ROTATION_INTERVAL_SECONDS
	for cid in cat_debut_times.keys():
		if int(cat_debut_times[cid]) <= now:
			cat_debut_times.erase(cid)
			cat_debut_ended.emit(String(cid))
	for cid in rotating_cats:
		if pinned_cats.has(cid):
			continue
		cat_cooldowns[cid] = now + COOLDOWN_SECONDS
		cat_weight_bonus[cid] = 0.0
		cat_cooldown_started.emit(cid)
	_accumulate_time_bonuses()
	rotating_cats = _select_rotation_candidates(max_rotating)
	for cid in rotating_cats:
		cat_weight_bonus[cid] = 0.0
	rotation_performed.emit(rotating_cats.duplicate())
	_sync_visible()
	_save_state()
	return get_visible_cats()


func get_cat_visibility(cat_id: String) -> Dictionary:
	var now := _now()
	return {
		"cat_id": cat_id,
		"exists": _cat_exists(cat_id),
		"is_visible": _cached_visible.has(cat_id),
		"is_pinned": pinned_cats.has(cat_id),
		"is_rotating": rotating_cats.has(cat_id),
		"pin_order": pinned_cats.find(cat_id),
		"rotation_order": rotating_cats.find(cat_id),
		"debut_until": int(cat_debut_times.get(cat_id, 0)),
		"is_debut": int(cat_debut_times.get(cat_id, 0)) > now,
		"cooldown_until": int(cat_cooldowns.get(cat_id, 0)),
		"is_on_cooldown": int(cat_cooldowns.get(cat_id, 0)) > now,
		"time_bonus": float(cat_weight_bonus.get(cat_id, 0.0)),
	}


func get_rotation_timer() -> Dictionary:
	var now := _now()
	return {
		"last_rotation": last_rotation_time,
		"next_rotation": next_rotation_time,
		"seconds_remaining": max(0, next_rotation_time - now),
		"is_due": is_rotation_due(),
		"interval_minutes": ROTATION_INTERVAL_SECONDS / 60,
	}


func set_max_cats(new_max: int) -> void:
	max_cats = clamp(new_max, 6, 8)
	max_rotating = max_cats - MAX_PINNED
	max_cats_changed.emit(max_cats)
	while rotating_cats.size() > max_rotating:
		rotating_cats.pop_back()
	_fill_rotating_gaps()
	_sync_visible()


func save_state() -> Dictionary:
	return {
		"max_cats": max_cats,
		"max_rotating": max_rotating,
		"pinned_cats": pinned_cats.duplicate(),
		"rotating_cats": rotating_cats.duplicate(),
		"last_rotation_time": last_rotation_time,
		"next_rotation_time": next_rotation_time,
		"cat_debut_times": cat_debut_times.duplicate(true),
		"cat_cooldowns": cat_cooldowns.duplicate(true),
		"cat_weight_bonus": cat_weight_bonus.duplicate(true),
	}


func load_state(data: Dictionary) -> void:
	if data.is_empty():
		max_cats = 6
		max_rotating = MAX_ROTATING_BASE
		pinned_cats.clear()
		rotating_cats.clear()
		last_rotation_time = _now()
		next_rotation_time = last_rotation_time + ROTATION_INTERVAL_SECONDS
		cat_debut_times.clear()
		cat_cooldowns.clear()
		cat_weight_bonus.clear()
		_sync_visible()
		return
	max_cats = clamp(int(data.get("max_cats", 6)), 6, 8)
	max_rotating = clamp(max_cats - MAX_PINNED, MAX_ROTATING_BASE, MAX_ROTATING_EXTENDED)
	pinned_cats = _to_string_array(Array(data.get("pinned_cats", [])))
	rotating_cats = _to_string_array(Array(data.get("rotating_cats", [])))
	last_rotation_time = int(data.get("last_rotation_time", 0))
	next_rotation_time = int(data.get("next_rotation_time", 0))
	cat_debut_times = _string_key_int_dict(Dictionary(data.get("cat_debut_times", {})))
	cat_cooldowns = _string_key_int_dict(Dictionary(data.get("cat_cooldowns", {})))
	cat_weight_bonus = _string_key_float_dict(Dictionary(data.get("cat_weight_bonus", {})))
	if last_rotation_time == 0:
		last_rotation_time = _now()
	if next_rotation_time == 0:
		next_rotation_time = last_rotation_time + ROTATION_INTERVAL_SECONDS
	_trim_invalid_state()
	_sync_visible()


func get_save_data() -> Dictionary:
	return save_state()


func apply_save(data: Dictionary) -> void:
	load_state(data)


func _save_state() -> void:
	if has_node("/root/SaveManager") and SaveManager.has_method("save_all"):
		SaveManager.save_all()


func _select_rotation_candidates(count: int) -> Array[String]:
	var now := _now()
	var cats := _get_all_cats()
	var debut_pool: Array[String] = []
	var normal_pool: Array[String] = []
	for cat_data in cats:
		var cid := _get_cat_id(cat_data)
		if cid == "":
			continue
		if pinned_cats.has(cid) or rotating_cats.has(cid):
			continue
		if int(cat_cooldowns.get(cid, 0)) > now:
			continue
		if int(cat_debut_times.get(cid, 0)) > now:
			debut_pool.append(cid)
		else:
			normal_pool.append(cid)
	debut_pool.sort_custom(func(a: String, b: String) -> bool: return int(cat_debut_times.get(a, 0)) < int(cat_debut_times.get(b, 0)))
	var result: Array[String] = []
	for cid in debut_pool:
		if result.size() >= count:
			break
		result.append(cid)
	while result.size() < count and not normal_pool.is_empty():
		var selected := _weighted_pick(normal_pool)
		if selected == "":
			break
		result.append(selected)
		normal_pool.erase(selected)
	return result


func _calculate_weight(cat_id: String, cat_data = null) -> float:
	var data = cat_data if cat_data != null else _get_cat_data(cat_id)
	var rarity: String = String(_get_cat_value(data, "rarity", "common"))
	var time_bonus: float = clamp(float(cat_weight_bonus.get(cat_id, 0.0)), 0.0, TIME_BONUS_MAX)
	return float(RARITY_WEIGHTS.get(rarity, 1.0)) + time_bonus


func _accumulate_time_bonuses() -> void:
	for cat_data in _get_all_cats():
		var cid := _get_cat_id(cat_data)
		if cid == "" or pinned_cats.has(cid) or rotating_cats.has(cid):
			continue
		var current := float(cat_weight_bonus.get(cid, 0.0))
		cat_weight_bonus[cid] = min(current + TIME_BONUS_GROWTH_RATE, TIME_BONUS_MAX)


func _fill_rotating_gaps() -> void:
	var gap := max_rotating - rotating_cats.size()
	if gap <= 0:
		return
	for cid in _select_rotation_candidates(gap):
		if rotating_cats.size() >= max_rotating:
			break
		if not rotating_cats.has(cid):
			rotating_cats.append(cid)


func _sync_visible() -> void:
	_trim_invalid_state()
	_cached_visible = pinned_cats.duplicate()
	for cid in rotating_cats:
		if not _cached_visible.has(cid):
			_cached_visible.append(cid)
	screen_cats_changed.emit(_cached_visible.duplicate())


func _on_tick_timer_timeout() -> void:
	if is_rotation_due():
		perform_rotation()
	rotation_timer_tick.emit(int(get_rotation_timer().get("seconds_remaining", 0)))


func _find_debut_replacement_index(now: int) -> int:
	var fallback_index := 0
	var fallback_expire := 2147483647
	for i in range(rotating_cats.size()):
		var cid := rotating_cats[i]
		var expire := int(cat_debut_times.get(cid, 0))
		if expire <= now:
			return i
		if expire < fallback_expire:
			fallback_expire = expire
			fallback_index = i
	return fallback_index


func _weighted_pick(pool: Array[String]) -> String:
	var total := 0.0
	for cid in pool:
		total += max(_calculate_weight(cid), 0.01)
	if total <= 0.0:
		return pool[0] if not pool.is_empty() else ""
	var roll := _rng.randf_range(0.0, total)
	var cursor := 0.0
	for cid in pool:
		cursor += max(_calculate_weight(cid), 0.01)
		if roll <= cursor:
			return cid
	return pool.back() if not pool.is_empty() else ""


func _trim_invalid_state() -> void:
	pinned_cats = _unique_existing(pinned_cats)
	rotating_cats = _unique_existing(rotating_cats)
	while pinned_cats.size() > MAX_PINNED:
		pinned_cats.pop_back()
	for cid in pinned_cats:
		rotating_cats.erase(cid)
	while rotating_cats.size() > max_rotating:
		rotating_cats.pop_back()


func _unique_existing(source: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for cid in source:
		if cid == "" or result.has(cid):
			continue
		if _cat_exists(cid):
			result.append(cid)
	return result


func _cat_exists(cat_id: String) -> bool:
	if cat_id == "":
		return false
	return _get_cat_data(cat_id) != null


func _get_all_cats() -> Array:
	if not has_node("/root/HatchEngine"):
		return []
	return HatchEngine.get_cats()


func _get_cat_data(cat_id: String):
	if has_node("/root/HatchEngine") and HatchEngine.has_method("get_cat_by_id"):
		return HatchEngine.get_cat_by_id(cat_id)
	for cat_data in _get_all_cats():
		if _get_cat_id(cat_data) == cat_id:
			return cat_data
	return null


func _get_cat_id(cat_data) -> String:
	return String(_get_cat_value(cat_data, "id", ""))


func _get_cat_value(cat_data, key: String, default_value):
	if cat_data == null:
		return default_value
	if cat_data is Dictionary:
		return cat_data.get(key, default_value)
	var value = cat_data.get(key)
	return default_value if value == null else value


func _to_string_array(source: Array) -> Array[String]:
	var result: Array[String] = []
	for item in source:
		result.append(String(item))
	return result


func _string_key_int_dict(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[String(key)] = int(source[key])
	return result


func _string_key_float_dict(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[String(key)] = float(source[key])
	return result


func _now() -> int:
	return int(Time.get_unix_time_from_system())
