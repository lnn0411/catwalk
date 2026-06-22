extends "res://ui/UIPage.gd"

const WorkshopSlotView := preload("res://ui/WorkshopSlotView.gd")
const BoxOpenAnimation := preload("res://ui/BoxOpenAnimation.gd")
const GiftInventoryGrid := preload("res://ui/GiftInventoryGrid.gd")

var _slot_views: Array[WorkshopSlotView] = []
var _back_btn: Button
var _hatch_btn: Button
var _inventory_btn: Button
var _status_label: Label
var _energy_bar: ColorRect
var _box_animation: BoxOpenAnimation
var _inventory_grid: GiftInventoryGrid
var _title_label: Label
var _anim_playing := false


func on_enter(_data: Dictionary = {}) -> void:
	_refresh_all()
	_refresh_energy_flow()
	_refresh_status_text()


func _ready() -> void:
	super()
	_build_layout()
	_connect_signals()
	_refresh_all()
	_refresh_energy_flow()
	_refresh_status_text()


func _build_layout() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color("#1A1A2E")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Top bar (H=130)
	var top_bar := ColorRect.new()
	top_bar.color = Color("#16213E")
	top_bar.size = Vector2(size.x, 130.0)
	top_bar.position = Vector2.ZERO
	add_child(top_bar)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "← 返回"
	back_btn.flat = true
	back_btn.size = Vector2(120.0, 44.0)
	back_btn.position = Vector2(16.0, 72.0)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back_btn)
	_back_btn = back_btn

	# Title
	var title := Label.new()
	title.text = "🌸 爱意工坊"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size = Vector2(size.x, 44.0)
	title.position = Vector2(0.0, 72.0)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#FFD166"))
	add_child(title)
	_title_label = title

	# Hatch toggle button
	var hatch_btn := Button.new()
	hatch_btn.text = "🔧 孵化"
	hatch_btn.flat = true
	hatch_btn.size = Vector2(120.0, 44.0)
	hatch_btn.position = Vector2(size.x - 136.0, 72.0)
	hatch_btn.add_theme_font_size_override("font_size", 18)
	hatch_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(hatch_btn)
	_hatch_btn = hatch_btn

	# Slot views (vertical center)
	var slot_area_y := 160.0
	var slot_spacing := 90.0
	var slot_start_y := slot_area_y

	for i in range(3):
		var sv := WorkshopSlotView.new()
		sv.name = "WorkshopSlot_%d" % i
		sv.slot_index = i
		sv.position = Vector2((size.x - 120.0) * 0.5, slot_start_y + float(i) * slot_spacing)
		sv.size = Vector2(120.0, 120.0)
		sv.custom_minimum_size = Vector2(120.0, 120.0)
		add_child(sv)
		_slot_views.append(sv)

	# Box open animation overlay
	var animation := BoxOpenAnimation.new()
	animation.name = "BoxOpenAnimation"
	animation.visible = false
	add_child(animation)
	_box_animation = animation

	# Bottom area
	var bottom_y := size.y - 200.0
	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color("#0F3460", 0.85)
	bottom_bar.size = Vector2(size.x, 200.0)
	bottom_bar.position = Vector2(0.0, bottom_y)
	add_child(bottom_bar)

	# Status label
	var status_label := Label.new()
	status_label.text = "准备就绪"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.size = Vector2(size.x, 32.0)
	status_label.position = Vector2(0.0, bottom_y + 16.0)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#A0A0A0"))
	add_child(status_label)
	_status_label = status_label

	# Energy flow bar
	var energy_bar := ColorRect.new()
	energy_bar.color = Color("#333355")
	energy_bar.size = Vector2(size.x - 80.0, 24.0)
	energy_bar.position = Vector2(40.0, bottom_y + 56.0)
	add_child(energy_bar)
	_energy_bar = energy_bar

	# Energy flow label
	var flow_label := Label.new()
	flow_label.text = "主池: 0  →  工坊"
	flow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flow_label.size = Vector2(size.x - 80.0, 24.0)
	flow_label.position = Vector2(40.0, bottom_y + 56.0)
	flow_label.add_theme_font_size_override("font_size", 14)
	flow_label.add_theme_color_override("font_color", Color("#888888"))
	flow_label.name = "FlowLabel"
	flow_label.z_index = 1
	add_child(flow_label)

	# Inventory button
	var inv_btn := Button.new()
	inv_btn.text = "🎁 物品栏"
	inv_btn.flat = true
	inv_btn.size = Vector2(160.0, 48.0)
	inv_btn.position = Vector2((size.x - 160.0) * 0.5, bottom_y + 100.0)
	inv_btn.add_theme_font_size_override("font_size", 18)
	inv_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(inv_btn)
	_inventory_btn = inv_btn

	# Inventory grid (hidden by default)
	var inv_grid := GiftInventoryGrid.new()
	inv_grid.name = "GiftInventoryGrid"
	inv_grid.visible = false
	inv_grid.position = Vector2(40.0, 160.0)
	inv_grid.size = Vector2(size.x - 80.0, size.y - 400.0)
	inv_grid.custom_minimum_size = Vector2(size.x - 80.0, 200.0)
	add_child(inv_grid)
	_inventory_grid = inv_grid


