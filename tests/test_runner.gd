extends Node

var passed := 0
var failed := 0
var results: Array[String] = []

func _ready() -> void:
	print("========================================")
	print("  T3-1 完整自动化测试")
	print("========================================")

	test_step_engine()
	test_step_edge_cases()
	test_energy_formula()
	test_energy_incremental()
	test_energy_pool_overflow()
	test_energy_overflow_waste()
	test_hatch_serial()
	test_hatch_slot_unlock()
	test_hatch_species_unlock()
	test_rarity_distribution()
	test_save_roundtrip()
	test_save_empty()
	test_newbie_protection()

	print("\n========================================")
	print("  结果: %d 通过 / %d 失败" % [passed, failed])
	for line in results:
		print(line)
	print("========================================")

func assert_eq(what: String, expected, actual) -> void:
	if expected == actual:
		passed += 1
		results.append("  ✅ %s" % what)
	else:
		failed += 1
		results.append("  ❌ %s: 期望=%s 实际=%s" % [what, str(expected), str(actual)])

func assert_gt(what: String, actual, threshold) -> void:
	if actual > threshold:
		passed += 1
		results.append("  ✅ %s" % what)
	else:
		failed += 1
		results.append("  ❌ %s: %s <= %s" % [what, str(actual), str(threshold)])

func assert_ge(what: String, actual, threshold) -> void:
	if actual >= threshold:
		passed += 1
		results.append("  ✅ %s" % what)
	else:
		failed += 1
		results.append("  ❌ %s: %s < %s" % [what, str(actual), str(threshold)])

func assert_between(what: String, actual, lo, hi) -> void:
	if actual >= lo and actual <= hi:
		passed += 1
		results.append("  ✅ %s" % what)
	else:
		failed += 1
		results.append("  ❌ %s: %s 不在 [%s, %s]" % [what, str(actual), str(lo), str(hi)])

# ═══════════════════════════════════════════════
# 1. StepEngine 基本操作
# ═══════════════════════════════════════════════
func test_step_engine() -> void:
	print("\n--- StepEngine 基本 ---")
	StepEngine.apply_save({})
	assert_eq("初始步数=0", 0, StepEngine.get_today_steps())
	assert_eq("初始总步数=0", 0, StepEngine.get_total_steps())

	StepEngine.add_mock_steps(1000)
	assert_eq("+1000步", 1000, StepEngine.get_today_steps())
	assert_eq("总步数=1000", 1000, StepEngine.get_total_steps())

	StepEngine.add_mock_steps(500)
	assert_eq("再+500步=1500", 1500, StepEngine.get_today_steps())
	assert_eq("总步数=1500", 1500, StepEngine.get_total_steps())

	var data: Dictionary = StepEngine.get_save_data()
	assert_eq("save有today_steps", 1500, int(data.get("today_steps", -1)))

	StepEngine.apply_save({"today_steps": 3000, "total_steps": 5000, "last_plugin_steps": 0, "last_step_date": StepEngine._today_key()})
	assert_eq("apply_save恢复步数", 3000, StepEngine.get_today_steps())
	assert_eq("apply_save恢复总步数", 5000, StepEngine.get_total_steps())

# ═══════════════════════════════════════════════
# 2. StepEngine 边界
# ═══════════════════════════════════════════════
func test_step_edge_cases() -> void:
	print("\n--- StepEngine 边界 ---")
	StepEngine.apply_save({})

	StepEngine.add_mock_steps(0)
	assert_eq("+0步不变", 0, StepEngine.get_today_steps())

	StepEngine.add_mock_steps(-100)
	assert_eq("负步数忽略", 0, StepEngine.get_today_steps())

	StepEngine.add_mock_steps(999999)
	assert_eq("大数值步数", 999999, StepEngine.get_today_steps())

# ═══════════════════════════════════════════════
# 3. 能量公式
# ═══════════════════════════════════════════════
func test_energy_formula() -> void:
	print("\n--- EnergyEngine 公式 ---")
	assert_eq("0步=0能量", 0, EnergyEngine.calc_energy(0, true))
	assert_eq("0步 非新手=0", 0, EnergyEngine.calc_energy(0, false))
	assert_eq("1000步 新手=800", 800, EnergyEngine.calc_energy(1000, true))
	assert_eq("1000步 非新手=300", 300, EnergyEngine.calc_energy(1000, false))
	assert_eq("3000步 新手=2800", 2800, EnergyEngine.calc_energy(3000, true))
	assert_eq("5000步 新手=5200", 5200, EnergyEngine.calc_energy(5000, true))
	assert_eq("6000步 新手=6700", 6700, EnergyEngine.calc_energy(6000, true))

