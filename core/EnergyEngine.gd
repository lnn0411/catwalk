extends Node

signal energy_changed(energy_pool: int, energy_reserve: int, total_energy_produced: int)
signal energy_produced(amount: int, today_energy: int)
signal energy_overflow(amount: int)

const MAX_ENERGY_POOL := 15000
const MAX_ENERGY_RESERVE := 6000
const OVERFLOW_WARNING_THRESHOLD := 13500

var energy_pool: int = 0
var energy_reserve: int = 0
var total_energy_produced: int = 0
var today_energy: int = 0

func _ready() -> void:
	_load_state()
	if StepEngine:
		StepEngine.steps_changed.connect(_on_steps_changed)
		_recalculate_from_steps(StepEngine.get_today_steps())

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

func add_energy(amount: int) -> void:
	if amount <= 0:
		return

	var remaining := amount
	var pool_space := MAX_ENERGY_POOL - energy_pool
	var to_pool = min(remaining, pool_space)
	energy_pool += to_pool
	remaining -= to_pool

	if remaining > 0:
		var reserve_space := MAX_ENERGY_RESERVE - energy_reserve
		var to_reserve = min(remaining, reserve_space)
		energy_reserve += to_reserve
		remaining -= to_reserve

	total_energy_produced += amount
	if remaining > 0:
		energy_overflow.emit(remaining)

	_save_state()
	energy_produced.emit(amount, today_energy)
	energy_changed.emit(energy_pool, energy_reserve, total_energy_produced)

	if HatchEngine:
		HatchEngine.add_energy(amount)

func consume_pool(amount: int) -> int:
	var consumed = min(max(amount, 0), energy_pool)
	energy_pool -= consumed
	_save_state()
	energy_changed.emit(energy_pool, energy_reserve, total_energy_produced)
	return consumed

func inject_reserve_to_hatch(amount: int) -> int:
	var injected = min(max(amount, 0), energy_reserve)
	energy_reserve -= injected
	_save_state()
	energy_changed.emit(energy_pool, energy_reserve, total_energy_produced)
	if HatchEngine:
		HatchEngine.add_energy(injected)
	return injected

func get_pool_fill_ratio() -> float:
	return float(energy_pool) / float(MAX_ENERGY_POOL)

func _on_steps_changed(steps: int, _total_steps: int, _delta_steps: int) -> void:
	_recalculate_from_steps(steps)

func _recalculate_from_steps(steps: int) -> void:
	var new_today_energy := calc_energy(steps, _is_new_player())
	var delta := new_today_energy - today_energy
	today_energy = new_today_energy
	if delta > 0:
		add_energy(delta)
	else:
		_save_state()
		energy_changed.emit(energy_pool, energy_reserve, total_energy_produced)

func _is_new_player() -> bool:
	if SaveManager:
		return SaveManager.is_new_player()
	return true

func _load_state() -> void:
	if SaveManager:
		var state := SaveManager.get_energy_state()
		energy_pool = int(state.get("energy_pool", 0))
		energy_reserve = int(state.get("energy_reserve", 0))
		total_energy_produced = int(state.get("total_energy_produced", 0))
		today_energy = int(state.get("today_energy", 0))

func _save_state() -> void:
	if SaveManager:
		SaveManager.set_energy_state({
			"energy_pool": energy_pool,
			"energy_reserve": energy_reserve,
			"total_energy_produced": total_energy_produced,
			"today_energy": today_energy,
		})
