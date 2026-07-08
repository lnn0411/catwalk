extends "res://ui/UIPage.gd"
# ============================================================
# S06 孵化屋 —— 概念图 1:1 布局（贴图驱动）
# 结构在 S06_HatchPage.tscn；本脚本负责绑定节点 + 状态驱动 + 交互。
# ============================================================

const CatData := preload("res://core/CatData.gd")
const WORKSHOP_SCENE := "res://scenes/WorkshopPage.gd"

@onready var _back_btn: TextureButton = %BackBtn
@onready var _ad_btn: TextureButton = %AdBtn
@onready var _workshop_link: Label = %WorkshopLink
@onready var _slots_parent: Array = [%Slot0, %Slot1, %Slot2, %Slot3]


func _ready() -> void:
	super._ready()
	_back_btn.pressed.connect(_on_back_pressed)
	_ad_btn.pressed.connect(_speed_up)
	_workshop_link.gui_input.connect(_on_workshop_clicked)
	for i in range(_slots_parent.size()):
		var slot_node = _slots_parent[i]
		# 实例化 HatchSlot 到占位节点
		if slot_node.get_child_count() == 0:
			var packed := load("res://scenes/components/HatchSlot.tscn")
			var slot = packed.instantiate()
			slot.slot_index = i
			if not slot.slot_pressed.is_connected(_on_slot_pressed):
				slot.slot_pressed.connect(_on_slot_pressed)
			slot_node.add_child(slot)
	_connect_data()
	_refresh_all()


func on_enter(_data: Dictionary = {}) -> void:
	_refresh_all()


func handle_back() -> bool:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")
	return true


func _exit_tree() -> void:
	if HatchEngine:
		if HatchEngine.hatch_progress.is_connected(_on_hatch_progress):
			HatchEngine.hatch_progress.disconnect(_on_hatch_progress)
		if HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
			HatchEngine.hatch_complete.disconnect(_on_hatch_complete)
	if EnergyEngine and EnergyEngine.energy_changed.is_connected(_on_energy_changed):
		EnergyEngine.energy_changed.disconnect(_on_energy_changed)


func _connect_data() -> void:
	if HatchEngine:
		if not HatchEngine.hatch_progress.is_connected(_on_hatch_progress):
			HatchEngine.hatch_progress.connect(_on_hatch_progress)
		if not HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
			HatchEngine.hatch_complete.connect(_on_hatch_complete)
	if EnergyEngine and not EnergyEngine.energy_changed.is_connected(_on_energy_changed):
		EnergyEngine.energy_changed.connect(_on_energy_changed)


# ── 刷新 ──

func _refresh_all() -> void:
	_refresh_slots()
	_refresh_ad_button()


func _refresh_slots() -> void:
	var slots: Array = HatchEngine.get_slots() if HatchEngine else []
	for i in range(_slots_parent.size()):
		var data: Dictionary = Dictionary(slots[i]) if i < slots.size() else {}
		var slot_node = _slots_parent[i].get_child(0) if _slots_parent[i].get_child_count() > 0 else null
		if slot_node and slot_node.has_method("set_data"):
			slot_node.set_data(data)


func _refresh_ad_button() -> void:
	var remaining: int = HatchEngine.ad_speedup_remaining() if HatchEngine else 0
	var label := _ad_btn.get_node_or_null("AdLabel") as Label
	if label:
		label.text = "补充能量 +3,000  今日还可%d次" % remaining
		label.add_theme_color_override("font_color", Color(1,1,1,0.5) if remaining <= 0 else Color(1,1,1,1))
	_ad_btn.disabled = false


# ── 交互 ──

func _on_back_pressed() -> void:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")


func _on_workshop_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		UIManager.push(WORKSHOP_SCENE)
	elif event is InputEventScreenTouch and event.pressed:
		UIManager.push(WORKSHOP_SCENE)


func _on_slot_pressed(index: int) -> void:
	if HatchEngine == null or index < 0:
		return
	var slots: Array = HatchEngine.get_slots()
	if index >= slots.size():
		return
	var slot_node = _slots_parent[index].get_child(0) if _slots_parent[index].get_child_count() > 0 else null
	if slot_node and slot_node.has_method("_effective_status") and slot_node._effective_status(Dictionary(slots[index])) != "ready":
		return
	# 背包满时阻止收取并提示
	if HatchEngine and HatchEngine._get_max_capacity() and HatchEngine.get_cats().size() >= HatchEngine._get_max_capacity():
		if Popups: Popups.show_toast("🏠 猫咪住满了，先去送养或扩容吧")
		return
	var j := get_node_or_null("/root/Juice")
	if j: j.hit()
	HatchEngine.collect_ready_slot(index)
	if SaveManager:
		SaveManager.save_all()
	_refresh_slots()


func _speed_up() -> void:
	if HatchEngine == null:
		return
	if not HatchEngine.has_filling_egg():
		if Popups: Popups.show_toast("当前没有正在孵化的蛋")
		return
	if not HatchEngine.can_ad_speedup():
		if Popups: Popups.show_toast("今日加速次数已用完")
		return
	HatchEngine.consume_ad_speedup()
	var used: float = HatchEngine.feed_current_egg(HatchEngine.AD_SPEEDUP_ENERGY)
	var leftover: float = HatchEngine.AD_SPEEDUP_ENERGY - used
	if leftover > 0.0 and EnergyEngine:
		EnergyEngine.add_pool_with_overflow(leftover)
	if SaveManager:
		SaveManager.save_all()
	_refresh_all()


# ── 信号回调 ──

func _on_hatch_progress(_slot: int, _progress: float) -> void:
	_refresh_slots()


func _on_hatch_complete(cat_data) -> void:
	_refresh_slots()
	UIManager.push("res://scenes/S08_HatchShow.tscn", {"cat": cat_data})


func _on_energy_changed(_current: float, _pool_max: float) -> void:
	pass
