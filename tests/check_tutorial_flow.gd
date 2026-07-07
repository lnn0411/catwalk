extends SceneTree

# 自检：纯文本模式验证 TutorialManager 修改后的关键逻辑
# godot --headless --script tests/check_tutorial_flow.gd --quit

var passed := 0
var failed := 0

func _init() -> void:
	print("=== TutorialManager 方案C 纯文本自检 ===\n")
	
	var f := FileAccess.open("res://core/TutorialManager.gd", FileAccess.READ)
	if f == null:
		print("[✗] 无法读取 TutorialManager.gd")
		quit(1)
		return
	
	var text := f.get_as_text()
	f.close()
	
	# 1. 语法检查：load 脚本
	var script = load("res://core/TutorialManager.gd")
	if script:
		_ok("脚本编译通过", "TutorialManager.gd 无语法错误")
	else:
		_fail("脚本编译失败", "有语法错误")
		return
	
	# 2. 关键新增方法存在
	var methods = {}
	for m in script.get_script_method_list():
		methods[m["name"]] = true
	
	var checks = [
		"_connect_hatch_signal",
		"_on_actual_hatch_completed",
		"_step_03_hatch",
	]
	for cname in checks:
		if methods.has(cname):
			_ok("方法存在: %s" % cname, "新增/修改")
		else:
			_fail("方法缺失: %s" % cname, "")
	
	# 3. 关键成员变量存在
	var vars = {}
	for v in script.get_script_property_list():
		vars[v["name"]] = true
	for vname in ["_waiting_for_actual_hatch", "_hatch_completed_during_transition", "_hatch_signal_connected"]:
		if vars.has(vname):
			_ok("变量存在: %s" % vname, "新增")
		else:
			_fail("变量缺失: %s" % vname, "应在脚本顶层声明")
	
	# 4. 逻辑验证（文本检查）
	if text.find("hatch_complete.connect(_on_actual_hatch_completed)") >= 0:
		_ok("信号连接", "HatchEngine.hatch_complete → _on_actual_hatch_completed")
	else:
		_fail("信号连接", "未连接到 hatch_complete 信号")
	
	if text.find("has_button: = false") >= 0 or text.find("false, 0.0") >= 0:
		_ok("Step 3 气泡无按钮", "has_button=false, 等真实信号")
	else:
		_fail("Step 3 气泡无按钮", "未找到 false,0.0 参数")
	
	if text.find("elif current_step == Step.HATCH") >= 0:
		_fail("_advance_from_ack 仍有 HATCH 分支", "应删除")
	else:
		_ok("_advance_from_ack", "已移除 HATCH 分支")
	
	if text.find("current_step = Step.OFF") >= 0 and text.find("start(garden_page)") >= 0:
		_fail("_on_hatch_timeout 仍有重启逻辑", "应改为 _step_03_hatch()")
	else:
		_ok("_on_hatch_timeout", "超时不重启，只回显气泡")
	
	if text.find("is_connected") >= 0:
		_ok("去重连接保护", "connect 前检查 is_connected，防重复连接")
	else:
		_fail("去重连接保护", "缺少 is_connected 检查")
	
	# 5. 验证 Step 3 气泡文案
	if text.find("蛋已经准备好了") >= 0:
		_ok("Step 3 文案", "已更新为引导用户亲手孵化")
	else:
		_fail("Step 3 文案", "仍是旧文案")
	
	_print_summary()
	quit(failed > 0 and 1 or 0)

func _ok(name: String, detail: String) -> void:
	passed += 1
	print("  [✓] %s%s" % [name, " — " + detail if detail.length() > 0 else ""])

func _fail(name: String, detail: String) -> void:
	failed += 1
	print("  [✗] %s — %s" % [name, detail])

func _print_summary() -> void:
	print("\n=== 结果 %d/%d 通过, %d 失败 ===\n" % [passed, passed + failed, failed])
