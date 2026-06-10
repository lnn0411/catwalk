extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

const DESIGN_SIZE := Vector2(1080.0, 1920.0)

var _cat = null
var _back_rect: Rect2 = Rect2()
var _rename_rect: Rect2 = Rect2()
var _diary_rect: Rect2 = Rect2()
var _release_rect: Rect2 = Rect2()

func _on_page_setup(data: Dictionary) -> void:
	_cat = data.get("cat", null)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var pos: Variant = _released_position(event)
	if pos == null:
		return
	var point: Vector2 = pos
	if _back_rect.has_point(point):
		UIManager.pop()
	elif _rename_rect.has_point(point):
		Popups.show_toast("改名功能即将开放")
	elif _diary_rect.has_point(point):
		Popups.show_toast("日记还在整理中")
	elif _release_rect.has_point(point):
		Popups.show_toast("%s正在花园里散步" % _cat_name())

func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE, true)
	_draw_top_bar()
	_draw_cat_panel()
	_draw_stats()
	_draw_buttons()
	_draw_diary()

func _draw_top_bar() -> void:
	_back_rect = Rect2(Vector2(42.0, 88.0), Vector2(128.0, 72.0))
	_draw_button(_back_rect, "返回", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_centered_text("猫咪详情", 136.0, 36, Palette.TEXT_PRIMARY)

func _draw_cat_panel() -> void:
	var image_rect: Rect2 = Rect2(Vector2(120.0, 218.0), Vector2(840.0, 400.0))
	_draw_round_rect(image_rect, 8.0, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 2.0)
	draw_circle(image_rect.position + image_rect.size * 0.5, 150.0, Color(_rarity_color(), 0.22))
	_draw_cat_shape(image_rect.position + image_rect.size * 0.5 + Vector2(0.0, 22.0), _cat_color(), 1.1)

	_draw_centered_text("%s · %s" % [_breed_label(), _rarity_label()], 690.0, 30, _rarity_color())
	_draw_centered_text(_cat_name(), 746.0, 42, Palette.TEXT_PRIMARY)

func _draw_stats() -> void:
	var level_panel: Rect2 = Rect2(Vector2(96.0, 820.0), Vector2(888.0, 176.0))
	_draw_round_rect(level_panel, 8.0, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 2.0)
	_draw_text("等级 Lv.%d" % _cat_level(), level_panel.position + Vector2(36.0, 56.0), 28, Palette.TEXT_PRIMARY)
	var ratio: float = clampf(float(_cat_exp() % 100) / 100.0, 0.0, 1.0)
	var bar: Rect2 = Rect2(level_panel.position + Vector2(36.0, 94.0), Vector2(816.0, 22.0))
	_draw_round_rect(bar, 8.0, Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, 1.0)
	_draw_round_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), 8.0, Palette.AMBER, Palette.AMBER, 0.0)
	_draw_text("%d / 100" % (_cat_exp() % 100), level_panel.position + Vector2(36.0, 148.0), 20, Palette.TEXT_SECONDARY)

	var affection_panel: Rect2 = Rect2(Vector2(96.0, 1028.0), Vector2(888.0, 176.0))
	_draw_round_rect(affection_panel, 8.0, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 2.0)
	_draw_text("亲密度", affection_panel.position + Vector2(36.0, 58.0), 28, Palette.TEXT_PRIMARY)
	_draw_text(_heart_text(), affection_panel.position + Vector2(36.0, 116.0), 32, Palette.BRICK_RED)
	_draw_text("孵化日期  %s" % _hatch_date(), Vector2(132.0, 1262.0), 24, Palette.TEXT_SECONDARY)

