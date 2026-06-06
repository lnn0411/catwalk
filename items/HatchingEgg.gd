extends Node2D

@export var progress: float = 0.0

func _ready():
	set_process(true)

func _process(_delta):
	queue_redraw()

func _draw():
	var center = Vector2(128, 128)

	# 蛋体形状
	var egg_points = _get_egg_shape(center, 56, 72)
	draw_colored_polygon(egg_points, Palette.BG_WARM_WHITE)
	draw_polyline(egg_points + PackedVector2Array([egg_points[0]]), Color("#C8BFB0"), 1.5, true)

	# 内部暖光（progress > 0.5 开始出现，渐强）
	if progress > 0.5:
		var glow_alpha = (progress - 0.5) * 2.0
		var glow_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, glow_alpha * 0.35)
		draw_colored_polygon(egg_points, glow_color)

	# 裂缝（progress >= 0.25 开始出现，随进度增多）
	if progress >= 0.25:
		_draw_cracks(center, progress)

func _get_egg_shape(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(24):
		var angle = i * TAU / 24.0
		var r_y = ry if sin(angle) > 0 else ry * 0.82
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * r_y))
	return points

func _draw_cracks(center: Vector2, p: float):
	var crack_color = Color("#B0A898")

	# 第一道裂缝（progress >= 0.25）
	draw_line(center + Vector2(-8, -20), center + Vector2(4, -8), crack_color, 1.0)

	# 第二道（progress >= 0.5）
	if p >= 0.5:
		draw_line(center + Vector2(10, -14), center + Vector2(20, 2), crack_color, 1.0)
		draw_line(center + Vector2(10, -14), center + Vector2(6, -28), crack_color, 1.0)

	# 第三道（progress >= 0.75，蛋壳剥落感）
	if p >= 0.75:
		draw_line(center + Vector2(-16, 0), center + Vector2(-4, 14), crack_color, 1.5)
		draw_line(center + Vector2(-4, 14), center + Vector2(8, 10), crack_color, 1.5)
