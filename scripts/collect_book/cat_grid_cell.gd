extends Control
## 图鉴单元格：三种渲染状态（已收集 / 已知未收集 / 完全未知）。
## 用 draw_circle 叠两个椭圆画猫头，稀有度边框，NEW 角标呼吸闪烁。
## （美术待补）

signal cell_pressed(species_name: String)

var _species: String = ""
var _is_collected: bool = false
var _is_known: bool = false
var _cat_data = null
var _rarity_color: Color = Color.WHITE

var _time: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(200, 170)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func setup(species_name: String, is_collected: bool, is_known: bool, cat_data, rarity_color: Color) -> void:
	_species = species_name
	_is_collected = is_collected
	_is_known = is_known
	_cat_data = cat_data
	_rarity_color = rarity_color
	queue_redraw()


func _process(delta: float) -> void:
	# 仅在已收集状态下需要呼吸动画
	if _is_collected:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var rect := Rect2(Vector2.ZERO, custom_minimum_size)

	if not _is_known:
		# 完全未知：全黑矩形 + ?
		draw_rect(rect, Color.BLACK, true)
		draw_string(font, Vector2(0, rect.size.y * 0.5 + 20),
			"?", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 56, Palette.BORDER_DEFAULT)
		return

	# 背景
	draw_rect(rect, Palette.BG_CEMENT, true)

	# 猫头（两个椭圆叠成猫形）
	var head_modulate := Color.WHITE if _is_collected else Color(0.5, 0.5, 0.5)
	_draw_cat_head(rect, head_modulate)

	# 稀有度边框
	draw_rect(rect.grow(2), _rarity_color, false, 2.0)

	# 品种名
	draw_string(font, Vector2(0, rect.size.y - 18),
		breed_label(_species), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24,
		Palette.AMBER if _is_collected else Color(0.6, 0.6, 0.6))

	# NEW 角标（已收集，金色呼吸闪烁）
	if _is_collected:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		var gold := Color(1.0, 0.84, 0.0, 0.4 + 0.6 * pulse)
		var badge := Rect2(8, 8, 54, 26)
		draw_rect(badge, gold, true)
		draw_string(font, Vector2(badge.position.x, badge.position.y + 20),
			"NEW", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 18, Color.BLACK)


func _draw_cat_head(rect: Rect2, mod: Color) -> void:
	var center := Vector2(rect.size.x * 0.5, rect.size.y * 0.42)
	var body_col := Color(0.95, 0.7, 0.4) * mod
	# 用 scale 模拟椭圆：先画脸（横向椭圆）
	_draw_ellipse(center, Vector2(46, 38), body_col)
	# 再叠一个略小的椭圆作为吻部/下巴
	_draw_ellipse(center + Vector2(0, 14), Vector2(30, 22), body_col)
	# 两只耳朵（小圆）
	_draw_ellipse(center + Vector2(-34, -30), Vector2(14, 16), body_col)
	_draw_ellipse(center + Vector2(34, -30), Vector2(14, 16), body_col)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	# draw_circle 无法直接画椭圆，用顶点构造多边形
	var pts := PackedVector2Array()
	var seg := 24
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func breed_label(species_name: String) -> String:
	match species_name:
		"orange":
			return "橘猫"
		"british":
			return "英短"
		"siamese":
			return "暹罗"
		_:
			return species_name


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		cell_pressed.emit(_species)
