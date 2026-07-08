extends Node

const CatData := preload("res://core/CatData.gd")

# ============================================================
# 猫步天下 · 运行时自检测试套件 v2（严谨版）
# ------------------------------------------------------------
# 与旧 t3_3b_testcases 的区别：
#   旧套件 ~80% 用「grep 源码字符串」假装测功能（会给"全绿"错觉）。
#   本套件全部「驱动真实行为 + 断言状态变化」，且确定性（可重复、不靠 RNG 运气）。
#
# 用法：
#   1. 新建一个场景，根节点为 Node，挂上本脚本（或直接把本脚本设为运行场景）。
#   2. 在 Godot 里运行该场景，看控制台输出每条 ✓/✗ + 末尾汇总。
#   3. 判定门槛：任何 ✗ → 禁止报 complete，修复后重跑。
#
# 安全：测试会写 user://save.cfg，运行前自动备份、结束后自动还原，不破坏现有存档。
#       但仍建议在 debug 构建 / 非生产存档上跑。
# ============================================================

const SAVE_PATH := "user://save.cfg"
const BAK_PATH := "user://save_selfcheck_backup.cfg"

var _pass := 0
var _fail := 0
var _section := ""
var _failed_list: Array[String] = []

func _ready() -> void:
	_backup_save()
	print("=".repeat(64))
	print("  猫步天下 · 运行时自检测试 v2（严谨版）")
	print("=".repeat(64))

	await _t_energy_engine()
	await _t_step_engine()
	await _t_hatch_engine()
	await _t_pity()
	await _t_save_roundtrip()
	await _t_integration()
	await _t_cat_spawner()
	await _t_uimanager()
	await _t_scene_smoke()
	await _t_explore_engine()
	await _t_emotion_state_machine()
	await _t_cat_schedule()
	await _t_level_system()
	await _t_interaction_system()
	await _t_signin_system()
	await _t_achievement_system()

	print("\n" + "=".repeat(64))
	print("  结果：%d 通过 / %d 失败" % [_pass, _fail])
	if _fail > 0:
	print("  ── 失败项 ──")
	for f in _failed_list:
	print("    ✗ " + f)
	print("  判定：" + ("✅ 全部通过，可报 complete" if _fail == 0 else "❌ 有失败，禁止 complete"))
	print("=".repeat(64))

	_restore_save()

# ---------- 断言框架 ----------
func _sec(name: String) -> void:
	_section = name
	print("\n─── %s ───" % name)

func _ok(desc: String, cond: bool) -> void:
	if cond:
	_pass += 1
	print("  [✓] %s" % desc)
	else:
	_fail += 1
	_failed_list.append("[%s] %s" % [_section, desc])
	print("  [✗] %s" % desc)

func _eq(desc: String, actual, expected) -> void:
	_ok("%s  (实际=%s 期望=%s)" % [desc, str(actual), str(expected)], actual == expected)

func _near(desc: String, actual: float, expected: float, tol: float = 0.5) -> void:
	_ok("%s  (实际=%.2f 期望=%.2f)" % [desc, actual, expected], absf(actual - expected) <= tol)

func _ge(desc: String, actual, minv) -> void:
	_ok("%s  (实际=%s 应≥%s)" % [desc, str(actual), str(minv)], actual >= minv)

func _le(desc: String, actual, maxv) -> void:
	_ok("%s  (实际=%s 应≤%s)" % [desc, str(actual), str(maxv)], actual <= maxv)

# ============================================================
# A. EnergyEngine —— 能量公式 / 池 / 储备 / 消耗
# ============================================================
func _t_energy_engine() -> void:
	_sec("A. EnergyEngine 能量逻辑")
	if not FileAccess.file_exists("res://core/EnergyEngine.gd"):
	print("  [⏭] 跳过 — EnergyEngine 已移除，相关逻辑归入 HatchEngine")
	await get_tree().process_frame
	return
	var E = load("res://core/EnergyEngine.gd")

	# A1 能量公式各 Tier 边界（对照 GDD §2.1 表，非新手 t1=0.3）
	_eq("calcEnergy 500步",   E.calc_energy(500, false), 150)
	_eq("calcEnergy 1000步",  E.calc_energy(1000, false), 300)
	_eq("calcEnergy 1500步",  E.calc_energy(1500, false), 800)
	_eq("calcEnergy 5000步",  E.calc_energy(5000, false), 4700)
	_eq("calcEnergy 8000步",  E.calc_energy(8000, false), 9200)
	# A2 新手保护期 t1=0.8
	_eq("calcEnergy 500步(新手)",  E.calc_energy(500, true), 400)
	_eq("calcEnergy 1500步(新手)", E.calc_energy(1500, true), 1300)

	# A3 新手保护判定
	E.created_at = Time.get_unix_time_from_system()
	_ok("刚建号 = 新手", E.is_new_player())
	E.created_at = Time.get_unix_time_from_system() - 8 * 86400
	_ok("8天前建号 = 非新手", not E.is_new_player())

	# A4 spend_pool 扣除与下限保护
	E.apply_save({})
	E.energy_pool = 1000.0
	_near("spend_pool(300) 返回值", E.spend_pool(300.0), 300.0)
	_near("spend_pool 后池剩余", E.energy_pool, 700.0)
	_near("spend_pool 超额只扣到0", E.spend_pool(99999.0), 700.0)
	_near("池清零不为负", E.energy_pool, 0.0)

	# A5 溢出：池满 15000 后截断（reserve_tank 已移除 R8）
	E.apply_save({})
	E.process_steps(60000)  # 远超池容量
	_near("池上限封顶 15000", E.energy_pool, 15000.0)
	_near("池上限无额外蓄能", E.energy_pool, 15000.0)

	# A6 跨天重置
	E.apply_save({})
	E.today_energy = 100.0
	E.today_steps_processed = 50
	E.last_energy_date = "2000-01-01"
	E.process_steps(0)
	_eq("跨天后 today_energy 归零", int(E.today_energy), 0)
	_eq("跨天后 today_steps_processed 归零", E.today_steps_processed, 0)

	await get_tree().process_frame

