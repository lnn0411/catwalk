extends Node2D

const GARDEN_SCALE := 0.351
const GARDEN_SIZE := Vector2(2048.0, 1536.0)
const GARDEN_SCALED_SIZE := GARDEN_SIZE * GARDEN_SCALE
const VIEWPORT_SIZE := Vector2(720.0, 1280.0)
const CAT_SOURCE_POSITION := Vector2(512.0, 1050.0)
const CAT_BASELINE_Y := 460.0

const GARDEN_FAR_PATH := "res://assets/art/garden/layers/garden_far.png"
const GARDEN_MID_PATH := "res://assets/art/garden/layers/garden_mid.png"
const GARDEN_NEAR_PATH := "res://assets/art/garden/layers/garden_near.png"
const CAT_IDLE_00_PATH := "res://assets/art/cats/orange_tabby/idle_00.png"
const CAT_IDLE_01_PATH := "res://assets/art/cats/orange_tabby/idle_01.png"
const CAT_IDLE_02_PATH := "res://assets/art/cats/orange_tabby/idle_02.png"

var _camera: Camera2D
var _dragging := false
var _drag_start := Vector2.ZERO
var _cat_frames: Array[Texture2D] = []
var _cat_sprites: Array[Sprite2D] = []
var _cat_frame_index := 0
var _debug_control: Control
var _debug_label: Label


func _ready() -> void:
	_load_cat_frames()
	_build_parallax_background()
	_build_cat()
	_build_camera()
	_build_debug_info()
	_build_cat_timer()
	_update_debug_info()


func _load_cat_frames() -> void:
	var idle_00 := load(CAT_IDLE_00_PATH) as Texture2D
	assert(idle_00 != null, 'Missing asset: ' + CAT_IDLE_00_PATH)
	var idle_01 := load(CAT_IDLE_01_PATH) as Texture2D
	assert(idle_01 != null, 'Missing asset: ' + CAT_IDLE_01_PATH)
	var idle_02 := load(CAT_IDLE_02_PATH) as Texture2D
	assert(idle_02 != null, 'Missing asset: ' + CAT_IDLE_02_PATH)
	_cat_frames = [
		idle_00,
		idle_01,
		idle_02,
	]


func _process(_delta: float) -> void:
	_update_debug_info()


func _build_parallax_background() -> void:
	var parallax := ParallaxBackground.new()
	parallax.name = "ParallaxBackground"
	add_child(parallax)

	var far_texture := load(GARDEN_FAR_PATH) as Texture2D
	assert(far_texture != null, 'Missing asset: ' + GARDEN_FAR_PATH)
	var mid_texture := load(GARDEN_MID_PATH) as Texture2D
	assert(mid_texture != null, 'Missing asset: ' + GARDEN_MID_PATH)
	var near_texture := load(GARDEN_NEAR_PATH) as Texture2D
	assert(near_texture != null, 'Missing asset: ' + GARDEN_NEAR_PATH)

	_add_garden_layer(parallax, "FarLayer", Vector2(0.05, 0.0), far_texture)
	_add_garden_layer(parallax, "MidLayer", Vector2(0.3, 0.0), mid_texture)
	_add_garden_layer(parallax, "NearLayer", Vector2(0.8, 0.0), near_texture)


func _add_garden_layer(parent: ParallaxBackground, layer_name: String, motion_scale: Vector2, texture: Texture2D) -> void:
	var layer := ParallaxLayer.new()
	layer.name = layer_name
	layer.motion_scale = motion_scale
	parent.add_child(layer)

	var sprite := Sprite2D.new()
	sprite.name = "%sSprite" % layer_name.trim_suffix("Layer")
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(GARDEN_SCALE, GARDEN_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	layer.add_child(sprite)


func _build_cat() -> void:
	var cat_anchor := Node2D.new()
	cat_anchor.name = "OrangeTabbyIdle"
	cat_anchor.position = CAT_SOURCE_POSITION * GARDEN_SCALE
	add_child(cat_anchor)

	for i in range(_cat_frames.size()):
		var frame_sprite := Sprite2D.new()
		frame_sprite.name = "Idle%02d" % i
		frame_sprite.texture = _cat_frames[i]
		frame_sprite.centered = false
		frame_sprite.offset = Vector2(-256.0, -CAT_BASELINE_Y)
		frame_sprite.scale = Vector2(GARDEN_SCALE, GARDEN_SCALE)
		frame_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		frame_sprite.visible = i == _cat_frame_index
		cat_anchor.add_child(frame_sprite)
		_cat_sprites.append(frame_sprite)


func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.position = GARDEN_SCALED_SIZE * 0.5
	add_child(_camera)
	_camera.make_current()


func _build_debug_info() -> void:
	_debug_control = Control.new()
	_debug_control.name = "DebugInfo"
	_debug_control.top_level = true
	_debug_control.size = Vector2(244.0, 52.0)
	add_child(_debug_control)

	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_debug_label.size = _debug_control.size
	_debug_control.add_child(_debug_label)


func _build_cat_timer() -> void:
	var timer := Timer.new()
	timer.name = "CatFrameTimer"
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_on_cat_frame_timer_timeout)
	add_child(timer)


func _on_cat_frame_timer_timeout() -> void:
	_cat_sprites[_cat_frame_index].visible = false
	_cat_frame_index = (_cat_frame_index + 1) % _cat_frames.size()
	_cat_sprites[_cat_frame_index].visible = true
	_update_debug_info()


func _update_debug_info() -> void:
	if not _debug_label or not _debug_control or not _camera:
		return

	_debug_control.global_position = _camera.position + Vector2(
		VIEWPORT_SIZE.x * 0.5 - _debug_control.size.x - 16.0,
		-VIEWPORT_SIZE.y * 0.5 + 16.0
	)
	_debug_label.text = "frame: %d\ncamera: (%.1f, %.1f)" % [
		_cat_frame_index,
		_camera.position.x,
		_camera.position.y,
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = get_global_mouse_position()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging and _camera:
		var drag_delta := get_global_mouse_position() - _drag_start
		_camera.position -= drag_delta
		_clamp_camera_to_world()
		_drag_start = get_global_mouse_position()


func _clamp_camera_to_world() -> void:
	if not _camera:
		return

	var half_viewport := VIEWPORT_SIZE * 0.5
	var camera_x := GARDEN_SCALED_SIZE.x * 0.5
	var camera_y := GARDEN_SCALED_SIZE.y * 0.5

	if GARDEN_SCALED_SIZE.x > VIEWPORT_SIZE.x:
		camera_x = clampf(_camera.position.x, half_viewport.x, GARDEN_SCALED_SIZE.x - half_viewport.x)
	if GARDEN_SCALED_SIZE.y > VIEWPORT_SIZE.y:
		camera_y = clampf(_camera.position.y, half_viewport.y, GARDEN_SCALED_SIZE.y - half_viewport.y)

	_camera.position = Vector2(
		camera_x,
		camera_y
	)
