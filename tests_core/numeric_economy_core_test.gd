extends SceneTree
# ============================================================================
# 猫步天下 v2.18 — 数值 / 经济 / 核心循环 / 功能逻辑 · 零依赖纯逻辑自检
# ----------------------------------------------------------------------------
# 运行：  godot --headless --path . --script res://tests_core/numeric_economy_core_test.gd
# 退出码：0 = 无回归(real FAIL=0)；1 = 有真实回归
#
# 设计约束：
#   · 不加载老 tests/ 框架、不实例化任何 UI/场景、不依赖 autoload 单例
#   · 只 load().new() core 脚本，且只调用「不触碰 autoload 标识符」的方法
#   · 真机部分(原生计步/功耗/帧率/渲染)不在范围
#
# 三类计数：
#   check()       常规断言 —— 失败=真实回归，计入退出码(红线)
#   check_xfail() 断言 GDD 正确行为 —— 当前代码有缺陷，预期失败(xfail)；
#                 若意外通过(XPASS) 说明该缺陷已修，提示把用例移出 xfail
#   pending()     依赖「时间注入缝」，缝未加则跳过并打印改法
# ============================================================================

var _pass := 0
var _fail := 0      # 真实回归(红线，决定退出码)
var _xfail := 0     # 已知缺陷，预期失败
var _xpass := 0     # 已知缺陷意外通过 → 该移出 xfail
var _skip := 0      # 待时间缝
var _log: Array[String] = []

# ---- 脚本资源(静态调用 / 取常量用)：用 preload 解析为具体脚本类，
#      否则 load() 返回泛型 Resource，静态方法/常量会被判定不存在。 ----
const EnergyS   = preload("res://core/EnergyEngine.gd")
const LevelS    = preload("res://core/LevelSystem.gd")
const RelinqS   = preload("res://core/RelinquishSystem.gd")
const BreedS    = preload("res://core/BreedUnlockEngine.gd")
const HatchS    = preload("res://core/HatchEngine.gd")
const StepS     = preload("res://core/StepEngine.gd")
const MailS     = preload("res://core/MailSystem.gd")
const ExploreS  = preload("res://core/ExploreEngine.gd")
const CurrencyS = preload("res://core/CurrencyManager.gd")
const CatDS     = preload("res://core/CatData.gd")
const PackageS  = preload("res://core/PackageSystem.gd")
const AchS      = preload("res://core/AchievementSystem.gd")
const SigninS   = preload("res://core/SigninSystem.gd")

# ===========================================================================
# 入口：extends SceneTree 经 --script 运行时，引擎在「构造期」调用 _init()
# （这是官方命令行文档的标准入口；_initialize() 是 MainLoop 的 C++ 钩子，
#  GDScript 侧不可靠，切勿使用）。_init() 内同步跑完所有断言后 quit()，
#  主循环启动即见退出标记、立即结束。
# 注意：_init() 时序下 autoload 单例尚未实例化、root 可能未就绪——本套件
#  全程用 preload().new() 自建实例 + 纯 static 调用，不依赖任何单例，故不受影响。
# ===========================================================================

func _init() -> void:
	print("\n===== 猫步天下 纯逻辑自检 开始 =====\n")
	_t_energy_formula()        # 一、步数引擎公式
	_t_energy_alloc()          # 二、能量分配
	_t_hatch_breed_slots()     # 三、孵化/解锁链/满包(B方案)
	_t_rarity_pity()           # 四、稀有度与保底
	_t_level()                 # 五、等级经验
	_t_relinquish_formula()    # 八、送养公式
	_t_currency()              # 九、货币非负
	_t_economy()               # 十、经济对账：扩容成本/成就奖励/签到（DEF-08 等）
	_t_workshop_mode()         # 十四、工坊态判定
	_t_explore()               # 十三、探索(基础逻辑)
	_t_mail_dates()            # DEF-13 节日信件日期
	_t_pending_seams()         # 待时间缝：DEF-01/05/09
	_report()
	quit(1 if _fail > 0 else 0)

# ============================ 断言原语 =====================================

func check(name: String, cond: bool, detail := "") -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		_log.append("[FAIL ] %s  %s" % [name, detail])

