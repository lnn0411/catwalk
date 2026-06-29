extends Control

const DESIGN_SIZE := Vector2(720.0, 1280.0)
# 卡片底图与按钮态已由 库洛洛 美术资源（TextureRect/TextureButton）提供，
# 不再用代码描边；仅保留禁用态的整体变暗系数。
const DISABLED_ALPHA := 0.4
const CatData := preload("res://core/CatData.gd")
const AD_REFRESH_CFG := "user://ad_refresh.cfg"
const AD_REFRESH_SECTION := "ad_refresh"
const AD_REFRESH_MAX := 2
# 立绘动画帧率（8 帧/动作）
const ANIM_FPS := 4.0

var cat_id: String = ""
var cat_data
var interaction_system

# 卡片底图改为 TextureRect（库洛洛 美术资源），动画仍以此节点为缩放/淡入对象
@onready var _card_background: Control = %CardTexture
@onready var _name_label: Label = %CatName
@onready var _meta_label: Label = %BreedRarityLabel
# 互动按钮全部换成 TextureButton；TextureButton 与 Button 同为 BaseButton 子类但互不继承，
# 故类型标注用具体 TextureButton，公共辅助函数参数改用 BaseButton。
@onready var _feed_button: TextureButton = %FeedButton
@onready var _pet_button: TextureButton = %PetButton
@onready var _play_button: TextureButton = %PlayButton
@onready var _explore_button: TextureButton = %ExploreButton
@onready var _relinquish_button: TextureButton = %RelinquishButton
@onready var _explore_state_panel: Control = %ExploreStatePanel
@onready var _exploring_label: Label = %ExploringLabel
@onready var _countdown_label: Label = %CountdownLabel
@onready var _return_time_label: Label = %ReturnTimeLabel
@onready var _status_label: Label = %StatusLabel
# 猫咪展示改为 AnimatedSprite2D（按品种逐帧动画）
@onready var _cat_display: AnimatedSprite2D = %CatDisplay
@onready var _ad_refresh_btn: TextureButton = %AdRefreshBtn
# TextureButton 没有 text 属性，动态文案改写其 Label 子节点
@onready var _explore_label: Label = %ExploreLabel
@onready var _ad_refresh_label: Label = %AdRefreshLabel
@onready var _relinquish_label: Label = %RelinquishLabel

var _cooldown_timer: Timer
var _explore_countdown_timer: Timer
var _is_exploring_this_cat := false
var _screen_pos := Vector2.ZERO
var _closing := false
var _feedback_until := 0.0
# 每个立绘目录(british/siamese) 对应一份 SpriteFrames，按需构建并缓存
var _frames_cache: Dictionary = {}
var _close_playing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 主题样式已由 TextureButton/卡片底图替代，无需再做代码描边
	_setup_cooldown_timer()
	_setup_explore_countdown_timer()
	_setup_anim_timer()
	_setup_sleep_anim_timer()
	_connect_button_feedback(_feed_button)
	_connect_button_feedback(_pet_button)
	_connect_button_feedback(_play_button)
	_connect_button_feedback(_explore_button)
	_connect_button_feedback(_ad_refresh_btn)
	_connect_button_feedback(_relinquish_button)
	_resolve_interaction_system()
	_refresh_cat_info()
	_check_explore_state()
	refresh_interaction_buttons()
	_update_ad_refresh_button()
	# 遮罩点击关闭
	var overlay := get_node_or_null("Overlay") as ColorRect
	if overlay:
		overlay.gui_input.connect(_on_overlay_clicked)
	_play_open_animation()


func setup(c_id: String, c_data, screen_pos: Vector2) -> void:
	cat_id = c_id
	cat_data = c_data
	_screen_pos = screen_pos
	_resolve_interaction_system()
	_refresh_cat_info()
	_check_explore_state()
	refresh_interaction_buttons()
	_update_ad_refresh_button()
	_load_cat_frames()


