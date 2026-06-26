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

	# Godot 4 Android 插件上 has_method 有已知 bug（#46673），
	# 改用直接 call，方法存在即可正常工作。
	# 方法已通过 @UsedByGodot + getPluginMethods 双重注册。

	# 优先尝试系统设置页
	_set_status("跳转系统设置…")
	sc.call("openAppSettings")
	return

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
	var result = sc.call("hasActivityRecognitionPermission")
	if result == null:
		return true  # 方法未注册，跳过权限检查
	return bool(result)

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
