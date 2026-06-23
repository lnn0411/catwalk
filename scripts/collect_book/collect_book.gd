extends "res://ui/UIPage.gd"
## 图鉴主面板 —— 全屏 Control。
## 内部托管 CatTab（猫猫图鉴）与 PostcardTab（明信片占位），
## 顶部标题 + 已发现统计 + TabBar（两个 Tab 按钮）+ 返回按钮。
## 所有 UI 全用 _draw() 代码绘制。

const DESIGN_SIZE: Vector2 = Vector2(720, 1280)

const CatTabScript: GDScript = preload("res://scripts/collect_book/cat_tab.gd")
const PostcardTabScript: GDScript = preload("res://scripts/collect_book/postcard_tab.gd")
const DetailPopupScript: GDScript = preload("res://scripts/collect_book/cat_detail_popup.gd")
const PostcardPopupScript: GDScript = preload("res://scripts/collect_book/postcard_detail_popup.gd")

# 点击热区（设计坐标系）
const BACK_BTN_RECT: Rect2 = Rect2(28, 59, 85, 48)
const TAB_CAT_RECT: Rect2 = Rect2(48, 150, 300, 66)
const TAB_POST_RECT: Rect2 = Rect2(372, 150, 300, 66)

enum Tab { CAT, POSTCARD }

var active_tab: int = Tab.CAT

var _cat_tab: Control
var _postcard_tab: Control

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

	_apply_tab_visibility()


func on_enter(_data: Dictionary = {}) -> void:
	_refresh()


func _refresh() -> void:
	var cats: Array = HatchEngine.get_cats()
	_discovered = cats.size()
	_total = cats.size()

	_cat_tab.set_data(cats)

	# 明信片数据
	var collected_ids: Array = ExploreEngine._collected_postcards if ExploreEngine else []
	_postcard_tab.set_data(collected_ids)
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


func _on_cat_cell_pressed(cat_data: Variant) -> void:
	var popup: Control = DetailPopupScript.new()
	add_child(popup)
	popup.setup(cat_data)


func _on_postcard_cell_pressed(postcard_id: String) -> void:
	var collected_ids: Array = ExploreEngine._collected_postcards if ExploreEngine else []
	var is_collected: bool = collected_ids.has(postcard_id)
	var popup: Control = PostcardPopupScript.new()
	add_child(popup)
	popup.setup(postcard_id, is_collected)
