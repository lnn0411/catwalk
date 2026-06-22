extends Control

signal duration_selected(duration_hours: int)
signal canceled

const DURATIONS := [1, 2, 4]

var _panel: PanelContainer


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
	dim.color = Color(0, 0, 0, 0.48)
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(dim)

	_panel = PanelContainer.new()
	_center_control(_panel, Vector2(560, 320))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(_panel, Color("#3C2A1C"), Palette.AMBER)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(box)

	var title := Label.new()
	title.text = "选择探索时长"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 26)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "时间越久，猫咪带回稀有发现的机会越高"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(hint, 15)
	box.add_child(hint)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	for duration in DURATIONS:
		var button := Button.new()
		button.text = "%d小时" % duration
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 96)
		_style_button(button)
		button.pressed.connect(func() -> void:
			duration_selected.emit(duration)
		)
		row.add_child(button)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(0, 48)
	_style_button(cancel)
	cancel.pressed.connect(func() -> void:
		canceled.emit()
	)
	box.add_child(cancel)


func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", font_size)


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.AMBER
	normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Palette.AMBER.lightened(0.08)
	hover.set_corner_radius_all(8)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Palette.UI_PRESSED_AMBER
	pressed.set_corner_radius_all(8)
	button.add_theme_stylebox_override("pressed", pressed)


func _style_panel(panel: PanelContainer, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_top = 24
	style.content_margin_right = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)


func _center_control(control: Control, control_size: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -control_size.x * 0.5
	control.offset_top = -control_size.y * 0.5
	control.offset_right = control_size.x * 0.5
	control.offset_bottom = control_size.y * 0.5
