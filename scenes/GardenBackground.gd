extends Node2D

const LAYER_FAR := 0
const LAYER_MID := 1
const LAYER_NEAR := 2

var layer_type := LAYER_FAR

func _draw():
	match layer_type:
		LAYER_FAR:
			_draw_sky_and_clouds()
		LAYER_MID:
			_draw_buildings()
		LAYER_NEAR:
			_draw_ground_and_plants()

func _draw_sky_and_clouds() -> void:
	for i in range(24):
		var t := float(i) / 23.0
		var color := Color("#FFE9C9").lerp(Color("#F7CFA8"), t)
		draw_rect(Rect2(0, i * 64, 2048, 68), color)

	draw_circle(Vector2(1710, 190), 92, Color("#FFD27A55"))
	draw_circle(Vector2(1710, 190), 58, Color("#FFE0A1AA"))

	_draw_cloud(Vector2(250, 170), 1.0, Color("#FFF8EDCC"))
	_draw_cloud(Vector2(760, 105), 0.75, Color("#FFF6E6B8"))
	_draw_cloud(Vector2(1320, 230), 1.2, Color("#FFF4E0AA"))

func _draw_buildings() -> void:
	_draw_tree(Vector2(130, 510), 0.75, true)
	_draw_tree(Vector2(1830, 520), 0.9, true)
	_draw_house(Vector2(250, 345), Vector2(270, 250), Color("#F5DDBF"), Color("#C96F4A"), Color("#7E9F80"))
	_draw_house(Vector2(665, 300), Vector2(330, 295), Color("#F9E9CB"), Color("#B95F43"), Color("#9CB7C9"))
	_draw_house(Vector2(1125, 365), Vector2(250, 230), Color("#EFD0A5"), Color("#D08655"), Color("#D2A66F"))
	_draw_house(Vector2(1515, 325), Vector2(300, 275), Color("#F8E6D0"), Color("#A85B46"), Color("#84A27A"))
	_draw_mid_bush(Vector2(100, 635), 1.2)
	_draw_mid_bush(Vector2(520, 640), 1.0)
	_draw_mid_bush(Vector2(1000, 645), 1.3)
	_draw_mid_bush(Vector2(1420, 635), 1.15)
	_draw_mid_bush(Vector2(1900, 650), 1.1)

func _draw_ground_and_plants() -> void:
	for i in range(18):
		var t := float(i) / 17.0
		var color := Color("#B9D38B").lerp(Color("#7FA35E"), t)
		draw_rect(Rect2(0, 384 + i * 64, 2048, 70), color)

	draw_rect(Rect2(0, 980, 2048, 556), Color("#8EB768"))
	_draw_path()
	_draw_grass_texture()
	_draw_tree(Vector2(185, 890), 1.15, false)
	_draw_tree(Vector2(1835, 860), 1.05, false)
	_draw_flower_bed(Vector2(145, 1235), 1.15)
	_draw_flower_bed(Vector2(1820, 1210), 1.0)
	_draw_flower_bed(Vector2(425, 670), 0.75)
	_draw_flower_bed(Vector2(1535, 690), 0.8)
	_draw_bush_cluster(Vector2(760, 1195), 1.0)
	_draw_bush_cluster(Vector2(1280, 1165), 1.1)
	_draw_leaf_scatter()
	_draw_bowl(Vector2(1680, 1320))

func _draw_cloud(pos: Vector2, scale_factor: float, color: Color) -> void:
	draw_ellipse(pos + Vector2(-75, 12) * scale_factor, 72.0 * scale_factor, 30.0 * scale_factor, color)
	draw_ellipse(pos + Vector2(-20, -4) * scale_factor, 88.0 * scale_factor, 42.0 * scale_factor, color)
	draw_ellipse(pos + Vector2(55, 12) * scale_factor, 76.0 * scale_factor, 32.0 * scale_factor, color)
	draw_ellipse(pos + Vector2(15, 22) * scale_factor, 150.0 * scale_factor, 24.0 * scale_factor, Color(color.r, color.g, color.b, color.a * 0.75))

