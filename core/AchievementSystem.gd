# AchievementSystem — 成就系统 (Autoload)
# 不要加 class_name，autoload 注册已提供全局名称
extends Node

signal achievement_unlocked(id: String, reward: Dictionary)

# ── 20 achievements (GDD v2.13 §10) ──
const ACHIEVEMENTS: Array[Dictionary] = [
	# A: Step milestones (§10.1)
	{id = "A1", name = "迈出第一步", category = "steps", type = "steps_total", target = 1000, reward = {gold_coins = 100}},
	{id = "A2", name = "日行千里", category = "steps", type = "steps_total", target = 10000, reward = {gold_coins = 200}},
	{id = "A3", name = "马拉松选手", category = "steps", type = "steps_total", target = 42195, reward = {diamonds = 30}},
	{id = "A4", name = "万里长征", category = "steps", type = "steps_total", target = 100000, reward = {diamonds = 50}},
	{id = "A5", name = "登顶珠峰", category = "steps", type = "steps_total", target = 1000000, reward = {diamonds = 100, title = "行者"}},
	{id = "A6", name = "永不停歇", category = "steps", type = "steps_streak", target = 7, reward = {diamonds = 50, makeup_card = 1}},
	# B: Collection (§10.2)
	{id = "B1", name = "猫奴入门", category = "collection", type = "hatch_count", target = 1, reward = {gold_coins = 200}},
	{id = "B2", name = "图鉴起步", category = "collection", type = "hatch_count", target = 4, reward = {diamonds = 30}},
	{id = "B3", name = "猫咪旅馆", category = "collection", type = "album_entries", target = 8, reward = {diamonds = 50, treasure_box = 1}},
	{id = "B4", name = "动物园园长", category = "collection", type = "album_entries", target = 12, reward = {diamonds = 100, title = "猫图鉴大师"}},
	{id = "B5", name = "全家福", category = "collection", type = "breeds_all", target = 3, reward = {diamonds = 80, garden_decor = 1}},
	# C: Growth (§10.3)
	{id = "C1", name = "成长快乐", category = "growth", type = "cat_level", target = 3, reward = {gold_coins = 300}},
	{id = "C2", name = "完美搭档", category = "growth", type = "cat_level", target = 10, reward = {diamonds = 50, hatch_accelerator = 1}},
	{id = "C3", name = "好感大师", category = "growth", type = "affection", target = 25, reward = {cat_collar = 1}},
	# E: Postcards (§10.4)
	{id = "E1", name = "第一张明信片", category = "postcards", type = "postcards", target = 1, reward = {gold_coins = 100}},
	{id = "E2", name = "城市探索者", category = "postcards", type = "postcards", target = 10, reward = {diamonds = 30}},
	{id = "E3", name = "见过世面的猫", category = "postcards", type = "postcards", target = 20, reward = {diamonds = 50, album_cover = 1}},
	{id = "E4", name = "城市说书人", category = "postcards", type = "city_postcards", target = 30, reward = {diamonds = 100, title = "城市行者"}},
	# D: Easter eggs (§10.5)
	{id = "D1", name = "午夜猫语", category = "easter_egg", type = "midnight", target = 1, reward = {diamonds = 20, hidden_diary = 1}},
	{id = "D2", name = "雨天的访客", category = "easter_egg", type = "friend_streak", target = 7, reward = {hidden_diary_5 = 1}},
]

# ── Instance state ──
var _unlocked: Dictionary = {}
var _progress: Dictionary = {}
var _hatch_count: int = 0
var _album_entry_count: int = 0
var _collected_breeds: Array = []
var _postcard_count: int = 0
var _city_postcard_count: int = 0
var _collected_city_postcards: Dictionary = {}
var _max_level: int = 0
var _max_affection: int = 0
var _total_steps: int = 0

# A6: daily step streak
var _step_streak: int = 0
var _step_streak_checked_today: String = ""
var _daily_step_accumulator: int = 0

# D2: per-cat daily interaction streak
var _cat_streak: Dictionary = {}
var _cat_streak_checked_today: String = ""

