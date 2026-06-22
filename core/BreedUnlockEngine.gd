extends Node

const CatData := preload("res://core/CatData.gd")

const UNLOCK_CHAIN_COUNT := 2
const PITY_THRESHOLD := 5
const BREED_ORDER: Array[String] = [
	CatData.BREED_ORANGE,
	CatData.BREED_BRITISH,
	CatData.BREED_SIAMESE,
]

var _unlocked: Array[String] = [CatData.BREED_ORANGE]
var _hatch_counts: Dictionary = {}
var _pity_counters: Dictionary = {}
var _new_breed_unlocked: bool = false
var _last_pity_breed: String = ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_reset_counts()
	_load()
	_normalize_state()
	_new_breed_unlocked = false


func get_unlocked_breeds() -> Array[String]:
	var result: Array[String] = []
	for breed in _unlocked:
		result.append(breed)
	return result


func determine_breed() -> String:
	var saved_flag: bool = _new_breed_unlocked
	_normalize_state()
	_new_breed_unlocked = saved_flag
	if _unlocked.is_empty():
		return CatData.BREED_ORANGE
	if _unlocked.size() == 1:
		var only_breed: String = _unlocked[0]
		_last_pity_breed = only_breed if get_pity_counter(only_breed) >= PITY_THRESHOLD else ""
		return only_breed

	var choices: Array[String] = get_unlocked_breeds()
	_last_pity_breed = _get_pity_breed(choices)
	if _last_pity_breed != "" and choices.size() > 1:
		choices.erase(_last_pity_breed)

	return choices[_rng.randi_range(0, choices.size() - 1)]


func record_hatch(breed: String) -> void:
	var normalized_breed: String = _normalize_breed(breed)
	_new_breed_unlocked = false
	_ensure_breed_keys(normalized_breed)
	_hatch_counts[normalized_breed] = get_hatch_count(normalized_breed) + 1

	# 保底：被排除的品种归零，被选中的品种+1，其余不变
	for known_breed in BREED_ORDER:
		if _last_pity_breed != "" and known_breed == _last_pity_breed:
			_pity_counters[known_breed] = 0
		elif known_breed == normalized_breed and _last_pity_breed != normalized_breed:
			_pity_counters[known_breed] = get_pity_counter(known_breed) + 1
	_last_pity_breed = ""

	_update_unlocks()
	_save()


func get_hatch_count(breed: String) -> int:
	return max(int(_hatch_counts.get(_normalize_breed(breed), 0)), 0)


func get_pity_counter(breed: String) -> int:
	return max(int(_pity_counters.get(_normalize_breed(breed), 0)), 0)


func is_new_breed_unlocked() -> bool:
	return _new_breed_unlocked


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("breed", "unlocked", _unlocked.duplicate())
	cfg.set_value("breed", "hatch_counts", _hatch_counts.duplicate(true))
	cfg.set_value("breed", "pity_counters", _pity_counters.duplicate(true))
	cfg.save("user://breed_unlock.cfg")


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://breed_unlock.cfg") != OK:
		return
	_unlocked = []
	for breed in Array(cfg.get_value("breed", "unlocked", [CatData.BREED_ORANGE])):
		_unlocked.append(_normalize_breed(String(breed)))
	var hc: Dictionary = Dictionary(cfg.get_value("breed", "hatch_counts", {}))
	for breed in hc.keys():
		_hatch_counts[_normalize_breed(String(breed))] = max(int(hc[breed]), 0)
	var pc: Dictionary = Dictionary(cfg.get_value("breed", "pity_counters", {}))
	for breed in pc.keys():
		_pity_counters[_normalize_breed(String(breed))] = max(int(pc[breed]), 0)


func get_save_data() -> Dictionary:
	var saved_flag: bool = _new_breed_unlocked
	_normalize_state()
	_new_breed_unlocked = saved_flag
	return {
		"unlocked": _unlocked.duplicate(),
		"hatch_counts": _hatch_counts.duplicate(true),
		"pity_counters": _pity_counters.duplicate(true),
	}


func apply_save(data: Dictionary) -> void:
	_unlocked = []
	for breed in Array(data.get("unlocked", [CatData.BREED_ORANGE])):
		var normalized_breed := _normalize_breed(String(breed))
		if not _unlocked.has(normalized_breed):
			_unlocked.append(normalized_breed)

	_hatch_counts.clear()
	for breed in BREED_ORDER:
		_hatch_counts[breed] = 0
	var saved_counts: Dictionary = Dictionary(data.get("hatch_counts", {}))
	for breed in saved_counts.keys():
		var normalized_count_breed := _normalize_breed(String(breed))
		_hatch_counts[normalized_count_breed] = max(int(saved_counts[breed]), 0)

	_pity_counters.clear()
	for breed in BREED_ORDER:
		_pity_counters[breed] = 0
	var saved_pity: Dictionary = Dictionary(data.get("pity_counters", {}))
	for breed in saved_pity.keys():
		var normalized_pity_breed := _normalize_breed(String(breed))
		_pity_counters[normalized_pity_breed] = max(int(saved_pity[breed]), 0)

	_normalize_state()
	_new_breed_unlocked = false


func _update_unlocks() -> void:
	_unlock_breed(CatData.BREED_ORANGE)
	if get_hatch_count(CatData.BREED_ORANGE) >= UNLOCK_CHAIN_COUNT:
		_unlock_breed(CatData.BREED_BRITISH)
	if get_hatch_count(CatData.BREED_BRITISH) >= UNLOCK_CHAIN_COUNT:
		_unlock_breed(CatData.BREED_SIAMESE)
	_sort_unlocked()


func _unlock_breed(breed: String) -> void:
	if not _unlocked.has(breed):
		_unlocked.append(breed)
		_new_breed_unlocked = true


func _get_pity_breed(choices: Array[String]) -> String:
	for breed in choices:
		if get_pity_counter(breed) >= PITY_THRESHOLD:
			return breed
	return ""


func _normalize_state() -> void:
	_reset_counts(false)
	if not _unlocked.has(CatData.BREED_ORANGE):
		_unlocked.append(CatData.BREED_ORANGE)
	for i in range(_unlocked.size() - 1, -1, -1):
		var breed: String = _normalize_breed(_unlocked[i])
		if not BREED_ORDER.has(breed) or _unlocked.find(breed) != i:
			_unlocked.remove_at(i)
		else:
			_unlocked[i] = breed
	_update_unlocks()


func _reset_counts(clear_values: bool = true) -> void:
	for breed in BREED_ORDER:
		if clear_values or not _hatch_counts.has(breed):
			_hatch_counts[breed] = 0
		if clear_values or not _pity_counters.has(breed):
			_pity_counters[breed] = 0


func _ensure_breed_keys(breed: String) -> void:
	if not _hatch_counts.has(breed):
		_hatch_counts[breed] = 0
	if not _pity_counters.has(breed):
		_pity_counters[breed] = 0


func _normalize_breed(breed: String) -> String:
	return breed if BREED_ORDER.has(breed) else CatData.BREED_ORANGE


func _sort_unlocked() -> void:
	var sorted: Array[String] = []
	for breed in BREED_ORDER:
		if _unlocked.has(breed):
			sorted.append(breed)
	_unlocked = sorted
