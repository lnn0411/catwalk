extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

const NAME_POOLS := {
	CatData.BREED_ORANGE: ["橘子", "小橘", "橙橙"],
	CatData.BREED_BRITISH: ["蓝蓝", "灰灰", "英英"],
	CatData.BREED_SIAMESE: ["暹暹", "可可", "奶茶"],
}

var _cat
var _hatch_show
var _panel: PanelContainer
var _name_input: LineEdit
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	_rng.randomize()
	_build_ui()
	_apply_cat()

func _on_page_setup(data: Dictionary) -> void:
	_cat = data.get("cat", null)
	_hatch_show = data.get("hatch_show", null)

func handle_back() -> bool:
	return true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(Palette.BG_NIGHT_OVERLAY, 0.72))

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(80.0, 273.0)
	_panel.size = Vector2(560.0, 607.0)
	_panel.add_theme_stylebox_override("panel", _style(Palette.BG_WARM_WHITE, Palette.BORDER_ACTIVE, 8))
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 15)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 32.0
	box.offset_right = -32.0
	box.offset_top = 29.0
	box.offset_bottom = -29.0
	_panel.add_child(box)

	var title := Label.new()
	title.text = "给猫咪取名"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	box.add_child(title)

	var image := ColorRect.new()
	image.color = _cat_color()
	image.custom_minimum_size = Vector2(200.0, 200.0)
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(image)

	var meta := Label.new()
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 16)
	meta.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	meta.text = "%s / %s" % [_breed_text(), _rarity_text()]
	box.add_child(meta)

	_name_input = LineEdit.new()
	_name_input.max_length = 16
	_name_input.custom_minimum_size = Vector2(0.0, 47.0)
	_name_input.add_theme_font_size_override("font_size", 18)
	_name_input.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_name_input.text = _random_name()
	box.add_child(_name_input)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var random_button := Button.new()
	random_button.text = "随机"
	random_button.custom_minimum_size = Vector2(0.0, 45.0)
	random_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_button.pressed.connect(func() -> void: _name_input.text = _random_name())
	row.add_child(random_button)

	var confirm_button := Button.new()
	confirm_button.text = "确认"
	confirm_button.custom_minimum_size = Vector2(0.0, 45.0)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(_confirm_name)
	row.add_child(confirm_button)

func _apply_cat() -> void:
	if _name_input == null:
		return
	if _cat != null and String(_cat.display_name).length() >= 2:
		_name_input.text = String(_cat.display_name)
	else:
		_name_input.text = _random_name()

func _confirm_name() -> void:
	if _cat == null:
		UIManager.close_overlay()
		return
	var value := _name_input.text.strip_edges()
	if value.length() < 2:
		value = _random_name()
	if value.length() > 16:
		value = value.substr(0, 16)
	_cat.display_name = value
	if SaveManager:
		SaveManager.save_all()
	if _hatch_show != null and is_instance_valid(_hatch_show) and _hatch_show.has_method("resume_after_name_popup"):
		_hatch_show.call_deferred("resume_after_name_popup")
	UIManager.close_overlay()

func _random_name() -> String:
	var pool := Array(NAME_POOLS.get(_species(), NAME_POOLS[CatData.BREED_ORANGE]))
	return String(pool[_rng.randi_range(0, pool.size() - 1)])

func _species() -> String:
	return String(_cat.species) if _cat != null else CatData.BREED_ORANGE

func _breed_text() -> String:
	match _species():
		CatData.BREED_BRITISH:
			return "英短"
		CatData.BREED_SIAMESE:
			return "暹罗"
		_:
			return "橘猫"

func _rarity_text() -> String:
	return String(_cat.rarity) if _cat != null else CatData.RARITY_COMMON

func _cat_color() -> Color:
	match _species():
		CatData.BREED_BRITISH:
			return Palette.CAT_BRIT_LIGHT
		CatData.BREED_SIAMESE:
			return Palette.CAT_SIAM_HIGH
		_:
			return Palette.CAT_ORANGE_LIGHT

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style
