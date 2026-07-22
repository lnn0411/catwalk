extends Node

const BoardGame := preload("res://scripts/board_game/BoardGame.gd")
const BoardGameData := preload("res://scripts/board_game/BoardGameData.gd")
const BoardItem := preload("res://scripts/board_game/BoardItem.gd")

# ============================================================
# 猫咪合合乐 · 棋盘逻辑自检（headless）
# 用法: godot --headless tests/board_game_selfcheck.tscn
# ============================================================

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("=".repeat(56))
	print("  猫咪合合乐 · BoardGame 自检")
	print("=".repeat(56))

	_t_new_game()
	_t_generator_click()
	_t_deterministic_sequence()
	_t_merge_upgrade()
	_t_cannot_merge()
	_t_win_detection()
	_t_deadlock_detection()
	_t_no_deadlock_when_mergeable()
	_t_serialize_restore()
	_t_undo_merge()
	_t_sub_chain_exit()
	_t_undo_paid_gate()
	_t_undo_excitement_rollback()
	_t_undo_triple_merge()
	_t_triple_merge_win()
	_t_triple_merge_sub_exit_signal()
	_t_sub_exit_second_time()
	_t_deadlock_lifeline()
	_t_sequence_no_rewind()
	_t_extra_clicks_main_chain()
	_t_undo_generator_click_count()
	_t_reward_tables()

	print("-".repeat(56))
	print("结果: %d 通过 / %d 失败" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS: %s" % label)
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func _fresh() -> BoardGame:
	var b := BoardGame.new()
	add_child(b)
	b.start_new_game()
	return b


func _same_serialized_state(a: Dictionary, b: Dictionary) -> bool:
	return var_to_str(a) == var_to_str(b)


func _t_new_game() -> void:
	print("[新局初始化]")
	var b := _fresh()
	_check(b.grid.size() > 0, "棋盘有初始物品")
	_check(b.current_main_chain != b.current_sub_chain, "主链副链不同")
	_check(b.generator_remaining == 20, "生成器=20")
	_check(not b.grid.has(BoardGameData.GENERATOR_POS), "生成器格无物品")
	b.queue_free()


func _t_generator_click() -> void:
	print("[生成器点击]")
	var b := _fresh()
	b.grid.clear()
	b.generator_remaining = BoardGameData.GENERATOR_TOTAL
	var expected_pos: Vector2i = b._nearest_empty(b._get_empty_cells(), BoardGameData.GENERATOR_POS)
	_check(b.click_generator(), "点击生成器成功")
	_check(b.grid.has(expected_pos), "最近空格产出")
	_check(b.grid[expected_pos].grid_pos == expected_pos, "产出格有物品")
	_check(b.generator_remaining == BoardGameData.GENERATOR_TOTAL - 1, "次数递减")
	b.queue_free()


func _t_deterministic_sequence() -> void:
	print("[确定性序列]")
	var b := _fresh()
	b.grid.clear()
	b.generator_remaining = BoardGameData.GENERATOR_TOTAL
	var drops: Array = []
	b.generator_clicked.connect(func(_pos: Vector2i, item: BoardItem) -> void:
		drops.append(item.chain)
	)
	for i in range(5):
		_check(b.click_generator(), "第%d次点击成功" % [i + 1])
	_check(drops.size() == 5, "记录到5次产出")
	_check(drops[4] == b.current_sub_chain, "第5次点击为副链品种")
	b.queue_free()


func _t_merge_upgrade() -> void:
	print("[合并升级]")
	var b := _fresh()
	b.grid.clear()
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p1)
	b.grid[p2] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p2)
	_check(b.merge_items(p1, p2), "同链同星可合并")
	_check(not b.grid.has(p1), "源格移除")
	_check(b.grid.has(p2), "目标格保留")
	_check(b.grid[p2].star == BoardGameData.StarLevel.TWO, "合为高一级")
	b.queue_free()


func _t_cannot_merge() -> void:
	print("[不可合并]")
	var b := _fresh()
	b.grid.clear()
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	var p3 := Vector2i(2, 0)
	var p4 := Vector2i(3, 0)
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p1)
	b.grid[p2] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.ONE, p2)
	b.grid[p3] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p3)
	b.grid[p4] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.TWO, p4)
	_check(not b.merge_items(p1, p2), "不同链不可合")
	_check(not b.merge_items(p3, p4), "不同星不可合")
	_check(b.grid.has(p1) and b.grid.has(p2) and b.grid.has(p3) and b.grid.has(p4), "失败后棋盘不变")
	b.queue_free()


