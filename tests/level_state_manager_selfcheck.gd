extends Node

const LevelStateManager := preload("res://scripts/board_game/LevelStateManager.gd")
const BoardGameData := preload("res://scripts/board_game/BoardGameData.gd")

# ============================================================
# 棋盘三档等级系统 · 持久化 + 升档自检（headless）
# 用法: godot --headless tests/level_state_manager_selfcheck.tscn
# 覆盖验收 TC-53
# ============================================================

const SAVE_PATH := "user://cat_merge_save.cfg"

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("=".repeat(56))
	print("  棋盘三档等级系统 · 自检 (TC-53)")
	print("=".repeat(56))

	_t_default_new_save()
	_t_upgrade_lv1_to_lv2()
	_t_upgrade_lv2_to_lv3()
	_t_persist_across_instances()
	_t_no_downgrade_when_wins_lost()
	_t_self_heal_level_lost()
	_t_delete_keeps_meta()
	_t_session_meta_coexist()
	_t_win_milestones()
	_t_milestone_persist()
	_t_milestone_cycle()
	_t_b6_decor_caps()

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


func _wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _fresh_manager() -> Node:
	# 手动实例化 autoload 脚本，触发 _ready → _load_meta
	var m := LevelStateManager.new()
	add_child(m)
	return m


func _t_default_new_save() -> void:
	print("[默认值 / 空存档]")
	_wipe_save()
	var m := _fresh_manager()
	_check(m.get_total_wins() == 0, "无存档时累计胜场=0")
	_check(m.get_board_level() == BoardGameData.BoardLevel.LV1, "无存档时等级=Lv1")
	m.queue_free()


func _t_upgrade_lv1_to_lv2() -> void:
	print("[0→5 胜触发 Lv1→Lv2]")
	_wipe_save()
	var m := _fresh_manager()
	var upgraded_at := -1
	for i in range(1, 5):
		_check(m.record_win() == -1, "第%d胜不升档" % i)
	upgraded_at = m.record_win()  # 第5胜
	_check(upgraded_at == BoardGameData.BoardLevel.LV2, "第5胜升到Lv2")
	_check(m.get_board_level() == BoardGameData.BoardLevel.LV2, "当前等级=Lv2")
	_check(m.get_total_wins() == 5, "累计胜场=5")
	m.queue_free()


func _t_upgrade_lv2_to_lv3() -> void:
	print("[5→15 胜触发 Lv2→Lv3]")
	# 承接上一测试的存档（total_wins=5, board_level=2）
	var m := _fresh_manager()
	_check(m.get_total_wins() == 5, "载入累计胜场=5")
	_check(m.get_board_level() == BoardGameData.BoardLevel.LV2, "载入等级=Lv2")
	for i in range(6, 15):
		_check(m.record_win() == -1, "第%d胜不升档" % i)
	var upgraded: int = m.record_win()  # 第15胜
	_check(upgraded == BoardGameData.BoardLevel.LV3, "第15胜升到Lv3")
	_check(m.get_board_level() == BoardGameData.BoardLevel.LV3, "当前等级=Lv3")
	m.queue_free()


func _t_persist_across_instances() -> void:
	print("[跨实例持久化]")
	# 上一测试已把 total_wins=15, board_level=3 写盘
	var m := _fresh_manager()
	_check(m.get_total_wins() == 15, "新实例载入累计胜场=15")
	_check(m.get_board_level() == BoardGameData.BoardLevel.LV3, "新实例载入等级=Lv3")
	m.queue_free()


func _t_no_downgrade_when_wins_lost() -> void:
	print("[胜场丢失也不降级]")
	# 伪造损坏存档：board_level=3 但 total_wins=0
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "total_wins", 0)
	cfg.set_value("meta", "board_level", BoardGameData.BoardLevel.LV3)
	cfg.save(SAVE_PATH)
	var m := _fresh_manager()
	_check(m.get_board_level() == BoardGameData.BoardLevel.LV3, "board_level 持久值不降 (仍Lv3)")
	m.queue_free()


func _t_delete_keeps_meta() -> void:
	print("[delete 保留 meta]")
	_wipe_save()
	var m := _fresh_manager()
	m.record_win()
	m.record_win()  # total_wins=2, level=Lv1
	m.delete()  # 开新局会调用 delete
	var m2 := _fresh_manager()
	_check(m2.get_total_wins() == 2, "delete 后累计胜场仍=2")
	m.queue_free()
	m2.queue_free()
	_wipe_save()


func _t_self_heal_level_lost() -> void:
	print("[等级丢失但胜场在 → 自愈升级]")
	_wipe_save()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "total_wins", 16)  # 16胜应到 Lv3
	# 不写 board_level → 模拟等级丢失
	cfg.save(SAVE_PATH)
	var m := _fresh_manager()
	_check(m.get_total_wins() == 16, "胜场=16")
	_check(m.get_board_level() == BoardGameData.BoardLevel.LV3, "自愈升级到Lv3 (calc_board_level(16)=3)")
	m.queue_free()
	_wipe_save()


func _t_session_meta_coexist() -> void:
	print("[session 与 meta 双 section 共存]")
	_wipe_save()
	var m := _fresh_manager()
	# 先写入 meta：累计5胜 → Lv2
	for _i in range(5):
		m.record_win()
	_check(m.get_board_level() == BoardGameData.BoardLevel.LV2, "meta: Lv2")
	# 再通过 save() 写入 session state
	m.game.start_new_game(m.get_board_level(), "测试猫")
	m.save()
	# 新实例同时载入 session 和 meta
	var m2 := _fresh_manager()
	_check(m2.get_total_wins() == 5, "meta 胜场=5 仍存在")
	_check(m2.get_board_level() == BoardGameData.BoardLevel.LV2, "meta 等级=Lv2 仍存在")
	_check(m2.has_saved(), "session 存档仍存在")
	m.queue_free()
	m2.queue_free()
	_wipe_save()


