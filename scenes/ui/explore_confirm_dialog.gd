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
	box.offset_top = 20
	box.offset_right = -24
	box.offset_bottom = -16
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_title_label, 24)
	box.add_child(_title_label)

	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_body_label, 16)
	box.add_child(_body_label)

	var sep := HSeparator.new()
	sep.modulate = Color("#D4A85A", 0.4)
	box.add_child(sep)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

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
	row.add_child(cancel)

	var cancel_label := Label.new()
	cancel_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cancel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cancel_label.text = "再想想"
	cancel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cancel_label.add_theme_font_size_override("font_size", 18)
	cancel_label.add_theme_color_override("font_color", Color("#4F453C"))
	cancel.add_child(cancel_label)

	var ok := TextureButton.new()
	ok.custom_minimum_size = Vector2(126, 68)
	ok.texture_normal = load("res://assets/art/ui/catcard/btn_explore_normal.png")
	ok.texture_hover = load("res://assets/art/ui/catcard/btn_explore_hover.png")
	ok.texture_pressed = load("res://assets/art/ui/catcard/btn_explore_pressed.png")
	ok.ignore_texture_size = true
	ok.stretch_mode = TextureButton.STRETCH_SCALE
	ok.pressed.connect(func() -> void:
		confirmed.emit(_duration_hours)
	)
	row.add_child(ok)

	var ok_label := Label.new()
	ok_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ok_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ok_label.text = "出发"
	ok_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ok_label.add_theme_font_size_override("font_size", 18)
	ok_label.add_theme_color_override("font_color", Color("#4F453C"))
	ok.add_child(ok_label)

func _refresh_text() -> void:
	if _title_label == null or _body_label == null:
		return
	_title_label.text = "派遣 %s 探索？" % _cat_name
	_body_label.text = "本次探索需要 %d 小时。探索期间不能喂食、抚摸或玩耍，返回后可领取奖励。" % _duration_hours

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
