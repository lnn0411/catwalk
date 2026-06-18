extends "res://ui/UIPage.gd"

const SPLASH_SECONDS := 2.0
const FIRST_TIME_SECONDS := 10.0 * 60.0

func _ready() -> void:
	super._ready()
	var debug_rect := ColorRect.new()
	debug_rect.color = Color(1, 0, 0, 0.3)
	debug_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(debug_rect)
	_add_background()
	await get_tree().create_timer(SPLASH_SECONDS).timeout
	if not is_inside_tree():
		return
	if _is_first_time():
		UIManager.replace("res://scenes/S01_Onboarding.tscn")
		call_deferred("queue_free")
	else:
		UIManager.replace("res://scenes/S02_Loading.tscn")
		call_deferred("queue_free")

func _add_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/ui/splash.png")
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	bg.stretch_mode = TextureRect.STRETCH_KEEP
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	print('SPLASH: texture=%s size=%s' % [bg.texture, bg.texture.get_size() if bg.texture else 'NULL'])
	add_child(bg)

func _is_first_time() -> bool:
	var created_at := float(EnergyEngine.created_at)
	if created_at <= 0.0:
		return true
	return Time.get_unix_time_from_system() - created_at < FIRST_TIME_SECONDS
