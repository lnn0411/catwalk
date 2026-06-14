# AchievementSystem TDD Test Suite
# 猫步天下 Day4 — 20成就全覆盖
extends Node

var passed := 0
var failed := 0
var results: Array[String] = []

func _ready() -> void:
	print("========================================")
	print("  AchievementSystem 测试套件")
	print("========================================")

	# 步数类 A1-A6
	test_a1_first_step()
	test_a2_daily_thousand()
	test_a3_marathon()
	test_a4_long_march()
	test_a5_everest()
	test_a6_never_stop()

	# 收集类 B1-B5
	test_b1_cat_servant()
	test_b2_three_mouths()
	test_b3_cat_hotel()
	test_b4_zoo_director()
	test_b5_family_photo()

	# 养成类 C1-C3
	test_c1_growth_happy()
	test_c2_perfect_partner()
	test_c3_affection_master()

	# 明信片类 E1-E4
	test_e1_first_postcard()
	test_e2_city_explorer()
	test_e3_worldly_cat()
	test_e4_city_storyteller()

	# 彩蛋类 D1-D2
	test_d1_midnight_cat()
	test_d2_rainy_visitor()

	# 奖励发放
	test_reward_delivery()
	# 持久化
	test_save_roundtrip()
	# 防重复
	test_no_duplicate_unlock()

	print("\n========================================")
	print("  结果: %d 通过 / %d 失败" % [passed, failed])
	for line in results:
		print(line)
	print("========================================")


func _pass(label: String) -> void:
	passed += 1
	results.append("  [PASS] %s" % label)

func _fail(label: String, detail := "") -> void:
	failed += 1
	var msg := "  [FAIL] %s" % label
	if detail != "":
		msg += " — %s" % detail
	results.append(msg)


# ── A1: 迈出第一步 (累计1000步) ──
func test_a1_first_step() -> void:
	print("\n--- A1: 迈出第一步 ---")
	StepEngine.apply_save({})
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	# 0步 → 未解锁
	_pass("A1 初始未解锁") if not AchievementSystem.is_unlocked("A1") else _fail("A1 初始未解锁", "已解锁")
	_pass("A1 初始进度=0") if AchievementSystem.get_progress("A1") == 0.0 else _fail("A1 初始进度≠0")

	# 模拟到达1000步
	StepEngine.add_mock_steps(1000)
	# 步数信号触发后检查
	AchievementSystem._check_step_achievements()
	_pass("A1 1000步后已解锁") if AchievementSystem.is_unlocked("A1") else _fail("A1 1000步后未解锁")
	_pass("A1 进度=1.0") if AchievementSystem.get_progress("A1") >= 1.0 else _fail("A1 进度≠1.0")


# ── A2: 日行千里 (累计10000步) ──
func test_a2_daily_thousand() -> void:
	print("\n--- A2: 日行千里 ---")
	StepEngine.apply_save({})
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	_pass("A2 初始未解锁") if not AchievementSystem.is_unlocked("A2") else _fail("A2 初始已解锁")

	StepEngine.add_mock_steps(5000)
	AchievementSystem._check_step_achievements()
	_pass("A2 5000步未解锁") if not AchievementSystem.is_unlocked("A2") else _fail("A2 5000步已解锁")
	_pass("A2 进度=0.5") if AchievementSystem.get_progress("A2") >= 0.5 else _fail("A2 进度≠0.5")

	StepEngine.add_mock_steps(5000)
	AchievementSystem._check_step_achievements()
	_pass("A2 10000步已解锁") if AchievementSystem.is_unlocked("A2") else _fail("A2 10000步未解锁")


# ── A3: 马拉松选手 (累计42195步) ──
func test_a3_marathon() -> void:
	print("\n--- A3: 马拉松选手 ---")
	StepEngine.apply_save({})
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	StepEngine.add_mock_steps(42195)
	AchievementSystem._check_step_achievements()
	_pass("A3 42195步已解锁") if AchievementSystem.is_unlocked("A3") else _fail("A3 42195步未解锁")


