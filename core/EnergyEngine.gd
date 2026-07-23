extends Node

signal energy_changed(current: float, pool_max: float)
# B3 溢出收口：池满截断时发出（每自然日仅第一次），UI 弹温和 Toast；
# 同日再满只由 HUD 常显满态，不再打扰。
signal pool_became_full()

const MAX_ENERGY_POOL := 15000.0
const NEW_PLAYER_DAYS := 7

var energy_pool: float = 0.0
var total_energy_produced: float = 0.0
var today_energy: float = 0.0
var today_steps_processed: int = 0
var created_at: float = 0.0
var last_energy_date: String = ""
var pool_full_toast_date: String = ""

func _ready() -> void:
	if created_at <= 0.0:
		created_at = Time.get_unix_time_from_system()
	if last_energy_date == "":
		last_energy_date = _today_key()
	_emit_energy_changed()

# P1 费率翻转（launch_overhaul_master_plan P1 / energy_hatch_redesign_plan §2.1）：
# T1 0–1500 ×1.1 | T2 –4000 ×1.0 | T3 –6000 ×0.8 | T4 6000+ ×0.4。
# 新手保护期改为首 7 天全段 ×1.2（替代旧 T1 专属 0.8）。
func calc_energy(steps: int, is_new_player: bool) -> int:
	var s: float = float(max(steps, 0))
	var total: float = 0.0
	if s <= 1500.0:
		total = s * 1.1
	elif s <= 4000.0:
		total = 1500.0 * 1.1 + (s - 1500.0) * 1.0
	elif s <= 6000.0:
		total = 1500.0 * 1.1 + 2500.0 * 1.0 + (s - 4000.0) * 0.8
	else:
		total = 1500.0 * 1.1 + 2500.0 * 1.0 + 2000.0 * 0.8 + (s - 6000.0) * 0.4
	if is_new_player:
		total *= 1.2
	return int(total)

func process_steps(delta_steps: int) -> float:
	_check_daily_reset()
	var delta: int = max(delta_steps, 0)
	if delta <= 0:
		_emit_energy_changed()
		return 0.0

	today_steps_processed += delta
	var next_today_energy: float = float(calc_energy(today_steps_processed, is_new_player()))
	var produced: float = max(next_today_energy - today_energy, 0.0)
	today_energy = next_today_energy
	if produced <= 0.0:
		_emit_energy_changed()
		return 0.0

	var remaining: float = produced
	var pool_space: float = max(MAX_ENERGY_POOL - energy_pool, 0.0)
	var to_pool: float = min(remaining, pool_space)
	energy_pool += to_pool
	remaining -= to_pool
	if remaining > 0.0:
		_notify_pool_full()

	total_energy_produced += produced
	_emit_energy_changed()
	return produced

func _notify_pool_full() -> void:
	var today: String = _today_key()
	if pool_full_toast_date == today:
		return
	pool_full_toast_date = today
	pool_became_full.emit()

# 把一笔能量加进主池（GDD v3.1 R8：备用槽已移除，溢出直接截断）。
# 用于退回未用完的能量（如加速补能后当前蛋已满的剩余），不计入 total_energy_produced。
func add_pool_with_overflow(amount: float) -> void:
	var remaining: float = max(amount, 0.0)
	if remaining <= 0.0:
		return
	var pool_space: float = max(MAX_ENERGY_POOL - energy_pool, 0.0)
	var to_pool: float = min(remaining, pool_space)
	energy_pool += to_pool
	remaining -= to_pool
	if remaining > 0.0:
		_notify_pool_full()
	_emit_energy_changed()

func newbie_protection_remaining_days() -> int:
	var elapsed: float = max(Time.get_unix_time_from_system() - created_at, 0.0)
	var remaining_seconds: float = max(float(NEW_PLAYER_DAYS * 24 * 60 * 60) - elapsed, 0.0)
	return int(ceil(remaining_seconds / float(24 * 60 * 60)))

func is_new_player() -> bool:
	return newbie_protection_remaining_days() > 0

func apply_save(data: Dictionary) -> void:
	energy_pool = max(float(data.get("energy_pool", 0.0)), 0.0)
	var old_reserve: float = max(float(data.get("reserve_tank", 0.0)), 0.0)
	if old_reserve > 0.0:
		energy_pool = min(energy_pool + old_reserve, MAX_ENERGY_POOL)
	total_energy_produced = max(float(data.get("total_energy_produced", 0.0)), 0.0)
	today_energy = max(float(data.get("today_energy", 0.0)), 0.0)
	today_steps_processed = max(int(data.get("today_steps_processed", 0)), 0)
	created_at = float(data.get("created_at", Time.get_unix_time_from_system()))
	last_energy_date = String(data.get("last_energy_date", _today_key()))
	pool_full_toast_date = String(data.get("pool_full_toast_date", ""))
	_check_daily_reset()
	_emit_energy_changed()

func get_save_data() -> Dictionary:
	return {
		"energy_pool": energy_pool,
		"total_energy_produced": total_energy_produced,
		"today_energy": today_energy,
		"today_steps_processed": today_steps_processed,
		"created_at": created_at,
		"last_energy_date": last_energy_date,
		"pool_full_toast_date": pool_full_toast_date,
	}

func get_pool_fill_ratio() -> float:
	if MAX_ENERGY_POOL <= 0.0:
		return 0.0
	return energy_pool / MAX_ENERGY_POOL

# 从主能量池扣除能量（孵化消耗调用）。返回实际扣除量。
func spend_pool(amount: float) -> float:
	var take: float = clamp(amount, 0.0, energy_pool)
	if take <= 0.0:
		return 0.0
	energy_pool -= take
	_emit_energy_changed()
	return take

func _emit_energy_changed() -> void:
	energy_changed.emit(energy_pool, MAX_ENERGY_POOL)

func _check_daily_reset() -> void:
	var today: String = _today_key()
	if last_energy_date == "":
		last_energy_date = today
		return
	if last_energy_date != today:
		today_energy = 0.0
		today_steps_processed = 0
		last_energy_date = today

func _today_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]
