extends Node2D

var body_color    = Palette.CAT_SIAM_BODY
var light_color   = Palette.CAT_SIAM_HIGH
var outline_color = Palette.CAT_SIAM_POINT

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
	# 身体 - 修长 42x34
	draw_ellipse(Vector2(0, 8), 42.0, 34.0, body_color)
	draw_arc(Vector2(0, 8), 42, 0, TAU, 32, outline_color, 1.5)

	# 胸腹浅色区
	draw_ellipse(Vector2(0, 14), 22.0, 20.0, light_color)

	# 头
	draw_circle(Vector2(0, -28), 20, body_color)
	draw_arc(Vector2(0, -28), 20, 0, TAU, 32, outline_color, 1.5)

	# 脸部重点色遮罩（椭圆，宽14高10，居中在脸上）
	draw_ellipse(Vector2(0, -28), 14.0, 10.0, outline_color)

	# 耳朵
	var ear_l = PackedVector2Array([Vector2(-15, -40), Vector2(-8, -30), Vector2(-22, -30)])
	var ear_r = PackedVector2Array([Vector2(15, -40), Vector2(8, -30), Vector2(22, -30)])
	draw_polygon(ear_l, [body_color])
	draw_polygon(ear_r, [body_color])
	# 耳内侧深色
	var ear_inner_l = PackedVector2Array([Vector2(-15, -38), Vector2(-10, -32), Vector2(-20, -32)])
	var ear_inner_r = PackedVector2Array([Vector2(15, -38), Vector2(10, -32), Vector2(20, -32)])
	draw_polygon(ear_inner_l, [outline_color])
	draw_polygon(ear_inner_r, [outline_color])

	# 眼睛 - 杏仁形 高=宽x0.6
	draw_ellipse(Vector2(-9, -30), 5.0, 4.0, outline_color)
	draw_ellipse(Vector2(9, -30), 5.0, 4.0, outline_color)
	# 瞳孔 - 细长暗椭圆
	draw_ellipse(Vector2(-9, -30), 2.0, 3.0, Color.BLACK)
	draw_ellipse(Vector2(9, -30), 2.0, 3.0, Color.BLACK)

	# 鼻子
	draw_polygon(PackedVector2Array([Vector2(0, -22), Vector2(-3, -19), Vector2(3, -19)]),
		[Color("#D4734A")])

	# 前爪 - CAT_SIAM_POINT
	draw_ellipse(Vector2(-20, 22), 8.0, 6.0, outline_color)
	draw_ellipse(Vector2(20, 22), 8.0, 6.0, outline_color)

	# 尾巴 - 高翘上扬
	draw_polyline(PackedVector2Array([
		Vector2(28, 8), Vector2(44, -8), Vector2(52, -18), Vector2(46, -24)
	]), outline_color, 4.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(28, 8), Vector2(44, -8), Vector2(52, -18), Vector2(46, -24)
	]), body_color, 2.5, true)
