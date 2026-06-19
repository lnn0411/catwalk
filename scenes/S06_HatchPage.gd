extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const SLOT_SIZE := 173.0
const SLOT_GAP := 24.0
const GRID_ORIGIN := Vector2(168.0, 374.0)

var _inject_rect := Rect2()
var _slot_rects: Array[Rect2] = []
var _slots: Array = []
var _last_cat_count := 0

# Bg/BackBtn/HatchBtn 现由 .tscn 提供（unique_name）；缺贴图时 _draw() 回退代码绘制
var _bg_has_texture := false
var _back_has_texture := false
var _hatch_has_texture := false

func _ready() -> void:
	super._ready()
	_bg_has_texture = %Bg.texture != null
	_back_has_texture = %BackBtn.texture_normal != null
	_hatch_has_texture = %HatchBtn.texture_normal != null
	%BackBtn.pressed.connect(_on_back_pressed)
	%HatchBtn.pressed.connect(_on_hatch_pressed)
	_connect_data()
	_refresh_slots()
	if HatchEngine:
		_last_cat_count = HatchEngine.get_cats().size()
	set_process(true)  # ready 蛋震动/光晕需要持续重绘

var _anim_time := 0.0

func _process(delta: float) -> void:
	_anim_time += delta
	# 仅当存在 ready 槽时才每帧重绘（省电；无 ready 时静止）
	for s in _slots:
		if String(Dictionary(s).get("status", "")) == "ready":
			queue_redraw()
			return

func on_enter(_data: Dictionary = {}) -> void:
	_refresh_slots()

func _exit_tree() -> void:
	if HatchEngine:
		if HatchEngine.hatch_progress.is_connected(_on_hatch_progress):
			HatchEngine.hatch_progress.disconnect(_on_hatch_progress)
		if HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
			HatchEngine.hatch_complete.disconnect(_on_hatch_complete)
	if EnergyEngine and EnergyEngine.energy_changed.is_connected(_on_energy_changed):
		EnergyEngine.energy_changed.disconnect(_on_energy_changed)

func _on_back_pressed() -> void:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")

func _on_hatch_pressed() -> void:
	_speed_up()

func _gui_input(event: InputEvent) -> void:
	if _is_back_event(event):
		UIManager.replace("res://scenes/S04_GardenMain.tscn")
		accept_event()
		return

	var pos = null
	pos = _released_position(event)
	if pos == null:
		return
	if _inject_rect.has_point(pos):
		_inject_energy()
		return
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			_on_slot_pressed(i)
			return

func _draw() -> void:
	var screen := get_viewport_rect().size
	if not _bg_has_texture:  # 背景美术未就位时才用代码铺底色
		draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE)
	_draw_top_bar()
	_draw_energy_panel()
	_draw_slot_grid()
	_draw_bottom_button()

func _connect_data() -> void:
	if HatchEngine:
		if not HatchEngine.hatch_progress.is_connected(_on_hatch_progress):
			HatchEngine.hatch_progress.connect(_on_hatch_progress)
		if not HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
			HatchEngine.hatch_complete.connect(_on_hatch_complete)
	if EnergyEngine and not EnergyEngine.energy_changed.is_connected(_on_energy_changed):
		EnergyEngine.energy_changed.connect(_on_energy_changed)

func _refresh_slots() -> void:
	_slots = HatchEngine.get_slots() if HatchEngine else []
	queue_redraw()

func _draw_top_bar() -> void:
	# BackBtn 由 .tscn 提供（60x48 左上角）；有贴图只叠文案，无贴图回退画按钮框
	var back_rect := Rect2(Vector2(28.0, 59.0), Vector2(60.0, 48.0))
	if _back_has_texture:
		_draw_centered_in_rect("返回", back_rect, 16, Palette.TEXT_PRIMARY)
	else:
		_draw_button(back_rect, "返回", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_centered_text("孵化室", 91.0, 24, Palette.TEXT_PRIMARY)

func _draw_energy_panel() -> void:
	var panel := Rect2(Vector2(48.0, 153.0), Vector2(624.0, 147.0))
	_draw_round_rect(panel, 5.0, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 1.0)
	_draw_text("储备能量", Vector2(panel.position.x + 24.0, panel.position.y + 39.0), 19, Palette.TEXT_PRIMARY)

	var current := EnergyEngine.reserve_tank if EnergyEngine else 0.0
	var max_value := EnergyEngine.MAX_RESERVE_TANK if EnergyEngine else 6000.0
	var ratio: float = clamp(current / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	var bar := Rect2(panel.position + Vector2(24.0, 71.0), Vector2(400.0, 16.0))
	_draw_round_rect(bar, 5.0, Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, 1.0)
	_draw_round_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), 5.0, Palette.AMBER, Palette.AMBER, 0.0)
	_draw_text("%.0f / %.0f" % [current, max_value], bar.position + Vector2(0.0, 45.0), 15, Palette.TEXT_SECONDARY)

	_inject_rect = Rect2(panel.position + Vector2(460.0, 51.0), Vector2(127.0, 51.0))
	_draw_button(_inject_rect, "注入", Palette.AMBER, Palette.AMBER, Palette.TEXT_ON_AMBER)

