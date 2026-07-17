extends VBoxContainer
class_name AchievementTab

const ICON_DIR := "res://assets/art/delivery/achievement/"
const TEXT_PRIMARY := Color("#4F453C")
const TEXT_SECONDARY := Color("#A2978C")
const BG_BEIGE := Color(0.96, 0.94, 0.88, 0.5)
const BORDER_LIGHT := Color(0.72, 0.6, 0.42, 0.3)
const BAR_BG := Color(0.96, 0.94, 0.88)
const BAR_FILL := Color(0.95, 0.77, 0.45)

const CATEGORIES: Array[Dictionary] = [
	{"id": "steps", "name": "步数", "icon": "ach_icon_steps.png"},
	{"id": "collection", "name": "收集", "icon": "ach_icon_collection.png"},
	{"id": "growth", "name": "养成", "icon": "ach_icon_growth.png"},
	{"id": "postcards", "name": "明信片", "icon": "ach_icon_postcard.png"},
	{"id": "easter_egg", "name": "彩蛋", "icon": "ach_icon_easter.png"},
]

var _achievement_data: Array = []


func setup() -> void:
	_achievement_data = AchievementSystem.get_definitions() if AchievementSystem else []
	_refresh()


func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	for category in CATEGORIES:
		_add_category_header(category)

		var shown_locked := false
		for achievement in _achievement_data:
			if String(achievement.get("category", "")) != String(category.get("id", "")):
				continue

			var achievement_id := String(achievement.get("id", ""))
			var unlocked := AchievementSystem.is_unlocked(achievement_id) if AchievementSystem else false
			var progress := AchievementSystem.get_progress(achievement_id) if AchievementSystem else 0.0

			if unlocked:
				add_child(_build_achievement_card(achievement, "unlocked", progress))
			elif progress > 0.0:
				add_child(_build_achievement_card(achievement, "progress", progress))
			elif not shown_locked:
				add_child(_build_achievement_card(achievement, "locked", progress))
				shown_locked = true

		_add_category_spacer()


func _add_category_header(category: Dictionary) -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 10)
	add_child(header)

	var icon := _make_icon(ICON_DIR + String(category.get("icon", "")), Vector2(48.0, 48.0))
	header.add_child(icon)

	var name_label := Label.new()
	name_label.text = String(category.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(name_label)

	var divider := ColorRect.new()
	divider.color = BORDER_LIGHT
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(divider)


func _add_category_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 12.0)
	add_child(spacer)


func _build_achievement_card(achievement: Dictionary, state: String, progress: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style())

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	row.add_child(copy)

	var name_label := Label.new()
	name_label.text = String(achievement.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(name_label)

	var description_label := Label.new()
	description_label.text = _description_for_state(achievement, state)
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_color_override("font_color", TEXT_SECONDARY)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(description_label)

	var status := _build_status_area(achievement, state, progress)
	row.add_child(status)

	return card


func _build_status_area(achievement: Dictionary, state: String, progress: float) -> Control:
	var status := VBoxContainer.new()
	status.custom_minimum_size = Vector2(60.0, 32.0)
	status.size_flags_horizontal = Control.SIZE_SHRINK_END
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 4)

	match state:
		"unlocked":
			var icons := HBoxContainer.new()
			icons.alignment = BoxContainer.ALIGNMENT_CENTER
			icons.add_theme_constant_override("separation", 6)
			icons.add_child(_make_icon(ICON_DIR + "ach_icon_check.png", Vector2(32.0, 32.0)))
			icons.add_child(_make_icon(_reward_icon_path(Dictionary(achievement.get("reward", {}))), Vector2(24.0, 24.0)))
			status.add_child(icons)
		"progress":
			status.custom_minimum_size = Vector2(200.0, 32.0)
			status.add_child(_make_progress_bar(progress))
			status.add_child(_make_score_label(achievement))
		_:
			var locked := HBoxContainer.new()
			locked.alignment = BoxContainer.ALIGNMENT_CENTER
			locked.add_theme_constant_override("separation", 4)
			locked.add_child(_make_icon(ICON_DIR + "ach_icon_locked.png", Vector2(32.0, 32.0)))
			var text := Label.new()
			text.text = _locked_condition_text(achievement)
			text.add_theme_font_size_override("font_size", 12)
			text.add_theme_color_override("font_color", TEXT_SECONDARY)
			locked.add_child(text)
			status.add_child(locked)

	return status


func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_BEIGE
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = BORDER_LIGHT
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _make_icon(path: String, minimum_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = minimum_size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	else:
		icon.modulate = Color(1.0, 1.0, 1.0, 0.25)
	return icon


func _make_progress_bar(progress: float) -> ColorRect:
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(200.0, 6.0)
	bg.color = BAR_BG
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.clip_contents = true

	var fill := ColorRect.new()
	fill.custom_minimum_size = Vector2(clampf(200.0 * progress, 0.0, 200.0), 6.0)
	fill.color = BAR_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)

	return bg


func _make_score_label(achievement: Dictionary) -> Label:
	var label := Label.new()
	label.text = _score_text(achievement)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", TEXT_SECONDARY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _description_for_state(achievement: Dictionary, state: String) -> String:
	match state:
		"locked":
			return _locked_condition_text(achievement)
		"progress":
			return _score_text(achievement)
		_:
			return _reward_text(Dictionary(achievement.get("reward", {})))


func _score_text(achievement: Dictionary) -> String:
	var achievement_id := String(achievement.get("id", ""))
	var current := AchievementSystem.get_current_value(achievement_id) if AchievementSystem else 0.0
	var target := float(achievement.get("target", 0.0))
	return "%d/%d" % [int(current), int(target)]


func _locked_condition_text(achievement: Dictionary) -> String:
	return "达成%s可解锁" % _target_text(achievement)


func _target_text(achievement: Dictionary) -> String:
	var target := int(achievement.get("target", 0))
	match String(achievement.get("type", "")):
		"steps_total":
			return "%d步" % target
		"steps_streak":
			return "连续%d天步行" % target
		"hatch_count":
			return "孵化%d只猫" % target
		"album_entries":
			return "收集%d个图鉴" % target
		"breeds_all":
			return "收集%d个品种" % target
		"cat_level":
			return "猫咪等级%d级" % target
		"affection":
			return "好感度%d" % target
		"postcards":
			return "收集%d张明信片" % target
		"city_postcards":
			return "收集%d张城市明信片" % target
		"midnight":
			return "午夜访问"
		"friend_streak":
			return "连续%d天互动" % target
	return "%d进度" % target


func _reward_text(reward: Dictionary) -> String:
	if reward.has("diamonds"):
		return "奖励钻石 x%d" % int(reward.get("diamonds", 0))
	if reward.has("gold_coins"):
		return "奖励金币 x%d" % int(reward.get("gold_coins", 0))
	if not reward.is_empty():
		return "奖励已领取"
	return "已完成"


func _reward_icon_path(reward: Dictionary) -> String:
	if reward.has("gold_coins"):
		return ICON_DIR + "ach_icon_coin.png"
	return ICON_DIR + "ach_icon_diamond.png"