func refresh_interaction_buttons() -> void:
	if not is_inside_tree():
		return
	_update_ad_refresh_button()
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
		# 切换到睡觉动画
		if _cat_display and _cat_display.animation != "sleep":
			_play_breed_animation("sleep")

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

	# ── 调试日志：按钮状态/冷却/情绪/探索 ──
	var emotion_str = "n/a"
	if cat_id != "" and get_node_or_null("/root/EmotionStateMachine") != null:
		emotion_str = String(EmotionStateMachine.get_emotion(cat_id))
	var explore_disp = "n/a"
	if _explore_button != null:
		explore_disp = str(_explore_button.disabled)
	print("[CatCard] refresh_interaction_buttons cat_id=%s" % cat_id)
	print("[CatCard]   disabled: feed=%s pet=%s play=%s explore=%s" % [
		_feed_button.disabled, _pet_button.disabled, _play_button.disabled, explore_disp])
	print("[CatCard]   cooldown(s): feed=%.1f pet=%.1f play=%.1f" % [
		_get_cooldown_remaining("feed"), _get_cooldown_remaining("pet"), _get_cooldown_remaining("play")])
	print("[CatCard]   blocked: feed=%s pet=%s play=%s" % [
		_is_interaction_blocked("feed"), _is_interaction_blocked("pet"), _is_interaction_blocked("play")])
	print("[CatCard]   emotion=%s annoyed=%s sleeping=%s" % [emotion_str, annoyed, sleeping])
	print("[CatCard]   explore: is_exploring_this_cat=%s any_cooldown=%s status='%s'" % [
		_is_exploring_this_cat, any_cooldown, status_text])

	# 送养按钮状态：最后一只或探索中禁用
	if _relinquish_button:
		var is_last := HatchEngine and HatchEngine.get_cats().size() <= 1
		var is_exploring := cat_id != "" and ExploreEngine and ExploreEngine.is_exploring(cat_id)
		_set_button_disabled(_relinquish_button, is_last or is_exploring)
		if _relinquish_label:
			_relinquish_label.text = "💕 送养" if not is_last else "最后一只"
	
	# 猫醒来时切回 idle 动画
	if not annoyed and not sleeping and _cat_display and _cat_display.animation == "sleep":
		_play_breed_animation("idle")


func _on_feed_pressed() -> void:
	print("[CatCard] _on_feed_pressed clicked cat_id=%s disabled=%s" % [cat_id, _feed_button.disabled])
	if _feed_button.disabled:
		print("[CatCard]   feed ignored: button disabled")
		return
	var cd_before = _get_cooldown_remaining("feed")
	var ok = _do_interaction("feed")
	var cd_after = _get_cooldown_remaining("feed")
	print("[CatCard]   feed _do_interaction success=%s cooldown before=%.1f after=%.1f" % [ok, cd_before, cd_after])
	_play_action_anim("eating")
	_show_feedback("🍖 喂食成功！")


func _on_pet_pressed() -> void:
	print("[CatCard] _on_pet_pressed clicked cat_id=%s disabled=%s" % [cat_id, _pet_button.disabled])
	if _pet_button.disabled:
		print("[CatCard]   pet ignored: button disabled")
		return
	var cd_before = _get_cooldown_remaining("pet")
	var ok = _do_interaction("pet")
	var cd_after = _get_cooldown_remaining("pet")
	print("[CatCard]   pet _do_interaction success=%s cooldown before=%.1f after=%.1f" % [ok, cd_before, cd_after])
	_play_action_anim("petting")
	_show_feedback("✋ 摸摸头~")


func _on_play_pressed() -> void:
	print("[CatCard] _on_play_pressed clicked cat_id=%s disabled=%s" % [cat_id, _play_button.disabled])
	if _play_button.disabled:
		print("[CatCard]   play ignored: button disabled")
		return
	var cd_before = _get_cooldown_remaining("play")
	var ok = _do_interaction("play")
	var cd_after = _get_cooldown_remaining("play")
	print("[CatCard]   play _do_interaction success=%s cooldown before=%.1f after=%.1f" % [ok, cd_before, cd_after])
	_play_action_anim("playing")
	_show_feedback("🎾 玩得好开心！")


