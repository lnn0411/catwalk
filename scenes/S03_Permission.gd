extends "res://ui/UIPage.gd"

const BTN_PERMISSION := preload("res://assets/art/ui/btn_permission.png")
const BTN_SKIP := preload("res://assets/art/ui/btn_skip.png")

const SIGNAL_TIMEOUT_SECONDS := 3.0

var _signal_connected := false
var _waiting_for_result := false

@onready var _status_label: Label = %StatusLabel

func _ready() -> void:
	super._ready()
	_set_status("")
	%AuthBtn.pressed.connect(handle_authorize)
	%SkipBtn.pressed.connect(handle_skip)
	_connect_permission_signal()
	call_deferred("_skip_if_authorized")

func _connect_permission_signal() -> void:
	if _signal_connected:
		return
	var sc := Engine.get_singleton("StepCounter")
	if sc == null:
		return
	if sc.has_signal("permission_result"):
		sc.connect("permission_result", _on_permission_result)
		_signal_connected = true

func _skip_if_authorized() -> void:
	if _check_permission():
		SaveManager.save_all()
		UIManager.replace("res://scenes/S02_Loading.tscn")

func handle_back() -> bool:
	return true

## 授权流程（两步走）：
## 第一步：in-app 系统对话框（`requestActivityRecognitionPermission`）
##         用户在当前页面直接看到 Android 原生授权弹窗，无需跳转。
##         同时启动 3s 超时计时器，信号未返回则降级。
## 第二步：如果用户曾在系统对话框上勾选「不再询问」，
##         系统自动拒绝且 `shouldShowRequestPermissionRationale` 返回 false，
##         此时降级跳系统设置页（`openAppSettings`）。
func handle_authorize() -> void:
	_set_status("正在请求授权…")
	_waiting_for_result = false
	var sc := Engine.get_singleton("StepCounter")
	if sc == null:
		_set_status("插件未加载")
		push_error("StepCounter singleton is null — plugin not registered in APK")
		return
	_connect_permission_signal()

	# 直接请求 in-app 弹窗（不应在首次请求前检查 shouldShowRequestPermissionRationale，
	# 该 API 在首次请求前返回 false，会被误判为「不能弹窗」而跳过真正的请求）
	_waiting_for_result = true
	sc.call("requestActivityRecognitionPermission")
	_start_signal_timeout()

func _start_signal_timeout() -> void:
	await get_tree().create_timer(SIGNAL_TIMEOUT_SECONDS).timeout
	if not _waiting_for_result:
		return  # 信号已正常返回
	# 信号超时未收到 → in-app 弹窗不可靠，降级跳系统设置页
	push_warning("permission_result signal timed out after %ds — falling back to system settings" % SIGNAL_TIMEOUT_SECONDS)
	_waiting_for_result = false
	_set_status("弹窗未响应，跳转系统设置…")
	_open_settings()

## 检测系统是否允许弹出 in-app 权限对话框。
## `shouldShowRequestPermissionRationale` 在以下情况返回 false：
##   - 用户勾选了「不再询问」
##   - 或设备策略禁止运行时权限弹窗
func _can_show_in_app_dialog() -> bool:
	var sc := Engine.get_singleton("StepCounter")
	if sc == null:
		return false
	if not sc.has_method("shouldShowRequestPermissionRationale"):
		return true  # 保守：可能有野方法
	var rationale = sc.call("shouldShowRequestPermissionRationale")
	if rationale == null:
		return true
	return bool(rationale)

func handle_skip() -> void:
	_waiting_for_result = false
	UIManager.replace("res://scenes/S02_Loading.tscn")

## —— 信号回调 ——

func _on_permission_result(granted: bool) -> void:
	_waiting_for_result = false
	if granted:
		_set_status("授权成功，进入游戏…")
		SaveManager.save_all()
		UIManager.replace("res://scenes/S02_Loading.tscn")
		return

	# 用户拒绝了对话框
	if _can_show_in_app_dialog():
		_set_status("需要授权才能记录步数，再试一次？")
	else:
		# Android 判定「不再询问」，系统不再弹 Dialog
		_set_status("已拒绝多次，请到系统设置页手动开启")
		_open_settings()

## —— 内部函数 ——

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

func _open_settings() -> void:
	var sc := Engine.get_singleton("StepCounter")
	if sc == null:
		_set_status("插件未加载")
		return
	sc.call("openAppSettings")

func _check_permission() -> bool:
	var sc := Engine.get_singleton("StepCounter")
	if sc == null:
		return true  # editor 模式没有插件，跳过权限检查
	var result = sc.call("hasActivityRecognitionPermission")
	if result == null:
		return true
	return bool(result)
