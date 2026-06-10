extends Node2D

var body_color    = Palette.CAT_SIAM_BODY
var light_color   = Palette.CAT_SIAM_HIGH
var outline_color = Palette.CAT_SIAM_POINT

func _ready():
	var static_body = StaticBody2D.new()
	static_body.collision_layer = 0
	static_body.collision_mask = 0
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 80)
	collision.shape = shape
	collision.position = Vector2(0, 4)
	static_body.add_child(collision)
	add_child(static_body)
	queue_redraw()

func _draw():
	var swing = 0.0
	var tail_sway = 0.0
	if get_parent() and "leg_swing_offset" in get_parent():
		swing = get_parent().leg_swing_offset
		if get_parent()._is_walking:
			tail_sway = sin(get_parent()._time * 3.0) * 8.0
	var leg_color = body_color.darkened(0.15)
	var mouth_color = Color(0.35, 0.25, 0.2)

	draw_ellipse(Vector2(0, 44), 34.0, 6.0, Color(0.2, 0.15, 0.1, 0.25))

	var tail_points = PackedVector2Array([
		Vector2(44 + tail_sway * 0.2, 18),
		Vector2(60 + tail_sway * 0.6, 5),
		Vector2(68 + tail_sway * 1.0, -12),
		Vector2(62 + tail_sway * 0.8, -28),
		Vector2(50 + tail_sway * 0.4, -24)
	])
	draw_polyline(tail_points, body_color, 4.0, true)

	draw_rect(Rect2(10, 30 - swing, 10, 16), leg_color, true)
	draw_rect(Rect2(26, 30 - swing, 10, 16), leg_color, true)

	draw_ellipse(Vector2(0, 8), 42.0, 34.0, body_color)
	draw_circle(Vector2(0, -28), 20, body_color)

	draw_colored_polygon(PackedVector2Array([Vector2(-14, -42), Vector2(-30, -65), Vector2(-4, -58)]), body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -45), Vector2(-25, -62), Vector2(-6, -56)]), Color(0.95, 0.75, 0.75))
	draw_colored_polygon(PackedVector2Array([Vector2(14, -42), Vector2(30, -65), Vector2(4, -58)]), body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(14, -45), Vector2(25, -62), Vector2(6, -56)]), Color(0.95, 0.75, 0.75))

	draw_rect(Rect2(-30, 28 + swing, 10, 18), leg_color, true)
	draw_rect(Rect2(-14, 28 + swing, 10, 18), leg_color, true)

	draw_colored_polygon(PackedVector2Array([Vector2(-4, -22), Vector2(4, -22), Vector2(0, -18)]), Color(0.9, 0.6, 0.6))
	draw_arc(Vector2(-5, -17), 5, deg_to_rad(200), deg_to_rad(270), 8, mouth_color, 1.5)
	draw_arc(Vector2(5, -17), 5, deg_to_rad(270), deg_to_rad(340), 8, mouth_color, 1.5)

	draw_circle(Vector2(-10, -32), 2.5, Color(1, 1, 1, 0.9))
	draw_circle(Vector2(10, -32), 2.5, Color(1, 1, 1, 0.9))