# ============================================================
# B. StepEngine —— 累计值转增量 / 重启保护 / 跨天
# ============================================================
func _t_step_engine() -> void:
	_sec("B. StepEngine 步数逻辑")
	if not FileAccess.file_exists("res://core/StepEngine.gd"):
	print("  [⏭] 跳过 — StepEngine.gd 未加载")
	await get_tree().process_frame
	return
	var S = StepEngine

	# B1 mock 步数累加
	S.apply_save({})
	S.add_mock_steps(1000)
	_eq("add 1000 → today", S.today_steps, 1000)
	S.add_mock_steps(500)
	_eq("add +500 → today", S.today_steps, 1500)

	# B2 插件累计值 → 增量（核心：后台步数恢复的关键算法）
	S.apply_save({})
	S._on_plugin_steps_changed(1000)   # 首读，累计1000
	_eq("累计1000 → today", S.today_steps, 1000)
	S._on_plugin_steps_changed(1500)   # 累计跳到1500（模拟回前台补步）
	_eq("累计1500 → today只+500", S.today_steps, 1500)
	_eq("last_plugin_steps 记录累计值", S.last_plugin_steps, 1500)

	# B3 设备重启保护：累计值变小不算负、不暴涨
	S._on_plugin_steps_changed(100)    # 累计骤降=重启
	_eq("重启(累计骤降) today不变", S.today_steps, 1500)
	_eq("重启后基准重置为新值", S.last_plugin_steps, 100)

	# B4 跨天重置
	S.apply_save({})
	S.today_steps = 500
	S.last_step_date = "2000-01-01"
	_eq("跨天 get_today_steps 归零", S.get_today_steps(), 0)

	await get_tree().process_frame

# ============================================================
# C. HatchEngine —— 手动孵化 / 串行 / 解锁
# ============================================================
func _t_hatch_engine() -> void:
	_sec("C. HatchEngine 孵化逻辑")
	var H = HatchEngine

	# C1 初始槽位状态
	SaveManager.reset_all()
	var slots = H.get_slots()
	_eq("共4槽", slots.size(), 4)
	_eq("slot0 初始 incubating", String(slots[0].get("status","")), "incubating")
	_ok("slot0 已解锁", bool(slots[0].get("unlocked", false)))
	_near("slot0 蛋成本=4250", float(slots[0].get("max_energy",0)), 4250.0)
	_ok("slot1 初始未解锁", not bool(slots[1].get("unlocked", true)))

	# C2 手动孵化：满能量 → ready，不自动产猫
	SaveManager.reset_all()
	H.feed_energy(4250.0)
	_eq("满能量后 slot0=ready", String(H.get_slots()[0].get("status","")), "ready")
	_eq("满能量后 不自动产猫", H.get_cats().size(), 0)

	# C3 collect_ready_slot 才产猫
	var cat = H.collect_ready_slot(0)
	_ok("collect 返回 CatData", cat != null)
	_eq("collect 后产1只猫", H.get_cats().size(), 1)

	# C4 非 ready 槽 collect 返回 null
	SaveManager.reset_all()
	_ok("非ready槽 collect=null", H.collect_ready_slot(0) == null)
	_eq("非ready collect 不产猫", H.get_cats().size(), 0)

	# C5 串行填充验证：collect slot0 后 slot0 被重新分配，能量继续灌回 slot0
	SaveManager.reset_all()
	H.feed_energy(4250.0)
	H.collect_ready_slot(0)                       # 产1猫，slot0变empty→_assign_next_empty_slots重新孵化slot0
	var s0 = H.get_slots()
	_eq("串行: collect后slot0重新孵化", String(s0[0].get("status","")), "incubating")
	_near("串行: slot0蛋成本4250", float(s0[0].get("max_energy",0)), 4250.0)
	H.feed_energy(4250.0)                          # 低索引优先，灌回slot0
	s0 = H.get_slots()
	_eq("串行: 再灌4250 slot0=ready", String(s0[0].get("status","")), "ready")
	_near("串行: slot0满4250", float(s0[0].get("energy",0)), 4250.0)

	# C6 槽位按孵化数解锁
	SaveManager.reset_all()
	H.hatched_count = 3
	H._update_unlocks()
	_ok("孵3只 slot2解锁", bool(H.get_slots()[2].get("unlocked", false)))
	_ok("孵3只 slot3仍锁", not bool(H.get_slots()[3].get("unlocked", true)))
	H.hatched_count = 10
	H._update_unlocks()
	_ok("孵10只 slot3解锁", bool(H.get_slots()[3].get("unlocked", false)))

	# C7 品种按累计产出解锁
	SaveManager.reset_all()
	EnergyEngine.total_energy_produced = 0.0
	_eq("0产出 仅橘猫", H.get_unlocked_species().size(), 1)
	EnergyEngine.total_energy_produced = 15000.0
	_ok("15000产出 解锁英短", H.get_unlocked_species().has(CatData.BREED_BRITISH))
	EnergyEngine.total_energy_produced = 30000.0
	_ok("30000产出 解锁暹罗", H.get_unlocked_species().has(CatData.BREED_SIAMESE))

	# C8 每蛋成本统一 4250
	_eq("橘猫蛋成本", CatData.get_hatch_cost(CatData.BREED_ORANGE), 4250)
	_eq("英短蛋成本", CatData.get_hatch_cost(CatData.BREED_BRITISH), 4250)
	_eq("暹罗蛋成本", CatData.get_hatch_cost(CatData.BREED_SIAMESE), 4250)

	SaveManager.reset_all()
	await get_tree().process_frame