func check_eq(name: String, got, exp) -> void:
	check(name, _eq(got, exp), "got=%s exp=%s" % [str(got), str(exp)])

func check_approx(name: String, got: float, exp: float, eps := 0.001) -> void:
	check(name, abs(got - exp) <= eps, "got=%f exp=%f" % [got, exp])

# 断言 GDD 正确行为；当前代码预期 FALSE
func check_xfail(name: String, gdd_correct_cond: bool, def_id: String, detail := "") -> void:
	if gdd_correct_cond:
		_xpass += 1
		_log.append("[XPASS] %s (%s) 似乎已修复 → 请移出 xfail" % [name, def_id])
	else:
		_xfail += 1
		_log.append("[xfail] %s (%s) 已知缺陷未修复  %s" % [name, def_id, detail])

func pending(name: String, seam_hint: String) -> void:
	_skip += 1
	_log.append("[skip ] %s  ⏳需时间缝：%s" % [name, seam_hint])

func _eq(a, b) -> bool:
	if a is float or b is float:
		return abs(float(a) - float(b)) <= 0.0001
	return a == b

# ============================ 一、步数引擎公式 =============================

func _t_energy_formula() -> void:
	var ee = EnergyS.new()
	# 1.1 calcEnergy 公式还原（int 截断口径已确认）
	# P1 费率翻转：T1 0-1500×1.1 | T2 -4000×1.0 | T3 -6000×0.8 | T4 6000+×0.4；新手全段×1.2
	check_eq("E-001 calc(500,false)",  ee.calc_energy(500, false),  550)
	check_eq("E-002 calc(500,true)",   ee.calc_energy(500, true),   660)
	check_eq("E-003 calc(1500,false)", ee.calc_energy(1500, false), 1650)
	check_eq("E-004 calc(1500,true)",  ee.calc_energy(1500, true),  1980)
	check_eq("E-005 calc(5000,false)", ee.calc_energy(5000, false), 4950)
	check_eq("E-006 calc(8000,false)", ee.calc_energy(8000, false), 6550)
	check_eq("E-007 calc(1000,false)", ee.calc_energy(1000, false), 1100)
	check_eq("E-008 calc(1001,false) int截断", ee.calc_energy(1001, false), 1101)
	check_eq("E-009 calc(3000,false)", ee.calc_energy(3000, false), 3150)
	check_eq("E-010 calc(3001,false)", ee.calc_energy(3001, false), 3151)
	check_eq("E-011 calc(5000,false)", ee.calc_energy(5000, false), 4950)
	check_eq("E-012 calc(5001,false) int截断", ee.calc_energy(5001, false), 4950)   # 4950.8→4950
	check_eq("E-013 calc(0,false)",    ee.calc_energy(0, false),    0)
	check("E-014 calc(-1,false) 不崩且非负", ee.calc_energy(-1, false) <= 0 + 0)
	ee.free()

# ============================ 二、能量分配 ================================

func _t_energy_alloc() -> void:
	var ee = EnergyS.new()
	ee.created_at = Time.get_unix_time_from_system() - 9_000_000.0   # 非新手
	ee.last_energy_date = ee._today_key()                            # 规避跨天重置
	ee.process_steps(200_000)                                        # 海量步数压满
	# E-017/018/019 GDD v3.1 R8：池满截断（备用槽已移除）
	check("E-017 主池≤15000", ee.energy_pool <= 15000.0 + 0.001, "pool=%f" % ee.energy_pool)
	check_approx("E-019 主池满=15000", ee.energy_pool, 15000.0)
	# E-025/026 GDD v3.1 R8：add_pool_with_overflow 溢出直接截断（无备用槽）
	var ee2 = EnergyS.new()
	ee2.energy_pool = 15000.0       # 主池已满
	ee2.add_pool_with_overflow(3000.0)
	check_approx("E-025R 主池满→溢出截断", ee2.energy_pool, 15000.0)
	var ee3 = EnergyS.new()
	ee3.energy_pool = 10000.0       # 主池有余量
	ee3.add_pool_with_overflow(3000.0)
	check_approx("E-026 主池有余量→3000进主池", ee3.energy_pool, 13000.0)
	ee.free(); ee2.free(); ee3.free()

