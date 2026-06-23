extends Control
## 猫猫详情全屏弹窗：半透明遮罩 + 居中弹窗面板。
## 点击遮罩或关闭按钮 → queue_free()。
## （美术待补）

const POPUP_SIZE := Vector2(520, 680)
const CLOSE_BTN_LOCAL := Rect2(POPUP_SIZE.x - 150, POPUP_SIZE.y - 78, 120, 52)
const RELEASE_BTN_LOCAL := Rect2(30, POPUP_SIZE.y - 78, 180, 52)

var _cat_data = null
var _time: float = 0.0
var _popup_rect: Rect2

var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

	# 遮罩层：真实 ColorRect 节点全屏拦截点击
	var mask := ColorRect.new()
	mask.color = Color(0, 0, 0, 0.3)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(mask)
	mask.gui_input.connect(_on_mask_input)

	# 弹窗接收器（PanelContainer），居中，吃掉内部点击避免穿透到遮罩
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = POPUP_SIZE
	_panel.size = POPUP_SIZE
	add_child(_panel)
	_panel.gui_input.connect(_on_panel_input)


func setup(cat_data) -> void:
	_cat_data = cat_data
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	# 居中弹窗
	_popup_rect = Rect2((size - POPUP_SIZE) * 0.5, POPUP_SIZE)
	if _panel:
		_panel.position = _popup_rect.position
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var origin := _popup_rect.position

	# 背景 + 边框
	draw_rect(_popup_rect, Palette.BG_CEMENT, true)
	draw_rect(_popup_rect, Palette.BORDER_DEFAULT, false, 3.0)

	var species := _species()

	# 大猫头像
	var head_center := origin + Vector2(POPUP_SIZE.x * 0.5, 150)
	_draw_big_head(head_center)

	# 猫名
	var cat_name := _cat_name()
	draw_string(font, origin + Vector2(0, 300), cat_name,
		HORIZONTAL_ALIGNMENT_CENTER, POPUP_SIZE.x, 40, Palette.AMBER)

	# 品种标签
	draw_string(font, origin + Vector2(0, 350), "品种: " + breed_label(species),
		HORIZONTAL_ALIGNMENT_CENTER, POPUP_SIZE.x, 26, Palette.BORDER_DEFAULT)

	# 稀有度标签
	draw_string(font, origin + Vector2(0, 392), "稀有度: " + _rarity_label(species),
		HORIZONTAL_ALIGNMENT_CENTER, POPUP_SIZE.x, 26, _rarity_color(species))

	# 描述文字
	draw_string(font, origin + Vector2(40, 450), cat_description(species),
		HORIZONTAL_ALIGNMENT_LEFT, POPUP_SIZE.x - 80, 22, Palette.BORDER_DEFAULT)

	# 已邂逅次数
	draw_string(font, origin + Vector2(0, 540), "已邂逅: %d 次" % _encounter(),
		HORIZONTAL_ALIGNMENT_CENTER, POPUP_SIZE.x, 24, Palette.AMBER)

	# 美术待补标记
	draw_string(font, origin + Vector2(0, 575), "（美术待补）",
		HORIZONTAL_ALIGNMENT_CENTER, POPUP_SIZE.x, 18, Color(0.5, 0.5, 0.5))

	# 让它出来按钮
	var release_rect := Rect2(origin + RELEASE_BTN_LOCAL.position, RELEASE_BTN_LOCAL.size)
	draw_rect(release_rect, Palette.AMBER, true)
	draw_rect(release_rect, Palette.AMBER, false, 2.0)
	draw_string(font, Vector2(release_rect.position.x + 50, release_rect.position.y + 35),
		"让它出来", HORIZONTAL_ALIGNMENT_CENTER, release_rect.size.x - 100, 26, Palette.TEXT_ON_AMBER)

	# 关闭按钮
	var close_rect := Rect2(origin + CLOSE_BTN_LOCAL.position, CLOSE_BTN_LOCAL.size)
	draw_rect(close_rect, Palette.AMBER, true)
	draw_rect(close_rect, Palette.BORDER_DEFAULT, false, 2.0)
	draw_string(font, Vector2(close_rect.position.x, close_rect.position.y + 35),
		"关闭", HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x, 26, Palette.BG_CEMENT)

	# 让它出来按钮
	var release_rect := Rect2(origin + RELEASE_BTN_LOCAL.position, RELEASE_BTN_LOCAL.size)
	draw_rect(release_rect, Palette.AMBER, true)
	draw_rect(release_rect, Palette.BORDER_DEFAULT, false, 2.0)
	draw_string(font, Vector2(release_rect.position.x, release_rect.position.y + 35),
		"让它出来", HORIZONTAL_ALIGNMENT_CENTER, release_rect.size.x, 26, Palette.BG_CEMENT)


func _draw_big_head(center: Vector2) -> void:
	var body_col := Color(0.95, 0.7, 0.4)
	_draw_ellipse(center, Vector2(92, 76), body_col)
	_draw_ellipse(center + Vector2(0, 28), Vector2(60, 44), body_col)
	_draw_ellipse(center + Vector2(-68, -60), Vector2(28, 32), body_col)
	_draw_ellipse(center + Vector2(68, -60), Vector2(28, 32), body_col)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	var seg := 32
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


# ---------------------------------------------------------------------------
# 数据读取（兼容 Dictionary 与对象）
# ---------------------------------------------------------------------------
func _species() -> String:
	return _field("species", "")


func _cat_name() -> String:
	var n := _field("name", "")
	return n if n != "" else breed_label(_species())


func _encounter() -> int:
	var e = _field_raw("encounter", null)
	if e == null:
		return 1
	return int(e)


func _field(key: String, default: String) -> String:
	var v = _field_raw(key, null)
	return String(v) if v != null else default


func _field_raw(key: String, default):
	if _cat_data == null:
		return default
	if typeof(_cat_data) == TYPE_DICTIONARY:
		return _cat_data.get(key, default)
	if key in _cat_data:
		return _cat_data.get(key)
	return default


func _rarity_color(species: String) -> Color:
	match species:
		"british":
			return Palette.RARITY_RARE
		"siamese":
			return Palette.RARITY_EPIC
		_:
			return Palette.AMBER


func _rarity_label(species: String) -> String:
	match species:
		"british":
			return "稀有"
		"siamese":
			return "史诗"
		_:
			return "普通"


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


func cat_description(species_name: String) -> String:
	match species_name:
		"orange":
			return "圆滚滚的橘猫，热爱美食，体重与可爱成正比。"
		"british":
			return "沉稳的英短，圆脸蓝灰毛，是天生的绅士。"
		"siamese":
			return "高贵的暹罗猫，蓝眼睛会说话，黏人又机灵。"
		_:
			return "一只神秘的猫咪，等待你去了解它的故事。"


# ---------------------------------------------------------------------------
# 关闭交互
# ---------------------------------------------------------------------------
func _on_mask_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		queue_free()


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 点击落在弹窗内部，仅当命中关闭按钮才关闭，否则吃掉事件
		var local: Vector2 = event.position
		if CLOSE_BTN_LOCAL.has_point(local):
			accept_event()
			queue_free()
		elif RELEASE_BTN_LOCAL.has_point(local):
			accept_event()
			_release_to_garden()
		else:
			accept_event()


func _release_to_garden() -> void:
	var data = _cat_data
	queue_free()
	if data != null:
		UIManager.replace("res://scenes/S04_GardenMain.tscn", {"focus_cat": data})