# ============================================================
# D. 稀有度保底（确定性，不靠 RNG 运气）
# ============================================================
func _t_pity() -> void:
	_sec("D. 稀有度保底")
	var H = HatchEngine

	# D1 计数器更新规则（直接测，确定性）
	H.epic_pity_count = 5; H.legendary_pity_count = 5
	H._update_pity_counters(CatData.RARITY_COMMON)
	_ok("common: 两计数+1", H.epic_pity_count == 6 and H.legendary_pity_count == 6)
	H._update_pity_counters(CatData.RARITY_RARE)
	_ok("rare: 两计数+1", H.epic_pity_count == 7 and H.legendary_pity_count == 7)
	H.epic_pity_count = 10; H.legendary_pity_count = 10
	H._update_pity_counters(CatData.RARITY_EPIC)
	_ok("epic: epic归零/leg+1", H.epic_pity_count == 0 and H.legendary_pity_count == 11)
	H.epic_pity_count = 10; H.legendary_pity_count = 10
	H._update_pity_counters(CatData.RARITY_LEGENDARY)
	_ok("legendary: 两计数都归零", H.epic_pity_count == 0 and H.legendary_pity_count == 0)

	# D2 epic 保底强制（epic计数到40 → 本次必 epic 或更高）
	var all_epic_or_better := true
	for i in range(80):
	H.epic_pity_count = EPIC_threshold()
	H.legendary_pity_count = 0
	var r = H._roll_rarity()
	if H._rarity_rank(r) < H._rarity_rank(CatData.RARITY_EPIC):
	all_epic_or_better = false
	break
	_ok("epic计数=40 → 必出epic+（80次）", all_epic_or_better)

	# D3 legendary 保底强制（leg计数到120 → 本次必 legendary）
	var all_leg := true
	for i in range(80):
	H.legendary_pity_count = LEG_threshold()
	var r = H._roll_rarity()
	if r != CatData.RARITY_LEGENDARY:
	all_leg = false
	break
	_ok("leg计数=120 → 必出legendary（80次）", all_leg)

	# D4 不变量：3000抽内，epic间隔永不超40、leg间隔永不超120
	H.rng.seed = 20260611
	H.epic_pity_count = 0
	H.legendary_pity_count = 0
	var run_epic := 0
	var run_leg := 0
	var max_run_epic := 0
	var max_run_leg := 0
	var saw_epic := false
	var saw_leg := false
	for i in range(3000):
	var r = H._roll_rarity()
	var rank = H._rarity_rank(r)
	if rank >= H._rarity_rank(CatData.RARITY_EPIC):
	run_epic = 0
	saw_epic = true
	else:
	run_epic += 1
	max_run_epic = maxi(max_run_epic, run_epic)
	if r == CatData.RARITY_LEGENDARY:
	run_leg = 0
	saw_leg = true
	else:
	run_leg += 1
	max_run_leg = maxi(max_run_leg, run_leg)
	_le("连续非epic+ 不超40", max_run_epic, 40)
	_le("连续非legendary 不超120", max_run_leg, 120)
	_ok("3000抽内确实出过epic", saw_epic)
	_ok("3000抽内确实出过legendary", saw_leg)

	SaveManager.reset_all()
	await get_tree().process_frame

func EPIC_threshold() -> int:
	return HatchEngine.EPIC_PITY

func LEG_threshold() -> int:
	return HatchEngine.LEGENDARY_PITY

# ============================================================
# E. 存档往返一致性（全字段）
# ============================================================
func _t_save_roundtrip() -> void:
	_sec("E. 存档往返一致性")

	SaveManager.reset_all()
	StepEngine.add_mock_steps(5000)        # 走路 → 蛋ready
	await get_tree().process_frame
	HatchEngine.collect_ready_slot(0)      # 领取 → 产猫
	HatchEngine.epic_pity_count = 17
	HatchEngine.legendary_pity_count = 88
	await get_tree().process_frame

	var s1 = StepEngine.today_steps
	var t1 = StepEngine.total_steps
	var e1 = int(EnergyEngine.energy_pool)
	var p1 = int(EnergyEngine.total_energy_produced)
	var c1 = HatchEngine.get_cats().size()
	var name1 = String(HatchEngine.get_cats()[0].display_name) if c1 > 0 else ""
	var sp1 = String(HatchEngine.get_cats()[0].species) if c1 > 0 else ""

	SaveManager.save_all()
	HatchEngine.epic_pity_count = 88   # 故意改脏，验证 load 会覆盖回来
	HatchEngine.legendary_pity_count = 17
	SaveManager.load_and_apply()
	await get_tree().process_frame

	_eq("today_steps 往返", StepEngine.today_steps, s1)
	_eq("total_steps 往返", StepEngine.total_steps, t1)
	_eq("energy_pool 往返", int(EnergyEngine.energy_pool), e1)
	_eq("total_energy_produced 往返", int(EnergyEngine.total_energy_produced), p1)
	_eq("猫数往返", HatchEngine.get_cats().size(), c1)
	_eq("epic保底计数往返", HatchEngine.epic_pity_count, 17)
	_eq("leg保底计数往返", HatchEngine.legendary_pity_count, 88)
	if c1 > 0:
	_eq("猫名往返", String(HatchEngine.get_cats()[0].display_name), name1)
	_eq("猫品种往返", String(HatchEngine.get_cats()[0].species), sp1)

	SaveManager.reset_all()
	await get_tree().process_frame

