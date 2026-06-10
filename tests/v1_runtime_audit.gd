extends Node

var passed := 0
var failed := 0
var results: Array[String] = []
var screenshots_dir := "user://screenshots/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(screenshots_dir)
	
	print("=".repeat(60))
	print("  T3-3b 运行时验证 (规范 v1.0)")
	print("=".repeat(60))
	
	t_scene_instantiation()
	t_interaction_response()
	t_signal_chain()
	t_persistence()
	t_visual_screenshots()
	
	print("\n" + "=".repeat(60))
	print("  结果: %d 通过 / %d 失败" % [passed, failed])
	for line in results:
		print(line)
	print("=".repeat(60))

func ok(what: String, condition: bool) -> void:
	if condition:
		passed += 1
		results.append("  [✓] %s" % what)
	else:
		failed += 1
		results.append("  [✗] %s" % what)

# ============================================
# 一、场景实例化验证
# ============================================
func t_scene_instantiation() -> void:
	print("\n─── 场景实例化验证 ───")
	
	var scenes = {
		"S00_Splash": "启动页",
		"S01_Onboarding": "引导滑动页",
		"S02_Loading": "加载页",
		"S03_Permission": "权限页",
		"S04_GardenMain": "花园主页",
		"S05_ReadOnlyGarden": "只读花园",
		"S06_HatchPage": "孵化室",
		"S08_HatchShow": "孵化演出",
		"S10_Album": "图鉴页",
		"S10_CatDetail": "猫咪详情",
		"S11_Settings": "设置页",
		"S90_NetworkError": "网络错误页",
		"S91_PermDenied": "权限拒绝页",
		"S92_SleepReturn": "休眠返回页",
		"BottomNav": "底部导航组件",
	}
	
	for name in scenes:
		var path = "res://scenes/%s.tscn" % name
		if name == "BottomNav":
			path = "res://ui/BottomNav.tscn"
		
		var node = _instantiate_safe(path)
		if node:
			add_child(node)
			await get_tree().process_frame
			
			# Check key children
			var children_ok = node.get_child_count() > 0
			if name == "S04_GardenMain":
				var has_garden = _has_named_child(node, "GardenLayer")
				var has_hud = _has_named_child(node, "HUD")
				ok("%s(%s) 实例化" % [scenes[name], name], true)
				ok("  ├ GardenLayer", has_garden)
				ok("  ├ HUD", has_hud)
				ok("  ├ BottomNav", _has_named_child(node, "BottomNav"))
			elif name == "BottomNav":
				ok("%s 实例化" % scenes[name], true)
				ok("  有 tab_selected 信号", node.has_signal("tab_selected"))
			else:
				ok("%s(%s) 实例化 ≥1子节点" % [scenes[name], name], children_ok)
			
			node.queue_free()
		else:
			ok("%s(%s) 实例化" % [scenes[name], name], false)

# ============================================
# 二、交互响应验证
# ============================================
func t_interaction_response() -> void:
	print("\n─── 交互响应验证 ───")
	
	# 2a. BottomNav Tab 点击模拟
	t_nav_tab_click()
	
	# 2b. Mock步数 → 能量 → 孵化
	t_mock_flow()
	
	# 2c. 返回导航
	t_back_navigation()

func t_nav_tab_click() -> void:
	print("  [交互] BottomNav 5Tab:")
	var nav_path = "res://ui/BottomNav.tscn"
	if not ResourceLoader.exists(nav_path):
		ok("  BottomNav 加载", false)
		return
	
	var nav = load(nav_path).instantiate()
	add_child(nav)
	await get_tree().process_frame
	
	var tabs = ["花园", "图鉴", "商店", "好友", "设置"]
	var responses: Array[String] = []
	
	if nav.has_signal("tab_selected"):
		nav.tab_selected.connect(func(idx): responses.append(tabs[idx]))
	
	# Simulate clicking each tab by calling _on_tab_pressed directly
	for i in range(5):
		if nav.has_method("_on_tab_pressed"):
			nav._on_tab_pressed(i)
			await get_tree().process_frame
	
	ok("  5 Tab 均触发 tab_selected", responses.size() >= 5)
	ok("  当前选中 Tab=0(花园)", nav.current_index == 0)
	
	nav.queue_free()

func t_mock_flow() -> void:
	print("  [交互] Mock步数→孵化:")
	
	SaveManager.reset_all()
	
	# Before
	var steps_before = StepEngine.get_today_steps()
	var energy_before = EnergyEngine.energy_pool
	var cats_before = HatchEngine.get_cats().size()
	
	# Action: mock +10000
	StepEngine.add_mock_steps(10000)
	await get_tree().process_frame
	
	# After
	var steps_after = StepEngine.get_today_steps()
	var energy_after = EnergyEngine.energy_pool
	var cats_after = HatchEngine.get_cats().size()
	
	ok("  步数 0→%d" % steps_after, steps_after == 10000)
	ok("  能量 0→%d (>0)" % int(energy_after), energy_after > 0)
	ok("  猫 0→%d (≥1)" % cats_after, cats_after >= 1)
	
	if cats_after >= 1:
		var cat = HatchEngine.get_cats()[0]
		ok("  猫有名字: %s" % cat.display_name, cat.display_name != "")

