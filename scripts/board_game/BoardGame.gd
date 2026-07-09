class_name BoardGame
extends Node

const BoardGameData := preload("res://scripts/board_game/BoardGameData.gd")
const BoardItem := preload("res://scripts/board_game/BoardItem.gd")

# ============================================================
# 猫咪合合乐 · 棋盘核心逻辑（纯逻辑，不含 UI）
# 5×5 棋盘，中心格为生成器；同链同星拖拽合并升级
# 通关：合出主链⭐5；死局：无可合并且（生成器耗尽或棋盘满）
# ============================================================

# 信号
signal item_merged(pos: Vector2i, new_item: BoardItem)
signal item_moved(from_pos: Vector2i, to_pos: Vector2i)
signal generator_clicked(pos: Vector2i, item: BoardItem)
signal generator_used(count: int)
signal game_won
signal game_won_with_stars(rating: int)  # D4
signal game_lost
signal sub_chain_completed(item: BoardItem)
signal undo_performed(action: Dictionary)
signal board_updated(grid_data: Dictionary)
signal consolation_prize(item_name: String, count: int, message: String)  # 放弃本局的安慰奖
signal mischief_warning(pos: Vector2i)  # 捣乱预警：猫出现在棋盘边缘
signal mischief_triggered(pos: Vector2i, item: BoardItem)  # 捣乱执行：猫拍飞物品
signal mischief_cat_apology(cat_name: String)  # 失败后猫来道歉
signal main_chain_star_changed(star: int)  # 主链星级提升时触发（⭐2/⭐3/⭐4/⭐5）
# D10: 兴奋值 / 连击 / 三连合 / 狂欢 / 毛线格
signal excitement_changed(value: int, max_value: int)  # 兴奋值变化
signal combo_triggered(count: int)  # 连击触发（count=连击数）
signal triple_merged(pos: Vector2i, new_item: BoardItem)  # 三连合触发
signal frenzy_ready  # 兴奋值满100，可触发狂欢
signal frenzy_activated  # 狂欢启动
signal frenzy_ended  # 狂欢结束
signal yarn_untangled(pos: Vector2i)  # 毛线格被解开
signal highest_star_changed(star: int)  # 最高星级变化

# 撤销：免费次数用尽后每次撤销的钻石成本
const UNDO_DIAMOND_COST := 10

# 主动放弃本局的安慰奖（与 LevelStateManager.CONSOLATION_PRIZE 保持一致）
const CONSOLATION_ITEM := "小鱼干"
const CONSOLATION_COUNT := 1
const CONSOLATION_TEXT := "猫咪们说：没关系，下次再来喵"

# 棋盘状态
var grid: Dictionary = {}  # key: Vector2i, value: BoardItem
var generator_remaining: int = BoardGameData.GENERATOR_TOTAL
var current_main_chain: int = BoardGameData.ItemChain.WEAR
var current_sub_chain: int = BoardGameData.ItemChain.SNACK
var game_state: int = BoardGameData.GameState.PLAYING
var undo_stack: Array = []
var undo_free_count: int = BoardGameData.UNDO_FREE_COUNT
var sub_chain_exit_used: bool = false  # 副链出口是否已用（副链⭐3只触发一次）
var ad_rescue_used: bool = false
var is_give_up: bool = false
var board_level: int = BoardGameData.BoardLevel.LV1
var star_rating: int = 0  # D4
var generator_click_count: int = 0  # 本局生成器已点击次数
var swiped_items: Array = []  # 被猫拍飞的物品 [{pos, item}]
var ad_rescue_restore_used: bool = false  # 本局是否已用救局恢复
var cat_name: String = ""  # 携带猫名字
var mischief_pending_trigger: int = -1  # 下一个触发捣乱的点击序号（-1=本局无）
var mischief_triggered_this_game: Array[int] = []  # 已触发的捣乱序号列表
var _consolation_emitted: bool = false
var _main_chain_max_star: int = 0  # 本局主链已达成的最高星级
# D10: 兴奋值 / 连击 / 毛线格 / 狂欢
var excitement: int = 0  # 当前兴奋值 0-100
var _last_merge_time: float = 0.0  # 上次合并时间（用于连击判定）
var _combo_active: bool = false  # 是否在连击窗口内
var _combo_count: int = 0  # 当前连击数
var special_tiles: Dictionary = {}  # Vector2i→int(SpecialTile)，毛线格位置
var frenzy_triggers_used: int = 0  # 本局已用狂欢次数
var frenzy_active: bool = false  # 是否狂欢进行中
var highest_star_achieved: int = 0  # 本局已合成的最高星级（初始0=未合成，第一次合并后点亮⭐1）
var frenzy_timer: float = 0.0  # 狂欢计时器


