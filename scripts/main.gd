extends Control

const PLUGIN_NAME := "StepCounter"

@onready var steps_label: Label = $VBoxContainer/StepsLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var permission_button: Button = $VBoxContainer/PermissionButton

var step_plugin: Object


func _ready() -> void:
	permission_button.pressed.connect(_on_permission_button_pressed)
	_load_plugin()


func _load_plugin() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		step_plugin = Engine.get_singleton(PLUGIN_NAME)
		status_label.text = "Step counter plugin loaded."
		if step_plugin.has_signal("steps_changed"):
			step_plugin.steps_changed.connect(_on_steps_changed)
		if step_plugin.has_signal("permission_result"):
			step_plugin.permission_result.connect(_on_permission_result)
		_refresh_steps()
	else:
		status_label.text = "Step counter plugin is only available on Android."
		permission_button.disabled = true


func _refresh_steps() -> void:
	if step_plugin == null:
		return
	var current_steps := 0
	if step_plugin.has_method("getSteps"):
		current_steps = int(step_plugin.getSteps())
	steps_label.text = str(current_steps)
	if step_plugin.has_method("hasActivityRecognitionPermission") and not step_plugin.hasActivityRecognitionPermission():
		status_label.text = "Activity recognition permission is required."
	else:
		status_label.text = "Counting steps."


func _on_permission_button_pressed() -> void:
	if step_plugin == null:
		return
	if step_plugin.has_method("requestActivityRecognitionPermission"):
		step_plugin.requestActivityRecognitionPermission()
		status_label.text = "Requesting permission..."


func _on_steps_changed(steps: int) -> void:
	steps_label.text = str(steps)
	status_label.text = "Counting steps."


func _on_permission_result(granted: bool) -> void:
	if granted:
		status_label.text = "Permission granted."
		_refresh_steps()
	else:
		status_label.text = "Permission denied."
