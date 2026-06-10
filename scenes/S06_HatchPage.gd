extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const SLOT_SIZE := 173.0
const SLOT_GAP := 24.0
const GRID_ORIGIN := Vector2(168.0, 374.0)

var _back_rect := Rect2()
var _inject_rect := Rect2()
var _ad_rect := Rect2()
var _slot_rects: Array[Rect2] = []
var _slots: Array = []
var _last_cat_count := 0

func _ready() -> void:
	super._ready()
	_connect_data()
	_refresh_slots()
	if HatchEngine:
		_last_cat_count = HatchEngine.get_cats().size()

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

func _gui_input(event: InputEvent) -> void:
	if _is_back_event(event):
		UIManager.go_back()
		accept_event()
		return

	var pos = null
	pos = _released_position(event)
	if pos == null:
		return
	if _back_rect.has_point(pos):
		UIManager.pop()
		return
	if _inject_rect.has_point(pos):
		_inject_energy()
		return
	if _ad_rect.has_point(pos):
		_speed_up()
		return
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			_on_slot_pressed(i)
			return

func _draw() -> void:
	var screen := get_viewport_rect().size
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
	_back_rect = Rect2(Vector2(28.0, 59.0), Vector2(85.0, 48.0))
	_draw_button(_back_rect, "返回", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
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
	var border := Palette.BORDER_ACTIVE if status == "ready" or status == "filling" else Palette.BORDER_DEFAULT
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
		draw_ellipse(center + Vector2(0.0, -11.0), 44.0, 57.0, egg_color)
		_draw_centered_in_rect("蛋 %d" % (index + 1), Rect2(rect.position + Vector2(0.0, 12.0), Vector2(rect.size.x, 33.0)), 15, Palette.TEXT_PRIMARY)
		var progress: float = _slot_progress(slot)
		var bar := Rect2(rect.position + Vector2(24.0, rect.size.y - 32.0), Vector2(rect.size.x - 48.0, 9.0))
		_draw_round_rect(bar, 5.0, Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, 0.0)
		_draw_round_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), 5.0, Palette.AMBER, Palette.AMBER, 0.0)
		if status == "ready":
			_draw_centered_in_rect("可领取", Rect2(rect.position + Vector2(0.0, rect.size.y - 59.0), Vector2(rect.size.x, 21.0)), 15, Palette.AMBER)
		else:
			_draw_centered_in_rect("%d%%" % int(progress * 100.0), Rect2(rect.position + Vector2(0.0, rect.size.y - 59.0), Vector2(rect.size.x, 21.0)), 13, Palette.TEXT_SECONDARY)

func _draw_bottom_button() -> void:
	_ad_rect = Rect2(Vector2(120.0, DESIGN_SIZE.y - 167.0), Vector2(480.0, 55.0))
	_draw_button(_ad_rect, "看广告加速", Palette.BG_CEMENT, Palette.BORDER_ACTIVE, Palette.TEXT_PRIMARY)

func _slot_status(slot: Dictionary) -> String:
	var status := String(slot.get("status", "empty"))
	var energy := float(slot.get("energy", 0.0))
	var max_energy := float(slot.get("max_energy", 0.0))
	if status == "filling" and max_energy > 0.0 and energy >= max_energy:
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
	if _slot_status(Dictionary(_slots[index])) == "ready":
		_push_latest_cat()

func _inject_energy() -> void:
	if HatchEngine == null or EnergyEngine == null:
		return
	var amount: float = max(EnergyEngine.reserve_tank, 0.0)
	if amount <= 0.0:
		return
	EnergyEngine.reserve_tank = 0.0
	HatchEngine.feed_energy(amount)
	EnergyEngine.energy_changed.emit(EnergyEngine.energy_pool, EnergyEngine.MAX_ENERGY_POOL, EnergyEngine.reserve_tank)
	if SaveManager:
		SaveManager.save_all()
	_refresh_slots()

func _speed_up() -> void:
	if HatchEngine:
		HatchEngine.feed_energy(1000.0)
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

func _push_latest_cat() -> void:
	if HatchEngine == null:
		return
	var cats := HatchEngine.get_cats()
	if cats.is_empty():
		return
	UIManager.push("res://scenes/S08_HatchShow.tscn", {"cat": cats[cats.size() - 1]})

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