func _connect_signals() -> void:
	if _back_btn != null:
		_back_btn.pressed.connect(_on_back)

	if _hatch_btn != null:
		_hatch_btn.pressed.connect(_on_hatch_toggle)

	if _inventory_btn != null:
		_inventory_btn.pressed.connect(_on_toggle_inventory)

	if _box_animation != null:
		_box_animation.animation_finished.connect(_on_animation_finished)

	# Connect WorkshopManager signals
	var wm := get_node_or_null("/root/WorkshopManager")
	if wm != null:
		if wm.has_signal("slot_energy_changed") and not wm.slot_energy_changed.is_connected(_on_slot_energy_changed):
			wm.slot_energy_changed.connect(_on_slot_energy_changed)
		if wm.has_signal("slot_box_ready") and not wm.slot_box_ready.is_connected(_on_slot_box_ready):
			wm.slot_box_ready.connect(_on_slot_box_ready)
		if wm.has_signal("slot_box_opened") and not wm.slot_box_opened.is_connected(_on_slot_box_opened):
			wm.slot_box_opened.connect(_on_slot_box_opened)

	# Connect slot view signals
	for i in range(_slot_views.size()):
		var sv := _slot_views[i]
		if sv != null and not sv.slot_pressed.is_connected(_on_slot_pressed):
			sv.slot_pressed.connect(_on_slot_pressed)


func _on_slot_pressed(slot_index: int) -> void:
	if _anim_playing:
		return
	var wm := get_node_or_null("/root/WorkshopManager")
	if wm == null:
		return

	var slot: Dictionary = wm.get_slot_data(slot_index) if wm.has_method("get_slot_data") else {}
	if slot.is_empty():
		return

	var status := String(slot.get("status", ""))
	if status != "box_ready":
		return

	_anim_playing = true
	wm.open_box(slot_index)

	# Get gift info for animation
	var gift_id := String(slot.get("gift_id", ""))
	var workshop_data := get_node_or_null("/root/WorkshopData")
	var gift_data: Dictionary = {}
	if workshop_data != null and workshop_data.has_method("get_gift_data"):
		gift_data = workshop_data.get_gift_data(gift_id)

	var rarity := String(gift_data.get("rarity", "common"))
	var name := String(gift_data.get("name", gift_id))
	var category := String(gift_data.get("category", ""))

	_box_animation.play(slot_index, gift_id, rarity, name, category)


func _on_animation_finished(_slot_index: int, _gift_id: String) -> void:
	_anim_playing = false
	var wm := get_node_or_null("/root/WorkshopManager")
	if wm != null and wm.has_method("reset_slot"):
		wm.reset_slot(_slot_index)
	_refresh_all()
	_refresh_status_text()


func _on_slot_energy_changed(slot_index: int, current: float, max_energy: float) -> void:
	if slot_index >= 0 and slot_index < _slot_views.size():
		var sv := _slot_views[slot_index]
		if sv != null:
			sv.set_energy(current, max_energy)
	_refresh_status_text()


