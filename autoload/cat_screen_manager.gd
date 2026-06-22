# CatScreenManager — 同屏猫筛选引擎 (Autoload)
# 4固定 + 2轮换，30分钟轮换周期
extends Node

signal screen_cats_changed(visible_cats: Array)
signal rotation_performed(new_rotating: Array)
signal max_cats_changed(new_max: int)

const MAX_PINNED := 4
const MAX_ROTATING := 2
const ROTATION_INTERVAL := 1800  # 30分钟
const DEBUT_DURATION := 1800     # 30分钟首秀
const COOLDOWN := 1800           # 冷却30分钟
const SAVE_PATH := "user://cat_screen.cfg"

var max_cats: int = 6  # 扩展包后可变8
var pinned_cats: Array[String] = []
var rotating_cats: Array[String] = []
var debut_map: Dictionary = {}       # cat_id -> debut_expire_time
var cooldown_map: Dictionary = {}    # cat_id -> cooldown_expire_time
var last_rotation_time: int = 0
var _cached_visible: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_state()
	if last_rotation_time == 0:
		last_rotation_time = int(Time.get_unix_time_from_system())
	_sync_visible()


func get_visible_cats() -> Array[String]:
	if is_rotation_due():
		perform_rotation()
	return _cached_visible.duplicate()


func pin_cat(cat_id: String) -> bool:
	if pinned_cats.size() >= MAX_PINNED or pinned_cats.has(cat_id):
		return false
	if not _cat_exists(cat_id):
		return false
	pinned_cats.append(cat_id)
	rotating_cats.erase(cat_id)
	_fill_rotating()
	_sync_visible()
	_save_state()
	return true


func unpin_cat(cat_id: String) -> bool:
	if not pinned_cats.has(cat_id):
		return false
	pinned_cats.erase(cat_id)
	_fill_rotating()
	_sync_visible()
	_save_state()
	return true


func force_debut(cat_id: String) -> bool:
	if not _cat_exists(cat_id):
		return false
	debut_map[cat_id] = int(Time.get_unix_time_from_system()) + DEBUT_DURATION
	# 已固定的猫不需要 debut 轮换
	if pinned_cats.has(cat_id):
		return true
	# 已在 rotating 中，只更新 debut
	if rotating_cats.has(cat_id):
		_sync_visible()
		return true
	# 插入 rotating（替换最老的非 debut 猫）
	if rotating_cats.size() < MAX_ROTATING:
		rotating_cats.append(cat_id)
	else:
		# 找最旧的非 debut 猫替换
		var oldest_idx := -1
		for i in range(rotating_cats.size()):
			var rid := rotating_cats[i]
			if not debut_map.has(rid) or debut_map[rid] <= int(Time.get_unix_time_from_system()):
				oldest_idx = i
				break
			if oldest_idx == -1:
				oldest_idx = i
		if oldest_idx >= 0:
			var old_id := rotating_cats[oldest_idx]
			cooldown_map[old_id] = int(Time.get_unix_time_from_system()) + COOLDOWN
			rotating_cats[oldest_idx] = cat_id
	_sync_visible()
	_save_state()
	return true


func is_rotation_due() -> bool:
	return int(Time.get_unix_time_from_system()) >= last_rotation_time + ROTATION_INTERVAL


func perform_rotation() -> void:
	last_rotation_time = int(Time.get_unix_time_from_system())
	# 清理到期 debut
	var now := int(Time.get_unix_time_from_system())
	for cid in debut_map.keys():
		if debut_map[cid] <= now:
			debut_map.erase(cid)
	# 标记当前 rotating 进入冷却
	for cid in rotating_cats:
		if not pinned_cats.has(cid):
			cooldown_map[cid] = now + COOLDOWN
	# 选新的 rotating
	rotating_cats = _select_candidates(MAX_ROTATING)
	_sync_visible()
	rotation_performed.emit(rotating_cats.duplicate())
	_save_state()


func get_rotation_timer() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	return {
		"last_rotation": last_rotation_time,
		"next_rotation": last_rotation_time + ROTATION_INTERVAL,
		"seconds_remaining": max(0, last_rotation_time + ROTATION_INTERVAL - now),
		"is_due": is_rotation_due(),
		"interval_minutes": ROTATION_INTERVAL / 60,
	}


func _select_candidates(count: int) -> Array[String]:
	var now := int(Time.get_unix_time_from_system())
	var pool: Array[String] = []
	# 收集所有非固定、非冷却的猫
	if has_node("/root/HatchEngine"):
		for cat_data in HatchEngine.get_cats():
			var cid := ""
			if cat_data is Dictionary:
				cid = String(cat_data.get("id", ""))
			elif cat_data != null:
				cid = String(cat_data.get("id"))
			if cid == "":
				continue
			if pinned_cats.has(cid):
				continue
			if cooldown_map.get(cid, 0) > now:
				continue
			pool.append(cid)
	# 去重
	pool = _unique(pool)
	# 优先 debut 猫
	var debut_pool: Array[String] = []
	var normal_pool: Array[String] = []
	for cid in pool:
		if debut_map.get(cid, 0) > now:
			debut_pool.append(cid)
		else:
			normal_pool.append(cid)
	var result: Array[String] = []
	# debut 优先
	for cid in debut_pool:
		if result.size() >= count:
			break
		result.append(cid)
	# 普通池随机补位
	normal_pool.shuffle()
	for cid in normal_pool:
		if result.size() >= count:
			break
		if not result.has(cid):
			result.append(cid)
	return result


func _fill_rotating() -> void:
	var needed := MAX_ROTATING - rotating_cats.size()
	if needed <= 0:
		return
	var candidates := _select_candidates(needed)
	for cid in candidates:
		if not rotating_cats.has(cid):
			rotating_cats.append(cid)


func _sync_visible() -> void:
	_cached_visible.clear()
	for cid in pinned_cats:
		_cached_visible.append(cid)
	for cid in rotating_cats:
		_cached_visible.append(cid)
	screen_cats_changed.emit(_cached_visible.duplicate())


func _cat_exists(_cat_id: String) -> bool:
	# 简单验证：任何 id 都接受（HatchEngine 会在 spawn 时过滤）
	return true


func _unique(arr: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for item in arr:
		if not seen.has(item):
			seen[item] = true
			result.append(item)
	return result


func _load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	pinned_cats = Array(cfg.get_value("state", "pinned_cats", []))
	rotating_cats = Array(cfg.get_value("state", "rotating_cats", []))
	last_rotation_time = int(cfg.get_value("state", "last_rotation_time", 0))
	max_cats = int(cfg.get_value("state", "max_cats", 6))
	var debut_raw: Dictionary = cfg.get_value("state", "debut_map", {})
	for k in debut_raw.keys():
		debut_map[String(k)] = int(debut_raw[k])
	var cooldown_raw: Dictionary = cfg.get_value("state", "cooldown_map", {})
	for k in cooldown_raw.keys():
		cooldown_map[String(k)] = int(cooldown_raw[k])


func _save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("state", "pinned_cats", pinned_cats)
	cfg.set_value("state", "rotating_cats", rotating_cats)
	cfg.set_value("state", "last_rotation_time", last_rotation_time)
	cfg.set_value("state", "max_cats", max_cats)
	cfg.set_value("state", "debut_map", debut_map)
	cfg.set_value("state", "cooldown_map", cooldown_map)
	cfg.save(SAVE_PATH)
