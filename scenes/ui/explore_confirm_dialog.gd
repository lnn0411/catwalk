extends Control

signal confirmed(chosen_location: String)
signal canceled

var _cat_name := "猫咪"
var _cat_id := ""
var _cat_species := ""
var duration_hours := 2
var _title_label: Label

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
		_title_label.text = "派遣 %s 去哪儿探索？" % _cat_name

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
	_center_control(panel, Vector2(560, 450))
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
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "派遣 %s 去哪儿探索？" % _cat_name
	_style_label(_title_label, 22)
	box.add_child(_title_label)

	var location_names := {
		"convenience_store": "便利店", "park_bench": "公园长椅",
		"subway_station": "地铁站", "bookstore": "书店",
		"cafe": "咖啡馆", "hospital_corridor": "医院走廊",
		"sky_bridge": "天桥", "night_market": "夜市",
		"playground": "游乐场", "rainy_day": "雨天"
	}
	var choices := ExploreEngine.get_location_choices(_cat_id, _cat_species)
	if choices.is_empty():
		choices = {"high": "park_bench", "medium": "cafe", "low": "bookstore"}
	for tier in ["high", "medium", "low"]:
		var loc := String(choices.get(tier, ""))
		if loc == "":
			continue
		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(360, 56)
		btn.size = Vector2(360, 56)
		btn.texture_normal = load("res://assets/art/ui/catcard/btn_feed_normal.png")
		btn.texture_hover = load("res://assets/art/ui/catcard/btn_feed_hover.png")
		btn.texture_pressed = load("res://assets/art/ui/catcard/btn_feed_pressed.png")
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		var my_loc := loc
		btn.pressed.connect(func() -> void:
			confirmed.emit(my_loc)
		)
		box.add_child(btn)

		var label := Label.new()
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 18
		label.offset_right = -18
		label.offset_top = 0
		label.offset_bottom = 0
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.clip_text = true
		label.add_theme_color_override("font_color", Color("#4F453C"))
		var loc_name := String(location_names.get(loc, loc))
		if tier == "high":
			label.text = "❤️ %s（偏好，返回物+1）" % loc_name
		else:
			label.text = "   %s" % loc_name
		btn.add_child(label)

	var cancel_row := HBoxContainer.new()
	cancel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cancel_row)

	var cancel := TextureButton.new()
	cancel.custom_minimum_size = Vector2(180, 52)
	cancel.size = Vector2(180, 52)
	cancel.texture_normal = load("res://assets/art/ui/catcard/btn_secondary_blank.png")
	cancel.ignore_texture_size = true
	cancel.stretch_mode = TextureButton.STRETCH_SCALE
	cancel.pressed.connect(func() -> void:
		canceled.emit()
	)
	cancel_row.add_child(cancel)

	var cl := Label.new()
	cl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.text = "算了"
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cl.add_theme_font_size_override("font_size", 18)
	cl.add_theme_color_override("font_color", Color("#4F453C"))
	cancel.add_child(cl)

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