# D1: midnight flag
var _midnight_accessed: bool = false

# Achievement unlock banner queue. Only two banners are shown during one app session.
const MAX_ACHIEVEMENT_POPUPS_PER_SESSION := 2
var _achievement_popup_queue: Array[Dictionary] = []
var _achievement_popup_active: bool = false
var _achievement_popups_shown: int = 0


func _ready() -> void:
	_step_streak_checked_today = _today_key()
	_cat_streak_checked_today = _today_key()

	if StepEngine and not StepEngine.steps_updated.is_connected(_on_steps_updated):
		StepEngine.steps_updated.connect(_on_steps_updated)
	if HatchEngine and not HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
		HatchEngine.hatch_complete.connect(_on_hatch_complete)
	if EventBus and not EventBus.level_up.is_connected(_on_level_up):
		EventBus.level_up.connect(_on_level_up)
	if EventBus and not EventBus.postcard_obtained.is_connected(_on_postcard_obtained):
		EventBus.postcard_obtained.connect(_on_postcard_obtained)
	if EventBus and not EventBus.cat_interacted.is_connected(_on_cat_interacted):
		EventBus.cat_interacted.connect(_on_cat_interacted)

	var now := Time.get_datetime_dict_from_system()
	_check_midnight_access(int(now.get("hour", 0)), int(now.get("minute", 0)))


# ── Public query ──

func is_unlocked(id: String) -> bool:
	return _unlocked.get(id, false)


func get_progress(id: String) -> float:
	var def_dict := _find_def(id)
	if def_dict.is_empty():
		return 0.0
	var type: String = String(def_dict.get("type", ""))
	var target: float = float(def_dict.get("target", 1))
	if target <= 0.0:
		return 1.0 if _unlocked.get(id, false) else 0.0
	match type:
		"steps_total":
			return clamp(float(_total_steps) / target, 0.0, 1.0)
		"steps_streak":
			return clamp(float(_step_streak) / target, 0.0, 1.0)
		"hatch_count":
			return clamp(float(_hatch_count) / target, 0.0, 1.0)
		"album_entries":
			return clamp(float(_album_entry_count) / target, 0.0, 1.0)
		"breeds_all":
			return clamp(float(_collected_breeds.size()) / target, 0.0, 1.0)
		"cat_level":
			return clamp(float(_max_level) / target, 0.0, 1.0)
		"affection":
			return clamp(float(_max_affection) / target, 0.0, 1.0)
		"postcards":
			return clamp(float(_postcard_count) / target, 0.0, 1.0)
		"city_postcards":
			return clamp(float(_city_postcard_count) / target, 0.0, 1.0)
		"midnight":
			return 1.0 if _midnight_accessed or _unlocked.get(id, false) else 0.0
		"friend_streak":
			var best := 0
			for cat_id in _cat_streak:
				best = max(best, int(_cat_streak[cat_id]))
			return clamp(float(best) / target, 0.0, 1.0)
	return 0.0


func get_current_value(id: String) -> float:
	var def_dict := _find_def(id)
	if def_dict.is_empty():
		return 0.0
	var type: String = String(def_dict.get("type", ""))
	match type:
		"steps_total": return float(_total_steps)
		"steps_streak": return float(_step_streak)
		"hatch_count": return float(_hatch_count)
		"album_entries": return float(_album_entry_count)
		"breeds_all": return float(_collected_breeds.size())
		"cat_level": return float(_max_level)
		"affection": return float(_max_affection)
		"postcards": return float(_postcard_count)
		"city_postcards": return float(_city_postcard_count)
		"midnight": return 1.0 if _midnight_accessed else 0.0
		"friend_streak": return float(_cat_streak.size())
	return 0.0


func get_unlocked_count() -> int:
	return _unlocked.size()


func get_total_count() -> int:
	return ACHIEVEMENTS.size()


func get_definitions() -> Array:
	return ACHIEVEMENTS.duplicate(true)


# ── Save/Load ──

