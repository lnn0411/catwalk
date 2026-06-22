extends "res://ui/UIPage.gd"

const SLEEP_RETURN_BG := preload("res://assets/art/ui/sleep_return_bg.png")
const BTN_CONTINUE_PATH := "res://assets/art/ui/btn_continue.png"

var _continue_rect := Rect2()
var _days := 0
var _have_gui := false

func _ready() -> void:
	super._ready()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	%ContinueBtn.pressed.connect(_on_continue_pressed)
	# 美术按钮就位时显示 TextureButton，否则隐藏并 fallback 到 _draw()
	if ResourceLoader.exists(BTN_CONTINUE_PATH):
		%ContinueBtn.texture_normal = load(BTN_CONTINUE_PATH)
		%ContinueBtn.visible = true
	else:
		%ContinueBtn.visible = false
		_have_gui = true

func _on_viewport_size_changed() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x > 0 and vp_size.y > 0:
		await get_tree().process_frame
		size = vp_size
		queue_redraw()

func _on_continue_pressed() -> void:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")

func _on_page_setup(data: Dictionary) -> void:
	_days = int(data.get("days", _days_since_last_open()))

func _draw() -> void:
	var screen := get_viewport_rect().size
	if not %Bg.visible:  # 背景美术未就位时才用代码铺底
		draw_texture_rect(SLEEP_RETURN_BG, Rect2(Vector2.ZERO, screen), false)
	_draw_centered_text("欢迎回来", 650.0, 36, Palette.TEXT_PRIMARY)
	_draw_centered_text("你离开了 %d 天" % _days, 730.0, 28, Palette.TEXT_SECONDARY)
	_draw_centered_text("花园还在等你", 790.0, 24, Palette.TEXT_SECONDARY)
	_continue_rect = Rect2(Vector2((screen.x - 480.0) * 0.5, 990.0), Vector2(480.0, 70.0))
	if _have_gui:
		_draw_button(_continue_rect, "继续")

func _draw_button(rect: Rect2, text: String, fill: Color = Palette.BG_WARM_WHITE, 
		border: Color = Palette.BORDER_DEFAULT, text_color: Color = Palette.TEXT_PRIMARY) -> void:
	_draw_round_rect(rect, 8.0, fill, border, 1.5)
	_draw_text_in_rect(text, rect, 18, text_color)

func _draw_round_rect(rect: Rect2, _radius: float, bg: Color, border: Color, border_width: float) -> void:
	draw_rect(rect, bg, true)
	if border_width > 0.0:
		draw_rect(rect, border, false, border_width)

func _gui_input(event: InputEvent) -> void:
	if _have_gui and event is InputEventMouseButton and event.pressed:
		if _continue_rect.has_point(event.position):
			_on_continue_pressed()
			accept_event()

func _days_since_last_open() -> int:
	if EnergyEngine == null:
		return 0
	var elapsed: float = max(Time.get_unix_time_from_system() - EnergyEngine.created_at, 0.0)
	return int(floor(elapsed / float(24 * 60 * 60)))

func _released_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and not event.pressed:
		return event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		return event.position
	return null

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((get_viewport_rect().size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_text_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, rect.position + Vector2((rect.size.x - size.x) * 0.5, (rect.size.y + size.y) * 0.5 - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
