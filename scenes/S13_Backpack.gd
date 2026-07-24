extends "res://ui/UIPage.gd"

# ============================================================
# S13 礼物背包
# 展示 InventoryManager 中的道具，支持点击零食喂猫。
# 全部 UI 走代码构建，样式统一 Palette，禁止硬编码颜色。
#
# Phase 1 桶映射（InventoryManager 暂无逐物品存储）：
#   零食桶 snack        → 🐟 小鱼干 / 🥫 猫罐头（同一 snack 计数，两种喂法）
#   玩具桶 hidden_item  → 🧶 逗猫毛线团 / 🪄 逗猫棒（仅展示，Phase 2 开放）
#   装饰桶 decor        → 🏗️ 猫爬架 / 🌸 樱花树（仅展示，Phase 2 开放）
# 逐物品类型待 Phase 2 美术/数值到位后拆分。
# ============================================================

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const SETTINGS_SCENE := "res://scenes/S11_Settings.tscn"
const SIDE_MARGIN := 48
const TOP_BAR_H := 104.0

# 每只猫每日喂食上限（独立于 4h 冷却的日次数护栏）
const DAILY_FEED_LIMIT := 3
const CFG_PATH := "user://backpack.cfg"
const CFG_SECTION := "feed_daily"

# 喂食种类
const KIND_FISH := "feed_fish"   # 小鱼干：走正常喂食流程（好感+1）
const KIND_CAN := "feed_can"     # 猫罐头：喂食后额外 +2（合计好感+3）
const KIND_PHASE2 := "phase2"    # 玩具/装饰：仅展示，Phase 2 开放

# 物品分组配置
const ITEM_GROUPS := [
	{
		"title": "🍪 零食",
		"items": [
			{"emoji": "🐟", "name": "小鱼干", "type": "snack", "kind": KIND_FISH},
			{"emoji": "🥫", "name": "猫罐头", "type": "snack", "kind": KIND_CAN},
		],
	},
	{
		"title": "🧸 玩具",
		"items": [
			{"emoji": "🧶", "name": "逗猫毛线团", "type": "hidden_item", "kind": KIND_PHASE2},
			{"emoji": "🪄", "name": "逗猫棒", "type": "hidden_item", "kind": KIND_PHASE2},
		],
	},
	{
		"title": "🏡 装饰",
		"items": [
			{"emoji": "🏗️", "name": "猫爬架", "type": "decor", "kind": KIND_PHASE2},
			{"emoji": "🌸", "name": "樱花树", "type": "decor", "kind": KIND_PHASE2},
		],
	},
]

var _list_vbox: VBoxContainer
var _picker: Control
var _daily_cfg := ConfigFile.new()


func _ready() -> void:
	super._ready()
	if has_node("Bg"):
		(%Bg as ColorRect).color = Palette.PAPER_CREAM
	_load_daily()
	_build_head()
	_build_body()
	_refresh()


func on_enter(_data: Dictionary = {}) -> void:
	_load_daily()
	_refresh()


# 返回：优先关闭猫咪选择弹窗，否则退回上一页
func handle_back() -> bool:
	if _picker != null and is_instance_valid(_picker):
		_close_picker()
		return true
	return false


func _on_back() -> void:
	if _picker != null and is_instance_valid(_picker):
		_close_picker()
		return
	UIManager.pop()


# ---------------------------------------------------------------- 构建 UI

