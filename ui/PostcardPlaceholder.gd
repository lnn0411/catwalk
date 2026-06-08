extends Node2D

const POSTCARD_COLORS = {
	"convenience_store": Color("#E8E4DC"),
	"park":              Color("#DDE8D8"),
	"subway":            Color("#DCE0E8"),
	"bookstore":         Color("#E8E0D4"),
	"cafe":              Color("#EDE4D8"),
	"hospital":          Color("#E4E8E8"),
	"overpass":          Color("#E0E4EC"),
	"night_market":      Color("#F0E8D8"),
	"playground":        Color("#E8ECE0"),
	"rainy":             Color("#DDE4EC"),
}

@export var location_type: String = "park"
@export var cat_breed: String = "orange"

func _draw():
	var bg = POSTCARD_COLORS.get(location_type, Palette.BG_CEMENT)

	# 背景
	draw_rect(Rect2(0, 0, 750, 500), bg)

	# 右侧白卡区（文案区）
	draw_rect(Rect2(500, 0, 250, 500), Palette.BG_WARM_WHITE)
	draw_line(Vector2(500, 0), Vector2(500, 500), Palette.BORDER_DEFAULT, 1.0)

	# 邮票占位（右上角，60×80px）
	draw_rect(Rect2(624, 16, 60, 80), Palette.BG_CEMENT)
	draw_rect(Rect2(624, 16, 60, 80), Palette.BORDER_DEFAULT, false, 1.0)

	# 文案占位线（灰色横线，4条）
	for i in range(4):
		var y = 200 + i * 28
		draw_line(Vector2(520, y), Vector2(720, y), Palette.BORDER_DEFAULT, 1.0)

	# 猫咪占位图标（右下，缩小版猫咪，坐标约 650, 420）
	_draw_mini_cat(Vector2(620, 400))

func _draw_mini_cat(pos: Vector2):
	var cat_color = Palette.CAT_ORANGE_MID
	var outline_color = Color("#A05A28")

	# 身体（小椭圆）
	draw_ellipse(Rect2(pos + Vector2(0, 14) - Vector2(10, 8), Vector2(20.0, 16.0)), cat_color)
	# 头（小圆）
	draw_circle(pos + Vector2(0, -8), 10, cat_color)
	# 耳朵
	var ear_l = PackedVector2Array([pos + Vector2(-8, -16), pos + Vector2(-4, -10), pos + Vector2(-12, -10)])
	var ear_r = PackedVector2Array([pos + Vector2(8, -16), pos + Vector2(4, -10), pos + Vector2(12, -10)])
	draw_polygon(ear_l, [cat_color])
	draw_polygon(ear_r, [cat_color])
	# 眼睛
	draw_ellipse(Rect2(pos + Vector2(-4, -10) - Vector2(1.5, 1), Vector2(3.0, 2.0)), outline_color)
	draw_ellipse(Rect2(pos + Vector2(4, -10) - Vector2(1.5, 1), Vector2(3.0, 2.0)), outline_color)
	# 尾巴（后摆）
	draw_polyline(PackedVector2Array([
		pos + Vector2(16, 12), pos + Vector2(28, 22), pos + Vector2(36, 18)
	]), outline_color, 2.0, true)
