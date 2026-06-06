extends Node

signal steps_changed(today_steps: int, total_steps: int, delta_steps: int)
signal permission_changed(granted: bool)

const PLUGIN_NAME := "StepCounter"

var today_steps: int = 0
var total_steps: int = 0
var last_plugin_steps: int = 0
var permission_granted: bool = false
var step_plugin: Object
var debug_mode: bool = false

func _ready() -> void:
	_load_state()
	_load_plugin()

func _load_state() -> void:
	if SaveManager:
		var state := SaveManager.get_step_state()
		today_steps = int(state.get("today_steps", 0))
		total_steps = int(state.get("total_steps", 0))
		last_plugin_steps = int(state.get("last_plugin_steps", 0))

func _load_plugin() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		step_plugin = Engine.get_singleton(PLUGIN_NAME)
		permission_granted = _has_permission()
		if step_plugin.has_signal("steps_changed"):
			step_plugin.steps_changed.connect(_on_plugin_steps_changed)
		if step_plugin.has_signal("permission_result"):
			step_plugin.permission_result.connect(_on_permission_result)
		_refresh_plugin_steps()
	else:
		debug_mode = true
		permission_granted = true
		_emit_steps_changed(0)

func request_permission() -> void:
	if step_plugin != null and step_plugin.has_method("requestActivityRecognitionPermission"):
		step_plugin.requestActivityRecognitionPermission()

func get_today_steps() -> int:
	return today_steps

func get_total_steps() -> int:
	return total_steps

func get_current_tier() -> int:
	if today_steps <= 1000:
		return 0
	if today_steps <= 3000:
		return 1
	if today_steps <= 5000:
		return 2
	return 3

func add_debug_steps(amount: int) -> void:
	if amount <= 0:
		return
	debug_mode = true
	today_steps += amount
	total_steps += amount
	_save_state()
	_emit_steps_changed(amount)

func set_debug_steps(value: int) -> void:
	debug_mode = true
	var next_steps: int = max(value, 0)
	var delta: int = max(next_steps - today_steps, 0)
	total_steps += delta
	today_steps = next_steps
	_save_state()
	_emit_steps_changed(delta)

func _refresh_plugin_steps() -> void:
	if step_plugin == null or not step_plugin.has_method("getSteps"):
		return
	_on_plugin_steps_changed(int(step_plugin.getSteps()))

func _on_plugin_steps_changed(raw_steps: int) -> void:
	if raw_steps < last_plugin_steps:
		last_plugin_steps = raw_steps
		_save_state()
		return

	var delta := raw_steps - last_plugin_steps
	last_plugin_steps = raw_steps
	if delta <= 0:
		_emit_steps_changed(0)
		return

	today_steps += delta
	total_steps += delta
	_save_state()
	_emit_steps_changed(delta)

func _on_permission_result(granted: bool) -> void:
	permission_granted = granted
	permission_changed.emit(granted)
	if granted:
		_refresh_plugin_steps()

func _has_permission() -> bool:
	if step_plugin != null and step_plugin.has_method("hasActivityRecognitionPermission"):
		return bool(step_plugin.hasActivityRecognitionPermission())
	return true

func _emit_steps_changed(delta: int) -> void:
	steps_changed.emit(today_steps, total_steps, delta)

func _save_state() -> void:
	if SaveManager:
		SaveManager.set_step_state({
			"today_steps": today_steps,
			"total_steps": total_steps,
			"last_plugin_steps": last_plugin_steps,
		})
