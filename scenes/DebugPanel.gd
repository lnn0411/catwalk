extends CanvasLayer




var steps_label: Label
var energy_pool_bar: ProgressBar
var reserve_bar: ProgressBar
var cumulative_energy_label: Label
var newbie_days_label: Label
var slot_bars: Array[ProgressBar] = []
var slot_labels: Array[Label] = []
var cat_list: VBoxContainer
var confirm_reset: ConfirmationDialog
var confirm_reset_steps: ConfirmationDialog

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_refresh()

func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 28)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 28)
	add_child(root)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.get_card_stylebox())
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	var title := Label.new()
	title.text = "Catwalk Debug"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)

	steps_label = _make_label("")
	content.add_child(steps_label)

	var mock_row := HBoxContainer.new()
	mock_row.visible = OS.has_feature("editor")
	mock_row.add_theme_constant_override("separation", 8)
	content.add_child(mock_row)
	for amount in [500, 1000, 5000, 10000]:
		var button := _make_secondary_button("+%d" % amount)
		button.pressed.connect(_on_add_steps.bind(amount))
		mock_row.add_child(button)
	var step_reset := _make_secondary_button("reset")
	step_reset.pressed.connect(_on_reset_steps)
	mock_row.add_child(step_reset)

	# 快捷填充按钮
	var fast_row := HBoxContainer.new()
	fast_row.visible = OS.has_feature("editor")
	fast_row.add_theme_constant_override("separation", 8)
	content.add_child(fast_row)
	for amount in [5000, 15000, 30000, 50000]:
		var btn := _make_secondary_button("+%d步" % amount)
		btn.pressed.connect(_on_add_steps.bind(amount))
		fast_row.add_child(btn)

	content.add_child(_make_section_label("Energy Pool"))
	energy_pool_bar = _make_progress_bar(EnergyEngine.MAX_ENERGY_POOL)
	content.add_child(energy_pool_bar)

	content.add_child(_make_section_label("Reserve Tank"))
	reserve_bar = _make_progress_bar(EnergyEngine.MAX_RESERVE_TANK)
	content.add_child(reserve_bar)

	cumulative_energy_label = _make_label("")
	content.add_child(cumulative_energy_label)

	newbie_days_label = _make_label("")
	content.add_child(newbie_days_label)

	content.add_child(_make_section_label("Hatch Slots"))
	for i in range(4):
		var slot_box := VBoxContainer.new()
		slot_box.add_theme_constant_override("separation", 4)
		content.add_child(slot_box)

		var label := _make_label("")
		slot_labels.append(label)
		slot_box.add_child(label)

		var bar := _make_progress_bar(1.0)
		bar.max_value = 1.0
		bar.step = 0.001
		slot_bars.append(bar)
		slot_box.add_child(bar)

	content.add_child(_make_section_label("Cats"))
	cat_list = VBoxContainer.new()
	cat_list.add_theme_constant_override("separation", 6)
	content.add_child(cat_list)

	var archive_reset := _make_primary_button("Archive Reset")
	archive_reset.pressed.connect(func(): confirm_reset.popup_centered())
	content.add_child(archive_reset)

	confirm_reset_steps = ConfirmationDialog.new()
	confirm_reset_steps.title = "Reset Debug State"
	confirm_reset_steps.dialog_text = "Clear saved steps, energy, slots, and cats?"
	confirm_reset_steps.confirmed.connect(_on_reset_steps_confirmed)
	add_child(confirm_reset_steps)

	confirm_reset = ConfirmationDialog.new()
	confirm_reset.title = "Archive Reset"
	confirm_reset.dialog_text = "Clear saved steps, energy, slots, and cats?"
	confirm_reset.confirmed.connect(_on_archive_reset_confirmed)
	add_child(confirm_reset)

func _connect_signals() -> void:
	if StepEngine and not StepEngine.steps_updated.is_connected(_on_steps_updated):
		StepEngine.steps_updated.connect(_on_steps_updated)
	if EnergyEngine and not EnergyEngine.energy_changed.is_connected(_on_energy_changed):
		EnergyEngine.energy_changed.connect(_on_energy_changed)
	if HatchEngine:
		if not HatchEngine.hatch_started.is_connected(_on_hatch_started):
			HatchEngine.hatch_started.connect(_on_hatch_started)
		if not HatchEngine.hatch_progress.is_connected(_on_hatch_progress):
			HatchEngine.hatch_progress.connect(_on_hatch_progress)
		if not HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
			HatchEngine.hatch_complete.connect(_on_hatch_complete)