func _draw_house(pos: Vector2, size: Vector2, wall_color: Color, roof_color: Color, accent_color: Color) -> void:
	var body := Rect2(pos, size)
	var roof := PackedVector2Array([
		pos + Vector2(-26, 20),
		pos + Vector2(size.x * 0.5, -78),
		pos + Vector2(size.x + 26, 20)
	])
	draw_colored_polygon(roof, roof_color)
	draw_line(roof[0], roof[1], Color("#8E4937"), 4.0)
	draw_line(roof[1], roof[2], Color("#8E4937"), 4.0)
	draw_rect(body, wall_color)
	draw_rect(Rect2(pos + Vector2(0, size.y - 28), Vector2(size.x, 28)), wall_color.darkened(0.08))
	draw_line(pos + Vector2(0, 0), pos + Vector2(size.x, 0), Color("#FFF3D7"), 3.0)

	var door_rect := Rect2(pos + Vector2(size.x * 0.42, size.y - 94), Vector2(size.x * 0.16, 94))
	draw_rect(door_rect, Color("#A96A43"))
	draw_arc(door_rect.position + Vector2(door_rect.size.x * 0.5, 0), door_rect.size.x * 0.5, PI, TAU, 18, Color("#A96A43"), 5.0)
	draw_circle(door_rect.position + Vector2(door_rect.size.x - 16, 50), 4, Color("#F6C56E"))

	for x in [0.18, 0.68]:
		_draw_window(pos + Vector2(size.x * x, size.y * 0.3), accent_color)
		_draw_window(pos + Vector2(size.x * x, size.y * 0.58), accent_color.lightened(0.08))

	draw_circle(pos + Vector2(size.x * 0.5, size.y * 0.2), 16, Color("#FFF6CF"))
	draw_arc(pos + Vector2(size.x * 0.5, size.y * 0.2), 16, 0, TAU, 24, Color("#CDAF83"), 2.0)

func _draw_window(pos: Vector2, shutter_color: Color) -> void:
	draw_rect(Rect2(pos + Vector2(-34, -28), Vector2(68, 56)), Color("#FFE8A8"))
	draw_rect(Rect2(pos + Vector2(-42, -28), Vector2(8, 56)), shutter_color)
	draw_rect(Rect2(pos + Vector2(34, -28), Vector2(8, 56)), shutter_color)
	draw_line(pos + Vector2(0, -28), pos + Vector2(0, 28), Color("#CFAF7A"), 2.0)
	draw_line(pos + Vector2(-34, 0), pos + Vector2(34, 0), Color("#CFAF7A"), 2.0)

func _draw_path() -> void:
	var path := PackedVector2Array([
		Vector2(855, 1536), Vector2(1190, 1536), Vector2(1105, 1170),
		Vector2(1015, 830), Vector2(980, 580), Vector2(930, 580),
		Vector2(910, 830), Vector2(840, 1170)
	])
	draw_colored_polygon(path, Color("#D9B879"))
	draw_line(Vector2(855, 1536), Vector2(910, 830), Color("#B98D55"), 4.0)
	draw_line(Vector2(1190, 1536), Vector2(1015, 830), Color("#B98D55"), 4.0)
	for y in [690, 815, 950, 1095, 1250, 1415]:
		var half_width: float = (float(y) - 530.0) * 0.19 + 42.0
		draw_line(Vector2(1024 - half_width, y), Vector2(1024 + half_width, y + 8), Color("#C99D5F88"), 2.0)

func _draw_tree(base: Vector2, scale_factor: float, muted: bool) -> void:
	var trunk_color := Color("#9A6741") if not muted else Color("#B78357")
	var leaf_color := Color("#6F9D55") if not muted else Color("#86AA68")
	draw_rect(Rect2(base + Vector2(-18, -150) * scale_factor, Vector2(36, 150) * scale_factor), trunk_color)
	draw_ellipse(base + Vector2(-42, -162) * scale_factor, 54.0 * scale_factor, 80.0 * scale_factor, leaf_color)
	draw_ellipse(base + Vector2(38, -170) * scale_factor, 62.0 * scale_factor, 78.0 * scale_factor, leaf_color.lightened(0.05))
	draw_circle(base + Vector2(0, -235) * scale_factor, 78.0 * scale_factor, leaf_color.lightened(0.1))
	draw_circle(base + Vector2(-62, -218) * scale_factor, 60.0 * scale_factor, leaf_color.darkened(0.04))
	draw_circle(base + Vector2(66, -218) * scale_factor, 58.0 * scale_factor, leaf_color)
	draw_circle(base + Vector2(10, -282) * scale_factor, 48.0 * scale_factor, leaf_color.lightened(0.12))

