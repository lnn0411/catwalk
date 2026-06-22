extends Control
class_name GiftItemView

signal gift_selected(gift_id: String)

const ITEM_SIZE := Vector2(120.0, 132.0)
const CORNER_RADIUS := 10.0
const ICON_SIZE := Vector2(48.0, 48.0)

var gift_id: String = ""
var count: int = 0
var item_data: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = ITEM_SIZE
	if size == Vector2.ZERO:
		size = ITEM_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(new_gift_id: String, new_count: int, new_item_data: Dictionary) -> void:
	gift_id = new_gift_id
	count = max(new_count, 0)
	item_data = new_item_data.duplicate(true)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			gift_selected.emit(gift_id)
			accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		gift_selected.emit(gift_id)
		accept_event()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size).grow(-4.0)
	var rarity := String(item_data.get("rarity", "common"))
	var bg_color := _rarity_color(rarity)
	var fill_color := Color("#FFFFFF")
	fill_color.a = 0.94
	_draw_rounded_rect(rect, CORNER_RADIUS, fill_color)
	if bg_color.a > 0.0:
		_draw_rounded_rect(rect, CORNER_RADIUS, _with_alpha(bg_color, 0.22))
		_draw_rounded_rect_outline(rect, CORNER_RADIUS, bg_color, 2.0)
	else:
		_draw_rounded_rect_outline(rect, CORNER_RADIUS, Color("#D8D1C8"), 1.0)
	var icon_rect := Rect2(Vector2((size.x - ICON_SIZE.x) * 0.5, 24.0), ICON_SIZE)
	_draw_category_icon(String(item_data.get("category", "")), icon_rect, _icon_color(rarity))
	_draw_count_badge(rect)
	_draw_name(rect)

func _draw_count_badge(rect: Rect2) -> void:
	if count <= 1:
		return
	var badge_text := "x%d" % count
	var font := get_theme_default_font()
	var font_size := 13
	var text_size := font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var badge_size := Vector2(maxf(30.0, text_size.x + 12.0), 22.0)
	var badge_rect := Rect2(rect.position + Vector2(rect.size.x - badge_size.x - 7.0, 7.0), badge_size)
	_draw_rounded_rect(badge_rect, 8.0, Color("#333333"))
	draw_string(font, badge_rect.position + Vector2((badge_rect.size.x - text_size.x) * 0.5, 15.5), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)

func _draw_name(rect: Rect2) -> void:
	var name := String(item_data.get("name", gift_id))
	var font := get_theme_default_font()
	var font_size := 14
	var max_width := rect.size.x - 18.0
	var text := _truncate_text(name, font, font_size, max_width)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos := Vector2(rect.position.x + (rect.size.x - text_size.x) * 0.5, rect.position.y + rect.size.y - 17.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, Color("#333333"))

func _draw_category_icon(category: String, view_rect: Rect2, color: Color) -> void:
	var center := view_rect.get_center()
	match category:
		"toy":
			draw_circle(center, 18.0, color)
			draw_arc(center, 11.0, -0.3, PI + 0.4, 32, Color("#FFFFFF"), 3.0)
			draw_arc(center + Vector2(1.0, 2.0), 16.0, PI * 0.15, PI * 1.15, 32, color.darkened(0.28), 2.0)
		"flower":
			for i in range(6):
				var angle := TAU * float(i) / 6.0
				draw_circle(center + Vector2(cos(angle), sin(angle)) * 11.0, 8.0, color)
			draw_circle(center, 7.0, Color("#FFD166"))
			draw_line(center + Vector2(0.0, 16.0), center + Vector2(0.0, 25.0), Color("#74C476"), 3.0)
		"deco":
			var points := PackedVector2Array([center + Vector2(0.0, -22.0), center + Vector2(18.0, -4.0), center + Vector2(12.0, 21.0), center + Vector2(-12.0, 21.0), center + Vector2(-18.0, -4.0)])
			draw_colored_polygon(points, color)
			draw_polyline(points + PackedVector2Array([points[0]]), color.darkened(0.3), 2.0)
		_:
			var body := Rect2(center + Vector2(-18.0, -8.0), Vector2(36.0, 28.0))
			var lid := Rect2(center + Vector2(-21.0, -18.0), Vector2(42.0, 12.0))
			draw_rect(body, color)
			draw_rect(lid, color.lightened(0.12))
			draw_rect(Rect2(body.position.x + 15.0, body.position.y, 6.0, body.size.y), Color("#FF6B6B"))
			draw_rect(Rect2(lid.position.x, lid.position.y + 4.0, lid.size.x, 4.0), Color("#FF6B6B"))

func _truncate_text(text: String, font: Font, font_size: int, max_width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
		return text
	var result := text
	while result.length() > 0:
		result = result.left(result.length() - 1)
		var candidate := result + "..."
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
			return candidate
	return "..."

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":     return Color("#9BB8D4")
		"epic":     return Color("#8E6FA8")
		"legendary": return Color("#FFD700")
		_:          return Color(1.0, 1.0, 1.0, 0.0)

func _icon_color(rarity: String) -> Color:
	match rarity:
		"rare":     return Color("#7EA8CF")
		"epic":     return Color("#9B74C8")
		"legendary": return Color("#F5B841")
		_:          return Color("#D9B46F")

func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color; result.a = alpha; return result

func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position.x + r, rect.position.y, rect.size.x - r * 2.0, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + r, rect.size.x, rect.size.y - r * 2.0), color)
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)

func _draw_rounded_rect_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var steps := 8
	for i in range(steps + 1): pts.append(rect.position + Vector2(r, r) + Vector2(cos(PI + PI * 0.5 * float(i) / float(steps)), sin(PI + PI * 0.5 * float(i) / float(steps))) * r)
	for i in range(steps + 1): pts.append(rect.position + Vector2(rect.size.x - r, r) + Vector2(cos(PI * 1.5 + PI * 0.5 * float(i) / float(steps)), sin(PI * 1.5 + PI * 0.5 * float(i) / float(steps))) * r)
	for i in range(steps + 1): pts.append(rect.position + Vector2(rect.size.x - r, rect.size.y - r) + Vector2(cos(PI * 0.5 * float(i) / float(steps)), sin(PI * 0.5 * float(i) / float(steps))) * r)
	for i in range(steps + 1): pts.append(rect.position + Vector2(r, rect.size.y - r) + Vector2(cos(PI * 0.5 + PI * 0.5 * float(i) / float(steps)), sin(PI * 0.5 + PI * 0.5 * float(i) / float(steps))) * r)
	pts.append(pts[0])
	draw_polyline(pts, color, width)
