extends "res://ui/UIPage.gd"

const SPLASH_SECONDS := 2.0
const LOADING_BAR_SIZE := Vector2(600.0, 8.0)
const FIRST_TIME_SECONDS := 10.0 * 60.0

var _progress := 0.0

func _ready() -> void:
	super._ready()
	var tween := create_tween()
	tween.tween_property(self, "_progress", 1.0, SPLASH_SECONDS)
	tween.tween_callback(queue_redraw)
	set_process(true)
	await get_tree().create_timer(SPLASH_SECONDS).timeout
	if not is_inside_tree():
		return
	if _is_first_time():
		UIManager.replace("res://scenes/S01_Onboarding.tscn")
		call_deferred("queue_free")
	else:
		UIManager.replace("res://scenes/S02_Loading.tscn")
		call_deferred("queue_free")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_CEMENT)

	var center := screen / 2.0
	draw_ellipse(center + Vector2(0.0, 24.0), 48.0, 38.0, Palette.AMBER)
	for offset in [
		Vector2(-36.0, -14.0),
		Vector2(-14.0, -34.0),
		Vector2(14.0, -34.0),
		Vector2(36.0, -14.0),
	]:
		draw_circle(center + offset, 12.0, Palette.AMBER)

	var text_y := center.y + 90.0
	draw_line(Vector2(center.x - 60.0, text_y), Vector2(center.x + 60.0, text_y), Palette.TEXT_PRIMARY, 2.0)

	var bar_pos := Vector2((screen.x - LOADING_BAR_SIZE.x) * 0.5, screen.y - 180.0)
	draw_rect(Rect2(bar_pos, LOADING_BAR_SIZE), Palette.BORDER_DEFAULT)
	draw_rect(Rect2(bar_pos, Vector2(LOADING_BAR_SIZE.x * clamp(_progress, 0.0, 1.0), LOADING_BAR_SIZE.y)), Palette.AMBER)

func _is_first_time() -> bool:
	var created_at := float(EnergyEngine.created_at)
	if created_at <= 0.0:
		return true
	return Time.get_unix_time_from_system() - created_at < FIRST_TIME_SECONDS
