extends "res://ui/UIPage.gd"
## 图鉴主面板 —— 全屏 Control。
## 内部托管 CatTab、PostcardTab 与 AchievementTab，
## 顶部标题 + 已发现统计 + TabBar（三个 Tab 按钮）+ 返回按钮。
## 所有 UI 全用 _draw() 代码绘制。

const DESIGN_SIZE: Vector2 = Vector2(720, 1280)

const CatTabScript: GDScript = preload("res://scripts/collect_book/cat_tab.gd")
const PostcardTabScript: GDScript = preload("res://scripts/collect_book/postcard_tab.gd")
const AchievementTabScript: GDScript = preload("res://scripts/collect_book/achievement_tab.gd")
const DetailPopupScript: GDScript = preload("res://scripts/collect_book/cat_detail_popup.gd")
const PostcardPopupScript: GDScript = preload("res://scripts/collect_book/postcard_detail_popup.gd")
const CatDataScript: GDScript = preload("res://core/CatData.gd")

# 点击热区（设计坐标系）
const BACK_BTN_RECT: Rect2 = Rect2(28, 59, 85, 48)
const TAB_CAT_RECT: Rect2 = Rect2(30, 150, 210, 66)
const TAB_POST_RECT: Rect2 = Rect2(255, 150, 210, 66)
const TAB_ACH_RECT: Rect2 = Rect2(480, 150, 210, 66)

enum Tab { CAT, POSTCARD, ACHIEVEMENT }

var active_tab: int = Tab.CAT

var _cat_tab: Control
var _postcard_tab: Control
var _achievement_tab: AchievementTab

var _discovered: int = 0
var _total: int = 0


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 猫猫 Tab
	_cat_tab = CatTabScript.new()
	_cat_tab.name = "CatTab"
	_cat_tab.position = Vector2(0, 236)
	_cat_tab.custom_minimum_size = Vector2(DESIGN_SIZE.x, DESIGN_SIZE.y - 236)
	_cat_tab.size = _cat_tab.custom_minimum_size
	add_child(_cat_tab)
	_cat_tab.cat_cell_pressed.connect(_on_cat_cell_pressed)

	# 明信片 Tab
	_postcard_tab = PostcardTabScript.new()
	_postcard_tab.name = "PostcardTab"
	_postcard_tab.position = Vector2(0, 236)
	_postcard_tab.custom_minimum_size = Vector2(DESIGN_SIZE.x, DESIGN_SIZE.y - 236)
	_postcard_tab.size = _postcard_tab.custom_minimum_size
	add_child(_postcard_tab)
	_postcard_tab.postcard_cell_pressed.connect(_on_postcard_cell_pressed)

	# 成就 Tab
	var achievement_scroll := ScrollContainer.new()
	achievement_scroll.name = "AchievementScroll"
	achievement_scroll.position = Vector2(0, 236)
	achievement_scroll.custom_minimum_size = Vector2(DESIGN_SIZE.x, DESIGN_SIZE.y - 236)
	achievement_scroll.size = achievement_scroll.custom_minimum_size
	achievement_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(achievement_scroll)

	var achievement_margin := MarginContainer.new()
	achievement_margin.add_theme_constant_override("margin_left", 28)
	achievement_margin.add_theme_constant_override("margin_right", 28)
	achievement_margin.add_theme_constant_override("margin_top", 20)
	achievement_margin.add_theme_constant_override("margin_bottom", 20)
	achievement_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_scroll.add_child(achievement_margin)

	_achievement_tab = AchievementTabScript.new()
	_achievement_tab.name = "AchievementTab"
	_achievement_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_margin.add_child(_achievement_tab)
	_achievement_tab.setup()

	_apply_tab_visibility()


func on_enter(_data: Dictionary = {}) -> void:
	_refresh()


func _refresh() -> void:
	var cats: Array = HatchEngine.get_cats()
	var discovered_species: Dictionary = {}
	for cat_data: Variant in cats:
		var species: String = _cat_species(cat_data)
		if species != "":
			discovered_species[species] = true
	var all_species: Array = CatDataScript.BREED_COSTS.keys()
	_discovered = discovered_species.size()
	_total = all_species.size()

	_cat_tab.set_data(cats, all_species)

	# 明信片数据
	var collected_ids: Array = ExploreEngine.get_collected_postcard_ids() if ExploreEngine else []
	_postcard_tab.set_data(collected_ids)
	_achievement_tab.setup()
	queue_redraw()


