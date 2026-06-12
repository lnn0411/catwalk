extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const CARD_HEIGHT := 107.0
const CARD_GAP := 11.0
const GRID_LEFT := 48.0
const GRID_TOP := 215.0
const GRID_WIDTH := 624.0
const TAB_TOP := 123.0
const UI_TEXTURE_PATH := "res://assets/temp/ui/"

var _back_rect: Rect2 = Rect2()
var _card_rects: Array[Rect2] = []
var _card_textures: Array[TextureRect] = []
var _cats: Array = []

# —— M7：NEW 角标（本次会话内新见到的猫；static 跨页面实例存活）——
static var _seen_ids := {}
var _new_ids := {}
var _anim_time := 0.0

func _ready() -> void:
	super._ready()
	_build_texture_layers()
	_refresh_cats()
	set_process(true)

func _process(delta: float) -> void:
	_anim_time += delta
	# 仅当有 epic+ 卡片（流光边框）或 NEW 角标（呼吸）时才每帧重绘
	if not _new_ids.is_empty():
		queue_redraw()
		return
	for c in _cats:
		var r := String(c.rarity)
		if r == CatData.RARITY_EPIC or r == CatData.RARITY_LEGENDARY:
			queue_redraw()
			return

func on_enter(_data: Dictionary = {}) -> void:
	_refresh_cats()
	# 计算本次进入时的"新猫"，随后标记为已见（NEW 只在首次看到的这次展示）
	_new_ids.clear()
	for c in _cats:
		var cid := String(c.id)
		if not _seen_ids.has(cid):
			_new_ids[cid] = true
			_seen_ids[cid] = true

func _gui_input(event: InputEvent) -> void:
	if _is_back_event(event):
		UIManager.replace("res://scenes/S04_GardenMain.tscn")
		accept_event()
		return

	var pos: Variant = _released_position(event)
	if pos == null:
		return
	var point: Vector2 = pos
	if _back_rect.has_point(point):
		UIManager.replace("res://scenes/S04_GardenMain.tscn")
		return
	for i in range(_card_rects.size()):
		if _card_rects[i].has_point(point):
			_open_cat(i)
			return

func _draw() -> void:
	_draw_top_bar()
	_draw_tabs()
	_draw_content()

