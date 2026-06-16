extends Node

signal backpack_capacity_expanded(new_capacity: int)

const INITIAL_CAPACITY := 24
const HARD_CAP := 36

# Ordered tiers: capacity unlocked when either threshold is met.
const EXPAND_TIERS: Array[Dictionary] = [
	{"capacity": 28, "steps": 300_000,   "postcards": 5},
	{"capacity": 32, "steps": 500_000,   "postcards": 10},
	{"capacity": 36, "steps": 1_000_000, "postcards": 20},
]

var backpack_max_capacity: int = INITIAL_CAPACITY


func _ready() -> void:
	if Engine.has_singleton("EventBus"):
		var eb := Engine.get_singleton("EventBus") as Node
		if eb.has_signal("steps_updated") and not eb.steps_updated.is_connected(_on_steps_updated):
			eb.steps_updated.connect(_on_steps_updated)
		if eb.has_signal("postcard_received") and not eb.postcard_received.is_connected(_on_postcard_received):
			eb.postcard_received.connect(_on_postcard_received)


func get_max_capacity() -> int:
	return backpack_max_capacity


func check_expansion(total_steps: int, postcard_count: int) -> void:
	var target := INITIAL_CAPACITY
	for tier: Dictionary in EXPAND_TIERS:
		if total_steps >= tier["steps"] or postcard_count >= tier["postcards"]:
			target = tier["capacity"]
	if target > backpack_max_capacity:
		_expand_to(target)


func apply_save(data: Dictionary) -> void:
	backpack_max_capacity = clampi(
		int(data.get("backpack_max_capacity", INITIAL_CAPACITY)),
		INITIAL_CAPACITY,
		HARD_CAP
	)


func get_save_data() -> Dictionary:
	return {"backpack_max_capacity": backpack_max_capacity}


func get_expansion_milestones() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tier: Dictionary in EXPAND_TIERS:
		result.append({
			"capacity":           tier["capacity"],
			"steps_required":     tier["steps"],
			"postcards_required": tier["postcards"],
			"unlocked":           backpack_max_capacity >= tier["capacity"],
		})
	return result


# ── Internal ──────────────────────────────────────────────────────────────────

func _expand_to(new_cap: int) -> void:
	new_cap = mini(new_cap, HARD_CAP)
	if new_cap <= backpack_max_capacity:
		return
	backpack_max_capacity = new_cap
	backpack_capacity_expanded.emit(backpack_max_capacity)


func _on_steps_updated(total_steps: int) -> void:
	var postcard_count := 0
	if has_node("/root/SaveManager"):
		postcard_count = int(SaveManager.get_save_data().get("postcard_count", 0))
	check_expansion(total_steps, postcard_count)


func _on_postcard_received(postcard_count: int) -> void:
	var total_steps := 0
	if has_node("/root/SaveManager"):
		total_steps = int(SaveManager.get_save_data().get("total_steps", 0))
	check_expansion(total_steps, postcard_count)
