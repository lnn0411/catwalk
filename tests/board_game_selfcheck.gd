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
