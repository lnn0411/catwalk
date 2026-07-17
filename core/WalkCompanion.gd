# WalkCompanion — 伴走系统 (Autoload / B1 D1)
# 不要加 class_name，autoload 注册已提供全局名称。
#
# 两个特性：
#  1) 随行碎碎念：随行猫陪走时，每满 1000 步触发一条品种专属短语，
#     每日上限 5 条（跨本地日期重置）。通过信号广播给 UI 弹条。
#  2) 散步小结：每天首次开 app 时，若今日步数 ≥ 1000 且当日未展示过，
#     弹出 15 秒小结卡片。同一天只展示一次。
extends Node

const CompanionChatter := preload("res://config/companion_chatter.gd")

const STEP_MILESTONE := 1000            # 每 1000 步触发一次碎碎念
const DAILY_CHATTER_CAP := 5            # 每日碎碎念上限
const SUMMARY_MIN_STEPS := 1000         # 触发散步小结的今日最低步数
const SUMMARY_CARD_SCENE := "res://ui/pages/WalkSummaryCard.tscn"

# 碎碎念触发：品种 + 短语文本
signal chatter_triggered(breed: String, phrase: String)
# 散步小结就绪：今日步数 + 随行猫名字
signal walk_summary_ready(steps: int, companion_name: String)

# --- 持久化状态 ---
var last_milestone_count: int = 0       # 上次已结算的里程碑数 floor(total/1000)
var chatter_count_today: int = 0        # 今日已触发碎碎念条数
var chatter_date: String = ""           # 碎碎念计数所属日期
var last_chatter_index: int = -1        # 上一条碎碎念下标（避免连续重复）
var last_summary_date: String = ""      # 上次展示散步小结的日期
var summary_shown_today: bool = false   # 今日是否已展示小结（内存态，跨天/存档重算）

var _connected := false


func _ready() -> void:
	_connect_step_engine()
	# 散步小结延迟到花园加载完成后展示（避免在加载页一闪而过）
	if UIManager and UIManager.has_signal("page_changed") and not UIManager.page_changed.is_connected(_on_page_changed_for_summary):
		UIManager.page_changed.connect(_on_page_changed_for_summary)


func _on_page_changed_for_summary(page_name: String) -> void:
	if page_name == "S04_GardenMain":
		_evaluate_summary_on_start()
		if UIManager and UIManager.page_changed.is_connected(_on_page_changed_for_summary):
			UIManager.page_changed.disconnect(_on_page_changed_for_summary)


# app 从后台回到前台：可能已经跨天，需要重新评估小结与每日重置。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_roll_daily_reset()
		call_deferred("_evaluate_summary_on_start")


func _connect_step_engine() -> void:
	if _connected:
		return
	if StepEngine and StepEngine.has_signal("steps_updated"):
		if not StepEngine.steps_updated.is_connected(_on_steps_updated):
			StepEngine.steps_updated.connect(_on_steps_updated)
		_connected = true


# ------------------------------------------------------------------
# 特性1：随行碎碎念
# ------------------------------------------------------------------
func _on_steps_updated(delta: int, total: int) -> void:
	var milestone: int = int(floor(float(max(total, 0)) / float(STEP_MILESTONE)))

	# delta <= 0 出现在存档回灌、后台唤醒对齐、传感器重置等非真实行走场景：
	# 只把里程碑对齐到当前累计值，绝不补发碎碎念，也不写存档（避免载入期误存）。
	if delta <= 0:
		last_milestone_count = milestone
		return

	_roll_daily_reset()

	if milestone <= last_milestone_count:
		if milestone < last_milestone_count:
			last_milestone_count = milestone
		return

	# 只在有随行猫时触发；无随行猫也要推进里程碑，避免下次一次性补发。
	var crossings: int = milestone - last_milestone_count
	last_milestone_count = milestone

	var breed: String = _get_companion_breed()
	if breed == "":
		return

	# 单次更新最多播一条：真实行走每 tick 通常只跨 1 个里程碑，而后台唤醒/存档回灌
	# 可能一次跨多个（crossings > 1）。逐个补发会「爆条」，故里程碑照常一次性推进
	# （已在上方完成），碎碎念每次调用只播一条，仍受每日上限约束。
	if crossings > 0 and chatter_count_today < DAILY_CHATTER_CAP:
		_fire_chatter(breed)


func _fire_chatter(breed: String) -> void:
	var picked: Dictionary = CompanionChatter.draw_phrase(breed, last_chatter_index)
	var phrase: String = String(picked.get("phrase", ""))
	if phrase == "":
		return
	last_chatter_index = int(picked.get("index", -1))
	chatter_count_today += 1
	chatter_triggered.emit(breed, phrase)
	_persist()


