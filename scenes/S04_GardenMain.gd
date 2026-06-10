extends "res://ui/UIPage.gd"

const GardenBackground := preload("res://scenes/GardenBackground.gd")
const BottomNavScene := preload("res://ui/BottomNav.tscn")
const BottomNav := preload("res://ui/BottomNav.gd")

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const HUD_HEIGHT := 288.0
const GARDEN_HEIGHT := 1152.0
const ACTION_HEIGHT := 96.0
const HATCH_HEIGHT := 80.0
const NAV_HEIGHT := 56.0
const CONTENT_SCALE := 0.72

var garden_layer: Node2D
var cat_container: Node2D
var _camera: Camera2D
var _dragging := false
var _drag_start := Vector2.ZERO
var _steps_label: Label
var _energy_bar: EnergyMeter
var _hatch_row: HBoxContainer
var _action_buttons: Array[GardenActionButton] = []
var _slot_views: Array[HatchSlotView] = []
var _empty_label: Label
var _debug_panel: PanelContainer
var _debug_layer: CanvasLayer
var _steps_hold_timer: Timer
var _stats_visible := false

func _ready() -> void:
	super()
	_build_garden_layer()
	_build_hud()
	_build_debug_panel()
	_connect_data()
	_refresh_all()

func _exit_tree() -> void:
	if CatSpawner:
		CatSpawner.set_cat_container(null)

func _build_garden_layer() -> void:
	garden_layer = Node2D.new()
	garden_layer.name = "GardenLayer"
	garden_layer.position = Vector2(0.0, HUD_HEIGHT)
	add_child(garden_layer)

	_build_parallax_background()
	cat_container = Node2D.new()
	cat_container.name = "CatContainer"
	cat_container.position = Vector2(0.0, 384.0)
	garden_layer.add_child(cat_container)

	_camera = Camera2D.new()
	_camera.position = Vector2(780.0, 690.0)
	_camera.zoom = Vector2(CONTENT_SCALE, CONTENT_SCALE)
	garden_layer.add_child(_camera)
	_camera.make_current()

	if CatSpawner:
		CatSpawner.set_cat_container(cat_container)
		if not CatSpawner.cat_count_changed.is_connected(_on_cat_count_changed):
			CatSpawner.cat_count_changed.connect(_on_cat_count_changed)

func _build_parallax_background() -> void:
	var parallax := ParallaxBackground.new()
	garden_layer.add_child(parallax)
	_add_background_layer(parallax, Vector2(0.05, 0.0), GardenBackground.LAYER_FAR)
	_add_background_layer(parallax, Vector2(0.3, 0.0), GardenBackground.LAYER_MID)
	_add_background_layer(parallax, Vector2(0.8, 0.0), GardenBackground.LAYER_NEAR)