func start_new_game(level: int = BoardGameData.BoardLevel.LV1, cat: String = "你的猫") -> void:
	"""初始化新一局：随机选链→初始掉落→生成器满"""
	randomize()
	board_level = level
	cat_name = cat
	var config := BoardGameData.get_level_config(board_level)
	star_rating = 0  # D4
	# 随机选主链和副链（不同）
	var chains: Array = BoardGameData.all_chains()
	chains.shuffle()
	current_main_chain = chains[0]
	current_sub_chain = chains[1]
	generator_remaining = BoardGameData.GENERATOR_TOTAL
	generator_click_count = 0
	undo_stack.clear()
	undo_free_count = BoardGameData.UNDO_FREE_COUNT
	sub_chain_exit_used = false
	ad_rescue_used = false
	ad_rescue_restore_used = false
	swiped_items.clear()
	is_give_up = false
	mischief_triggered_this_game.clear()
	_consolation_emitted = false
	_main_chain_max_star = 0
	# D10: 兴奋值/连击/毛线格/狂欢 初始化
	excitement = int(config.get("excitement_initial", 0))
	_last_merge_time = 0.0
	_combo_active = false
	_combo_count = 0
	special_tiles.clear()
	frenzy_triggers_used = 0
	frenzy_active = false
	highest_star_achieved = 0
	frenzy_timer = 0.0
	game_state = BoardGameData.GameState.PLAYING
	_advance_mischief_trigger()
	# 初始掉落
	grid.clear()
	var main_count := randi_range(int(config["initial_main_min"]), int(config["initial_main_max"]))
	var sub_count := randi_range(int(config["initial_sub_min"]), int(config["initial_sub_max"]))
	_place_initial_items(main_count, sub_count)
	_place_yarn_tiles()  # D10: 放置毛线格（避开已有物品与生成器）
	board_updated.emit(grid.duplicate(true))
	highest_star_changed.emit(0)  # D10: 重置目标横幅（全部未点亮）
	excitement_changed.emit(excitement, BoardGameData.EXCITEMENT_MAX)  # D10


func can_merge(item_a: BoardItem, item_b: BoardItem) -> bool:
	"""判断两个物品是否可以合并：同链+同星级，且未达⭐5"""
	if item_a == null or item_b == null:
		return false
	if item_a.is_max_star():
		return false
	return item_a.chain == item_b.chain and item_a.star == item_b.star


