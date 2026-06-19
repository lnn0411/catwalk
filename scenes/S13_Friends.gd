extends "res://ui/UIPage.gd"

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const FRIENDS_BG_PATH := "res://assets/art/ui/friends_bg.png"

var _back_rect: Rect2 = Rect2()

func _ready() -> void:
	super._ready()
	_build_background()
	%BackBtn.pressed.connect(_on_back)

func _on_back() -> void:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")

func _gui_input(event: InputEvent) -> void:
	if _is_back_event(event):
		UIManager.replace("res://scenes/S04_GardenMain.tscn")
		accept_event()
		return

	var pos: Variant = _released_position(event)
	if pos == null:
		return
	var point: Vector2 = pos
	if _back_rect.has_point(point):
		UIManager.replace("res://scenes/S04_GardenMain.tscn")

func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	if not %Bg.visible:
		draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE, true)
	_draw_top_bar()
	_draw_centered_text("好友系统即将开放", DESIGN_SIZE.y * 0.5, 22, Palette.TEXT_SECONDARY)

func _build_background() -> void:
	%Bg.visible = ResourceLoader.exists(FRIENDS_BG_PATH)
	if %Bg.visible:
		%Bg.texture = load(FRIENDS_BG_PATH)

func _draw_top_bar() -> void:
	_back_rect = Rect2(Vector2(28.0, 59.0), Vector2(85.0, 48.0))
	_draw_button(_back_rect, "返回", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_centered_text("好友", 91.0, 24, Palette.TEXT_PRIMARY)

func _released_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and not event.pressed:
		return event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		return event.position
	return null

func _is_back_event(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_BACK
	)

func _draw_button(rect: Rect2, text: String, bg: Color, border: Color, text_color: Color) -> void:
	draw_rect(rect, bg, true)
	draw_rect(rect, border, false, 1.0)
	_draw_centered_in_rect(text, rect, 16, text_color)

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((DESIGN_SIZE.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_centered_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y + text_size.y) * 0.5 - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
