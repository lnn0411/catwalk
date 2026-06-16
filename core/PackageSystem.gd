# PackageSystem — 猫包渐进式扩容管理 (Autoload)
# GDD v2.17 §2.2.1 四、· T3-4 §5.4
# 24→28→32→36 级联扩容，按累计步数或明信片数触发
extends Node

signal backpack_capacity_expanded(new_capacity: int)

const INITIAL_CAPACITY := 24
const MAX_CAPACITY := 36

# 扩容阶梯：{目标容量: {steps: 累计步数阈值, postcards: 明信片数阈值}}
const EXPAND_TIERS := {
	28: {"steps": 300000, "postcards": 5},
	32: {"steps": 500000, "postcards": 10},
	36: {"steps": 1000000, "postcards": 20},
}

var _capacity: int = INITIAL_CAPACITY
var _last_checked_capacity: int = INITIAL_CAPACITY

func _ready() -> void:
	_last_checked_capacity = _capacity

# 每帧或事件触发时调用，检查扩容条件
func check_expand(total_steps: int, postcard_count: int) -> int:
	var new_cap: int = _capacity
	for cap in [28, 32, 36]:
		var tier: Dictionary = EXPAND_TIERS[cap]
		if total_steps >= int(tier["steps"]) or postcard_count >= int(tier["postcards"]):
			new_cap = max(new_cap, cap)
	if new_cap > _capacity:
		var old: int = _capacity
		_capacity = new_cap
		# 同步到 HatchEngine（如果存在）
		if HatchEngine:
			HatchEngine.backpack_max_capacity = _capacity
		if new_cap > _last_checked_capacity:
			backpack_capacity_expanded.emit(new_cap)
		_last_checked_capacity = new_cap
	return _capacity

func get_capacity() -> int:
	return _capacity

# 存档读写
func apply_save(data: Dictionary) -> void:
	_capacity = clamp(int(data.get("backpack_max_capacity", INITIAL_CAPACITY)), INITIAL_CAPACITY, MAX_CAPACITY)
	_last_checked_capacity = _capacity

func get_save_data() -> Dictionary:
	return {
		"backpack_max_capacity": _capacity,
	}
