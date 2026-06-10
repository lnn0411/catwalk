extends "res://ui/UIPage.gd"

const ALLOW_BUTTON_SIZE := Vector2(480.0, 56.0)
const LATER_BUTTON_SIZE := Vector2(220.0, 56.0)

var _allow_rect := Rect2()
var _later_rect := Rect2()
var _requesting := false

func _ready() -> void:
	super._ready()

func handle_back() -> bool:
	return true

func _gui_input(event: InputEvent) -> void:
	if _requesting:
		return
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and not event.pressed:
		released = true
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		released = true
		pos = event.position
	if not released:
		return
	if _allow_rect.has_point(pos):
		_on_allow_pressed()
	elif _later_rect.has_point(pos):
		UIManager.replace("res://scenes/S05_ReadOnlyGarden.tscn")

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE)
	_draw_paw(Vector2(screen.x * 0.5, 330.0), 1.75)
	_draw_centered_text("允许访问步数数据", 690.0, 32, Palette.TEXT_PRIMARY)
	_draw_centered_text("我们用它来计算能量，帮你孵化猫咪", 760.0, 22, Palette.TEXT_SECONDARY)
	_draw_allow_button(screen)
	_draw_later_button(screen)

func _on_allow_pressed() -> void:
	_requesting = true
	var step_counter := Engine.get_singleton("StepCounter")
	if step_counter == null:
		_on_permission_result(false)
		return
	if step_counter.has_signal("permission_result") and not step_counter.permission_result.is_connected(_on_permission_result):
		step_counter.permission_result.connect(_on_permission_result, CONNECT_ONE_SHOT)
	if step_counter.has_method("hasActivityRecognitionPermission") and bool(step_counter.call("hasActivityRecognitionPermission")):
		_on_permission_result(true)
		return
	if step_counter.has_method("requestActivityRecognitionPermission"):
		step_counter.call("requestActivityRecognitionPermission")
	elif step_counter.has_method("request_permission"):
		step_counter.call("request_permission")
	else:
		_on_permission_result(false)

func _on_permission_result(granted: bool) -> void:
	_requesting = false
	if granted:
		SaveManager.save_all()
		UIManager.replace("res://scenes/S04_GardenMain.tscn")
		return
	var step_counter := Engine.get_singleton("StepCounter")
	if step_counter != null:
		if step_counter.has_method("isPermissionDeniedPermanently") and bool(step_counter.call("isPermissionDeniedPermanently")):
			UIManager.replace("res://scenes/S91_PermDenied.tscn")
			return
		if step_counter.has_method("is_permission_denied_permanently") and bool(step_counter.call("is_permission_denied_permanently")):
			UIManager.replace("res://scenes/S91_PermDenied.tscn")
			return
	UIManager.replace("res://scenes/S05_ReadOnlyGarden.tscn")

func _draw_paw(center: Vector2, scale_value: float) -> void:
	draw_ellipse(center + Vector2(0.0, 24.0) * scale_value, 48.0 * scale_value, 38.0 * scale_value, Palette.AMBER)
	for offset in [
		Vector2(-36.0, -14.0),
		Vector2(-14.0, -34.0),
		Vector2(14.0, -34.0),
		Vector2(36.0, -14.0),
	]:
		draw_circle(center + offset * scale_value, 12.0 * scale_value, Palette.AMBER)

func _draw_allow_button(screen: Vector2) -> void:
	_allow_rect = Rect2(Vector2((screen.x - ALLOW_BUTTON_SIZE.x) * 0.5, 980.0), ALLOW_BUTTON_SIZE)
	draw_rect(_allow_rect, Palette.AMBER)
	_draw_text_in_rect("允许", _allow_rect, 26, Palette.TEXT_ON_AMBER)

func _draw_later_button(screen: Vector2) -> void:
	_later_rect = Rect2(Vector2((screen.x - LATER_BUTTON_SIZE.x) * 0.5, screen.y - 250.0), LATER_BUTTON_SIZE)
	_draw_text_in_rect("先不了", _later_rect, 24, Palette.TEXT_SECONDARY)

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((get_viewport_rect().size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_text_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, rect.position + Vector2((rect.size.x - size.x) * 0.5, (rect.size.y + size.y) * 0.5 - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
