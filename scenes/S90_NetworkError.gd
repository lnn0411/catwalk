extends "res://ui/UIPage.gd"

var _retry_rect := Rect2()

func _gui_input(event: InputEvent) -> void:
	var pos: Variant = _released_position(event)
	if pos != null and _retry_rect.has_point(pos):
		UIManager.replace("res://scenes/S02_Loading.tscn")

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE)
	_draw_centered_text("网络连接失败", 700.0, 34, Palette.TEXT_PRIMARY)
	_draw_centered_text("请检查连接后重试", 770.0, 24, Palette.TEXT_SECONDARY)
	_retry_rect = Rect2(Vector2((screen.x - 480.0) * 0.5, 980.0), Vector2(480.0, 70.0))
	_draw_button(_retry_rect, "重试")

func _released_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and not event.pressed:
		return event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		return event.position
	return null

func _draw_button(rect: Rect2, text: String) -> void:
	draw_rect(rect, Palette.AMBER)
	_draw_text_in_rect(text, rect, 26, Palette.TEXT_ON_AMBER)

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((get_viewport_rect().size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_text_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, rect.position + Vector2((rect.size.x - size.x) * 0.5, (rect.size.y + size.y) * 0.5 - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