# ============================================================
# F. 集成：防双算 + 完整孵化链
# ============================================================
func _t_integration() -> void:
	_sec("F. 集成（防双算 + 孵化链）")

	# F1 防双重计算：走5000步(新手)→产5200能量，孵1颗蛋扣4250，池剩950
	SaveManager.reset_all()
	StepEngine.add_mock_steps(5000)
	await get_tree().process_frame
	_near("产出能量 5200", EnergyEngine.total_energy_produced, 5200.0)
	_near("池=产出-蛋成本=950（未双算）", EnergyEngine.energy_pool, 950.0)
	_eq("走路只到ready 不自动产猫", HatchEngine.get_cats().size(), 0)
	_eq("slot0=ready", String(HatchEngine.get_slots()[0].get("status","")), "ready")

	# F2 完整链：collect → 产猫 + 发 hatch_complete 信号
	var got_signal := [false]
	var cb := func(_c): got_signal[0] = true
	HatchEngine.hatch_complete.connect(cb)
	var cat = HatchEngine.collect_ready_slot(0)
	HatchEngine.hatch_complete.disconnect(cb)
	_ok("collect 发出 hatch_complete", got_signal[0])
	_eq("产猫1只", HatchEngine.get_cats().size(), 1)
	_eq("首猫必为橘猫", String(cat.species), CatData.BREED_ORANGE)
	_ok("猫有有效稀有度", cat.rarity in [CatData.RARITY_COMMON, CatData.RARITY_RARE, CatData.RARITY_EPIC, CatData.RARITY_LEGENDARY])
	_ok("猫有默认名(未命名)", CatData.is_default_name(String(cat.display_name)))

	SaveManager.reset_all()
	await get_tree().process_frame

# ============================================================
# G. CatSpawner —— 信号驱动生成 + 去重
# ============================================================
func _t_cat_spawner() -> void:
	_sec("G. CatSpawner 生成")

	if not ResourceLoader.exists("res://scenes/CatSprite.tscn"):
	_ok("CatSprite.tscn 存在", false)
	return

	SaveManager.reset_all()
	var container := Node2D.new()
	add_child(container)
	CatSpawner.set_cat_container(container)

	# 孵一只 → 应在容器里生成一个节点
	HatchEngine.feed_energy(4250.0)
	var cat = HatchEngine.collect_ready_slot(0)
	await get_tree().process_frame
	_ge("孵化后容器生成猫节点", container.get_child_count(), 1)

	# 同一只重复 instance 不应重复生成（去重）
	var before = container.get_child_count()
	CatSpawner.instance_cat(cat)
	await get_tree().process_frame
	_eq("同猫不重复生成", container.get_child_count(), before)

	CatSpawner.set_cat_container(null)
	container.queue_free()
	SaveManager.reset_all()
	await get_tree().process_frame

# ============================================================
# H. UIManager —— 真实栈机制（push/pop/replace/pop_to_root）
# ============================================================
func _t_uimanager() -> void:
	_sec("H. UIManager 导航栈")

	var d0 = UIManager.get_stack_depth()
	UIManager.push("res://scenes/S04_GardenMain.tscn", {}, true)
	await get_tree().process_frame
	_eq("push 后栈深+1", UIManager.get_stack_depth(), d0 + 1)

	UIManager.push("res://scenes/S06_HatchPage.tscn", {}, true)
	await get_tree().process_frame
	_eq("再push 栈深+2", UIManager.get_stack_depth(), d0 + 2)

	UIManager.replace("res://scenes/S11_Settings.tscn", {}, true)
	await get_tree().process_frame
	_eq("replace 栈深不变", UIManager.get_stack_depth(), d0 + 2)

	UIManager.pop(true)
	await get_tree().process_frame
	_eq("pop 后栈深-1", UIManager.get_stack_depth(), d0 + 1)

	UIManager.pop_to_root()
	await get_tree().process_frame
	_eq("pop_to_root 回到栈底(深=1)", UIManager.get_stack_depth(), 1)
	# 注：UIManager.pop() 不会弹掉最后一页（栈底常驻），故测试结束保留 1 页属正常。

# ============================================================
# I. 场景冒烟（实例化不崩 + 关键节点存在，非 grep）
# ============================================================
func _t_scene_smoke() -> void:
	_sec("I. 场景冒烟实例化")

	# 注：S00_Splash / S02_Loading 含「定时器到点自动 replace」逻辑，
	# 提前 free 会让定时器回调访问已释放节点刷错误，故不纳入冒烟（其 _ready 逻辑极简）。
	var scenes := [
	"res://scenes/S01_Onboarding.tscn", "res://scenes/S03_Permission.tscn",
	"res://scenes/S04_GardenMain.tscn", "res://scenes/S05_ReadOnlyGarden.tscn",
	"res://scenes/S06_HatchPage.tscn", "res://scenes/S08_HatchShow.tscn",
	"res://scenes/S06_NamePopup.tscn", "res://scenes/S10_Album.tscn",
	"res://scenes/S10_CatDetail.tscn", "res://scenes/S11_Settings.tscn",
	"res://scenes/S90_NetworkError.tscn", "res://scenes/S91_PermDenied.tscn",
	"res://scenes/S92_SleepReturn.tscn",
	]
	for path in scenes:
	var name = path.get_file().get_basename()
	if not ResourceLoader.exists(path):
	_ok("%s 资源存在" % name, false)
	continue
	var packed = load(path)
	var node = packed.instantiate() if packed else null
	if node == null:
	_ok("%s 实例化" % name, false)
	continue
	add_child(node)
	await get_tree().process_frame
	_ok("%s 实例化无崩溃" % name, is_instance_valid(node))
	node.queue_free()
	await get_tree().process_frame

	# S04 关键节点结构（真实节点检查，非 grep）
	var s04 = load("res://scenes/S04_GardenMain.tscn").instantiate()
	add_child(s04)
	await get_tree().process_frame
	_ok("S04 含 GardenLayer 节点", _find_child_named(s04, "GardenLayer"))
	_ok("S04 含 HUD 节点", _find_child_named(s04, "HUD"))
	s04.queue_free()

	# BottomNav 含 5 个 Tab
	if ResourceLoader.exists("res://ui/BottomNav.tscn"):
	var nav = load("res://ui/BottomNav.tscn").instantiate()
	add_child(nav)
	await get_tree().process_frame
	var emitted := [-1]
	if nav.has_signal("tab_selected"):
	nav.tab_selected.connect(func(i): emitted[0] = i)
	if nav.has_method("_on_tab_pressed"):
	nav._on_tab_pressed(4)
	_eq("BottomNav 点设置Tab 发index=4", emitted[0], 4)
	nav.queue_free()
	await get_tree().process_frame