func _draw_buttons() -> void:
	_rename_rect = Rect2(Vector2(96.0, 1336.0), Vector2(272.0, 78.0))
	_diary_rect = Rect2(Vector2(404.0, 1336.0), Vector2(272.0, 78.0))
	_release_rect = Rect2(Vector2(712.0, 1336.0), Vector2(272.0, 78.0))
	_draw_button(_rename_rect, "改名", Palette.BG_CEMENT, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_button(_diary_rect, "日记", Palette.BG_CEMENT, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_button(_release_rect, "让它出来", Palette.AMBER, Palette.AMBER, Palette.TEXT_ON_AMBER)

func _draw_diary() -> void:
	var rect: Rect2 = Rect2(Vector2(96.0, 1472.0), Vector2(888.0, 318.0))
	_draw_round_rect(rect, 8.0, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 2.0)
	_draw_text("日记", rect.position + Vector2(36.0, 58.0), 30, Palette.TEXT_PRIMARY)
	_draw_text("今天还没有新的记录", rect.position + Vector2(36.0, 116.0), 24, Palette.TEXT_SECONDARY)
	_draw_text("锁定 · 一起散步后解锁更多故事", rect.position + Vector2(36.0, 184.0), 24, Palette.TEXT_SECONDARY)
	draw_line(rect.position + Vector2(36.0, 232.0), rect.position + Vector2(rect.size.x - 36.0, 232.0), Palette.BORDER_DEFAULT, 2.0)
	_draw_text("锁定 · 达到 Lv.3 解锁", rect.position + Vector2(36.0, 282.0), 22, Palette.TEXT_SECONDARY)

func _cat_name() -> String:
	if _cat == null:
		return "未命名猫咪"
	return String(_cat.display_name)

func _cat_level() -> int:
	return int(_cat.level) if _cat != null else 1

func _cat_exp() -> int:
	return int(_cat.exp) if _cat != null else 0

func _cat_friendship() -> int:
	return int(_cat.friendship) if _cat != null else 0

func _heart_text() -> String:
	var filled: int = clampi(int(floor(float(_cat_friendship()) / 20.0)), 0, 5)
	var text: String = ""
	for i in range(5):
		text += "♥" if i < filled else "♡"
	return text

func _hatch_date() -> String:
	var unix_time: float = float(_cat.created_at) if _cat != null else Time.get_unix_time_from_system()
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix_time))
	return "%04d-%02d-%02d" % [int(date.get("year", 1970)), int(date.get("month", 1)), int(date.get("day", 1))]

func _breed_label() -> String:
	var species: String = String(_cat.species) if _cat != null else CatData.BREED_ORANGE
	match species:
		CatData.BREED_BRITISH:
			return "英短"
		CatData.BREED_SIAMESE:
			return "暹罗"
		_:
			return "橘猫"

func _rarity_label() -> String:
	var rarity: String = String(_cat.rarity) if _cat != null else CatData.RARITY_COMMON
	match rarity:
		CatData.RARITY_RARE:
			return "稀有"
		CatData.RARITY_EPIC:
			return "史诗"
		CatData.RARITY_LEGENDARY:
			return "传说"
		_:
			return "普通"

func _cat_color() -> Color:
	var species: String = String(_cat.species) if _cat != null else CatData.BREED_ORANGE
	match species:
		CatData.BREED_BRITISH:
			return Palette.CAT_BRIT_MID
		CatData.BREED_SIAMESE:
			return Palette.CAT_SIAM_BODY
		_:
			return Palette.CAT_ORANGE_MID

func _rarity_color() -> Color:
	var rarity: String = String(_cat.rarity) if _cat != null else CatData.RARITY_COMMON
	match rarity:
		CatData.RARITY_RARE:
			return Palette.RARITY_RARE
		CatData.RARITY_EPIC:
			return Palette.RARITY_EPIC
		CatData.RARITY_LEGENDARY:
			return Palette.RARITY_LEG_A
		_:
			return Palette.AMBER

func _draw_cat_shape(center: Vector2, color: Color, scale_value: float) -> void:
	draw_circle(center + Vector2(0.0, -70.0) * scale_value, 95.0 * scale_value, color)
	draw_circle(center + Vector2(0.0, 84.0) * scale_value, 120.0 * scale_value, color)
	draw_polygon(PackedVector2Array([
		center + Vector2(-70.0, -140.0) * scale_value,
		center + Vector2(-26.0, -198.0) * scale_value,
		center + Vector2(-10.0, -124.0) * scale_value,
	]), PackedColorArray([color, color, color]))
	draw_polygon(PackedVector2Array([
		center + Vector2(70.0, -140.0) * scale_value,
		center + Vector2(26.0, -198.0) * scale_value,
		center + Vector2(10.0, -124.0) * scale_value,
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