# ---------------------------------------------------------------------------
# 绘制
# ---------------------------------------------------------------------------
func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# 顶部标题
	draw_string(font, Vector2(0, 110), "图鉴", HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 48, Palette.AMBER)
	# 统计
	var stat: String = "已发现: %d/%d" % [_discovered, _total]
	draw_string(font, Vector2(0, 200), stat, HORIZONTAL_ALIGNMENT_CENTER, DESIGN_SIZE.x, 26, Palette.BORDER_DEFAULT)

	# 返回按钮
	draw_rect(BACK_BTN_RECT, Palette.BG_CEMENT, true)
	draw_rect(BACK_BTN_RECT, Palette.BORDER_DEFAULT, false, 2.0)
	draw_string(font, Vector2(BACK_BTN_RECT.position.x, BACK_BTN_RECT.position.y + 34),
		"返回", HORIZONTAL_ALIGNMENT_CENTER, BACK_BTN_RECT.size.x, 26, Palette.AMBER)

	# Tab 按钮
	_draw_tab_button(font, TAB_CAT_RECT, "猫猫", active_tab == Tab.CAT)
	_draw_tab_button(font, TAB_POST_RECT, "明信片", active_tab == Tab.POSTCARD)
	_draw_tab_button(font, TAB_ACH_RECT, "成就", active_tab == Tab.ACHIEVEMENT)


func _draw_tab_button(font: Font, rect: Rect2, label: String, is_active: bool) -> void:
	var bg: Color = Palette.AMBER if is_active else Palette.BG_CEMENT
	draw_rect(rect, bg, true)
	draw_rect(rect, Palette.BORDER_DEFAULT, false, 2.0)
	var text_col: Color = Palette.BG_CEMENT if is_active else Palette.AMBER
	draw_string(font, Vector2(rect.position.x, rect.position.y + 44),
		label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 30, text_col)


# ---------------------------------------------------------------------------
# 输入
# ---------------------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if BACK_BTN_RECT.has_point(p):
			accept_event()
			UIManager.replace("res://scenes/S04_GardenMain.tscn")
		elif TAB_CAT_RECT.has_point(p):
			accept_event()
			_switch_tab(Tab.CAT)
		elif TAB_POST_RECT.has_point(p):
			accept_event()
			_switch_tab(Tab.POSTCARD)
		elif TAB_ACH_RECT.has_point(p):
			accept_event()
			_switch_tab(Tab.ACHIEVEMENT)


func _switch_tab(tab: int) -> void:
	if active_tab == tab:
		return
	active_tab = tab
	_apply_tab_visibility()
	queue_redraw()


func _apply_tab_visibility() -> void:
	if _cat_tab:
		_cat_tab.visible = active_tab == Tab.CAT
	if _postcard_tab:
		_postcard_tab.visible = active_tab == Tab.POSTCARD
	var achievement_scroll := get_node_or_null("AchievementScroll") as ScrollContainer
	if achievement_scroll:
		achievement_scroll.visible = active_tab == Tab.ACHIEVEMENT


func _on_cat_cell_pressed(cat_data: Variant) -> void:
	var popup: Control = DetailPopupScript.new()
	add_child(popup)
	popup.setup(cat_data)


func _on_postcard_cell_pressed(postcard_id: String) -> void:
	var collected_ids: Array = ExploreEngine.get_collected_postcard_ids() if ExploreEngine else []
	var is_collected: bool = collected_ids.has(postcard_id)
	var popup: Control = PostcardPopupScript.new()
	add_child(popup)
	popup.setup(postcard_id, is_collected)


func _cat_species(cat_data: Variant) -> String:
	var value: Variant = _cat_field_raw(cat_data, "species", "")
	return String(value)


func _cat_field_raw(cat_data: Variant, key: String, default: Variant) -> Variant:
	if cat_data == null:
		return default
	if typeof(cat_data) == TYPE_DICTIONARY:
		return cat_data.get(key, default)
	if key in cat_data:
		return cat_data.get(key)
	return default