func _t_win_detection() -> void:
	print("[通关检测]")
	var b := _fresh()
	b.grid.clear()
	var won := [false]
	b.game_won.connect(func() -> void:
		won[0] = true
	)
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.FOUR, p1)
	b.grid[p2] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.FOUR, p2)
	_check(b.merge_items(p1, p2), "主链⭐4合并成功")
	_check(b.grid[p2].star == BoardGameData.StarLevel.FIVE, "产物为主链⭐5")
	_check(won[0], "触发胜利信号")
	_check(b.game_state == BoardGameData.GameState.WON, "状态为WON")
	b.queue_free()


func _t_deadlock_detection() -> void:
	print("[死局检测]")
	var b := _fresh()
	b.grid.clear()
	b.generator_remaining = 0
	var lost := [false]
	b.game_lost.connect(func() -> void:
		lost[0] = true
	)
	var filler_chain := BoardGameData.ItemChain.WEAR
	for pos in BoardGameData.all_cells():
		if pos == BoardGameData.GENERATOR_POS:
			continue
		b.grid[pos] = BoardItem.create(filler_chain, BoardGameData.StarLevel.FIVE, pos)
	_check(b._get_empty_cells().is_empty(), "满格")
	_check(not b._has_mergeable(), "无合并")
	b._check_deadlock()
	_check(lost[0], "触发死局信号")
	_check(b.game_state == BoardGameData.GameState.LOST, "状态为LOST")
	b.queue_free()


func _t_no_deadlock_when_mergeable() -> void:
	print("[死局负向检测]")
	var b := _fresh()
	b.grid.clear()
	# 毛线格随机落点可能与本用例的固定测试格重合（真实对局物品不会在毛线格上），
	# 清掉以保证用例确定性
	b.special_tiles.clear()
	b.generator_remaining = 0
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p1)
	b.grid[p2] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p2)
	b._check_deadlock()
	_check(b.game_state != BoardGameData.GameState.LOST, "生成器=0但有可合并对不死局")

	b.grid.clear()
	b.generator_remaining = 1
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.FIVE, p1)
	b._check_deadlock()
	_check(b.game_state != BoardGameData.GameState.LOST, "生成器>0且有空格不死局")
	b.queue_free()


func _t_serialize_restore() -> void:
	print("[序列化恢复]")
	var b := _fresh()
	b.grid.clear()
	b.generator_remaining = 12
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.TWO, p1)
	b.grid[p2] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.THREE, p2)
	b.move_item(p1, Vector2i(0, 1))
	var saved := b.serialize_state()
	var restored := BoardGame.new()
	add_child(restored)
	restored.deserialize_state(saved)
	_check(_same_serialized_state(saved, restored.serialize_state()), "save后restore状态一致")
	_check(restored.generator_remaining == 12, "生成器次数恢复")
	_check(restored.grid.size() == b.grid.size(), "棋盘物品数恢复")
	restored.queue_free()
	b.queue_free()


func _t_undo_merge() -> void:
	print("[撤销合并]")
	var b := _fresh()
	b.grid.clear()
	b.undo_stack.clear()
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.TWO, p1)
	b.grid[p2] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.TWO, p2)
	var before := b.serialize_state()
	_check(b.merge_items(p1, p2), "合并成功")
	_check(b.undo(), "撤销成功")
	var after := b.serialize_state()
	_check(after.grid == before.grid, "合并后撤销回到原棋盘")
	_check(b.grid[p1].star == BoardGameData.StarLevel.TWO and b.grid[p2].star == BoardGameData.StarLevel.TWO, "原星级恢复")
	b.queue_free()


func _t_sub_chain_exit() -> void:
	print("[副链出口]")
	var b := _fresh()
	b.grid.clear()
	b.generator_remaining = 3
	var p := Vector2i(0, 0)
	b.grid[p] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.THREE, p)
	_check(b.sub_chain_exit(p), "点击⭐3副链成功")
	_check(not b.grid.has(p), "副链⭐3被移除")
	_check(b.generator_remaining == 5, "次数+2")
	_check(b.sub_chain_exit_used, "副链出口标记已使用")
	b.queue_free()


# ---------------- M1 热修用例 ----------------

func _t_undo_paid_gate() -> void:
	print("[M1-1 撤销付费拦截]")
	var b := _fresh()
	b.grid.clear()
	b.undo_stack.clear()
	b.undo_free_count = 0
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p1)
	b.grid[p2] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p2)
	_check(b.merge_items(p1, p2), "合并成功")
	_check(not b.undo(), "免费额度耗尽后未付费撤销被拒")
	_check(b.grid.has(p2) and b.grid[p2].star == BoardGameData.StarLevel.TWO, "拒绝后棋盘不变")
	_check(b.undo(true), "付费撤销成功")
	_check(b.get_undo_cost()["diamond_cost"] == BoardGame.UNDO_DIAMOND_COST, "付费期成本=10钻")
	b.queue_free()


