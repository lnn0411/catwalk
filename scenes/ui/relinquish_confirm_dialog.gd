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

	var panel := TextureRect.new()
	panel.texture = load("res://assets/art/ui/panels/popup_bg.png")
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
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	var cancel := TextureButton.new()
	cancel.custom_minimum_size = Vector2(170, 70)
	cancel.texture_normal = load("res://assets/art/ui/incubation/components/btn_secondary_blank.png")
	cancel.ignore_texture_size = true
	cancel.stretch_mode = TextureButton.STRETCH_SCALE
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
	ok.custom_minimum_size = Vector2(170, 70)
	ok.texture_normal = load("res://assets/art/ui/incubation/components/btn_confirm_name.png")
	ok.ignore_texture_size = true
	ok.stretch_mode = TextureButton.STRETCH_SCALE
	ok.pressed.connect(func() -> void:
		confirmed.emit()
	)
	row.add_child(ok)

	var ok_label := Label.new()
	ok_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ok_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ok_label.text = "💕 送养"
	ok_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ok_label.add_theme_font_size_override("font_size", 18)
	ok_label.add_theme_color_override("font_color", Color("#4F453C"))
	ok.add_child(ok_label)


func _refresh_text() -> void:
	if _title_label == null:
		return
	var name_str: String = String(_cat_data.get("display_name", _cat_data.get("name", "猫咪")))
	var rarity: String = String(_cat_data.get("rarity", "common"))
	var level := int(_cat_data.get("level", 1))
	var friendship := int(_cat_data.get("friendship", 0))

	_title_label.text = "送养 %s？" % name_str
	_body_label.text = "将它送到一个更好的家庭，\n虽然很不舍，但希望它能幸福..."

	var preview := RelinquishSystem.preview_relinquish(_cat_data)
	var petals: int = preview.get("love_petals", 0)
	var gold: int = preview.get("gold_coins", 0)

	var rarity_cn := ""
	match rarity:
		"legendary": rarity_cn = "传说"
		"epic": rarity_cn = "史诗"
		"rare": rarity_cn = "稀有"
		_: rarity_cn = "普通"

	_detail_label.text = "%s · Lv.%d · 好感 %d\n\n返还：❤️ %d 花瓣  🪙 %d 金币" % [rarity_cn, level, friendship, petals, gold]


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
