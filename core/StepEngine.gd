extends Node

signal steps_updated(delta: int, total: int)
signal step_chest_opened(index: int, gold: int)

const PLUGIN_NAME := "StepCounter"

# 今日步数宝箱（P1：仅数据结构+结算，演出与广告位#4翻倍在 P2 合流卡接入；
# milestone 序号即 D12 三段式日循环的挂接位）。内容 [待sim校准]。
const CHEST_THRESHOLDS: Array[int] = [3000, 6000, 10000]
const CHEST_GOLD: Array[int] = [10, 20, 30]
var chest_claimed_today: Array = [false, false, false]
var chest_date: String = ""

var today_steps: int = 0
var total_steps: int = 0
var last_plugin_steps: int = 0
var last_step_date: String = ""
var _fresh_sensor_init: bool = false
var _fresh_hc_init: bool = false
var step_plugin: Object
var _poll_attempts: int = 0

func _ready() -> void:
	last_step_date = _today_key()
	_load_plugin()
	_poll_for_first_reading()
	# 尝试接入 Health Connect 日桶步数（可用时作为今日步数的权威来源）
	_connect_health_connect()

# app 从后台回到前台时，重读硬件累计步数，补回最小化/进程被杀期间走的步。
# TYPE_STEP_COUNTER 在固件层计数，进程死了也照常累加，这里读一次即可对齐。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_check_daily_reset()
		_refresh_plugin_steps()
		# Health Connect 冷启动时已在插件后台线程异步读取，resume 无需额外触发；
		# 若之前已拿到 HC 数据，也不在此覆写，避免旧日桶值回退今日步数。
		await get_tree().create_timer(0.5).timeout
		if is_inside_tree():
			_refresh_plugin_steps()

func add_mock_steps(n: int) -> void:
	_check_daily_reset()
	var delta: int = max(n, 0)
	if delta <= 0:
		_emit_steps_updated(0)
		return

	today_steps += delta
	total_steps += delta
	_emit_steps_updated(delta)

func apply_save(data: Dictionary) -> void:
	today_steps = max(int(data.get("today_steps", 0)), 0)
	total_steps = max(int(data.get("total_steps", 0)), 0)
	last_plugin_steps = max(int(data.get("last_plugin_steps", 0)), 0)
	last_step_date = String(data.get("last_step_date", _today_key()))
	chest_claimed_today = Array(data.get("chest_claimed_today", [false, false, false]))
	while chest_claimed_today.size() < CHEST_THRESHOLDS.size():
		chest_claimed_today.append(false)
	chest_date = String(data.get("chest_date", ""))
	_fresh_sensor_init = (total_steps == 0 and last_plugin_steps == 0)
	_fresh_hc_init = _fresh_sensor_init
	_check_daily_reset()
	# 不在此 emit steps_updated：加载后 _refresh_plugin_steps 统一对齐，避免在
	# AchievementSystem.apply_save() 之前触发成就检查导致错误弹窗。

func get_today_steps() -> int:
	_check_daily_reset()
	return today_steps

func get_total_steps() -> int:
	return total_steps

func get_save_data() -> Dictionary:
	return {
		"today_steps": today_steps,
		"total_steps": total_steps,
		"last_plugin_steps": last_plugin_steps,
		"last_step_date": last_step_date,
		"chest_claimed_today": chest_claimed_today.duplicate(),
		"chest_date": chest_date,
	}

func _load_plugin() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		step_plugin = Engine.get_singleton(PLUGIN_NAME)
		if step_plugin.has_signal("steps_changed"):
			step_plugin.steps_changed.connect(_on_plugin_steps_changed)
	else:
		_emit_steps_updated(0)
	# 第一次同步交给 SaveManager.load_and_apply() 末尾

func _refresh_plugin_steps() -> void:
	if step_plugin == null or not step_plugin.has_method("getSteps"):
		return
	var raw: int = int(step_plugin.getSteps())
	if raw < 0:
		return  # 插件尚未拿到传感器读数（返回 -1），跳过，避免误判为设备重启
	_on_plugin_steps_changed(raw)

