extends "res://ui/UIPage.gd"

const PAGE_COUNT := 3
const SWIPE_THRESHOLD := 100.0
const AUTO_ADVANCE_INTERVAL := 3.0
const START_BUTTON_SIZE := Vector2(360.0, 48.0)
const SKIP_BUTTON_SIZE := Vector2(180.0, 56.0)

const PAGE_TEXTURES := [
	preload("res://assets/art/ui/onboarding_1.png"),
	preload("res://assets/art/ui/onboarding_2.png"),
	preload("res://assets/art/ui/onboarding_3.png"),
]

var _current_page := 0
var _touch_start := Vector2.ZERO
var _tracking_touch := false
var _pages: Array[TextureRect] = []
var _start_button: Button
var _auto_timer: Timer

func _ready() -> void:
	super._ready()
	_build_pages()
	_build_buttons()
	_update_page_visibility()
	_auto_timer = Timer.new()
	_auto_timer.one_shot = true
	_auto_timer.wait_time = AUTO_ADVANCE_INTERVAL
	_auto_timer.timeout.connect(_on_auto_advance)
	add_child(_auto_timer)
	_auto_timer.start()

func handle_back() -> bool:
	return true

func _build_pages() -> void:
	for tex in PAGE_TEXTURES:
		var page := TextureRect.new()
		page.texture = tex
		page.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		page.stretch_mode = TextureRect.STRETCH_KEEP
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(page)
		_pages.append(page)

func _build_buttons() -> void:
	var screen := get_viewport_rect().size

	var skip := Button.new()
	skip.text = "跳过"
	skip.size = SKIP_BUTTON_SIZE
	skip.position = Vector2(screen.x - SKIP_BUTTON_SIZE.x - 24.0, 48.0)
	skip.pressed.connect(_on_skip_pressed)
	add_child(skip)

	_start_button = Button.new()
	_start_button.text = "🐾 开始"
	_start_button.size = START_BUTTON_SIZE
	_start_button.position = Vector2((screen.x - START_BUTTON_SIZE.x) * 0.5, screen.y - 150.0)
	_start_button.pressed.connect(_on_start_pressed)
	add_child(_start_button)

func _on_skip_pressed() -> void:
	UIManager.replace("res://scenes/S03_Permission.tscn")

func _on_start_pressed() -> void:
	UIManager.replace("res://scenes/S03_Permission.tscn")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_tracking_touch = true
		elif _tracking_touch:
			_tracking_touch = false
			_handle_release(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_start = event.position
			_tracking_touch = true
		elif _tracking_touch:
			_tracking_touch = false
			_handle_release(event.position)

func _handle_release(position: Vector2) -> void:
	var dx := position.x - _touch_start.x
	if dx < -SWIPE_THRESHOLD and _current_page < PAGE_COUNT - 1:
		_current_page += 1
		_update_page_visibility()
		_auto_timer.start()
	elif dx > SWIPE_THRESHOLD and _current_page > 0:
		_current_page -= 1
		_update_page_visibility()
		_auto_timer.start()

func _on_auto_advance() -> void:
	if _current_page >= PAGE_COUNT - 1:
		return
	_current_page += 1
	_update_page_visibility()
	if _current_page < PAGE_COUNT - 1:
		_auto_timer.start()

func _update_page_visibility() -> void:
	for i in range(_pages.size()):
		_pages[i].visible = i == _current_page
	if _start_button != null:
		_start_button.visible = _current_page == PAGE_COUNT - 1
