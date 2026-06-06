extends Control

@onready var steps_label: Label = %StepsLabel
@onready var energy_label: Label = %EnergyLabel
@onready var total_energy_label: Label = %TotalEnergyLabel
@onready var cats_label: Label = %CatsLabel
@onready var slots_box: VBoxContainer = %SlotsBox

func _ready() -> void:
	%Add100Button.pressed.connect(_on_add_steps.bind(100))
	%Add1000Button.pressed.connect(_on_add_steps.bind(1000))
	%Add5000Button.pressed.connect(_on_add_steps.bind(5000))
	%ResetButton.pressed.connect(_on_reset_pressed)

	StepEngine.steps_changed.connect(_refresh)
	EnergyEngine.energy_changed.connect(func(_pool, _reserve, _total): _refresh())
	HatchEngine.slots_changed.connect(func(_slots): _refresh())
	HatchEngine.hatch_completed.connect(func(_cat, _slot_id): _refresh())
	_refresh()

func _refresh(_a = null, _b = null, _c = null) -> void:
	steps_label.text = "Steps: today %d / total %d / tier T%d" % [
		StepEngine.get_today_steps(),
		StepEngine.get_total_steps(),
		StepEngine.get_current_tier() + 1,
	]
	energy_label.text = "Energy: pool %d/%d / reserve %d/%d / today %d" % [
		EnergyEngine.energy_pool,
		EnergyEngine.MAX_ENERGY_POOL,
		EnergyEngine.energy_reserve,
		EnergyEngine.MAX_ENERGY_RESERVE,
		EnergyEngine.today_energy,
	]
	total_energy_label.text = "Total produced: %d / new player: %s" % [
		EnergyEngine.total_energy_produced,
		str(SaveManager.is_new_player()),
	]
	cats_label.text = "Cats hatched: %d" % HatchEngine.get_hatched_count()
	_refresh_slots()

func _refresh_slots() -> void:
	for child in slots_box.get_children():
		child.queue_free()

	for slot in HatchEngine.get_slots():
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 44)

		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = _format_slot(slot)
		row.add_child(label)

		var button := Button.new()
		button.text = "Hatch"
		button.disabled = String(slot.get("status", "")) != "complete"
		button.pressed.connect(_on_hatch_pressed.bind(int(slot.get("id", 0))))
		row.add_child(button)

		slots_box.add_child(row)

func _format_slot(slot: Dictionary) -> String:
	var status := String(slot.get("status", "locked"))
	if status == "locked":
		return "Slot %d: locked" % int(slot.get("id", 0))

	var energy := int(slot.get("energy", 0))
	var max_energy := int(slot.get("max_energy", 0))
	var species := String(slot.get("species", "?"))
	if max_energy <= 0:
		return "Slot %d: %s" % [int(slot.get("id", 0)), status]

	var percent := int(round(float(energy) / float(max_energy) * 100.0))
	return "Slot %d: %s %s %d/%d (%d%%)" % [
		int(slot.get("id", 0)),
		species,
		status,
		energy,
		max_energy,
		percent,
	]

func _on_add_steps(amount: int) -> void:
	StepEngine.add_debug_steps(amount)

func _on_hatch_pressed(slot_id: int) -> void:
	HatchEngine.hatch(slot_id)

func _on_reset_pressed() -> void:
	SaveManager.reset_game()
	get_tree().reload_current_scene()
