extends VBoxContainer
class_name AchievementTab

const CATEGORY_ICONS := {
	"steps": "res://assets/art/delivery/achievement/ach_icon_steps.png",
	"collection": "res://assets/art/delivery/achievement/ach_icon_collection.png",
	"growth": "res://assets/art/delivery/achievement/ach_icon_growth.png",
	"postcards": "res://assets/art/delivery/achievement/ach_icon_postcard.png",
	"easter_egg": "res://assets/art/delivery/achievement/ach_icon_easter.png",
}
const ICON_LOCKED := preload("res://assets/art/delivery/achievement/ach_icon_locked.png")
const ICON_CHECK := preload("res://assets/art/delivery/achievement/ach_icon_check.png")
const ICON_DIAMOND := preload("res://assets/art/delivery/achievement/ach_icon_diamond.png")
const ICON_COIN := preload("res://assets/art/delivery/achievement/ach_icon_coin.png")

const COLOR_CARD_BG := Color("0xfffff7")
const COLOR_CARD_BORDER_LIGHT := Color("0xeae0cf")
const COLOR_CARD_BORDER_DARK := Color("0xd4c5a8")
const COLOR_TEXT_PRIMARY := Color("0x4f453c")
const COLOR_TEXT_SECONDARY := Color("0xa2978c")
const COLOR_TEXT_LOCKED := Color("0xc0b8a8")
const COLOR_PROGRESS_BG := Color("0xf6efe2")
const COLOR_PROGRESS_FILL := Color("0xf2c572")
const COLOR_GREEN_CHECK := Color("0x4db34d")
const COLOR_GOLD := Color("0xe6a61a")

const CATEGORIES := [
	{"id": "steps", "name": "步数"},
	{"id": "collection", "name": "收集"},
	{"id": "growth", "name": "养成"},
	{"id": "postcards", "name": "明信片"},
	{"id": "easter_egg", "name": "彩蛋"},
]

var _achievement_data: Array = []
var _ach_system_cache = null


func setup() -> void:
	if not _load_achievements():
		return
	_refresh()


func _load_achievements() -> bool:
	if AchievementSystem == null:
		return false
	_achievement_data = AchievementSystem.ACHIEVEMENTS.duplicate()
	return not _achievement_data.is_empty()


func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	for cat in CATEGORIES:
		_add_category_header(cat)
		_add_category_items(cat)


func _add_category_header(cat: Dictionary) -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.custom_minimum_size = Vector2(0, 56)
	add_child(header)

	# Category icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path = CATEGORY_ICONS.get(cat.id, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		# Fallback: colored circle
		icon.custom_minimum_size = Vector2(36, 36)
	header.add_child(icon)

	# Category name
	var name_label := Label.new()
	name_label.text = cat.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.add_theme_font_override("font", _get_bold_font())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(name_label)

	add_child(header)

	# Separator line (dashed-style via thin ColorRect)
	var sep := ColorRect.new()
	sep.color = COLOR_CARD_BORDER_LIGHT
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(sep)


func _add_category_items(cat: Dictionary) -> void:
	var items := _get_filtered_achievements(cat.id)
	for a in items:
		_add_achievement_card(a)
	# Category bottom spacer
	var spacer := ColorRect.new()
	spacer.color = Color.TRANSPARENT
	spacer.custom_minimum_size = Vector2(0, 8)
	add_child(spacer)


func _get_filtered_achievements(cat_id: String) -> Array:
	var category_items: Array = []
	for a in _achievement_data:
		if a.get("category", "") == cat_id:
			var aid = a.get("id", "")
			var unlocked = AchievementSystem.is_unlocked(aid) if AchievementSystem else false
			var progress = AchievementSystem.get_progress(aid) if AchievementSystem else 0.0
			if unlocked:
				category_items.append(a)
			elif progress > 0.0:
				category_items.append(a)
			else:
				# Locked — only include the most recent one
				# Break after adding one locked item
				category_items.append(a)
				break
	return category_items


func _add_achievement_card(a: Dictionary) -> void:
	var aid := String(a.get("id", ""))
	var aname := String(a.get("name", ""))
	var unlocked := AchievementSystem.is_unlocked(aid) if AchievementSystem else false
	var progress := AchievementSystem.get_progress(aid) if AchievementSystem else 0.0

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style())
	add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Left: info area
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	# Achievement name
	var name_label := Label.new()
	name_label.text = aname
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.add_theme_font_override("font", _get_bold_font())
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name_label)

	if unlocked:
		_add_unlocked_card_content(info, a)
	elif progress > 0.0:
		_add_progress_card_content(info, a, progress, aid)
	else:
		_add_locked_card_content(info, a)

	# Right: status icon area
	var status := CenterContainer.new()
	status.custom_minimum_size = Vector2(40, 40)
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(status)

	var status_icon := TextureRect.new()
	status_icon.custom_minimum_size = Vector2(28, 28)
	status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if unlocked:
		status_icon.texture = ICON_CHECK
	elif progress > 0.0:
		# No icon for in-progress — the progress bar is the indicator
		status_icon.queue_free()
		status_icon = null
	else:
		status_icon.texture = ICON_LOCKED
		status_icon.modulate = Color(1, 1, 1, 0.6)

	if status_icon:
		status.add_child(status_icon)
	else:
		status.queue_free()