func t_back_navigation() -> void:
	print("  [交互] 返回导航:")
	
	# Verify 5 pages reference S04 for back
	var pages = ["S10_Album", "S11_Settings", "S05_ReadOnlyGarden", "S06_HatchPage", "S10_CatDetail"]
	for page in pages:
		var c = _read("res://scenes/%s.gd" % page)
		ok("  %s 返回→S04" % page, 'S04_GardenMain' in c)
	
	# Verify onboarding+permission block back
	for page in ["S01_Onboarding", "S03_Permission"]:
		var c = _read("res://scenes/%s.gd" % page)
		var blocks = "handle_back" in c and "return true" in c
		ok("  %s handle_back=true" % page, blocks)

# ============================================
# 三、信号链路验证
# ============================================
func t_signal_chain() -> void:
	print("\n─── 信号链路验证 ───")
	
	SaveManager.reset_all()
	
	# 3a. StepEngine.steps_updated → HatchEngine 响应
	print("  [信号] StepEngine.steps_updated → HatchEngine:")
	var steps_connected = StepEngine.steps_updated.get_connections().size() > 0
	ok("  StepEngine.steps_updated 已连接", steps_connected)
	
	var before = HatchEngine.get_cats().size()
	StepEngine.add_mock_steps(5000)
	await get_tree().process_frame
	var after = HatchEngine.get_cats().size()
	ok("  信号触发后猫数 %d→%d" % [before, after], after >= before)
	
	# 3b. HatchEngine.hatch_complete → CatSpawner 响应
	print("  [信号] HatchEngine.hatch_complete → CatSpawner:")
	ok("  CatSpawner 监听 hatch_complete", 
		HatchEngine.hatch_complete.is_connected(CatSpawner._on_hatch_complete))
	
	# 3c. EnergyEngine.energy_changed → SaveManager 自动存档
	print("  [信号] EnergyEngine.energy_changed → SaveManager:")
	ok("  SaveManager 监听 energy_changed",
		EnergyEngine.energy_changed.is_connected(SaveManager._on_auto_save))

# ============================================
# 四、持久化验证
# ============================================
func t_persistence() -> void:
	print("\n─── 持久化验证 ───")
	
	SaveManager.reset_all()
	StepEngine.add_mock_steps(5000)
	await get_tree().process_frame
	
	var saved_steps = StepEngine.get_today_steps()
	var saved_energy = EnergyEngine.energy_pool
	var saved_cats = HatchEngine.get_cats().size()
	
	SaveManager.save_all()
	print("    保存: 步数=%d 能量=%.0f 猫=%d" % [saved_steps, saved_energy, saved_cats])
	
	# Restore from disk (simulates kill+restart)
	SaveManager.load_and_apply()
	await get_tree().process_frame
	
	var restored_steps = StepEngine.get_today_steps()
	var restored_energy = EnergyEngine.energy_pool
	var restored_cats = HatchEngine.get_cats().size()
	print("    恢复: 步数=%d 能量=%.0f 猫=%d" % [restored_steps, restored_energy, restored_cats])
	
	ok("  步数 %d==%d" % [saved_steps, restored_steps], saved_steps == restored_steps)
	ok("  能量 %.0f==%.0f" % [saved_energy, restored_energy], int(saved_energy) == int(restored_energy))
	ok("  猫 %d==%d" % [saved_cats, restored_cats], saved_cats == restored_cats)

# ============================================
# 五、视觉截图
# ============================================
func t_visual_screenshots() -> void:
	print("\n─── 视觉截图 ───")
	
	var scenes_to_capture = [
		{"name": "S04_GardenMain", "path": "res://scenes/S04_GardenMain.tscn"},
		{"name": "S10_Album", "path": "res://scenes/S10_Album.tscn"},
		{"name": "S11_Settings", "path": "res://scenes/S11_Settings.tscn"},
	]
	
	for entry in scenes_to_capture:
		if not ResourceLoader.exists(entry["path"]):
			ok("  %s 截图" % entry["name"], false)
			continue
		
		var node = load(entry["path"]).instantiate()
		add_child(node)
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Capture viewport
		var img = get_viewport().get_texture().get_image()
		if img:
			var path = screenshots_dir + entry["name"] + ".png"
			var err = img.save_png(path)
			ok("  %s 截图 → %s" % [entry["name"], path], err == OK)
		else:
			ok("  %s 截图" % entry["name"], false)
		
		node.queue_free()
	
	# Also capture the test results
	var view_img = get_viewport().get_texture().get_image()
	if view_img:
		var path = screenshots_dir + "test_results.png"
		view_img.save_png(path)

# ============================================
# Helpers
# ============================================
func _instantiate_safe(path: String):
	if not ResourceLoader.exists(path):
		return null
	var packed = load(path)
	if packed == null:
		return null
	return packed.instantiate()

func _has_named_child(node: Node, name: String) -> bool:
	for child in node.get_children():
		if child.name == name:
			return true
		# Also check recursively one level deep
		for grandchild in child.get_children():
			if grandchild.name == name:
				return true
	return false

func _read(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null: return ""
	var c = f.get_as_text()
	f.close()
	return c
