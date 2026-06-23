extends Control

signal confirmed
signal canceled

var _cat_data: Dictionary = {}
var _title_label: Label
var _body_label: Label
var _detail_label: Label


func _ready() -> void:
	name = "RelinquishConfirmDialog"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_text()


func setup(cat_data: Dictionary) -> void:
	_cat_data = cat_data
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
	_center_control(panel, Vector2(560, 360))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(panel, Color("#3C2A1C"), Color("#D4A85A"))
	add_child(panel)

	var box := VBoxContainer.new()
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

	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(_detail_label, 15)
	box.add_child(_detail_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var cancel := Button.new()
	cancel.text = "再想想"
	cancel.custom_minimum_size = Vector2(0, 52)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(cancel, Color("#7A7A7A"))
	cancel.pressed.connect(func() -> void:
		canceled.emit()
	)
	row.add_child(cancel)

	var ok := Button.new()
	ok.text = "💕 送养"
	ok.custom_minimum_size = Vector2(0, 52)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(ok, Color("#C0392B"))
	ok.pressed.connect(func() -> void:
		confirmed.emit()
	)
	row.add_child(ok)


func _refresh_text() -> void:
	if _title_label == null:
		return
	var name_str: String = String(_cat_data.get("display_name", _cat_data.get("name", "猫咪")))
	var rarity: String = String(_cat_data.get("rarity", "common"))
	var level := int(_cat_data.get("level", 1))
	var friendship := int(_cat_data.get("friendship", 0))

	_title_label.text = "送养 %s？" % name_str
	_body_label.text = "将它送到一个更好的家庭，\n虽然很不舍，但希望它能幸福..."

	var factor := 0.0
	match rarity:
		"legendary":
			factor = 5.0
		"epic":
			factor = 2.0
		"rare":
			factor = 1.0
		_:
			factor = 0.0

	var petals := 0
	var gold := 0
	if factor <= 0.0:
		gold = 200
	else:
		petals = int(factor * (level * 10 + friendship * 2))
		gold = 100

	var rarity_cn := ""
	match rarity:
		"legendary": rarity_cn = "传说"
		"epic": rarity_cn = "史诗"
		"rare": rarity_cn = "稀有"
		_: rarity_cn = "普通"

	_detail_label.text = "%s · Lv.%d · 好感 %d\n\n返还：❤️ %d 花瓣  🪙 %d 金币" % [rarity_cn, level, friendship, petals, gold]


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