func _add_background_layer(parent: ParallaxBackground, motion_scale: Vector2, layer_type: int) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = motion_scale
	parent.add_child(layer)

	var background := GardenBackground.new()
	background.layer_type = layer_type
	layer.add_child(background)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	canvas.layer = 5
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var top_bar := ColorRect.new()
	top_bar.color = Palette.BG_WARM_WHITE
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0.0, HUD_HEIGHT)
	top_bar.size = Vector2(DESIGN_SIZE.x, HUD_HEIGHT)
	root.add_child(top_bar)

	var top_row := HBoxContainer.new()
	top_row.position = Vector2(32.0, 94.0)
	top_row.size = Vector2(DESIGN_SIZE.x - 64.0, 92.0)
	top_row.add_theme_constant_override("separation", 24)
	root.add_child(top_row)

	var steps_box := HBoxContainer.new()
	steps_box.custom_minimum_size = Vector2(230.0, 72.0)
	steps_box.add_theme_constant_override("separation", 8)
	top_row.add_child(steps_box)

	var steps_icon := Label.new()
	steps_icon.text = "👣"
	steps_icon.add_theme_font_size_override("font_size", 30)
	steps_icon.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	steps_box.add_child(steps_icon)

	_steps_label = Label.new()
	_steps_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_steps_label.add_theme_font_size_override("font_size", 28)
	_steps_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_steps_label.gui_input.connect(_on_steps_label_input)
	steps_box.add_child(_steps_label)

	_energy_bar = EnergyMeter.new()
	_energy_bar.custom_minimum_size = Vector2(300.0, 48.0)
	top_row.add_child(_energy_bar)

	var currency_box := HBoxContainer.new()
	currency_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	currency_box.alignment = BoxContainer.ALIGNMENT_END
	currency_box.add_theme_constant_override("separation", 14)
	top_row.add_child(currency_box)
	for entry in ["💰 0", "💎 0", "🌸 0"]:
		var label := Label.new()
		label.text = entry
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		currency_box.add_child(label)

	_empty_label = Label.new()
	_empty_label.text = "多走几步，猫咪就来了"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.position = Vector2(0.0, HUD_HEIGHT + GARDEN_HEIGHT * 0.42)
	_empty_label.size = Vector2(DESIGN_SIZE.x, 80.0)
	_empty_label.add_theme_font_size_override("font_size", 28)
	_empty_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	root.add_child(_empty_label)

	var action_row := HBoxContainer.new()
	action_row.position = Vector2(48.0, HUD_HEIGHT + GARDEN_HEIGHT + 14.0)
	action_row.size = Vector2(DESIGN_SIZE.x - 96.0, ACTION_HEIGHT)
	action_row.add_theme_constant_override("separation", 16)
	root.add_child(action_row)
	for title in ["喂食", "抚摸", "玩耍", "拍照"]:
		var button := GardenActionButton.new()
		button.text = title
		button.custom_minimum_size = Vector2(220.0, 64.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(button)
		_action_buttons.append(button)

	_hatch_row = HBoxContainer.new()
	_hatch_row.position = Vector2(32.0, DESIGN_SIZE.y - NAV_HEIGHT - HATCH_HEIGHT)
	_hatch_row.size = Vector2(DESIGN_SIZE.x - 64.0, HATCH_HEIGHT)
	_hatch_row.add_theme_constant_override("separation", 12)
	root.add_child(_hatch_row)
	for i in range(4):
		var slot_view := HatchSlotView.new()
		slot_view.slot_index = i
		slot_view.custom_minimum_size = Vector2(240.0, HATCH_HEIGHT)
		slot_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_view.slot_pressed.connect(_on_hatch_slot_pressed)
		_hatch_row.add_child(slot_view)
		_slot_views.append(slot_view)

	var nav = BottomNavScene.instantiate()
	nav.set_current_tab(0)
	nav.tab_selected.connect(_on_bottom_nav_tab_selected)
	root.add_child(nav)

	_steps_hold_timer = Timer.new()
	_steps_hold_timer.one_shot = true
	_steps_hold_timer.wait_time = 3.0
	_steps_hold_timer.timeout.connect(_toggle_debug_panel)
	add_child(_steps_hold_timer)

func _build_debug_panel() -> void:
	_debug_layer = CanvasLayer.new()
	_debug_layer.name = "DebugLayer"
	_debug_layer.layer = 6
	add_child(_debug_layer)

	_debug_panel = PanelContainer.new()
	_debug_panel.visible = false
	_debug_panel.position = Vector2(56.0, 320.0)
	_debug_panel.size = Vector2(420.0, 360.0)
	_debug_panel.add_theme_stylebox_override("panel", _make_box_style(Palette.BG_WARM_WHITE, Palette.BORDER_ACTIVE, 8))
	_debug_layer.add_child(_debug_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_debug_panel.add_child(box)

	for item in [
		["+100 steps", func() -> void: _add_mock_steps(100)],
		["+1000 steps", func() -> void: _add_mock_steps(1000)],
		["+5000 steps", func() -> void: _add_mock_steps(5000)],
		["+10000 steps", func() -> void: _add_mock_steps(10000)],
		["Reset Save", func() -> void: _reset_save()],
		["Show/Hide stats", func() -> void: _toggle_stats()],
	]:
		var button := Button.new()
		button.text = String(item[0])
		button.custom_minimum_size = Vector2(0.0, 56.0)
		button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		button.add_theme_stylebox_override("normal", _make_box_style(Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, 6))
		button.add_theme_stylebox_override("hover", _make_box_style(Palette.BG_WARM_WHITE, Palette.BORDER_ACTIVE, 6))
		button.add_theme_stylebox_override("pressed", _make_box_style(Palette.AMBER, Palette.BORDER_ACTIVE, 6))
		button.pressed.connect(item[1])
		box.add_child(button)

func _make_box_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _connect_data() -> void:
	if StepEngine and not StepEngine.steps_updated.is_connected(_on_steps_updated):
		StepEngine.steps_updated.connect(_on_steps_updated)
	if EnergyEngine and not EnergyEngine.energy_changed.is_connected(_on_energy_changed):
		EnergyEngine.energy_changed.connect(_on_energy_changed)
	if HatchEngine:
		if not HatchEngine.hatch_progress.is_connected(_on_hatch_progress):
			HatchEngine.hatch_progress.connect(_on_hatch_progress)
		if not HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
			HatchEngine.hatch_complete.connect(_on_hatch_complete)

func _refresh_all() -> void:
	_refresh_steps()
	_refresh_energy()
	_refresh_slots()
	_refresh_cat_state()

func _refresh_steps() -> void:
	var steps := 0
	if StepEngine:
		steps = StepEngine.get_today_steps()
	_steps_label.text = "%s 步" % _format_int(steps)

func _refresh_energy() -> void:
	var current := 0.0
	var max_value := 15000.0
	if EnergyEngine:
		current = EnergyEngine.energy_pool
		max_value = EnergyEngine.MAX_ENERGY_POOL
	_energy_bar.set_energy(current, max_value)

func _refresh_slots() -> void:
	var slots := []
	if HatchEngine:
		slots = HatchEngine.get_slots()
	for i in range(_slot_views.size()):
		var data := {}
		if i < slots.size():
			data = Dictionary(slots[i])
		_slot_views[i].set_slot_data(data)

func _refresh_cat_state() -> void:
	var cat_count := 0
	if HatchEngine:
		cat_count = HatchEngine.get_cats().size()
	_empty_label.visible = cat_count == 0
	for button in _action_buttons:
		button.set_enabled(cat_count > 0)

func _on_steps_updated(_delta: int, _total: int) -> void:
	_refresh_steps()

func _on_energy_changed(_current: float, _pool_max: float, _backup: float) -> void:
	_refresh_energy()

func _on_hatch_progress(_slot: int, _progress: float) -> void:
	_refresh_slots()

func _on_hatch_complete(_cat_data) -> void:
	_refresh_slots()
	_refresh_cat_state()

func _on_cat_count_changed(_count: int) -> void:
	_refresh_cat_state()

func _on_hatch_slot_pressed(_slot_index: int) -> void:
	UIManager.push("res://scenes/S06_HatchPage.tscn")

func _on_bottom_nav_tab_selected(index: int) -> void:
	if index < 0 or index >= BottomNav.TABS.size():
		return
	var page := String(BottomNav.TABS[index]["page"])
	if page != "":
		UIManager.replace(page)

func _on_steps_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_steps_hold_timer.start()
		else:
			_steps_hold_timer.stop()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_steps_hold_timer.start()
		else:
			_steps_hold_timer.stop()

func _toggle_debug_panel() -> void:
	_debug_panel.visible = not _debug_panel.visible

func _add_mock_steps(amount: int) -> void:
	if StepEngine:
		StepEngine.add_mock_steps(amount)
	if SaveManager:
		SaveManager.save_all()

func _reset_save() -> void:
	if SaveManager:
		SaveManager.reset_all()
	_refresh_all()

func _toggle_stats() -> void:
	_stats_visible = not _stats_visible
	if Popups:
		var text := "Steps %d / Energy %.0f / Cats %d" % [
			StepEngine.get_today_steps() if StepEngine else 0,
			EnergyEngine.energy_pool if EnergyEngine else 0.0,
			HatchEngine.get_cats().size() if HatchEngine else 0,
		]
		Popups.show_info(text if _stats_visible else "stats hidden")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_in_garden(event.position):
			_dragging = true
			_drag_start = get_global_mouse_position()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging and _camera:
		var drag_delta := get_global_mouse_position() - _drag_start
		_camera.position -= drag_delta / CONTENT_SCALE
		_clamp_camera_to_world()
		_drag_start = get_global_mouse_position()

func _is_in_garden(pos: Vector2) -> bool:
	return pos.y >= HUD_HEIGHT and pos.y <= HUD_HEIGHT + GARDEN_HEIGHT

func _clamp_camera_to_world() -> void:
	_camera.position = Vector2(
		clampf(_camera.position.x, 360.0, 2048.0 - 360.0),
		clampf(_camera.position.y, 640.0, 1536.0 - 640.0)
	)

func _format_int(value: int) -> String:
	var raw: String = str(value)
	var result: String = ""
	var count: int = 0
	for i in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = raw[i] + result
		count += 1
	return result

class EnergyMeter:
	extends Control

	var current: float = 0.0
	var max_value: float = 15000.0

	func set_energy(value: float, limit: float) -> void:
		current = maxf(value, 0.0)
		max_value = maxf(limit, 1.0)
		queue_redraw()

	func _draw() -> void:
		var bar_rect: Rect2 = Rect2(0.0, 12.0, 300.0, 24.0)
		draw_rect(bar_rect, Palette.BORDER_DEFAULT, true)
		var ratio: float = clampf(current / max_value, 0.0, 1.0)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), Palette.AMBER, true)
		draw_rect(bar_rect, Palette.BORDER_ACTIVE, false, 2.0)

		var font: Font = ThemeDB.fallback_font
		var text: String = "%s/%s" % [_format_number(int(current)), _format_number(int(max_value))]
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20)
		draw_string(font, Vector2((bar_rect.size.x - text_size.x) * 0.5, 31.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.TEXT_PRIMARY)

	func _format_number(value: int) -> String:
		var raw: String = str(value)
		var result: String = ""
		var count: int = 0
		for i in range(raw.length() - 1, -1, -1):
			if count > 0 and count % 3 == 0:
				result = "," + result
			result = raw[i] + result
			count += 1
		return result

class GardenActionButton:
	extends Button

	func _ready() -> void:
		flat = true
		add_theme_font_size_override("font_size", 24)
		set_enabled(true)

	func set_enabled(value: bool) -> void:
		disabled = not value
		add_theme_color_override("font_color", Palette.TEXT_ON_AMBER if value else Palette.TEXT_SECONDARY)
		queue_redraw()

	func _draw() -> void:
		var bg := Palette.AMBER if not disabled else Palette.BORDER_DEFAULT
		var style := StyleBoxFlat.new()
		style.bg_color = bg
		style.border_color = Palette.BORDER_ACTIVE if not disabled else Palette.BORDER_DEFAULT
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		draw_style_box(style, Rect2(Vector2.ZERO, size))

class HatchSlotView:
	extends Control

	signal slot_pressed(slot_index: int)

	var slot_index := 0
	var slot_data: Dictionary = {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_slot_data(data: Dictionary) -> void:
		slot_data = data
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			slot_pressed.emit(slot_index)
			accept_event()
		elif event is InputEventScreenTouch and event.pressed:
			slot_pressed.emit(slot_index)
			accept_event()

	func _draw() -> void:
		var unlocked := bool(slot_data.get("unlocked", slot_index == 0))
		var status := String(slot_data.get("status", "empty" if slot_index == 0 else "locked"))
		var energy := float(slot_data.get("energy", 0.0))
		var max_energy := float(slot_data.get("max_energy", 0.0))
		var progress: float = 0.0
		if max_energy > 0.0:
			progress = clamp(energy / max_energy, 0.0, 1.0)

		var border_color := Palette.BORDER_ACTIVE if unlocked else Palette.BORDER_DEFAULT
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.BG_WARM_WHITE
		style.border_color = border_color
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		draw_style_box(style, Rect2(Vector2.ZERO, size))

		var icon := "🔒"
		var detail := ""
		if unlocked and status == "filling":
			icon = "🥚"
			detail = "等待能量填充" if progress <= 0.0 else "%d%%" % int(progress * 100.0)
		elif unlocked:
			icon = "🥚"
			detail = "等待能量填充"

		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(16.0, 31.0), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.TEXT_PRIMARY if unlocked else Palette.TEXT_SECONDARY)
		draw_string(font, Vector2(62.0, 31.0), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.TEXT_SECONDARY)

		var bar_rect := Rect2(16.0, size.y - 20.0, size.x - 32.0, 8.0)
		draw_rect(bar_rect, Palette.BORDER_DEFAULT, true)
		if unlocked and progress > 0.0:
			draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress, bar_rect.size.y)), Palette.AMBER, true)
		elif unlocked:
			var y := size.y - 31.0
			draw_dashed_line(Vector2(16.0, y), Vector2(size.x - 16.0, y), Palette.BORDER_DEFAULT, 2.0, 8.0)
