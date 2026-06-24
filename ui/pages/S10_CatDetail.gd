extends UIPage
class_name S10_CatDetail

const DIARY_DATA := [
	["#1 第一次观察你", "「你走路的样子，不像有什么目的地。嗯……我喜欢这样的人。」"],
	["#2 等待的哲学", "「等你回来不是一件难事。难的是不知道等多久——但我从来不数。」"],
	["#3 关于食物的诚实", "🔒 好感Lv4解锁"],
]

var _cat_data: Dictionary = {}
var _cat_id: String = ""

func _on_page_setup(data: Dictionary) -> void:
	_cat_data = data.get("cat", {})
	_cat_id = String(_cat_data.get("id", ""))
	_refresh()

func _refresh() -> void:
	var name_str: String = String(_cat_data.get("name", String(_cat_data.get("display_name", "猫咪"))))
	var breed: String = String(_cat_data.get("breed", String(_cat_data.get("species", "普通"))))
	var lv: int = int(_cat_data.get("level", 1))
	var aff_lv: int = int(_cat_data.get("affection_lv", min(lv, 3)))
	var diary_unlocked: int = int(_cat_data.get("diary_unlocked", min(lv - 1, 2)))
	
	$VBox/Head/CatName.text = name_str
	$VBox/Head/BreedSub.text = breed
	
	$VBox/Scroll/Body/StatsRow/LevelCard/LvValue.text = "Lv.%d" % lv
	var xp_pct: float = clampf((lv % 10) / 10.0, 0.05, 1.0)
	$VBox/Scroll/Body/StatsRow/LevelCard/LvBar/LvBarFill.size.x = 90.0 * xp_pct
	
	$VBox/Scroll/Body/StatsRow/AffCard/AffValue.text = "Lv.%d" % aff_lv
	var aff_pct: float = clampf(aff_lv / 5.0, 0.05, 1.0)
	$VBox/Scroll/Body/StatsRow/AffCard/AffBar/AffBarFill.size.x = 90.0 * aff_pct
	
	# Diary entries
	for i in range(3):
		var unlocked: bool = i < diary_unlocked
		var card_path: String = "$VBox/Scroll/Body/Diary%d" % (i + 1)
		var card = get_node(card_path)
		if card == null:
			continue
		var title_label: Label = card.get_node("D%dTitle" % (i + 1))
		var status_label: Label = card.get_node("D%dStatus" % (i + 1))
		var text_label: Label = card.get_node("D%dText" % (i + 1))
		if title_label:
			title_label.text = DIARY_DATA[i][0]
		if status_label:
			status_label.text = "已解锁" if unlocked else "🔒 好感Lv%d" % (i + 3)
		if text_label:
			text_label.text = DIARY_DATA[i][1] if unlocked else "再亲密一点点，就能读到啦"
		if card is ColorRect:
			card.color = Color(1, 1, 1, 1) if unlocked else Color(0.95, 0.95, 0.95, 1)

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
			UIManager.replace("res://ui/pages/S10_Album.tscn")
		else:
			Popups.show_toast("送养失败，请重试")
	)

func _on_back_pressed() -> void:
	UIManager.replace("res://ui/pages/S10_Album.tscn")
