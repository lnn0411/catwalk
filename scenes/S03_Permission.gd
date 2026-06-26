extends "res://ui/UIPage.gd"

const BTN_PERMISSION := preload("res://assets/art/ui/btn_permission.png")
const BTN_SKIP := preload("res://assets/art/ui/btn_skip.png")

var _returning_from_settings := false

@onready var _status_label: Label = %StatusLabel

func _ready() -> void:
	super._ready()
	_set_status("")
	%AuthBtn.pressed.connect(handle_authorize)
	%SkipBtn.pressed.connect(handle_skip)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _returning_from_settings:
		_returning_from_settings = false
		_set_status("检测授权结果…")
		call_deferred("_check_and_proceed")

func handle_back() -> bool:
	return true

func handle_authorize() -> void:
	_set_status("正在尝试获取权限…")
	_open_settings()

func handle_skip() -> void:
	UIManager.replace("res://scenes/S02_Loading.tscn")

## —— 内部函数 ——

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

func _open_settings() -> void:
	_returning_from_settings = true
	var sc := Engine.get_singleton("StepCounter")

	if sc == null:
		_set_status("插件未加载，无法打开设置页")
		push_error("StepCounter singleton is null — plugin not registered in APK")
		return

	# 调试：列出所有可用方法
	var methods: Array = []
	for m in sc.get_method_list():
		methods.append(String(m.get("name", "")))
	print("[Permission] StepCounter methods: ", methods)

	# 优先尝试系统设置页（最可靠：跳转到系统应用信息 → 用户手动开权限）
	if _try_call(sc, "openAppSettings"):
		_set_status("跳转系统设置…")
		return

	# 降级：尝试标准权限对话框（部分 ROM 可能拦截）
	if _try_call(sc, "requestActivityRecognitionPermission"):
		_set_status("弹出授权对话框…")
		_check_permission_result()
		return

	_set_status("插件缺少所需方法")
	push_error("StepCounter plugin missing both openAppSettings and requestActivityRecognitionPermission")

# 安全调用插件方法，返回 true 表示方法存在且调用成功
func _try_call(sc, method: String) -> bool:
	if sc == null:
		return false
	# 先用 has_method 检查（Godot 反射机制）
	if sc.has_method(method):
		sc.call(method)
		return true
	# 兜底：get_method_list 可能有但 has_method 不认
	for m in sc.get_method_list():
		if String(m.get("name", "")) == method:
			sc.call(method)
			return true
	return false

func _check_permission_result() -> void:
	for i in range(6):
		if _check_permission():
			_set_status("授权成功，进入游戏…")
			SaveManager.save_all()
			UIManager.replace("res://scenes/S02_Loading.tscn")
			return
		await get_tree().create_timer(0.5).timeout
	# 弹窗无反应，改用系统设置页
	_set_status("弹窗无响应，尝试系统设置…")
	var sc := Engine.get_singleton("StepCounter")
	if sc and sc.has_method("openAppSettings"):
		sc.call("openAppSettings")
	else:
		_set_status("无法跳转设置，请手动授权")

func _check_permission() -> bool:
	var sc := Engine.get_singleton("StepCounter")
	if sc == null:
		return true  # editor
	if sc.has_method("hasActivityRecognitionPermission"):
		return bool(sc.call("hasActivityRecognitionPermission"))
	return true

var _retry_count := 0

func _check_and_proceed() -> void:
	if _check_permission():
		_set_status("")
		SaveManager.save_all()
		UIManager.replace("res://scenes/S02_Loading.tscn")
		return
	_retry_count += 1
	if _retry_count < 3:
		_set_status("授权未刷新，重试中…")
		await get_tree().create_timer(0.5).timeout
		_check_and_proceed()
	else:
		_retry_count = 0
		_set_status("授权未通过，可再次点击授权按钮")