# ── A4: 万里长征 (累计100000步) ──
func test_a4_long_march() -> void:
	print("\n--- A4: 万里长征 ---")
	StepEngine.apply_save({})
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	StepEngine.add_mock_steps(50000)
	AchievementSystem._check_step_achievements()
	_pass("A4 50000步未解锁") if not AchievementSystem.is_unlocked("A4") else _fail("A4 50000步已解锁")

	StepEngine.add_mock_steps(50000)
	AchievementSystem._check_step_achievements()
	_pass("A4 100000步已解锁") if AchievementSystem.is_unlocked("A4") else _fail("A4 100000步未解锁")


# ── A5: 登顶珠峰 (累计1000000步) ──
func test_a5_everest() -> void:
	print("\n--- A5: 登顶珠峰 ---")
	StepEngine.apply_save({})
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	StepEngine.add_mock_steps(999999)
	AchievementSystem._check_step_achievements()
	_pass("A5 999999步未解锁") if not AchievementSystem.is_unlocked("A5") else _fail("A5 999999步已解锁")

	StepEngine.add_mock_steps(1)
	AchievementSystem._check_step_achievements()
	_pass("A5 1000000步已解锁") if AchievementSystem.is_unlocked("A5") else _fail("A5 1000000步未解锁")


# ── A6: 永不停歇 (连续7天≥3000步) ──
func test_a6_never_stop() -> void:
	print("\n--- A6: 永不停歇 ---")
	StepEngine.apply_save({})
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	# 模拟连续6天达标但不解锁
	for _i in range(6):
		AchievementSystem._record_daily_step_met(3000)
	_pass("A6 6天未解锁") if not AchievementSystem.is_unlocked("A6") else _fail("A6 6天已解锁")

	AchievementSystem._record_daily_step_met(3000)
	_pass("A6 7天已解锁") if AchievementSystem.is_unlocked("A6") else _fail("A6 7天未解锁")


# ── B1: 猫奴入门 (孵化第1只猫) ──
func test_b1_cat_servant() -> void:
	print("\n--- B1: 猫奴入门 ---")
	StepEngine.apply_save({})
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	_pass("B1 初始未解锁") if not AchievementSystem.is_unlocked("B1") else _fail("B1 初始已解锁")

	# 用 _on_hatch_complete 替代实际孵化(避免依赖整个孵化链路)
	AchievementSystem._on_hatch_complete(null)
	_pass("B1 孵化1只后已解锁") if AchievementSystem.is_unlocked("B1") else _fail("B1 孵化1只后未解锁")


