class_name BoardTwists
extends RefCounted

# ============================================================
# 猫咪合合乐 · 每日变异规则（M3-3.2 Daily Twist）
# 每天按日期确定性地选一条规则挂在当日所有对局上（入口明示，规则透明）。
# 变异以 modifier 叠加层作用于 BoardGame，不改基础配置。
# 「双子日」等新变异按此结构加池即可。
# ============================================================

const TWISTS := {
	"yarn_day": {
		"name": "毛线日",
		"icon": "🧶",
		"desc": "毛线格+2，解开毛线格兴奋值 20→30",
		"yarn_extra_tiles": 2,
		"yarn_excitement": 30,
	},
	"mischief_day": {
		"name": "捣蛋日",
		"icon": "😼",
		"desc": "捣乱+1次，但通关奖励二选一",
		"extra_mischief_click": 16,
		"reward_double_roll": true,
	},
	"generous_day": {
		"name": "慷慨日",
		"icon": "🎁",
		"desc": "初始主链物品+2，但三星线收紧（剩余≥5）",
		"initial_main_bonus": 2,
		"star3_threshold": 5,
	},
	"combo_day": {
		"name": "连击日",
		"icon": "⚡",
		"desc": "连击判定窗口 3秒→5秒",
		"combo_window": 5.0,
	},
}

# 参与每日轮换的变异池（顺序即轮换相位）
const DAILY_POOL := ["yarn_day", "mischief_day", "generous_day", "combo_day"]


static func get_today_twist_id() -> String:
	"""按日期确定性选取当日变异（同一天所有对局一致，跨天自动切换）"""
	var d := Time.get_date_dict_from_system()
	var day_key: int = d.year * 10000 + d.month * 100 + d.day
	return DAILY_POOL[day_key % DAILY_POOL.size()]


static func get_twist(twist_id: String) -> Dictionary:
	"""取变异配置；空 id 或未知 id 返回空字典（=无变异）"""
	return TWISTS.get(twist_id, {})


static func get_twist_banner(twist_id: String) -> String:
	"""入口/开局展示用的变异说明文案"""
	var t := get_twist(twist_id)
	if t.is_empty():
		return ""
	return "%s 今日变异「%s」：%s" % [t["icon"], t["name"], t["desc"]]
