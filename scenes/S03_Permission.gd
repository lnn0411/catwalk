extends "res://ui/UIPage.gd"

const ALLOW_BUTTON_SIZE := Vector2(480.0, 56.0)
const LATER_BUTTON_SIZE := Vector2(220.0, 56.0)
const SETTINGS_BUTTON_SIZE := Vector2(480.0, 56.0)

var _allow_rect := Rect2()
var _later_rect := Rect2()
var _settings_rect := Rect2()
var _show_settings := false
var _requesting := false

func _ready() -> void:
	super._ready()
	_add_background()
	_layout_hotspots()

func _add_background() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/art/ui/permission.png")
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	bg.stretch_mode = TextureRect.STRETCH_KEEP
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _layout_hotspots() -> void:
	var screen := get_viewport_rect().size
	_allow_rect = Rect2(Vector2((screen.x - ALLOW_BUTTON_SIZE.x) * 0.5, 980.0), ALLOW_BUTTON_SIZE)
	_later_rect = Rect2(Vector2((screen.x - LATER_BUTTON_SIZE.x) * 0.5, screen.y - 250.0), LATER_BUTTON_SIZE)
	_settings_rect = Rect2(Vector2((screen.x - SETTINGS_BUTTON_SIZE.x) * 0.5, 900.0), SETTINGS_BUTTON_SIZE)

func handle_back() -> bool:
	return true

func _gui_input(event: InputEvent) -> void:
	if _requesting:
		return
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and not event.pressed:
		released = true
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		released = true
		pos = event.position
	if not released:
		return
	if _show_settings and _settings_rect.has_point(pos):
		_open_app_settings()
	elif _allow_rect.has_point(pos):
		_on_allow_pressed()
	elif _later_rect.has_point(pos):
		UIManager.replace("res://scenes/S02_Loading.tscn")

func _on_allow_pressed() -> void:
	_requesting = true
	var step_counter := Engine.get_singleton("StepCounter")
	if step_counter == null:
		# Editor / non-Android → skip permission, go to garden
		UIManager.replace("res://scenes/S02_Loading.tscn")
		return
	if step_counter.has_signal("permission_result") and not step_counter.permission_result.is_connected(_on_permission_result):
		step_counter.permission_result.connect(_on_permission_result, CONNECT_ONE_SHOT)
	if step_counter.has_method("hasActivityRecognitionPermission") and bool(step_counter.call("hasActivityRecognitionPermission")):
		_on_permission_result(true)
		return
	if step_counter.has_method("requestActivityRecognitionPermission"):
		step_counter.call("requestActivityRecognitionPermission")
	elif step_counter.has_method("request_permission"):
		step_counter.call("request_permission")
	else:
		_on_permission_result(false)

func _on_permission_result(granted: bool) -> void:
	_requesting = false
	if granted:
		SaveManager.save_all()
		UIManager.replace("res://scenes/S02_Loading.tscn")
		return
	_show_settings = true
	var step_counter := Engine.get_singleton("StepCounter")
	if step_counter != null:
		if step_counter.has_method("isPermissionDeniedPermanently") and bool(step_counter.call("isPermissionDeniedPermanently")):
			UIManager.replace("res://scenes/S91_PermDenied.tscn")
			return
		if step_counter.has_method("is_permission_denied_permanently") and bool(step_counter.call("is_permission_denied_permanently")):
			UIManager.replace("res://scenes/S91_PermDenied.tscn")
			return

func _open_app_settings() -> void:
	var sc := Engine.get_singleton("StepCounter")
	if sc and sc.has_method("openAppSettings"):
		sc.call("openAppSettings")
