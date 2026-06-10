extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const SLOT_SIZE := 260.0
const SLOT_GAP := 36.0
const GRID_ORIGIN := Vector2(252.0, 560.0)

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
	_back_rect = Rect2(Vector2(42.0, 88.0), Vector2(128.0, 72.0))
	_draw_button(_back_rect, "返回", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_centered_text("孵化室", 136.0, 36, Palette.TEXT_PRIMARY)

func _draw_energy_panel() -> void:
	var panel := Rect2(Vector2(72.0, 230.0), Vector2(936.0, 220.0))
	_draw_round_rect(panel, 8.0, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 2.0)
	_draw_text("储备能量", Vector2(panel.position.x + 36.0, panel.position.y + 58.0), 28, Palette.TEXT_PRIMARY)

	var current := EnergyEngine.reserve_tank if EnergyEngine else 0.0
	var max_value := EnergyEngine.MAX_RESERVE_TANK if EnergyEngine else 6000.0
	var ratio: float = clamp(current / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	var bar := Rect2(panel.position + Vector2(36.0, 106.0), Vector2(600.0, 24.0))
	_draw_round_rect(bar, 8.0, Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, 1.0)
	_draw_round_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), 8.0, Palette.AMBER, Palette.AMBER, 0.0)
	_draw_text("%.0f / %.0f" % [current, max_value], bar.position + Vector2(0.0, 68.0), 22, Palette.TEXT_SECONDARY)

	_inject_rect = Rect2(panel.position + Vector2(690.0, 76.0), Vector2(190.0, 76.0))
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
	_draw_round_rect(rect, 8.0, bg, border, 3.0)
	var center := rect.position + rect.size * 0.5
	var egg_color := _species_color(String(slot.get("species", CatData.BREED_ORANGE)))
	if status == "locked":
		draw_circle(center, 58.0, Color(Palette.CITY_GRAY, 0.28))
		_draw_centered_in_rect("未解锁", rect, 24, Palette.TEXT_SECONDARY)
	elif status == "empty":
		_draw_centered_in_rect("空槽", rect, 24, Palette.TEXT_SECONDARY)
	else:
		draw_ellipse(center + Vector2(0.0, -16.0), 66.0, 86.0, egg_color)
		_draw_centered_in_rect("蛋 %d" % (index + 1), Rect2(rect.position + Vector2(0.0, 18.0), Vector2(rect.size.x, 50.0)), 22, Palette.TEXT_PRIMARY)
		var progress: float = _slot_progress(slot)
		var bar := Rect2(rect.position + Vector2(36.0, rect.size.y - 48.0), Vector2(rect.size.x - 72.0, 14.0))
		_draw_round_rect(bar, 7.0, Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, 0.0)
		_draw_round_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), 7.0, Palette.AMBER, Palette.AMBER, 0.0)
		if status == "ready":
			_draw_centered_in_rect("可领取", Rect2(rect.position + Vector2(0.0, rect.size.y - 88.0), Vector2(rect.size.x, 32.0)), 22, Palette.AMBER)
		else:
			_draw_centered_in_rect("%d%%" % int(progress * 100.0), Rect2(rect.position + Vector2(0.0, rect.size.y - 88.0), Vector2(rect.size.x, 32.0)), 20, Palette.TEXT_SECONDARY)

func _draw_bottom_button() -> void:
	_ad_rect = Rect2(Vector2(180.0, DESIGN_SIZE.y - 250.0), Vector2(720.0, 82.0))
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

func _draw_button(rect: Rect2, text: String, bg: Color, border: Color, text_color: Color) -> void:
	_draw_round_rect(rect, 8.0, bg, border, 2.0)
	_draw_centered_in_rect(text, rect, 24, text_color)

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
	draw_string(font, rect.position + Vector2((rect.size.x - size.x) * 0.5, (rect.size.y + size.y) * 0.5 - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