func _t_undo_excitement_rollback() -> void:
	print("[M1-2 撤销回退兴奋值]")
	var b := _fresh()
	b.grid.clear()
	b.undo_stack.clear()
	b.excitement = 0
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p1)
	b.grid[p2] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p2)
	_check(b.merge_items(p1, p2), "合并成功")
	_check(b.excitement > 0, "合并增加兴奋值")
	_check(b.undo(), "撤销成功")
	_check(b.excitement == 0, "兴奋值回退到合并前")
	_check(b._combo_count == 0, "连击计数重置")
	b.queue_free()


func _t_undo_triple_merge() -> void:
	print("[M1-2 三连合撤销完整性]")
	var b := _fresh()
	b.grid.clear()
	b.undo_stack.clear()
	b.special_tiles.clear()
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	var p3 := Vector2i(2, 0)
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p1)
	b.grid[p2] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.ONE, p2)
	b.grid[p3] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.TWO, p3)
	var before := b.serialize_state()
	_check(b.merge_items(p1, p2), "合并触发三连合")
	_check(b.grid.has(p2) and b.grid[p2].star == BoardGameData.StarLevel.THREE, "三连合产物⭐3")
	_check(not b.grid.has(p3), "邻居⭐2被吞")
	_check(b.undo(), "撤销成功")
	var after := b.serialize_state()
	_check(after.grid == before.grid, "撤销后棋盘完全还原（邻居归位、返还⭐1收回）")
	b.queue_free()


func _t_triple_merge_win() -> void:
	print("[M1修复 三连合直达主链⭐5判胜]")
	var b := _fresh()
	b.grid.clear()
	b.undo_stack.clear()
	b.special_tiles.clear()
	var won := [false]
	b.game_won.connect(func() -> void:
		won[0] = true
	)
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	var p3 := Vector2i(2, 0)
	b.grid[p1] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.THREE, p1)
	b.grid[p2] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.THREE, p2)
	b.grid[p3] = BoardItem.create(b.current_main_chain, BoardGameData.StarLevel.FOUR, p3)
	_check(b.merge_items(p1, p2), "⭐3+⭐3合并成功")
	_check(b.grid.has(p2) and b.grid[p2].star == BoardGameData.StarLevel.FIVE, "三连合产物为⭐5")
	_check(won[0], "三连合直达⭐5触发胜利信号")
	_check(b.game_state == BoardGameData.GameState.WON, "状态为WON")
	b.queue_free()


func _t_triple_merge_sub_exit_signal() -> void:
	print("[M1修复 三连合产出副链⭐3发出口提示]")
	var b := _fresh()
	b.grid.clear()
	b.undo_stack.clear()
	b.special_tiles.clear()
	var completed := [false]
	b.sub_chain_completed.connect(func(_item: BoardItem) -> void:
		completed[0] = true
	)
	var p1 := Vector2i(0, 0)
	var p2 := Vector2i(1, 0)
	var p3 := Vector2i(2, 0)
	b.grid[p1] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.ONE, p1)
	b.grid[p2] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.ONE, p2)
	b.grid[p3] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.TWO, p3)
	_check(b.merge_items(p1, p2), "副链⭐1+⭐1合并成功")
	_check(b.grid.has(p2) and b.grid[p2].star == BoardGameData.StarLevel.THREE, "三连合产物为副链⭐3")
	_check(completed[0], "三连合产出副链⭐3发出提示信号")
	b.queue_free()


func _t_sub_exit_second_time() -> void:
	print("[M1-2 副链出口二次结算]")
	var b := _fresh()
	b.grid.clear()
	b.generator_remaining = 3
	var results: Array = []
	b.sub_chain_exit_done.connect(func(_pos: Vector2i, first_time: bool) -> void:
		results.append(first_time)
	)
	var p := Vector2i(0, 0)
	b.grid[p] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.THREE, p)
	_check(b.sub_chain_exit(p), "首次出口成功")
	b.grid[p] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.THREE, p)
	_check(b.sub_chain_exit(p), "二次出口成功")
	_check(b.generator_remaining == 5, "仅首次返还+2")
	_check(results == [true, false], "出口信号 first_time 标记正确")
	b.queue_free()