func _draw_mid_bush(pos: Vector2, scale_factor: float) -> void:
	var color := Color("#7FA765")
	for offset in [Vector2(-60, 8), Vector2(-24, -12), Vector2(22, -18), Vector2(66, 6)]:
		draw_circle(pos + offset * scale_factor, 42.0 * scale_factor, color.lightened(offset.y * -0.002))
	draw_rect(Rect2(pos + Vector2(-105, 8) * scale_factor, Vector2(210, 38) * scale_factor), color)

func _draw_bush_cluster(pos: Vector2, scale_factor: float) -> void:
	for offset in [Vector2(-86, 22), Vector2(-42, -12), Vector2(8, -28), Vector2(58, -8), Vector2(98, 22)]:
		draw_circle(pos + offset * scale_factor, 48.0 * scale_factor, Color("#5F8F4F").lightened((offset.x + 90.0) / 900.0))

func _draw_flower_bed(pos: Vector2, scale_factor: float) -> void:
	_draw_bush_cluster(pos, scale_factor * 0.72)
	var colors := [Color("#E86F65"), Color("#F5C45D"), Color("#F18AB5"), Color("#FFF1A8"), Color("#D96F4F")]
	for i in range(18):
		var x := float((i % 6) - 2) * 32.0
		var y := float(i / 6) * 34.0 - 42.0
		_draw_flower(pos + Vector2(x, y) * scale_factor, scale_factor, colors[i % colors.size()])

func _draw_flower(pos: Vector2, scale_factor: float, color: Color) -> void:
	draw_line(pos + Vector2(0, 18) * scale_factor, pos + Vector2(0, -8) * scale_factor, Color("#47763E"), 2.0 * scale_factor)
	for offset in [Vector2(-8, 0), Vector2(8, 0), Vector2(0, -8), Vector2(0, 8)]:
		draw_circle(pos + offset * scale_factor, 6.0 * scale_factor, color)
	draw_circle(pos, 4.0 * scale_factor, Color("#D79A36"))

func _draw_grass_texture() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in range(90):
		var pos := Vector2(rng.randf_range(0, 2048), rng.randf_range(420, 1536))
		var h := rng.randf_range(10, 28)
		var color := Color("#668F4B73")
		draw_line(pos, pos + Vector2(rng.randf_range(-5, 5), -h), color, 2.0)
	for i in range(40):
		var pos := Vector2(rng.randf_range(0, 2048), rng.randf_range(760, 1510))
		draw_ellipse(pos, rng.randf_range(8, 18), rng.randf_range(3, 7), Color("#A6C47A77"))

func _draw_leaf_scatter() -> void:
	var leaves := [
		Vector2(330, 1030), Vector2(520, 1370), Vector2(715, 865), Vector2(1350, 1015),
		Vector2(1510, 1320), Vector2(1885, 980), Vector2(1120, 1420), Vector2(250, 720)
	]
	for pos in leaves:
		draw_ellipse(pos, 16.0, 7.0, Color("#D6A44F88"))
		draw_line(pos + Vector2(-10, 0), pos + Vector2(10, 0), Color("#A8783D77"), 1.0)

func _draw_bowl(pos: Vector2) -> void:
	var bowl_color := Color("#F4D1A7")
	draw_arc(pos, 30, PI, TAU, 24, bowl_color, 6.0)
	draw_line(pos + Vector2(-30, 0), pos + Vector2(30, 0), bowl_color, 5.0)
	draw_arc(pos + Vector2(0, 2), 22, 0, PI, 24, Color("#C98B5E"), 3.0)
