extends "res://ui/UIPage.gd"

const BTN_PERMISSION := preload("res://assets/art/ui/btn_permission.png")
const BTN_SKIP := preload("res://assets/art/ui/btn_skip.png")

var _returning_from_settings := false

func _ready() -> void:
	super._ready()
	_add_background()

	var btn_permission := TextureButton.new()
	btn_permission.texture_normal = BTN_PERMISSION
	btn_permission.position = Vector2(210, 900)
	btn_permission.size = Vector2(300, 82)
	btn_permission.pressed.connect(handle_authorize)
	add_child(btn_permission)

	var btn_skip := TextureButton.new()
	btn_skip.texture_normal = BTN_SKIP
	btn_skip.position = Vector2(210, 1030)
	btn_skip.size = Vector2(300, 82)
	btn_skip.pressed.connect(handle_skip)
	add_child(btn_skip)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _returning_from_settings:
		_returning_from_settings = false
		# 延迟检查，等 Android 系统刷新权限状态
		call_deferred("_check_and_proceed")

func _add_background() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/art/ui/permission.png")
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	bg.stretch_mode = TextureRect.STRETCH_KEEP
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func handle_back() -> bool:
	return true

func handle_authorize() -> void:
	_open_settings()

func handle_skip() -> void:
	UIManager.replace("res://scenes/S02_Loading.tscn")

## —— 内部函数 ——

func _open_settings() -> void:
	_returning_from_settings = true
	var sc := Engine.get_singleton("StepCounter")
	if sc and sc.has_method("openAppSettings"):
		sc.call("openAppSettings")

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
		SaveManager.save_all()
		UIManager.replace("res://scenes/S02_Loading.tscn")
		return
	# 权限还没刷新，最多重试 3 次，每次间隔 0.5s
	_retry_count += 1
	if _retry_count < 3:
		await get_tree().create_timer(0.5).timeout
		_check_and_proceed()
	else:
		_retry_count = 0  # 放弃，用户可手动点按钮
