extends "res://ui/UIPage.gd"

const LOADING_BAR_SIZE := Vector2(600.0, 8.0)
const LOAD_DELAY_SECONDS := 1.5
const LOAD_TIMEOUT_SECONDS := 5.0

var _progress := 0.0
var _spinner_angle := 0.0
var _load_finished := false
var _timed_out := false

func _ready() -> void:
	super._ready()
	set_process(true)
	var tween := create_tween()
	tween.tween_property(self, "_progress", 1.0, LOAD_DELAY_SECONDS)
	_start_timeout()
	await get_tree().create_timer(LOAD_DELAY_SECONDS).timeout
	if not is_inside_tree() or _timed_out:
		return
	_restore_save()

func _process(delta: float) -> void:
	_spinner_angle = fmod(_spinner_angle + delta * 4.0, TAU)
	queue_redraw()

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_CEMENT)
	_draw_centered_text("花园正在等你回来……", screen.y * 0.40, 28, Palette.TEXT_PRIMARY)
	draw_arc(screen / 2.0 + Vector2(0.0, 120.0), 42.0, _spinner_angle, _spinner_angle + PI * 1.45, 36, Palette.AMBER, 6.0)

	var bar_pos := Vector2((screen.x - LOADING_BAR_SIZE.x) * 0.5, screen.y - 260.0)
	draw_rect(Rect2(bar_pos, LOADING_BAR_SIZE), Palette.BORDER_DEFAULT)
	draw_rect(Rect2(bar_pos, Vector2(LOADING_BAR_SIZE.x * clamp(_progress, 0.0, 1.0), LOADING_BAR_SIZE.y)), Palette.AMBER)

func _start_timeout() -> void:
	var timer := get_tree().create_timer(LOAD_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if _load_finished or not is_inside_tree():
			return
		_timed_out = true
		UIManager.replace("res://scenes/S90_NetworkError.tscn")
	)

func _restore_save() -> void:
	if SaveManager == null:
		UIManager.replace("res://scenes/S90_NetworkError.tscn")
		return
	SaveManager.load_and_apply()
	_load_finished = true
	if _days_since_last_open() >= 3:
		UIManager.replace("res://scenes/S92_SleepReturn.tscn")
		return

	var _cats_empty := HatchEngine == null or HatchEngine.get_cats().is_empty()
	UIManager.replace("res://scenes/S04_GardenMain.tscn")

func _days_since_last_open() -> int:
	var last_key := ""
	if SaveManager != null:
		last_key = String(SaveManager._config.get_value("energy", "last_energy_date", ""))
	if last_key == "":
		last_key = String(EnergyEngine.last_energy_date)
	if last_key == "" and float(EnergyEngine.created_at) > 0.0:
		var elapsed := Time.get_unix_time_from_system() - float(EnergyEngine.created_at)
		return int(floor(elapsed / float(24 * 60 * 60)))
	if last_key.length() < 10:
		return 0

	var date_parts := last_key.split("-")
	if date_parts.size() != 3:
		return 0
	var last_time := Time.get_unix_time_from_datetime_dict({
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"hour": 0,
		"minute": 0,
		"second": 0,
	})
	var today := Time.get_date_dict_from_system()
	var today_time := Time.get_unix_time_from_datetime_dict({
		"year": int(today["year"]),
		"month": int(today["month"]),
		"day": int(today["day"]),
		"hour": 0,
		"minute": 0,
		"second": 0,
	})
	return max(int(floor((today_time - last_time) / float(24 * 60 * 60))), 0)

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((get_viewport_rect().size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
