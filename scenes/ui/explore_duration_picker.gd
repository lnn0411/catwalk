extends Control

signal duration_selected(duration_hours: int)
signal canceled

const DURATIONS := [1, 2, 4]

func _ready() -> void:
	name = "ExploreDurationPicker"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		canceled.emit()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(dim)

	var panel := TextureRect.new()
	panel.texture = load("res://assets/art/ui/adopt/adopt_panel.png")
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	_center_control(panel, Vector2(560, 360))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_top = 0.0
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 24
	box.offset_top = 16
	box.offset_right = -24
	box.offset_bottom = -14
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "选择探索时长"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 24)
	box.add_child(title)

	# spacer — 提示文案下移20px
	var hint_spacer := Control.new()
	hint_spacer.custom_minimum_size = Vector2(0, 20)
	box.add_child(hint_spacer)

	var hint := Label.new()
	hint.text = "时间越久，猫咪带回稀有发现的机会越高"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hint, 18)
	box.add_child(hint)

	# spacer — 按钮下移30px(原50px,提示下移20px后减20保持按钮位置不变)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(row)

	for duration in DURATIONS:
		var button := TextureButton.new()
		# explore 贴图 280×48 (5.83:1)。三按钮并排最大宽 ~162，高取下限 80 →
		# 2.03:1，是本约束下最接近横条、变形最小的可行尺寸。
		button.custom_minimum_size = Vector2(162, 80)
		button.texture_normal = load("res://assets/art/ui/catcard/btn_explore_normal.png")
		button.texture_hover = load("res://assets/art/ui/catcard/btn_explore_hover.png")
		button.texture_pressed = load("res://assets/art/ui/catcard/btn_explore_pressed.png")
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.pressed.connect(func() -> void:
			duration_selected.emit(duration)
		)
		row.add_child(button)

		var label := Label.new()
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "%d小时" % duration
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color("#4F453C"))
		button.add_child(label)

	var sep := HSeparator.new()
	sep.modulate = Color("#D4A85A", 0.4)
	box.add_child(sep)

	var cancel_row := HBoxContainer.new()
	cancel_row.add_theme_constant_override("separation", 12)
	cancel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cancel_row)

	var cancel := TextureButton.new()
	# feed 贴图 180×52 (3.46:1)。单独一行、无并排约束，取 220×80 (2.75:1)，接近原生横条，变形 ~1.26×。
	cancel.custom_minimum_size = Vector2(220, 80)
	cancel.texture_normal = load("res://assets/art/ui/catcard/btn_feed_normal.png")
	cancel.texture_hover = load("res://assets/art/ui/catcard/btn_feed_hover.png")
	cancel.texture_pressed = load("res://assets/art/ui/catcard/btn_feed_pressed.png")
	cancel.ignore_texture_size = true
	cancel.stretch_mode = TextureButton.STRETCH_SCALE
	cancel.pressed.connect(func() -> void:
		canceled.emit()
	)
	cancel_row.add_child(cancel)

	var cancel_label := Label.new()
	cancel_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cancel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cancel_label.text = "取消"
	cancel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cancel_label.add_theme_font_size_override("font_size", 18)
	cancel_label.add_theme_color_override("font_color", Color("#4F453C"))
	cancel.add_child(cancel_label)

func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_color_override("font_color", Color("#4F453C"))
	label.add_theme_font_size_override("font_size", font_size)

func _center_control(control: Control, control_size: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -control_size.x * 0.5
	control.offset_top = -control_size.y * 0.5
	control.offset_right = control_size.x * 0.5
	control.offset_bottom = control_size.y * 0.5