func _t_deadlock_lifeline() -> void:
	print("[M1-3 死局出口豁免]")
	var b := _fresh()
	b.grid.clear()
	b.generator_remaining = 0
	var lifeline := [false]
	b.sub_exit_lifeline.connect(func(_pos: Vector2i) -> void:
		lifeline[0] = true
	)
	var p := Vector2i(0, 0)
	b.grid[p] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.THREE, p)
	b._check_deadlock()
	_check(b.game_state == BoardGameData.GameState.PLAYING, "有副链⭐3+出口未用不判负")
	_check(lifeline[0], "发出自救提示信号")
	_check(b.sub_chain_exit(p), "走出口自救成功")
	_check(b.generator_remaining == 2, "出口返还+2次生成器")
	# 出口已用后再陷入同样局面 → 正常判负
	b.grid.clear()
	b.generator_remaining = 0
	b.grid[p] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.THREE, p)
	b._check_deadlock()
	_check(b.game_state == BoardGameData.GameState.LOST, "出口已用后同局面正常判负")
	b.queue_free()


func _t_sequence_no_rewind() -> void:
	print("[M1-4 出口返还不倒带序列]")
	var b := _fresh()
	b.grid.clear()
	b.generator_remaining = BoardGameData.GENERATOR_TOTAL
	var drops: Array = []
	b.generator_clicked.connect(func(_pos: Vector2i, item: BoardItem) -> void:
		drops.append(item.chain)
	)
	for i in range(4):
		b.click_generator()
	# 第4次点击后走出口返还+2（remaining 16→18），旧实现会使索引倒带
	var p := Vector2i(4, 4)
	b.grid[p] = BoardItem.create(b.current_sub_chain, BoardGameData.StarLevel.THREE, p)
	_check(b.sub_chain_exit(p), "出口返还成功")
	b.click_generator()  # 第5次点击：索引4，必须仍是副链
	_check(drops.size() == 5 and drops[4] == b.current_sub_chain, "返还后第5次点击仍为副链（序列不倒带）")
	b.queue_free()


func _t_extra_clicks_main_chain() -> void:
	print("[M1-4 超出序列恒出主链]")
	var b := _fresh()
	b.grid.clear()
	b.generator_click_count = BoardGameData.DROP_SEQUENCE.size()  # 已走完20次
	b.generator_remaining = 2  # 出口返还的额外次数
	var drops: Array = []
	b.generator_clicked.connect(func(_pos: Vector2i, item: BoardItem) -> void:
		drops.append(item.chain)
	)
	b.click_generator()
	b.click_generator()
	_check(drops.size() == 2, "额外2次点击成功")
	_check(drops[0] == b.current_main_chain and drops[1] == b.current_main_chain, "超出序列的点击恒出主链")
	b.queue_free()


func _t_undo_generator_click_count() -> void:
	print("[M1-4 撤销生成器回退计数]")
	var b := _fresh()
	b.grid.clear()
	b.generator_remaining = BoardGameData.GENERATOR_TOTAL
	b.undo_stack.clear()
	var drops: Array = []
	b.generator_clicked.connect(func(_pos: Vector2i, item: BoardItem) -> void:
		drops.append(item.chain)
	)
	b.click_generator()
	_check(b.generator_click_count == 1, "点击后计数=1")
	_check(b.undo(), "撤销生成器点击成功")
	_check(b.generator_click_count == 0, "撤销后计数回退到0")
	b.click_generator()
	_check(drops.size() == 2 and drops[0] == drops[1], "重新点击产出与被撤销一致（不可reroll）")
	b.queue_free()


func _t_reward_tables() -> void:
	print("[M1-5 奖励分表]")
	var RewardS := preload("res://scripts/board_game/RewardSystem.gd")
	for level in [BoardGameData.BoardLevel.LV1, BoardGameData.BoardLevel.LV2, BoardGameData.BoardLevel.LV3]:
		var table: Dictionary = RewardS.REWARDS_BY_LEVEL[level]
		var total := 0
		for k in table:
			total += int(table[k]["weight"])
		_check(total == 100, "LV%d 权重总和=100" % level)
	var lv1_decor: int = RewardS.REWARDS_BY_LEVEL[BoardGameData.BoardLevel.LV1]["cat_tree"]["weight"] + RewardS.REWARDS_BY_LEVEL[BoardGameData.BoardLevel.LV1]["cherry_tree"]["weight"]
	var lv3_decor: int = RewardS.REWARDS_BY_LEVEL[BoardGameData.BoardLevel.LV3]["cat_tree"]["weight"] + RewardS.REWARDS_BY_LEVEL[BoardGameData.BoardLevel.LV3]["cherry_tree"]["weight"]
	_check(lv3_decor > lv1_decor, "LV3 装饰权重高于 LV1")
	for i in range(50):
		var reward: Dictionary = RewardS.roll_reward(BoardGameData.BoardLevel.LV3)
		if not reward.has("id") or not reward.has("name"):
			_check(false, "roll_reward 返回结构完整")
			return
	_check(true, "roll_reward×50 返回结构完整")
