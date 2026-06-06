extends Node

var passed := 0
var failed := 0
var results: Array[String] = []

func _ready() -> void:
	print("========================================")
	print("  T3-1 自动化测试")
	print("========================================")

	test_step_engine()
	test_energy_formula()
	test_energy_pool_overflow()
	test_hatch_serial()
	test_save_roundtrip()
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

# ────────────────────────────────────────────
# 1. StepEngine
# ────────────────────────────────────────────
func test_step_engine() -> void:
	print("\n--- StepEngine ---")
	# 清空状态
	StepEngine.apply_save({})
	assert_eq("初始步数=0", 0, StepEngine.get_today_steps())

	StepEngine.add_mock_steps(1000)
	assert_eq("+1000步", 1000, StepEngine.get_today_steps())

	StepEngine.add_mock_steps(500)
	assert_eq("再+500步=1500", 1500, StepEngine.get_today_steps())

	var data := StepEngine.get_save_data()
	assert_eq("save有today_steps", 1500, int(data.get("today_steps", -1)))

	StepEngine.apply_save({"today_steps": 3000, "total_steps": 5000, "last_plugin_steps": 0, "last_step_date": StepEngine._today_key()})
	assert_eq("apply_save恢复", 3000, StepEngine.get_today_steps())

# ────────────────────────────────────────────
# 2. 能量公式
# ────────────────────────────────────────────
func test_energy_formula() -> void:
	print("\n--- EnergyEngine 公式 ---")
	var e0 := EnergyEngine.calc_energy(0, true)
	assert_eq("0步=0能量", 0, e0)

	var e1k := EnergyEngine.calc_energy(1000, true)
	assert_eq("1000步 新手=800", 800, e1k)

	var e3k := EnergyEngine.calc_energy(3000, true)
	assert_eq("3000步 新手=2800", 2800, e3k)

	var e5k := EnergyEngine.calc_energy(5000, true)
	assert_eq("5000步 新手=5200", 5200, e5k)

	var e1k_vet := EnergyEngine.calc_energy(1000, false)
	assert_eq("1000步 非新手=300", 300, e1k_vet)

# ────────────────────────────────────────────
# 3. 能量池溢出 → 备用槽
# ────────────────────────────────────────────
func test_energy_pool_overflow() -> void:
	print("\n--- 能量池溢出 ---")
	EnergyEngine.apply_save({})
	assert_eq("初始池=0", 0.0, EnergyEngine.energy_pool)
	assert_eq("初始备用=0", 0.0, EnergyEngine.reserve_tank)

	# 模拟大量步数，应填满主池+备用槽
	StepEngine.add_mock_steps(50000)
	var produced := EnergyEngine.total_energy_produced
	assert_gt("总产能>0", produced, 0.0)
	assert_eq("主池满", EnergyEngine.MAX_ENERGY_POOL, EnergyEngine.energy_pool)
	assert_eq("备用槽满", EnergyEngine.MAX_RESERVE_TANK, EnergyEngine.reserve_tank)

# ────────────────────────────────────────────
# 4. 串行孵化
# ────────────────────────────────────────────
func test_hatch_serial() -> void:
	print("\n--- HatchEngine 串行孵化 ---")
	# 重置
	HatchEngine.apply_save({"slots": [], "cats": [], "hatched_count": 0})
	HatchEngine._ensure_slots()
	HatchEngine._update_unlocks()
	HatchEngine._assign_next_empty_slots()

	var slots := HatchEngine.get_slots()
	# 初始只有 slot[0] 在填充
	assert_eq("初始 slot0=filling", "filling", String(slots[0].get("status", "")))
	assert_eq("初始 slot1=empty(未解锁)", "locked", String(slots[1].get("status", "")))

	# 喂刚好一个橘猫的孵化门槛 4250 能量
	HatchEngine.feed_energy(4250.0)
	print("  DEBUG after feed 4250: cats=%d, hatched=%d" % [HatchEngine.get_cats().size(), HatchEngine.hatched_count])
	for si in range(4):
		var s = HatchEngine.get_slots()[si]
		print("  DEBUG   slot%d: status=%s species=%s energy=%.0f/%.0f" % [si, str(s.get("status")), str(s.get("species")), float(s.get("energy", 0)), float(s.get("max_energy", 0))])
	var cats := HatchEngine.get_cats()
	assert_eq("孵出1只猫", 1, cats.size())
	if cats.size() > 0:
		assert_eq("第一只是橘猫", CatData.BREED_ORANGE, String(cats[0].species))

	# 继续喂 15000 能量 → 第二个槽应该孵化（英短门槛）
	HatchEngine.feed_energy(15000.0)
	print("  DEBUG after feed 15000: cats=%d, hatched=%d" % [HatchEngine.get_cats().size(), HatchEngine.hatched_count])
	for si in range(4):
		var s = HatchEngine.get_slots()[si]
		print("  DEBUG   slot%d: status=%s species=%s energy=%.0f/%.0f" % [si, str(s.get("status")), str(s.get("species")), float(s.get("energy", 0)), float(s.get("max_energy", 0))])
	cats = HatchEngine.get_cats()
	assert_gt("孵出>=2只", cats.size(), 1)
	if cats.size() >= 2:
		# 第二只可能是橘猫或英短（取决于roll）
		var s2 := String(cats[1].species)
		assert_eq("第二只品种合法", true, s2 == CatData.BREED_ORANGE or s2 == CatData.BREED_BRITISH)

	# 继续喂大量能量
	HatchEngine.feed_energy(50000.0)
	cats = HatchEngine.get_cats()
	assert_gt("孵出>=3只", cats.size(), 2)

# ────────────────────────────────────────────
# 5. 存档往返
# ────────────────────────────────────────────
func test_save_roundtrip() -> void:
	print("\n--- SaveManager 往返 ---")
	SaveManager.reset_all()

	StepEngine.add_mock_steps(2000)
	# 触发存档（add_mock_steps 已通过 energy_changed 自动存档）
	SaveManager.save_all()

	# 手动清空引擎状态（不触发存档）
	StepEngine.today_steps = 0
	StepEngine.total_steps = 0
	EnergyEngine.energy_pool = 0.0
	EnergyEngine.reserve_tank = 0.0

	# 从磁盘恢复
	SaveManager.load_and_apply()
	assert_eq("恢复后步数", 2000, StepEngine.get_today_steps())

# ────────────────────────────────────────────
# 6. 新手保护天数
# ────────────────────────────────────────────
func test_newbie_protection() -> void:
	print("\n--- 新手保护 ---")
	EnergyEngine.apply_save({})
	assert_eq("初始是新玩家", true, EnergyEngine.is_new_player())
	var remaining := EnergyEngine.newbie_protection_remaining_days()
	assert_gt("剩余天数>0", remaining, 0)
	assert_eq("剩余天数<=7", true, remaining <= 7)
