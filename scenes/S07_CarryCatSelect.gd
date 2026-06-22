extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")
const CAT_ICON_SIZE := 64.0
const DRAWER_HEIGHT := 400.0

var _drawer: Control
var _scrim: ColorRect
var _list_container: VBoxContainer
var _cat_items: Array = []

func _ready() -> void:
	super._ready()
	_build_ui()
	_refresh_list()

func _build_ui() -> void:
	# 暗化遮罩
	_scrim = ColorRect.new()
	_scrim.color = Color(0, 0, 0, 0.5)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	# 抽屉面板 — 锚定底部
	_drawer = Control.new()
	_drawer.anchor_left = 0.0
	_drawer.anchor_right = 1.0
	_drawer.anchor_top = 1.0
	_drawer.anchor_bottom = 1.0
	_drawer.offset_top = -DRAWER_HEIGHT
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_drawer)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.12, 0.10, 0.95)
	bg.set_corner_radius_all(16)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer.add_child(panel)

	# 标题栏
	var title_bar := HBoxContainer.new()
	title_bar.anchor_left = 0.0
	title_bar.anchor_right = 1.0
	title_bar.offset_bottom = 50.0
	title_bar.add_theme_constant_override("separation", 0)
	_drawer.add_child(title_bar)

	var title := Label.new()
	title.text = "\u{1F4CB} \u9009\u62E9\u968F\u884C\u732B\u5496"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "\u2715"
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.custom_minimum_size = Vector2(50, 50)
	close_btn.pressed.connect(_close)
	title_bar.add_child(close_btn)

	# 猫列表
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_top = 50.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drawer.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_list_container)

	# 空状态
	var empty := Label.new()
	empty.name = "EmptyLabel"
	empty.text = "\u8FD8\u6CA1\u6709\u732B\u5496\uFF0C\u5148\u53BB\u5B75\u5316\u4E00\u53EA\u5427~"
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	empty.add_theme_font_size_override("font_size", 16)
	empty.visible = false
	_list_container.add_child(empty)

	# 入场动画：抽屉从底部滑入
	var final_top := -DRAWER_HEIGHT
	_drawer.offset_top = 0.0
	var t := create_tween()
	t.tween_property(_drawer, "offset_top", final_top, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _refresh_list() -> void:
	for item in _cat_items:
		item.queue_free()
	_cat_items.clear()

	var cats: Array = HatchEngine.get_cats() if HatchEngine else []
	var companion_id: String = HatchEngine.current_companion_cat_id if HatchEngine else ""
	var empty_label := _list_container.get_node_or_null("EmptyLabel")

	if cats.is_empty():
		if empty_label: empty_label.visible = true
		return
	if empty_label: empty_label.visible = false

	for cat_data in cats:
		var row := _build_cat_row(cat_data, companion_id)
		_list_container.add_child(row)
		_cat_items.append(row)

func _build_cat_row(cat_data, companion_id: String) -> Control:
	var cat_id := String(cat_data.id)
	var is_companion := cat_id == companion_id

	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.20, 0.17, 0.8)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	row.add_theme_stylebox_override("normal", sb)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 12)
	row.add_child(hb)

	# 猫图标（品种色圆形）
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(CAT_ICON_SIZE, CAT_ICON_SIZE)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = _breed_color(String(cat_data.species))
	icon_sb.set_corner_radius_all(32)
	icon.add_theme_stylebox_override("panel", icon_sb)
	hb.add_child(icon)

	# 名字 + 品种
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hb.add_child(info)

	var name_label := Label.new()
	name_label.text = cat_data.display_name
	name_label.add_theme_color_override("font_color", Color.WHITE if not is_companion else Color.AMBER)
	name_label.add_theme_font_size_override("font_size", 18)
	info.add_child(name_label)

	var breed_label := Label.new()
	breed_label.text = _breed_text(String(cat_data.species))
	breed_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	breed_label.add_theme_font_size_override("font_size", 13)
	info.add_child(breed_label)

	# 随行标记
	if is_companion:
		var check := Label.new()
		check.text = "\u2705 \u968F\u884C\u4E2D"
		check.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		check.add_theme_font_size_override("font_size", 14)
		hb.add_child(check)

	row.pressed.connect(func():
		_on_cat_selected(cat_id, is_companion)
	)

	return row

func _on_cat_selected(cat_id: String, is_current: bool) -> void:
	if is_current:
		_close()
		return
	if HatchEngine:
		HatchEngine.current_companion_cat_id = cat_id
	if SaveManager:
		SaveManager.save_all()
	_close()

func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()

func _close() -> void:
	var t := create_tween()
	t.tween_property(_drawer, "offset_top", 0.0, 0.25)
	await t.finished
	UIManager.go_back()

func handle_back() -> bool:
	_close()
	return true

func _breed_color(species: String) -> Color:
	match species:
		CatData.BREED_ORANGE: return Color(1.0, 0.6, 0.2)
		CatData.BREED_BRITISH: return Color(0.5, 0.5, 0.6)
		CatData.BREED_SIAMESE: return Color(0.8, 0.7, 0.5)
		_: return Color(0.6, 0.6, 0.6)

func _breed_text(species: String) -> String:
	match species:
		CatData.BREED_ORANGE: return "\u6A58\u732B"
		CatData.BREED_BRITISH: return "\u82F1\u77ED"
		CatData.BREED_SIAMESE: return "\u66B9\u7F57"
		_: return species