func _draw_slot_grid() -> void:
	_slot_rects.clear()
	for i in range(4):
		var col := i % 2
		var row := i / 2
		var rect := Rect2(GRID_ORIGIN + Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP)), Vector2(SLOT_SIZE, SLOT_SIZE))
		_slot_rects.append(rect)
		var slot := Dictionary(_slots[i]) if i < _slots.size() else {}
		_draw_slot(rect, i, slot)

func _draw_slot(rect: Rect2, index: int, slot: Dictionary) -> void:
	var status := _slot_status(slot)
	var border := Palette.BORDER_ACTIVE if status == "ready" or status == "incubating" else Palette.BORDER_DEFAULT
	var bg := Palette.BG_CEMENT if status != "locked" else Color(Palette.CITY_GRAY, 0.18)
	_draw_round_rect(rect, 5.0, bg, border, 2.0)
	var center := rect.position + rect.size * 0.5
	var egg_color := _species_color(String(slot.get("species", CatData.BREED_ORANGE)))
	if status == "locked":
		draw_circle(center, 39.0, Color(Palette.CITY_GRAY, 0.28))
		_draw_centered_in_rect("未解锁", rect, 16, Palette.TEXT_SECONDARY)
	elif status == "empty":
		_draw_centered_in_rect("空槽", rect, 16, Palette.TEXT_SECONDARY)
	else:
		var egg_center := center + Vector2(0.0, -11.0)
		if status == "ready":
			# ready 态：蛋震动 + 金色呼吸光晕（GDD：蛋震动+发光，等待玩家操作）
			var shake := Vector2(sin(_anim_time * 30.0) * 3.0, cos(_anim_time * 26.0) * 2.0)
			egg_center += shake
			var pulse := (sin(_anim_time * 4.0) + 1.0) * 0.5
			draw_circle(egg_center, 70.0 + pulse * 12.0, Color(Palette.AMBER, 0.10 + pulse * 0.12))
			draw_circle(egg_center, 56.0 + pulse * 8.0, Color(Palette.AMBER, 0.16 + pulse * 0.12))
		draw_ellipse(egg_center, 44.0, 57.0, egg_color)
		_draw_centered_in_rect("蛋 %d" % (index + 1), Rect2(rect.position + Vector2(0.0, 12.0), Vector2(rect.size.x, 33.0)), 15, Palette.TEXT_PRIMARY)
		var progress: float = _slot_progress(slot)
		var bar := Rect2(rect.position + Vector2(24.0, rect.size.y - 32.0), Vector2(rect.size.x - 48.0, 9.0))
		_draw_round_rect(bar, 5.0, Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, 0.0)
		_draw_round_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), 5.0, Palette.AMBER, Palette.AMBER, 0.0)
		if status == "ready":
			_draw_centered_in_rect("点击孵化", Rect2(rect.position + Vector2(0.0, rect.size.y - 59.0), Vector2(rect.size.x, 21.0)), 15, Palette.AMBER)
		else:
			_draw_centered_in_rect("%d%%" % int(progress * 100.0), Rect2(rect.position + Vector2(0.0, rect.size.y - 59.0), Vector2(rect.size.x, 21.0)), 13, Palette.TEXT_SECONDARY)

func _draw_bottom_button() -> void:
	_ad_rect = Rect2(Vector2(120.0, DESIGN_SIZE.y - 167.0), Vector2(480.0, 55.0))
	var remaining: int = HatchEngine.ad_speedup_remaining() if HatchEngine else 0
	var limit: int = HatchEngine.AD_SPEEDUP_DAILY_LIMIT if HatchEngine else 3
	# 按钮文案保持简洁「看广告加速 X/Y」；GDD v2.14 的「补充3000能量（≈30分钟步行）」
	# 说明文案放在点击提示/旁注，不挤在按钮上。
	var label: String = "看广告加速 %d/%d" % [remaining, limit]
	if _art_hatch_btn and _art_hatch_node:
		# 美术按钮就位：定位贴图层，仅在其上叠动态文案（次数随状态变化）
		_art_hatch_node.position = _ad_rect.position
		_art_hatch_node.size = _ad_rect.size
		var text_color := Palette.TEXT_SECONDARY if remaining <= 0 else Palette.TEXT_PRIMARY
		_draw_centered_in_rect(label, _ad_rect, 16, text_color)
	elif remaining <= 0:
		# 用完置灰（仍可点，点了提示"今日已用完"）
		_draw_button(_ad_rect, label, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, Palette.TEXT_SECONDARY)
	else:
		_draw_button(_ad_rect, label, Palette.BG_CEMENT, Palette.BORDER_ACTIVE, Palette.TEXT_PRIMARY)