func _refresh() -> void:
	steps_label.text = "Steps: today %d / total %d" % [
		StepEngine.get_today_steps(),
		StepEngine.get_total_steps(),
	]
	energy_pool_bar.value = EnergyEngine.energy_pool
	reserve_bar.value = EnergyEngine.reserve_tank
	cumulative_energy_label.text = "Cumulative energy: %.0f" % EnergyEngine.total_energy_produced
	newbie_days_label.text = "Newbie days remaining: %d" % EnergyEngine.newbie_protection_remaining_days()
	_refresh_slots()
	_refresh_cats()

func _refresh_slots() -> void:
	var slots := HatchEngine.get_slots()
	for i in range(slot_bars.size()):
		if i >= slots.size():
			slot_labels[i].text = "Slot %d: missing" % (i + 1)
			slot_bars[i].value = 0.0
			continue

		var slot: Dictionary = slots[i]
		var status := String(slot.get("status", "locked"))
		var species := String(slot.get("species", ""))
		var energy := float(slot.get("energy", 0.0))
		var max_energy := float(slot.get("max_energy", 0.0))
		var progress := 0.0
		if max_energy > 0.0:
			progress = clamp(energy / max_energy, 0.0, 1.0)
		slot_bars[i].value = progress

		if status == "locked":
			slot_labels[i].text = "Slot %d: locked" % (i + 1)
		elif max_energy > 0.0:
			slot_labels[i].text = "Slot %d: %s %.0f/%.0f" % [i + 1, species, energy, max_energy]
		else:
			slot_labels[i].text = "Slot %d: %s" % [i + 1, status]

func _refresh_cats() -> void:
	for child in cat_list.get_children():
		child.queue_free()

	var cats := HatchEngine.get_cats()
	if cats.is_empty():
		cat_list.add_child(_make_label("No cats hatched"))
		return

	for cat in cats:
		var row := _make_label(_format_cat(cat))
		cat_list.add_child(row)

func _format_cat(cat) -> String:
	return "%s / %s / %s / Lv.%d" % [
		cat.display_name,
		cat.species,
		cat.rarity,
		cat.level,
	]

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	label.add_theme_font_size_override("font_size", 18)
	return label

func _make_section_label(text: String) -> Label:
	var label := _make_label(text)
	label.add_theme_color_override("font_color", Palette.AMBER)
	label.add_theme_font_size_override("font_size", 22)
	return label

func _make_progress_bar(maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = maximum
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(0, 24)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.AMBER
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Palette.BG_CEMENT
	background.border_color = Palette.BORDER_DEFAULT
	background.set_border_width_all(1)
	background.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", background)
	return bar

func _make_primary_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_stylebox_override("normal", UITheme.get_button_primary())
	button.add_theme_color_override("font_color", Palette.TEXT_ON_AMBER)
	return button

func _make_secondary_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_stylebox_override("normal", UITheme.get_button_secondary())
	button.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	return button

func _on_steps_updated(_delta: int, _total: int) -> void:
	_refresh()

func _on_energy_changed(_current: float, _pool_max: float, _backup: float) -> void:
	_refresh()

func _on_hatch_started(_slot: int) -> void:
	_refresh()

func _on_hatch_progress(_slot: int, _progress: float) -> void:
	_refresh()

func _on_hatch_complete(_cat_data) -> void:
	_refresh()

func _on_add_steps(amount: int) -> void:
	StepEngine.add_mock_steps(amount)

func _on_reset_steps() -> void:
	confirm_reset_steps.popup_centered()

func _on_reset_steps_confirmed() -> void:
	StepEngine.apply_save({})
	EnergyEngine.apply_save({})
	HatchEngine.apply_save({})
	SaveManager.save_all()
	_refresh()

func _on_archive_reset_confirmed() -> void:
	SaveManager.reset_all()
	_refresh()
