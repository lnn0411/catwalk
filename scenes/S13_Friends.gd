extends "res://ui/UIPage.gd"

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const FRIENDS_BG_PATH := "res://assets/art/ui/friends_bg.png"
const CFG_PATH := "user://friends.cfg"
const CFG_SECTION := "friends"

const DEFAULT_FRIENDS := [
	{"nickname": "散步达人", "steps": 8523},
	{"nickname": "猫步新手", "steps": 2341},
	{"nickname": "健走冠军", "steps": 15678},
]

const FAKE_NAMES := ["HappyCat", "TinyPaws", "Mocha", "FurryBall", "MewMew", "SunnyPaw", "MilkTea", "LuckyCat"]
const INVITE_PREFIX := "CAT-"
const INVITE_CODE_LEN := 4
const CHART_COLORS = [Color("7A9E6E"), Color("D2E4EC"), Color("B5553C"), Color("E8B87A"), Color("9BB8D4")]


class ChartControl:
	extends Control

	var player_steps: int = 0
	var entries: Array[Dictionary] = []

	func set_data(p_steps: int, friends: Array[Dictionary]) -> void:
		player_steps = max(p_steps, 0)
		entries.clear()
		entries.append({"name": "我", "steps": player_steps, "self": true})
		var sorted := friends.duplicate(true)
		sorted.sort_custom(func(a, b): return int(a.get("steps", 0)) > int(b.get("steps", 0)))
		for i in range(min(5, sorted.size())):
			entries.append({"name": str(sorted[i].get("nickname", "好友")), "steps": int(sorted[i].get("steps", 0)), "self": false})
		queue_redraw()

	func _draw() -> void:
		if entries.is_empty():
			return
		var font := get_theme_default_font()
		draw_string(font, Vector2(0.0, 28.0), "步数对比", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Palette.TEXT_PRIMARY)

		if entries.size() <= 1 and player_steps <= 0:
			var msg := "还没有步数数据，出去散步后再来看看吧"
			var ts := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15)
			draw_string(font, Vector2((size.x - ts.x) * 0.5, 140.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Palette.TEXT_SECONDARY)
			return

		var chart_rect := Rect2(Vector2(20.0, 50.0), Vector2(size.x - 40.0, size.y - 90.0))
		var axis_col := Color(Palette.BORDER_DEFAULT, 0.75)
		draw_line(chart_rect.position + Vector2(0.0, chart_rect.size.y), chart_rect.position + chart_rect.size, axis_col, 1.0)
		draw_line(chart_rect.position, chart_rect.position + Vector2(0.0, chart_rect.size.y), axis_col, 1.0)

		var max_steps := 1
		for e in entries:
			max_steps = max(max_steps, int(e.get("steps", 0)))
		var y_max: float = float(max_steps) * 1.2
		var gap: float = 14.0
		var n: int = entries.size()
		var bar_w: float = min(54.0, (chart_rect.size.x - gap * float(n + 1)) / float(n))
		var start_x: float = chart_rect.position.x + (chart_rect.size.x - (bar_w * float(n) + gap * float(n - 1))) * 0.5

		for i in range(n):
			var e: Dictionary = entries[i]
			var steps: int = int(e.get("steps", 0))
			var ratio: float = clamp(float(steps) / y_max, 0.0, 1.0)
			var bar_h: float = max(chart_rect.size.y * ratio, 2.0)
			var x: float = start_x + float(i) * (bar_w + gap)
			var bar_rect := Rect2(Vector2(x, chart_rect.position.y + chart_rect.size.y - bar_h), Vector2(bar_w, bar_h))
			var col: Color = Palette.AMBER if bool(e.get("self", false)) else CHART_COLORS[i % CHART_COLORS.size()]
			draw_rect(bar_rect, col, true)

			var sl := str(steps)
			var ss := font.get_string_size(sl, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
			draw_string(font, Vector2(x + (bar_w - ss.x) * 0.5, bar_rect.position.y - 8.0), sl, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Palette.TEXT_SECONDARY)

			var nm := str(e.get("name", ""))
			if nm.length() > 4:
				nm = nm.substr(0, 4)
			if nm.is_empty():
				nm = "好友"
			var ns := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
			draw_string(font, Vector2(x + (bar_w - ns.x) * 0.5, chart_rect.position.y + chart_rect.size.y + 22.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Palette.TEXT_SECONDARY)


var _cfg := ConfigFile.new()
var _invite_code := ""
var _friends: Array[Dictionary] = []
var _pending_codes: Array[String] = []
var _gifts_seeded: bool = false
var _rng := RandomNumberGenerator.new()
var _back_rect := Rect2()
var _code_label: Label
var _input: LineEdit
var _list: VBoxContainer
var _chart: ChartControl


func _ready() -> void:
	super._ready()
	_build_background()
	_load_data()
	_check_daily_reset()
	_ensure_default_friends()
	_seed_gifts_if_needed(true)
	_build_ui()
	%BackBtn.pressed.connect(_on_back)


func on_enter(_data := {}) -> void:
	_load_data()
	_check_daily_reset()
	_seed_gifts_if_needed(false)
	_refresh_all()


func _on_back() -> void:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")


func _gui_input(event: InputEvent) -> void:
	if _is_back_event(event):
		_on_back()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _is_back_event(event):
		_on_back()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var screen := get_viewport_rect().size
	if not %Bg.visible:
		draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE, true)
	_draw_top_bar()


func _build_background() -> void:
	%Bg.visible = ResourceLoader.exists(FRIENDS_BG_PATH)
	%Bg.show_behind_parent = true
	if %Bg.visible:
		%Bg.texture = load(FRIENDS_BG_PATH)


func _build_ui() -> void:
	var old := get_node_or_null("Scroll")
	if old:
		old.queue_free()
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 128.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(DESIGN_SIZE.x, 0.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	content.add_child(_section_invite())
	content.add_child(_section_add())
	content.add_child(_section_friends())
	content.add_child(_section_chart())
	_refresh_all()


func _section_invite() -> Control:
	var panel := _panel(624.0)
	var box := _vbox(panel)
	box.add_child(_label("邀请好友一起散步", 21, Palette.TEXT_PRIMARY))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 72.0)
	card.add_theme_stylebox_override("panel", _style(Palette.MILK_WHITE, Palette.BORDER_DEFAULT, 8, 14))
	_code_label = _label(_invite_code, 24, Palette.TEXT_PRIMARY)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(_code_label)
	box.add_child(card)
	var copy_btn := _btn("复制邀请码", Palette.AMBER, Palette.TEXT_ON_AMBER)
	copy_btn.custom_minimum_size = Vector2(0.0, 48.0)
	copy_btn.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_invite_code)
		Popups.show_toast("邀请码已复制，发送给好友吧！")
	)
	box.add_child(copy_btn)
	var hint := _label("好友输入你的邀请码即可添加你", 14, Palette.TEXT_SECONDARY)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	return _wrap(panel)


