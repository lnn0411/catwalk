class_name BoardOrders
extends RefCounted

const ItemChains := preload("res://scripts/board_game/ItemChains.gd")

# ============================================================
# 猫咪合合乐 · 猫咪委托（M3-3.3 订单局）
# 周末开放的替代玩法：通关条件从「主链⭐5」替换为组合订单。
# 订单模板用 main/sub 角色描述需求（每局主副链随机，UI 渲染实际链名）。
# 模板池按 ISO 周序号确定性轮换。
# ============================================================

# requirements: [{role: "main"/"sub", star, count}]
# click_limit: 可选，生成器点击数上限（超出未交付即失败）
const ORDERS := [
	{
		"id": "order_dual_delivery",
		"name": "双份委托",
		"desc": "凑齐 副链⭐3×2 + 主链⭐4×1",
		"requirements": [
			{"role": "sub", "star": 3, "count": 2},
			{"role": "main", "star": 4, "count": 1},
		],
	},
	{
		"id": "order_speed_rush",
		"name": "限时委托",
		"desc": "在16次生成内凑齐 主链⭐4×1",
		"requirements": [
			{"role": "main", "star": 4, "count": 1},
		],
		"click_limit": 16,
	},
	{
		"id": "order_feast",
		"name": "盛宴委托",
		"desc": "凑齐 主链⭐3×2 + 副链⭐3×1",
		"requirements": [
			{"role": "main", "star": 3, "count": 2},
			{"role": "sub", "star": 3, "count": 1},
		],
	},
]

# 完成委托的额外好感奖励（接 interaction 通道）
const ORDER_AFFECTION_BONUS := 5


static func is_available_today() -> bool:
	"""周末（周六/周日）开放。Godot weekday: 0=周日 … 6=周六"""
	var d := Time.get_date_dict_from_system()
	return int(d.weekday) == 0 or int(d.weekday) == 6


static func get_this_week_order() -> Dictionary:
	"""按 ISO 周序号确定性轮换本周委托模板"""
	var d := Time.get_date_dict_from_system()
	var unix := Time.get_unix_time_from_system()
	var week_index := int(unix / (7 * 24 * 3600))
	return ORDERS[week_index % ORDERS.size()]


static func get_order_by_id(order_id: String) -> Dictionary:
	for order in ORDERS:
		if String(order["id"]) == order_id:
			return order
	return {}


static func describe_requirements(order: Dictionary, main_chain: int, sub_chain: int) -> String:
	"""用本局实际链名渲染需求文案，如「零食链⭐3×2 + 穿戴链⭐4×1」"""
	var parts: Array = []
	for req in order.get("requirements", []):
		var chain: int = main_chain if String(req["role"]) == "main" else sub_chain
		parts.append("%s⭐%d×%d" % [ItemChains.get_chain_display_name(chain), int(req["star"]), int(req["count"])])
	var text := " + ".join(parts)
	var limit := int(order.get("click_limit", 0))
	if limit > 0:
		text += "（限%d次生成）" % limit
	return text
