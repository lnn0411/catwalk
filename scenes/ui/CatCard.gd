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
@onready var _explore_button: Button = %ExploreButton
var _relinquish_button: Button
@onready var _explore_state_panel: Control = %ExploreStatePanel
@onready var _exploring_label: Label = %ExploringLabel
@onready var _countdown_label: Label = %CountdownLabel
@onready var _return_time_label: Label = %ReturnTimeLabel
@onready var _status_label: Label = %StatusLabel

var _cooldown_timer: Timer
var _explore_countdown_timer: Timer
var _is_exploring_this_cat := false
var _screen_pos := Vector2.ZERO
var _closing := false
var _feedback_until := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_theme()
	_setup_cooldown_timer()
	_style_button(_explore_button)
	_setup_explore_countdown_timer()
	# 送养按钮
	_relinquish_button = Button.new()
	_relinquish_button.text = "💕 送养"
	_relinquish_button.pressed.connect(_on_relinquish_pressed)
	if _explore_button and _explore_button.get_parent():
		_explore_button.get_parent().add_child(_relinquish_button)
	_resolve_interaction_system()
	_refresh_cat_info()
	_check_explore_state()
	refresh_interaction_buttons()
	_play_open_animation()


func setup(c_id: String, c_data, screen_pos: Vector2) -> void:
	cat_id = c_id
	cat_data = c_data
	_screen_pos = screen_pos
	_resolve_interaction_system()
	_refresh_cat_info()
	_check_explore_state()
	refresh_interaction_buttons()


func refresh_interaction_buttons() -> void:
	if not is_inside_tree():
		return
	if _feed_button == null or _pet_button == null or _play_button == null:
		return
	if _check_explore_state():
		return
	update_explore_button_state()

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


func _on_relinquish_pressed() -> void:
	var cat_id := _get_cat_property("id", "")
	var cat_data = _get_full_cat_data()
	if cat_id == "":
		return
	var rs := get_node_or_null("/root/RelinquishSystem")
	if rs == null:
		return
	if HatchEngine and HatchEngine.get_cats().size() <= 1:
		_show_feedback("至少要留一只猫陪着你哦～")
		return
	var uuid := "rel_%d_%s" % [Time.get_unix_time_from_system(), cat_id]
	var result = rs.relinquish_cat(cat_data, uuid)
	if result.get("love_petals", 0) > 0 or result.get("gold_coins", 0) > 0:
		_show_feedback("送养成功 +%d花瓣 %d金币" % [result.get("love_petals",0), result.get("gold_coins",0)])
		_close()
	else:
		_show_feedback(result.get("reason", "操作被阻止"))

func _on_explore_button_pressed() -> void:
	if _explore_button == null or _explore_button.disabled:
		return
	if cat_id == "" and cat_data != null:
		cat_id = _get_cat_property("id", "")
	if cat_id == "":
		_show_feedback("暂时找不到这只猫")
		return
	if ExploreEngine.is_exploring(cat_id):
		if ExploreEngine.is_returned(cat_id):
			_collect_explore_return()
		return
	_show_duration_picker()


func update_explore_button_state() -> void:
	if _explore_button == null:
		return
	if cat_id == "" and cat_data != null:
		cat_id = _get_cat_property("id", "")
	if cat_id != "" and ExploreEngine.is_exploring(cat_id):
		_explore_button.visible = true
		_explore_button.text = "🎁 领取" if ExploreEngine.is_returned(cat_id) else "🧭 探索中"
		_set_button_disabled(_explore_button, not ExploreEngine.is_returned(cat_id))
		return

	_explore_button.visible = true
	var has_explore_slot := _has_explore_slot_available()
	_explore_button.text = "🧭 探索" if has_explore_slot else "探索名额已满"
	_set_button_disabled(_explore_button, not has_explore_slot)


func _check_explore_state() -> bool:
	if _explore_state_panel == null:
		return false
	if cat_id == "" and cat_data != null:
		cat_id = _get_cat_property("id", "")

	_is_exploring_this_cat = cat_id != "" and ExploreEngine.is_exploring(cat_id)
	_explore_state_panel.visible = _is_exploring_this_cat
	if not _is_exploring_this_cat:
		_update_explore_countdown_timer(false)
		if _feed_button != null:
			_feed_button.visible = true
		if _pet_button != null:
			_pet_button.visible = true
		if _play_button != null:
			_play_button.visible = true
		update_explore_button_state()
		return false

	if _feed_button != null:
		_feed_button.visible = false
	if _pet_button != null:
		_pet_button.visible = false
	if _play_button != null:
		_play_button.visible = false

	_update_explore_labels()
	update_explore_button_state()
	_update_explore_countdown_timer(not ExploreEngine.is_returned(cat_id))
	return true


func _setup_explore_countdown_timer() -> void:
	_explore_countdown_timer = Timer.new()
	_explore_countdown_timer.name = "ExploreCountdownTimer"
	_explore_countdown_timer.wait_time = 1.0
	_explore_countdown_timer.one_shot = false
	_explore_countdown_timer.timeout.connect(_on_explore_countdown_timeout)
	add_child(_explore_countdown_timer)


func _on_explore_countdown_timeout() -> void:
	_check_explore_state()


func _update_explore_countdown_timer(should_run: bool) -> void:
	if _explore_countdown_timer == null:
		return
	if should_run and _explore_countdown_timer.is_stopped():
		_explore_countdown_timer.start()
	elif not should_run and not _explore_countdown_timer.is_stopped():
		_explore_countdown_timer.stop()


