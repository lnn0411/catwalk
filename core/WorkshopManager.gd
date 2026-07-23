extends Node

# C1 爱意工坊 · 独立步数礼盒模型（launch_overhaul_master_plan §2.2 / v2.2 §6）。
# 原始步数计数器驱动（与门票同源信号，不经费率系数），与能量池/包容量完全解耦。
# 旧能量槽位队列模型已废弃；旧档能量按 §6.4 迁移（⌊Σ/3000⌋ 折盒 + 余量折计数器）。

signal box_minted(unopened: int)
signal box_opened(gift_id: String, dupe_petals: int)
signal progress_changed(steps_into_box: int, box_steps: int)

const BOX_STEPS := 3000
const DAILY_BOX_CAP := 3
const UNOPENED_CAP := 5
const SAVE_PATH := "user://workshop.cfg"
# 配饰重复折爱心花瓣；花卉可重复持有但每种上限 5（C3 折算总表），超限折 10 花瓣
const DUPE_PETALS := {
	"common": 10,
	"rare": 25,
	"epic": 60,
	"legendary": 150,
}
const FLOWER_HOLD_CAP := 5
const FLOWER_OVERFLOW_PETALS := 10

var box_step_counter: int = 0
var unopened_boxes: int = 0
var boxes_today: int = 0
var boxes_date: String = ""


func _ready() -> void:
	if StepEngine and not StepEngine.steps_updated.is_connected(_on_steps_updated):
		StepEngine.steps_updated.connect(_on_steps_updated)


func _on_steps_updated(delta: int, _total: int) -> void:
	if delta <= 0:
		return
	_check_daily_reset()
	box_step_counter += delta
	_mint_boxes()
	progress_changed.emit(box_step_counter, BOX_STEPS)


# 铸盒：满 3000 步一盒；日上限 3、未开上限 5。达上限时计数器继续累计、
# 低于上限时补铸——走路永远不白走。
func _mint_boxes() -> void:
	_check_daily_reset()
	while (
		box_step_counter >= BOX_STEPS
		and boxes_today < DAILY_BOX_CAP
		and unopened_boxes < UNOPENED_CAP
	):
		box_step_counter -= BOX_STEPS
		unopened_boxes += 1
		boxes_today += 1
		box_minted.emit(unopened_boxes)


func open_box() -> Dictionary:
	if unopened_boxes <= 0:
		return {"success": false, "gift_id": "", "dupe_petals": 0}
	unopened_boxes -= 1
	var gift_id := ""
	if WorkshopData:
		gift_id = String(WorkshopData.roll_gift())
	if gift_id == "":
		gift_id = "deco_scarf"

	var dupe_petals: int = _grant_gift(gift_id)

	_mint_boxes()  # 腾出未开位后补铸攒下的步数
	box_opened.emit(gift_id, dupe_petals)
	if SaveManager:
		SaveManager.save_all()
	return {"success": true, "gift_id": gift_id, "dupe_petals": dupe_petals}


# 礼物入库/折算（C3 折算总表）：配饰重复→按稀有度折花瓣；
# 花卉每种持有上限 5，超限→10 花瓣。返回折算花瓣数（0=正常入库）。
func _grant_gift(gift_id: String) -> int:
	var gift: Dictionary = WorkshopData.get_gift_data(gift_id) if WorkshopData else {}
	var category := String(gift.get("category", ""))
	var held: int = GiftInventory.get_count(gift_id) if GiftInventory else 0
	var petals: int = 0
	if category == "deco" and held > 0:
		petals = int(DUPE_PETALS.get(String(gift.get("rarity", "common")), 10))
	elif category == "flower" and held >= FLOWER_HOLD_CAP:
		petals = FLOWER_OVERFLOW_PETALS
	if petals > 0:
		if CurrencyManager:
			CurrencyManager.add_love_petals(petals, "workshop_dupe")
		return petals
	if GiftInventory:
		GiftInventory.add_gift(gift_id)
	return 0


func get_unopened_count() -> int:
	return unopened_boxes


func get_progress() -> Dictionary:
	_check_daily_reset()
	return {
		"steps_into_box": box_step_counter,
		"box_steps": BOX_STEPS,
		"unopened": unopened_boxes,
		"boxes_today": boxes_today,
		"daily_cap": DAILY_BOX_CAP,
		"unopened_cap": UNOPENED_CAP,
	}


func _check_daily_reset() -> void:
	var date: Dictionary = Time.get_date_dict_from_system()
	var today := "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]
	if boxes_date != today:
		boxes_date = today
		boxes_today = 0


func get_save_data() -> Dictionary:
	return {
		"box_step_counter": box_step_counter,
		"unopened_boxes": unopened_boxes,
		"boxes_today": boxes_today,
		"boxes_date": boxes_date,
	}


func apply_save(data: Dictionary) -> void:
	if data.has("slots") and not data.has("box_step_counter"):
		_migrate_legacy_slots(Array(data.get("slots", [])))
		return
	box_step_counter = max(int(data.get("box_step_counter", 0)), 0)
	unopened_boxes = clampi(int(data.get("unopened_boxes", 0)), 0, UNOPENED_CAP)
	boxes_today = max(int(data.get("boxes_today", 0)), 0)
	boxes_date = String(data.get("boxes_date", ""))
	_check_daily_reset()


# 旧档迁移（v2.2 §6.4）：旧槽位能量合计 ⌊Σ/3000⌋ 折为待开礼盒（≤5），
# 余量按 1:1 折入步数计数器；box_ready 槽本身即一盒。
func _migrate_legacy_slots(legacy_slots: Array) -> void:
	var total_energy: float = 0.0
	var ready_boxes: int = 0
	for entry in legacy_slots:
		var slot: Dictionary = Dictionary(entry)
		if String(slot.get("status", "")) == "box_ready":
			ready_boxes += 1
		else:
			total_energy += max(float(slot.get("energy", 0.0)), 0.0)
	var energy_boxes: int = int(floor(total_energy / float(BOX_STEPS)))
	unopened_boxes = clampi(ready_boxes + energy_boxes, 0, UNOPENED_CAP)
	box_step_counter = int(total_energy) - energy_boxes * BOX_STEPS
	boxes_today = 0
	boxes_date = ""
	_check_daily_reset()
