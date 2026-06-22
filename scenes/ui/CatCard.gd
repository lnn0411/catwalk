extends Control

const CARD_HEIGHT := 200.0
const DESIGN_SIZE := Vector2(720.0, 1280.0)
const CARD_COLOR := Color("#3C2A1C")
const TEXT_COLOR := Color("#FFFFFF")
const DISABLED_ALPHA := 0.4

var cat_id: String = ""
var cat_data
var interaction_system

@onready var _card_background: ColorRect = %CardBackground
@onready var _avatar_rect: TextureRect = %AvatarRect
@onready var _name_label: Label = %CatName
@onready var _meta_label: Label = %BreedRarityLabel
@onready var _feed_button: Button = %FeedButton
@onready var _pet_button: Button = %PetButton
@onready var _play_button: Button = %PlayButton
@onready var _status_label: Label = %StatusLabel

var _cooldown_timer: Timer
var _screen_pos := Vector2.ZERO
var _closing := false
var _feedback_until := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_theme()
	_setup_cooldown_timer()
	_resolve_interaction_system()
	_refresh_cat_info()
	refresh_interaction_buttons()
	_play_open_animation()


func setup(c_id: String, c_data, screen_pos: Vector2) -> void:
	cat_id = c_id
	cat_data = c_data
	_screen_pos = screen_pos
	_resolve_interaction_system()
	_refresh_cat_info()
	refresh_interaction_buttons()


func refresh_interaction_buttons() -> void:
	if not is_inside_tree():
		return
	if _feed_button == null or _pet_button == null or _play_button == null:
		return

	_resolve_interaction_system()
	_reset_button(_feed_button)
	_reset_button(_pet_button)
	_reset_button(_play_button)

	if cat_id == "" and cat_data != null:
		cat_id = _get_cat_property("id", "")
	if cat_data == null and cat_id == "":
		_update_cooldown_timer(false)
		return

	var annoyed := _is_annoyed()
	var sleeping := _is_sleeping()
	var any_cooldown := false
	var status_text := ""

	if annoyed:
		_set_button_disabled(_feed_button, true)
		_set_button_disabled(_pet_button, true)
		_set_button_disabled(_play_button, true)
		status_text = "猫咪不想理你..."
	elif sleeping:
		_set_button_disabled(_feed_button, true)
		_set_button_disabled(_pet_button, false)
		_set_button_disabled(_play_button, true)
		status_text = "猫咪在睡觉 😴"

	for interaction_type in ["feed", "pet", "play"]:
		var button := _button_for_type(interaction_type)
		if button == null:
			continue
		var remaining := _get_cooldown_remaining(interaction_type)
		var blocked := _is_interaction_blocked(interaction_type) or remaining > 0.0
		if blocked and not (sleeping and interaction_type == "pet") and not annoyed:
			_set_button_disabled(button, true)
		if remaining > 0.0:
			any_cooldown = true
			if status_text == "":
				status_text = "冷却中 %ds" % int(ceil(remaining))

	if Time.get_unix_time_from_system() >= _feedback_until:
		_status_label.text = status_text
	_update_cooldown_timer(any_cooldown)


func _on_feed_pressed() -> void:
	if _feed_button.disabled:
		return
	_do_interaction("feed")
	_show_feedback("🍖 喂食成功！")


func _on_pet_pressed() -> void:
	if _pet_button.disabled:
		return
	_do_interaction("pet")
	_show_feedback("✋ 摸摸头~")


func _on_play_pressed() -> void:
	if _play_button.disabled:
		return
	_do_interaction("play")
	_show_feedback("🎾 玩得好开心！")


func _play_open_animation() -> void:
	modulate.a = 1.0
	scale = Vector2.ZERO
	_set_animation_pivot()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.17)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)


func _play_close_animation() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)


func _draw() -> void:
	if _card_background == null:
		return
	var rect := Rect2(_card_background.position, _card_background.size)
	_draw_round_rect(rect, 6.0, CARD_COLOR)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _apply_theme() -> void:
	_card_background.color = Color(CARD_COLOR, 0.0)
	_style_label(_name_label, 22)
	_style_label(_meta_label, 15)
	_style_label(_status_label, 14)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_button(_feed_button)
	_style_button(_pet_button)
	_style_button(_play_button)


func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_font_size_override("font_size", font_size)


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", Color(TEXT_COLOR, 0.75))
	button.add_theme_font_size_override("font_size", 18)
	button.custom_minimum_size = Vector2(0.0, 52.0)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.AMBER
	normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", normal)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Palette.UI_PRESSED_AMBER
	pressed.set_corner_radius_all(6)
	button.add_theme_stylebox_override("pressed", pressed)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Palette.AMBER.lightened(0.08)
	hover.set_corner_radius_all(6)
	button.add_theme_stylebox_override("hover", hover)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Palette.CITY_GRAY
	disabled.set_corner_radius_all(6)
	button.add_theme_stylebox_override("disabled", disabled)


func _setup_cooldown_timer() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.name = "CooldownTimer"
	_cooldown_timer.wait_time = 1.0
	_cooldown_timer.one_shot = false
	_cooldown_timer.timeout.connect(refresh_interaction_buttons)
	add_child(_cooldown_timer)


func _refresh_cat_info() -> void:
	if not is_inside_tree():
		return
	_name_label.text = _get_cat_property("display_name", _get_cat_property("name", "猫咪"))
	var species := _get_cat_property("species", _get_cat_property("breed", "orange"))
	var rarity := _get_cat_property("rarity", "common")
	_meta_label.text = "%s · %s" % [_species_label(species), _rarity_label(rarity)]
	_avatar_rect.texture = _make_avatar_texture(_species_color(species))


