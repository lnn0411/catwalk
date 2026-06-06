extends Node

signal steps_updated(delta: int, total: int)

const PLUGIN_NAME := "StepCounter"

var today_steps: int = 0
var total_steps: int = 0
var last_plugin_steps: int = 0
var last_step_date: String = ""
var step_plugin: Object

func _ready() -> void:
	last_step_date = _today_key()
	_load_plugin()

func add_mock_steps(n: int) -> void:
	_check_daily_reset()
	var delta: int = max(n, 0)
	if delta <= 0:
		_emit_steps_updated(0)
		return

	today_steps += delta
	total_steps += delta
	_emit_steps_updated(delta)

func apply_save(data: Dictionary) -> void:
	today_steps = max(int(data.get("today_steps", 0)), 0)
	total_steps = max(int(data.get("total_steps", 0)), 0)
	last_plugin_steps = max(int(data.get("last_plugin_steps", 0)), 0)
	last_step_date = String(data.get("last_step_date", _today_key()))
	_check_daily_reset()
	_emit_steps_updated(0)

func get_today_steps() -> int:
	_check_daily_reset()
	return today_steps

func get_total_steps() -> int:
	return total_steps

func get_save_data() -> Dictionary:
	return {
		"today_steps": today_steps,
		"total_steps": total_steps,
		"last_plugin_steps": last_plugin_steps,
		"last_step_date": last_step_date,
	}

func _load_plugin() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		step_plugin = Engine.get_singleton(PLUGIN_NAME)
		if step_plugin.has_signal("steps_changed"):
			step_plugin.steps_changed.connect(_on_plugin_steps_changed)
		_refresh_plugin_steps()
	else:
		_emit_steps_updated(0)

func _refresh_plugin_steps() -> void:
	if step_plugin == null or not step_plugin.has_method("getSteps"):
		return
	_on_plugin_steps_changed(int(step_plugin.getSteps()))

func _on_plugin_steps_changed(raw_steps: int) -> void:
	_check_daily_reset()
	raw_steps = max(raw_steps, 0)
	if raw_steps < last_plugin_steps:
		last_plugin_steps = raw_steps
		_emit_steps_updated(0)
		return

	var delta: int = raw_steps - last_plugin_steps
	last_plugin_steps = raw_steps
	if delta <= 0:
		_emit_steps_updated(0)
		return

	today_steps += delta
	total_steps += delta
	_emit_steps_updated(delta)

func _check_daily_reset() -> void:
	var today: String = _today_key()
	if last_step_date == "":
		last_step_date = today
		return
	if last_step_date != today:
		today_steps = 0
		last_plugin_steps = 0
		last_step_date = today

func _emit_steps_updated(delta: int) -> void:
	steps_updated.emit(delta, total_steps)

func _today_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]
