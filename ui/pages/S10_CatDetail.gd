extends UIPage
class_name S10_CatDetail

const DIARY_DATA := [
	["#1 第一次观察你", "「你走路的样子，不像有什么目的地。嗯……我喜欢这样的人。」"],
	["#2 等待的哲学", "「等你回来不是一件难事。难的是不知道等多久——但我从来不数。」"],
	["#3 关于食物的诚实", "🔒 好感Lv4解锁"],
	["#4 温暖的午后", "🔒 好感Lv5解锁"],
	["#5 星空下的告白", "🔒 好感Lv6解锁"],
]

const PORTRAIT_PATHS := {
	"orange": "res://assets/art/cats/portraits/reveal/portrait_orange.png",
	"orange_tabby": "res://assets/art/cats/portraits/reveal/portrait_orange.png",
	"british": "res://assets/art/cats/portraits/reveal/portrait_british.png",
	"british_shorthair": "res://assets/art/cats/portraits/reveal/portrait_british.png",
	"siamese": "res://assets/art/cats/portraits/reveal/portrait_siamese.png",
}

var _cat_data: Dictionary = {}
var _cat_id: String = ""

func _on_page_setup(data: Dictionary) -> void:
	_cat_data = data.get("cat", {})
	_cat_id = String(_cat_data.get("id", ""))
	_refresh()
	_build_stat_dividers()
	_render_diary()

	# 进入详情页即视作已读——清除该猫的日记未读标记并落盘
	_cat_data["diary_has_unread"] = false
	var cat = _find_cat()
	if cat != null:
		if cat is Dictionary:
			cat["diary_has_unread"] = false
		else:
			cat.set("diary_has_unread", false)
	if SaveManager:
		SaveManager.save_all()

# Draw two vertical dashed dividers that split the stats panel into 3 columns,
# matching the concept art. Idempotent so re-setup doesn't stack duplicates.
func _build_stat_dividers() -> void:
	var panel: Control = $VBox/Scroll/Body/StatsRow
	for child in panel.get_children():
		if String(child.name).begins_with("Divider"):
			child.queue_free()
	for fx in [0.3333, 0.6667]:
		var line := Control.new()
		line.name = "Divider_%d" % int(fx * 1000)
		line.anchor_left = fx
		line.anchor_right = fx
		line.anchor_top = 0.0
		line.anchor_bottom = 1.0
		line.offset_top = 30.0
		line.offset_bottom = -30.0
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(line)
		var y := 0.0
		while y < 112.0:
			var dash := ColorRect.new()
			dash.color = Color(0.72, 0.6, 0.42, 0.55)
			dash.position = Vector2(-1.0, y)
			dash.size = Vector2(2.0, 8.0)
			dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_child(dash)
			y += 14.0

func _refresh() -> void:
	var name_str: String = String(_cat_data.get("name", String(_cat_data.get("display_name", "猫咪"))))
	var breed: String = String(_cat_data.get("breed", String(_cat_data.get("species", "普通"))))
	# Load portrait by breed
	var portrait_path: String = PORTRAIT_PATHS.get(breed, "")
	if not portrait_path.is_empty():
		var tex := load(portrait_path) as Texture2D
		if tex != null:
			$VBox/Scroll/Body/CatImageArea.texture = tex

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

		# 每条日记 = 单行可点击按钮：标题（左）+ 状态（右），点击弹出全文/提示
		var row := TextureButton.new()
		row.name = "DiaryRow_%d" % i
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0.0, 54.0)
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var top := HBoxContainer.new()
		top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(top)

		var title_label := Label.new()
		title_label.name = "Title"
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.offset_top = 30
		title_label.text = DIARY_DATA[i][0]
		title_label.add_theme_font_size_override("font_size", 19)
		title_label.add_theme_color_override("font_color", Color(0.3, 0.26, 0.22, 1) if unlocked else Color(0.55, 0.5, 0.45, 1))
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(title_label)

		var status_label := Label.new()
		status_label.name = "Status"
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.text = "查看 ›" if unlocked else "🔒 好感Lv%d解锁" % (i + 3)
		status_label.add_theme_font_size_override("font_size", 16)
		status_label.add_theme_color_override("font_color", Color(0.6, 0.45, 0.3, 1) if unlocked else Color(0.5, 0.45, 0.4, 1))
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(status_label)

		var idx := i
		var is_unlocked := unlocked
		row.pressed.connect(func() -> void:
			if is_unlocked:
				_show_diary_popup(idx)
			else:
				Popups.show_toast("好感Lv%d解锁" % (idx + 3))
		)

		list.add_child(row)

		# 每行之间加一条细分隔线（最后一行除外）
		if i < count - 1:
			var sep := ColorRect.new()
			sep.color = Color(0.72, 0.6, 0.42, 0.2)
			sep.custom_minimum_size = Vector2(0.0, 1.0)
			sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			list.add_child(sep)