func get_save_data() -> Dictionary:
	return {
		"unlocked": _unlocked.keys(),
		"hatch_count": _hatch_count,
		"album_entry_count": _album_entry_count,
		"collected_breeds": _collected_breeds.duplicate(),
		"postcard_count": _postcard_count,
		"city_postcard_count": _city_postcard_count,
		"collected_city_postcards": _collected_city_postcards.keys(),
		"max_level": _max_level,
		"max_affection": _max_affection,
		"total_steps": _total_steps,
		"step_streak": _step_streak,
		"daily_step_accumulator": _daily_step_accumulator,
		"step_streak_checked_today": _step_streak_checked_today,
		"cat_streak": _cat_streak.duplicate(),
		"cat_streak_checked_today": _cat_streak_checked_today,
		"midnight_accessed": _midnight_accessed,
	}


func apply_save(data: Dictionary) -> void:
	_unlocked = {}
	for k in Array(data.get("unlocked", [])):
		_unlocked[String(k)] = true
	_hatch_count = max(int(data.get("hatch_count", 0)), 0)
	_album_entry_count = max(int(data.get("album_entry_count", 0)), 0)
	_collected_breeds = []
	for b in Array(data.get("collected_breeds", [])):
		_collected_breeds.append(String(b))
	_postcard_count = max(int(data.get("postcard_count", 0)), 0)
	_city_postcard_count = max(int(data.get("city_postcard_count", 0)), 0)
	_collected_city_postcards = {}
	for postcard_id in Array(data.get("collected_city_postcards", [])):
		_collected_city_postcards[String(postcard_id)] = true
	_city_postcard_count = max(_city_postcard_count, _collected_city_postcards.size())
	_max_level = max(int(data.get("max_level", 0)), 0)
	_max_affection = max(int(data.get("max_affection", 0)), 0)
	_total_steps = max(int(data.get("total_steps", 0)), 0)
	_step_streak = max(int(data.get("step_streak", 0)), 0)
	_daily_step_accumulator = max(int(data.get("daily_step_accumulator", 0)), 0)
	_step_streak_checked_today = String(data.get("step_streak_checked_today", ""))
	_cat_streak = {}
	for k in Dictionary(data.get("cat_streak", {})):
		_cat_streak[String(k)] = max(int(data["cat_streak"][k]), 0)
	_cat_streak_checked_today = String(data.get("cat_streak_checked_today", ""))
	_midnight_accessed = bool(data.get("midnight_accessed", false))

	# 加载时仅恢复解锁状态，不重新发奖（防止schema迁移/存档兼容性导致重复发奖）
	for def_dict in ACHIEVEMENTS:
		_check_def(def_dict, true)


func reset_all() -> void:
	_unlocked = {}
	_progress = {}
	_hatch_count = 0
	_album_entry_count = 0
	_collected_breeds = []
	_postcard_count = 0
	_city_postcard_count = 0
	_collected_city_postcards = {}
	_max_level = 0
	_max_affection = 0
	_total_steps = 0
	_step_streak = 0
	_daily_step_accumulator = 0
	_step_streak_checked_today = ""
	_cat_streak = {}
	_cat_streak_checked_today = ""
	_midnight_accessed = false


# ── Signal handlers ──

func _on_steps_updated(_delta: int, total: int) -> void:
	_total_steps = max(_total_steps, total)

	var today := _today_key()
	var today_steps := 0
	if StepEngine and StepEngine.has_method("get_today_steps"):
		today_steps = StepEngine.get_today_steps()

	if today != _step_streak_checked_today:
		# Day changed: evaluate previous day's steps for A6 streak
		_record_daily_step_met(_daily_step_accumulator)
		_daily_step_accumulator = today_steps
		_step_streak_checked_today = today
	else:
		# Same day: track today's max steps
		_daily_step_accumulator = max(_daily_step_accumulator, today_steps)

	_check_step_achievements()


