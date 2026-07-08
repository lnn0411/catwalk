extends "res://ui/UIPage.gd"

# ============================================================
# S11 我的 / 设置
# Control 节点布局（锚点 + 容器），样式统一走 Palette，禁止硬编码颜色。
# 历史版本基于 _draw() + TextureRect 像素摆放，已废弃。
# ============================================================

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const HOME_SCENE := "res://scenes/S04_GardenMain.tscn"
const FRIENDS_SCENE := "res://scenes/S13_Friends.tscn"

const SIDE_MARGIN := 48
const ROW_PAD_H := 20
const ROW_PAD_V := 12


# 自绘开关：圆角轨道 + 圆形滑块，on=AMBER / off=BORDER
class ToggleSwitch:
	extends Button

	signal toggled_state(on: bool)

	var on: bool = false
	var _track := StyleBoxFlat.new()

	func _init() -> void:
		custom_minimum_size = Vector2(52.0, 30.0)
		focus_mode = Control.FOCUS_NONE
		_track.set_corner_radius_all(15)
		# 抹掉 Button 自带的底框，完全由 _draw 接管
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(s, empty)
		pressed.connect(_on_pressed)

	func _on_pressed() -> void:
		on = not on
		queue_redraw()
		toggled_state.emit(on)

	func set_on(value: bool) -> void:
		on = value
		queue_redraw()

	func _draw() -> void:
		_track.bg_color = Palette.AMBER if on else Palette.BORDER
		draw_style_box(_track, Rect2(Vector2.ZERO, size))
		var r: float = size.y * 0.5 - 4.0
		var cx: float = (size.x - size.y * 0.5) if on else size.y * 0.5
		draw_circle(Vector2(cx, size.y * 0.5), r, Color.WHITE)


var _push_notifications: bool = true
var _sound_enabled: bool = true
var _music_enabled: bool = true
var _toggles: Dictionary = {}
var _back_btn: Button


func _ready() -> void:
	super._ready()
	if has_node("Bg"):
		(%Bg as ColorRect).color = Palette.PAPER_CREAM
	_load_settings()
	_build_ui()


func on_enter(_data: Dictionary = {}) -> void:
	_load_settings()
	for idx in _toggles:
		(_toggles[idx] as ToggleSwitch).set_on(_value_for(int(idx)))


func _gui_input(event: InputEvent) -> void:
	if _is_back_event(event):
		_on_back()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _is_back_event(event):
		_on_back()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- 构建 UI

func _build_ui() -> void:
	if has_node("PageHead"):
		get_node("PageHead").queue_free()
	if has_node("Body"):
		get_node("Body").queue_free()

	_build_head()
	_build_body()


func _build_head() -> void:
	var head := HBoxContainer.new()
	head.name = "PageHead"
	head.position = Vector2(28.0, 54.0)
	head.add_theme_constant_override("separation", 12)

	_back_btn = _circle_btn("‹")
	_back_btn.pressed.connect(_on_back)
	head.add_child(_back_btn)

	var title := _label("我的", 17, Palette.TEXT_PRIMARY)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0.0, 34.0)
	head.add_child(title)

	add_child(head)


func _build_body() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Body"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 104.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var pad := MarginContainer.new()
	pad.custom_minimum_size = Vector2(DESIGN_SIZE.x, 0.0)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", SIDE_MARGIN)
	pad.add_theme_constant_override("margin_right", SIDE_MARGIN)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", SIDE_MARGIN)
	scroll.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 16)
	pad.add_child(vbox)

	vbox.add_child(_profile_card())
	vbox.add_child(_entry_row())
	vbox.add_child(_settings_section())
	vbox.add_child(_info_section())


func _profile_card() -> PanelContainer:
	var card := _card_panel(16)
	var margin := _inner_margin(18, 18, 18, 18)
	card.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	margin.add_child(hb)

	var icon := _label("🐱", 32, Palette.TEXT_PRIMARY)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 4)
	info.add_child(_label("花园管家", 15, Palette.TEXT_PRIMARY))
	info.add_child(_label("累计 %s 步" % _format_int(_total_steps()), 10, Palette.TEXT_SECONDARY))
	hb.add_child(info)

	return card


func _entry_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_entry_card("👭", "好友", _on_friends))
	row.add_child(_entry_card("🎀", "礼物背包", func() -> void: UIManager.push("res://scenes/S13_Backpack.tscn")))
	row.add_child(_entry_card("✉️", "信箱", func() -> void: Popups.show_toast("即将开放")))
	return row


func _entry_card(emoji: String, text: String, cb: Callable) -> PanelContainer:
	var card := _card_panel(14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 92.0)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)

	var e := _label(emoji, 26, Palette.TEXT_PRIMARY)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(e)

	var t := _label(text, 12, Palette.TEXT_PRIMARY)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(t)

	card.add_child(vb)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(cb)
	card.add_child(btn)

	return card


func _settings_section() -> PanelContainer:
	var card := _card_panel(16)
	var margin := _inner_margin(0, 6, 0, 6)
	card.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	margin.add_child(vb)

	vb.add_child(_setting_row("🔔 通知", 0))
	vb.add_child(_divider())
	vb.add_child(_setting_row("🎵 音效", 1))
	vb.add_child(_divider())
	vb.add_child(_setting_row("🎶 音乐", 2))
	vb.add_child(_divider())
	vb.add_child(_value_row("👟 步数权限", "已授权"))

	return card


