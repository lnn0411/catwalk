extends Node

class_name WorkshopManager

signal slot_energy_changed(slot_index: int, current: float, max: float)
signal slot_box_ready(slot_index: int)
signal slot_box_opened(slot_index: int, gift_id: String)
signal all_slots_full()

const CatDataScript := preload("res://core/CatData.gd")
const WorkshopDataScript := preload("res://core/WorkshopData.gd")

const MAX_SLOTS := 3
const ENERGY_PER_SLOT := 3000.0

const STATUS_FILLING := "filling"
const STATUS_BOX_READY := "box_ready"
const STATUS_BOX_OPENED := "box_opened"

var slots: Array[Dictionary] = []
var _workshop_data_instance: Node = null

func _ready() -> void:
	_initialize_slots()
	_ensure_workshop_data_instance()
	_connect_event_bus()

func _on_workshop_activated(data: Dictionary = {}) -> void:
	var _activation_data := data
	if not has_node("/root/HatchEngine"):
		return
	var hatch_engine := get_node("/root/HatchEngine")
	var cached_energy: float = float(hatch_engine.get("workshop_cached_energy"))
	allocate_energy(cached_energy)
	hatch_engine.set("workshop_cached_energy", 0.0)
	_save_state()

func _on_hatch_activated() -> void:
	_save_state()

func allocate_energy(amount: float) -> void:
	var remaining: float = maxf(amount, 0.0)
	if remaining <= 0.0:
		return
	for slot_index in range(MAX_SLOTS):
		var slot: Dictionary = slots[slot_index]
		if String(slot.get("status", STATUS_FILLING)) != STATUS_FILLING:
			continue
		var current_energy: float = float(slot.get("energy", 0.0))
		var need: float = maxf(ENERGY_PER_SLOT - current_energy, 0.0)
		var added: float = minf(remaining, need)
		if added <= 0.0:
			continue
		current_energy = minf(current_energy + added, ENERGY_PER_SLOT)
		slot["energy"] = current_energy
		remaining -= added
		slots[slot_index] = slot
		slot_energy_changed.emit(slot_index, current_energy, ENERGY_PER_SLOT)
		if current_energy >= ENERGY_PER_SLOT:
			slot["status"] = STATUS_BOX_READY
			slot["energy"] = ENERGY_PER_SLOT
			slots[slot_index] = slot
			slot_box_ready.emit(slot_index)
		if remaining <= 0.0:
			break
	if _are_all_slots_ready():
		all_slots_full.emit()
	_save_state()

func open_box(slot_index: int) -> void:
	if not _is_valid_slot_index(slot_index):
		return
	var slot: Dictionary = slots[slot_index]
	if String(slot.get("status", "")) != STATUS_BOX_READY:
		return
	var workshop_data := _get_workshop_data()
	if workshop_data == null or not workshop_data.has_method("roll_gift"):
		return
	var gift_id: String = String(workshop_data.roll_gift())
	slot["gift_id"] = gift_id
	slot["status"] = STATUS_BOX_OPENED
	slots[slot_index] = slot
	if has_node("/root/GiftInventory"):
		var gift_inventory := get_node("/root/GiftInventory")
		if gift_inventory.has_method("add_gift"):
			gift_inventory.add_gift(gift_id)
	slot_box_opened.emit(slot_index, gift_id)
	_save_state()

func reset_slot(slot_index: int) -> void:
	if not _is_valid_slot_index(slot_index):
		return
	slots[slot_index] = _make_slot(slot_index)
	slot_energy_changed.emit(slot_index, 0.0, ENERGY_PER_SLOT)
	_save_state()

func get_slot_data(slot_index: int) -> Dictionary:
	if not _is_valid_slot_index(slot_index):
		return {}
	return slots[slot_index].duplicate(true)

func is_any_box_ready() -> bool:
	for slot in slots:
		if String(slot.get("status", "")) == STATUS_BOX_READY:
			return true
	return false

func get_total_filled_energy() -> float:
	var total := 0.0
	for slot in slots:
		total += float(slot.get("energy", 0.0))
	return total

func get_save_data() -> Dictionary:
	return { "slots": slots.duplicate(true) }

func apply_save(data: Dictionary) -> void:
	var saved_slots: Array = Array(data.get("slots", []))
	slots.clear()
	for i in range(MAX_SLOTS):
		var slot_data := {}
		if i < saved_slots.size() and saved_slots[i] is Dictionary:
			slot_data = Dictionary(saved_slots[i])
		slots.append(_normalize_slot(slot_data, i))
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		slot_energy_changed.emit(i, float(slot.get("energy", 0.0)), ENERGY_PER_SLOT)
		if String(slot.get("status", "")) == STATUS_BOX_READY:
			slot_box_ready.emit(i)
	if _are_all_slots_ready():
		all_slots_full.emit()

func _initialize_slots() -> void:
	slots.clear()
	for i in range(MAX_SLOTS):
		slots.append(_make_slot(i))

func _connect_event_bus() -> void:
	if not has_node("/root/EventBus"):
		return
	var event_bus := get_node("/root/EventBus")
	if event_bus.has_signal("workshop_activated") and not event_bus.workshop_activated.is_connected(_on_workshop_activated):
		event_bus.workshop_activated.connect(_on_workshop_activated)
	if event_bus.has_signal("hatch_activated") and not event_bus.hatch_activated.is_connected(_on_hatch_activated):
		event_bus.hatch_activated.connect(_on_hatch_activated)

func _make_slot(slot_index: int) -> Dictionary:
	return { "slot_index": slot_index, "energy": 0.0, "status": STATUS_FILLING, "gift_id": "" }

func _normalize_slot(slot_data: Dictionary, slot_index: int) -> Dictionary:
	var status := String(slot_data.get("status", STATUS_FILLING))
	if status != STATUS_FILLING and status != STATUS_BOX_READY and status != STATUS_BOX_OPENED:
		status = STATUS_FILLING
	var energy := clampf(float(slot_data.get("energy", 0.0)), 0.0, ENERGY_PER_SLOT)
	if status == STATUS_BOX_READY:
		energy = ENERGY_PER_SLOT
	return { "slot_index": slot_index, "energy": energy, "status": status, "gift_id": String(slot_data.get("gift_id", "")) }

func _is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slots.size()

func _are_all_slots_ready() -> bool:
	if slots.size() < MAX_SLOTS:
		return false
	for slot in slots:
		if String(slot.get("status", "")) != STATUS_BOX_READY:
			return false
	return true

func _ensure_workshop_data_instance() -> void:
	if has_node("/root/WorkshopData"):
		return
	if _workshop_data_instance != null:
		return
	_workshop_data_instance = WorkshopDataScript.new()
	_workshop_data_instance.name = "WorkshopDataLocal"
	add_child(_workshop_data_instance)

func _get_workshop_data() -> Node:
	if has_node("/root/WorkshopData"):
		return get_node("/root/WorkshopData")
	if _workshop_data_instance == null:
		_ensure_workshop_data_instance()
	return _workshop_data_instance

func _save_state() -> void:
	if has_node("/root/SaveManager"):
		var sm := get_node("/root/SaveManager")
		if sm.has_method("save_all"):
			sm.save_all()
