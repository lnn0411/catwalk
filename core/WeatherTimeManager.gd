extends Node

enum TimePeriod { DAY, SUNSET, NIGHT }
enum WeatherType { CLEAR, RAIN, SNOW }

signal period_changed(period: int)
signal weather_changed(weather: int)

const SAVE_PATH := "user://weather_time.cfg"
const RAIN_PROBABILITY := 0.15
const TRANSITION_DURATION := 2.0

var current_period: int = TimePeriod.DAY
var current_weather: int = WeatherType.CLEAR
var _last_weather_date := ""
var _period_blend_value := 0.0
var _weather_rng := RandomNumberGenerator.new()
var _check_timer: Timer
var _blend_tween: Tween


func _ready() -> void:
	_load_state()
	_update_period()
	_update_weather()
	_check_timer = Timer.new()
	_check_timer.wait_time = 30.0
	_check_timer.timeout.connect(_on_check_timer_timeout)
	add_child(_check_timer)
	_check_timer.start()


func _on_check_timer_timeout() -> void:
	_update_period()
	_update_weather()


func _update_period() -> void:
	var td := Time.get_time_dict_from_system()
	var h: int = td.hour
	var next_period := TimePeriod.DAY
	if h >= 6 and h < 18:
		next_period = TimePeriod.DAY
	elif h >= 18 and h < 20:
		next_period = TimePeriod.SUNSET
	else:
		next_period = TimePeriod.NIGHT

	if next_period == current_period:
		_period_blend_value = _period_to_blend(current_period)
		return

	var from_blend := _period_blend_value
	if _blend_tween != null and _blend_tween.is_running():
		_blend_tween.kill()
	current_period = next_period
	_blend_tween = create_tween()
	_blend_tween.tween_property(self, "_period_blend_value", _period_to_blend(current_period), TRANSITION_DURATION) \
		.from(from_blend)
	period_changed.emit(current_period)


func _update_weather() -> void:
	var today := _today_key()
	if _last_weather_date == today:
		return
	_last_weather_date = today

	var previous_weather := current_weather
	var dd := Time.get_date_dict_from_system()
	var month: int = dd.month
	_weather_rng.randomize()
	if month >= 12 or month <= 2:
		if _weather_rng.randf() < RAIN_PROBABILITY:
			current_weather = WeatherType.SNOW
		else:
			current_weather = WeatherType.CLEAR
	elif _weather_rng.randf() < RAIN_PROBABILITY:
		current_weather = WeatherType.RAIN
	else:
		current_weather = WeatherType.CLEAR

	_save_state()
	if current_weather != previous_weather:
		weather_changed.emit(current_weather)


func get_weather_bonus_data() -> Dictionary:
	return {
		"period": current_period,
		"weather": current_weather,
		"description": _get_description()
	}


func get_period_tint_color(period: int = current_period) -> Color:
	match period:
		TimePeriod.SUNSET:
			return Color(1.0, 0.72, 0.42, 1.0)
		TimePeriod.NIGHT:
			return Color(0.42, 0.54, 0.9, 1.0)
		_:
			return Color.WHITE


func get_period_tint_strength(period: int = current_period) -> float:
	match period:
		TimePeriod.SUNSET:
			return 0.22
		TimePeriod.NIGHT:
			return 0.38
		_:
			return 0.0


func _get_description() -> String:
	var p := ""
	match current_period:
		TimePeriod.DAY: p = "白天"
		TimePeriod.SUNSET: p = "黄昏"
		TimePeriod.NIGHT: p = "夜晚"
	var w := ""
	match current_weather:
		WeatherType.CLEAR: w = "晴"
		WeatherType.RAIN: w = "雨"
		WeatherType.SNOW: w = "雪"
	return p + " · " + w


func _period_to_blend(period: int) -> float:
	match period:
		TimePeriod.SUNSET:
			return 1.0
		TimePeriod.NIGHT:
			return 2.0
		_:
			return 0.0


func _today_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]


func _load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	current_weather = int(cfg.get_value("state", "current_weather", WeatherType.CLEAR))
	_last_weather_date = String(cfg.get_value("state", "last_weather_date", ""))


func _save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("state", "current_weather", current_weather)
	cfg.set_value("state", "last_weather_date", _last_weather_date)
	cfg.save(SAVE_PATH)