func _on_hatch_complete(cat) -> void:
	_hatch_count += 1
	if cat != null:
		var breed := ""
		if "species" in cat:
			breed = String(cat.species)
		elif "breed" in cat:
			breed = String(cat.breed)
		if breed != "":
			_register_breed_collected(breed)

	for def_dict in ACHIEVEMENTS:
		var t: String = String(def_dict.get("type", ""))
		if t in ["hatch_count", "breeds_all"]:
			_check_def(def_dict)


func _on_level_up(_cat_id: String, _from_level: int, to_level: int) -> void:
	_max_level = max(_max_level, to_level)
	for def_dict in ACHIEVEMENTS:
		if String(def_dict.get("type", "")) == "cat_level":
			_check_def(def_dict)


func _on_postcard_obtained(postcard_id: String, location_type: String) -> void:
	_postcard_count += 1
	if _is_city_postcard(postcard_id, location_type) and not _collected_city_postcards.has(postcard_id):
		_collected_city_postcards[postcard_id] = true
		_city_postcard_count = _collected_city_postcards.size()
	for def_dict in ACHIEVEMENTS:
		if String(def_dict.get("type", "")) in ["postcards", "city_postcards"]:
			_check_def(def_dict)


func _on_friendship_changed(_cat_id: String, friendship: int) -> void:
	_max_affection = max(_max_affection, friendship)
	for def_dict in ACHIEVEMENTS:
		if String(def_dict.get("type", "")) == "affection":
			_check_def(def_dict)


func _on_cat_interacted(cat_id: String, _interaction_type: String) -> void:
	# D2: record daily interaction for friend_streak achievement
	_record_daily_interaction(cat_id, 1)
	# Bridge to friendship check via InteractionSystem
	if InteractionSystem:
		var affection: int = InteractionSystem.get_affection(cat_id)
		_on_friendship_changed(cat_id, affection)


# ── Achievement evaluation ──

func _check_step_achievements() -> void:
	for def_dict in ACHIEVEMENTS:
		var t: String = String(def_dict.get("type", ""))
		if t in ["steps_total", "steps_streak"]:
			_check_def(def_dict)


func _check_def(def_dict: Dictionary, skip_reward := false) -> void:
	var id: String = String(def_dict.get("id", ""))
	if id == "" or _unlocked.get(id, false):
		return
	var type: String = String(def_dict.get("type", ""))
	var target: int = int(def_dict.get("target", 0))
	var met := false
	match type:
		"steps_total":
			met = _total_steps >= target
		"steps_streak":
			met = _step_streak >= target
		"hatch_count":
			met = _hatch_count >= target
		"album_entries":
			met = _album_entry_count >= target
		"breeds_all":
			met = _collected_breeds.size() >= target
		"cat_level":
			met = _max_level >= target
		"affection":
			met = _max_affection >= target
		"postcards":
			met = _postcard_count >= target
		"city_postcards":
			met = _city_postcard_count >= target
		"midnight":
			met = _midnight_accessed
		"friend_streak":
			for cat_id in _cat_streak:
				if int(_cat_streak[cat_id]) >= target:
					met = true
					break
	if met:
		_try_unlock(id, skip_reward)


func _try_unlock(id: String, skip_reward := false) -> void:
	if _unlocked.get(id, false):
		return
	_unlocked[id] = true
	_progress[id] = 1.0

	if skip_reward:
		return

	var def_dict := _find_def(id)
	if def_dict.is_empty():
		return

	var reward: Dictionary = Dictionary(def_dict.get("reward", {}))
	if reward.has("gold_coins"):
		var amount: int = int(reward.get("gold_coins", 0))
		if amount > 0 and CurrencyManager:
			CurrencyManager.add_gold(amount, "achievement:" + id)
	if reward.has("diamonds"):
		var amount: int = int(reward.get("diamonds", 0))
		if amount > 0 and CurrencyManager:
			CurrencyManager.add_diamonds(amount, "achievement:" + id)

	achievement_unlocked.emit(id, reward)
	if EventBus:
		EventBus.emit_achievement_unlocked(id, reward)
	show_achievement_unlock(id, reward)

