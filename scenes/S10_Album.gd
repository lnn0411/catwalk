extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const CARD_HEIGHT := 160.0
const CARD_GAP := 16.0
const GRID_LEFT := 72.0
const GRID_TOP := 322.0
const GRID_WIDTH := 936.0
const TAB_TOP := 184.0

var _back_rect: Rect2 = Rect2()
var _card_rects: Array[Rect2] = []
var _cats: Array = []

func _ready() -> void:
	super._ready()
	_refresh_cats()

func on_enter(_data: Dictionary = {}) -> void:
	_refresh_cats()

func _gui_input(event: InputEvent) -> void:
	var pos: Variant = _released_position(event)
	if pos == null:
		return
	var point: Vector2 = pos
	if _back_rect.has_point(point):
		UIManager.pop()
		return
	for i in range(_card_rects.size()):
		if _card_rects[i].has_point(point):
			_open_cat(i)
			return

func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE, true)
	_draw_top_bar()
	_draw_tabs()
	_draw_content()

func _refresh_cats() -> void:
	_cats = HatchEngine.get_cats() if HatchEngine else []
	queue_redraw()

func _draw_top_bar() -> void:
	_back_rect = Rect2(Vector2(42.0, 88.0), Vector2(128.0, 72.0))
	_draw_button(_back_rect, "返回", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_centered_text("图鉴", 136.0, 36, Palette.TEXT_PRIMARY)

func _draw_tabs() -> void:
	var labels: Array[String] = ["猫咪", "明信片", "成就"]
	var tab_width: float = 288.0
	var start_x: float = (DESIGN_SIZE.x - tab_width * 3.0) * 0.5
	for i in range(labels.size()):
		var rect: Rect2 = Rect2(Vector2(start_x + tab_width * float(i), TAB_TOP), Vector2(tab_width, 72.0))
		var active: bool = i == 0
		_draw_round_rect(rect, 8.0, Palette.AMBER if active else Palette.BG_CEMENT, Palette.BORDER_ACTIVE if active else Palette.BORDER_DEFAULT, 2.0)
		_draw_centered_in_rect(labels[i], rect, 26, Palette.TEXT_ON_AMBER if active else Palette.TEXT_SECONDARY)

func _draw_content() -> void:
	_card_rects.clear()
	if _cats.is_empty():
		_draw_centered_in_rect("还没有猫咪。多走几步，第一只就来了", Rect2(Vector2(96.0, 760.0), Vector2(888.0, 96.0)), 28, Palette.TEXT_SECONDARY)
		return

	var card_width: float = (GRID_WIDTH - CARD_GAP) * 0.5
	for i in range(_cats.size()):
		var col: int = i % 2
		var row: int = i / 2
		var rect: Rect2 = Rect2(Vector2(GRID_LEFT + float(col) * (card_width + CARD_GAP), GRID_TOP + float(row) * (CARD_HEIGHT + CARD_GAP)), Vector2(card_width, CARD_HEIGHT))
		_card_rects.append(rect)
		_draw_cat_card(rect, _cats[i])

func _draw_cat_card(rect: Rect2, cat) -> void:
	_draw_round_rect(rect, 8.0, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 2.0)
	var swatch_rect: Rect2 = Rect2(rect.position + Vector2(20.0, 24.0), Vector2(88.0, 88.0))
	_draw_round_rect(swatch_rect, 8.0, _cat_color(cat), _rarity_color(cat), 2.0)
	_draw_cat_icon(swatch_rect.position + swatch_rect.size * 0.5, _cat_color(cat), 0.42)

	var text_x: float = rect.position.x + 128.0
	_draw_text(_breed_label(cat), Vector2(text_x, rect.position.y + 45.0), 25, Palette.TEXT_PRIMARY)
	_draw_text("%s  Lv.%d" % [_rarity_label(cat), _cat_level(cat)], Vector2(text_x, rect.position.y + 84.0), 21, _rarity_color(cat))
	_draw_text("亲密 %d" % _cat_friendship(cat), Vector2(text_x, rect.position.y + 120.0), 20, Palette.TEXT_SECONDARY)

func _open_cat(index: int) -> void:
	if index < 0 or index >= _cats.size():
		return
	UIManager.push("res://scenes/S10_CatDetail.tscn", {"cat": _cats[index]})

func _cat_level(cat) -> int:
	return int(cat.level) if cat != null else 1

func _cat_friendship(cat) -> int:
	return int(cat.friendship) if cat != null else 0

func _breed_label(cat) -> String:
	var species: String = String(cat.species) if cat != null else CatData.BREED_ORANGE
	match species:
		CatData.BREED_BRITISH:
			return "英短"
		CatData.BREED_SIAMESE:
			return "暹罗"
		_:
			return "橘猫"

func _rarity_label(cat) -> String:
	var rarity: String = String(cat.rarity) if cat != null else CatData.RARITY_COMMON
	match rarity:
		CatData.RARITY_RARE:
			return "稀有"
		CatData.RARITY_EPIC:
			return "史诗"
		CatData.RARITY_LEGENDARY:
			return "传说"
		_:
			return "普通"

func _cat_color(cat) -> Color:
	var species: String = String(cat.species) if cat != null else CatData.BREED_ORANGE
	match species:
		CatData.BREED_BRITISH:
			return Palette.CAT_BRIT_LIGHT
		CatData.BREED_SIAMESE:
			return Palette.CAT_SIAM_BODY
		_:
			return Palette.CAT_ORANGE_LIGHT

func _rarity_color(cat) -> Color:
	var rarity: String = String(cat.rarity) if cat != null else CatData.RARITY_COMMON
	match rarity:
		CatData.RARITY_RARE:
			return Palette.RARITY_RARE
		CatData.RARITY_EPIC:
			return Palette.RARITY_EPIC
		CatData.RARITY_LEGENDARY:
			return Palette.RARITY_LEG_A
		_:
			return Palette.AMBER

func _draw_cat_icon(center: Vector2, color: Color, scale_value: float) -> void:
	draw_circle(center + Vector2(0.0, -24.0) * scale_value, 58.0 * scale_value, color)
	draw_circle(center + Vector2(0.0, 38.0) * scale_value, 68.0 * scale_value, color)
	draw_polygon(PackedVector2Array([
		center + Vector2(-42.0, -70.0) * scale_value,
		center + Vector2(-18.0, -110.0) * scale_value,
		center + Vector2(-8.0, -60.0) * scale_value,
	]), PackedColorArray([color, color, color]))
	draw_polygon(PackedVector2Array([
		center + Vector2(42.0, -70.0) * scale_value,
		center + Vector2(18.0, -110.0) * scale_value,
		center + Vector2(8.0, -60.0) * scale_value,
	]), PackedColorArray([color, color, color]))

func _released_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and not event.pressed:
		return event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		return event.position
	return null

func _draw_button(rect: Rect2, text: String, bg: Color, border: Color, text_color: Color) -> void:
	_draw_round_rect(rect, 8.0, bg, border, 2.0)
	_draw_centered_in_rect(text, rect, 24, text_color)

func _draw_round_rect(rect: Rect2, _radius: float, bg: Color, border: Color, border_width: float) -> void:
	draw_rect(rect, bg, true)
	if border_width > 0.0:
		draw_rect(rect, border, false, border_width)

func _draw_text(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(get_theme_default_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((DESIGN_SIZE.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_centered_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y + text_size.y) * 0.5 - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
