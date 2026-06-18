extends "res://ui/UIPage.gd"

const MAIN_BUTTON_SIZE := Vector2(480.0, 60.0)
const SKIP_BUTTON_SIZE := Vector2(220.0, 50.0)

var _main_rect := Rect2()
var _skip_rect := Rect2()
var _returning_from_settings := false

func _ready() -> void:
	super._ready()
	_add_background()
	_layout_hotspots()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _returning_from_settings:
		_returning_from_settings = false
		if _check_permission():
			SaveManager.save_all()
			UIManager.replace("res://scenes/S02_Loading.tscn")

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
	_main_rect = Rect2(Vector2((screen.x - MAIN_BUTTON_SIZE.x) * 0.5, 900.0), MAIN_BUTTON_SIZE)
	_skip_rect = Rect2(Vector2((screen.x - SKIP_BUTTON_SIZE.x) * 0.5, screen.y - 250.0), SKIP_BUTTON_SIZE)

func handle_back() -> bool:
	return true

func _gui_input(event: InputEvent) -> void:
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
	if _main_rect.has_point(pos):
		_open_settings()
	elif _skip_rect.has_point(pos):
		UIManager.replace("res://scenes/S02_Loading.tscn")

## —— 内部函数 ——

func _open_settings() -> void:
	_returning_from_settings = true
	var sc := Engine.get_singleton("StepCounter")
	if sc and sc.has_method("openAppSettings"):
		sc.call("openAppSettings")

func _check_permission() -> bool:
	var sc := Engine.get_singleton("StepCounter")
	if sc == null:
		return true  # editor
	if sc.has_method("hasActivityRecognitionPermission"):
		return bool(sc.call("hasActivityRecognitionPermission"))
	return true