func _section_add() -> Control:
	var panel := _panel(624.0)
	var box := _vbox(panel)
	box.add_child(_label("添加好友", 18, Palette.TEXT_PRIMARY))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_input = LineEdit.new()
	_input.placeholder_text = "请输入好友邀请码"
	_input.custom_minimum_size = Vector2(0.0, 48.0)
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_size_override("font_size", 16)
	_input.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_input.add_theme_color_override("font_placeholder_color", Palette.TEXT_SECONDARY)
	_input.add_theme_stylebox_override("normal", _style(Palette.MILK_WHITE, Palette.BORDER_DEFAULT, 8, 12))
	_input.add_theme_stylebox_override("focus", _style(Palette.MILK_WHITE, Palette.AMBER, 8, 12))
	_input.text_submitted.connect(func(_t: String) -> void: _add_friend())
	row.add_child(_input)
	var add_btn := _btn("添加", Palette.AMBER, Palette.TEXT_ON_AMBER)
	add_btn.custom_minimum_size = Vector2(100.0, 48.0)
	add_btn.pressed.connect(_add_friend)
	row.add_child(add_btn)
	box.add_child(row)
	return _wrap(panel)


func _section_friends() -> Control:
	var panel := _panel(624.0)
	var box := _vbox(panel)
	box.add_child(_label("我的好友", 18, Palette.TEXT_PRIMARY))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 320.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	box.add_child(scroll)
	return _wrap(panel)


func _section_chart() -> Control:
	var panel := _panel(624.0)
	var box := _vbox(panel)
	_chart = ChartControl.new()
	_chart.custom_minimum_size = Vector2(540.0, 240.0)
	_chart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_chart)
	return _wrap(panel)


func _refresh_all() -> void:
	_sort_friends()
	_refresh_list()
	_chart.set_data(StepEngine.get_today_steps(), _friends)
	if _code_label:
		_code_label.text = _invite_code


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	if _friends.is_empty():
		var e := _label("还没有好友，快去添加吧！", 16, Palette.TEXT_SECONDARY)
		e.custom_minimum_size = Vector2(0.0, 80.0)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_list.add_child(e)
		return
	for i in range(_friends.size()):
		_list.add_child(_friend_row(i))


