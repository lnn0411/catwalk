extends Control

signal confirmed(chosen_location: String, duration_hours: int)
signal canceled

const DURATIONS: Array[int] = [1, 2, 4]

var _cat_name := "猫咪"
var _cat_id := ""
var _cat_species := ""

var _title_label: Label
var _selected_location := ""
var _selected_duration := 2
var _location_buttons: Array[Button] = []
var _duration_buttons: Array[Button] = []


func _ready() -> void:
	name = "ExploreConfirmDialog"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func setup(cat_name: String, cat_id: String, cat_species: String) -> void:
	_cat_name = cat_name
	_cat_id = cat_id
	_cat_species = cat_species
	if _title_label != null:
		_title_label.text = "派遣 %s 去探索" % _cat_name


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
	box.offset_left = 28
	box.offset_top = 20
	box.offset_right = -28
	box.offset_bottom = -16
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title_label = Label.new()
	_title_label.text = "派遣 %s 去探索" % _cat_name
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_title_label, 24)
	box.add_child(_title_label)

	var location_names := {
		"convenience_store": "便利店",
		"park_bench": "公园长椅",
		"subway_station": "地铁站",
		"bookstore": "书店",
		"cafe": "咖啡馆",
		"hospital_corridor": "医院走廊",
		"sky_bridge": "天桥",
		"night_market": "夜市",
		"playground": "游乐场",
		"rainy_day": "雨天"
	}

	var choices := ExploreEngine.get_location_choices(_cat_id, _cat_species)
	if choices.is_empty():
		choices = {"high": "park_bench", "medium": "cafe", "low": "bookstore"}

	var first_loc := ""
	for tier in ["high", "medium", "low"]:
		var loc := String(choices.get(tier, ""))
		if loc == "":
			continue
		if first_loc == "":
			first_loc = loc
		var loc_name := String(location_names.get(loc, loc))
		var text := "推荐 %s 返回物+1" % loc_name if tier == "high" else loc_name
		var btn := _make_flat_button(text, Vector2(496, 34), 14)
		var my_loc := loc
		btn.pressed.connect(func() -> void:
			_selected_location = my_loc
			_refresh_location_buttons()
		)
		box.add_child(btn)
		_location_buttons.append(btn)

	_selected_location = first_loc
	_refresh_location_buttons()

	var duration_row := HBoxContainer.new()
	duration_row.alignment = BoxContainer.ALIGNMENT_CENTER
	duration_row.add_theme_constant_override("separation", 10)
	box.add_child(duration_row)

	for duration in DURATIONS:
		var btn := _make_flat_button("%d小时" % duration, Vector2(82, 32), 14)
		var my_duration := duration
		btn.pressed.connect(func() -> void:
			_selected_duration = my_duration
			_refresh_duration_buttons()
		)
		duration_row.add_child(btn)
		_duration_buttons.append(btn)

	_refresh_duration_buttons()

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	box.add_child(action_row)

	var cancel_btn := TextureButton.new()
	cancel_btn.custom_minimum_size = Vector2(126, 68)
	cancel_btn.texture_normal = load("res://assets/art/ui/catcard/btn_feed_normal.png")
	cancel_btn.texture_hover = load("res://assets/art/ui/catcard/btn_feed_hover.png")
	cancel_btn.texture_pressed = load("res://assets/art/ui/catcard/btn_feed_pressed.png")
	cancel_btn.texture_disabled = load("res://assets/art/ui/catcard/btn_feed_disabled.png")
	cancel_btn.ignore_texture_size = true
	cancel_btn.stretch_mode = TextureButton.STRETCH_SCALE
	cancel_btn.pressed.connect(func() -> void:
		canceled.emit()
	)
	action_row.add_child(cancel_btn)

	var cancel_label := Label.new()
	cancel_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cancel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cancel_label.text = "取消"
	cancel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cancel_label.add_theme_font_size_override("font_size", 18)
	cancel_label.add_theme_color_override("font_color", Color("#4F453C"))
	cancel_btn.add_child(cancel_label)

	var confirm_btn := TextureButton.new()
	confirm_btn.custom_minimum_size = Vector2(126, 68)
	confirm_btn.texture_normal = load("res://assets/art/ui/catcard/btn_play_normal.png")
	confirm_btn.texture_hover = load("res://assets/art/ui/catcard/btn_play_hover.png")
	confirm_btn.texture_pressed = load("res://assets/art/ui/catcard/btn_play_pressed.png")
	confirm_btn.texture_disabled = load("res://assets/art/ui/catcard/btn_play_disabled.png")
	confirm_btn.ignore_texture_size = true
	confirm_btn.stretch_mode = TextureButton.STRETCH_SCALE
	confirm_btn.pressed.connect(func() -> void:
		if _selected_location != "":
			confirmed.emit(_selected_location, _selected_duration)
	)
	action_row.add_child(confirm_btn)

	var confirm_label := Label.new()
	confirm_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_label.text = "出发"
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirm_label.add_theme_font_size_override("font_size", 18)
	confirm_label.add_theme_color_override("font_color", Color("#4F453C"))
	confirm_btn.add_child(confirm_label)


func _make_flat_button(text: String, min_size: Vector2, font_size: int, primary := false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color("#4F453C") if not primary else Color.WHITE)
	btn.add_theme_stylebox_override("normal", _button_style(primary, false))
	btn.add_theme_stylebox_override("hover", _button_style(primary, true))
	btn.add_theme_stylebox_override("pressed", _button_style(primary, true))
	return btn


func _button_style(primary: bool, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#D89B42") if primary else Color("#FFF4D8")
	if active:
		style.bg_color = Color("#C9852E") if primary else Color("#FFE4A8")
	style.border_color = Color("#8F6843")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _refresh_location_buttons() -> void:
	for btn in _location_buttons:
		var selected := btn.text.find(_location_label(_selected_location)) != -1
		btn.add_theme_stylebox_override("normal", _button_style(false, selected))


func _refresh_duration_buttons() -> void:
	for btn in _duration_buttons:
		var selected := btn.text == "%d小时" % _selected_duration
		btn.add_theme_stylebox_override("normal", _button_style(false, selected))


func _location_label(loc: String) -> String:
	var location_names := {
		"convenience_store": "便利店",
		"park_bench": "公园长椅",
		"subway_station": "地铁站",
		"bookstore": "书店",
		"cafe": "咖啡馆",
		"hospital_corridor": "医院走廊",
		"sky_bridge": "天桥",
		"night_market": "夜市",
		"playground": "游乐场",
		"rainy_day": "雨天"
	}
	return String(location_names.get(loc, loc))


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