func _update_progress(id: String, current: float) -> void:
	var def_dict := _find_def(id)
	if def_dict.is_empty():
		return
	var target: float = float(def_dict.get("target", 1))
	if target <= 0.0:
		_progress[id] = 1.0
	else:
		_progress[id] = clamp(current / target, 0.0, 1.0)


# ── External hooks (called by other systems) ──

func notify_album_entry() -> void:
	_album_entry_count += 1
	_check_collection_achievements()
	_save()


func notify_city_postcard() -> void:
	_city_postcard_count += 1
	_check_collection_achievements()
	_save()


func _check_collection_achievements() -> void:
	_check_achievement("B3")
	_check_achievement("B4")


func _check_achievement(id: String) -> void:
	var def_dict := _find_def(id)
	if not def_dict.is_empty():
		_check_def(def_dict)


func _save() -> void:
	if SaveManager:
		SaveManager.save_all()


func _register_breed_collected(breed: String) -> void:
	if breed == "":
		return
	if not _collected_breeds.has(breed):
		_collected_breeds.append(breed)
	for def_dict in ACHIEVEMENTS:
		if String(def_dict.get("type", "")) == "breeds_all":
			_check_def(def_dict)


func _record_daily_step_met(steps: int) -> void:
	if steps >= 3000:
		_step_streak += 1
	else:
		_step_streak = 0
	for def_dict in ACHIEVEMENTS:
		if String(def_dict.get("type", "")) == "steps_streak":
			_check_def(def_dict)


func _record_daily_interaction(cat_id: String, count: int) -> void:
	if cat_id == "":
		return
	if count >= 3:
		if not _cat_streak.has(cat_id):
			_cat_streak[cat_id] = 0
		_cat_streak[cat_id] = int(_cat_streak[cat_id]) + 1
	else:
		_cat_streak[cat_id] = 0
	for def_dict in ACHIEVEMENTS:
		if String(def_dict.get("type", "")) == "friend_streak":
			_check_def(def_dict)


func _check_midnight_access(hour: int, _minute: int) -> void:
	if hour >= 0 and hour < 6:
		_midnight_accessed = true
		for def_dict in ACHIEVEMENTS:
			if String(def_dict.get("type", "")) == "midnight":
				_check_def(def_dict)


# ── Helpers ──

func _find_def(id: String) -> Dictionary:
	for def_dict in ACHIEVEMENTS:
		if String(def_dict.get("id", "")) == id:
			return def_dict
	return {}


func _is_city_postcard(postcard_id: String, location_type: String) -> bool:
	# "city" is retained for compatibility with older callers and save migrations.
	if location_type == "city":
		return true
	return postcard_id in PostcardData.get_city_postcard_ids()


func show_achievement_unlock(achievement_id: String, reward: Dictionary) -> void:
	_achievement_popup_queue.append({
		"id": achievement_id,
		"reward": reward.duplicate(true),
	})
	_try_show_next_achievement_popup()