func _friend_row(idx: int) -> Control:
	var f := _friends[idx]
	var code := str(f.get("code", ""))
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 68.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var ava := PanelContainer.new()
	ava.custom_minimum_size = Vector2(46.0, 46.0)
	ava.add_theme_stylebox_override("panel", _style(Color("#E4E8EA"), Color.TRANSPARENT, 23, 0))
	var al := _label(_avatar_text(str(f.get("nickname", "友"))), 18, Palette.TEXT_PRIMARY)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ava.add_child(al)
	row.add_child(ava)
	var nb := VBoxContainer.new()
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nb.add_theme_constant_override("separation", 2)
	nb.add_child(_label(str(f.get("nickname", "好友")), 16, Palette.TEXT_PRIMARY))
	nb.add_child(_label("%d步" % int(f.get("steps", 0)), 13, Palette.TEXT_SECONDARY))
	row.add_child(nb)

	var has_pending := _pending_codes.has(code) and not bool(f.get("gift_received_today", false))
	if has_pending:
		var rcv := _btn("领取", Palette.MOSS_GREEN, Palette.TEXT_ON_AMBER)
		rcv.custom_minimum_size = Vector2(110.0, 40.0)
		rcv.pressed.connect(func(): _claim_gift(code))
		row.add_child(rcv)
	else:
		var sent := bool(f.get("gift_sent_today", false))
		var bg := Color("#C4C9CE") if sent else Palette.AMBER
		var gbtn := _btn("已赠送" if sent else "赠送体力", bg, Palette.TEXT_ON_AMBER)
		gbtn.custom_minimum_size = Vector2(110.0, 40.0)
		gbtn.disabled = sent
		if not sent:
			gbtn.pressed.connect(func(): _confirm_send(idx))
		row.add_child(gbtn)
	return row


func _confirm_send(idx: int) -> void:
	if idx < 0 or idx >= _friends.size():
		return
	var nm := str(_friends[idx].get("nickname", "好友"))
	Popups.show_confirm("赠送体力", "确定赠送体力给%s？你将消耗5体力" % nm, func(): _send_gift(idx))


func _send_gift(idx: int) -> void:
	if idx < 0 or idx >= _friends.size():
		return
	if bool(_friends[idx].get("gift_sent_today", false)):
		Popups.show_toast("今天已经赠送过啦")
		return
	var spent := EnergyEngine.spend_pool(5.0)
	if spent < 5.0:
		if spent > 0.0:
			EnergyEngine.add_pool_with_overflow(spent)
		Popups.show_toast("体力不足，散步获取更多体力吧！")
		return
	_friends[idx]["gift_sent_today"] = true
	_save_data()
	_refresh_all()
	Popups.show_toast("体力已赠送")


func _claim_gift(code: String) -> void:
	var idx := _find_by_code(code)
	if idx < 0:
		return
	if bool(_friends[idx].get("gift_received_today", false)):
		Popups.show_toast("今天已经领取过啦")
		return
	EnergyEngine.add_pool_with_overflow(10.0)
	_friends[idx]["gift_received_today"] = true
	_pending_codes.erase(code)
	_save_data()
	_refresh_all()
	Popups.show_toast("已领取10体力")


func _find_by_code(code: String) -> int:
	for i in range(_friends.size()):
		if str(_friends[i].get("code", "")) == code:
			return i
	return -1


func _add_friend() -> void:
	var code := _input.text.strip_edges().to_upper()
	if code.is_empty():
		Popups.show_toast("请输入邀请码")
		return
	if code == _invite_code or _find_by_code(code) >= 0:
		Popups.show_toast("该好友已在列表中")
		return
	_rng.randomize()
	var f := {"code": code, "nickname": FAKE_NAMES[_rng.randi_range(0, FAKE_NAMES.size() - 1)], "steps": _rng.randi_range(1000, 20000), "gift_sent_today": false, "gift_received_today": false}
	_friends.append(f)
	_input.clear()
	_save_data()
	_refresh_all()
	Popups.show_toast("好友添加成功")


func _load_data() -> void:
	_cfg = ConfigFile.new()
	_cfg.load(CFG_PATH)
	_invite_code = str(_cfg.get_value(CFG_SECTION, "invite_code", ""))
	if _invite_code.is_empty():
		_invite_code = _gen_code()
		_cfg.set_value(CFG_SECTION, "invite_code", _invite_code)
	_friends.clear()
	for item in _cfg.get_value(CFG_SECTION, "friends", []):
		if item is Dictionary:
			_friends.append(_norm(item))
	_pending_codes.clear()
	for v in _cfg.get_value(CFG_SECTION, "pending_codes", []):
		_pending_codes.append(str(v))
	var seeded_date := str(_cfg.get_value(CFG_SECTION, "gifts_seeded_date", ""))
	_gifts_seeded = (seeded_date == _today_key())