func _update_explore_labels() -> void:
	if cat_id == "":
		return
	var remaining := ExploreEngine.get_remaining_seconds(cat_id)
	var cat_name := _get_cat_display_name()
	if ExploreEngine.is_returned(cat_id):
		_exploring_label.text = "%s 回来了" % cat_name
		_countdown_label.text = "探索完成"
		_return_time_label.text = "带回了新的发现"
		return

	_exploring_label.text = "%s 正在探索" % cat_name
	_countdown_label.text = "返回倒计时 %s" % _format_duration(remaining)
	var return_unix := Time.get_unix_time_from_system() + remaining
	var dt := Time.get_datetime_dict_from_unix_time(return_unix)
	_return_time_label.text = "预计返回 %02d:%02d" % [int(dt.get("hour", 0)), int(dt.get("minute", 0))]


func _show_duration_picker() -> void:
	var packed := load("res://scenes/ui/explore_duration_picker.tscn")
	var picker = packed.instantiate()
	picker.duration_selected.connect(func(duration_hours: int) -> void:
		_on_explore_duration_selected(duration_hours, picker)
	)
	picker.canceled.connect(func() -> void:
		picker.queue_free()
	)
	_add_overlay(picker)


func _on_explore_duration_selected(duration_hours: int, picker: Node) -> void:
	if picker != null:
		picker.queue_free()
	var packed := load("res://scenes/ui/explore_confirm_dialog.tscn")
	var dialog = packed.instantiate()
	dialog.setup(_get_cat_display_name(), duration_hours)
	dialog.confirmed.connect(func(confirmed_duration_hours: int) -> void:
		_on_explore_confirmed(confirmed_duration_hours, dialog)
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	_add_overlay(dialog)


func _on_explore_confirmed(duration_hours: int, dialog: Node) -> void:
	if dialog != null:
		dialog.queue_free()
	if cat_id == "":
		return
	if ExploreEngine.dispatch(cat_id, duration_hours):
		var remaining := ExploreEngine.get_remaining_seconds(cat_id)
		if EventBus:
			EventBus.emit_explore_dispatched(cat_id, Time.get_unix_time_from_system() + remaining)
		_show_feedback("🧭 已出发探索")
		_check_explore_state()
		refresh_interaction_buttons()
	else:
		_show_feedback("探索名额已满")


func _collect_explore_return() -> void:
	var entry := ExploreEngine.collect(cat_id)
	if entry.is_empty():
		return
	var reward_type := ExploreEngine._roll_reward_type(cat_id)
	if EventBus:
		EventBus.emit_explore_returned(cat_id, reward_type)
		if reward_type == "postcard":
			EventBus.emit_postcard_obtained("pc_%s_%d" % [cat_id, Time.get_unix_time_from_system()], "city")
	_show_return_animation(reward_type)
	_show_feedback("探索奖励已领取")
	_check_explore_state()
	refresh_interaction_buttons()


func _show_return_animation(reward_type: String) -> void:
	var packed := load("res://scenes/ui/explore_return_animation.tscn")
	var animation = packed.instantiate()
	animation.finished.connect(func() -> void:
		animation.queue_free()
		_show_postcard_reveal(reward_type)
	)
	_add_overlay(animation)
	animation.play(_get_cat_display_name(), reward_type)


func _show_postcard_reveal(reward_type: String) -> void:
	var packed := load("res://scenes/ui/postcard_reveal.tscn")
	var reveal = packed.instantiate()
	reveal.closed.connect(func() -> void:
		reveal.queue_free()
	)
	_add_overlay(reveal)
	reveal.reveal(_get_cat_display_name(), reward_type)


func _add_overlay(node: Control) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(node)


func _has_explore_slot_available() -> bool:
	var available := 0
	for i in range(ExploreEngine.get_slot_count()):
		if ExploreEngine.is_slot_available(i):
			available += 1
	return ExploreEngine.get_exploring_count() < available


func _get_cat_display_name() -> String:
	var local_name := _get_cat_property("display_name", _get_cat_property("name", "猫咪"))
	if local_name != "猫咪" or cat_id == "":
		return local_name
	if HatchEngine:
		for cat in HatchEngine.get_cats():
			var found_id := ""
			var found_name := ""
			if cat is Dictionary:
				found_id = String(cat.get("id", ""))
				found_name = String(cat.get("display_name", cat.get("name", "猫咪")))
			else:
				found_id = String(cat.get("id"))
				found_name = String(cat.get("display_name")) if cat.get("display_name") != null else String(cat.get("name"))
			if found_id == cat_id and found_name != "":
				return found_name
	return local_name


func _format_duration(total_seconds: int) -> String:
	var seconds: int = maxi(total_seconds, 0)
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	var secs: int = seconds % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]


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
	_style_button(_explore_button)
	if _relinquish_button:
		_style_button(_relinquish_button)


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


func _get_full_cat_data() -> Dictionary:
	if cat_data is Dictionary:
		return cat_data.duplicate(true)
	if cat_data != null and cat_data.has_method("serialize"):
		return CatData.serialize(cat_data)
	return {
		"id": cat_id,
		"species": _get_cat_property("species", "orange"),
		"rarity": _get_cat_property("rarity", "common"),
		"level": int(_get_cat_property("level", "1")),
		"friendship": int(_get_cat_property("friendship", "0")),
	}


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