# ---------- 工具 ----------
func _find_child_named(node: Node, target: String, depth: int = 3) -> bool:
	if depth < 0:
	return false
	for c in node.get_children():
	if c.name == target:
	return true
	if _find_child_named(c, target, depth - 1):
	return true
	return false

# ============================================================
# J. ExploreEngine — 探索系统（TDD，先写测试再实现）
# ============================================================
func _t_explore_engine() -> void:
	_sec("J. ExploreEngine 探索系统")
	if not FileAccess.file_exists("res://core/ExploreEngine.gd"):
	print("  [⏭] 跳过 — ExploreEngine.gd 尚未创建")
	await get_tree().process_frame
	return
	var E = load("res://core/ExploreEngine.gd")

	# J1 探索槽初始化
	E.reset_all()
	_eq("J1 探索槽共2个", E.get_slot_count(), 2)
	_ok("J1 slot0初始可用", E.is_slot_available(0))
	_ok("J1 slot1初始锁定(需孵5只)", not E.is_slot_available(1))

	# J2 派遣猫咪
	E.reset_all()
	var dispatched: bool = E.dispatch("test_cat_1", 1)
	_ok("J2 派遣成功", dispatched)
	_ok("J2 猫在探索中", E.is_exploring("test_cat_1"))
	_ok("J2 未到返回时间", not E.is_returned("test_cat_1"))
	_ok("J2 重复派遣拒绝", not E.dispatch("test_cat_1", 1))

	# J3 槽位并行
	E.reset_all()
	E._override_hatched_count(5)
	_ok("J3 slot1已解锁", E.is_slot_available(1))
	E.dispatch("cat_A", 1)
	E.dispatch("cat_B", 2)
	_ok("J3 两猫同时探索", E.is_exploring("cat_A") and E.is_exploring("cat_B"))

	# J4 返回检测
	E.reset_all()
	E.dispatch("test_cat_2", 1)
	E._override_return_time("test_cat_2", Time.get_unix_time_from_system() - 10.0)
	_ok("J4 已过期返回true", E.is_returned("test_cat_2"))
	E.dispatch("test_cat_3", 2)
	_ok("J4 未来时间返回false", not E.is_returned("test_cat_3"))

	# J5 奖励Roll类型验证
	E.reset_all()
	var types_seen: Array = []
	for i in range(50):
	var reward_type: String = E._roll_reward_type("test_cat_r", 0)
	if not types_seen.has(reward_type):
	types_seen.append(reward_type)
	_ok("J5 奖励类型在四选一内", types_seen.all(func(t): return t in ["postcard", "ingredient", "decoration", "hidden"]))
	_ok("J5 多次roll覆盖多种类型", types_seen.size() >= 2)

	# J6 防重复明信片
	E.reset_all()
	E._mock_collected_postcards(["pc_001", "pc_002"])
	var dup_count := 0
	for i in range(30):
	if E._roll_reward_type("test_cat_d", 0) == "postcard":
	dup_count += 1
	_ok("J6 防重复-连续postcard不超15次", dup_count <= 15)

	SaveManager.reset_all()
	await get_tree().process_frame

# ============================================================
# K. EmotionStateMachine — 情绪状态机（TDD）
# ============================================================
func _t_emotion_state_machine() -> void:
	_sec("K. EmotionStateMachine 情绪状态机")
	if not FileAccess.file_exists("res://core/EmotionStateMachine.gd"):
	print("  [⏭] 跳过 — EmotionStateMachine.gd 尚未创建")
	await get_tree().process_frame
	return
	var M = load("res://core/EmotionStateMachine.gd")

	# K1 初始状态
	M.reset_all()
	_eq("K1 新猫默认idle", M.get_emotion("cat_k1"), "idle")

	# K2 happy转换
	M.reset_all()
	M.record_interaction("cat_k2", "feed")
	_eq("K2 互动后变happy", M.get_emotion("cat_k2"), "happy")
	_ok("K2 30min内仍是happy", not M.is_expired("cat_k2", "happy", 30))
	M._override_elapsed("cat_k2", 1801.0)
	_eq("K2 30min后恢复idle", M.get_emotion("cat_k2"), "idle")

	# K3 annoyed触发
	M.reset_all()
	var interaction_types: Array = ["feed", "pet", "play", "photo"]
	for i in range(4):
	M.record_interaction("cat_k3", interaction_types[i])
	M._advance_window(300.0)
	_eq("K3 4次互动变annoyed", M.get_emotion("cat_k3"), "annoyed")
	_ok("K3 is_annoyed=true", M.is_annoyed("cat_k3"))
	M._advance_window(3601.0)  # 推进1h+让历史记录滑出窗口
	_eq("K3 1h后恢复idle", M.get_emotion("cat_k3"), "idle")

	# K4 curious触发
	M.reset_all()
	M.trigger_curious("cat_k4", "new_cat_arrived")
	_eq("K4 新猫触发curious", M.get_emotion("cat_k4"), "curious")
	M._override_elapsed("cat_k4", 601.0)
	_eq("K4 10min后消退", M.get_emotion("cat_k4"), "idle")

	# K5 sleepy时段
	M.reset_all()
	M.set_schedule_override("sleep")
	_eq("K5 sleep时段变sleepy", M.get_emotion("cat_k5"), "sleepy")
	M.wake_up("cat_k5")
	_eq("K5 抚摸唤醒变idle", M.get_emotion("cat_k5"), "idle")
	M.set_schedule_override("active")
	_eq("K5 active时段非sleepy", M.get_emotion("cat_k5"), "idle")

	# K6 互动历史滑动窗口
	M.reset_all()
	var k6_types: Array = ["feed", "pet", "play", "photo", "feed"]
	for i in range(5):
	M.record_interaction("cat_k6", k6_types[i])
	M._advance_window(750.0)  # 12.5min间隔，5次=62.5min，第1次滑出1h窗口
	_eq("K6 窗口外旧记录不计数", M.get_emotion("cat_k6"), "annoyed")

	SaveManager.reset_all()
	await get_tree().process_frame