func _info_section() -> PanelContainer:
	var card := _card_panel(16)
	var margin := _inner_margin(0, 6, 0, 6)
	card.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	margin.add_child(vb)

	vb.add_child(_info_row("🌐 语言", "简体中文", "语言"))
	vb.add_child(_divider())
	vb.add_child(_info_row("📤 导出存档", "JSON", "导出存档"))
	vb.add_child(_divider())
	vb.add_child(_info_row("🔒 隐私政策", "", "隐私政策"))
	vb.add_child(_divider())
	vb.add_child(_info_row("ℹ️ 关于 v1.0.0", "", "关于 v1.0.0"))

	return card


# ---------------------------------------------------------------- 行

func _setting_row(text: String, idx: int) -> PanelContainer:
	var hb := _row_hbox()
	hb.add_child(_row_label(text))

	var toggle := ToggleSwitch.new()
	toggle.set_on(_value_for(idx))
	toggle.toggled_state.connect(func(on: bool) -> void: _on_toggle(idx, on))
	_toggles[idx] = toggle
	hb.add_child(toggle)

	return _plain_row(hb)


func _value_row(text: String, value: String) -> PanelContainer:
	var hb := _row_hbox()
	hb.add_child(_row_label(text))
	var v := _label(value, 13, Palette.TEXT_SECONDARY)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(v)
	return _plain_row(hb)


func _info_row(text: String, value: String, toast: String) -> PanelContainer:
	var hb := _row_hbox()
	hb.add_child(_row_label(text))
	if value != "":
		var v := _label(value, 13, Palette.TEXT_SECONDARY)
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(v)
	var chevron := _label("›", 18, Palette.TEXT_SECONDARY)
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(chevron)
	return _click_row(hb, func() -> void: Popups.show_toast(toast))


func _row_hbox() -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0.0, 30.0)
	hb.add_theme_constant_override("separation", 8)
	return hb


func _row_label(text: String) -> Label:
	var l := _label(text, 14, Palette.TEXT_PRIMARY)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _row_holder() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxEmpty.new()
	s.set_content_margin(SIDE_LEFT, ROW_PAD_H)
	s.set_content_margin(SIDE_RIGHT, ROW_PAD_H)
	s.set_content_margin(SIDE_TOP, ROW_PAD_V)
	s.set_content_margin(SIDE_BOTTOM, ROW_PAD_V)
	p.add_theme_stylebox_override("panel", s)
	return p


func _plain_row(content: Control) -> PanelContainer:
	var p := _row_holder()
	p.add_child(content)
	return p


func _click_row(content: Control, cb: Callable) -> PanelContainer:
	var p := _row_holder()
	p.add_child(content)
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(cb)
	p.add_child(btn)
	return p


func _divider() -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", ROW_PAD_H)
	m.add_theme_constant_override("margin_right", ROW_PAD_H)
	var line := ColorRect.new()
	line.color = Palette.BORDER
	line.custom_minimum_size = Vector2(0.0, 1.0)
	m.add_child(line)
	return m


# ---------------------------------------------------------------- 交互

func _on_back() -> void:
	UIManager.replace(HOME_SCENE)


func _on_friends() -> void:
	UIManager.push(FRIENDS_SCENE)


func _on_toggle(idx: int, on: bool) -> void:
	match idx:
		0:
			_push_notifications = on
		1:
			_sound_enabled = on
		2:
			_music_enabled = on
	_save_settings()


func _value_for(idx: int) -> bool:
	match idx:
		0:
			return _push_notifications
		1:
			return _sound_enabled
		2:
			return _music_enabled
	return false


# ---------------------------------------------------------------- 存档

func _load_settings() -> void:
	if SaveManager == null:
		return
	_push_notifications = bool(SaveManager._config.get_value("settings", "push_notifications", true))
	_sound_enabled = bool(SaveManager._config.get_value("settings", "sound_enabled", true))
	_music_enabled = bool(SaveManager._config.get_value("settings", "music_enabled", true))


func _save_settings() -> void:
	if SaveManager == null:
		return
	SaveManager._config.set_value("settings", "push_notifications", _push_notifications)
	SaveManager._config.set_value("settings", "sound_enabled", _sound_enabled)
	SaveManager._config.set_value("settings", "music_enabled", _music_enabled)
	SaveManager._config.save(SaveManager.SAVE_PATH)


# ---------------------------------------------------------------- 样式辅助

func _card_panel(radius: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.MILK_WHITE
	s.border_color = Palette.BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
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


func _circle_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(34.0, 34.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	b.add_theme_color_override("font_hover_color", Palette.TEXT_PRIMARY)
	b.add_theme_color_override("font_pressed_color", Palette.TEXT_PRIMARY)
	b.add_theme_stylebox_override("normal", _circle_style(Palette.MILK_WHITE))
	b.add_theme_stylebox_override("hover", _circle_style(Palette.MILK_WHITE))
	b.add_theme_stylebox_override("pressed", _circle_style(Palette.BORDER))
	return b


func _circle_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Palette.BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(17)
	return s


func _label(text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l


# ---------------------------------------------------------------- 工具

func _total_steps() -> int:
	if StepEngine and StepEngine.has_method("get_total_steps"):
		return int(StepEngine.get_total_steps())
	return 142300


func _format_int(n: int) -> String:
	var digits := str(max(n, 0))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


func _is_back_event(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_BACK
	)
