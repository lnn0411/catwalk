extends "res://ui/UIPage.gd"

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const UI_TEXTURE_PATH := "res://assets/temp/ui/"

var _back_rect: Rect2 = Rect2()
var _toggle_rects: Array[Rect2] = []
var _row_rects: Array[Rect2] = []
var _clear_rect: Rect2 = Rect2()
var _toggle_buttons: Array[TextureButton] = []
var _push_notifications: bool = true
var _sound_enabled: bool = true
var _music_enabled: bool = true

func _ready() -> void:
	super._ready()
	_build_texture_layers()
	_load_settings()

func on_enter(_data: Dictionary = {}) -> void:
	_load_settings()

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

func _build_texture_layers() -> void:
	var back := TextureRect.new()
	back.name = "BackTexture"
	var back_formal := "res://assets/art/ui/buttons/btn_settings.png"
	var back_fallback := UI_TEXTURE_PATH + "btn_settings.png"
	if ResourceLoader.exists(back_formal):
		back.texture = load(back_formal)
	else:
		back.texture = load(back_fallback)
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.show_behind_parent = true
	add_child(back)

	for name in ["TogglePanelTexture", "RowsPanelTexture", "ClearTexture"]:
		var panel := TextureRect.new()
		panel.name = name
		var formal_file := "buttons/btn_secondary.png" if name == "ClearTexture" else "panels/panel_settings.png"
		var formal_path := "res://assets/art/ui/" + formal_file
		var fallback_path := UI_TEXTURE_PATH + ("btn_secondary.png" if name == "ClearTexture" else "panel_settings.png")
		if ResourceLoader.exists(formal_path):
			panel.texture = load(formal_path)
		else:
			panel.texture = load(fallback_path)
		panel.stretch_mode = TextureRect.STRETCH_SCALE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.show_behind_parent = true
		add_child(panel)

	for i in range(3):
		var toggle := TextureButton.new()
		var toggle_formal := "res://assets/art/ui/panels/toggle_on.png"
		var toggle_fallback := UI_TEXTURE_PATH + "toggle_on.png"
		if ResourceLoader.exists(toggle_formal):
			toggle.texture_normal = load(toggle_formal)
		else:
			toggle.texture_normal = load(toggle_fallback)
		toggle.texture_pressed = toggle.texture_normal
		toggle.texture_hover = toggle.texture_normal
		toggle.stretch_mode = TextureButton.STRETCH_SCALE
		toggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toggle.show_behind_parent = true
		add_child(toggle)
		_toggle_buttons.append(toggle)

func _draw_top_bar() -> void:
	_back_rect = Rect2(Vector2(28.0, 59.0), Vector2(85.0, 48.0))
	var back := get_node_or_null("BackTexture") as TextureRect
	if back:
		back.position = _back_rect.position
		back.size = _back_rect.size
	_draw_centered_in_rect("返回", _back_rect, 16, Palette.TEXT_PRIMARY)
	_draw_centered_text("设置", 91.0, 24, Palette.TEXT_PRIMARY)

func _draw_toggles() -> void:
	_toggle_rects.clear()
	var labels: Array[String] = ["推送通知", "音效", "音乐"]
	var values: Array[bool] = [_push_notifications, _sound_enabled, _music_enabled]
	var panel: Rect2 = Rect2(Vector2(48.0, 152.0), Vector2(624.0, 200.0))
	var panel_texture := get_node_or_null("TogglePanelTexture") as TextureRect
	if panel_texture:
		panel_texture.position = panel.position
		panel_texture.size = panel.size
	for i in range(labels.size()):
		var y: float = panel.position.y + 24.0 + float(i) * 57.0
		_draw_text(labels[i], Vector2(panel.position.x + 24.0, y + 28.0), 19, Palette.TEXT_PRIMARY)
		var toggle_rect: Rect2 = Rect2(Vector2(panel.position.x + panel.size.x - 105.0, y + 5.0), Vector2(69.0, 36.0))
		_toggle_rects.append(toggle_rect)
		if i < _toggle_buttons.size():
			_toggle_buttons[i].position = toggle_rect.position
			_toggle_buttons[i].size = toggle_rect.size
			var toggle_file := "toggle_on.png" if values[i] else "toggle_off.png"
			var toggle_formal := "res://assets/art/ui/panels/" + toggle_file
			var toggle_fallback := UI_TEXTURE_PATH + toggle_file
			if ResourceLoader.exists(toggle_formal):
				_toggle_buttons[i].texture_normal = load(toggle_formal)
			else:
				_toggle_buttons[i].texture_normal = load(toggle_fallback)
			_toggle_buttons[i].texture_pressed = _toggle_buttons[i].texture_normal
			_toggle_buttons[i].texture_hover = _toggle_buttons[i].texture_normal
		if i < labels.size() - 1:
			draw_line(Vector2(panel.position.x + 24.0, y + 53.0), Vector2(panel.position.x + panel.size.x - 24.0, y + 53.0), Palette.BORDER_DEFAULT, 1.0)

func _draw_rows() -> void:
	_row_rects.clear()
	var rows: Array[String] = ["语言", "关于", "隐私", "协议"]
	var panel: Rect2 = Rect2(Vector2(48.0, 389.0), Vector2(624.0, 261.0))
	var panel_texture := get_node_or_null("RowsPanelTexture") as TextureRect
	if panel_texture:
		panel_texture.position = panel.position
		panel_texture.size = panel.size
	for i in range(rows.size()):
		var row_rect: Rect2 = Rect2(Vector2(panel.position.x, panel.position.y + float(i) * 65.0), Vector2(panel.size.x, 65.0))
		_row_rects.append(row_rect)
		_draw_text(rows[i], row_rect.position + Vector2(24.0, 39.0), 19, Palette.TEXT_PRIMARY)
		_draw_text(">", row_rect.position + Vector2(row_rect.size.x - 43.0, 39.0), 19, Palette.TEXT_SECONDARY)
		if i < rows.size() - 1:
			draw_line(row_rect.position + Vector2(24.0, row_rect.size.y), row_rect.position + Vector2(row_rect.size.x - 24.0, row_rect.size.y), Palette.BORDER_DEFAULT, 1.0)

func _draw_clear_cache() -> void:
	_clear_rect = Rect2(Vector2(48.0, 688.0), Vector2(624.0, 65.0))
	var clear_texture := get_node_or_null("ClearTexture") as TextureRect
	if clear_texture:
		clear_texture.position = _clear_rect.position
		clear_texture.size = _clear_rect.size
	_draw_text("清除缓存", _clear_rect.position + Vector2(24.0, 40.0), 19, Palette.TEXT_PRIMARY)
	_draw_text("12.5 MB>", _clear_rect.position + Vector2(_clear_rect.size.x - 117.0, 40.0), 16, Palette.TEXT_SECONDARY)

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