# ── B2: 三口之家 (孵化10只猫) ──
func test_b2_three_mouths() -> void:
	print("\n--- B2: 三口之家 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	for _i in range(5):
		AchievementSystem._on_hatch_complete(null)
	_pass("B2 5只未解锁") if not AchievementSystem.is_unlocked("B2") else _fail("B2 5只已解锁")
	_pass("B2 进度=0.5") if AchievementSystem.get_progress("B2") >= 0.5 else _fail("B2 进度≠0.5")

	for _i in range(5):
		AchievementSystem._on_hatch_complete(null)
	_pass("B2 10只已解锁") if AchievementSystem.is_unlocked("B2") else _fail("B2 10只未解锁")


# ── B3: 猫咪旅馆 (孵化50只猫) ──
func test_b3_cat_hotel() -> void:
	print("\n--- B3: 猫咪旅馆 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	for _i in range(50):
		AchievementSystem._on_hatch_complete(null)
	_pass("B3 50只已解锁") if AchievementSystem.is_unlocked("B3") else _fail("B3 50只未解锁")


# ── B4: 动物园园长 (孵化100只猫) ──
func test_b4_zoo_director() -> void:
	print("\n--- B4: 动物园园长 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	for _i in range(100):
		AchievementSystem._on_hatch_complete(null)
	_pass("B4 100只已解锁") if AchievementSystem.is_unlocked("B4") else _fail("B4 100只未解锁")


# ── B5: 全家福 (集齐全部3品种) ──
func test_b5_family_photo() -> void:
	print("\n--- B5: 全家福 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	_pass("B5 初始未解锁") if not AchievementSystem.is_unlocked("B5") else _fail("B5 初始已解锁")

	# 注册已收集品种
	AchievementSystem._register_breed_collected("orange")
	_pass("B5 仅橘猫未解锁") if not AchievementSystem.is_unlocked("B5") else _fail("B5 橘猫就解锁了")

	AchievementSystem._register_breed_collected("british")
	_pass("B5 两品种未解锁") if not AchievementSystem.is_unlocked("B5") else _fail("B5 两品种就解锁了")

	AchievementSystem._register_breed_collected("siamese")
	_pass("B5 三品种已解锁") if AchievementSystem.is_unlocked("B5") else _fail("B5 三品种未解锁")


# ── C1: 成长快乐 (任意猫Lv.3) ──
func test_c1_growth_happy() -> void:
	print("\n--- C1: 成长快乐 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	_pass("C1 初始未解锁") if not AchievementSystem.is_unlocked("C1") else _fail("C1 初始已解锁")

	# level_up 信号: from=2, to=3
	AchievementSystem._on_level_up("cat_1", 2, 3)
	_pass("C1 Lv.3已解锁") if AchievementSystem.is_unlocked("C1") else _fail("C1 Lv.3未解锁")


# ── C2: 完美搭档 (任意猫Lv.10满级) ──
func test_c2_perfect_partner() -> void:
	print("\n--- C2: 完美搭档 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	AchievementSystem._on_level_up("cat_1", 8, 9)
	_pass("C2 Lv.9未解锁") if not AchievementSystem.is_unlocked("C2") else _fail("C2 Lv.9已解锁")

	AchievementSystem._on_level_up("cat_1", 9, 10)
	_pass("C2 Lv.10已解锁") if AchievementSystem.is_unlocked("C2") else _fail("C2 Lv.10未解锁")


# ── C3: 好感大师 (任意猫好感Lv.5) ──
func test_c3_affection_master() -> void:
	print("\n--- C3: 好感大师 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	# 模拟猫好感达到5级（InteractionSystem 好感值阈值）
	# friendship >= 25 记为好感Lv.5 (每级5点)
	AchievementSystem._on_friendship_changed("cat_1", 20)
	_pass("C3 好感20未解锁") if not AchievementSystem.is_unlocked("C3") else _fail("C3 好感20已解锁")

	AchievementSystem._on_friendship_changed("cat_1", 25)
	_pass("C3 好感25已解锁") if AchievementSystem.is_unlocked("C3") else _fail("C3 好感25未解锁")


# ── E1: 第一张明信片 (收集第1张) ──
func test_e1_first_postcard() -> void:
	print("\n--- E1: 第一张明信片 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	_pass("E1 初始未解锁") if not AchievementSystem.is_unlocked("E1") else _fail("E1 初始已解锁")

	AchievementSystem._on_postcard_obtained("pc_001", "city")
	_pass("E1 1张后已解锁") if AchievementSystem.is_unlocked("E1") else _fail("E1 1张后未解锁")


# ── E2: 城市探索者 (10张不同明信片) ──
func test_e2_city_explorer() -> void:
	print("\n--- E2: 城市探索者 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	for i in range(5):
		AchievementSystem._on_postcard_obtained("pc_%03d" % i, "city")
	_pass("E2 5张未解锁") if not AchievementSystem.is_unlocked("E2") else _fail("E2 5张已解锁")

	for i in range(5, 10):
		AchievementSystem._on_postcard_obtained("pc_%03d" % i, "city")
	_pass("E2 10张已解锁") if AchievementSystem.is_unlocked("E2") else _fail("E2 10张未解锁")


# ── E3: 见过世面的猫 (30张不同明信片) ──
func test_e3_worldly_cat() -> void:
	print("\n--- E3: 见过世面的猫 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	for i in range(30):
		AchievementSystem._on_postcard_obtained("pc_%03d" % i, "city")
	_pass("E3 30张已解锁") if AchievementSystem.is_unlocked("E3") else _fail("E3 30张未解锁")


# ── E4: 城市说书人 (集齐30张首发) ──
func test_e4_city_storyteller() -> void:
	print("\n--- E4: 城市说书人 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	# E4 需要集齐30张首发（与E3不同：E3=30张不同，E4=全部首发30张）
	# 实际逻辑同E3但有不同奖励，都设30张阈值
	for i in range(30):
		AchievementSystem._on_postcard_obtained("pc_%03d" % i, "city")
	_pass("E4 30张已解锁") if AchievementSystem.is_unlocked("E4") else _fail("E4 30张未解锁")


# ── D1: 午夜猫语 (0:00-5:00打开App) ──
func test_d1_midnight_cat() -> void:
	print("\n--- D1: 午夜猫语 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	_pass("D1 初始未解锁") if not AchievementSystem.is_unlocked("D1") else _fail("D1 初始已解锁")

	AchievementSystem._check_midnight_access(2, 30)  # 凌晨2:30
	_pass("D1 凌晨2:30已解锁") if AchievementSystem.is_unlocked("D1") else _fail("D1 凌晨2:30未解锁")


# ── D2: 雨天的访客 (连续7天互动同一只猫≥3次/天) ──
func test_d2_rainy_visitor() -> void:
	print("\n--- D2: 雨天的访客 ---")
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	var cat_id := "cat_test_d2"
	# 连续6天互动3次
	for _day in range(6):
		AchievementSystem._record_daily_interaction(cat_id, 3)
	_pass("D2 6天未解锁") if not AchievementSystem.is_unlocked("D2") else _fail("D2 6天已解锁")

	AchievementSystem._record_daily_interaction(cat_id, 3)
	_pass("D2 7天已解锁") if AchievementSystem.is_unlocked("D2") else _fail("D2 7天未解锁")


# ── 奖励发放 ──
func test_reward_delivery() -> void:
	print("\n--- 奖励发放 ---")
	StepEngine.apply_save({})
	AchievementSystem.reset_all()
	CurrencyManager.apply_save({})
	var gold_before := CurrencyManager.get_gold() if CurrencyManager else 0

	# 触发 A1 (金币×100)
	StepEngine.add_mock_steps(1000)
	AchievementSystem._check_step_achievements()

	var gold_after := CurrencyManager.get_gold() if CurrencyManager else 0
	_pass("A1 已解锁") if AchievementSystem.is_unlocked("A1") else _fail("A1 未解锁")
	_pass("A1 金币奖励已发放") if gold_after >= gold_before + 100 else _fail("A1 金币未发放", "before=%d after=%d" % [gold_before, gold_after])


# ── 持久化 ──
func test_save_roundtrip() -> void:
	print("\n--- 持久化 roundtrip ---")
	StepEngine.apply_save({})
	AchievementSystem.reset_all()
	StepEngine.apply_save({})

	# 解锁几个成就
	StepEngine.add_mock_steps(2000)
	AchievementSystem._check_step_achievements()
	for _i in range(10):
		AchievementSystem._on_hatch_complete(null)
	AchievementSystem._on_level_up("cat_1", 2, 3)

	var data: Dictionary = AchievementSystem.get_save_data()
	_pass("save有unlocked") if data.has("unlocked") else _fail("save缺unlocked")
	_pass("save有hatch_count") if data.has("hatch_count") else _fail("save缺hatch_count")
	_pass("save有total_steps") if data.has("total_steps") else _fail("save缺total_steps")

	# 重置后恢复
	AchievementSystem.reset_all()
	StepEngine.apply_save({})
	_pass("reset后A1未解锁") if not AchievementSystem.is_unlocked("A1") else _fail("reset后A1仍解锁")

	AchievementSystem.apply_save(data)
	_pass("恢复后A1已解锁") if AchievementSystem.is_unlocked("A1") else _fail("恢复后A1未解锁")
	_pass("恢复后B2已解锁") if AchievementSystem.is_unlocked("B2") else _fail("恢复后B2未解锁")
	_pass("恢复后C1已解锁") if AchievementSystem.is_unlocked("C1") else _fail("恢复后C1未解锁")


# ── 防重复 ──
func test_no_duplicate_unlock() -> void:
	print("\n--- 防重复解锁 ---")
	StepEngine.apply_save({})
	AchievementSystem.reset_all()
	CurrencyManager.apply_save({})

	StepEngine.add_mock_steps(1000)
	AchievementSystem._check_step_achievements()
	_pass("首次A1已解锁") if AchievementSystem.is_unlocked("A1") else _fail("首次A1未解锁")
	var gold_first := CurrencyManager.get_gold() if CurrencyManager else 0

	# 再次触发步数检查，不应再次解锁或发放奖励
	AchievementSystem._check_step_achievements()
	var gold_second := CurrencyManager.get_gold() if CurrencyManager else 0
	_pass("重复检查A1仍解锁") if AchievementSystem.is_unlocked("A1") else _fail("重复检查A1已消失")
	_pass("重复检查金币未重复发放") if gold_second == gold_first else _fail("金币重复发放", "first=%d second=%d" % [gold_first, gold_second])
