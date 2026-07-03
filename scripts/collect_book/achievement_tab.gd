extends VBoxContainer
class_name AchievementTab

var _achievement_data: Array = []

func setup() -> void:
	var AchSystem = load("res://core/AchievementSystem.gd")
	if AchSystem:
		_achievement_data = AchSystem.ACHIEVEMENTS.duplicate()
	_refresh()

func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	var categories = [
		{"id": "steps", "name": "步数", "color": Color(0.8, 0.55, 0.25, 1)},
		{"id": "collection", "name": "收集", "color": Color(0.6, 0.45, 0.3, 1)},
		{"id": "growth", "name": "养成", "color": Color(0.9, 0.5, 0.65, 1)},
		{"id": "postcards", "name": "明信片", "color": Color(0.45, 0.55, 0.7, 1)},
		{"id": "easter_egg", "name": "彩蛋", "color": Color(0.6, 0.5, 0.8, 1)},
	]

	for cat in categories:
		var cat_label := Label.new()
		cat_label.text = cat.name
		cat_label.add_theme_font_size_override("font_size", 18)
		cat_label.add_theme_color_override("font_color", cat.color)
		add_child(cat_label)

		for a in _achievement_data:
			if a.get("category") != cat.id:
				continue
			var aid = a.get("id", "")
			var aname = a.get("name", "")
			var unlocked = AchievementSystem.is_unlocked(aid) if AchievementSystem else false
			var progress = AchievementSystem.get_progress(aid) if AchievementSystem else 0.0

			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.custom_minimum_size = Vector2(0.0, 48.0)

			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(36.0, 36.0)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_path = "res://assets/art/ui/achievements/achievement_%s.png" % aid
			if ResourceLoader.exists(icon_path):
				icon.texture = load(icon_path)
			else:
				icon.modulate = Color(1, 1, 1, 0.3)
			row.add_child(icon)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var name_label := Label.new()
			name_label.text = aname
			name_label.add_theme_font_size_override("font_size", 15)
			name_label.add_theme_color_override("font_color", Color(0.3, 0.26, 0.22, 1))
			info.add_child(name_label)

			var progress_bg := ColorRect.new()
			progress_bg.custom_minimum_size = Vector2(0.0, 6.0)
			progress_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			progress_bg.color = Color(0.94, 0.9, 0.82, 1)
			if not unlocked:
				var fill := ColorRect.new()
				fill.custom_minimum_size = Vector2(200.0 * clampf(progress, 0.0, 1.0), 6.0)
				fill.color = cat.color
				fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
				progress_bg.add_child(fill)
			info.add_child(progress_bg)

			row.add_child(info)

			var status_label := Label.new()
			if unlocked:
				status_label.text = "✅"
			else:
				status_label.text = "%d%%" % int(progress * 100)
			status_label.custom_minimum_size = Vector2(40.0, 40.0)
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(status_label)

			add_child(row)

			var sep := ColorRect.new()
			sep.color = Color(0.72, 0.6, 0.42, 0.15)
			sep.custom_minimum_size = Vector2(0.0, 1.0)
			sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_child(sep)