func _slot_status(slot: Dictionary) -> String:
	var status := String(slot.get("status", "empty"))
	var energy := float(slot.get("energy", 0.0))
	var max_energy := float(slot.get("max_energy", 0.0))
	if status == "incubating" and max_energy > 0.0 and energy >= max_energy:
		return "ready"
	return status

func _slot_progress(slot: Dictionary) -> float:
	var max_energy := float(slot.get("max_energy", 0.0))
	if max_energy <= 0.0:
		return 0.0
	return clamp(float(slot.get("energy", 0.0)) / max_energy, 0.0, 1.0)

func _on_slot_pressed(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	if HatchEngine == null:
		return
	if _slot_status(Dictionary(_slots[index])) == "ready":
		# 触觉：确认点到蛋（Juice 未注册时安全跳过）
		var j := get_node_or_null("/root/Juice")
		if j: j.hit()
		# 完成孵化 → 发出 hatch_complete → _on_hatch_complete 推送 S08 演出
		HatchEngine.collect_ready_slot(index)
		if SaveManager:
			SaveManager.save_all()
		_refresh_slots()

func _inject_energy() -> void:
	if HatchEngine == null or EnergyEngine == null:
		return
	var reserve: float = max(EnergyEngine.reserve_tank, 0.0)
	if reserve <= 0.0:
		if Popups:
			Popups.show_toast("暂无备用能量")
		return
	if not HatchEngine.has_filling_egg():
		if Popups:
			Popups.show_toast("当前没有正在孵化的蛋")
		return
	# GDD §S06：点「注入」→ 确认弹窗 → 确认 → 备用槽减少、当前蛋进度增加
	if Popups:
		Popups.show_confirm("注入备用能量", "将备用能量注入当前孵化的蛋？", _do_inject)
	else:
		_do_inject()

func _do_inject() -> void:
	if HatchEngine == null or EnergyEngine == null:
		return
	var reserve: float = max(EnergyEngine.reserve_tank, 0.0)
	if reserve <= 0.0:
		return
	# 只喂当前蛋、封顶不溢出；只扣实际用掉的，剩余留在备用槽
	var used: float = HatchEngine.feed_current_egg(reserve)
	EnergyEngine.reserve_tank = max(reserve - used, 0.0)
	EnergyEngine.energy_changed.emit(EnergyEngine.energy_pool, EnergyEngine.MAX_ENERGY_POOL, EnergyEngine.reserve_tank)
	if SaveManager:
		SaveManager.save_all()
	_refresh_slots()

func _speed_up() -> void:
	if HatchEngine == null:
		return
	if not HatchEngine.has_filling_egg():
		if Popups:
			Popups.show_toast("当前没有正在孵化的蛋")
		return
	if not HatchEngine.can_ad_speedup():
		if Popups:
			Popups.show_toast("今日加速次数已用完")
		return
	HatchEngine.consume_ad_speedup()
	# 补充 3000 能量（≈30分钟步行），只进当前蛋；满了的剩余退回主池，不溢出别的蛋
	var used: float = HatchEngine.feed_current_egg(HatchEngine.AD_SPEEDUP_ENERGY)
	var leftover: float = HatchEngine.AD_SPEEDUP_ENERGY - used
	if leftover > 0.0 and EnergyEngine:
		EnergyEngine.add_pool_with_overflow(leftover)
	if SaveManager:
		SaveManager.save_all()
	_refresh_slots()

func _on_hatch_progress(_slot: int, _progress: float) -> void:
	_refresh_slots()

func _on_hatch_complete(cat_data) -> void:
	_refresh_slots()
	_last_cat_count = HatchEngine.get_cats().size() if HatchEngine else _last_cat_count
	UIManager.push("res://scenes/S08_HatchShow.tscn", {"cat": cat_data})

func _on_energy_changed(_current: float, _pool_max: float, _backup: float) -> void:
	queue_redraw()

func _species_color(species: String) -> Color:
	match species:
		CatData.BREED_BRITISH:
			return Palette.CAT_BRIT_LIGHT
		CatData.BREED_SIAMESE:
			return Palette.CAT_SIAM_BODY
		_:
			return Palette.CAT_ORANGE_LIGHT

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

func _draw_round_rect(rect: Rect2, radius: float, bg: Color, border: Color, border_width: float) -> void:
	draw_rect(rect, bg)
	if border_width > 0.0:
		draw_rect(rect, border, false, border_width)

func _draw_text(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(get_theme_default_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((DESIGN_SIZE.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_centered_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, rect.position + Vector2((rect.size.x - size.x) * 0.5, (rect.size.y + size.y) * 0.5 - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