# ═══════════════════════════════════════════════
# 4. 增量能量
# ═══════════════════════════════════════════════
func test_energy_incremental() -> void:
	print("\n--- EnergyEngine 增量 ---")
	EnergyEngine.apply_save({})

	var r1 := EnergyEngine.process_steps(1000)
	assert_eq("首次1000步产能", 800.0, r1)
	assert_eq("累计能量=800", 800.0, EnergyEngine.today_energy)

	var r2 := EnergyEngine.process_steps(1000)
	assert_eq("二次1000步产能", 1000.0, r2)

	var r3 := EnergyEngine.process_steps(0)
	assert_eq("零步产能=0", 0.0, r3)

# ═══════════════════════════════════════════════
# 5. 能量池溢出
# ═══════════════════════════════════════════════
func test_energy_pool_overflow() -> void:
	print("\n--- 能量池溢出 ---")
	EnergyEngine.apply_save({})
	StepEngine.apply_save({})
	assert_eq("初始池=0", 0.0, EnergyEngine.energy_pool)
	assert_eq("初始备用=0", 0.0, EnergyEngine.reserve_tank)

	StepEngine.add_mock_steps(50000)
	assert_gt("总产能>0", EnergyEngine.total_energy_produced, 0.0)
	assert_eq("主池满 15000", EnergyEngine.MAX_ENERGY_POOL, EnergyEngine.energy_pool)
	assert_eq("备用槽满 6000", EnergyEngine.MAX_RESERVE_TANK, EnergyEngine.reserve_tank)

# ═══════════════════════════════════════════════
# 6. 溢出浪费
# ═══════════════════════════════════════════════
func test_energy_overflow_waste() -> void:
	print("\n--- 溢出浪费 ---")
	EnergyEngine.apply_save({})
	StepEngine.apply_save({})

	# 灌满池+备用后再加步数，多余能量丢弃
	StepEngine.add_mock_steps(100000)
	assert_eq("再灌仍满池", EnergyEngine.MAX_ENERGY_POOL, EnergyEngine.energy_pool)
	assert_eq("再灌仍满备用", EnergyEngine.MAX_RESERVE_TANK, EnergyEngine.reserve_tank)

# ═══════════════════════════════════════════════
# 7. 串行孵化
# ═══════════════════════════════════════════════
func test_hatch_serial() -> void:
	print("\n--- HatchEngine 串行孵化 ---")
	HatchEngine.apply_save({"slots": [], "cats": [], "hatched_count": 0})
	HatchEngine._ensure_slots()
	HatchEngine._update_unlocks()
	HatchEngine._assign_next_empty_slots()

	var slots := HatchEngine.get_slots()
	assert_eq("初始 slot0=filling", "filling", String(slots[0].get("status", "")))
	assert_eq("初始 slot1=locked", "locked", String(slots[1].get("status", "")))

	HatchEngine.feed_energy(4250.0)
	var cats := HatchEngine.get_cats()
	assert_eq("喂4250→1只猫", 1, cats.size())
	assert_eq("第一只橘猫", CatData.BREED_ORANGE, String(cats[0].species))

	HatchEngine.feed_energy(15000.0)
	cats = HatchEngine.get_cats()
	assert_gt("再喂15000→>=2只", cats.size(), 1)

	HatchEngine.feed_energy(50000.0)
	cats = HatchEngine.get_cats()
	assert_gt("再喂50000→>=3只", cats.size(), 2)

# ═══════════════════════════════════════════════
# 8. 槽位解锁顺序
# ═══════════════════════════════════════════════
func test_hatch_slot_unlock() -> void:
	print("\n--- 槽位解锁顺序 ---")
	HatchEngine.apply_save({"slots": [], "cats": [], "hatched_count": 0})
	HatchEngine._ensure_slots()
	HatchEngine._update_unlocks()
	HatchEngine._assign_next_empty_slots()

	var s := HatchEngine.get_slots()
	assert_eq("0猫时 slot0解锁", true, bool(s[0].get("unlocked", false)))
	assert_eq("0猫时 slot1锁定", false, bool(s[1].get("unlocked", false)))
	assert_eq("0猫时 slot2锁定", false, bool(s[2].get("unlocked", false)))
	assert_eq("0猫时 slot3锁定", false, bool(s[3].get("unlocked", false)))

	# 孵1只 → slot1解锁
	HatchEngine.feed_energy(5000.0)
	s = HatchEngine.get_slots()
	assert_eq("1猫后 slot1解锁", true, bool(s[1].get("unlocked", false)))
	assert_eq("1猫后 slot2仍锁定", false, bool(s[2].get("unlocked", false)))

	# 孵到3只 → slot2解锁
	HatchEngine.feed_energy(50000.0)
	s = HatchEngine.get_slots()
	if HatchEngine.hatched_count >= 3:
		assert_eq("3猫后 slot2解锁", true, bool(s[2].get("unlocked", false)))

