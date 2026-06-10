extends "res://ui/UIPage.gd"

var _settings_rect := Rect2()
var _later_rect := Rect2()

func _gui_input(event: InputEvent) -> void:
	var pos: Variant = _released_position(event)
	if pos == null:
		return
	if _settings_rect.has_point(pos):
		_open_settings()
	elif _later_rect.has_point(pos):
		UIManager.replace("res://scenes/S05_ReadOnlyGarden.tscn")

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE)
	_draw_centered_text("步数权限未开启", 690.0, 34, Palette.TEXT_PRIMARY)
	_draw_centered_text("开启后才能用步数孵化猫咪", 760.0, 24, Palette.TEXT_SECONDARY)
	_settings_rect = Rect2(Vector2((screen.x - 520.0) * 0.5, 980.0), Vector2(520.0, 70.0))
	_later_rect = Rect2(Vector2((screen.x - 260.0) * 0.5, 1090.0), Vector2(260.0, 64.0))
	_draw_button(_settings_rect, "打开设置", Palette.AMBER, Palette.TEXT_ON_AMBER)
	_draw_button(_later_rect, "稍后", Palette.BG_CEMENT, Palette.TEXT_SECONDARY)

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

func _draw_button(rect: Rect2, text: String, bg: Color, color: Color) -> void:
	draw_rect(rect, bg)
	_draw_text_in_rect(text, rect, 26, color)

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((get_viewport_rect().size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_text_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, rect.position + Vector2((rect.size.x - size.x) * 0.5, (rect.size.y + size.y) * 0.5 - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
