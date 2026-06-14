extends Node

# Emotion state machine for cats.
# 5 emotions: idle (default), happy (30min post-interaction),
# sleepy (schedule), curious (10min), annoyed (>=4 unique interaction
# types within a sliding 1h window).
# Static API; persistence is independent (user://emotion.cfg).

const SAVE_PATH := "user://emotion.cfg"
const WINDOW_SECONDS := 3600.0
const ANNOYED_THRESHOLD := 4

static var _emotions := {}        # cat_id -> emotion String
static var _starts := {}          # cat_id -> emotion start (virtual seconds)
static var _history := {}         # cat_id -> Array of {time, type}
static var _affection := {}       # cat_id -> int
static var _schedule_override := ""
static var _clock_offset := 0.0   # virtual clock shift
static var _loaded := false
static var _rng := RandomNumberGenerator.new()


static func _now() -> float:
	return Time.get_unix_time_from_system() + _clock_offset


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_rng.randomize()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_emotions = cfg.get_value("state", "emotions", {})
		_starts = cfg.get_value("state", "starts", {})
		_history = cfg.get_value("state", "history", {})
		_affection = cfg.get_value("state", "affection", {})
		_schedule_override = cfg.get_value("state", "schedule", "")


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("state", "emotions", _emotions)
	cfg.set_value("state", "starts", _starts)
	cfg.set_value("state", "history", _history)
	cfg.set_value("state", "affection", _affection)
	cfg.set_value("state", "schedule", _schedule_override)
	cfg.save(SAVE_PATH)


static func _ensure(cat_id: String) -> void:
	_ensure_loaded()
	if not _emotions.has(cat_id):
		_history[cat_id] = []
		if not _affection.has(cat_id):
			_affection[cat_id] = 0
		if _schedule_override == "sleep":
			_emotions[cat_id] = "sleepy"
		else:
			_emotions[cat_id] = "idle"
		_starts[cat_id] = _now()


static func _set_emotion(cat_id: String, emotion: String) -> void:
	_emotions[cat_id] = emotion
	_starts[cat_id] = _now()
	_save()


static func _prune(cat_id: String) -> void:
	if not _history.has(cat_id):
		return
	var cutoff := _now() - WINDOW_SECONDS
	var kept := []
	for h in _history[cat_id]:
		if float(h["time"]) >= cutoff:
			kept.append(h)
	_history[cat_id] = kept


static func _unique_type_count(cat_id: String) -> int:
	if not _history.has(cat_id):
		return 0
	var seen := {}
	for h in _history[cat_id]:
		seen[h["type"]] = true
	return seen.size()


static func reset_all() -> void:
	_loaded = true
	_emotions = {}
	_starts = {}
	_history = {}
	_affection = {}
	_schedule_override = ""
	_clock_offset = 0.0
	_rng.randomize()
	_save()


static func get_emotion(cat_id: String) -> String:
	_ensure(cat_id)
	_prune(cat_id)
	var e: String = _emotions[cat_id]
	if e == "happy" and is_expired(cat_id, "happy", 30.0):
		_set_emotion(cat_id, "idle")
		e = "idle"
	elif e == "curious" and is_expired(cat_id, "curious", 10.0):
		_set_emotion(cat_id, "idle")
		e = "idle"
	elif e == "annoyed" and is_expired(cat_id, "annoyed", 60.0):
		_set_emotion(cat_id, "idle")
		e = "idle"
	return e


static func record_interaction(cat_id: String, type: String) -> void:
	_ensure(cat_id)
	_history[cat_id].append({"time": _now(), "type": type})
	_prune(cat_id)
	if _unique_type_count(cat_id) >= ANNOYED_THRESHOLD:
		_set_emotion(cat_id, "annoyed")
	else:
		_set_emotion(cat_id, "happy")


static func is_expired(cat_id: String, emotion: String, minutes: float) -> bool:
	_ensure(cat_id)
	var elapsed := _now() - float(_starts.get(cat_id, _now()))
	return elapsed >= minutes * 60.0


static func _override_elapsed(cat_id: String, seconds: float) -> void:
	_ensure(cat_id)
	_starts[cat_id] = _now() - seconds
	_save()


static func is_annoyed(cat_id: String) -> bool:
	return get_emotion(cat_id) == "annoyed"


static func trigger_curious(cat_id: String, reason: String) -> void:
	_ensure(cat_id)
	_set_emotion(cat_id, "curious")


static func set_schedule_override(state: String) -> void:
	_ensure_loaded()
	_schedule_override = state
	for cat_id in _emotions:
		if _emotions[cat_id] == "idle" and state == "sleep":
			_emotions[cat_id] = "sleepy"
			_starts[cat_id] = _now()
		elif _emotions[cat_id] == "sleepy" and state != "sleep":
			_emotions[cat_id] = "idle"
			_starts[cat_id] = _now()
	_save()


static func wake_up(cat_id: String) -> void:
	_ensure(cat_id)
	if _emotions[cat_id] == "sleepy":
		_set_emotion(cat_id, "idle")
		_affection[cat_id] = int(_affection.get(cat_id, 0)) + 1
		_save()


static func _advance_window(seconds: float) -> void:
	_ensure_loaded()
	_clock_offset += seconds
