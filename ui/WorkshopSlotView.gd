extends Control

signal slot_pressed(slot_index: int)

const SLOT_SIZE := Vector2(120.0, 120.0)
const CORNER_RADIUS := 14.0
const ARC_WIDTH := 8.0
const ARC_POINT_COUNT := 72

var slot_index: int = 0
var current_energy: float = 0.0
var max_energy: float = 3000.0
var status: String = "filling"
var gift_icon_name: String = ""

var _shimmer_time := 0.0
var _pulse_time := 0.0

func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	if size == Vector2.ZERO:
		size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	start_pulse_animation()

func _process(delta: float) -> void:
	if status == "filling":
		_tick_filling_effect(delta)
	elif status == "box_ready":
		_pulse_time += delta
		queue_redraw()

func _draw() -> void:
	match status:
		"box_ready":
			_draw_box_ready()
		"box_opened":
			_draw_box_opened()
		_:
			_draw_filling()

func update_display() -> void:
	queue_redraw()

func set_energy(current: float, max: float) -> void:
	current_energy = maxf(current, 0.0)
	max_energy = maxf(max, 1.0)
	queue_redraw()

func set_status(new_status: String) -> void:
	status = new_status
	start_pulse_animation()
	queue_redraw()

func start_pulse_animation() -> void:
	set_process(status == "filling" or status == "box_ready")

func _gui_input(event: InputEvent) -> void:
	if status != "box_ready":
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			slot_pressed.emit(slot_index)
			accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		slot_pressed.emit(slot_index)
		accept_event()

func _tick_filling_effect(delta: float) -> void:
	_shimmer_time += delta
	queue_redraw()

func _draw_filling() -> void:
	var rect := _slot_rect()
	_draw_rounded_rect(rect, CORNER_RADIUS, Color("#333333"))
	var progress := _energy_progress()
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.32
	var shimmer := (sin(_shimmer_time * 4.0) + 1.0) * 0.5
	var progress_color := Color("#888888").lerp(Color("#FFD700"), progress)
	progress_color.a = 0.72 + shimmer * 0.28
	draw_arc(center, radius, 0.0, TAU, ARC_POINT_COUNT, Color(0.20, 0.20, 0.20, 1.0), ARC_WIDTH)
	if progress > 0.0:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * progress, ARC_POINT_COUNT, progress_color, ARC_WIDTH)
	var energy_text := "%d/%d" % [int(round(current_energy)), int(round(max_energy))]
	_draw_centered_text(energy_text, Vector2(0.0, center.y + 6.0), size.x, 15, Color.WHITE)

func _draw_box_ready() -> void:
	var rect := _slot_rect()
	_draw_rounded_rect(rect, CORNER_RADIUS, Color("#333333"))
	var pulse := (sin(_pulse_time * 4.2) + 1.0) * 0.5
	var glow := Color("#FF6B6B")
	glow.a = 0.45 + pulse * 0.45
	_draw_rounded_rect_outline(rect.grow(-2.0), CORNER_RADIUS, glow, 4.0)
	_draw_gift_box(rect.get_center() + Vector2(0.0, -6.0), Color("#FFD166"), Color("#FF6B6B"))
	_draw_centered_text("点击开启", Vector2(0.0, rect.position.y + rect.size.y - 28.0), size.x, 16, Color("#FFE0E0"))

func _draw_box_opened() -> void:
	var rect := _slot_rect()
	_draw_rounded_rect(rect, CORNER_RADIUS, Color(0.40, 0.40, 0.40, 0.5))
	_draw_open_box(rect.get_center() + Vector2(0.0, -4.0), Color("#B8AFA7"), Color("#E0D4C8"))
	if gift_icon_name != "":
		_draw_gift_icon(gift_icon_name, rect.get_center() + Vector2(0.0, -20.0))
	_draw_centered_text("已开启", Vector2(0.0, rect.position.y + rect.size.y - 28.0), size.x, 16, Color("#DDDDDD"))

