extends Node

signal spotlight_changed(location_type: String)

const CFG_PATH := "user://explore.cfg"
const SECTION := "spotlight"
const CITY_LOCATION_TYPES := [
	"convenience_store", "park_bench", "subway_station", "bookstore", "cafe",
	"hospital_corridor", "sky_bridge", "night_market", "playground", "rainy_day",
]
const LOCATION_DISPLAY_NAMES := {
	"convenience_store": "便利店",
	"park_bench": "公园长椅",
	"subway_station": "地铁站",
	"bookstore": "书店",
	"cafe": "咖啡馆",
	"hospital_corridor": "医院走廊",
	"sky_bridge": "天桥",
	"night_market": "夜市",
	"playground": "游乐场",
	"rainy_day": "雨天",
}

static var _test_week_number := -1
static var _test_week_key := -1
static var _test_unix_time := -1


func _ready() -> void:
	schedule_rotation_check()


static func get_current_spotlight_location() -> String:
	var data := _load_config()
	var override_location := String(data.get("override_location", ""))
	var override_until := int(data.get("override_until", 0))
	if override_location != "" and CITY_LOCATION_TYPES.has(override_location):
		if override_until == 0 or override_until > _now_unix():
			return override_location
	return get_location_for_week_number(_current_iso_week_number())


static func is_spotlight(location_type: String) -> bool:
	return location_type != "" and location_type == get_current_spotlight_location()


static func get_spotlight_display_name() -> String:
	var location_type := get_current_spotlight_location()
	return String(LOCATION_DISPLAY_NAMES.get(location_type, location_type))


func schedule_rotation_check() -> void:
	var current_week := _current_week_key()
	var data := _load_config()
	var last_checked_week := int(data.get("last_checked_week", -1))
	if last_checked_week == current_week:
		return
	_save_config({
		"last_checked_week": current_week,
		"override_location": String(data.get("override_location", "")),
		"override_until": int(data.get("override_until", 0)),
	})
	var next_location := get_current_spotlight_location()
	spotlight_changed.emit(next_location)
	if is_inside_tree():
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus != null and event_bus.has_method("emit_weekly_spotlight_changed"):
			event_bus.emit_weekly_spotlight_changed(next_location)


static func needs_rotation_check() -> bool:
	return int(_load_config().get("last_checked_week", -1)) != _current_week_key()


static func get_location_for_week_number(week_number: int) -> String:
	var index := posmod(week_number - 1, CITY_LOCATION_TYPES.size())
	return String(CITY_LOCATION_TYPES[index])


static func set_override(location_type: String, override_until: int = 0) -> void:
	var data := _load_config()
	_save_config({
		"last_checked_week": int(data.get("last_checked_week", -1)),
		"override_location": location_type,
		"override_until": override_until,
	})


static func clear_override() -> void:
	set_override("", 0)


static func _load_config() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return {"last_checked_week": -1, "override_location": "", "override_until": 0}
	return {
		"last_checked_week": int(cfg.get_value(SECTION, "last_checked_week", -1)),
		"override_location": String(cfg.get_value(SECTION, "override_location", "")),
		"override_until": int(cfg.get_value(SECTION, "override_until", 0)),
	}


static func _save_config(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SECTION, "last_checked_week", int(data.get("last_checked_week", -1)))
	cfg.set_value(SECTION, "override_location", String(data.get("override_location", "")))
	cfg.set_value(SECTION, "override_until", int(data.get("override_until", 0)))
	if cfg.save(CFG_PATH) != OK:
		push_error("[WeeklySpotlightManager] Save failed: %s" % CFG_PATH)


static func _current_iso_week_number() -> int:
	if _test_week_number > 0:
		return _test_week_number
	var date := Time.get_date_dict_from_system()
	return _iso_week_number(int(date.year), int(date.month), int(date.day))


static func _current_week_key() -> int:
	if _test_week_key > 0:
		return _test_week_key
	var date := Time.get_date_dict_from_system()
	var iso_year := _iso_week_year(int(date.year), int(date.month), int(date.day))
	var iso_week := _iso_week_number(int(date.year), int(date.month), int(date.day))
	return iso_year * 100 + iso_week


static func _iso_week_number(year: int, month: int, day: int) -> int:
	var day_of_year := _day_of_year(year, month, day)
	var weekday := _iso_weekday(year, month, day)
	var week := int(floor(float(day_of_year - weekday + 10) / 7.0))
	if week < 1:
		return _weeks_in_iso_year(year - 1)
	if week > _weeks_in_iso_year(year):
		return 1
	return week


static func _iso_week_year(year: int, month: int, day: int) -> int:
	var week := int(floor(float(_day_of_year(year, month, day) - _iso_weekday(year, month, day) + 10) / 7.0))
	if week < 1:
		return year - 1
	if week > _weeks_in_iso_year(year):
		return year + 1
	return year


static func _weeks_in_iso_year(year: int) -> int:
	var jan_1 := _iso_weekday(year, 1, 1)
	var dec_31 := _iso_weekday(year, 12, 31)
	return 53 if jan_1 == 4 or dec_31 == 4 else 52


static func _iso_weekday(year: int, month: int, day: int) -> int:
	var days := _days_from_civil(year, month, day)
	return posmod(days + 3, 7) + 1


static func _day_of_year(year: int, month: int, day: int) -> int:
	var days := day
	for m in range(1, month):
		days += _days_in_month(year, m)
	return days


static func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
	return 30


static func _is_leap_year(year: int) -> bool:
	return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)


static func _days_from_civil(year: int, month: int, day: int) -> int:
	var y := year - (1 if month <= 2 else 0)
	var era := int(floor(float(y) / 400.0))
	var yoe := y - era * 400
	var mp := month + (-3 if month > 2 else 9)
	var doy := int(floor(float(153 * mp + 2) / 5.0)) + day - 1
	var doe := yoe * 365 + int(floor(float(yoe) / 4.0)) - int(floor(float(yoe) / 100.0)) + doy
	return era * 146097 + doe - 719468


static func _now_unix() -> int:
	return _test_unix_time if _test_unix_time >= 0 else int(Time.get_unix_time_from_system())
