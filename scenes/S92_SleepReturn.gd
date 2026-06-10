extends "res://ui/UIPage.gd"

var _continue_rect := Rect2()
var _days := 0

func _on_page_setup(data: Dictionary) -> void:
	_days = int(data.get("days", _days_since_last_open()))

func _gui_input(event: InputEvent) -> void:
	var pos: Variant = _released_position(event)
	if pos != null and _continue_rect.has_point(pos):
		UIManager.replace("res://scenes/S04_GardenMain.tscn")

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE)
	_draw_centered_text("欢迎回来", 650.0, 36, Palette.TEXT_PRIMARY)
	_draw_centered_text("你离开了 %d 天" % _days, 730.0, 28, Palette.TEXT_SECONDARY)
	_draw_centered_text("花园还在等你", 790.0, 24, Palette.TEXT_SECONDARY)
	_continue_rect = Rect2(Vector2((screen.x - 480.0) * 0.5, 990.0), Vector2(480.0, 70.0))
	_draw_button(_continue_rect, "继续")

func _days_since_last_open() -> int:
	if EnergyEngine == null:
		return 0
	var elapsed := max(Time.get_unix_time_from_system() - EnergyEngine.created_at, 0.0)
	return int(floor(elapsed / float(24 * 60 * 60)))

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
