extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

var _scrim: ColorRect
var _list_container: VBoxContainer
var _cat_items: Array = []

func _ready() -> void:
	super._ready()
	_build_ui()
	_refresh_list()


func _build_ui() -> void:
	# 暗化遮罩（点击关闭）
	_scrim = ColorRect.new()
	_scrim.color = Color(0, 0, 0, 0.5)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	# 弹窗底板（居中 560x500）
	var panel := TextureRect.new()
	panel.texture = load("res://assets/art/ui/companion/panel_companion.png")
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	_center_control(panel, Vector2(560, 500))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	# 顶部文案
	var head := VBoxContainer.new()
	head.position = Vector2(40, 20)
	head.size = Vector2(480, 64)
	head.add_theme_constant_override("separation", 4)
	panel.add_child(head)

	var title := Label.new()
	title.text = "谁来陪你散步？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#4F453C"))
	title.add_theme_font_size_override("font_size", 20)
	head.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "随行的那只，享受你今天走过的所有步数"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#8B7355"))
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(subtitle)

	# 猫列表（滚动容器）
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 90)
	scroll.size = Vector2(480, 380)
	panel.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_container)

	# 空状态文字
	var empty := Label.new()
	empty.name = "EmptyLabel"
	empty.text = "还没有猫咪，先去孵化一只吧~"
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_theme_color_override("font_color", Color("#4F453C"))
	empty.add_theme_font_size_override("font_size", 16)
	empty.visible = false
	_list_container.add_child(empty)

	# 入场动画（淡入）
	modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(self, "modulate", Color.WHITE, 0.2)


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
	var cat_id: String = String(cat_data.id)
	var is_companion := cat_id == companion_id

	var row := TextureButton.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.texture_normal = load("res://assets/art/ui/companion/btn_cat_row_normal.png")
	row.texture_hover = load("res://assets/art/ui/companion/btn_cat_row_hover.png")
	row.texture_pressed = load("res://assets/art/ui/companion/btn_cat_row_pressed.png")
	row.texture_disabled = load("res://assets/art/ui/companion/btn_cat_row_disabled.png")
	row.ignore_texture_size = true
	row.stretch_mode = TextureButton.STRETCH_SCALE

	# 内容容器
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 8)
	row.add_child(hb)

	# 左边距 + 品种色圆头像（Panel 才能正确渲染圆角）
	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(14, 1)
	hb.add_child(left_pad)

	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(48, 48)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var avatar_sb := StyleBoxFlat.new()
	avatar_sb.bg_color = _breed_color(String(cat_data.species))
	avatar_sb.set_corner_radius_all(24)
	avatar.add_theme_stylebox_override("panel", avatar_sb)
	hb.add_child(avatar)

	# 名字 + 品种
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(info)

	var name_label := Label.new()
	name_label.text = cat_data.display_name
	name_label.add_theme_color_override("font_color", Color("#4F453C") if not is_companion else Color("#C4894A"))
	name_label.add_theme_font_size_override("font_size", 18)
	info.add_child(name_label)

	var breed_label := Label.new()
	breed_label.text = _breed_text(String(cat_data.species))
	breed_label.add_theme_color_override("font_color", Color("#8B7355"))
	breed_label.add_theme_font_size_override("font_size", 13)
	info.add_child(breed_label)

	# 随行标记
	if is_companion:
		var check := Label.new()
		check.text = "✅ 随行中"
		check.add_theme_color_override("font_color", Color("#C4894A"))
		check.add_theme_font_size_override("font_size", 14)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(check)
	else:
		# 右侧留白占位
		var right_pad := Control.new()
		right_pad.custom_minimum_size = Vector2(12, 1)
		hb.add_child(right_pad)

	row.pressed.connect(func():
		_on_cat_selected(cat_id, is_companion)
	)

	return row


func _on_cat_selected(cat_id: String, is_current: bool) -> void:
	if is_current:
		_close()
		return
	if HatchEngine:
		HatchEngine.set_companion_cat_id(cat_id)
	_close()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _close() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.15)
	await t.finished
	UIManager.go_back()


func handle_back() -> bool:
	_close()
	return true


func _center_control(control: Control, control_size: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -control_size.x * 0.5
	control.offset_top = -control_size.y * 0.5
	control.offset_right = control_size.x * 0.5
	control.offset_bottom = control_size.y * 0.5


func _breed_color(species: String) -> Color:
	match species:
		CatData.BREED_ORANGE: return Color(1.0, 0.6, 0.2)
		CatData.BREED_BRITISH: return Color(0.5, 0.5, 0.6)
		CatData.BREED_SIAMESE: return Color(0.8, 0.7, 0.5)
		_: return Color(0.6, 0.6, 0.6)


func _breed_text(species: String) -> String:
	match species:
		CatData.BREED_ORANGE: return "橘猫"
		CatData.BREED_BRITISH: return "英短"
		CatData.BREED_SIAMESE: return "暹罗"
		_: return species