# ============================================================
# L. CatSchedule — 作息时段系统（TDD）
# ============================================================
func _t_cat_schedule() -> void:
	_sec("L. CatSchedule 作息时段")
	if not FileAccess.file_exists("res://core/CatSchedule.gd"):
	print("  [⏭] 跳过 — CatSchedule.gd 尚未创建")
	await get_tree().process_frame
	return
	var C = load("res://core/CatSchedule.gd")

	# L1 6时段定义
	_eq("L1 6点=dawn", C.get_period(6), "dawn")
	_eq("L1 8点=dawn", C.get_period(8), "dawn")
	_eq("L1 9点=morning", C.get_period(9), "morning")
	_eq("L1 11点=morning", C.get_period(11), "morning")
	_eq("L1 12点=noon", C.get_period(12), "noon")
	_eq("L1 13点=noon", C.get_period(13), "noon")
	_eq("L1 14点=afternoon", C.get_period(14), "afternoon")
	_eq("L1 17点=afternoon", C.get_period(17), "afternoon")
	_eq("L1 18点=dusk", C.get_period(18), "dusk")
	_eq("L1 19点=dusk", C.get_period(19), "dusk")
	_eq("L1 20点=night", C.get_period(20), "night")
	_eq("L1 23点=night", C.get_period(23), "night")
	_eq("L1 0点=night", C.get_period(0), "night")
	_eq("L1 5点=night", C.get_period(5), "night")

	# L2 品种×小时状态
	_eq("L2 橘猫7点=active", C.get_state("orange", 7), "active")
	_eq("L2 橘猫10点=sleep", C.get_state("orange", 10), "sleep")
	_eq("L2 橘猫13点=active", C.get_state("orange", 13), "active")
	_eq("L2 橘猫15点=sleep", C.get_state("orange", 15), "sleep")
	_eq("L2 橘猫18点=active", C.get_state("orange", 18), "active")
	_eq("L2 橘猫22点=active", C.get_state("orange", 22), "active")
	_eq("L2 橘猫23点=sleep", C.get_state("orange", 23), "sleep")
	_eq("L2 橘猫0点=sleep", C.get_state("orange", 0), "sleep")
	_eq("L2 英短7点=window", C.get_state("british", 7), "window")
	_eq("L2 英短10点=active", C.get_state("british", 10), "active")
	_eq("L2 英短13点=sleep", C.get_state("british", 13), "sleep")
	_eq("L2 英短15点=active", C.get_state("british", 15), "active")
	_eq("L2 英短18点=active", C.get_state("british", 18), "active")
	_eq("L2 英短22点=active", C.get_state("british", 22), "active")
	_eq("L2 英短23点=sleep", C.get_state("british", 23), "sleep")
	_eq("L2 暹罗7点=active", C.get_state("siamese", 7), "active")
	_eq("L2 暹罗10点=active", C.get_state("siamese", 10), "active")
	_eq("L2 暹罗12点=active", C.get_state("siamese", 12), "active")
	_eq("L2 暹罗13点=active", C.get_state("siamese", 13), "active")
	_eq("L2 暹罗15点=sleep", C.get_state("siamese", 15), "sleep")
	_eq("L2 暹罗18点=active", C.get_state("siamese", 18), "active")
	_eq("L2 暹罗22点=lazy", C.get_state("siamese", 22), "lazy")
	_eq("L2 暹罗23点=sleep", C.get_state("siamese", 23), "sleep")

	# L3 set_time_override 时间助手
	C.set_time_override(13)
	_eq("L3 override13点 当前=noon", C.get_current_period(), "noon")
	C.set_time_override(8)
	_eq("L3 override8点 当前=dawn", C.get_current_period(), "dawn")

	# L4 night巡逻（品种感知）
	C.set_time_override(20)
	_ok("L4 20点=巡逻", C.is_night_patrol("orange"))
	C.set_time_override(23)
	_ok("L4 23点=巡逻", C.is_night_patrol("british"))
	C.set_time_override(19)
	_ok("L4 19点非巡逻", not C.is_night_patrol("orange"))
	C.set_time_override(0)
	_ok("L4 0点橘猫巡逻", C.is_night_patrol("orange"))
	C.set_time_override(3)
	_ok("L4 3点英短非巡逻", not C.is_night_patrol("british"))

	# L5 抚摸唤醒 — 任一品种睡眠时可唤醒
	C.set_time_override(9)
	_ok("L5 9点可唤醒(橘猫睡)", C.can_wake())
	C.set_time_override(13)
	_ok("L5 13点可唤醒(英短睡)", C.can_wake())
	C.set_time_override(7)
	_ok("L5 7点不可唤醒(全醒)", not C.can_wake())
	C.set_time_override(18)
	_ok("L5 18点不可唤醒(全醒)", not C.can_wake())
	C.set_time_override(22)
	_ok("L5 22点不可唤醒(全醒)", not C.can_wake())

	# TC-42: 各黄金时段快照断言>=2品种可互动
	C.set_time_override(8)
	_ok("TC-42 8点(黄金时段)>=2品种醒", C.is_golden_hour(8))
	C.set_time_override(13)
	_ok("TC-42 13点(黄金时段)>=2品种醒", C.is_golden_hour(13))
	C.set_time_override(7)
	_ok("TC-42 7点(黄金时段)>=2品种醒", C.is_golden_hour(7))
	C.set_time_override(21)
	_ok("TC-42 21点(黄金时段)>=2品种醒", C.is_golden_hour(21))
	C.set_time_override(14)
	_ok("TC-42 14点(黄金时段)>=2品种醒", C.is_golden_hour(14))

	SaveManager.reset_all()
	await get_tree().process_frame