func _build_texture_layers() -> void:
	var bg := TextureRect.new()
	bg.texture = load(UI_TEXTURE_PATH + "grid_album_bg.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	add_child(bg)

	var back := TextureRect.new()
	back.name = "BackTexture"
	back.texture = load(UI_TEXTURE_PATH + "btn_album.png")
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.show_behind_parent = true
	add_child(back)

func _refresh_cats() -> void:
	_cats = HatchEngine.get_cats() if HatchEngine else []
	queue_redraw()

func _draw_top_bar() -> void:
	_back_rect = Rect2(Vector2(28.0, 59.0), Vector2(85.0, 48.0))
	var back := get_node_or_null("BackTexture") as TextureRect
	if back:
		back.position = _back_rect.position
		back.size = _back_rect.size
	_draw_centered_in_rect("返回", _back_rect, 16, Palette.TEXT_PRIMARY)
	_draw_centered_text("图鉴", 91.0, 24, Palette.TEXT_PRIMARY)

func _draw_tabs() -> void:
	var labels: Array[String] = ["猫咪", "明信片", "成就"]
	var tab_width: float = 192.0
	var start_x: float = (DESIGN_SIZE.x - tab_width * 3.0) * 0.5
	for i in range(labels.size()):
		var rect: Rect2 = Rect2(Vector2(start_x + tab_width * float(i), TAB_TOP), Vector2(tab_width, 48.0))
		var active: bool = i == 0
		_draw_round_rect(rect, 5.0, Palette.AMBER if active else Palette.BG_CEMENT, Palette.BORDER_ACTIVE if active else Palette.BORDER_DEFAULT, 1.0)
		_draw_centered_in_rect(labels[i], rect, 17, Palette.TEXT_ON_AMBER if active else Palette.TEXT_SECONDARY)

func _draw_content() -> void:
	_card_rects.clear()
	_sync_card_textures(_cats.size())
	if _cats.is_empty():
		_draw_centered_in_rect("还没有猫咪。多走几步，第一只就来了", Rect2(Vector2(64.0, 507.0), Vector2(592.0, 64.0)), 19, Palette.TEXT_SECONDARY)
		return

	var card_width: float = (GRID_WIDTH - CARD_GAP) * 0.5
	for i in range(_cats.size()):
		var col: int = i % 2
		var row: int = i / 2
		var rect: Rect2 = Rect2(Vector2(GRID_LEFT + float(col) * (card_width + CARD_GAP), GRID_TOP + float(row) * (CARD_HEIGHT + CARD_GAP)), Vector2(card_width, CARD_HEIGHT))
		_card_rects.append(rect)
		_card_textures[i].position = rect.position
		_card_textures[i].size = rect.size
		_card_textures[i].visible = true
		_draw_cat_card(rect, _cats[i])

func _draw_cat_card(rect: Rect2, cat) -> void:
	# M7：epic/legendary 卡片流光边框
	var rarity := String(cat.rarity)
	if rarity == CatData.RARITY_LEGENDARY:
		var hue := fmod(_anim_time * 0.25, 1.0)
		var glow := Color.from_hsv(hue, 0.40, 1.0, 0.85)
		_draw_round_rect(rect.grow(2.0), 7.0, Color(0, 0, 0, 0), glow, 2.5)
	elif rarity == CatData.RARITY_EPIC:
		var pulse := (sin(_anim_time * 3.0) + 1.0) * 0.5
		_draw_round_rect(rect.grow(2.0), 7.0, Color(0, 0, 0, 0), Color(Palette.RARITY_EPIC, 0.45 + pulse * 0.45), 2.0)

	var swatch_rect: Rect2 = Rect2(rect.position + Vector2(13.0, 16.0), Vector2(59.0, 59.0))
	_draw_round_rect(swatch_rect, 5.0, _cat_color(cat), _rarity_color(cat), 1.0)
	_draw_cat_icon(swatch_rect.position + swatch_rect.size * 0.5, _cat_color(cat), 0.42)

	var text_x: float = rect.position.x + 85.0
	_draw_text(_breed_label(cat), Vector2(text_x, rect.position.y + 30.0), 17, Palette.TEXT_PRIMARY)
	_draw_text("%s  Lv.%d" % [_rarity_label(cat), _cat_level(cat)], Vector2(text_x, rect.position.y + 56.0), 14, _rarity_color(cat))
	_draw_text("亲密 %d" % _cat_friendship(cat), Vector2(text_x, rect.position.y + 80.0), 13, Palette.TEXT_SECONDARY)

	# M7：NEW 角标（呼吸闪烁，右上角）
	if _new_ids.has(String(cat.id)):
		var blink := 0.7 + (sin(_anim_time * 4.0) + 1.0) * 0.15
		var badge := Rect2(rect.position + Vector2(rect.size.x - 56.0, 8.0), Vector2(46.0, 22.0))
		_draw_round_rect(badge, 5.0, Color(Palette.AMBER, blink), Color(Palette.AMBER, blink), 0.0)
		_draw_centered_in_rect("NEW", badge, 12, Palette.TEXT_ON_AMBER)

func _sync_card_textures(count: int) -> void:
	while _card_textures.size() < count:
		var texture_rect := TextureRect.new()
		texture_rect.texture = load(UI_TEXTURE_PATH + "panel_cat_card.png")
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_rect.show_behind_parent = true
		add_child(texture_rect)
		_card_textures.append(texture_rect)
	for i in range(_card_textures.size()):
		_card_textures[i].visible = i < count

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
	draw_circle(center + Vector2(0.0, -16.0) * scale_value, 39.0 * scale_value, color)
	draw_circle(center + Vector2(0.0, 25.0) * scale_value, 45.0 * scale_value, color)
	draw_polygon(PackedVector2Array([
		center + Vector2(-28.0, -47.0) * scale_value,
		center + Vector2(-12.0, -73.0) * scale_value,
		center + Vector2(-5.0, -40.0) * scale_value,
	]), PackedColorArray([color, color, color]))
	draw_polygon(PackedVector2Array([
		center + Vector2(28.0, -47.0) * scale_value,
		center + Vector2(12.0, -73.0) * scale_value,
		center + Vector2(5.0, -40.0) * scale_value,
	]), PackedColorArray([color, color, color]))

func _released_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and not event.pressed:
		return event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		return event.position
	return null

func _is_back_event(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_BACK
	)

func _draw_button(rect: Rect2, text: String, bg: Color, border: Color, text_color: Color) -> void:
	_draw_round_rect(rect, 5.0, bg, border, 1.0)
	_draw_centered_in_rect(text, rect, 16, text_color)

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
	draw_string(font, rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y + text_size.y) * 0.5 - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
