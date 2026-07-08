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
