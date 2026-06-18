extends "res://ui/UIPage.gd"

var _settings_rect := Rect2()
var _later_rect := Rect2()

func _ready() -> void:
	super._ready()
	_add_background()
	_layout_hotspots()

func _add_background() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/art/ui/perm_denied.png")
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	bg.stretch_mode = TextureRect.STRETCH_KEEP
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _layout_hotspots() -> void:
	var screen := get_viewport_rect().size
	_settings_rect = Rect2(Vector2((screen.x - 520.0) * 0.5, 980.0), Vector2(520.0, 70.0))
	_later_rect = Rect2(Vector2((screen.x - 260.0) * 0.5, 1090.0), Vector2(260.0, 64.0))

func _gui_input(event: InputEvent) -> void:
	var pos: Variant = _released_position(event)
	if pos == null:
		return
	if _settings_rect.has_point(pos):
		_open_settings()
	elif _later_rect.has_point(pos):
		UIManager.replace("res://scenes/S05_ReadOnlyGarden.tscn")

func _open_settings() -> void:
	var step_counter := Engine.get_singleton("StepCounter")
	if step_counter != null:
		if step_counter.has_method("openAppSettings"):
			step_counter.call("openAppSettings")
			return
		if step_counter.has_method("open_app_settings"):
			step_counter.call("open_app_settings")

func _released_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and not event.pressed:
		return event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		return event.position
	return null
