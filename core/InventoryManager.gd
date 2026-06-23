# InventoryManager — 道具背包账本 (Autoload)
# 不要加 class_name：已注册为同名 autoload，class_name 会与单例命名冲突。
# 自带独立存档 user://inventory.cfg（ConfigFile），与 CurrencyManager 风格一致。
extends Node

const SAVE_PATH := "user://inventory.cfg"
const SECTION := "inventory"

# 物品类型
const ITEM_INGREDIENT_SHARD := "ingredient_shard"   # 食材碎片（3片合成1个snack）
const ITEM_DECORATION_SHARD := "decoration_shard"   # 装饰碎片（累计合成装饰品）
const ITEM_SNACK := "snack"                         # 成品零食（喂食互动+10%好感加成）
const ITEM_HIDDEN_ITEM := "hidden_item"             # 隐藏道具（稀有外观配件）
const ITEM_TREASURE_BOX := "treasure_box"           # 签到/成就宝箱
const ITEM_DECOR := "decor"                         # 随机装饰品

const VALID_TYPES := [
	ITEM_INGREDIENT_SHARD,
	ITEM_DECORATION_SHARD,
	ITEM_SNACK,
	ITEM_HIDDEN_ITEM,
	ITEM_TREASURE_BOX,
	ITEM_DECOR,
]

var _counts: Dictionary = {}

func _ready() -> void:
	for t in VALID_TYPES:
		_counts[t] = 0
	_load()

# ---- API ----

# 增加物品，返回新数量；无效类型或非正数量返回当前数量
func add_item(item_type: String, quantity: int) -> int:
	if not _counts.has(item_type):
		push_warning("InventoryManager.add_item: 未知物品类型 '%s'" % item_type)
		return 0
	if quantity <= 0:
		return _counts[item_type]
	_counts[item_type] = max(_counts[item_type] + quantity, 0)
	_after_change(item_type)
	return _counts[item_type]

func add_treasure_box(quantity: int, _source: String = "") -> int:
	return add_item(ITEM_TREASURE_BOX, quantity)

func add_random_decor(quantity: int, _source: String = "") -> int:
	return add_item(ITEM_DECOR, quantity)

func has_item(item_type: String, quantity: int) -> bool:
	return get_count(item_type) >= max(quantity, 0)

# 消耗物品；不足或无效则返回 false
func consume_item(item_type: String, quantity: int) -> bool:
	if not _counts.has(item_type):
		return false
	var need: int = max(quantity, 0)
	if _counts[item_type] < need:
		return false
	_counts[item_type] = max(_counts[item_type] - need, 0)
	_after_change(item_type)
	return true

func get_count(item_type: String) -> int:
	return int(_counts.get(item_type, 0))

# 合成：消耗 cost 个 from_type，产出 1 个 to_type
func synthesize(from_type: String, to_type: String, cost: int) -> bool:
	if not _counts.has(from_type) or not _counts.has(to_type):
		return false
	var need: int = max(cost, 0)
	if need <= 0:
		return false
	if _counts[from_type] < need:
		return false
	_counts[from_type] = max(_counts[from_type] - need, 0)
	_counts[to_type] = max(_counts[to_type] + 1, 0)
	_after_change(from_type)
	_after_change(to_type)
	return true

# ---- 存档（独立 ConfigFile）----

func _load() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return
	for t in VALID_TYPES:
		_counts[t] = max(int(cfg.get_value(SECTION, t, 0)), 0)

func _save() -> void:
	var cfg := ConfigFile.new()
	for t in VALID_TYPES:
		cfg.set_value(SECTION, t, _counts[t])
	if cfg.save(SAVE_PATH) != OK:
		push_error("[InventoryManager] Save failed: %s" % SAVE_PATH)

# ---- 内部 ----

func _after_change(item_type: String) -> void:
	_save()
	EventBus.inventory_changed.emit(item_type, _counts[item_type])
