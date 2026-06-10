extends Node2D

var body_color    = Palette.CAT_BRIT_MID
var light_color   = Palette.CAT_BRIT_LIGHT
var outline_color = Color("#6E7278")

func _ready():
	var static_body = StaticBody2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 80)
	collision.shape = shape
	collision.position = Vector2(0, 4)
	static_body.add_child(collision)
	add_child(static_body)
	queue_redraw()

func _draw():
	# 身体 - 更圆墩 46x40
	draw_ellipse(Vector2(0, 8), 46.0, 40.0, body_color)
	draw_arc(Vector2(0, 8), 46, 0, TAU, 32, outline_color, 1.5)

	# 胸腹浅色区 - 稍大
	draw_ellipse(Vector2(0, 14), 26.0, 24.0, light_color)

	# 头 - 更大更圆 半径24
	draw_circle(Vector2(0, -28), 24, body_color)
	draw_arc(Vector2(0, -28), 24, 0, TAU, 32, outline_color, 1.5)

	# 耳朵 - 稍小圆润
	var ear_l = PackedVector2Array([Vector2(-20, -44), Vector2(-12, -32), Vector2(-28, -32)])
	var ear_r = PackedVector2Array([Vector2(20, -44), Vector2(12, -32), Vector2(28, -32)])
	draw_polygon(ear_l, [body_color])
	draw_polygon(ear_r, [body_color])

	# 眼睛 - 圆形 r=5
	draw_circle(Vector2(-9, -30), 5, outline_color)
	draw_circle(Vector2(9, -30), 5, outline_color)
	# 高光小点
	draw_circle(Vector2(-9, -31), 2, Color.WHITE)
	draw_circle(Vector2(9, -31), 2, Color.WHITE)

	# 鼻子
	draw_polygon(PackedVector2Array([Vector2(0, -24), Vector2(-3, -21), Vector2(3, -21)]),
		[Color("#D4734A")])

	# 尾巴 - 收于身侧向下
	draw_polyline(PackedVector2Array([
		Vector2(28, 10), Vector2(36, 22), Vector2(32, 34), Vector2(28, 38)
	]), outline_color, 4.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(28, 10), Vector2(36, 22), Vector2(32, 34), Vector2(28, 38)
	]), body_color, 2.5, true)