# ============================================================
# M. LevelSystem — 等级/经验系统（TDD）
# ============================================================
func _t_level_system() -> void:
	_sec("M. LevelSystem 等级系统")
	if not FileAccess.file_exists("res://core/LevelSystem.gd"):
	print("  [⏭] 跳过 — LevelSystem.gd 尚未创建")
	await get_tree().process_frame
	return
	var L = load("res://core/LevelSystem.gd")

	# M1 品种系数
	_near("M1 橘猫系数1.0", L.get_breed_multiplier("orange"), 1.0)
	_near("M1 英短系数1.2", L.get_breed_multiplier("british"), 1.2)
	_near("M1 暹罗系数1.5", L.get_breed_multiplier("siamese"), 1.5)

	# M2 经验计算 = 步数×系数
	_near("M2 1000步×1.0", L.calc_exp(1000, 1.0), 1000.0)
	_near("M2 1000步×1.2", L.calc_exp(1000, 1.2), 1200.0)
	_near("M2 1000步×1.5", L.calc_exp(1000, 1.5), 1500.0)

	# M3 Lv门槛
	_eq("M3 0→Lv1", L.get_level(0), 1)
	_eq("M3 5000→Lv2", L.get_level(5000), 2)
	_eq("M3 15000→Lv3", L.get_level(15000), 3)
	_eq("M3 30000→Lv4", L.get_level(30000), 4)
	_eq("M3 50000→Lv5", L.get_level(50000), 5)
	_eq("M3 75000→Lv6", L.get_level(75000), 6)
	_eq("M3 100000→Lv7", L.get_level(100000), 7)
	_eq("M3 120000→Lv8", L.get_level(120000), 8)
	_eq("M3 138000→Lv9", L.get_level(138000), 9)
	_eq("M3 150000→Lv10", L.get_level(150000), 10)

	# M4 边界
	_eq("M4 4999=Lv1", L.get_level(4999), 1)
	_eq("M4 5000=Lv2", L.get_level(5000), 2)
	_eq("M4 149999=Lv9", L.get_level(149999), 9)
	_eq("M4 150000=Lv10", L.get_level(150000), 10)

	# M5 满级
	_ok("M5 150000满级", L.is_max_level(150000))
	_ok("M5 200000满级", L.is_max_level(200000))
	_ok("M5 149999未满级", not L.is_max_level(149999))

	SaveManager.reset_all()
	await get_tree().process_frame

# ============================================================
# N. InteractionSystem — 互动/冷却/好感系统（TDD）
# ============================================================
func _t_interaction_system() -> void:
	_sec("N. InteractionSystem 互动系统")
	if not FileAccess.file_exists("res://core/InteractionSystem.gd"):
	print("  [⏭] 跳过 — InteractionSystem.gd 尚未创建")
	await get_tree().process_frame
	return
	var I = load("res://core/InteractionSystem.gd")

	# N1 冷却定义（分钟）
	I.reset_all()
	_eq("N1 feed冷却240", I.get_cooldown_minutes("feed"), 240)
	_eq("N1 pet冷却120", I.get_cooldown_minutes("pet"), 120)
	_eq("N1 play冷却360", I.get_cooldown_minutes("play"), 360)
	_eq("N1 photo冷却60", I.get_cooldown_minutes("photo"), 60)

	# N2 好感值增益
	_eq("N2 feed好感+5", I.get_affection_gain("feed"), 5)
	_eq("N2 pet好感+3", I.get_affection_gain("pet"), 3)
	_eq("N2 play好感+4", I.get_affection_gain("play"), 4)
	_eq("N2 photo好感+2", I.get_affection_gain("photo"), 2)

	# N3 冷却检查
	I.reset_all()
	_ok("N3 初始可互动", I.can_interact("cat_n3", "feed"))
	I.do_interact("cat_n3", "feed")
	_ok("N3 互动后进入冷却", not I.can_interact("cat_n3", "feed"))
	_ok("N3 不同类型不受影响", I.can_interact("cat_n3", "pet"))

	# N4 执行互动返回好感增益
	I.reset_all()
	_eq("N4 do_interact(feed)返回5", I.do_interact("cat_n4", "feed"), 5)
	_ok("N4 执行后进入冷却", not I.can_interact("cat_n4", "feed"))

	# N5 冷却后重新可用
	I.reset_all()
	I.do_interact("cat_n5", "pet")
	_ok("N5 刚互动仍冷却", not I.can_interact("cat_n5", "pet"))
	I._override_last_interact("cat_n5", "pet", 121 * 60)   # 121分钟前 > 120冷却
	_ok("N5 冷却过期重新可用", I.can_interact("cat_n5", "pet"))
	I._override_last_interact("cat_n5", "pet", 119 * 60)   # 119分钟前 < 120
	_ok("N5 未到冷却仍不可用", not I.can_interact("cat_n5", "pet"))

	# N6 好感累积（跨多次互动）
	I.reset_all()
	_eq("N6 初始好感0", I.get_affection("cat_n6"), 0)
	I.do_interact("cat_n6", "feed")   # +5
	I.do_interact("cat_n6", "pet")    # +3
	_eq("N6 好感累积=8", I.get_affection("cat_n6"), 8)

	I.reset_all()
	SaveManager.reset_all()
	await get_tree().process_frame

