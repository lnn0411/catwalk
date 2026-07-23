extends Node

signal backpack_capacity_expanded(new_capacity: int)
signal expansion_available(unlock_count: int, cost_gold: int, capacity: int)

const _INITIAL_CAPACITY := 24
const _HARD_CAP := 36
# P1/B4：首档 5000→7000（sim 收敛值：中活跃自然分布 D19~40，月卡提前~2天属付费权益）
const _TIERS := [
	{"capacity": 28, "unlock_count": 4,  "cost_gold": 7000},
	{"capacity": 32, "unlock_count": 8, "cost_gold": 10000},
	{"capacity": 36, "unlock_count": 12, "cost_gold": 0},
]

var backpack_max_capacity: int = _INITIAL_CAPACITY

func get_max_capacity() -> int:
	return backpack_max_capacity

func get_capacity() -> int:
	return get_max_capacity()

# Called when a new cat is hatched (from HatchEngine signal).
# Checks if player has enough unique species to qualify for a new tier.
# If cost is 0, auto-expands. If cost > 0, tries to charge gold.
func check_expansion(unlock_count: int) -> void:
	if backpack_max_capacity >= _HARD_CAP:
		return
	var tier_index: int = -1
	for i in range(_TIERS.size()):
		if _TIERS[i]["capacity"] > backpack_max_capacity and unlock_count >= _TIERS[i]["unlock_count"]:
			tier_index = i
			break
	if tier_index == -1:
		return
	var tier: Dictionary = _TIERS[tier_index]
	var cost := int(tier["cost_gold"])
	if cost <= 0:
		backpack_max_capacity = tier["capacity"]
		backpack_capacity_expanded.emit(backpack_max_capacity)
		print("[PackageSystem] Free expansion to cap ", backpack_max_capacity)
		return
	# Cost > 0: check gold
	if CurrencyManager and CurrencyManager.spend_gold(cost):
		backpack_max_capacity = tier["capacity"]
		backpack_capacity_expanded.emit(backpack_max_capacity)
		print("[PackageSystem] Purchased expansion to cap ", backpack_max_capacity, " for ", cost, " gold")
	else:
		print("[PackageSystem] Cannot afford expansion: need ", cost, " gold")
		expansion_available.emit(unlock_count, cost, tier["capacity"])

func set_capacity(cap: int) -> void:
	cap = clamp(cap, backpack_max_capacity, _HARD_CAP)
	if cap > backpack_max_capacity:
		backpack_max_capacity = cap
		backpack_capacity_expanded.emit(backpack_max_capacity)

func get_expansion_milestones() -> Array:
	var result: Array = []
	for tier in _TIERS:
		result.append({
			"capacity":     tier["capacity"],
			"unlock_count": tier["unlock_count"],
			"cost_gold":    tier["cost_gold"],
			"unlocked":     backpack_max_capacity >= tier["capacity"],
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