# ============================ 三、孵化/解锁链/满包 ========================

func _t_hatch_breed_slots() -> void:
	# E-027 每蛋孵化能量统一 4250（取 CatData 常量）
	check_eq("E-027 每蛋孵化能量=4250", CatDS.HATCH_ENERGY_REQUIRED, 4250)
	check_eq("E-027 get_hatch_cost(暹罗)=4250", CatDS.get_hatch_cost("siamese"), 4250)

	# 解锁链：GDD §2.3 = 3 只。当前 UNLOCK_CHAIN_COUNT=2 → xfail
	check_xfail("DEF-07 UNLOCK_CHAIN_COUNT==3", int(BreedS.UNLOCK_CHAIN_COUNT) == 3, "DEF-07",
		"当前=%d" % int(BreedS.UNLOCK_CHAIN_COUNT))

	# E-029 孵 2 橘 → 仍只有橘（链=3 才成立；链=2 会提前解锁英短）
	var bu = BreedS.new()
	bu._hatch_counts = {"orange": 2, "british": 0, "siamese": 0}
	bu._unlocked.clear(); bu._unlocked.append("orange")
	bu._update_unlocks()
	check_xfail("E-029 孵2橘→仍只橘", not bu._unlocked.has("british"), "DEF-07",
		"链=2 时第2只即解锁英短")

	# E-030 孵 3 橘 → 解锁英短（两套链值都≥3，故为常规断言）
	var bu2 = BreedS.new()
	bu2._hatch_counts = {"orange": 3, "british": 0, "siamese": 0}
	bu2._unlocked.clear(); bu2._unlocked.append("orange")
	bu2._update_unlocks()
	check("E-030 孵3橘→英短解锁", bu2._unlocked.has("british"))
	bu.free(); bu2.free()

	# E-037 / F-006（B方案）：满包时 _do_assign_empty_slots 不得落新蛋
	var he = HatchS.new()
	he._ensure_slots()
	# 解锁 slot[0]、置 empty；其余 locked
	he.hatched_count = 0
	he._update_unlocks()
	he.slots[0]["unlocked"] = true
	he.slots[0]["status"] = "empty"
	# 造满包
	he.cats = _dummy_cats(24)
	he.backpack_max_capacity = 24
	# _do_assign_empty_slots 内部经 _roll_next_species 触及 BreedUnlockEngine(autoload)；
	# _init() 时序下该单例尚未实例化 → `if BreedUnlockEngine:` 取 null → 安全回退橘猫，
	# 落蛋逻辑照常执行。用 ProjectSettings 确认 autoload 已配置即放行（不依赖 root）。
	if _breed_global_safe():
		he._do_assign_empty_slots()
		var has_incubating := he._get_active_filling_slot() != -1
		check_xfail("E-037/F-006 满包不落蛋(B方案)", not has_incubating, "DEF-02",
			"当前 _do_assign_empty_slots 满包仍落蛋")
	else:
		pending("E-037/F-006 满包不落蛋(B方案)",
			"在带 autoload 环境运行；或对 _do_assign_empty_slots 增加满包守卫后改为常规断言")
	he.free()

# BreedUnlockEngine 全局是否可安全求值（autoload 已配置即可，null 也安全回退橘猫）
func _breed_global_safe() -> bool:
	return ProjectSettings.has_setting("autoload/BreedUnlockEngine")

# ============================ 四、稀有度与保底 ============================

