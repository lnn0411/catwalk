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
	_center_control(panel, Vector2(560, 400))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_top = 0.0
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 24
	box.offset_top = 20
	box.offset_right = -24
	box.offset_bottom = -16
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "选择探索时长"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 24)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "时间越久，猫咪带回稀有发现的机会越高"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hint, 15)
	box.add_child(hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(row)

	for duration in DURATIONS:
		var button := TextureButton.new()
		button.custom_minimum_size = Vector2(126, 68)
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
	cancel.custom_minimum_size = Vector2(126, 68)
	cancel.texture_normal = load("res://assets/art/ui/catcard/btn_feed_normal.png")
	cancel.texture_hover = load("res://assets/art/ui/catcard/btn_feed_hover.png")
	cancel.texture_pressed = load("res://assets/art/ui/catcard/btn_feed_pressed.png")
	cancel.ignore_texture_size = true
	cancel.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
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
