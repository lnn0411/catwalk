extends Node

const BoardGame := preload("res://scripts/board_game/BoardGame.gd")
const BoardGameData := preload("res://scripts/board_game/BoardGameData.gd")
const BoardItem := preload("res://scripts/board_game/BoardItem.gd")

# ============================================================
# 猫咪合合乐 · 蒙特卡洛通关率实测（M4-4.1）
# 贪心策略 bot：合并优先（主链优先/高星优先，副链只合到⭐3）
#   → 副链⭐3走出口 → 点生成器
# bot 不失误、即时决策、必用出口，不用撤销/狂欢/广告救局；
# 结果是高效玩家的通关率上界近似，真实玩家会低于此值
# 用法: godot --headless tests/board_montecarlo.tscn
# 环境变量 MC_RUNS 控制每关卡局数（默认 1000）
# ============================================================

const MAX_STEPS_PER_GAME := 600

var runs_per_level := 1000


func _ready() -> void:
	var env_runs := OS.get_environment("MC_RUNS")
	if not env_runs.is_empty():
		runs_per_level = maxi(int(env_runs), 10)
	print("=".repeat(64))
	print("  猫咪合合乐 · 蒙特卡洛通关率实测（%d 局/关卡，贪心bot）" % runs_per_level)
	print("=".repeat(64))
	var target := {1: 92.0, 2: 85.0, 3: 75.0}
	var all_ok := true
	for level in [BoardGameData.BoardLevel.LV1, BoardGameData.BoardLevel.LV2, BoardGameData.BoardLevel.LV3]:
		var stats := _run_level(level)
		var clear_rate: float = 100.0 * stats["wins"] / float(runs_per_level)
		var star3_rate: float = 100.0 * stats["star3"] / float(maxi(stats["wins"], 1))
		print("LV%d: 通关率 %.1f%% (目标≥%.0f%%) | 三星率 %.1f%% | 平均点击 %.1f | 捣乱均 %.2f | 死局: 生成器耗尽 %d / 棋盘满 %d" % [
			level, clear_rate, target[level], star3_rate,
			stats["avg_clicks"], stats["avg_mischief"],
			stats["lost_generator"], stats["lost_full"],
		])
		if clear_rate < target[level]:
			all_ok = false
	print("-".repeat(64))
	print("蒙特卡洛结论: %s" % ("PASS（各关卡通关率均达标）" if all_ok else "FAIL（存在关卡低于目标线）"))
	get_tree().quit(0 if all_ok else 1)


func _run_level(level: int) -> Dictionary:
	var stats := {
		"wins": 0, "star3": 0, "lost_generator": 0, "lost_full": 0,
		"avg_clicks": 0.0, "avg_mischief": 0.0,
	}
	var total_clicks := 0
	var total_mischief := 0
	for i in range(runs_per_level):
		var b := BoardGame.new()
		add_child(b)
		b.start_new_game(level, "bot")
		var mischief_count := [0]
		b.mischief_triggered.connect(func(_pos: Vector2i, _item: BoardItem) -> void:
			mischief_count[0] += 1
		)
		_play_out(b)
		total_clicks += b.generator_click_count
		total_mischief += mischief_count[0]
		if b.game_state == BoardGameData.GameState.WON:
			stats["wins"] += 1
			if b.star_rating >= 3:
				stats["star3"] += 1
		else:
			if b._get_empty_cells().is_empty():
				stats["lost_full"] += 1
			else:
				stats["lost_generator"] += 1
		remove_child(b)
		b.free()
	stats["avg_clicks"] = total_clicks / float(runs_per_level)
	stats["avg_mischief"] = total_mischief / float(runs_per_level)
	return stats


func _play_out(b: BoardGame) -> void:
	for _step in range(MAX_STEPS_PER_GAME):
		if b.game_state != BoardGameData.GameState.PLAYING:
			return
		if _try_merge(b):
			continue
		if _try_sub_exit(b):
			continue
		if b.generator_remaining > 0 and b.click_generator():
			continue
		return  # 无操作可做（引擎应已判死局）


func _try_merge(b: BoardGame) -> bool:
	"""找最优可合并对：主链优先、星级高优先；副链只合⭐1/⭐2（合到⭐3为止）"""
	var by_id: Dictionary = {}
	for pos in b.grid:
		if pos in b.special_tiles:
			continue
		var item: BoardItem = b.grid[pos]
		if item.is_max_star():
			continue
		if item.chain == b.current_sub_chain and item.star >= BoardGameData.StarLevel.THREE:
			continue  # 副链⭐3是出口素材，不再往上合
		if not by_id.has(item.id):
			by_id[item.id] = []
		by_id[item.id].append(pos)
	var best_pair: Array = []
	var best_score := -1
	for id in by_id:
		var positions: Array = by_id[id]
		if positions.size() < 2:
			continue
		var sample: BoardItem = b.grid[positions[0]]
		var score: int = sample.star * 10 + (100 if sample.chain == b.current_main_chain else 0)
		if score > best_score:
			best_score = score
			best_pair = [positions[0], positions[1]]
	if best_pair.is_empty():
		return false
	return b.merge_items(best_pair[0], best_pair[1])


func _try_sub_exit(b: BoardGame) -> bool:
	for pos in b.grid:
		var item: BoardItem = b.grid[pos]
		if item.chain == b.current_sub_chain and item.star == BoardGameData.StarLevel.THREE:
			return b.sub_chain_exit(pos)
	return false
