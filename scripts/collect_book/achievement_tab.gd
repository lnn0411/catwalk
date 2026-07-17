extends VBoxContainer
class_name AchievementTab

const ICON_DIR := "res://assets/art/delivery/achievement/"
const TEXT_PRIMARY := Color("4f453c")
const TEXT_SECONDARY := Color("a2978c")
const BG_CREAM := Color(0.98, 0.95, 0.89, 0.35)
const CARD_BORDER := Color("c4b69c")
const CARD_BORDER_INNER := Color("d9cdb9")
const BAR_BG := Color("efe4d6")
const BAR_FILL := Color("f2c572")
const AMBER := Color("f2c572")
const PAPER_CREAM := Color("f6efe2")

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
	add_theme_constant_override("separation", 6)

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
	header.add_theme_constant_override("separation", 8)
	add_child(header)

	var icon := _make_icon_w(ICON_DIR + String(category.get("icon", "")), Vector2(40.0, 40.0))
	header.add_child(icon)

	var name_label := Label.new()
	name_label.text = String(category.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(name_label)

	var divider := ColorRect.new()
	divider.color = Color(0.77, 0.69, 0.55, 0.3)
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(divider)


func _add_category_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	add_child(spacer)


func _build_achievement_card(achievement: Dictionary, state: String, progress: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style(state == "locked"))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	# left side: text
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)

	var name_label := Label.new()
	name_label.text = String(achievement.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if state == "locked":
		name_label.modulate = Color(1, 1, 1, 0.5)
	copy.add_child(name_label)

	# condition / progress text under name
	var sub = _build_subtext(achievement, state, progress)
	copy.add_child(sub)

	# right side: status
	var status := _build_status(achievement, state, progress)
	row.add_child(status)

	return card


func _build_subtext(achievement: Dictionary, state: String, progress: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	match state:
		"unlocked":
			label.text = _reward_text(Dictionary(achievement.get("reward", {})))
			label.add_theme_color_override("font_color", AMBER)
			label.modulate = Color(1, 1, 1, 0.85)
		"progress":
			label.text = _score_text(achievement)
			label.add_theme_color_override("font_color", TEXT_SECONDARY)
		_:
			var target := int(achievement.get("target", 0))
			var type_str := String(achievement.get("type", ""))
			if type_str == "midnight":
				label.text = "凌晨0-5点访问"
			elif type_str == "friend_streak":
				label.text = "连续%d天互动" % target
			elif type_str == "steps_streak":
				label.text = "连续%d天≥3000步" % target
			elif type_str == "steps_total":
				label.text = "%d步" % target
			elif type_str == "hatch_count":
				label.text = "孵化%d只" % target
			elif type_str == "album_entries":
				label.text = "%d图鉴" % target
			elif type_str == "breeds_all":
				label.text = "%d品种" % target
			elif type_str == "cat_level":
				label.text = "Lv.%d" % target
			elif type_str == "affection":
				label.text = "好感%d" % target
			elif type_str == "postcards":
				label.text = "%d明信片" % target
			elif type_str == "city_postcards":
				label.text = "%d城市明信片" % target
			else:
				label.text = "%d进度" % target
			label.add_theme_color_override("font_color", TEXT_SECONDARY)
			label.modulate = Color(1, 1, 1, 0.55)

	return label


func _build_status(achievement: Dictionary, state: String, progress: float) -> Control:
	var block := VBoxContainer.new()
	block.custom_minimum_size = Vector2(72.0, 32.0)
	block.size_flags_horizontal = Control.SIZE_SHRINK_END
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_theme_constant_override("separation", 4)

	match state:
		"unlocked":
			var icons := HBoxContainer.new()
			icons.alignment = BoxContainer.ALIGNMENT_CENTER
			icons.add_theme_constant_override("separation", 6)
			icons.add_child(_make_icon_w(ICON_DIR + "ach_icon_check.png", Vector2(28.0, 28.0)))
			var reward := Dictionary(achievement.get("reward", {}))
			icons.add_child(_make_icon_w(_reward_path(reward), Vector2(22.0, 22.0)))
			block.add_child(icons)

		"progress":
			block.custom_minimum_size = Vector2(160.0, 32.0)
			block.add_child(_make_progress_bar(progress))
			block.add_child(_make_score_text(achievement))

		_:
			var locked := HBoxContainer.new()
			locked.alignment = BoxContainer.ALIGNMENT_CENTER
			locked.add_theme_constant_override("separation", 4)
			locked.add_child(_make_icon_w(ICON_DIR + "ach_icon_locked.png", Vector2(26.0, 26.0)))
			var t := Label.new()
			t.text = "未达成"
			t.add_theme_font_size_override("font_size", 13)
			t.add_theme_color_override("font_color", TEXT_SECONDARY)
			t.modulate = Color(1, 1, 1, 0.5)
			locked.add_child(t)
			block.add_child(locked)

	return block


func _make_card_style(locked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if locked:
		style.bg_color = Color(0.96, 0.94, 0.88, 0.2)
	else:
		style.bg_color = Color(0.98, 0.96, 0.91, 0.85)
	style.set_corner_radius_all(8)
	# 双线描边：外层粗线+内层细线
	style.set_border_width_all(2)
	style.border_color = CARD_BORDER
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	# 通过 draw_center=false 在内层再加一条细线
	style.draw_center = true
	return style


func _make_icon_w(path: String, min_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = min_size
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	else:
		icon.modulate = Color(1.0, 1.0, 1.0, 0.15)
	return icon


func _make_progress_bar(progress: float) -> Control:
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(160.0, 6.0)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.color = PAPER_CREAM
	bg.clip_contents = true

	var fill := ColorRect.new()
	fill.custom_minimum_size = Vector2(clampf(160.0 * progress, 0.0, 160.0), 6.0)
	fill.color = BAR_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)

	return bg


func _make_score_text(achievement: Dictionary) -> Label:
	var label := Label.new()
	label.text = _score_text(achievement)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", TEXT_SECONDARY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _score_text(achievement: Dictionary) -> String:
	var achievement_id := String(achievement.get("id", ""))
	var current := AchievementSystem.get_current_value(achievement_id) if AchievementSystem else 0.0
	var target := float(achievement.get("target", 0.0))
	return "%d / %d" % [int(current), int(target)]


func _reward_text(reward: Dictionary) -> String:
	if reward.has("diamonds"):
		return "钻石×%d" % int(reward.get("diamonds", 0))
	if reward.has("gold_coins"):
		return "金币×%d" % int(reward.get("gold_coins", 0))
	return "已领取"


func _reward_path(reward: Dictionary) -> String:
	if reward.has("gold_coins"):
		return ICON_DIR + "ach_icon_coin.png"
	return ICON_DIR + "ach_icon_diamond.png"