func _draw_gift_box(center: Vector2, box_color: Color, ribbon_color: Color) -> void:
	var body := Rect2(center + Vector2(-24.0, -8.0), Vector2(48.0, 32.0))
	var lid := Rect2(center + Vector2(-28.0, -18.0), Vector2(56.0, 12.0))
	draw_rect(body, box_color)
	draw_rect(lid, box_color.lightened(0.12))
	draw_rect(Rect2(body.position.x + body.size.x * 0.43, body.position.y, body.size.x * 0.14, body.size.y), ribbon_color)
	draw_rect(Rect2(lid.position.x, lid.position.y + lid.size.y * 0.34, lid.size.x, lid.size.y * 0.28), ribbon_color)
	draw_line(center + Vector2(-4.0, -18.0), center + Vector2(-18.0, -30.0), ribbon_color, 3.0)
	draw_line(center + Vector2(4.0, -18.0), center + Vector2(18.0, -30.0), ribbon_color, 3.0)
	draw_line(center + Vector2(-18.0, -30.0), center + Vector2(-4.0, -30.0), ribbon_color, 3.0)
	draw_line(center + Vector2(18.0, -30.0), center + Vector2(4.0, -30.0), ribbon_color, 3.0)

func _draw_open_box(center: Vector2, box_color: Color, flap_color: Color) -> void:
	var body := Rect2(center + Vector2(-25.0, -2.0), Vector2(50.0, 28.0))
	draw_rect(body, box_color)
	draw_line(body.position, body.position + Vector2(body.size.x, 0.0), Color("#8F8178"), 2.0)
	var left_flap := PackedVector2Array([center + Vector2(-25.0, -2.0), center + Vector2(-48.0, -18.0), center + Vector2(-20.0, -24.0), center + Vector2(0.0, -6.0)])
	var right_flap := PackedVector2Array([center + Vector2(25.0, -2.0), center + Vector2(48.0, -18.0), center + Vector2(20.0, -24.0), center + Vector2(0.0, -6.0)])
	draw_colored_polygon(left_flap, flap_color)
	draw_colored_polygon(right_flap, flap_color.lightened(0.08))
	draw_line(center + Vector2(-25.0, -2.0), center + Vector2(-48.0, -18.0), Color("#8F8178"), 2.0)
	draw_line(center + Vector2(25.0, -2.0), center + Vector2(48.0, -18.0), Color("#8F8178"), 2.0)

func _draw_gift_icon(icon_name: String, center: Vector2) -> void:
	match icon_name:
		"toy_yarn":
			draw_circle(center, 10.0, Color("#B084F5"))
			draw_arc(center, 6.0, -0.4, PI + 0.6, 28, Color("#F7D6FF"), 2.0)
			draw_arc(center + Vector2(1.0, 1.0), 9.0, PI * 0.15, PI * 1.25, 28, Color("#7D5BD6"), 2.0)
		"flower_rose":
			draw_circle(center, 5.0, Color("#FF6B6B"))
			for i in range(6):
				var angle := TAU * float(i) / 6.0
				draw_circle(center + Vector2(cos(angle), sin(angle)) * 7.0, 5.0, Color("#FF8E8E"))
			draw_line(center + Vector2(0.0, 8.0), center + Vector2(0.0, 18.0), Color("#74C476"), 2.0)
		_:
			draw_circle(center, 10.0, Color("#FFD700"))
			draw_circle(center, 4.0, Color("#FFFFFF"))

func _slot_rect() -> Rect2:
	var draw_size := Vector2(minf(size.x, SLOT_SIZE.x), minf(size.y, SLOT_SIZE.y))
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		draw_size = SLOT_SIZE
	return Rect2((size - draw_size) * 0.5, draw_size)

func _energy_progress() -> float:
	if max_energy <= 0.0:
		return 0.0
	return clampf(current_energy / max_energy, 0.0, 1.0)

func _draw_centered_text(text: String, top_left: Vector2, width: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos := Vector2(top_left.x + (width - text_size.x) * 0.5, top_left.y + text_size.y)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position.x + r, rect.position.y, rect.size.x - r * 2.0, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + r, rect.size.x, rect.size.y - r * 2.0), color)
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)

func _draw_rounded_rect_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var left := rect.position.x; var right := rect.position.x + rect.size.x
	var top := rect.position.y; var bottom := rect.position.y + rect.size.y
	draw_line(Vector2(left + r, top), Vector2(right - r, top), color, width)
	draw_line(Vector2(right, top + r), Vector2(right, bottom - r), color, width)
	draw_line(Vector2(right - r, bottom), Vector2(left + r, bottom), color, width)
	draw_line(Vector2(left, bottom - r), Vector2(left, top + r), color, width)
	draw_arc(Vector2(left + r, top + r), r, PI, PI * 1.5, 18, color, width)
	draw_arc(Vector2(right - r, top + r), r, PI * 1.5, TAU, 18, color, width)
	draw_arc(Vector2(right - r, bottom - r), r, 0.0, PI * 0.5, 18, color, width)
	draw_arc(Vector2(left + r, bottom - r), r, PI * 0.5, PI, 18, color, width)
