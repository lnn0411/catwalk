extends "res://ui/UIPage.gd"

const PAGE_COUNT := 3
const SWIPE_THRESHOLD := 100.0
const START_BUTTON_SIZE := Vector2(360.0, 48.0)
const SKIP_BUTTON_SIZE := Vector2(180.0, 56.0)

var _current_page := 0
var _touch_start := Vector2.ZERO
var _tracking_touch := false
var _skip_rect := Rect2()
var _start_rect := Rect2()

func _ready() -> void:
	super._ready()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_tracking_touch = true
		elif _tracking_touch:
			_tracking_touch = false
			_handle_release(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_start = event.position
			_tracking_touch = true
		elif _tracking_touch:
			_tracking_touch = false
			_handle_release(event.position)

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE)

	match _current_page:
		0:
			_draw_centered_text("走出家门", screen.y * 0.35, 42, Palette.TEXT_PRIMARY)
			_draw_footsteps(screen)
		1:
			_draw_centered_text("收集能量", screen.y * 0.35, 42, Palette.TEXT_PRIMARY)
			_draw_energy_icon(screen / 2.0 + Vector2(0.0, 90.0))
		2:
			_draw_centered_text("孵化猫咪", screen.y * 0.35, 42, Palette.TEXT_PRIMARY)
			_draw_egg(screen / 2.0 + Vector2(0.0, 100.0))

	_draw_indicators(screen)
	_draw_skip_button(screen)
	if _current_page == 2:
		_draw_start_button(screen)

func _handle_release(position: Vector2) -> void:
	if _skip_rect.has_point(position):
		UIManager.replace("res://scenes/S03_Permission.tscn")
		return
	if _current_page == 2 and _start_rect.has_point(position):
		UIManager.replace("res://scenes/S03_Permission.tscn")
		return

	var dx := position.x - _touch_start.x
	if dx < -SWIPE_THRESHOLD and _current_page < PAGE_COUNT - 1:
		_next_page()
	elif dx > SWIPE_THRESHOLD and _current_page > 0:
		_prev_page()

func _next_page() -> void:
	_current_page += 1
	queue_redraw()

func _prev_page() -> void:
	_current_page -= 1
	queue_redraw()

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((get_viewport_rect().size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_footsteps(screen: Vector2) -> void:
	var start := screen / 2.0 + Vector2(-180.0, 70.0)
	for i in range(8):
		var pos := start + Vector2(float(i) * 52.0, sin(float(i) * 0.9) * 34.0)
		draw_circle(pos, 12.0, Palette.AMBER)
		draw_circle(pos + Vector2(18.0, -18.0), 6.0, Palette.AMBER)
		draw_circle(pos + Vector2(4.0, -24.0), 5.0, Palette.AMBER)
		draw_circle(pos + Vector2(-10.0, -18.0), 5.0, Palette.AMBER)

func _draw_energy_icon(center: Vector2) -> void:
	var points: PackedVector2Array = []
	for i in range(6):
		var angle := TAU * float(i) / 6.0 + PI / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * 86.0)
	draw_colored_polygon(points, Palette.AMBER)
	var bolt := PackedVector2Array([
		center + Vector2(6.0, -62.0),
		center + Vector2(-36.0, 10.0),
		center + Vector2(-4.0, 10.0),
		center + Vector2(-18.0, 66.0),
		center + Vector2(42.0, -10.0),
		center + Vector2(10.0, -10.0),
	])
	draw_colored_polygon(bolt, Palette.BG_WARM_WHITE)

func _draw_egg(center: Vector2) -> void:
	draw_ellipse(center, 80.0, 100.0, Palette.AMBER)
	var crack := [
		center + Vector2(-36.0, -8.0),
		center + Vector2(-12.0, 10.0),
		center + Vector2(4.0, -2.0),
		center + Vector2(22.0, 18.0),
		center + Vector2(44.0, 0.0),
	]
	for i in range(crack.size() - 1):
		draw_line(crack[i], crack[i + 1], Palette.BG_WARM_WHITE, 4.0)

func _draw_indicators(screen: Vector2) -> void:
	var y := screen.y - 220.0
	for i in range(PAGE_COUNT):
		var color := Palette.AMBER if i == _current_page else Palette.BORDER_DEFAULT
		draw_circle(Vector2(screen.x * 0.5 + (float(i) - 1.0) * 34.0, y), 9.0, color)

func _draw_skip_button(screen: Vector2) -> void:
	_skip_rect = Rect2(Vector2(screen.x - SKIP_BUTTON_SIZE.x - 56.0, screen.y - 150.0), SKIP_BUTTON_SIZE)
	var font := get_theme_default_font()
	var text := "跳过"
	var font_size := 24
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, _skip_rect.position + Vector2((_skip_rect.size.x - size.x) * 0.5, 36.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Palette.TEXT_SECONDARY)

func _draw_start_button(screen: Vector2) -> void:
	_start_rect = Rect2(Vector2((screen.x - START_BUTTON_SIZE.x) * 0.5, screen.y - 150.0), START_BUTTON_SIZE)
	draw_rect(_start_rect, Palette.AMBER)
	var font := get_theme_default_font()
	var text := "🐾 开始"
	var font_size := 24
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, _start_rect.position + Vector2((_start_rect.size.x - size.x) * 0.5, 33.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Palette.TEXT_ON_AMBER)
