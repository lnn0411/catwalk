extends Control

signal closed

var _cat_name := "猫咪"
var _reward_type := "postcard"
var _title: Label
var _body: Label


func _ready() -> void:
	name = "PostcardReveal"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_text()


func reveal(cat_name: String, reward_type: String) -> void:
	_cat_name = cat_name
	_reward_type = reward_type
	if is_inside_tree():
		_refresh_text()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	add_child(dim)

	var panel := PanelContainer.new()
	_center_control(panel, Vector2(560, 360))
	_style_panel(panel)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_title, 27, Palette.AMBER)
	box.add_child(_title)

	var art := ColorRect.new()
	art.custom_minimum_size = Vector2(0, 130)
	art.color = Color("#F6E6C8")
	box.add_child(art)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_body, 16, Color.WHITE)
	box.add_child(_body)

	var ok := Button.new()
	ok.text = "收下"
	ok.custom_minimum_size = Vector2(0, 52)
	_style_button(ok)
	ok.pressed.connect(func() -> void:
		closed.emit()
	)
	box.add_child(ok)


func _refresh_text() -> void:
	if _title == null or _body == null:
		return
	_title.text = _title_text(_reward_type)
	_body.text = "%s %s" % [_cat_name, _body_text(_reward_type)]


func _title_text(reward_type: String) -> String:
	match reward_type:
		"ingredient":
			return "新食材"
		"decoration":
			return "新装饰"
		"hidden":
			return "隐藏发现"
		_:
			return "城市明信片"


func _body_text(reward_type: String) -> String:
	match reward_type:
		"ingredient":
			return "带回了一份可以收藏的探索食材。"
		"decoration":
			return "找到了适合小窝的新装饰灵感。"
		"hidden":
			return "发现了一处平时看不见的秘密角落。"
		_:
			return "从城市的一角寄回了新的风景。"


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_color_override("font_color", color)
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


func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3C2A1C")
	style.border_color = Palette.AMBER
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
