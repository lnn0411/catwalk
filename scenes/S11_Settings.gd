extends "res://ui/UIPage.gd"

const DESIGN_SIZE := Vector2(1080.0, 1920.0)

var _back_rect: Rect2 = Rect2()
var _toggle_rects: Array[Rect2] = []
var _row_rects: Array[Rect2] = []
var _clear_rect: Rect2 = Rect2()
var _push_notifications: bool = true
var _sound_enabled: bool = true
var _music_enabled: bool = true

func _ready() -> void:
	super._ready()
	_load_settings()

func on_enter(_data: Dictionary = {}) -> void:
	_load_settings()

func _gui_input(event: InputEvent) -> void:
	var pos: Variant = _released_position(event)
	if pos == null:
		return
	var point: Vector2 = pos
	if _back_rect.has_point(point):
		UIManager.pop()
		return
	for i in range(_toggle_rects.size()):
		if _toggle_rects[i].has_point(point):
			_toggle_setting(i)
			return
	for i in range(_row_rects.size()):
		if _row_rects[i].has_point(point):
			Popups.show_toast("即将开放")
			return
	if _clear_rect.has_point(point):
		Popups.show_confirm("清除缓存", "当前缓存约 12.5 MB，确认清除？", func() -> void:
			Popups.show_toast("缓存已清除")
		)

func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE, true)
	_draw_top_bar()
	_draw_toggles()
	_draw_rows()
	_draw_clear_cache()

func _draw_top_bar() -> void:
	_back_rect = Rect2(Vector2(42.0, 88.0), Vector2(128.0, 72.0))
	_draw_button(_back_rect, "返回", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_centered_text("设置", 136.0, 36, Palette.TEXT_PRIMARY)

func _draw_toggles() -> void:
	_toggle_rects.clear()
	var labels: Array[String] = ["推送通知", "音效", "音乐"]
	var values: Array[bool] = [_push_notifications, _sound_enabled, _music_enabled]
	var panel: Rect2 = Rect2(Vector2(72.0, 228.0), Vector2(936.0, 300.0))
	_draw_round_rect(panel, 8.0, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 2.0)
	for i in range(labels.size()):
		var y: float = panel.position.y + 36.0 + float(i) * 86.0
		_draw_text(labels[i], Vector2(panel.position.x + 36.0, y + 42.0), 28, Palette.TEXT_PRIMARY)
		var toggle_rect: Rect2 = Rect2(Vector2(panel.position.x + panel.size.x - 158.0, y + 8.0), Vector2(104.0, 54.0))
		_toggle_rects.append(toggle_rect)
		_draw_toggle(toggle_rect, values[i])
		if i < labels.size() - 1:
			draw_line(Vector2(panel.position.x + 36.0, y + 80.0), Vector2(panel.position.x + panel.size.x - 36.0, y + 80.0), Palette.BORDER_DEFAULT, 1.0)

func _draw_rows() -> void:
	_row_rects.clear()
	var rows: Array[String] = ["语言", "关于", "隐私", "协议"]
	var panel: Rect2 = Rect2(Vector2(72.0, 584.0), Vector2(936.0, 392.0))
	_draw_round_rect(panel, 8.0, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 2.0)
	for i in range(rows.size()):
		var row_rect: Rect2 = Rect2(Vector2(panel.position.x, panel.position.y + float(i) * 98.0), Vector2(panel.size.x, 98.0))
		_row_rects.append(row_rect)
		_draw_text(rows[i], row_rect.position + Vector2(36.0, 58.0), 28, Palette.TEXT_PRIMARY)
		_draw_text(">", row_rect.position + Vector2(row_rect.size.x - 64.0, 58.0), 28, Palette.TEXT_SECONDARY)
		if i < rows.size() - 1:
			draw_line(row_rect.position + Vector2(36.0, row_rect.size.y), row_rect.position + Vector2(row_rect.size.x - 36.0, row_rect.size.y), Palette.BORDER_DEFAULT, 1.0)

func _draw_clear_cache() -> void:
	_clear_rect = Rect2(Vector2(72.0, 1032.0), Vector2(936.0, 98.0))
	_draw_round_rect(_clear_rect, 8.0, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 2.0)
	_draw_text("清除缓存", _clear_rect.position + Vector2(36.0, 60.0), 28, Palette.TEXT_PRIMARY)
	_draw_text("12.5 MB>", _clear_rect.position + Vector2(_clear_rect.size.x - 176.0, 60.0), 24, Palette.TEXT_SECONDARY)

func _draw_toggle(rect: Rect2, enabled: bool) -> void:
	var bg: Color = Palette.AMBER if enabled else Palette.BORDER_DEFAULT
	_draw_round_rect(rect, 27.0, bg, bg, 0.0)
	var knob_x: float = rect.position.x + 76.0 if enabled else rect.position.x + 28.0
	draw_circle(Vector2(knob_x, rect.position.y + rect.size.y * 0.5), 22.0, Palette.BG_WARM_WHITE)

func _toggle_setting(index: int) -> void:
	match index:
		0:
			_push_notifications = not _push_notifications
		1:
			_sound_enabled = not _sound_enabled
		2:
			_music_enabled = not _music_enabled
	_save_settings()
	queue_redraw()

func _load_settings() -> void:
	if SaveManager == null:
		return
	_push_notifications = bool(SaveManager._config.get_value("settings", "push_notifications", true))
	_sound_enabled = bool(SaveManager._config.get_value("settings", "sound_enabled", true))
	_music_enabled = bool(SaveManager._config.get_value("settings", "music_enabled", true))
	queue_redraw()

func _save_settings() -> void:
	if SaveManager == null:
		return
	SaveManager._config.set_value("settings", "push_notifications", _push_notifications)
	SaveManager._config.set_value("settings", "sound_enabled", _sound_enabled)
	SaveManager._config.set_value("settings", "music_enabled", _music_enabled)
	SaveManager._config.save(SaveManager.SAVE_PATH)

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
