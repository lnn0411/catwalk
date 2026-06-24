extends UIPage
class_name S10_CatDetail

const DIARY_DATA := [
	["#1 第一次观察你", "「你走路的样子，不像有什么目的地。嗯……我喜欢这样的人。」"],
	["#2 等待的哲学", "「等你回来不是一件难事。难的是不知道等多久——但我从来不数。」"],
	["#3 关于食物的诚实", "🔒 好感Lv4解锁"],
]

var _cat_data: Dictionary = {}

func _on_page_setup(data: Dictionary) -> void:
	_cat_data = data
	_refresh()

func _refresh() -> void:
	var name_str: String = String(_cat_data.get("name", "猫咪"))
	var breed: String = String(_cat_data.get("breed", "普通"))
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

func _on_rename_pressed() -> void:
	pass

func _on_companion_pressed() -> void:
	pass

func _on_giveaway_pressed() -> void:
	pass

func _on_back_pressed() -> void:
	UIManager.replace("res://ui/pages/S10_Album.tscn")