func merge_items(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	"""合并两个物品：pos_a 拖到 pos_b，pos_b 处生成高一级物品"""
	if game_state != BoardGameData.GameState.PLAYING:
		return false
	if pos_a == pos_b:
		return false
	if not (grid.has(pos_a) and grid.has(pos_b)):
		return false
	var item_a: BoardItem = grid[pos_a]
	var item_b: BoardItem = grid[pos_b]
	if not can_merge(item_a, item_b):
		return false
	# 保存撤销信息（快照，避免后续引用被改）
	undo_stack.append({
		"type": "merge",
		"from_a": pos_a, "item_a": item_a.duplicate_item(),
		"from_b": pos_b, "item_b": item_b.duplicate_item(),
	})
	# 合并：移除两个，在目标位置生成高级物品
	grid.erase(pos_a)
	grid.erase(pos_b)
	var new_star: int = min(item_a.star + 1, BoardGameData.StarLevel.FIVE)
	var new_item := BoardItem.create(item_a.chain, new_star, pos_b)
	grid[pos_b] = new_item
	item_merged.emit(pos_b, new_item)
	board_updated.emit(grid.duplicate(true))
	# 副链⭐3：通知 UI 可走副链出口；奖励由 sub_chain_exit 负责结算
	if new_item.chain == current_sub_chain and new_item.star == BoardGameData.StarLevel.THREE:
		sub_chain_completed.emit(new_item)
	# 主链星级提升检测：逐级触发 reaction（⭐2/⭐3/⭐4/⭐5）
	if new_item.chain == current_main_chain and new_item.star > _main_chain_max_star:
		_main_chain_max_star = new_item.star
		main_chain_star_changed.emit(new_item.star)

	# ===== D10: 兴奋值 / 连击 / 三连合 / 毛线格 / 狂欢 =====
	# 兴奋值增长（按合并前星级计价）
	var merge_star: int = item_a.star
	var excite_gain: int = BoardGameData.EXCITEMENT_MERGE_VALUES.get(merge_star, 0)
	excitement = mini(excitement + excite_gain, BoardGameData.EXCITEMENT_MAX)
	excitement_changed.emit(excitement, BoardGameData.EXCITEMENT_MAX)

	# 连击检测
	var now := Time.get_ticks_msec() / 1000.0
	if _last_merge_time > 0 and (now - _last_merge_time) <= BoardGameData.COMBO_WINDOW_SECONDS:
		_combo_active = true
		excitement = mini(excitement + BoardGameData.EXCITEMENT_COMBO_BONUS, BoardGameData.EXCITEMENT_MAX)
		excitement_changed.emit(excitement, BoardGameData.EXCITEMENT_MAX)
		combo_triggered.emit(_combo_count)
		_combo_count += 1
	else:
		_combo_active = false
		_combo_count = 1
	_last_merge_time = now

	# 三连合检测（在合并后位置检查4邻域是否有同链同星）
	var triple_list: Array = []
	for neighbor_pos in _get_neighbors(pos_b):
		if neighbor_pos in grid:
			var neighbor: BoardItem = grid[neighbor_pos]
			if neighbor.chain == new_item.chain and neighbor.star == new_item.star:
				triple_list.append(neighbor_pos)
	if triple_list.size() >= 1:  # 自身(pos_a已消耗) + new_item + 1邻居 = 三连合
		var removed_pos: Vector2i = triple_list[0]
		grid.erase(removed_pos)
		# 升级合并结果
		var triple_star: int = mini(new_item.star + 1, BoardGameData.StarLevel.FIVE)
		var triple_item := BoardItem.create(new_item.chain, triple_star, pos_b)
		grid[pos_b] = triple_item
		# 返还⭐1×1
		var refund_pos := _find_refund_cell(pos_b)
		if refund_pos != Vector2i(-1, -1):
			var refund_item := BoardItem.create(new_item.chain, BoardGameData.StarLevel.ONE, refund_pos)
			grid[refund_pos] = refund_item
		# 兴奋值奖励
		excitement = mini(excitement + BoardGameData.EXCITEMENT_TRIPLE_MERGE_BONUS, BoardGameData.EXCITEMENT_MAX)
		excitement_changed.emit(excitement, BoardGameData.EXCITEMENT_MAX)
		triple_merged.emit(pos_b, triple_item)
		# 三连合最高星级检查（用升级后星级）
		if triple_item.star > highest_star_achieved:
			highest_star_achieved = triple_item.star
			highest_star_changed.emit(highest_star_achieved)

	# 普通合并最高星级检查
	if new_item.star > highest_star_achieved:
		highest_star_achieved = new_item.star
		highest_star_changed.emit(highest_star_achieved)

	# 解开相邻毛线格
	for npos in _get_neighbors(pos_b):
		if special_tiles.get(npos) == BoardGameData.SpecialTile.YARN:
			special_tiles.erase(npos)
			excitement = mini(excitement + BoardGameData.EXCITEMENT_YARN_BONUS, BoardGameData.EXCITEMENT_MAX)
			excitement_changed.emit(excitement, BoardGameData.EXCITEMENT_MAX)
			yarn_untangled.emit(npos)

	# 兴奋值满 → 可触发狂欢
	if excitement >= BoardGameData.EXCITEMENT_MAX:
		frenzy_ready.emit()
	# ===== D10 end =====

	# 检查通关：主链⭐5出现
	if new_item.chain == current_main_chain and new_item.star == BoardGameData.StarLevel.FIVE:
		game_state = BoardGameData.GameState.WON
		star_rating = calc_star_rating()  # D4
		game_won_with_stars.emit(star_rating)  # D4
		game_won.emit()
		return true
	_check_deadlock()
	return true


func move_item(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	"""移动物品到空格"""
	if game_state != BoardGameData.GameState.PLAYING:
		return false
	if not BoardGameData.is_valid_pos(to_pos) or to_pos == BoardGameData.GENERATOR_POS:
		return false
	if not grid.has(from_pos) or grid.has(to_pos):
		return false
	# D10: 禁止移动到/离开毛线格
	if to_pos in special_tiles or from_pos in special_tiles:
		return false
	var item: BoardItem = grid[from_pos]
	grid.erase(from_pos)
	item.grid_pos = to_pos
	grid[to_pos] = item
	undo_stack.append({"type": "move", "from": from_pos, "to": to_pos})
	item_moved.emit(from_pos, to_pos)
	board_updated.emit(grid.duplicate(true))
	return true


func click_generator() -> bool:
	"""点击生成器，在最近空格产出物品"""
	if game_state != BoardGameData.GameState.PLAYING:
		return false
	if generator_remaining <= 0:
		return false
	var empty_cells := _get_empty_cells()
	if empty_cells.is_empty():
		return false  # 棋盘满了
	var index: int = clampi(BoardGameData.GENERATOR_TOTAL - generator_remaining, 0, BoardGameData.DROP_SEQUENCE.size() - 1)
	var is_main: bool = BoardGameData.DROP_SEQUENCE[index]
	var target_pos := _nearest_empty(empty_cells, BoardGameData.GENERATOR_POS)
	var chain := current_main_chain if is_main else current_sub_chain
	var new_item := BoardItem.create(chain, BoardGameData.StarLevel.ONE, target_pos)
	grid[target_pos] = new_item
	# D10: 狂欢期间不消耗生成器次数（免费生成）
	if not frenzy_active:
		generator_remaining -= 1
	generator_click_count += 1
	undo_stack.append({"type": "generator", "pos": target_pos, "item": new_item.duplicate_item()})
	generator_clicked.emit(target_pos, new_item)
	generator_used.emit(generator_remaining)
	board_updated.emit(grid.duplicate(true))
	_check_mischief()
	_check_deadlock()
	return true


func can_undo() -> bool:
	return not undo_stack.is_empty() and game_state == BoardGameData.GameState.PLAYING


# D4: Calculate star rating based on remaining generator uses when game is won.
func calc_star_rating() -> int:
	if generator_remaining >= 4:
		return 3
	elif generator_remaining >= 2:
		return 2
	return 1


func undo() -> bool:
	"""撤销上一步操作。前 UNDO_FREE_COUNT 次免费，之后由 UI 层负责扣钻石后再调用"""
	if not can_undo():
		return false
	if undo_free_count > 0:
		undo_free_count -= 1
	var action: Dictionary = undo_stack.pop_back()
	_apply_undo(action)
	undo_performed.emit(action)
	board_updated.emit(grid.duplicate(true))
	return true


func get_undo_cost() -> Dictionary:
	"""下一次撤销的成本：免费额度内为 0 钻石，用尽后每次 UNDO_DIAMOND_COST 钻石。"""
	var free_remaining: int = max(undo_free_count, 0)
	return {
		"free_remaining": free_remaining,
		"diamond_cost": 0 if free_remaining > 0 else UNDO_DIAMOND_COST,
	}


func give_up() -> void:
	"""主动放弃本局：置为失败并发放安慰奖（小鱼干x1）"""
	if game_state != BoardGameData.GameState.PLAYING:
		return
	is_give_up = true
	game_state = BoardGameData.GameState.LOST
	_emit_consolation_prize()


func ad_rescue_restore() -> bool:
	"""看广告救局：恢复本局全部被猫拍飞的物品，每局限1次"""
	if game_state != BoardGameData.GameState.LOST or ad_rescue_restore_used or is_give_up:
		return false
	if swiped_items.is_empty():
		return false
	ad_rescue_restore_used = true
	ad_rescue_used = true
	for entry in swiped_items:
		var pos: Vector2i = entry["pos"]
		var item: BoardItem = entry["item"]
		if not grid.has(pos):
			item.grid_pos = pos
			grid[pos] = item
	swiped_items.clear()
	game_state = BoardGameData.GameState.PLAYING
	board_updated.emit(grid.duplicate(true))
	_check_deadlock()
	return true


func ad_rescue(extra_uses: int = 5) -> bool:
	"""Deprecated：兼容旧救局入口，改为恢复被猫拍飞的物品。"""
	return ad_rescue_restore()


func sub_chain_exit(pos: Vector2i) -> bool:
	"""副链出口：移除指定位置的副链⭐3；每局首次额外返还2次生成器。"""
	if not grid.has(pos):
		return false
	var item: BoardItem = grid[pos]
	if item == null or item.chain != current_sub_chain or item.star != BoardGameData.StarLevel.THREE:
		return false
	grid.erase(pos)
	if not sub_chain_exit_used:
		sub_chain_exit_used = true
		generator_remaining += 2
		generator_used.emit(generator_remaining)
	board_updated.emit(grid.duplicate(true))
	_check_deadlock()
	return true


func get_item(pos: Vector2i) -> BoardItem:
	return grid.get(pos)


func is_generator_pos(pos: Vector2i) -> bool:
	return pos == BoardGameData.GENERATOR_POS


func _check_mischief() -> void:
	# 如果 mischief_pending_trigger == -1，说明本局无捣乱或已全部触发
	if mischief_pending_trigger < 0:
		return
	# 如果当前点击未达到触发点，不触发
	if generator_click_count < mischief_pending_trigger:
		return
	_trigger_mischief()


func _trigger_mischief() -> void:
	mischief_triggered_this_game.append(mischief_pending_trigger)
	var targets: Array = []
	for pos in grid:
		var item: BoardItem = grid[pos]
		if item.star <= BoardGameData.StarLevel.TWO:
			var weight := 2 if item.star == BoardGameData.StarLevel.TWO else 1
			for _i in range(weight):
				targets.append({"pos": pos, "item": item})
	if targets.is_empty():
		_advance_mischief_trigger()
		return
	targets.shuffle()
	var target: Dictionary = targets[0]
	var pos: Vector2i = target["pos"]
	var item: BoardItem = target["item"]
	mischief_warning.emit(pos)
	swiped_items.append({"pos": pos, "item": item.duplicate_item()})
	grid.erase(pos)
	mischief_triggered.emit(pos, item)
	board_updated.emit(grid.duplicate(true))
	_advance_mischief_trigger()
	_check_deadlock()


func _advance_mischief_trigger() -> void:
	var config := BoardGameData.get_level_config(board_level)
	var triggers: Array = config["mischief_triggers"]
	mischief_pending_trigger = -1
	for t in triggers:
		var trigger := int(t)
		if trigger > generator_click_count and not mischief_triggered_this_game.has(trigger):
			mischief_pending_trigger = trigger
			break


func serialize_state() -> Dictionary:
	"""序列化当前棋盘对局状态，供外层存档系统保存。"""
	var grid_data: Dictionary = {}
	for pos in grid:
		grid_data[_pos_to_key(pos)] = _serialize_item(grid[pos])
	var undo_data: Array = []
	for action in undo_stack:
		undo_data.append(_serialize_undo_action(action))
	return {
		"grid": grid_data,
		"generator_remaining": generator_remaining,
		"current_main_chain": current_main_chain,
		"current_sub_chain": current_sub_chain,
		"game_state": game_state,
		"undo_stack": undo_data,
		"undo_free_count": undo_free_count,
		"sub_chain_exit_used": sub_chain_exit_used,
		"ad_rescue_used": ad_rescue_used,
		"is_give_up": is_give_up,
		"board_level": board_level,
		"star_rating": star_rating,  # D4
		"generator_click_count": generator_click_count,
		"swiped_items": _serialize_swiped_items(),
		"ad_rescue_restore_used": ad_rescue_restore_used,
		"cat_name": cat_name,
		"mischief_pending_trigger": mischief_pending_trigger,
		"mischief_triggered_this_game": mischief_triggered_this_game.duplicate(),
		"consolation_emitted": _consolation_emitted,
		"main_chain_max_star": _main_chain_max_star,
		"excitement": excitement,
		# _last_merge_time 不持久化——单调时钟跨进程必失灵（参见 P1-1）
		"_combo_active": _combo_active,
		"special_tiles": _serialize_special_tiles(),
		"frenzy_triggers_used": frenzy_triggers_used,
		"frenzy_active": frenzy_active,
		"frenzy_timer": frenzy_timer,
		"highest_star_achieved": highest_star_achieved,
	}


func deserialize_state(data: Dictionary) -> void:
	"""恢复 serialize_state 产生的状态。缺失字段按当前默认值兜底。"""
	grid.clear()
	var grid_data: Dictionary = data.get("grid", {})
	for key in grid_data:
		var pos := _key_to_pos(str(key))
		var item := _deserialize_item(grid_data[key], pos)
		if item != null:
			grid[pos] = item
	generator_remaining = int(data.get("generator_remaining", generator_remaining))
	current_main_chain = int(data.get("current_main_chain", current_main_chain))
	current_sub_chain = int(data.get("current_sub_chain", current_sub_chain))
	game_state = int(data.get("game_state", game_state))
	undo_free_count = int(data.get("undo_free_count", undo_free_count))
	sub_chain_exit_used = bool(data.get("sub_chain_exit_used", sub_chain_exit_used))
	ad_rescue_used = bool(data.get("ad_rescue_used", ad_rescue_used))
	is_give_up = bool(data.get("is_give_up", is_give_up))
	board_level = int(data.get("board_level", board_level))
	star_rating = int(data.get("star_rating", star_rating))  # D4
	generator_click_count = int(data.get("generator_click_count", generator_click_count))
	ad_rescue_restore_used = bool(data.get("ad_rescue_restore_used", data.get("ad_rescue_used", ad_rescue_restore_used)))
	cat_name = String(data.get("cat_name", cat_name))
	mischief_pending_trigger = int(data.get("mischief_pending_trigger", mischief_pending_trigger))
	_main_chain_max_star = int(data.get("main_chain_max_star", _main_chain_max_star))
	mischief_triggered_this_game.clear()
	for trigger in data.get("mischief_triggered_this_game", []):
		mischief_triggered_this_game.append(int(trigger))
	swiped_items = _deserialize_swiped_items(data.get("swiped_items", []))
	_consolation_emitted = bool(data.get("consolation_emitted", _consolation_emitted))
	# D10: 兴奋值 / 连击 / 毛线格 / 狂欢
	excitement = int(data.get("excitement", 0))
	_last_merge_time = 0.0  # 单调时钟不可跨进程持久化，重置防假连击
	_combo_active = bool(data.get("_combo_active", false))
	special_tiles = _deserialize_special_tiles(data.get("special_tiles", {}))
	frenzy_triggers_used = int(data.get("frenzy_triggers_used", 0))
	frenzy_active = bool(data.get("frenzy_active", false))
	frenzy_timer = float(data.get("frenzy_timer", 0.0))
	highest_star_achieved = int(data.get("highest_star_achieved", 1))
	undo_stack.clear()
	for raw_action in data.get("undo_stack", []):
		var action := _deserialize_undo_action(raw_action)
		if not action.is_empty():
			undo_stack.append(action)
	generator_used.emit(generator_remaining)
	board_updated.emit(grid.duplicate(true))


# ---------------- 内部方法 ----------------

func _pos_to_key(pos: Vector2i) -> String:
	return "%d_%d" % [pos.x, pos.y]


func _key_to_pos(key: String) -> Vector2i:
	var parts := key.split("_")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _serialize_pos(pos: Vector2i) -> Dictionary:
	return {"x": pos.x, "y": pos.y}


func _deserialize_pos(data: Variant) -> Vector2i:
	if data is Vector2i:
		return data
	if data is Dictionary:
		return Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	if data is String:
		return _key_to_pos(data)
	return Vector2i.ZERO


func _serialize_item(item: BoardItem) -> Dictionary:
	if item == null:
		return {}
	return {
		"chain": item.chain,
		"star": item.star,
		"id": item.id,
		"grid_pos": _serialize_pos(item.grid_pos),
	}


func _deserialize_item(data: Variant, fallback_pos: Vector2i) -> BoardItem:
	if not (data is Dictionary):
		return null
	var pos := _deserialize_pos(data.get("grid_pos", fallback_pos))
	return BoardItem.create(int(data.get("chain", current_main_chain)), int(data.get("star", BoardGameData.StarLevel.ONE)), pos)


func _serialize_swiped_items() -> Array:
	var data: Array = []
	for entry in swiped_items:
		data.append({
			"pos": _serialize_pos(entry["pos"]),
			"item": _serialize_item(entry["item"]),
		})
	return data


func _deserialize_swiped_items(data: Variant) -> Array:
	var items: Array = []
	if not (data is Array):
		return items
	for raw_entry in data:
		if not (raw_entry is Dictionary):
			continue
		var pos := _deserialize_pos(raw_entry.get("pos", Vector2i.ZERO))
		var item := _deserialize_item(raw_entry.get("item", {}), pos)
		if item != null:
			item.grid_pos = pos
			items.append({"pos": pos, "item": item})
	return items


func _serialize_undo_action(action: Dictionary) -> Dictionary:
	var out := {"type": action.get("type", "")}
	match String(out.type):
		"merge":
			out["from_a"] = _serialize_pos(action.from_a)
			out["item_a"] = _serialize_item(action.item_a)
			out["from_b"] = _serialize_pos(action.from_b)
			out["item_b"] = _serialize_item(action.item_b)
		"move":
			out["from"] = _serialize_pos(action.from)
			out["to"] = _serialize_pos(action.to)
		"generator":
			out["pos"] = _serialize_pos(action.pos)
			out["item"] = _serialize_item(action.item)
	return out


func _deserialize_undo_action(data: Variant) -> Dictionary:
	if not (data is Dictionary):
		return {}
	var action := {"type": String(data.get("type", ""))}
	match action.type:
		"merge":
			var from_a := _deserialize_pos(data.get("from_a", Vector2i.ZERO))
			var from_b := _deserialize_pos(data.get("from_b", Vector2i.ZERO))
			action["from_a"] = from_a
			action["item_a"] = _deserialize_item(data.get("item_a", {}), from_a)
			action["from_b"] = from_b
			action["item_b"] = _deserialize_item(data.get("item_b", {}), from_b)
		"move":
			action["from"] = _deserialize_pos(data.get("from", Vector2i.ZERO))
			action["to"] = _deserialize_pos(data.get("to", Vector2i.ZERO))
		"generator":
			var pos := _deserialize_pos(data.get("pos", Vector2i.ZERO))
			action["pos"] = pos
			action["item"] = _deserialize_item(data.get("item", {}), pos)
		_:
			return {}
	return action

func _apply_undo(action: Dictionary) -> void:
	"""执行具体的撤销逻辑"""
	match action.type:
		"merge":
			# 移除合并产物，还原两个原物品
			grid.erase(action.from_b)
			var item_a: BoardItem = action.item_a.duplicate_item()
			item_a.grid_pos = action.from_a
			var item_b: BoardItem = action.item_b.duplicate_item()
			item_b.grid_pos = action.from_b
			grid[action.from_a] = item_a
			grid[action.from_b] = item_b
			# 撤销的是通关/副链出口合成时，回退相应状态
			if item_a.chain == current_sub_chain and action.item_a.star == BoardGameData.StarLevel.FOUR:
				pass  # 副链出口奖励不回收（一次性）
		"move":
			var item: BoardItem = grid[action.to]
			grid.erase(action.to)
			item.grid_pos = action.from
			grid[action.from] = item
		"generator":
			grid.erase(action.pos)
			generator_remaining += 1
			generator_used.emit(generator_remaining)


func _place_initial_items(main_count: int, sub_count: int) -> void:
	"""初始掉落：随机空格放置1星物品（避开生成器格）"""
	var cells: Array = []
	for pos in BoardGameData.all_cells():
		if pos != BoardGameData.GENERATOR_POS:
			cells.append(pos)
	cells.shuffle()
	var idx := 0
	for i in range(main_count):
		if idx >= cells.size():
			return
		grid[cells[idx]] = BoardItem.create(current_main_chain, BoardGameData.StarLevel.ONE, cells[idx])
		idx += 1
	for i in range(sub_count):
		if idx >= cells.size():
			return
		grid[cells[idx]] = BoardItem.create(current_sub_chain, BoardGameData.StarLevel.ONE, cells[idx])
		idx += 1


func _get_empty_cells() -> Array:
	var empty: Array = []
	for pos in BoardGameData.all_cells():
		if pos == BoardGameData.GENERATOR_POS:
			continue
		if not grid.has(pos):
			empty.append(pos)
	return empty


func _nearest_empty(empty_cells: Array, origin: Vector2i) -> Vector2i:
	"""曼哈顿距离最近的空格；距离相同时按 y、x 排序保证确定性"""
	var best: Vector2i = empty_cells[0]
	var best_dist := _manhattan(best, origin)
	for pos in empty_cells:
		var d := _manhattan(pos, origin)
		if d < best_dist or (d == best_dist and (pos.y < best.y or (pos.y == best.y and pos.x < best.x))):
			best = pos
			best_dist = d
	return best


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _check_deadlock() -> void:
	"""死局判定：无可合并物品，且（生成器耗尽 或 棋盘已满无法再产出）"""
	if game_state != BoardGameData.GameState.PLAYING:
		return
	if _has_mergeable():
		return  # 还有可合并项
	var board_full := _get_empty_cells().is_empty()
	if generator_remaining > 0 and not board_full:
		return  # 生成器还能产出新物品
	game_state = BoardGameData.GameState.LOST
	if not is_give_up:
		mischief_cat_apology.emit(cat_name)
	_emit_consolation_prize()
	game_lost.emit()


func _has_mergeable() -> bool:
	"""检查是否存在任意两个同链同星（<⭐5）的物品——拖拽可跨格，无需相邻"""
	var count_by_id: Dictionary = {}
	for pos in grid:
		# D10: 毛线格不参与合并判定
		if pos in special_tiles and special_tiles[pos] == BoardGameData.SpecialTile.YARN:
			continue
		var item: BoardItem = grid[pos]
		if item.is_max_star():
			continue
		count_by_id[item.id] = count_by_id.get(item.id, 0) + 1
		if count_by_id[item.id] >= 2:
			return true
	return false


func _emit_consolation_prize() -> void:
	if _consolation_emitted:
		return
	_consolation_emitted = true
	consolation_prize.emit(CONSOLATION_ITEM, CONSOLATION_COUNT, CONSOLATION_TEXT)


# ---------------- D10: 兴奋值 / 连击 / 三连合 / 狂欢 / 毛线格 ----------------

func _place_yarn_tiles() -> void:
	"""按关卡配置放置毛线格（避开生成器与初始掉落物品位置）"""
	var config := BoardGameData.get_level_config(board_level)
	var count: int = int(config.get("yarn_tile_count", 0))
	if count <= 0:
		return
	var candidates: Array = []
	for pos in BoardGameData.all_cells():
		if pos != BoardGameData.GENERATOR_POS and not grid.has(pos):
			candidates.append(pos)
	candidates.shuffle()
	for i in range(min(count, candidates.size())):
		var pos: Vector2i = candidates[i]
		special_tiles[pos] = BoardGameData.SpecialTile.YARN


func _get_neighbors(pos: Vector2i) -> Array:
	"""返回上下左右4邻域中合法的格子"""
	var neighbors: Array = []
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var npos: Vector2i = pos + offset
		if BoardGameData.is_valid_pos(npos):
			neighbors.append(npos)
	return neighbors


func _find_refund_cell(center: Vector2i) -> Vector2i:
	"""三连合返还⭐1时寻找离 center 最近的空格（避开生成器与毛线格）"""
	var best_dist := 999
	var best_pos := Vector2i(-1, -1)
	for pos in BoardGameData.all_cells():
		if pos == BoardGameData.GENERATOR_POS:
			continue
		if not grid.has(pos) and pos not in special_tiles:
			var d: int = abs(pos.x - center.x) + abs(pos.y - center.y)
			if d < best_dist:
				best_dist = d
				best_pos = pos
	return best_pos


func trigger_frenzy() -> bool:
	"""触发狂欢：兴奋值需满、未超本局狂欢次数、对局进行中"""
	if excitement < BoardGameData.EXCITEMENT_MAX:
		return false
	if frenzy_triggers_used >= BoardGameData.FRENZY_MAX_TRIGGERS:
		return false
	if game_state != BoardGameData.GameState.PLAYING:
		return false
	frenzy_triggers_used += 1
	frenzy_active = true
	frenzy_timer = BoardGameData.FRENZY_DURATION_SECONDS
	excitement = 0
	excitement_changed.emit(excitement, BoardGameData.EXCITEMENT_MAX)
	frenzy_activated.emit()
	return true


func _process(delta: float) -> void:
	"""狂欢倒计时"""
	if not frenzy_active:
		return
	if game_state != BoardGameData.GameState.PLAYING:
		return
	frenzy_timer -= delta
	if frenzy_timer <= 0.0:
		frenzy_active = false
		frenzy_ended.emit()


func _serialize_special_tiles() -> Dictionary:
	var data: Dictionary = {}
	for pos in special_tiles:
		data[_pos_to_key(pos)] = special_tiles[pos]
	return data


func _deserialize_special_tiles(data: Variant) -> Dictionary:
	var tiles: Dictionary = {}
	if data is Dictionary:
		for key in data:
			tiles[_key_to_pos(str(key))] = int(data[key])
	return tiles