# ---------------- M3-3.1 胜场里程碑 ----------------

func _t_win_milestones() -> void:
	print("[M3 里程碑 25/50 胜]")
	_wipe_save()
	var m := _fresh_manager()
	var reached: Array = []
	m.win_milestone_reached.connect(func(wins: int, _reward: Dictionary) -> void:
		reached.append(wins)
	)
	m.total_wins = 24
	var d_before: int = CurrencyManager.get_diamonds() if CurrencyManager != null else 0
	m.record_win()  # 第25胜
	_check(reached == [25], "第25胜触发里程碑")
	_check(25 in m.claimed_milestones, "25已记录领取")
	if CurrencyManager != null:
		_check(CurrencyManager.get_diamonds() - d_before == 30, "💎30入账")
	m.record_win()  # 26胜：不应重复
	_check(reached == [25], "26胜不重复触发")
	m.total_wins = 49
	m.record_win()  # 第50胜
	_check(reached == [25, 50], "第50胜触发里程碑")
	var reward_50: Dictionary = {}
	for ms in m.WIN_MILESTONES:
		if int(ms["wins"]) == 50:
			reward_50 = ms
	_check(not reward_50.get("items", []).is_empty(), "50胜奖励含物品")
	m.queue_free()
	_wipe_save()


func _t_milestone_persist() -> void:
	print("[M3 里程碑持久化与一次性补领]")
	_wipe_save()
	var m := _fresh_manager()
	var reached1: Array = []
	m.win_milestone_reached.connect(func(wins: int, _reward: Dictionary) -> void:
		reached1.append(wins)
	)
	m.total_wins = 99
	m.record_win()  # 第100胜：25/50/100 全部达成且未领 → 一次性补领
	_check(reached1 == [25, 50, 100], "跳到100胜时25/50/100一次性补领（实际%s）" % str(reached1))
	_check("合合小能手" in m.get_earned_titles(), "称号已获得")
	m.queue_free()
	# 新实例载入：不重复发放，记录仍在
	var m2 := _fresh_manager()
	var reached2: Array = []
	m2.win_milestone_reached.connect(func(wins: int, _reward: Dictionary) -> void:
		reached2.append(wins)
	)
	_check(100 in m2.claimed_milestones, "领取记录跨实例持久化")
	_check("合合小能手" in m2.get_earned_titles(), "称号跨实例持久化")
	m2.record_win()  # 101胜：全部已领 → 不再触发
	_check(reached2.is_empty(), "已领里程碑不重复触发")
	var info: Dictionary = m2.get_next_milestone_info()
	_check(int(info["wins"]) == 200 and int(info["remaining"]) == 99, "下一里程碑指向200")
	m2.queue_free()
	_wipe_save()


func _t_milestone_cycle() -> void:
	print("[M3 300+循环里程碑]")
	_wipe_save()
	var m := _fresh_manager()
	# 预标记固定里程碑为已领，聚焦循环逻辑
	m.claimed_milestones = [25, 50, 100, 200]
	m.total_wins = 299
	var reached: Array = []
	m.win_milestone_reached.connect(func(wins: int, _reward: Dictionary) -> void:
		reached.append(wins)
	)
	var d_before: int = CurrencyManager.get_diamonds() if CurrencyManager != null else 0
	m.record_win()  # 第300胜
	_check(reached == [300], "第300胜触发循环里程碑")
	if CurrencyManager != null:
		_check(CurrencyManager.get_diamonds() - d_before == 50, "循环奖励💎50入账")
	m.total_wins = 399
	m.record_win()
	_check(reached == [300, 400], "第400胜继续循环")
	var info: Dictionary = m.get_next_milestone_info()
	_check(int(info["wins"]) == 500, "下一循环点=500")
	m.queue_free()
	_wipe_save()


# ---------------- B6 装饰上限与折算 ----------------

func _t_b6_decor_caps() -> void:
	print("[B6 装饰上限折算]")
	_wipe_save()
	var m := _fresh_manager()
	# 猫爬架上限3：前3次入库，第4次折算50金
	for i in range(3):
		var r: Dictionary = m.process_board_decor("cat_tree")
		_check(not bool(r["converted"]), "第%d个猫爬架正常入库" % (i + 1))
	var gold_before: int = CurrencyManager.get("gold_coins") if CurrencyManager != null else 0
	var r4: Dictionary = m.process_board_decor("cat_tree")
	_check(bool(r4["converted"]) and int(r4["gold"]) == 50, "第4个猫爬架折算💰50")
	if CurrencyManager != null:
		_check(int(CurrencyManager.get("gold_coins")) - gold_before == 50, "金币入账50")
	# 樱花树上限1
	_check(not bool(m.process_board_decor("cherry_tree")["converted"]), "首个樱花树入库")
	_check(bool(m.process_board_decor("cherry_tree")["converted"]), "第2个樱花树折算")
	# 未配置上限的装饰直接放行
	_check(not bool(m.process_board_decor("yarn_throne")["converted"]), "无上限装饰放行")
	m.queue_free()
	# 计数跨实例持久化：新实例第5个猫爬架仍折算
	var m2 := _fresh_manager()
	_check(bool(m2.process_board_decor("cat_tree")["converted"]), "装饰计数跨实例持久化（第5个仍折算）")
	m2.queue_free()
	_wipe_save()