# ------------------------------------------------------------------
# 特性2：散步小结
# ------------------------------------------------------------------
func _evaluate_summary_on_start() -> void:
	_roll_daily_reset()
	if summary_shown_today:
		return
	var steps: int = _get_today_steps()
	if steps < SUMMARY_MIN_STEPS:
		return

	var companion_name: String = _get_companion_name()
	walk_summary_ready.emit(steps, companion_name)

	# 卡片真正交给 UIManager 后，再标记「今日已展示」并落存档，防止同一天重复弹出；
	# 若展示失败（UIManager 尚未就绪），不锁定当天，留待下次评估重试。
	if not _show_summary_card(steps, companion_name):
		return
	summary_shown_today = true
	last_summary_date = _today_key()
	_persist()


func _show_summary_card(steps: int, companion_name: String) -> bool:
	if UIManager == null or not UIManager.has_method("push"):
		return false
	var data := {
		"steps": steps,
		"companion_name": companion_name,
		"breed": _get_companion_breed(),
	}
	UIManager.push(SUMMARY_CARD_SCENE, data)
	return true


# ------------------------------------------------------------------
# 每日重置
# ------------------------------------------------------------------
func _roll_daily_reset() -> void:
	var today: String = _today_key()
	if chatter_date == "":
		chatter_date = today
	elif chatter_date != today:
		chatter_count_today = 0
		last_chatter_index = -1
		chatter_date = today
	# 小结跨天：新的一天重新允许展示。
	if last_summary_date != today:
		summary_shown_today = false


# ------------------------------------------------------------------
# 随行猫信息（从 HatchEngine 读取）
# ------------------------------------------------------------------
func _get_companion() -> Variant:
	if HatchEngine == null:
		return null
	var cat_id: String = ""
	if "current_companion_cat_id" in HatchEngine:
		cat_id = String(HatchEngine.current_companion_cat_id)
	if cat_id == "":
		return null
	if HatchEngine.has_method("get_cat_by_id"):
		return HatchEngine.get_cat_by_id(cat_id)
	return null


func _get_companion_breed() -> String:
	var cat: Variant = _get_companion()
	if cat == null:
		return ""
	var breed: String = ""
	if typeof(cat) == TYPE_DICTIONARY:
		breed = String(cat.get("species", cat.get("breed", "")))
	elif "species" in cat:
		breed = String(cat.species)
	if not CompanionChatter.CHATTER_POOLS.has(breed):
		return ""
	return breed


func _get_companion_name() -> String:
	var cat: Variant = _get_companion()
	if cat == null:
		return ""
	if typeof(cat) == TYPE_DICTIONARY:
		return String(cat.get("display_name", cat.get("name", "")))
	elif "display_name" in cat:
		return String(cat.display_name)
	return ""


func _get_today_steps() -> int:
	if StepEngine and StepEngine.has_method("get_today_steps"):
		return int(StepEngine.get_today_steps())
	return 0


func _today_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]


# ------------------------------------------------------------------
# 存档（SaveManager 通过 apply_save / get_save_data 对接）
# ------------------------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"last_milestone_count": last_milestone_count,
		"chatter_count_today": chatter_count_today,
		"chatter_date": chatter_date,
		"last_chatter_index": last_chatter_index,
		"last_summary_date": last_summary_date,
	}


func apply_save(data: Dictionary) -> void:
	last_milestone_count = max(int(data.get("last_milestone_count", 0)), 0)
	chatter_count_today = max(int(data.get("chatter_count_today", 0)), 0)
	chatter_date = String(data.get("chatter_date", ""))
	last_chatter_index = int(data.get("last_chatter_index", -1))
	last_summary_date = String(data.get("last_summary_date", ""))
	# 从存档恢复后，先按当前日期结算重置；summary_shown_today 依 last_summary_date 推导。
	summary_shown_today = (last_summary_date == _today_key())
	_roll_daily_reset()
	# 里程碑对齐当前累计步数，避免存档载入瞬间补发历史碎碎念。
	if StepEngine and StepEngine.has_method("get_total_steps"):
		var total: int = int(StepEngine.get_total_steps())
		var milestone: int = int(floor(float(max(total, 0)) / float(STEP_MILESTONE)))
		# 只在存档值明显落后时才抬高，避免覆盖尚未结算的合法里程碑。
		if milestone > last_milestone_count:
			last_milestone_count = milestone
	_connect_step_engine()


func _persist() -> void:
	if SaveManager and SaveManager.has_method("save_all"):
		SaveManager.save_all()
