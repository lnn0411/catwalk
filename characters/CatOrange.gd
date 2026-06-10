extends Node2D

var body_color    = Palette.CAT_ORANGE_MID
var light_color   = Palette.CAT_ORANGE_LIGHT
var outline_color = Color("#A05A28")

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
	# 身体
	draw_ellipse(Vector2(0, 8), 50.0, 38.0, body_color)
	draw_arc(Vector2(0, 8), 50, 0, TAU, 32, outline_color, 1.5)

	# 胸腹浅色区
	draw_ellipse(Vector2(0, 14), 28.0, 22.0, light_color)

	# 头
	draw_circle(Vector2(0, -28), 22, body_color)
	draw_arc(Vector2(0, -28), 22, 0, TAU, 32, outline_color, 1.5)

	# 耳朵
	var ear_l = PackedVector2Array([Vector2(-18, -42), Vector2(-10, -28), Vector2(-26, -28)])
	var ear_r = PackedVector2Array([Vector2(18, -42), Vector2(10, -28), Vector2(26, -28)])
	draw_polygon(ear_l, [body_color])
	draw_polygon(ear_r, [body_color])

	# 眼睛 - 扁椭圆（半眯）
	draw_ellipse(Vector2(-9, -30), 6.0, 3.0, outline_color)
	draw_ellipse(Vector2(9, -30), 6.0, 3.0, outline_color)

	# 鼻子
	draw_polygon(PackedVector2Array([Vector2(0, -24), Vector2(-3, -21), Vector2(3, -21)]),
		[Color("#D4734A")])

	# 尾巴 - 搭在地上
	draw_polyline(PackedVector2Array([
		Vector2(30, 12), Vector2(46, 20), Vector2(54, 16), Vector2(48, 10)
	]), outline_color, 4.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(30, 12), Vector2(46, 20), Vector2(54, 16), Vector2(48, 10)
	]), body_color, 2.5, true)
