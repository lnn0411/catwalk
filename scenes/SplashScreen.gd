extends Node2D

func _draw():
	var screen = get_viewport_rect().size

	# 背景
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_CEMENT)

	# 猫爪印 logo（一个大爪垫 + 四个小趾垫，居中偏上）
	var center = screen / 2.0

	# 主掌垫（椭圆，宽48，高38）
	draw_ellipse(Rect2(center + Vector2(0, 24) - Vector2(24, 19), Vector2(48.0, 38.0)), Palette.AMBER)

	# 四个趾垫（小圆，半径12，排成弧形）
	var toe_offsets = [
		Vector2(-36, -14),
		Vector2(-14, -34),
		Vector2(14, -34),
		Vector2(36, -14),
	]
	for offset in toe_offsets:
		draw_circle(center + offset, 12, Palette.AMBER)

	# 底部文字占位「猫步天下」
	var font_size = 28
	# 用简单线条代替文字（等正式字体资源到位后替换）
	var text_y = center.y + 90
	var text_center = center.x
	var line_width = 120.0
	draw_line(Vector2(text_center - line_width / 2, text_y), Vector2(text_center + line_width / 2, text_y), Palette.TEXT_PRIMARY, 2.0)