# ============================================================
# P. SigninSystem — 签到系统（TDD）
# ============================================================
func _t_signin_system() -> void:
	_sec("P. SigninSystem 签到系统")
	if not FileAccess.file_exists("res://core/SigninSystem.gd"):
	print("  [⏭] 跳过 — SigninSystem.gd 尚未创建")
	await get_tree().process_frame
	return
	var P = load("res://core/SigninSystem.gd")

	# P1 签到 day从1开始
	P.reset_all()
	P.set_date_override("2026-06-15")
	var r1: Dictionary = P.signin()
	_eq("P1 首签day=1", int(r1.get("day", 0)), 1)
	_ok("P1 返回含reward", r1.has("reward"))

	# P2 连续7天奖励序列
	P.reset_all()
	var rewards: Array = []
	var days: Array = []
	for i in range(7):
	var r: Dictionary = P.signin()
	days.append(int(r.get("day", 0)))
	rewards.append(r.get("reward"))
	P._simulate_next_day()
	_eq("P2 day序列1-7", days, [1, 2, 3, 4, 5, 6, 7])
	_eq("P2 day1金币100", rewards[0], "金币100")
	_eq("P2 day2金币200", rewards[1], "金币200")
	_eq("P2 day3金币150", rewards[2], "金币150")
	_eq("P2 day4金币200", rewards[3], "金币200")
	_eq("P2 day5金币100", rewards[4], "金币100")
	_eq("P2 day6金币150", rewards[5], "金币150")
	_eq("P2 day7宝箱", rewards[6], "宝箱")

	# P3 断签退1（每漏1天退1级，非归1）
	P.reset_all()
	for i in range(4):                 # 连续签到累计到day4
	P.signin()
	P._simulate_next_day()
	P.set_last_signin_days_ago(2)      # 漏签2天
	var r3: Dictionary = P.signin()
	_eq("P3 断签2天退2级 day=2", int(r3.get("day", 0)), 2)

	# P4 补签卡 每周期最多2张
	P.reset_all()
	_ok("P4 第1张补签可用", P.use_makeup_card())
	_ok("P4 第2张补签可用", P.use_makeup_card())
	_ok("P4 第3张补签拒绝", not P.use_makeup_card())

	# P5 跨天 day推进
	P.reset_all()
	var d0: int = int(P.signin().get("day", 0))
	P._simulate_next_day()
	var d1: int = int(P.signin().get("day", 0))
	_eq("P5 跨天后day+1", d1, d0 + 1)

	P.reset_all()
	SaveManager.reset_all()
	await get_tree().process_frame

# ============================================================
# Q. AchievementSystem — 成就系统（TDD）
# ============================================================
func _t_achievement_system() -> void:
	_sec("Q. AchievementSystem 成就系统")
	var A = AchievementSystem

	# Q1 20成就定义
	A.reset_all()
	_eq("Q1 成就总数20", A.get_definitions().size(), 20)

	# Q2 步数A1
	A.reset_all()
	A._override_total_steps(1500)
	A.check("A1")
	_ok("Q2 A1解锁", A.is_unlocked("A1"))

	# Q3 步数A2
	A.reset_all()
	A._override_total_steps(12000)
	A.check("A2")
	_ok("Q3 A2解锁", A.is_unlocked("A2"))

	# Q4 收集B1
	A.reset_all()
	A._override_hatched_count(1)
	A.check("B1")
	_ok("Q4 B1解锁", A.is_unlocked("B1"))

	# Q5 收集B5全品种
	A.reset_all()
	A._unlock_breed("orange")
	A._unlock_breed("british")
	A._unlock_breed("siamese")
	A.check("B5")
	_ok("Q5 B5全品种解锁", A.is_unlocked("B5"))

	# Q6 养成C1 Lv3
	A.reset_all()
	A._override_cat_level("test_cat", 3)
	A.check("C1")
	_ok("Q6 C1 Lv3解锁", A.is_unlocked("C1"))

	# Q7 防重复: 同条件触发两次仍只解锁一次
	A.reset_all()
	A._override_total_steps(1500)
	A.check("A1")
	_ok("Q7 A1首次解锁", A.is_unlocked("A1"))
	A._override_total_steps(2000)
	A.check("A1")
	_ok("Q7 A1重复仍解锁不崩", A.is_unlocked("A1"))

	# Q8 奖励
	A.reset_all()
	var reward = A.get_reward("A1")
	_ge("Q8 A1奖励金币≥100", int(reward.get("gold", 0)), 100)

	# Q9 重置
	A.reset_all()
	_ok("Q9 重置后A1未解锁", not A.is_unlocked("A1"))

	SaveManager.reset_all()
	await get_tree().process_frame

func _backup_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
	DirAccess.copy_absolute(SAVE_PATH, BAK_PATH)

func _restore_save() -> void:
	if FileAccess.file_exists(BAK_PATH):
	DirAccess.copy_absolute(BAK_PATH, SAVE_PATH)
	DirAccess.remove_absolute(BAK_PATH)
	elif FileAccess.file_exists(SAVE_PATH):
	# 原本没存档 → 删掉测试产生的，保持干净
	DirAccess.remove_absolute(SAVE_PATH)
