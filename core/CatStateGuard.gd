extends Node

# A3 猫状态互斥矩阵的统一校验入口（launch_overhaul_master_plan §2.1）。
# 各系统禁止私判状态互斥——新增规则一律加在这里，UI 文案与拦截同源。
# 备注：
# - annoyed × 四键互动不在此拦截：GDD §5.5 明确经济奖励照常流转，annoyed
#   仅冻结情绪表现（矩阵表述随 P5 修订回写总案）；
# - sleeping 暂无权威查询源（CatSchedule 未提供 API），钩子恒 false，
#   作息系统补齐后在 _is_sleeping 接入。

enum Action { DISPATCH, SET_COMPANION, RELINQUISH, FEED_SNACK }


func can(action: Action, cat_id: String) -> Dictionary:
	match action:
		Action.DISPATCH:
			if _is_carried(cat_id):
				return _no("它正陪你走路呢，先换携带猫吧")
			if _is_sleeping(cat_id):
				return _no("它睡得正香，等它醒来吧")
			if _is_exploring(cat_id):
				return _no("它已经在城里逛啦")
		Action.SET_COMPANION:
			if _is_exploring(cat_id):
				return _no("它还在城里逛，回来才能陪你走路")
		Action.RELINQUISH:
			if _is_carried(cat_id):
				return _no("先换下携带猫，再考虑送养吧")
			if _is_exploring(cat_id):
				return _no("它还在外面探索，回来再说吧")
		Action.FEED_SNACK:
			if _is_exploring(cat_id):
				return _no("它不在花园里")
	return {"allowed": true, "reason": ""}


func is_allowed(action: Action, cat_id: String) -> bool:
	return bool(can(action, cat_id).get("allowed", false))


func _is_carried(cat_id: String) -> bool:
	return HatchEngine != null and HatchEngine.current_companion_cat_id == cat_id


func _is_exploring(cat_id: String) -> bool:
	return ExploreEngine != null and ExploreEngine.is_exploring(cat_id)


func _is_sleeping(_cat_id: String) -> bool:
	return false  # 作息查询钩子（CatSchedule 提供 API 后接入）


func _no(reason: String) -> Dictionary:
	return {"allowed": false, "reason": reason}