func _add_unlocked_card_content(info: VBoxContainer, a: Dictionary) -> void:
	# Condition description
	var desc := Label.new()
	desc.text = _condition_text(a)
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)

	# Reward row
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 6)
	info.add_child(reward_row)

	var reward: Dictionary = a.get("reward", {})
	for reward_key in reward:
		var value = reward[reward_key]
		if reward_key in ["gold_coins", "diamonds"]:
			var reward_icon := TextureRect.new()
			reward_icon.custom_minimum_size = Vector2(20, 20)
			reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			reward_icon.texture = ICON_DIAMOND if reward_key == "diamonds" else ICON_COIN
			reward_row.add_child(reward_icon)

			var reward_label := Label.new()
			reward_label.text = "+%d" % int(value)
			reward_label.add_theme_font_size_override("font_size", 12)
			reward_label.add_theme_color_override("font_color", COLOR_GOLD)
			reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			reward_row.add_child(reward_label)


func _add_progress_card_content(info: VBoxContainer, a: Dictionary, progress: float, aid: String) -> void:
	# Progress bar row
	var bar_row := HBoxContainer.new()
	bar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_theme_constant_override("separation", 8)
	bar_row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_child(bar_row)

	# Progress bar background
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 6)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.color = COLOR_PROGRESS_BG
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(bar_bg)

	# Fill
	var fill := ColorRect.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.color = COLOR_PROGRESS_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Use a margin to control width ratio
	bar_bg.add_child(fill)

	# Force fill width via custom_minimum_size after add_child
	# The fill will expand to parent width; use anchor trick
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.anchor_right = clampf(progress, 0.0, 1.0)
	fill.offset_right = 0.0

	# Fraction text
	var target = float(a.get("target", 1))
	var current = AchievementSystem.get_current_value(aid) if AchievementSystem.has_method("get_current_value") else 0.0
	var fraction_label := Label.new()
	fraction_label.text = "%s/%s" % [_format_number(current), _format_number(target)]
	fraction_label.add_theme_font_size_override("font_size", 12)
	fraction_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	fraction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fraction_label.custom_minimum_size = Vector2(90, 0)
	fraction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar_row.add_child(fraction_label)


func _add_locked_card_content(info: VBoxContainer, a: Dictionary) -> void:
	# Condition description for locked
	var desc := Label.new()
	desc.text = _condition_text(a)
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", COLOR_TEXT_LOCKED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)


func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	# Double border: outer dark + inner light
	style.set_border_width_all(1)
	style.border_color = COLOR_CARD_BORDER_DARK
	# Inner light border via draw_center offset trick
	# Since StyleBoxFlat doesn't support double border natively,
	# we use a second pass: set draw_center = true with shadow style
	# Alternative: just use a single warm border with slightly thicker width
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2

	return style


func _condition_text(a: Dictionary) -> String:
	var type := String(a.get("type", ""))
	var target := int(a.get("target", 0))
	# Generate readable condition text
	match type:
		"steps_total":
			return "累计步数达到 %s 步" % _format_number(target)
		"steps_streak":
			return "连续 %d 天每日步数 ≥ 3000" % target
		"hatch_count":
			return "孵化 %d 只猫" % target
		"album_entries":
			return "图鉴收录 %d 只猫" % target
		"breeds_all":
			return "集齐 %d 个品种" % target
		"cat_level":
			return "拥有 %d 级猫" % target
		"affection":
			return "好感度达到 %d" % target
		"postcards":
			return "收集 %d 张明信片" % target
		"city_postcards":
			return "收集 %d 张城市明信片" % target
		"midnight":
			return "在午夜时分打开游戏 (0:00-6:00)"
		"friend_streak":
			return "连续 %d 天与同一只猫互动 ≥ 3 次" % target
	return ""


func _format_number(n: float) -> String:
	var val := int(n)
	if val >= 10000:
		return "%d万" % (val / 10000)
	elif val >= 1000:
		return "%.1fk" % (val / 1000.0)
	return str(val)


func _get_bold_font() -> Font:
	# Try to use a bold font variant if available, else fallback
	return ThemeDB.fallback_font