# ── 看广告刷新冷却 ──
func _on_ad_refresh_pressed() -> void:
	if _ad_refresh_btn == null or _ad_refresh_btn.disabled:
		return
	if cat_id == "" and cat_data != null:
		cat_id = _get_cat_property("id", "")
	if cat_id == "":
		_show_feedback("暂时找不到这只猫")
		return
	var count := _get_ad_refresh_count()
	if count >= AD_REFRESH_MAX:
		_update_ad_refresh_button()
		return
	# 清除这只猫的全部冷却
	_resolve_interaction_system()
	if interaction_system != null and interaction_system.has_method("clear_cat_cooldowns"):
		interaction_system.clear_cat_cooldowns(cat_id)
	count += 1
	_save_ad_refresh_count(count)
	_update_ad_refresh_button()
	refresh_interaction_buttons()
	# 刷新后如果猫处于烦躁/睡觉状态，给出提示
	if _is_annoyed():
		_show_feedback("⚡ 冷却已刷新，但猫咪还在烦躁中…")
	elif _is_sleeping():
		_show_feedback("⚡ 冷却已刷新，但猫咪还在睡觉😴")


func _update_ad_refresh_button() -> void:
	if _ad_refresh_btn == null:
		return
	var count := _get_ad_refresh_count()
	if count >= AD_REFRESH_MAX:
		if _ad_refresh_label:
			_ad_refresh_label.text = "今日已用完(2/2)"
		_set_button_disabled(_ad_refresh_btn, true)
	else:
		if _ad_refresh_label:
			_ad_refresh_label.text = "⚡ 看广告刷新冷却 🎬"
		_set_button_disabled(_ad_refresh_btn, false)


func _ad_refresh_today_string() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(dt.get("year", 0)), int(dt.get("month", 0)), int(dt.get("day", 0))]


# 读取今天的刷新次数；存档日期非今天则视为 0（每日重置）
func _get_ad_refresh_count() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(AD_REFRESH_CFG) != OK:
		return 0
	var saved_date := String(cfg.get_value(AD_REFRESH_SECTION, "refresh_date", ""))
	if saved_date != _ad_refresh_today_string():
		return 0
	return int(cfg.get_value(AD_REFRESH_SECTION, "refresh_count", 0))


func _save_ad_refresh_count(count: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(AD_REFRESH_CFG)
	cfg.set_value(AD_REFRESH_SECTION, "refresh_count", count)
	cfg.set_value(AD_REFRESH_SECTION, "refresh_date", _ad_refresh_today_string())
	cfg.save(AD_REFRESH_CFG)


func _on_relinquish_pressed() -> void:
	var cid := _get_cat_property("id", "")
	if cid == "":
		return
	# 检查是否为最后一只猫
	if HatchEngine and HatchEngine.get_cats().size() <= 1:
		_show_feedback("至少要留一只猫陪着你哦～")
		return
	# 探索中不能送养
	if ExploreEngine and ExploreEngine.is_exploring(cid):
		_show_feedback("探索中，不能送养")
		return
	# 显示确认弹窗
	_show_relinquish_confirm_dialog()


func _show_relinquish_confirm_dialog() -> void:
	var packed := load("res://scenes/ui/relinquish_confirm_dialog.tscn")
	var dialog = packed.instantiate()
	var c_data := _get_full_cat_data()
	dialog.setup(c_data)
	dialog.confirmed.connect(func() -> void:
		_on_relinquish_confirmed(dialog)
	)
	dialog.canceled.connect(func() -> void:
		_close_overlay(dialog)
	)
	_add_overlay(dialog)


func _on_relinquish_confirmed(dialog: Node) -> void:
	_close_overlay(dialog)
	var cid := _get_cat_property("id", "")
	if cid == "":
		return
	var c_data := _get_full_cat_data()
	var event_id := "%s_rel_%d" % [cid, Time.get_unix_time_from_system()]
	var result = RelinquishSystem.relinquish_cat(c_data, event_id)
	if result.get("blocked", false):
		_show_feedback(result.get("reason", "送养失败"))
		return
	# 先移除猫咪，再发币（防止 remove 失败后金币已发出）
	if not HatchEngine.remove_cat(cid):
		_show_feedback("送养失败")
		return
	# 发放金币（RelinquishSystem 已发花瓣，金币由这里发）
	var gold: int = int(result.get("gold_coins", 0))
	if gold > 0 and CurrencyManager:
		CurrencyManager.add_gold(gold, "relinquish")
	# 存档
	if SaveManager:
		SaveManager.save_all()
	# 通知 EventBus
	if EventBus:
		EventBus.emit_relinquish_completed(cid, result.get("love_petals", 0), gold)
	_show_feedback("💕 %s 已找到新家" % _get_cat_display_name())
	_play_close_animation()

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
		if _explore_label:
			_explore_label.text = "🎁 领取" if ExploreEngine.is_returned(cat_id) else "🧭 探索中"
		_set_button_disabled(_explore_button, not ExploreEngine.is_returned(cat_id))
		return

	_explore_button.visible = true
	var has_explore_slot := _has_explore_slot_available()
	if _explore_label:
		_explore_label.text = "🧭 探索" if has_explore_slot else "探索名额已满"
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
		_close_overlay(picker)
	)
	_add_overlay(picker)