func _try_show_next_achievement_popup() -> void:
	if _achievement_popup_active:
		return
	if _achievement_popups_shown >= MAX_ACHIEVEMENT_POPUPS_PER_SESSION:
		return
	if _achievement_popup_queue.is_empty() or not is_inside_tree():
		return

	var popup_data: Dictionary = _achievement_popup_queue.pop_front()
	var achievement_id := String(popup_data.get("id", ""))
	var reward := Dictionary(popup_data.get("reward", {}))
	var definition := _find_def(achievement_id)
	var achievement_name := String(definition.get("name", achievement_id))

	var layer := CanvasLayer.new()
	layer.name = "AchievementUnlockLayer"
	layer.layer = 100
	add_child(layer)

	var banner := PanelContainer.new()
	banner.name = "AchievementUnlockBanner"
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -310.0
	banner.offset_right = 310.0
	banner.offset_top = -120.0
	banner.offset_bottom = -8.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.98, 0.94, 0.84, 0.98)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.shadow_color = Color(0.15, 0.1, 0.05, 0.24)
	panel_style.shadow_size = 12
	banner.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(banner)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	banner.add_child(margin)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var ach_category := String(definition.get("category", ""))
	var icon_path := "res://assets/art/delivery/achievement/ach_icon_%s.png" % {
		"steps": "steps", "collection": "collection", "growth": "growth",
		"postcards": "postcard", "easter_egg": "easter",
	}.get(ach_category, "steps")
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64.0, 64.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		icon.modulate = Color(0.88, 0.65, 0.28, 1.0)
	content.add_child(icon)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(copy)

	var title := Label.new()
	title.text = "成就解锁 · " + achievement_name
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.28, 0.22, 0.17, 1.0))
	copy.add_child(title)

	var reward_label := Label.new()
	reward_label.text = _format_reward_text(reward)
	reward_label.add_theme_font_size_override("font_size", 15)
	reward_label.add_theme_color_override("font_color", Color(0.48, 0.38, 0.27, 1.0))
	copy.add_child(reward_label)

	var confirm := Button.new()
	confirm.text = "知道了"
	confirm.custom_minimum_size = Vector2(88.0, 44.0)
	confirm.focus_mode = Control.FOCUS_NONE
	content.add_child(confirm)

	var auto_dismiss := Timer.new()
	auto_dismiss.one_shot = true
	auto_dismiss.wait_time = 5.0
	layer.add_child(auto_dismiss)
	confirm.pressed.connect(_dismiss_achievement_popup.bind(layer, banner))
	auto_dismiss.timeout.connect(_dismiss_achievement_popup.bind(layer, banner))

	_achievement_popup_active = true
	_achievement_popups_shown += 1
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "offset_top", 24.0, 0.4)
	tween.tween_property(banner, "offset_bottom", 136.0, 0.4)
	auto_dismiss.start()


func _dismiss_achievement_popup(layer: CanvasLayer, banner: PanelContainer) -> void:
	if not is_instance_valid(layer) or layer.has_meta("dismissing"):
		return
	layer.set_meta("dismissing", true)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(banner, "offset_top", -12.0, 0.15)
	tween.tween_property(banner, "offset_bottom", 100.0, 0.15)
	tween.tween_property(banner, "modulate:a", 0.0, 0.15)
	tween.set_parallel(false)
	tween.tween_callback(_finish_achievement_popup.bind(layer))


func _finish_achievement_popup(layer: CanvasLayer) -> void:
	if is_instance_valid(layer):
		layer.queue_free()
	_achievement_popup_active = false
	_try_show_next_achievement_popup()


func _format_reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	var labels := {
		"gold_coins": "金币",
		"diamonds": "钻石",
		"title": "称号",
		"treasure_box": "宝箱",
		"makeup_card": "补签卡",
		"garden_decor": "花园装饰",
		"hatch_accelerator": "孵化加速器",
		"cat_collar": "猫项圈",
		"album_cover": "图鉴封面",
		"hidden_diary": "隐藏日记",
		"hidden_diary_5": "隐藏日记",
	}
	for key in reward:
		var label := String(labels.get(key, key))
		var value: Variant = reward[key]
		parts.append("%s %s" % [label, str(value)])
	return "奖励：" + "、".join(parts) if not parts.is_empty() else "奖励已领取"


func _today_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]

# ── Test helpers ──
func check(id: String) -> void:
	var def_dict := _find_def(id)
	if not def_dict.is_empty():
		_check_def(def_dict)

func _override_total_steps(n: int) -> void:
	_total_steps = n

func _override_hatch_count(n: int) -> void:
	_hatch_count = n

func _override_cat_level(_cat_id: String, level: int) -> void:
	_max_level = max(_max_level, level)

func _override_affection(_cat_id: String, val: int) -> void:
	_max_affection = max(_max_affection, val)

func _unlock_breed(name: String) -> void:
	_register_breed_collected(name)

func get_reward(id: String) -> Dictionary:
	var def_dict := _find_def(id)
	return def_dict.get("reward", {})
