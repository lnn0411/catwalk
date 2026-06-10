extends Node2D

var body_color    = Palette.CAT_BRIT_MID
var light_color   = Palette.CAT_BRIT_LIGHT
var outline_color = Color("#6E7278")

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

	draw_ellipse(Vector2(0, 46), 42.0, 7.0, Color(0.2, 0.15, 0.1, 0.25))

	var tail_points = PackedVector2Array([
		Vector2(48 + tail_sway * 0.2, 20),
		Vector2(62 + tail_sway * 0.6, 8),
		Vector2(68 + tail_sway * 1.0, -10),
		Vector2(58 + tail_sway * 0.8, -24),
		Vector2(46 + tail_sway * 0.4, -20)
	])
	draw_polyline(tail_points, body_color, 5.0, true)

	draw_rect(Rect2(8, 30 - swing, 10, 12), leg_color, true)
	draw_rect(Rect2(24, 30 - swing, 10, 12), leg_color, true)

	draw_ellipse(Vector2(0, 8), 46.0, 40.0, body_color)
	draw_circle(Vector2(0, -28), 24, body_color)

	draw_colored_polygon(PackedVector2Array([Vector2(-16, -46), Vector2(-26, -60), Vector2(-6, -57)]), body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -49), Vector2(-23, -58), Vector2(-8, -55)]), Color(0.95, 0.75, 0.75))
	draw_colored_polygon(PackedVector2Array([Vector2(16, -46), Vector2(26, -60), Vector2(6, -57)]), body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(16, -49), Vector2(23, -58), Vector2(8, -55)]), Color(0.95, 0.75, 0.75))

	draw_rect(Rect2(-28, 28 + swing, 10, 14), leg_color, true)
	draw_rect(Rect2(-12, 28 + swing, 10, 14), leg_color, true)

	draw_colored_polygon(PackedVector2Array([Vector2(-4, -22), Vector2(4, -22), Vector2(0, -18)]), Color(0.9, 0.6, 0.6))
	draw_arc(Vector2(-5, -17), 5, deg_to_rad(200), deg_to_rad(270), 8, mouth_color, 1.5)
	draw_arc(Vector2(5, -17), 5, deg_to_rad(270), deg_to_rad(340), 8, mouth_color, 1.5)

	draw_circle(Vector2(-10, -32), 2.5, Color(1, 1, 1, 0.9))
	draw_circle(Vector2(10, -32), 2.5, Color(1, 1, 1, 0.9))
