# CurrencyManager — 货币账本 (Autoload)
# 不要加 class_name：已注册为同名 autoload，class_name 会与单例命名冲突。
# 持久化交由 SaveManager（ConfigFile section "currency"）通过 apply_save/get_save_data 驱动。
extends Node

const SECTION := "currency"

var gold_coins: int = 0
var diamonds: int = 0
var flower_petals: int = 0
var love_petals: int = 0

func _ready() -> void:
	pass

# ---- 金币 ----
# source: 扩展预留，用于标注来源（埋点/审计），当前未消费。
func add_gold(amount: int, source: String = "") -> void:
	if amount < 0:
		push_warning("CurrencyManager.add_gold: 负数 amount=%d，已拒绝" % amount)
		return
	gold_coins = max(gold_coins + amount, 0)
	_after_change()

func spend_gold(amount: int) -> bool:
	var cost: int = max(amount, 0)
	if gold_coins < cost:
		return false
	gold_coins = max(gold_coins - cost, 0)
	_after_change()
	return true

func get_gold() -> int:
	return gold_coins

# ---- 钻石 ----
# source: 扩展预留，用于标注来源（埋点/审计），当前未消费。
func add_diamonds(amount: int, source: String = "") -> void:
	if amount < 0:
		push_warning("CurrencyManager.add_diamonds: 负数 amount=%d，已拒绝" % amount)
		return
	diamonds = max(diamonds + amount, 0)
	_after_change()

func spend_diamonds(amount: int) -> bool:
	var cost: int = max(amount, 0)
	if diamonds < cost:
		return false
	diamonds = max(diamonds - cost, 0)
	_after_change()
	return true

func get_diamonds() -> int:
	return diamonds

# ---- 花瓣 ----
# source: 扩展预留，用于标注来源（埋点/审计），当前未消费。
func add_petals(amount: int, source: String = "") -> void:
	if amount < 0:
		push_warning("CurrencyManager.add_petals: 负数 amount=%d，已拒绝" % amount)
		return
	flower_petals = max(flower_petals + amount, 0)
	_after_change()

func spend_petals(amount: int) -> bool:
	var cost: int = max(amount, 0)
	if flower_petals < cost:
		return false
	flower_petals = max(flower_petals - cost, 0)
	_after_change()
	return true

func get_petals() -> int:
	return flower_petals

# ---- 心动花瓣 ----
# source: 扩展预留，用于标注来源（埋点/审计），当前未消费。
func add_love_petals(amount: int, source: String = "") -> void:
	if amount < 0:
		push_warning("CurrencyManager.add_love_petals: 负数 amount=%d，已拒绝" % amount)
		return
	love_petals = max(love_petals + amount, 0)
	_after_change()

func spend_love_petals(amount: int) -> bool:
	var cost: int = max(amount, 0)
	if love_petals < cost:
		return false
	love_petals = max(love_petals - cost, 0)
	_after_change()
	return true

func get_love_petals() -> int:
	return love_petals

# ---- 组合校验 ----
func can_afford(gold_cost: int, diamond_cost: int, petal_cost: int, love_petal_cost: int = 0) -> bool:
	return gold_coins >= max(gold_cost, 0) \
		and diamonds >= max(diamond_cost, 0) \
		and flower_petals >= max(petal_cost, 0) \
		and love_petals >= max(love_petal_cost, 0)

# ---- 存档（对齐 SaveManager 的 ConfigFile section "currency"）----
func apply_save(data: Dictionary) -> void:
	gold_coins = max(int(data.get("gold_coins", 0)), 0)
	diamonds = max(int(data.get("diamonds", 0)), 0)
	flower_petals = max(int(data.get("flower_petals", 0)), 0)
	love_petals = max(int(data.get("love_petals", 0)), 0)
	_after_change()

func get_save_data() -> Dictionary:
	return {
		"gold_coins": gold_coins,
		"diamonds": diamonds,
		"flower_petals": flower_petals,
		"love_petals": love_petals,
	}

# ---- 内部 ----
func _after_change() -> void:
	EventBus.emit_currency_changed(gold_coins, diamonds, flower_petals, love_petals)