func _on_slot_box_ready(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < _slot_views.size():
		var sv := _slot_views[slot_index]
		if sv != null:
			sv.set_status("box_ready")
	_refresh_status_text()


func _on_slot_box_opened(slot_index: int, _gift_id: String) -> void:
	if slot_index >= 0 and slot_index < _slot_views.size():
		var sv := _slot_views[slot_index]
		if sv != null:
			sv.set_status("box_opened")
	_refresh_status_text()


func _on_back() -> void:
	var ui := get_node_or_null("/root/UIManager")
	if ui != null and ui.has_method("pop"):
		ui.pop()
	else:
		_pop_self()


func _on_hatch_toggle() -> void:
	var ui := get_node_or_null("/root/UIManager")
	if ui != null and ui.has_method("replace"):
		ui.replace("res://scenes/S06_HatchPage.tscn")
	else:
		_pop_self()


func _on_toggle_inventory() -> void:
	if _inventory_grid == null:
		return
	if _inventory_grid.visible:
		_inventory_grid.hide()
	else:
		_inventory_grid.show()


func _on_animation_finished_connected(slot_index: int, gift_id: String) -> void:
	_on_animation_finished(slot_index, gift_id)


func _refresh_all() -> void:
	var wm := get_node_or_null("/root/WorkshopManager")
	if wm == null:
		return

	for i in range(_slot_views.size()):
		var sv := _slot_views[i]
		if sv == null:
			continue
		var slot: Dictionary = wm.get_slot_data(i) if wm.has_method("get_slot_data") else {}
		var status := String(slot.get("status", "filling"))
		var energy := float(slot.get("energy", 0.0))
		sv.set_energy(energy, 3000.0)
		sv.set_status(status)

	_refresh_energy_flow()
	_refresh_status_text()


func _refresh_status_text() -> void:
	if _status_label == null:
		return
	var wm := get_node_or_null("/root/WorkshopManager")
	if wm == null:
		_status_label.text = "准备就绪"
		return

	var any_ready := false
	var any_filling := false
	var all_ready := true

	for i in range(3):
		var slot: Dictionary = wm.get_slot_data(i) if wm.has_method("get_slot_data") else {}
		var status := String(slot.get("status", "filling"))
		if status == "box_ready":
			any_ready = true
		elif status == "filling":
			any_filling = true
			all_ready = false
		elif status == "box_opened":
			all_ready = false

	if all_ready:
		_status_label.text = "🎉 全部礼盒待开启！快来拆礼物吧！"
		_status_label.add_theme_color_override("font_color", Color("#FF6B6B"))
	elif any_ready:
		_status_label.text = "🎁 有礼盒待开启！"
		_status_label.add_theme_color_override("font_color", Color("#FFD700"))
	elif any_filling:
		_status_label.text = "⚡ 能量正在注入工坊..."
		_status_label.add_theme_color_override("font_color", Color("#88CCFF"))
	else:
		_status_label.text = "等待能量注入..."
		_status_label.add_theme_color_override("font_color", Color("#A0A0A0"))


func _refresh_energy_flow() -> void:
	var ee := get_node_or_null("/root/EnergyEngine")
	if ee == null:
		return

	var pool: Variant = ee.get("energy_pool")
	var reserve: Variant = ee.get("reserve_tank")
	var pool_val := float(pool) if pool != null else 0.0
	var reserve_val := float(reserve) if reserve != null else 0.0

	var label := _get_flow_label() as Label
	if label != null:
		label.text = "主池: %d  |  备用: %d  |  →  工坊" % [int(pool_val), int(reserve_val)]

	# Update energy bar fill
	var max_val := 21000.0  # 15000 + 6000
	var fill_pct := clampf((pool_val + reserve_val) / max_val, 0.0, 1.0)
	_energy_bar.size.x = lerpf(10.0, (size.x - 80.0), fill_pct)
	var full_color := Color("#FFD700")
	var empty_color := Color("#333355")
	_energy_bar.color = empty_color.lerp(full_color, fill_pct)


func _get_flow_label() -> Label:
	for child in get_children():
		if child is Label and child.name == "FlowLabel":
			return child
	return null


func _pop_self() -> void:
	var tree := get_tree()
	if tree != null:
		tree.current_scene = load("res://scenes/S04_GardenMain.tscn").instantiate()
		tree.change_scene_to_file("res://scenes/S04_GardenMain.tscn")