func _show_feedback(text: String) -> void:
	_feedback_until = Time.get_unix_time_from_system() + 1.2
	_status_label.text = text
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(refresh_interaction_buttons)


func _do_interaction(interaction_type: String) -> void:
	_resolve_interaction_system()
	if interaction_system == null:
		return
	if _call_interaction("do_interact", interaction_type, false):
		return
	_call_interaction("do_interact_global", interaction_type, false)


func _is_interaction_blocked(interaction_type: String) -> bool:
	_resolve_interaction_system()
	if interaction_system == null:
		return false
	if _has_interaction_method("is_interaction_blocked"):
		return _call_interaction("is_interaction_blocked", interaction_type, false)
	if _has_interaction_method("can_interact"):
		return not _call_interaction("can_interact", interaction_type, true)
	if _has_interaction_method("can_interact_global"):
		return not _call_interaction("can_interact_global", interaction_type, true)
	return false


func _get_cooldown_remaining(interaction_type: String) -> float:
	_resolve_interaction_system()
	if interaction_system == null:
		return 0.0
	if _has_interaction_method("get_cooldown_remaining"):
		return float(_call_interaction("get_cooldown_remaining", interaction_type, 0.0))
	if _has_interaction_method("get_global_cooldown_remaining"):
		return float(_call_interaction("get_global_cooldown_remaining", interaction_type, 0.0))
	return 0.0


func _call_interaction(method_name: String, interaction_type: String, default_value):
	if interaction_system == null or not interaction_system.has_method(method_name):
		return default_value
	var arg_count := _get_method_arg_count(interaction_system, method_name)
	if arg_count <= 1:
		return interaction_system.call(method_name, interaction_type)
	return interaction_system.call(method_name, cat_id, interaction_type)


func _has_interaction_method(method_name: String) -> bool:
	return interaction_system != null and interaction_system.has_method(method_name)


func _get_method_arg_count(target, method_name: String) -> int:
	for method in target.get_method_list():
		if String(method.get("name", "")) == method_name:
			return Array(method.get("args", [])).size()
	return 2


func _is_annoyed() -> bool:
	if cat_id == "":
		return false
	if get_node_or_null("/root/EmotionStateMachine") != null:
		return EmotionStateMachine.is_annoyed(cat_id)
	return false


func _is_sleeping() -> bool:
	if cat_id != "" and get_node_or_null("/root/EmotionStateMachine") != null:
		if String(EmotionStateMachine.get_emotion(cat_id)) == "sleepy":
			return true
	if get_node_or_null("/root/CatSchedule") == null:
		return false
	var species := _get_cat_property("species", _get_cat_property("breed", "orange"))
	var hour := int(Time.get_datetime_dict_from_system().get("hour", 12))
	var period: String = CatSchedule.get_period(hour)
	return String(CatSchedule.get_state(species, period)) == "sleep"


func _resolve_interaction_system() -> void:
	if interaction_system != null:
		return
	interaction_system = get_node_or_null("/root/InteractionSystem")


func _reset_button(button: Button) -> void:
	button.disabled = false
	button.modulate.a = 1.0


func _set_button_disabled(button: Button, disabled: bool) -> void:
	button.disabled = disabled
	button.modulate.a = DISABLED_ALPHA if disabled else 1.0


func _button_for_type(interaction_type: String) -> Button:
	match interaction_type:
		"feed":
			return _feed_button
		"pet":
			return _pet_button
		"play":
			return _play_button
		_:
			return null


func _update_cooldown_timer(should_run: bool) -> void:
	if _cooldown_timer == null:
		return
	if should_run and _cooldown_timer.is_stopped():
		_cooldown_timer.start()
	elif not should_run and not _cooldown_timer.is_stopped():
		_cooldown_timer.stop()


func _set_animation_pivot() -> void:
	var viewport_size := get_viewport_rect().size
	var fallback := Vector2(viewport_size.x * 0.5, viewport_size.y - CARD_HEIGHT * 0.5)
	pivot_offset = _screen_pos if _screen_pos != Vector2.ZERO else fallback


func _get_cat_property(property_name: String, default_value: String) -> String:
	if cat_data == null:
		return default_value
	if cat_data is Dictionary:
		return String(cat_data.get(property_name, default_value))
	var value = cat_data.get(property_name)
	return default_value if value == null else String(value)


func _draw_round_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position + Vector2(r, 0.0), Vector2(rect.size.x - r * 2.0, rect.size.y)), color, true)
	draw_rect(Rect2(rect.position + Vector2(0.0, r), Vector2(rect.size.x, rect.size.y - r * 2.0)), color, true)
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)


func _species_label(species: String) -> String:
	match species:
		"orange":
			return "橘猫"
		"british":
			return "英短"
		"siamese":
			return "暹罗"
		_:
			return species


func _rarity_label(rarity: String) -> String:
	match rarity:
		"common":
			return "普通"
		"rare":
			return "稀有"
		"epic":
			return "史诗"
		"legendary":
			return "传说"
		_:
			return rarity


func _species_color(species: String) -> Color:
	match species:
		"british":
			return Palette.CAT_BRIT_MID
		"siamese":
			return Palette.CAT_SIAM_BODY
		_:
			return Palette.CAT_ORANGE_MID


func _make_avatar_texture(color: Color) -> Texture2D:
	var image := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
