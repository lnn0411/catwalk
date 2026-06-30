extends UIPage
class_name S10_CatDetail

const DIARY_DATA := [
	["#1 第一次观察你", "「你走路的样子，不像有什么目的地。嗯……我喜欢这样的人。」"],
	["#2 等待的哲学", "「等你回来不是一件难事。难的是不知道等多久——但我从来不数。」"],
	["#3 关于食物的诚实", "🔒 好感Lv4解锁"],
	["#4 温暖的午后", "🔒 好感Lv5解锁"],
	["#5 星空下的告白", "🔒 好感Lv6解锁"],
]

var _cat_data: Dictionary = {}
var _cat_id: String = ""

func _on_page_setup(data: Dictionary) -> void:
	_cat_data = data.get("cat", {})
	_cat_id = String(_cat_data.get("id", ""))
	_refresh()
	_render_diary()

func _refresh() -> void:
	var name_str: String = String(_cat_data.get("name", String(_cat_data.get("display_name", "猫咪"))))
	var breed: String = String(_cat_data.get("breed", String(_cat_data.get("species", "普通"))))
	var lv: int = int(_cat_data.get("level", 1))
	var aff_lv: int = int(_cat_data.get("affection_lv", min(lv, 3)))

	$VBox/Head/CatName.text = name_str
	$VBox/Head/BreedSub.text = breed
	
	$VBox/Scroll/Body/StatsRow/LevelCard/LvValue.text = "Lv.%d" % lv
	var xp_pct: float = clampf((lv % 10) / 10.0, 0.05, 1.0)
	$VBox/Scroll/Body/StatsRow/LevelCard/LvBar/LvBarFill.size.x = 90.0 * xp_pct
	
	$VBox/Scroll/Body/StatsRow/AffCard/AffValue.text = "Lv.%d" % aff_lv
	var aff_pct: float = clampf(aff_lv / 5.0, 0.05, 1.0)
	$VBox/Scroll/Body/StatsRow/AffCard/AffBar/AffBarFill.size.x = 90.0 * aff_pct

func _render_diary() -> void:
	var diary_unlocked: int = int(_cat_data.get("diary_unlocked", min(int(_cat_data.get("level", 1)) - 1, 2)))
	var list: VBoxContainer = $VBox/Scroll/Body/Diary1/ScrollView/DiaryList
	for child in list.get_children():
		child.queue_free()
	var count: int = min(DIARY_DATA.size(), 5)
	for i in range(count):
		var unlocked: bool = i < diary_unlocked

		var entry := Control.new()
		entry.custom_minimum_size = Vector2(0, 36)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title_label := Label.new()
		title_label.name = "Title"
		title_label.offset_left = 20.0
		title_label.offset_top = 4.0
		title_label.offset_right = 220.0
		title_label.offset_bottom = 32.0
		title_label.text = DIARY_DATA[i][0]
		title_label.add_theme_font_size_override("font_size", 15)
		title_label.add_theme_color_override("font_color", Color(0.3, 0.26, 0.22, 1))
		entry.add_child(title_label)

		var status_label := Label.new()
		status_label.name = "Status"
		status_label.offset_left = 500.0
		status_label.offset_top = 4.0
		status_label.offset_right = -12.0
		status_label.offset_bottom = 32.0
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_label.text = "已解锁" if unlocked else "🔒 好感Lv%d解锁" % (i + 3)
		status_label.add_theme_font_size_override("font_size", 12)
		status_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 1))
		entry.add_child(status_label)

		var text_label := Label.new()
		text_label.name = "Text"
		text_label.offset_left = 20.0
		text_label.offset_top = 36.0
		text_label.offset_right = -20.0
		text_label.offset_bottom = 64.0
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.text = DIARY_DATA[i][1] if unlocked else "再亲密一点点，就能读到啦"
		text_label.add_theme_font_size_override("font_size", 13)
		text_label.add_theme_color_override("font_color", Color(0.45, 0.4, 0.36, 1))
		entry.add_child(text_label)

		list.add_child(entry)

func _find_cat() -> Variant:
	if _cat_id.is_empty() or not HatchEngine:
		return null
	return HatchEngine.get_cat_by_id(_cat_id)

func _on_rename_pressed() -> void:
	Popups.show_input("改名", "请输入新名字", func(new_name: String) -> void:
		var cat = _find_cat()
		if cat == null:
			Popups.show_toast("找不到这只猫了")
			return
		# CatData has display_name, Dictionary has "name"
		if cat is Dictionary:
			cat["name"] = new_name
		else:
			cat.display_name = new_name
		_cat_data["name"] = new_name
		_cat_data["display_name"] = new_name
		if SaveManager:
			SaveManager.save_all()
		_refresh()
		Popups.show_toast("已改名「%s」" % new_name)
	)

func _on_companion_pressed() -> void:
	if _cat_id.is_empty() or not HatchEngine:
		return
	HatchEngine.set_companion_cat_id(_cat_id)
	Popups.show_toast("已设为随行猫")
	UIManager.replace("res://scenes/S04_GardenMain.tscn")

func _on_let_out_pressed() -> void:
	if _cat_data.is_empty():
		return
	UIManager.replace("res://scenes/S04_GardenMain.tscn", {"focus_cat": _cat_data})

func _on_giveaway_pressed() -> void:
	if _cat_id.is_empty():
		return
	# Check that we have more than 1 cat
	if HatchEngine and HatchEngine.get_cats().size() <= 1:
		Popups.show_toast("至少保留一只猫咪")
		return
	Popups.show_confirm("送养", "确定送养这只猫咪吗？", func() -> void:
		if HatchEngine and HatchEngine.remove_cat(_cat_id):
			if SaveManager:
				SaveManager.save_all()
			UIManager.pop()
		else:
			Popups.show_toast("送养失败，请重试")
	)

func _on_back_pressed() -> void:
	UIManager.pop()
