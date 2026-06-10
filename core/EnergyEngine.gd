extends Node

signal energy_changed(current: float, pool_max: float, backup: float)

const MAX_ENERGY_POOL := 15000.0
const MAX_RESERVE_TANK := 6000.0
const NEW_PLAYER_DAYS := 7

var energy_pool: float = 0.0
# Reserve energy auto-drains back into the pool whenever the pool has space.
var reserve_tank: float = 0.0
var total_energy_produced: float = 0.0
var today_energy: float = 0.0
var today_steps_processed: int = 0
var created_at: float = 0.0
var last_energy_date: String = ""

func _ready() -> void:
	if created_at <= 0.0:
		created_at = Time.get_unix_time_from_system()
	if last_energy_date == "":
		last_energy_date = _today_key()
	_emit_energy_changed()

func calc_energy(steps: int, is_new_player: bool) -> int:
	var t1 := 0.3
	if is_new_player:
		t1 = 0.8

	if steps <= 1000:
		return int(float(steps) * t1)
	if steps <= 3000:
		return int(1000.0 * t1 + float(steps - 1000) * 1.0)
	if steps <= 5000:
		return int(1000.0 * t1 + 2000.0 * 1.0 + float(steps - 3000) * 1.2)
	return int(1000.0 * t1 + 2000.0 * 1.0 + 2000.0 * 1.2 + float(steps - 5000) * 1.5)

func process_steps(delta_steps: int) -> float:
	_check_daily_reset()
	var delta: int = max(delta_steps, 0)
	if delta <= 0:
		_drain_reserve_to_pool()
		_emit_energy_changed()
		return 0.0

	today_steps_processed += delta
	var next_today_energy: float = float(calc_energy(today_steps_processed, is_new_player()))
	var produced: float = max(next_today_energy - today_energy, 0.0)
	today_energy = next_today_energy
	if produced <= 0.0:
		_drain_reserve_to_pool()
		_emit_energy_changed()
		return 0.0

	var remaining: float = produced
	var pool_space: float = max(MAX_ENERGY_POOL - energy_pool, 0.0)
	var to_pool: float = min(remaining, pool_space)
	energy_pool += to_pool
	remaining -= to_pool

	if remaining > 0.0:
		var reserve_space: float = max(MAX_RESERVE_TANK - reserve_tank, 0.0)
		var to_reserve: float = min(remaining, reserve_space)
		reserve_tank += to_reserve

	total_energy_produced += produced
	_drain_reserve_to_pool()
	_emit_energy_changed()
	return produced

func newbie_protection_remaining_days() -> int:
	var elapsed: float = max(Time.get_unix_time_from_system() - created_at, 0.0)
	var remaining_seconds: float = max(float(NEW_PLAYER_DAYS * 24 * 60 * 60) - elapsed, 0.0)
	return int(ceil(remaining_seconds / float(24 * 60 * 60)))

func is_new_player() -> bool:
	return newbie_protection_remaining_days() > 0

func apply_save(data: Dictionary) -> void:
	energy_pool = clamp(float(data.get("energy_pool", 0.0)), 0.0, MAX_ENERGY_POOL)
	reserve_tank = clamp(float(data.get("reserve_tank", 0.0)), 0.0, MAX_RESERVE_TANK)
	total_energy_produced = max(float(data.get("total_energy_produced", 0.0)), 0.0)
	today_energy = max(float(data.get("today_energy", 0.0)), 0.0)
	today_steps_processed = max(int(data.get("today_steps_processed", 0)), 0)
	created_at = float(data.get("created_at", Time.get_unix_time_from_system()))
	last_energy_date = String(data.get("last_energy_date", _today_key()))
	_check_daily_reset()
	_emit_energy_changed()

func get_save_data() -> Dictionary:
	return {
		"energy_pool": energy_pool,
		"reserve_tank": reserve_tank,
		"total_energy_produced": total_energy_produced,
		"today_energy": today_energy,
		"today_steps_processed": today_steps_processed,
		"created_at": created_at,
		"last_energy_date": last_energy_date,
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
	energy_changed.emit(energy_pool, MAX_ENERGY_POOL, reserve_tank)

func _drain_reserve_to_pool() -> void:
	while energy_pool < MAX_ENERGY_POOL and reserve_tank > 0.0:
		var pool_space: float = MAX_ENERGY_POOL - energy_pool
		var to_pool: float = min(pool_space, reserve_tank)
		energy_pool += to_pool
		reserve_tank -= to_pool

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