func _on_explore_duration_selected(duration_hours: int, picker: Node) -> void:
	_close_overlay(picker)
	var packed := load("res://scenes/ui/explore_confirm_dialog.tscn")
	var dialog = packed.instantiate()
	dialog.setup(_get_cat_display_name(), duration_hours)
	dialog.confirmed.connect(func(confirmed_duration_hours: int) -> void:
		_on_explore_confirmed(confirmed_duration_hours, dialog)
	)
	dialog.canceled.connect(func() -> void:
		_close_overlay(dialog)
	)
	_add_overlay(dialog)


func _on_explore_confirmed(duration_hours: int, dialog: Node) -> void:
	_close_overlay(dialog)
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
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(node)
	var root := get_tree().root
	if root != null:
		root.add_child(canvas)

# Close an overlay node and its CanvasLayer wrapper
func _close_overlay(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var p := node.get_parent()
	if p is CanvasLayer:
		p.queue_free()
	else:
		node.queue_free()


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


# ── 动画 ──
# 缩放/淡入轴心设在底部中点（半屏弹窗从底部生长）
func _apply_panel_pivot(panel: Control) -> void:
	if panel == null:
		return
	var psize := panel.size
	if psize == Vector2.ZERO:
		psize = Vector2(get_viewport_rect().size.x, 520.0)
	panel.pivot_offset = Vector2(psize.x * 0.5, psize.y)


# 错峰进场：遮罩先淡入（0.05s 延迟），卡片随后缩放(0.8→1.0)+淡入
func _play_open_animation() -> void:
	modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE
	var overlay := get_node_or_null("Overlay") as ColorRect
	var panel := _card_background
	_apply_panel_pivot(panel)
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0

	if overlay:
		overlay.modulate.a = 0.0
		var overlay_tween := create_tween()
		overlay_tween.set_trans(Tween.TRANS_SINE)
		overlay_tween.set_ease(Tween.EASE_OUT)
		overlay_tween.tween_interval(0.05)
		overlay_tween.tween_property(overlay, "modulate:a", 1.0, 0.2)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	# 弹窗内飘爱心
	_show_card_heart()


func _show_card_heart() -> void:
	var heart := Label.new()
	heart.text = "♥"
	heart.add_theme_font_size_override("font_size", 36)
	heart.add_theme_color_override("font_color", Color("#D98E8E"))
	heart.position = Vector2(340, 100)
	heart.z_index = 100
	add_child(heart)
	var ht := create_tween()
	ht.set_parallel(true)
	ht.tween_property(heart, "position:y", heart.position.y - 60.0, 0.8).set_ease(Tween.EASE_OUT)
	ht.tween_property(heart, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	ht.tween_callback(heart.queue_free)


func _play_close_animation() -> void:
	if _close_playing:
		return
	_close_playing = true
	var overlay := get_node_or_null("Overlay") as ColorRect
	var panel := _card_background
	_apply_panel_pivot(panel)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.15)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	if overlay:
		tween.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(_on_close_anim_done)


func _on_close_anim_done() -> void:
	if interaction_system and interaction_system.has_method("_close_cat_card"):
		interaction_system._close_cat_card()
	else:
		queue_free()


# 详情链接：关闭卡片并跳转到图鉴/详情页
func _on_detail_link_pressed() -> void:
	if interaction_system and interaction_system.has_method("_close_cat_card"):
		interaction_system._close_cat_card()
	else:
		_play_close_animation()
	if UIManager and UIManager.has_method("push"):
		UIManager.push("res://ui/pages/S10_CatDetail.tscn", {"cat": _get_full_cat_data()})


func _on_companion_pressed() -> void:
	if cat_id.is_empty():
		return
	if HatchEngine:
		HatchEngine.set_companion_cat_id(cat_id)
		_show_feedback("已设为随行猫 🐾")
		if SaveManager:
			SaveManager.save_all()


# 按钮按压缩放反馈：按下缩到 0.95，松开弹回 1.0
func _connect_button_feedback(button: BaseButton) -> void:
	if button == null:
		return
	button.button_down.connect(func() -> void: _on_button_down(button))
	button.button_up.connect(func() -> void: _on_button_up(button))


func _on_button_down(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05)


func _on_button_up(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.1)


func _setup_cooldown_timer() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.name = "CooldownTimer"
	_cooldown_timer.wait_time = 1.0
	_cooldown_timer.one_shot = false
	_cooldown_timer.timeout.connect(refresh_interaction_buttons)
	add_child(_cooldown_timer)


var _sleep_anim_timer: Timer
func _setup_sleep_anim_timer() -> void:
	_sleep_anim_timer = Timer.new()
	_sleep_anim_timer.name = "SleepAnimTimer"
	_sleep_anim_timer.wait_time = 0.5
	_sleep_anim_timer.one_shot = false
	_sleep_anim_timer.timeout.connect(_on_sleep_anim_check)
	add_child(_sleep_anim_timer)
	_sleep_anim_timer.start()

func _on_sleep_anim_check() -> void:
	if _cat_display == null:
		return
	var sleeping := _is_sleeping()
	if sleeping and _cat_display.animation != "sleep":
		_play_breed_animation("sleep")
	elif not sleeping and _cat_display.animation == "sleep":
		_play_breed_animation("idle")


func _refresh_cat_info() -> void:
	if not is_inside_tree():
		return
	_name_label.text = _get_cat_property("display_name", _get_cat_property("name", "猫咪"))
	var species := _get_cat_property("species", _get_cat_property("breed", "orange"))
	var rarity := _get_cat_property("rarity", "common")
	_meta_label.text = "%s · %s" % [_species_label(species), _rarity_label(rarity)]
	_load_cat_frames()


func _show_feedback(text: String) -> void:
	_feedback_until = Time.get_unix_time_from_system() + 1.2
	_status_label.text = text
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(refresh_interaction_buttons)


func _do_interaction(interaction_type: String) -> bool:
	_resolve_interaction_system()
	if interaction_system == null:
		print("[CatCard] _do_interaction(%s) ERROR: interaction_system is null" % interaction_type)
		return false
	if _call_interaction("do_interact", interaction_type, false):
		print("[CatCard] _do_interaction(%s) via do_interact -> success" % interaction_type)
		return true
	var ok = bool(_call_interaction("do_interact_global", interaction_type, false))
	print("[CatCard] _do_interaction(%s) via do_interact_global -> success=%s" % [interaction_type, ok])
	return ok


func _is_interaction_blocked(interaction_type: String) -> bool:
	_resolve_interaction_system()
	if interaction_system == null:
		return false
	# 按这只猫单独判定冷却（注意参数顺序：type, cat_id）
	if _has_interaction_method("is_interaction_blocked"):
		return bool(interaction_system.is_interaction_blocked(interaction_type, cat_id))
	if _has_interaction_method("can_interact"):
		return not bool(interaction_system.can_interact(cat_id, interaction_type))
	return false


func _get_cooldown_remaining(interaction_type: String) -> float:
	_resolve_interaction_system()
	if interaction_system == null:
		return 0.0
	# 优先使用按猫查询的接口
	if _has_interaction_method("cat_cooldown_remaining"):
		return float(interaction_system.cat_cooldown_remaining(cat_id, interaction_type))
	if _has_interaction_method("get_cooldown_remaining"):
		return float(interaction_system.get_cooldown_remaining(interaction_type))
	return 0.0


func _call_interaction(method_name: String, interaction_type: String, default_value):
	if interaction_system == null or not interaction_system.has_method(method_name):
		print("[CatCard] _call_interaction method=%s unavailable -> default=%s" % [method_name, str(default_value)])
		return default_value
	var arg_count := _get_method_arg_count(interaction_system, method_name)
	var result
	if arg_count <= 1:
		result = interaction_system.call(method_name, interaction_type)
	else:
		result = interaction_system.call(method_name, cat_id, interaction_type)
	print("[CatCard] _call_interaction method=%s(arg_count=%d) type=%s -> %s" % [method_name, arg_count, interaction_type, str(result)])
	return result


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
	var hour := int(CatSchedule._current_hour())
	var period: String = CatSchedule.get_period(hour)
	return String(CatSchedule.get_state(species, period)) == "sleep"


func _resolve_interaction_system() -> void:
	if interaction_system != null:
		return
	interaction_system = get_node_or_null("/root/InteractionSystem")


func _reset_button(button: BaseButton) -> void:
	button.disabled = false
	button.modulate.a = 1.0


func _set_button_disabled(button: BaseButton, disabled: bool) -> void:
	button.disabled = disabled
	button.modulate.a = DISABLED_ALPHA if disabled else 1.0


func _button_for_type(interaction_type: String) -> BaseButton:
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


# ── 猫咪展示（AnimatedSprite2D，按品种 8 帧/动作）──

# _ready 中调用：连接动作播放结束信号（动作放完一次自动回到 idle 循环）
func _setup_anim_timer() -> void:
	if _cat_display == null:
		return
	if not _cat_display.animation_finished.is_connected(_on_anim_finished):
		_cat_display.animation_finished.connect(_on_anim_finished)

func _on_anim_finished() -> void:
	# idle/sleep 为循环动画不会触发本信号；feed/pet/play 播完后回到当前状态
	_play_breed_animation("sleep" if _is_sleeping() else "idle")

func _current_breed() -> String:
	if cat_data == null:
		return "orange"
	if cat_data is Dictionary:
		return String(cat_data.get("species", cat_data.get("breed", "orange")))
	var value = cat_data.get("species")
	if value == null:
		value = cat_data.get("breed")
	return String(value) if value != null else "orange"

# 立绘目录
func _portrait_dir(breed: String) -> String:
	match breed:
		"siamese":
			return "siamese"
		"british", "british_shorthair":
			return "british"
		"orange":
			return "orange"
		_:
			return "british"

# 按品种构建 SpriteFrames（idle 循环，feed/pet/play 各播一次），并缓存
func _ensure_breed_frames(breed: String) -> SpriteFrames:
	var dir := _portrait_dir(breed)
	if _frames_cache.has(dir):
		return _frames_cache[dir]
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for action in ["idle", "feed", "pet", "play", "sleep"]:
		sf.add_animation(action)
		sf.set_animation_loop(action, action == "idle" or action == "sleep")
		sf.set_animation_speed(action, ANIM_FPS)
		for i in range(8):
			var p := "res://assets/art/cats/portraits/catcard/%s/catcard_%s_%s_frame_%02d.png" % [dir, dir, action, i]
			if ResourceLoader.exists(p):
				sf.add_frame(action, load(p))
	_frames_cache[dir] = sf
	return sf

func _play_breed_animation(action: String) -> void:
	if _cat_display == null:
		return
	var sf := _ensure_breed_frames(_current_breed())
	if sf == null:
		return
	var anim := action
	if not sf.has_animation(anim) or sf.get_frame_count(anim) == 0:
		anim = "idle"
	if _cat_display.sprite_frames != sf:
		_cat_display.sprite_frames = sf
	_cat_display.animation = anim
	_cat_display.frame = 0
	_cat_display.play(anim)

func _load_idle_frame() -> void:
	_play_breed_animation("idle")

func _load_cat_frames() -> void:
	if _cat_display == null:
		return
	_ensure_breed_frames(_current_breed())
	_play_breed_animation("sleep" if _is_sleeping() else "idle")

# _on_feed/pet/play_pressed 传入 eating/petting/playing，映射到立绘动作并播放一次
func _play_action_anim(action: String) -> void:
	var mapped := "idle"
	match action:
		"eating":
			mapped = "feed"
		"petting":
			mapped = "pet"
		"playing":
			mapped = "play"
	_play_breed_animation(mapped)

func _stop_action_anim() -> void:
	_play_breed_animation("idle")

# 遮罩点击关闭
func _on_overlay_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_play_close_animation()
