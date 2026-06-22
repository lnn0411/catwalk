extends Control

signal confirmed(duration_hours: int)
signal canceled

var _cat_name := "猫咪"
var _duration_hours := 1
var _title_label: Label
var _body_label: Label


func _ready() -> void:
	name = "ExploreConfirmDialog"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_text()


func setup(cat_name: String, duration_hours: int) -> void:
	_cat_name = cat_name
	_duration_hours = duration_hours
	if is_inside_tree():
		_refresh_text()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		canceled.emit()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(dim)

	var panel := PanelContainer.new()
	_center_control(panel, Vector2(560, 300))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(panel, Color("#3C2A1C"), Palette.AMBER)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_title_label, 25)
	box.add_child(_title_label)

	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_body_label, 16)
	box.add_child(_body_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var cancel := Button.new()
	cancel.text = "再想想"
	cancel.custom_minimum_size = Vector2(0, 52)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(cancel, Palette.CITY_GRAY)
	cancel.pressed.connect(func() -> void:
		canceled.emit()
	)
	row.add_child(cancel)

	var ok := Button.new()
	ok.text = "出发"
	ok.custom_minimum_size = Vector2(0, 52)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(ok, Palette.AMBER)
	ok.pressed.connect(func() -> void:
		confirmed.emit(_duration_hours)
	)
	row.add_child(ok)


func _refresh_text() -> void:
	if _title_label == null or _body_label == null:
		return
	_title_label.text = "派遣 %s 探索？" % _cat_name
	_body_label.text = "本次探索需要 %d 小时。探索期间不能喂食、抚摸或玩耍，返回后可领取奖励。" % _duration_hours


func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", font_size)


func _style_button(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.08)
	hover.set_corner_radius_all(8)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = color.darkened(0.08)
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