# ═══════════════════════════════════════════════
# 9. 品种解锁（能量门槛）
# ═══════════════════════════════════════════════
func test_hatch_species_unlock() -> void:
	print("\n--- 品种解锁 ---")
	EnergyEngine.apply_save({})
	StepEngine.apply_save({})

	# <15000 能量 → 只有橘猫
	StepEngine.add_mock_steps(1000)
	var sp := HatchEngine.get_unlocked_species()
	assert_eq("<15k只有橘猫", 1, sp.size())

	# >=15000 → +英短
	StepEngine.add_mock_steps(20000)
	sp = HatchEngine.get_unlocked_species()
	assert_eq(">=15k有橘猫+英短", 2, sp.size())

	# >=30000 → +暹罗
	StepEngine.add_mock_steps(20000)
	sp = HatchEngine.get_unlocked_species()
	assert_eq(">=30k有3品种", 3, sp.size())

# ═══════════════════════════════════════════════
# 10. 稀有度分布
# ═══════════════════════════════════════════════
func test_rarity_distribution() -> void:
	print("\n--- 稀有度分布（1000次） ---")
	var counts := {CatData.RARITY_COMMON: 0, CatData.RARITY_RARE: 0, CatData.RARITY_EPIC: 0, CatData.RARITY_LEGENDARY: 0}

	HatchEngine.apply_save({"slots": [], "cats": [], "hatched_count": 0})
	HatchEngine._ensure_slots()
	HatchEngine._update_unlocks()
	HatchEngine._assign_next_empty_slots()

	# 喂入大量能量，统计稀有度
	for _i in range(200):
		HatchEngine.feed_energy(300000.0)

	var total := 0
	for k in counts.keys():
		for cat in HatchEngine.get_cats():
			if cat.rarity == k:
				counts[k] += 1
		total += counts[k]

	assert_gt("孵出足够样本", total, 0)

	if total > 0:
		var cr := float(counts[CatData.RARITY_COMMON]) / float(total) * 100.0
		var rr := float(counts[CatData.RARITY_RARE]) / float(total) * 100.0
		var er := float(counts[CatData.RARITY_EPIC]) / float(total) * 100.0
		var lr := float(counts[CatData.RARITY_LEGENDARY]) / float(total) * 100.0
		print("  分布: common=%.1f%% rare=%.1f%% epic=%.1f%% leg=%.1f%% (n=%d)" % [cr, rr, er, lr, total])
		assert_between("common≈68%", cr, 55.0, 80.0)
		assert_between("rare≈24%", rr, 12.0, 35.0)
		assert_between("epic≈7%", er, 0.0, 20.0)
		assert_between("leg≈1%", lr, 0.0, 8.0)

# ═══════════════════════════════════════════════
# 11. 存档往返
# ═══════════════════════════════════════════════
func test_save_roundtrip() -> void:
	print("\n--- SaveManager 往返 ---")
	SaveManager.reset_all()

	StepEngine.add_mock_steps(2000)
	SaveManager.save_all()

	StepEngine.today_steps = 0
	StepEngine.total_steps = 0
	EnergyEngine.energy_pool = 0.0
	EnergyEngine.reserve_tank = 0.0

	SaveManager.load_and_apply()
	assert_eq("恢复步数=2000", 2000, StepEngine.get_today_steps())

# ═══════════════════════════════════════════════
# 12. 空存档
# ═══════════════════════════════════════════════
func test_save_empty() -> void:
	print("\n--- 空存档 ---")
	SaveManager.reset_all()
	SaveManager.load_and_apply()

	assert_eq("空存档步数=0", 0, StepEngine.get_today_steps())
	assert_eq("空存档池=0", 0.0, EnergyEngine.energy_pool)
	assert_eq("空存档孵化为0", 0, HatchEngine.get_cats().size())

# ═══════════════════════════════════════════════
# 13. 新手保护
# ═══════════════════════════════════════════════
func test_newbie_protection() -> void:
	print("\n--- 新手保护 ---")
	EnergyEngine.apply_save({})
	assert_eq("初始是新玩家", true, EnergyEngine.is_new_player())
	var remaining := EnergyEngine.newbie_protection_remaining_days()
	assert_gt("剩余天数>0", remaining, 0)
	assert_eq("剩余天数<=7", true, remaining <= 7)
