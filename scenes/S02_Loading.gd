extends "res://ui/UIPage.gd"

const LOAD_DELAY_SECONDS := 1.5
const LOAD_TIMEOUT_SECONDS := 5.0
const BAR_WIDTH := 400.0
const BAR_HEIGHT := 10.0

var _progress := 0.0
var _spinner_angle := 0.0
var _load_finished := false
var _timed_out := false

var _spinner: SpinnerArc = null
var _bar_fill: ColorRect = null

class SpinnerArc extends Control:
	var angle := 0.0

	func _draw() -> void:
		draw_arc(Vector2(64.0, 60.0), 42.0, angle, angle + PI * 1.45, 36, Color.WHITE, 6.0)

func _ready() -> void:
	super._ready()
	_add_background()
	_add_foreground()
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
	if _spinner != null:
		_spinner.angle = _spinner_angle
		_spinner.queue_redraw()
	if _bar_fill != null:
		_bar_fill.size.x = BAR_WIDTH * clamp(_progress, 0.0, 1.0)

func _add_background() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/art/ui/loading_bg.png")
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	bg.stretch_mode = TextureRect.STRETCH_KEEP
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _add_foreground() -> void:
	var label := Label.new()
	label.text = "花园正在等你回来……"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = -200.0
	label.offset_right = 200.0
	label.offset_top = 500.0
	label.offset_bottom = 540.0
	add_child(label)

	_spinner = SpinnerArc.new()
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spinner.anchor_left = 0.5
	_spinner.anchor_right = 0.5
	_spinner.anchor_top = 0.5
	_spinner.anchor_bottom = 0.5
	_spinner.offset_left = -64.0
	_spinner.offset_right = 64.0
	_spinner.offset_top = -64.0
	_spinner.offset_bottom = 64.0
	add_child(_spinner)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color.BLACK * 0.25
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.anchor_left = 0.5
	bar_bg.anchor_right = 0.5
	bar_bg.anchor_top = 1.0
	bar_bg.anchor_bottom = 1.0
	bar_bg.offset_left = -BAR_WIDTH * 0.5
	bar_bg.offset_right = BAR_WIDTH * 0.5
	bar_bg.offset_top = -200.0
	bar_bg.offset_bottom = -200.0 + BAR_HEIGHT
	add_child(bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.color = Color.WHITE
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.anchor_left = 0.5
	_bar_fill.anchor_right = 0.5
	_bar_fill.anchor_top = 1.0
	_bar_fill.anchor_bottom = 1.0
	_bar_fill.offset_left = -BAR_WIDTH * 0.5
	_bar_fill.offset_top = -200.0
	_bar_fill.offset_bottom = -200.0 + BAR_HEIGHT
	_bar_fill.size = Vector2(BAR_WIDTH * clamp(_progress, 0.0, 1.0), BAR_HEIGHT)
	add_child(_bar_fill)

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
