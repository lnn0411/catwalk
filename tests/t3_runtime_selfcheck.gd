extends Node

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
	var E = EnergyEngine

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

	# A5 溢出：池满 15000 后进储备 6000
	E.apply_save({})
	E.process_steps(60000)  # 远超池容量
	_near("池上限封顶 15000", E.energy_pool, 15000.0)
	_le("储备不超 6000", E.reserve_tank, 6000.0)
	_ge("储备已积累", E.reserve_tank, 1.0)

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

	# C5 串行填充：slot0 满才轮到 slot1
	SaveManager.reset_all()
	H.feed_energy(4250.0)
	H.collect_ready_slot(0)                       # 产1猫，slot1解锁，slot0/1都incubating
	H.feed_energy(4250.0)                          # 只够1颗
	var s = H.get_slots()
	_eq("串行: slot0 先满=ready", String(s[0].get("status","")), "ready")
	_near("串行: slot1 仍为0", float(s[1].get("energy",0)), 0.0)

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