func _show_diary_popup(index: int) -> void:
	if index < 0 or index >= DIARY_DATA.size():
		return
	var title_text: String = String(DIARY_DATA[index][0])
	var content_text: String = String(DIARY_DATA[index][1])

	var layer := CanvasLayer.new()
	layer.layer = 100
	get_tree().root.add_child(layer)

	# 半透明遮罩，点击空白处关闭
	var mask := TextureRect.new()
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.stretch_mode = TextureRect.STRETCH_SCALE
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	var mask_path := "res://assets/art/ui/panels/overlay_mask.png"
	if ResourceLoader.exists(mask_path):
		mask.texture = load(mask_path)
	else:
		mask.modulate = Color(0, 0, 0, 0.5)
	mask.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			layer.queue_free()
	)
	layer.add_child(mask)

	# 弹窗主体
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var card := TextureRect.new()
	card.custom_minimum_size = Vector2(560.0, 420.0)
	card.size = Vector2(560.0, 420.0)
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg_path := "res://assets/art/ui/panels/popup_bg.png"
	if ResourceLoader.exists(bg_path):
		card.texture = load(bg_path)
	center.add_child(card)

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 56.0
	content.offset_top = 56.0
	content.offset_right = -56.0
	content.offset_bottom = -48.0
	content.add_theme_constant_override("separation", 18)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.26, 0.22, 1))
	content.add_child(title_label)

	var body_label := Label.new()
	body_label.text = content_text
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.add_theme_font_size_override("font_size", 16)
	body_label.add_theme_color_override("font_color", Color(0.45, 0.4, 0.36, 1))
	content.add_child(body_label)

	var close_button := TextureButton.new()
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.custom_minimum_size = Vector2(180.0, 64.0)
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var btn_path := "res://assets/art/ui/incubation/components/btn_confirm_name.png"
	if ResourceLoader.exists(btn_path):
		var btn_tex := load(btn_path) as Texture2D
		close_button.texture_normal = btn_tex
		close_button.texture_pressed = btn_tex
		close_button.texture_hover = btn_tex
	var close_label := Label.new()
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	close_label.text = "关闭"
	close_label.add_theme_font_size_override("font_size", 18)
	close_label.add_theme_color_override("font_color", Color(0.3, 0.26, 0.22, 1))
	close_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_button.add_child(close_label)
	close_button.pressed.connect(func() -> void:
		layer.queue_free()
	)
	content.add_child(close_button)


func _find_cat() -> Variant:
	if _cat_id.is_empty() or not HatchEngine:
		return null
	return HatchEngine.get_cat_by_id(_cat_id)


func _is_name_taken(name: String) -> bool:
	if not HatchEngine:
		return false
	for c in HatchEngine.get_cats():
		var cid: String = String(c.id)
		if cid == _cat_id:
			continue
		var cname: String = String(c.display_name) if "display_name" in c else String(c.get("name", ""))
		if cname == name:
			return true
	return false

func _on_rename_pressed() -> void:
	Popups.show_input("改名", "请输入新名字", func(new_name: String) -> void:
		var cat = _find_cat()
		if cat == null:
			Popups.show_toast("找不到这只猫了")
			return
		if _is_name_taken(new_name):
			Popups.show_toast("已有同名猫咪，请重新选一个")
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
	Popups.show_confirm("随行", "确定将这只猫咪设为随行猫吗？", func() -> void:
		HatchEngine.set_companion_cat_id(_cat_id)
		Popups.show_toast("已设为随行猫")
		UIManager.replace("res://scenes/S04_GardenMain.tscn")
	)

func _on_let_out_pressed() -> void:
	if _cat_data.is_empty():
		return
	Popups.show_confirm("放出", "确定将这只猫咪放到花园吗？", func() -> void:
		UIManager.replace("res://scenes/S04_GardenMain.tscn", {"focus_cat": _cat_data})
	)

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