func _save_data() -> void:
	_cfg.set_value(CFG_SECTION, "invite_code", _invite_code)
	_cfg.set_value(CFG_SECTION, "friends", _friends)
	_cfg.set_value(CFG_SECTION, "pending_codes", _pending_codes)
	if str(_cfg.get_value(CFG_SECTION, "last_reset_date", "")).is_empty():
		_cfg.set_value(CFG_SECTION, "last_reset_date", _today_key())
	if _gifts_seeded:
		_cfg.set_value(CFG_SECTION, "gifts_seeded_date", _today_key())
	_cfg.save(CFG_PATH)


func _check_daily_reset() -> void:
	var today := _today_key()
	var last := str(_cfg.get_value(CFG_SECTION, "last_reset_date", ""))
	if last == today:
		return
	for i in range(_friends.size()):
		_friends[i]["gift_sent_today"] = false
		_friends[i]["gift_received_today"] = false
	_pending_codes.clear()
	_gifts_seeded = false
	_cfg.set_value(CFG_SECTION, "last_reset_date", today)


func _seed_gifts_if_needed(_is_init: bool) -> void:
	if _gifts_seeded:
		return
	if _friends.is_empty():
		return
	_rng.seed = hash(_today_key() + _invite_code)
	var count: int = min(_rng.randi_range(1, 2), _friends.size())
	var codes: Array[String] = []
	while codes.size() < count:
		var idx := _rng.randi_range(0, _friends.size() - 1)
		var c := str(_friends[idx].get("code", ""))
		if not codes.has(c) and not bool(_friends[idx].get("gift_received_today", false)):
			codes.append(c)
	_pending_codes = codes
	_gifts_seeded = true
	_cfg.set_value(CFG_SECTION, "gifts_seeded_date", _today_key())
	_save_data()


func _ensure_default_friends() -> void:
	if not _friends.is_empty():
		return
	for item in DEFAULT_FRIENDS:
		var code := _gen_code()
		_friends.append({"code": code, "nickname": str(item.nickname), "steps": int(item.steps), "gift_sent_today": false, "gift_received_today": false})


func _norm(item: Dictionary) -> Dictionary:
	return {"code": str(item.get("code", "")), "nickname": str(item.get("nickname", "好友")), "steps": max(int(item.get("steps", 0)), 0), "gift_sent_today": bool(item.get("gift_sent_today", false)), "gift_received_today": bool(item.get("gift_received_today", false))}


func _sort_friends() -> void:
	_friends.sort_custom(func(a, b): return int(a.get("steps", 0)) > int(b.get("steps", 0)))
	# _pending_codes uses invite codes, not indices, so sorting does not affect them


func _gen_code() -> String:
	var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	_rng.randomize()
	var a := ""
	var b := ""
	for i in range(INVITE_CODE_LEN):
		a += letters[_rng.randi_range(0, letters.length() - 1)]
		b += letters[_rng.randi_range(0, letters.length() - 1)]
	return INVITE_PREFIX + a + "-" + b


func _today_key() -> String:
	var ut := Time.get_unix_time_from_system()
	if TimeGuard and TimeGuard.has_method("get_safe_unix_time"):
		ut = TimeGuard.get_safe_unix_time()
	var d := Time.get_datetime_dict_from_unix_time(ut)
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


func _panel(w: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, 0.0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", _style(Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, 8, 16))
	return p


func _vbox(p: PanelContainer) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_constant_override("separation", 10)
	p.add_child(b)
	return b


func _wrap(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 48)
	m.add_theme_constant_override("margin_right", 48)
	m.add_child(c)
	return m


func _label(text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, bg: Color, fc: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_disabled_color", Palette.TEXT_ON_AMBER)
	b.add_theme_stylebox_override("normal", _style(bg, bg, 8, 8))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.06), bg.lightened(0.06), 8, 8))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.08), bg.darkened(0.08), 8, 8))
	b.add_theme_stylebox_override("disabled", _style(Color("#C4C9CE"), Color("#C4C9CE"), 8, 8))
	return b


func _style(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if border.a > 0.0:
		s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


func _avatar_text(name: String) -> String:
	if name.is_empty():
		return "友"
	return name.substr(0, 1)


func _draw_top_bar() -> void:
	_back_rect = Rect2(Vector2(28.0, 59.0), Vector2(85.0, 48.0))
	_draw_centered_in_rect("返回", _back_rect, 16, Palette.TEXT_PRIMARY)
	_draw_centered_text("好友", 91.0, 24, Palette.TEXT_PRIMARY)


func _draw_centered_text(text: String, y: float, sz: int, col: Color) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz).x
	draw_string(font, Vector2((DESIGN_SIZE.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, col)


func _draw_centered_in_rect(text: String, rect: Rect2, sz: int, col: Color) -> void:
	var font := get_theme_default_font()
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz)
	draw_string(font, rect.position + Vector2((rect.size.x - ts.x) * 0.5, (rect.size.y + ts.y) * 0.5 - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sz, col)


func _is_back_event(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACK)
