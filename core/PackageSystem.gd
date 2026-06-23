extends Node

signal backpack_capacity_expanded(new_capacity: int)

const _INITIAL_CAPACITY := 24
const _HARD_CAP := 36
const _TIERS := [
	{"capacity": 28, "steps": 300_000, "postcards": 5},
	{"capacity": 32, "steps": 500_000, "postcards": 10},
	{"capacity": 36, "steps": 1_000_000, "postcards": 20},
]

var backpack_max_capacity: int = _INITIAL_CAPACITY


func _ready() -> void:
	if StepEngine and not StepEngine.steps_updated.is_connected(_on_steps_updated):
		StepEngine.steps_updated.connect(_on_steps_updated)


func get_max_capacity() -> int:
	return backpack_max_capacity


func get_capacity() -> int:
	return get_max_capacity()


func check_expansion(total_steps: int, postcard_count: int) -> void:
	if backpack_max_capacity >= _HARD_CAP:
		return
	var new_cap := backpack_max_capacity
	for tier in _TIERS:
		if tier["capacity"] <= new_cap:
			continue
		if total_steps >= tier["steps"] or postcard_count >= tier["postcards"]:
			new_cap = tier["capacity"]
	if new_cap > backpack_max_capacity:
		backpack_max_capacity = new_cap
		backpack_capacity_expanded.emit(backpack_max_capacity)


func set_capacity(cap: int) -> void:
	cap = clamp(cap, backpack_max_capacity, _HARD_CAP)
	if cap > backpack_max_capacity:
		backpack_max_capacity = cap
		backpack_capacity_expanded.emit(backpack_max_capacity)


func get_expansion_milestones() -> Array:
	var result: Array = []
	for tier in _TIERS:
		result.append({
			"capacity":  tier["capacity"],
			"steps":     tier["steps"],
			"postcards": tier["postcards"],
			"unlocked":  backpack_max_capacity >= tier["capacity"],
		})
	return result


func get_save_data() -> Dictionary:
	return {"backpack_max_capacity": backpack_max_capacity}


func apply_save(data: Dictionary) -> void:
	backpack_max_capacity = clamp(
		int(data.get("backpack_max_capacity", _INITIAL_CAPACITY)),
		_INITIAL_CAPACITY,
		_HARD_CAP
	)


func _on_steps_updated(_delta: int, total: int) -> void:
	var postcard_count := 0
	if AchievementSystem:
		postcard_count = int(AchievementSystem.get_save_data().get("postcard_count", 0))
	check_expansion(total, postcard_count)
