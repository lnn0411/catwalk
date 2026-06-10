extends Node2D

func _draw():
	# === Layer 1: 天空（画面上25%） ===
	draw_rect(Rect2(0, 0, 2048, 384), Palette.BG_WARM_WHITE)

	# === Layer 2: 远景建筑轮廓 ===
	var building_color = Color("#C8BFB0")
	var buildings = [
		[200, 264, 120, 80],
		[480, 304, 80, 120],
		[800, 224, 160, 100],
		[1200, 284, 100, 180],
		[1600, 244, 140, 90],
	]
	for b in buildings:
		var x = b[0]
		var y_top = b[1]
		var height = b[2]
		var width = b[3]
		draw_rect(Rect2(x, y_top, width, height), building_color)
		# 建筑顶部高光线
		draw_line(Vector2(x, y_top), Vector2(x + width, y_top), Color("#D8CFC4"), 1.0)

	# === Layer 3: 地面（画面下75%） ===
	draw_rect(Rect2(0, 384, 2048, 1152), Palette.BG_CEMENT)

	# 水泥裂缝（左下角，固定seed）
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var crack_color = Color("#C8BFB0")
	for i in range(6):
		var start = Vector2(rng.randf_range(0, 300), rng.randf_range(900, 1536))
		var end = start + Vector2(rng.randf_range(20, 80), rng.randf_range(-20, 20))
		draw_line(start, end, crack_color, 1.0)

	# 右下角裂缝群
	for i in range(6):
		var start = Vector2(rng.randf_range(1700, 2048), rng.randf_range(900, 1536))
		var end = start + Vector2(rng.randf_range(-20, -80), rng.randf_range(-20, 20))
		draw_line(start, end, crack_color, 1.0)

	# 野草（小椭圆簇，分布在边缘，中心留空）
	var grass_color = Palette.MOSS_GREEN
	var grass_positions = [
		Vector2(80, 1200), Vector2(120, 1350), Vector2(160, 1180),
		Vector2(1900, 1100), Vector2(1960, 1300),
		Vector2(300, 500), Vector2(1700, 550),
		Vector2(60, 800), Vector2(1970, 750),
	]
	for pos in grass_positions:
		draw_ellipse(pos, 8.0, 4.0, grass_color)
		draw_ellipse(pos + Vector2(6, -3), 6.0, 3.0, grass_color)
		draw_ellipse(pos + Vector2(-5, -2), 5.0, 3.0, grass_color)

	# 瓷碗（右下区域，固定坐标 1680, 1320）
	var bowl_color = Color("#D4C8BC")
	draw_arc(Vector2(1680, 1320), 24, PI, TAU, 16, bowl_color, 3.0)
	draw_line(Vector2(1656, 1320), Vector2(1704, 1320), bowl_color, 3.0)