func _on_plugin_steps_changed(raw_steps: int) -> void:
	_check_daily_reset()
	raw_steps = max(raw_steps, 0)
	if _fresh_sensor_init and raw_steps > 0:
		_fresh_sensor_init = false
		last_plugin_steps = raw_steps
		_emit_steps_updated(0)
		return
	if raw_steps < last_plugin_steps:
		last_plugin_steps = raw_steps
		_emit_steps_updated(0)
		return

	var delta: int = raw_steps - last_plugin_steps
	last_plugin_steps = raw_steps
	if delta <= 0:
		_emit_steps_updated(0)
		return
	today_steps += delta
	total_steps += delta
	_emit_steps_updated(delta)

func _poll_for_first_reading() -> void:
	_poll_attempts += 1
	if _poll_attempts > 10:
		_poll_attempts = 0
		return

	_refresh_plugin_steps()
	if step_plugin != null and step_plugin.has_method("getSteps") and int(step_plugin.getSteps()) < 0:
		await get_tree().create_timer(1.0).timeout
		if is_inside_tree():
			_poll_for_first_reading()


# ── Health Connect 日桶步数（辅助数据源）───────────────────────────────
# TYPE_STEP_COUNTER 只能捕获 app 存活期间的传感器增量；Health Connect 提供
# 系统级"今日累计"日桶，可补回进程被杀/设备重启期间漏记的步数。
# 仅当 HC 值高于当前 today_steps 时向上对齐，永不回退；HC 不可用（-1）时
# 静默降级，TYPE_STEP_COUNTER 差值方案继续独立工作。
func _connect_health_connect() -> void:
	if step_plugin == null:
		return
	if step_plugin.has_signal("health_connect_steps"):
		if not step_plugin.health_connect_steps.is_connected(_on_health_connect_steps):
			step_plugin.health_connect_steps.connect(_on_health_connect_steps)
	# 插件可能已在后台线程读完，尝试同步取一次缓存值。
	_refresh_health_connect_steps()

func _refresh_health_connect_steps() -> void:
	if step_plugin == null or not step_plugin.has_method("getHealthConnectTodaySteps"):
		return
	_apply_health_connect_steps(int(step_plugin.getHealthConnectTodaySteps()))

func _on_health_connect_steps(hc_steps: int) -> void:
	# Health Connect 后台线程读取完成后的异步回调。
	_apply_health_connect_steps(int(hc_steps))

func _apply_health_connect_steps(hc_steps: int) -> void:
	_check_daily_reset()
	if hc_steps < 0:
		return  # HC 不可用（返回 -1）：静默跳过
	if _fresh_hc_init:
		_fresh_hc_init = false
		return
	if hc_steps <= today_steps:
		return  # 旧日桶值不回退今日步数
	var delta: int = hc_steps - today_steps
	today_steps = hc_steps
	total_steps += delta  # 补回 HC 记录但传感器未捕获的步数（如进程被杀/设备重启）
	_emit_steps_updated(delta)

func _check_daily_reset() -> void:
	var today: String = _today_key()
	if last_step_date == "":
		last_step_date = today
		return
	if last_step_date != today:
		today_steps = 0
		# 不重置 last_plugin_steps：Android TYPE_STEP_COUNTER 是开机累计，
		# 归零后下次回调会把硬件累计值整笔当今日步数注入（DEF-01 P0）。
		last_step_date = today

func _emit_steps_updated(delta: int) -> void:
	_check_step_chests()
	steps_updated.emit(delta, total_steps)

func _check_step_chests() -> void:
	var today: String = _today_key()
	if chest_date != today:
		chest_date = today
		chest_claimed_today = [false, false, false]
	for i in range(CHEST_THRESHOLDS.size()):
		if not bool(chest_claimed_today[i]) and today_steps >= int(CHEST_THRESHOLDS[i]):
			chest_claimed_today[i] = true
			var gold: int = int(CHEST_GOLD[i])
			if CurrencyManager:
				CurrencyManager.add_gold(gold, "step_chest")
			preload("res://core/CoreTelemetry.gd").log_event("step_chest", {"index": i, "gold": gold})
			step_chest_opened.emit(i, gold)

func _today_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]