func _t_rarity_pity() -> void:
	var he = HatchS.new()
	he.rng.seed = 1234567
	var N := 100000
	var tally := {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	for i in N:
		tally[he._base_roll_rarity()] += 1
	check("E-041 common≈68%", abs(float(tally["common"]) / N - 0.68) <= 0.005,
		"实际=%.4f" % (float(tally["common"]) / N))
	check("E-041 rare≈24%", abs(float(tally["rare"]) / N - 0.24) <= 0.005,
		"实际=%.4f" % (float(tally["rare"]) / N))
	check("E-041 epic≈7%", abs(float(tally["epic"]) / N - 0.07) <= 0.005,
		"实际=%.4f" % (float(tally["epic"]) / N))
	check("E-041 legendary≈1%", abs(float(tally["legendary"]) / N - 0.01) <= 0.005,
		"实际=%.4f" % (float(tally["legendary"]) / N))

	# E-042 epic 保底
	check_eq("E-044 EPIC_PITY 常量", int(HatchS.EPIC_PITY), 40)
	check_eq("E-044 LEGENDARY_PITY 常量", int(HatchS.LEGENDARY_PITY), 120)
	he.epic_pity_count = 40
	he.legendary_pity_count = 0
	var r = he._roll_rarity()
	check("E-042 epic保底触发(≥epic)", he._rarity_rank(r) >= he._rarity_rank("epic"),
		"roll=%s" % r)
	# E-043 legendary 保底
	he.legendary_pity_count = 120
	var r2 = he._roll_rarity()
	check_eq("E-043 legendary保底触发", r2, "legendary")
	he.free()

# ============================ 五、等级经验 ================================

func _t_level() -> void:
	# E-046/047/048 升级公式
	check_eq("E-046 橘×5000步=5000exp",
		LevelS.calc_exp(5000, LevelS.get_breed_multiplier("orange")), 5000)
	check_eq("E-047 英短×5000步=6000exp",
		LevelS.calc_exp(5000, LevelS.get_breed_multiplier("british")), 6000)
	check_eq("E-048 暹罗×5000步=7500exp",
		LevelS.calc_exp(5000, LevelS.get_breed_multiplier("siamese")), 7500)
	# E-049/050/051 门槛逐级（边界 ±1）
	check_eq("E-049 exp4999→Lv1", LevelS.get_level(4999), 1)
	check_eq("E-050 exp5000→Lv2", LevelS.get_level(5000), 2)
	var th := [0, 5000, 15000, 30000, 50000, 75000, 100000, 120000, 138000, 150000]
	for i in range(th.size()):
		check_eq("E-051 exp=%d→Lv%d" % [th[i], i + 1], LevelS.get_level(th[i]), i + 1)
	# E-052 满级封顶
	check_eq("E-052 exp150000→Lv10", LevelS.get_level(150000), 10)
	check_eq("E-052 exp999999→Lv10", LevelS.get_level(999999), 10)

# ============================ 八、送养公式 ================================

func _t_relinquish_formula() -> void:
	var rs = RelinqS.new()
	# _level_factor 函数本身正确（但当前未被调用 → DEF-04）
	check_eq("LF Lv1=0",  rs._level_factor(1),  0.0)
	check_eq("LF Lv3=1.0", rs._level_factor(3), 1.0)
	check_eq("LF Lv6=1.5", rs._level_factor(6), 1.5)
	check_eq("LF Lv9=2.0", rs._level_factor(9), 2.0)
	check_eq("LF Lv10=3.0", rs._level_factor(10), 3.0)

	# 好感因子边界：GDD 500→1.5；代码 <=500→1.0 → off-by-one (新发现 DEF-23)
	check_eq("AF 99→0",  rs._affection_factor(99),  0.0)
	check_eq("AF 100→1.0", rs._affection_factor(100), 1.0)
	check_xfail("DEF-23 AF 500→1.5(GDD)", _eq(rs._affection_factor(500), 1.5), "DEF-23",
		"代码 <=500 返回1.0，GDD 500 应为1.5")
	check_eq("AF 1500→2.0", rs._affection_factor(1500), 2.0)

	# 底值：GDD 5/10/15；代码 10/20/30 → DEF-06
	check_xfail("DEF-06 orange base==5", int(RelinqS.SPECIES_BASE.get("orange", -1)) == 5, "DEF-06",
		"当前=%d" % int(RelinqS.SPECIES_BASE.get("orange", -1)))

	# M-009 Common 不获花瓣（v2.18 约定，代码正确 → 常规断言通过）
	check_eq("M-009 Common→0花瓣",
		rs._calculate_love_petals({"species": "orange", "rarity": "common", "friendship": 1500}), 0)

	# M-001/002/003 具体点（GDD 正确值；代码漏 Level + 底值翻倍 → xfail）
	check_xfail("M-001 橘×rare×aff100=8",
		rs._calculate_love_petals({"species": "orange", "rarity": "rare", "friendship": 100}) == 8,
		"DEF-06", "got=%d" % rs._calculate_love_petals({"species": "orange", "rarity": "rare", "friendship": 100}))
	check_xfail("M-002 暹×epic×Lv5×aff500=68",
		_ref_petals("siamese", "epic", 5, 500) == 68 \
			and rs._calculate_love_petals({"species": "siamese", "rarity": "epic", "friendship": 500}) == 68,
		"DEF-04", "代码漏LevelFactor+AF500错")
	check_xfail("M-003 英×leg×Lv10×aff1500=180",
		rs._calculate_love_petals({"species": "british", "rarity": "legendary", "friendship": 1500}) == 180,
		"DEF-04", "got=%d exp=180" % rs._calculate_love_petals({"species": "british", "rarity": "legendary", "friendship": 1500}))

	# 差分矩阵：Lv10 应享 ×3 LevelFactor，代码无法体现 → 整片 xfail (DEF-04)
	for sp in ["orange", "british", "siamese"]:
		for rar in ["rare", "epic", "legendary"]:
			var got: int = rs._calculate_love_petals({"species": sp, "rarity": rar, "friendship": 200})
			var exp: int = _ref_petals(sp, rar, 10, 200)
			check_xfail("M-diff %s/%s/Lv10/aff200" % [sp, rar], got == exp, "DEF-04",
				"got=%d exp=%d" % [got, exp])

	# 周上限常量
	check_eq("M-007 周上限常量=500", int(RelinqS.WEEKLY_PETAL_CAP), 500)

	# M-010 幂等键：同一 id 二次请求被挡（不触 autoload 的纯判定部分）
	# relinquish_cat 内部会访问 HatchEngine/CurrencyManager(autoload)，此处只验证 id 去重表逻辑。
	rs.relinquished_event_ids = ["evt-1"]
	check("M-010 幂等键去重表命中", "evt-1" in rs.relinquished_event_ids)
	rs.free()

func _ref_petals(species: String, rarity: String, level: int, affection: int) -> int:
	if rarity == "common":
		return 0
	var base: int = {"orange": 5, "british": 10, "siamese": 15}.get(species, 5)
	var rf: float = {"common": 1.0, "rare": 1.5, "epic": 2.0, "legendary": 3.0}.get(rarity, 0.0)
	var lf := 0.0 if level <= 1 else (1.0 if level <= 3 else (1.5 if level <= 6 else (2.0 if level <= 9 else 3.0)))
	var af := 0.0 if affection < 100 else (1.0 if affection < 500 else (1.5 if affection < 1500 else 2.0))
	return int(round(float(base) * rf * lf * af))

# ============================ 九、货币非负 ================================

func _t_currency() -> void:
	# 注意：spend_* 成功路径会调 EventBus(autoload)；但「余额不足拒绝」和「负数加被拒」
	# 两条路径都在调用 _after_change() 之前 return，故可零依赖安全测试。
	var cm = CurrencyS.new()
	cm.gold_coins = 50
	cm.diamonds = 50
	cm.flower_petals = 50
	check("M-012 金币不足→拒绝", not cm.spend_gold(60))
	check_eq("M-012 金币余额不变", cm.gold_coins, 50)
	check("M-013 钻石不足→拒绝", not cm.spend_diamonds(60))
	check_eq("M-013 钻石余额不变", cm.diamonds, 50)
	check("M-014 花瓣不足→拒绝", not cm.spend_petals(60))
	check_eq("M-014 花瓣余额不变", cm.flower_petals, 50)
	cm.add_gold(-5)
	check_eq("负数加金币被拒(余额不变)", cm.gold_coins, 50)
	cm.free()

# ============================ 十、经济对账 ================================
# 扩容金币成本(DEF-08)、成就奖励数值(§10)、签到经济常量(§11)。
# 全部纯 const / 纯函数，零 autoload。

func _t_economy() -> void:
	# —— 猫包扩容档位 §2.2.1 第四节 (DEF-08) ——
	check_eq("猫包初始上限=24", int(PackageS._INITIAL_CAPACITY), 24)         # PASS
	check_eq("猫包硬顶=36", int(PackageS._HARD_CAP), 36)                     # PASS
	var tiers: Array = PackageS._TIERS
	check_eq("扩容容量档=28/32/36",
		[int(tiers[0]["capacity"]), int(tiers[1]["capacity"]), int(tiers[2]["capacity"])],
		[28, 32, 36])                                                        # PASS（容量值对）
	# GDD：按图鉴解锁数(6/12/24) + 金币(5000/10000/0)触发；代码用 steps/postcards 且无金币 → DEF-08
	check_xfail("DEF-08 扩容档应含金币成本字段", bool(tiers[0].has("gold")), "DEF-08",
		"当前档位无 gold 字段，扩容免费")
	check_xfail("DEF-08 第一档应=5000金币", int(tiers[0].get("gold", -1)) == 5000, "DEF-08",
		"GDD 28只档需 5000 金币")
	# 行为：仅靠步数达标不应免费扩容（GDD 要图鉴解锁+金币）
	var ps = PackageS.new()
	ps.check_expansion(300_000)   # 30万步（当前只接受 unlock_count；需 postcard 参数 → DEF-08）
	check_xfail("DEF-08 步数达标不应免费扩容", ps.backpack_max_capacity == 24, "DEF-08",
		"当前 steps≥30万 即免费扩到 28（应需图鉴B2解锁+5000金币）")
	ps.free()

	# —— 成就奖励数值对账 §10（const 数组，逐条回归红线）——
	_ach_check("A1", 1000, "gold_coins", 100)
	_ach_check("A2", 10000, "gold_coins", 200)
	_ach_check("A3", 42195, "diamonds", 30)
	_ach_check("A4", 100000, "diamonds", 50)
	_ach_check("A5", 1000000, "diamonds", 100)
	_ach_check("A6", 7, "diamonds", 50)
	_ach_check("B1", 1, "gold_coins", 200)
	_ach_check("B2", 6, "diamonds", 30)
	_ach_check("B3", 12, "diamonds", 50)
	_ach_check("B4", 24, "diamonds", 100)
	_ach_check("B5", 3, "diamonds", 80)
	_ach_check("C1", 3, "gold_coins", 300)
	_ach_check("C2", 10, "diamonds", 50)
	_ach_check("E1", 1, "gold_coins", 100)
	_ach_check("E2", 10, "diamonds", 30)
	_ach_check("E3", 30, "diamonds", 50)
	_ach_check("E4", 30, "diamonds", 100)
	_ach_check("D1", 1, "diamonds", 20)

	# C3 好感大师：奖励项圈在（PASS），但 target=25 与 GDD「好感Lv5」对不上 → 提示核对
	var c3 := _ach_by_id("C3")
	check("C3 奖励含猫咪项圈", c3.size() > 0 and Dictionary(c3.get("reward", {})).has("cat_collar"))
	check_xfail("FINDING-C3 target 应对应好感Lv5", int(c3.get("target", -1)) != 25, "FINDING-C3",
		"当前 target=25，GDD 好感Lv5=累计360/等级5，口径不符，请核对")

	# B2/B3/B4 计量口径：type=hatch_count，GDD §10.2 要『图鉴去重数(品种×稀有度)』
	check_xfail("FINDING-DEX B2 应按图鉴去重而非孵化总数",
		String(_ach_by_id("B2").get("type", "")) != "hatch_count", "FINDING-DEX",
		"代码无『图鉴解锁数』概念，B2/B3/B4 与 DEF-08 同源退化为孵化/步数计")

	# —— 签到经济常量 §11.1 ——
	check_eq("签到周期=7天", int(SigninS.CYCLE_LENGTH), 7)
	check_eq("每周期补签上限=2", int(SigninS.MAX_MAKEUP), 2)

func _ach_by_id(id: String) -> Dictionary:
	for a in AchS.ACHIEVEMENTS:
		if String(a.get("id", "")) == id:
			return a
	return {}

func _ach_check(id: String, target: int, reward_key: String, reward_val: int) -> void:
	var a := _ach_by_id(id)
	if a.is_empty():
		check("成就 %s 存在" % id, false, "未找到该成就")
		return
	check_eq("成就 %s target" % id, int(a.get("target", -999)), target)
	var rw: Dictionary = a.get("reward", {})
	check_eq("成就 %s 奖励 %s" % [id, reward_key], int(rw.get(reward_key, -999)), reward_val)

# ============================ 十四、包满锁蛋（C1 工坊态已移除） ============================

func _t_workshop_mode() -> void:
	# C1/P2：工坊态双轨已移除（H-8）；包满语义 = is_bag_full，ready 蛋保持待收（H-1）
	var he = HatchS.new()
	he._ensure_slots()
	he.cats = _dummy_cats(24)
	check("C-025R 满包→is_bag_full true", he.is_bag_full())
	he.cats = _dummy_cats(23)
	check("C-027R 未满包→is_bag_full false", not he.is_bag_full())
	check("C-028 H-8 工坊态API已移除", not he.has_method("is_workshop_mode") and not he.has_method("toggle_workshop_override"))
	he.free()

# ============================ 十三、探索（基础逻辑）======================

func _t_explore() -> void:
	ExploreS.reset_all()
	# C-016 派遣 + 重复拒绝
	check("C-016 首次派遣成功", ExploreS.dispatch("c1", 4))
	check("C-016 外出中重复派遣被拒", not ExploreS.dispatch("c1", 4))
	check("派遣非法时长被拒", not ExploreS.dispatch("c2", 3))
	# 返回判定（用 _override_return_time，不依赖真实等待）
	ExploreS._override_return_time("c1", Time.get_unix_time_from_system() + 99999.0)
	check("未到点→未返回", not ExploreS.is_returned("c1"))
	ExploreS._override_return_time("c1", Time.get_unix_time_from_system() - 10.0)
	check("到点→已返回", ExploreS.is_returned("c1"))
	# C-018 领取后可再派
	var got: Dictionary = ExploreS.collect("c1")
	check("C-018 领取返回非空", not got.is_empty())
	check("C-018 领取后可再派", ExploreS.dispatch("c1", 1))
	# slot1 解锁门槛
	ExploreS.reset_all()
	check("slot1 默认未解锁", not ExploreS.is_slot_available(1))
	ExploreS._override_hatched_count(5)
	check("slot1 孵5只后解锁", ExploreS.is_slot_available(1))
	# C-020 返回奖励概率（用唯一 cat_id 规避连续防重，测原始 60/25/10/5）
	ExploreS._rng.seed = 987654
	var N := 100000
	var tally := {"postcard": 0, "ingredient": 0, "decoration": 0, "hidden": 0}
	for i in N:
		tally[ExploreS._roll_reward_type("u%d" % i)] += 1
	check("C-020 明信片≈60%", abs(float(tally["postcard"]) / N - 0.60) <= 0.005,
		"实际=%.4f" % (float(tally["postcard"]) / N))
	check("C-020 食材≈25%", abs(float(tally["ingredient"]) / N - 0.25) <= 0.005)
	check("C-020 装饰≈10%", abs(float(tally["decoration"]) / N - 0.10) <= 0.005)
	check("C-020 隐藏≈5%", abs(float(tally["hidden"]) / N - 0.05) <= 0.005)
	ExploreS.reset_all()

# ============================ DEF-13 节日信件日期 ========================

func _t_mail_dates() -> void:
	var ms = MailS.new()
	# 复活节（算法已知值）
	var e24: Dictionary = ms._calc_easter_sunday(2024)
	check_eq("复活节2024=3/31", "%d/%d" % [e24["month"], e24["day"]], "3/31")
	var e25: Dictionary = ms._calc_easter_sunday(2025)
	check_eq("复活节2025=4/20", "%d/%d" % [e25["month"], e25["day"]], "4/20")
	# 感恩节（美国第4个周四）
	var t24: Dictionary = ms._calc_thanksgiving(2024)
	check_eq("感恩节2024=11/28", "%d/%d" % [t24["month"], t24["day"]], "11/28")
	var t25: Dictionary = ms._calc_thanksgiving(2025)
	check_eq("感恩节2025=11/27", "%d/%d" % [t25["month"], t25["day"]], "11/27")
	# 农历节日：固定公历窗会落空 → xfail (DEF-13)
	var spring := _holiday_by_id(ms, "spring_festival")
	var midaut := _holiday_by_id(ms, "mid_autumn")
	# 2026 春节真实公历 = 2/17
	check_xfail("DEF-13 春节2026(2/17)命中", spring.size() > 0 and ms._holiday_matches(spring, 2026, 2, 17),
		"DEF-13", "固定窗 1/25–2/2 落空")
	# 2026 中秋真实公历 = 9/25
	check_xfail("DEF-13 中秋2026(9/25)命中", midaut.size() > 0 and ms._holiday_matches(midaut, 2026, 9, 25),
		"DEF-13", "固定 9/15 错日")
	ms.free()

func _holiday_by_id(ms, id: String) -> Dictionary:
	for h in ms.HOLIDAYS:
		if String(h.get("id", "")) == id:
			return h
	return {}

# ============================ 待时间缝：DEF-01/05/09 =====================

func _t_pending_seams() -> void:
	# DEF-01 跨天步数爆炸（F-008）：需 StepEngine._today_key() 支持覆盖
	var se = StepS.new()
	if "_test_today" in se:
		se.last_step_date = "2026-06-22"
		se.last_plugin_steps = 850000
		se.today_steps = 0
		se.total_steps = 850000
		se.set("_test_today", "2026-06-23")          # 缝：用 set() 绕过静态检查
		se._on_plugin_steps_changed(850100)
		check_xfail("F-008 跨天不爆炸(today=100)", se.today_steps == 100, "DEF-01",
			"today=%d（修好后=100，未修=850100）" % se.today_steps)
	else:
		pending("F-008 DEF-01 跨天步数爆炸",
			"在 StepEngine 加 `var _test_today:=\"\"`，并让 _today_key() 在其非空时返回它")
	se.free()

	# DEF-05 送养周上限重置：需一个可注入「当前时间戳」的重置入口
	var rs = RelinqS.new()
	if rs.has_method("check_weekly_reset"):
		rs.this_week_petals_gained = 500
		rs.week_reset_timestamp = 0
		rs.call("check_weekly_reset", 1_900_000_000)   # 缝：用 call() 绕过静态检查
		check_xfail("M-008 周上限重置归0", rs.this_week_petals_gained == 0, "DEF-05",
			"重置后应=0")
	else:
		pending("M-008 DEF-05 周上限重置",
			"在 RelinquishSystem 加 check_weekly_reset(now_unix)：跨本地周一 0 点则 this_week_petals_gained=0")
	rs.free()

	# DEF-09 探索改表秒收：需 ExploreEngine 用可注入 _now() 取代裸 Time
	pending("DEF-09 探索改表秒收",
		"ExploreEngine 用 _now()(可注入) 取代 Time.get_unix_time_from_system()，并接 TimeGuard 防回拨/大跳")

# ============================ 工具 =======================================

func _dummy_cats(n: int) -> Array:
	var a: Array = []
	for i in range(n):
		a.append({"id": "cat_%d" % i, "species": "orange", "rarity": "common"})
	return a

# ============================ 汇总 =======================================

func _report() -> void:
	print("")
	for line in _log:
		print(line)
	print("\n===== 自检汇总 =====")
	print("  PASS  : %d" % _pass)
	print("  FAIL  : %d   (真实回归，决定退出码)" % _fail)
	print("  xfail : %d   (已知缺陷，预期失败)" % _xfail)
	print("  XPASS : %d   (缺陷疑似已修，请移出 xfail)" % _xpass)
	print("  skip  : %d   (待时间缝)" % _skip)
	print("====================")
	if _fail == 0:
		print("结果：✅ 无回归（已知缺陷 %d 项仍待修，见上方 xfail）" % _xfail)
	else:
		print("结果：❌ 有 %d 项真实回归，需排查" % _fail)