func _build_head() -> void:
	var bar := ColorRect.new()
	bar.color = Palette.TEXT_PRIMARY
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = TOP_BAR_H
	add_child(bar)

	var back := Button.new()
	back.text = "‹ 返回"
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.position = Vector2(20.0, 52.0)
	back.custom_minimum_size = Vector2(96.0, 40.0)
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_color_override("font_color", Palette.PAPER_CREAM)
	back.add_theme_color_override("font_hover_color", Palette.AMBER)
	back.add_theme_color_override("font_pressed_color", Palette.AMBER)
	back.pressed.connect(_on_back)
	add_child(back)

	var title := _label("🎀 礼物背包", 20, Palette.PAPER_CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 52.0
	title.offset_bottom = 92.0
	add_child(title)


func _build_body() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Body"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = TOP_BAR_H
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var pad := MarginContainer.new()
	pad.custom_minimum_size = Vector2(DESIGN_SIZE.x, 0.0)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", SIDE_MARGIN)
	pad.add_theme_constant_override("margin_right", SIDE_MARGIN)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", SIDE_MARGIN)
	scroll.add_child(pad)

	_list_vbox = VBoxContainer.new()
	_list_vbox.add_theme_constant_override("separation", 16)
	pad.add_child(_list_vbox)


func _refresh() -> void:
	if _list_vbox == null:
		return
	for c in _list_vbox.get_children():
		c.queue_free()

	var counts: Dictionary = InventoryManager.get_all_counts()
	var total := 0
	for t in ["snack", "hidden_item", "decor"]:
		total += int(counts.get(t, 0))

	if total <= 0:
		_list_vbox.add_child(_empty_card())
		return

	for group in ITEM_GROUPS:
		_list_vbox.add_child(_group_card(group, counts))


func _empty_card() -> PanelContainer:
	var card := _card_panel()
	var m := _inner_margin(20, 40, 20, 40)
	card.add_child(m)
	var l := _label("背包空空如也~", 16, Palette.TEXT_SECONDARY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(l)
	return card


func _group_card(group: Dictionary, counts: Dictionary) -> PanelContainer:
	var card := _card_panel()
	var m := _inner_margin(18, 16, 18, 16)
	card.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	m.add_child(vb)

	vb.add_child(_label(str(group.get("title", "")), 16, Palette.TEXT_PRIMARY))

	for item in group.get("items", []):
		vb.add_child(_item_row(item, int(counts.get(str(item.get("type", "")), 0))))

	return card


func _item_row(item: Dictionary, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 48.0)
	row.add_theme_constant_override("separation", 12)

	var emoji := _label(str(item.get("emoji", "")), 24, Palette.TEXT_PRIMARY)
	emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(emoji)

	var name_lbl := _label(str(item.get("name", "")), 15, Palette.TEXT_PRIMARY)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var count_lbl := _label("×%d" % count, 15, Palette.TEXT_SECONDARY)
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_lbl.custom_minimum_size = Vector2(48.0, 0.0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count_lbl)

	var kind := str(item.get("kind", KIND_PHASE2))
	if kind == KIND_PHASE2:
		row.add_child(_action_btn("敬请期待", false, func() -> void: pass))
	else:
		var usable := count > 0
		var btn := _action_btn("使用", usable, func() -> void: _on_use(item))
		row.add_child(btn)

	return row


# ---------------------------------------------------------------- 喂食

func _on_use(item: Dictionary) -> void:
	if not InventoryManager.has_item("snack", 1):
		Popups.show_toast("没有零食了")
		return
	var cats: Array = HatchEngine.get_cats()
	if cats.is_empty():
		Popups.show_toast("还没有猫咪，先去孵化吧")
		return
	_open_cat_picker(item)


func _feed(cat_id: String, item: Dictionary) -> void:
	var item_name := str(item.get("name", "零食"))
	if not InventoryManager.has_item("snack", 1):
		Popups.show_toast("没有零食了")
		return
	if _feed_count_today(cat_id) >= DAILY_FEED_LIMIT:
		Popups.show_toast("今天喂这只猫的次数够啦，明天再来吧")
		return
	# try_interact 内含 4h 喂食冷却与情绪检查；失败则不消耗零食
	if not InteractionSystem.try_interact(cat_id, "feed"):
		Popups.show_toast("猫咪暂时不想吃，稍后再来吧")
		return

	InventoryManager.consume_item("snack", 1)

	var gain := 1
	if str(item.get("kind", "")) == KIND_CAN:
		# feed 已 +1，猫罐头再补 +2 → 合计 +3
		var cat = HatchEngine.get_cat_by_id(cat_id)
		if cat != null and cat is CatData:
			cat.friendship += 2
			if SaveManager:
				SaveManager.save_all()
		gain = 3

	_record_feed(cat_id)
	Popups.show_toast("【%s】喂食成功！好感+%d" % [item_name, gain])
	_refresh()


# ---------------------------------------------------------------- 猫咪选择弹窗

func _open_cat_picker(item: Dictionary) -> void:
	_close_picker()

	_picker = Control.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_picker)

	var shade := Button.new()
	shade.flat = true
	shade.focus_mode = Control.FOCUS_NONE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade_style := StyleBoxFlat.new()
	shade_style.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	for s in ["normal", "hover", "pressed", "focus"]:
		shade.add_theme_stylebox_override(s, shade_style)
	shade.pressed.connect(_close_picker)
	_picker.add_child(shade)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(300.0, 400.0)
	card.offset_left = -150.0
	card.offset_top = -200.0
	card.offset_right = 150.0
	card.offset_bottom = 200.0
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Palette.MILK_WHITE
	card_style.border_color = Palette.BORDER
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(16)
	card_style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", card_style)
	_picker.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var title := _label("选择一只猫咪", 17, Palette.TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	for cat in HatchEngine.get_cats():
		var cell := _cat_cell(cat, item)
		if cell != null:
			grid.add_child(cell)


func _cat_cell(cat, item: Dictionary) -> Control:
	var cat_id := ""
	var cat_name := "猫咪"
	var species := ""
	if cat is CatData:
		cat_id = String(cat.id)
		cat_name = String(cat.display_name)
		species = String(cat.species)
	elif cat is Dictionary:
		cat_id = String(cat.get("id", ""))
		cat_name = String(cat.get("display_name", "猫咪"))
		species = String(cat.get("species", ""))
	if cat_id == "":
		return null

	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(0.0, 108.0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = Palette.PAPER_CREAM
	cell_style.border_color = Palette.BORDER
	cell_style.set_border_width_all(1)
	cell_style.set_corner_radius_all(12)
	cell_style.set_content_margin_all(8)
	cell.add_theme_stylebox_override("panel", cell_style)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	cell.add_child(vb)

	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(48.0, 48.0)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var av_style := StyleBoxFlat.new()
	av_style.bg_color = _species_color(species)
	av_style.set_corner_radius_all(24)
	avatar.add_theme_stylebox_override("panel", av_style)
	var initial := _label(_avatar_text(cat_name), 20, Palette.MILK_WHITE)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(initial)
	vb.add_child(avatar)

	var nm := _label(cat_name, 12, Palette.TEXT_PRIMARY)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(nm)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func() -> void:
		_close_picker()
		_feed(cat_id, item)
	)
	cell.add_child(btn)

	return cell


func _close_picker() -> void:
	if _picker != null and is_instance_valid(_picker):
		_picker.queue_free()
	_picker = null


# ---------------------------------------------------------------- 每日次数存档

func _load_daily() -> void:
	_daily_cfg = ConfigFile.new()
	var central_data: Dictionary = {}
	if SaveManager and SaveManager.has_method("get_feed_daily_data"):
		central_data = SaveManager.get_feed_daily_data()
	if not central_data.is_empty() and (not Dictionary(central_data.get("counts", {})).is_empty() or str(central_data.get("date", "")) != ""):
		_daily_cfg.set_value(CFG_SECTION, "date", String(central_data.get("date", "")))
		for cat_id in Dictionary(central_data.get("counts", {})):
			_daily_cfg.set_value(CFG_SECTION, str(cat_id), int(central_data["counts"][cat_id]))
	else:
		_daily_cfg.load(CFG_PATH)
	var last := str(_daily_cfg.get_value(CFG_SECTION, "date", ""))
	if last != _today_key():
		# 跨天：清空所有猫的当日计数
		if _daily_cfg.has_section(CFG_SECTION):
			_daily_cfg.erase_section(CFG_SECTION)
		_daily_cfg.set_value(CFG_SECTION, "date", _today_key())
		_daily_cfg.save(CFG_PATH)
		if SaveManager and SaveManager.has_method("set_feed_daily_data"):
			SaveManager.set_feed_daily_data({"date": _today_key(), "counts": {}})
			SaveManager.save_all()


func _feed_count_today(cat_id: String) -> int:
	return int(_daily_cfg.get_value(CFG_SECTION, cat_id, 0))


func _record_feed(cat_id: String) -> void:
	var n := _feed_count_today(cat_id) + 1
	_daily_cfg.set_value(CFG_SECTION, "date", _today_key())
	_daily_cfg.set_value(CFG_SECTION, cat_id, n)
	_daily_cfg.save(CFG_PATH)
	if SaveManager and SaveManager.has_method("set_feed_daily_data"):
		var counts: Dictionary = Dictionary(SaveManager.get_feed_daily_data().get("counts", {})).duplicate(true)
		counts[cat_id] = n
		SaveManager.set_feed_daily_data({"date": _today_key(), "counts": counts})
		SaveManager.save_all()


func _today_key() -> String:
	var ut := Time.get_unix_time_from_system()
	if TimeGuard and TimeGuard.has_method("get_safe_unix_time"):
		ut = TimeGuard.get_safe_unix_time()
	var d := Time.get_datetime_dict_from_unix_time(ut)
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


# ---------------------------------------------------------------- 样式辅助

func _card_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.MILK_WHITE
	s.border_color = Palette.BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(16)
	s.set_content_margin_all(0)
	s.shadow_color = Palette.UI_SHADOW
	s.shadow_size = 6
	s.shadow_offset = Vector2(0.0, 3.0)
	p.add_theme_stylebox_override("panel", s)
	return p


func _inner_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m


func _action_btn(text: String, enabled: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(88.0, 36.0)
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	b.add_theme_color_override("font_hover_color", Palette.TEXT_PRIMARY)
	b.add_theme_color_override("font_pressed_color", Palette.TEXT_PRIMARY)
	b.add_theme_color_override("font_disabled_color", Palette.TEXT_SECONDARY)
	var bg: Color = Palette.AMBER if enabled else Palette.BORDER
	b.add_theme_stylebox_override("normal", _pill_style(bg))
	b.add_theme_stylebox_override("hover", _pill_style(bg.lightened(0.06)))
	b.add_theme_stylebox_override("pressed", _pill_style(Palette.AMBER_PRESS))
	b.add_theme_stylebox_override("disabled", _pill_style(Palette.BORDER))
	if enabled:
		b.pressed.connect(cb)
	return b


func _pill_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(18)
	s.set_content_margin(SIDE_LEFT, 12)
	s.set_content_margin(SIDE_RIGHT, 12)
	s.set_content_margin(SIDE_TOP, 6)
	s.set_content_margin(SIDE_BOTTOM, 6)
	return s


func _species_color(species: String) -> Color:
	match species:
		CatData.BREED_ORANGE:
			return Palette.CAT_ORANGE_MID
		CatData.BREED_BRITISH:
			return Palette.CAT_BRIT_MID
		CatData.BREED_SIAMESE:
			return Palette.CAT_SIAM_POINT
		_:
			return Palette.TEXT_SECONDARY


func _avatar_text(name: String) -> String:
	if name.is_empty():
		return "猫"
	return name.substr(0, 1)


func _label(text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l
