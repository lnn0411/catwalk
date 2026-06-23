extends Control
## 图鉴单元格：每个已收集猫咪一个单元格。
## 用 draw_circle 叠两个椭圆画猫头，稀有度边框，NEW 角标呼吸闪烁。
## （美术待补）

signal cell_pressed(cat_data)

var _cat_data: Variant = null
var _rarity_color: Color = Color.WHITE
var _is_placeholder: bool = false
var _species: String = ""

var _time: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(200, 170)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func setup(cat_data: Variant) -> void:
	_is_placeholder = false
	_cat_data = cat_data
	_species = _field("species", "")
	_rarity_color = _get_rarity_color()
	queue_redraw()


func set_placeholder(species: String) -> void:
	_is_placeholder = true
	_species = species
	_cat_data = null
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var rect: Rect2 = Rect2(Vector2.ZERO, custom_minimum_size)

	if _is_placeholder:
		_draw_placeholder(font, rect)
		return

	# 背景
	draw_rect(rect, Palette.BG_CEMENT, true)

	# 猫头（两个椭圆叠成猫形）
	var head_modulate: Color = Color.WHITE
	_draw_cat_head(rect, head_modulate)

	# 稀有度边框
	draw_rect(rect.grow(2), _rarity_color, false, 2.0)

	# 猫名
	draw_string(font, Vector2(0, rect.size.y - 18),
		_display_name(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24,
		Palette.AMBER)

	# NEW 角标（金色呼吸闪烁）
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	var gold: Color = Color(1.0, 0.84, 0.0, 0.4 + 0.6 * pulse)
	var badge: Rect2 = Rect2(8, 8, 54, 26)
	draw_rect(badge, gold, true)
	draw_string(font, Vector2(badge.position.x, badge.position.y + 20),
		"NEW", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 18, Color.BLACK)


func _draw_placeholder(font: Font, rect: Rect2) -> void:
	var bg: Color = Color(0.16, 0.17, 0.16)
	var head_modulate: Color = Color(0.35, 0.39, 0.36)
	var label_color: Color = Color(0.50, 0.62, 0.52)
	var bottom_color: Color = Color(0.45, 0.48, 0.45)

	draw_rect(rect, bg, true)
	_draw_cat_head(rect, head_modulate)
	draw_rect(rect.grow(2), Color(0.30, 0.34, 0.31), false, 2.0)
	draw_string(font, Vector2(0, rect.size.y - 48),
		_species_label(_species), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 22,
		label_color)
	draw_string(font, Vector2(0, rect.size.y - 18),
		"未发现", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 20,
		bottom_color)


func _draw_cat_head(rect: Rect2, mod: Color) -> void:
	var center: Vector2 = Vector2(rect.size.x * 0.5, rect.size.y * 0.42)
	var body_col: Color = Color(0.95, 0.7, 0.4) * mod
	# 用 scale 模拟椭圆：先画脸（横向椭圆）
	_draw_ellipse(center, Vector2(46, 38), body_col)
	# 再叠一个略小的椭圆作为吻部/下巴
	_draw_ellipse(center + Vector2(0, 14), Vector2(30, 22), body_col)
	# 两只耳朵（小圆）
	_draw_ellipse(center + Vector2(-34, -30), Vector2(14, 16), body_col)
	_draw_ellipse(center + Vector2(34, -30), Vector2(14, 16), body_col)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	# draw_circle 无法直接画椭圆，用顶点构造多边形
	var pts: PackedVector2Array = PackedVector2Array()
	var seg: int = 24
	for i in range(seg):
		var a: float = TAU * float(i) / float(seg)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _display_name() -> String:
	var display_name: String = _field("display_name", "")
	if display_name != "":
		return display_name

	var name: String = _field("name", "")
	if name != "":
		return name

	var species: String = _field("species", "")
	if species != "":
		return species

	return "猫咪"


func _get_rarity_color() -> Color:
	var rarity: String = _field("rarity", "")
	match rarity:
		"rare":
			return Palette.RARITY_RARE
		"epic":
			return Palette.RARITY_EPIC
		"legendary":
			return Palette.RARITY_LEG_A
		_:
			var species: String = _field("species", "")
			match species:
				"british":
					return Palette.RARITY_RARE
				"siamese":
					return Palette.RARITY_EPIC
				_:
					return Palette.AMBER


func _species_label(species: String) -> String:
	match species:
		"orange":
			return "橘猫"
		"british":
			return "英短"
		"siamese":
			return "暹罗"
		_:
			return species


func _field(key: String, default: String) -> String:
	var value: Variant = _field_raw(key, null)
	return String(value) if value != null else default


func _field_raw(key: String, default: Variant) -> Variant:
	if _cat_data == null:
		return default
	if typeof(_cat_data) == TYPE_DICTIONARY:
		return _cat_data.get(key, default)
	if key in _cat_data:
		return _cat_data.get(key)
	return default


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _is_placeholder:
			return
		cell_pressed.emit(_cat_data)
