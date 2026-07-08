extends Node

static var _time_override: int = -1

static func get_period(hour: int) -> String:
	if hour >= 6 and hour <= 8:
		return "dawn"
	elif hour >= 9 and hour <= 11:
		return "morning"
	elif hour >= 12 and hour <= 13:
		return "noon"
	elif hour >= 14 and hour <= 17:
		return "afternoon"
	elif hour >= 18 and hour <= 19:
		return "dusk"
	else:
		return "night"

static func _current_hour() -> int:
	if _time_override >= 0:
		return _time_override
	return Time.get_datetime_dict_from_system()["hour"]

static func _in_range(hour: int, start: int, end: int) -> bool:
	return hour >= start and hour <= end

static func get_state(breed: String, hour: int) -> String:
	match breed:
		"orange":
			if _in_range(hour, 0, 5) or hour == 23:
				return "sleep"
			if _in_range(hour, 9, 11) or _in_range(hour, 14, 16):
				return "sleep"
			return "active"
		"british":
			if _in_range(hour, 0, 5) or hour == 23:
				return "sleep"
			if _in_range(hour, 6, 8):
				return "window"
			if _in_range(hour, 12, 13):
				return "sleep"
			return "active"
		"siamese":
			if _in_range(hour, 0, 5) or hour == 23:
				return "sleep"
			if _in_range(hour, 15, 16):
				return "sleep"
			if _in_range(hour, 20, 22):
				return "lazy"
			return "active"
		_:
			return "active"

static func is_night_patrol(breed: String = "") -> bool:
	var h: int = _current_hour()
	if breed == "orange" and _in_range(h, 0, 5):
		return true
	return h >= 20 and h <= 23

static func can_wake(_cat_id: String = "") -> bool:
	var h: int = _current_hour()
	return get_state("orange", h) == "sleep" or get_state("british", h) == "sleep" or get_state("siamese", h) == "sleep"

static func get_current_period() -> String:
	return get_period(_current_hour())

static func is_golden_hour(hour: int) -> bool:
	var awake_count: int = 0
	for breed in ["orange", "british", "siamese"]:
		if get_state(breed, hour) != "sleep":
			awake_count += 1
	return awake_count >= 2

static func set_time_override(hour: int) -> void:
	_time_override = hour

static func reset_all() -> void:
	_time_override = -1
