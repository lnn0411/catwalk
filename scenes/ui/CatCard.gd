extends Control

const CARD_HEIGHT := 260.0

var _cat_data: Dictionary = {}
var _name_label: Label
var _species_label: Label
var _rarity_label: Label
var _feed_btn: Button
var _pet_btn: Button
var _play_btn: Button
var _cooldown_label: Label
var _overlay: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.4)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 50
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	var panel := PanelContainer.new()
	panel.name = "CatCardPanel"
	panel.z_index = 60
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -CARD_HEIGHT
	panel.offset_bottom = 0.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.10, 0.08, 0.97)
	panel_style.set_corner_radius(CORNER_TOP_LEFT, 20)
	panel_style.set_corner_radius(CORNER_TOP_RIGHT, 20)
	panel_style.set_corner_radius(CORNER_BOTTOM_LEFT, 0)
	panel_style.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.anchor_left = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_top = 0.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 16.0
	vbox.offset_right = -16.0
	vbox.offset_top = 12.0
	vbox.offset_bottom = -16.0
	panel.add_child(vbox)

	var info_box := HBoxContainer.new()
	info_box.add_theme_constant_override("separation", 10)
	vbox.add_child(info_box)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	info_box.add_child(_name_label)

	_species_label = Label.new()
	_species_label.add_theme_font_size_override("font_size", 16)
	_species_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_species_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_child(_species_label)

	_rarity_label = Label.new()
	_rarity_label.add_theme_font_size_override("font_size", 14)
	_rarity_label.add_theme_color_override("font_color", Color.GOLD)
	info_box.add_child(_rarity_label)

	_cooldown_label = Label.new()
	_cooldown_label.add_theme_font_size_override("font_size", 13)
	_cooldown_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	vbox.add_child(_cooldown_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_row)

	_feed_btn = _create_interact_btn("🍖 喂食", Color(0.9, 0.5, 0.2))
	_feed_btn.pressed.connect(_on_feed_pressed)
	btn_row.add_child(_feed_btn)

	_pet_btn = _create_interact_btn("✋ 抚摸", Color(0.4, 0.7, 0.9))
	_pet_btn.pressed.connect(_on_pet_pressed)
	btn_row.add_child(_pet_btn)

	_play_btn = _create_interact_btn("🎾 玩耍", Color(0.3, 0.8, 0.4))
	_play_btn.pressed.connect(_on_play_pressed)
	btn_row.add_child(_play_btn)

	scale = Vector2.ZERO
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func _create_interact_btn(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, 52.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 16)

	var bg := StyleBoxFlat.new()
	bg.bg_color = color
	bg.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("normal", bg)

	var disabled_bg := StyleBoxFlat.new()
	disabled_bg.bg_color = Color(0.3, 0.3, 0.3)
	disabled_bg.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("disabled", disabled_bg)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

func set_data(cat_data: Dictionary, _screen_pos: Vector2 = Vector2.ZERO) -> void:
	_cat_data = cat_data
	_name_label.text = String(cat_data.get("display_name", cat_data.get("id", "猫")))
	_species_label.text = _translate_species(String(cat_data.get("species", "")))
	var rarity := String(cat_data.get("rarity", "common"))
	_rarity_label.text = _translate_rarity(rarity)
	_refresh_button_states()

func _translate_species(species: String) -> String:
	match species:
		"orange":
			return "橘猫"
		"british":
			return "英短"
		"siamese":
			return "暹罗"
		_:
			return species

func _translate_rarity(rarity: String) -> String:
	match rarity:
		"common":
			return "★ 普通"
		"rare":
			return "★★ 稀有"
		"epic":
			return "★★★ 史诗"
		"legendary":
			return "★★★★ 传说"
		_:
			return rarity

func _on_feed_pressed() -> void:
	if _cat_data.is_empty():
		return
	var isys := get_node_or_null("/root/InteractionSystem")
	if isys == null:
		return
	if isys.do_interact_global(String(_cat_data.get("id", "")), "feed"):
		_show_feedback("❤️×3")
		_refresh_button_states()

func _on_pet_pressed() -> void:
	if _cat_data.is_empty():
		return
	var isys := get_node_or_null("/root/InteractionSystem")
	if isys == null:
		return
	if isys.do_interact_global(String(_cat_data.get("id", "")), "pet"):
		_show_feedback("❤️×1")
		_refresh_button_states()

func _on_play_pressed() -> void:
	if _cat_data.is_empty():
		return
	var isys := get_node_or_null("/root/InteractionSystem")
	if isys == null:
		return
	if isys.do_interact_global(String(_cat_data.get("id", "")), "play"):
		_show_feedback("⭐×5")
		_refresh_button_states()

func _show_feedback(text: String) -> void:
	var fb := Label.new()
	fb.text = text
	fb.add_theme_font_size_override("font_size", 36)
	fb.add_theme_color_override("font_color", Color.WHITE)
	fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fb.z_index = 100
	fb.position = Vector2(260.0, 300.0)
	fb.size = Vector2(200.0, 60.0)
	add_child(fb)

	var tween := create_tween()
	tween.tween_property(fb, "position:y", fb.position.y - 80.0, 0.8)
	tween.parallel().tween_property(fb, "modulate:a", 0.0, 0.8)
	tween.tween_callback(fb.queue_free)

func _refresh_button_states() -> void:
	var isys := get_node_or_null("/root/InteractionSystem")
	if isys == null or _feed_btn == null:
		return

	var cat_id := String(_cat_data.get("id", ""))
	_feed_btn.text = "🍖 喂食"
	_pet_btn.text = "✋ 抚摸"
	_play_btn.text = "🎾 玩耍"

	_feed_btn.disabled = not isys.can_interact_global("feed")
	_pet_btn.disabled = not isys.can_interact_global("pet")
	_play_btn.disabled = not isys.can_interact_global("play")

	var texts := []
	for t in ["feed", "play"]:
		var rem := isys.get_global_cooldown_remaining(t)
		if rem > 0.0:
			texts.append("%s: %ds" % ["喂食" if t == "feed" else "玩耍", int(ceil(rem))])
	_cooldown_label.text = "  ".join(texts)

	if isys.is_interaction_blocked(cat_id, "feed"):
		_feed_btn.disabled = true
		_feed_btn.text = "😴 猫咪在休息"
	if isys.is_interaction_blocked(cat_id, "play"):
		_play_btn.disabled = true
		_play_btn.text = "😴 猫咪在休息"
	if isys.is_interaction_blocked(cat_id, "pet"):
		_pet_btn.disabled = true

func _process(_delta: float) -> void:
	_refresh_button_states()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()
	elif event is InputEventScreenTouch and event.pressed:
		_close()

func _close() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free)
