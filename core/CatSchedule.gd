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

static func get_state(breed: String, period: String) -> String:
	match breed:
		"orange":
			if period == "night" or period == "dawn" or period == "noon":
				return "sleep"
			return "active"
		"british":
			if period == "noon":
				return "sleep"
			return "active"
		"siamese":
			if period == "night":
				return "sleep"
			return "active"
		_:
			return "active"

static func is_night_patrol() -> bool:
	var h: int = _current_hour()
	return h >= 20 and h <= 23

static func can_wake() -> bool:
	var period: String = get_period(_current_hour())
	return period == "night" or period == "dawn" or period == "noon"

static func set_time_override(hour: int) -> void:
	_time_override = hour

static func reset_all() -> void:
	_time_override = -1
