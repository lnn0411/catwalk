extends Node2D

const GardenBackground := preload("res://scenes/GardenBackground.gd")

var cat_container: Node2D
var debug_panel
var toggle_button: TextureButton
var _dragging: bool = false
var _drag_start: Vector2
var _camera: Camera2D

# GDD v2.17：MultiMeshInstance2D 花海合批渲染
var _flower_multimesh: MultiMeshInstance2D
var _flower_count: int = 0

func _ready() -> void:
	_build_parallax_background()
	_build_flower_field()
	_build_cat_container()
	_build_camera()
	_connect_cat_spawner()
	_build_debug_panel()
	_build_debug_toggle()

func _build_parallax_background() -> void:
	var parallax := ParallaxBackground.new()
	add_child(parallax)

	_add_background_layer(parallax, Vector2(0.05, 0.0), GardenBackground.LAYER_FAR)
	_add_background_layer(parallax, Vector2(0.3, 0.0), GardenBackground.LAYER_MID)
	_add_background_layer(parallax, Vector2(0.8, 0.0), GardenBackground.LAYER_NEAR)

func _add_background_layer(parent: ParallaxBackground, motion_scale: Vector2, layer_type: int) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = motion_scale
	parent.add_child(layer)

	var background := GardenBackground.new()
	background.layer_type = layer_type
	background.scale = Vector2(1.0, 1.0)
	layer.add_child(background)

func _build_cat_container() -> void:
	cat_container = Node2D.new()
	cat_container.name = "CatContainer"
	cat_container.position = Vector2(0.0, 384.0)
	add_child(cat_container)

func _build_camera() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(1024.0, 768.0)
	add_child(camera)
	camera.make_current()
	_camera = camera

func _connect_cat_spawner() -> void:
	if CatSpawner:
		CatSpawner.set_cat_container(cat_container)

func _build_debug_panel() -> void:
	# GDD v2.17：通过代码创建 DebugPanel，附加配饰滑块脚本
	var dbg_script := load("res://scenes/DebugPanel.gd")
	if dbg_script:
		debug_panel = Control.new()
		debug_panel.set_script(dbg_script)
		debug_panel.visible = false
		debug_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(debug_panel)

func _build_debug_toggle() -> void:

# ── GDD v2.17 MultiMeshInstance2D 花海合批渲染 ──

func _build_flower_field() -> void:
	# 创建 MultiMeshInstance2D 节点，所有花朵合批为 1 个 Draw Call
	_flower_multimesh = MultiMeshInstance2D.new()
	_flower_multimesh.name = "FlowerField"
	add_child(_flower_multimesh)

	var multimesh := MultiMesh.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(32.0, 32.0)
	multimesh.mesh = quad
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0
	_flower_multimesh.multimesh = multimesh
	_flower_multimesh.texture = _make_flower_texture()
	_flower_count = 0

func _make_flower_texture() -> Texture2D:
	# 程序化 16x16 花朵纹理（单朵花，颜色随机）
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2i(16, 16)
	var colors := [
		Color(1.0, 0.4, 0.6, 1.0),  # 粉色
		Color(1.0, 0.9, 0.2, 1.0),  # 黄色
		Color(1.0, 1.0, 1.0, 1.0),  # 白色
		Color(0.6, 0.3, 1.0, 1.0),  # 紫色
		Color(1.0, 0.5, 0.3, 1.0),  # 橙色
	]
	var col := colors[randi() % colors.size()]
	# 画 5 个花瓣圆
	for angle_deg in [0, 72, 144, 216, 288]:
		var rad := deg_to_rad(float(angle_deg))
		var px := center.x + int(cos(rad) * 8.0)
		var py := center.y + int(sin(rad) * 8.0)
		for dx in range(-4, 5):
			for dy in range(-4, 5):
				var cx := px + dx
				var cy := py + dy
				if cx >= 0 and cx < 32 and cy >= 0 and cy < 32:
					if Vector2(cx - px, cy - py).length() <= 4.0:
						img.set_pixel(cx, cy, col)
	# 画花蕊
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var cx := center.x + dx
			var cy := center.y + dy
			if cx >= 0 and cx < 32 and cy >= 0 and cy < 32:
				if Vector2(dx, dy).length() <= 3.0:
					img.set_pixel(cx, cy, Color(1.0, 0.9, 0.1, 1.0))
	var tex := ImageTexture.create_from_image(img)
	return tex

# 供工坊/外部调用：种植一朵花
func add_flower(x: float, y: float, color_hint: Color = Color.WHITE) -> void:
	if _flower_multimesh == null:
		return
	var mm := _flower_multimesh.multimesh
	_flower_count += 1
	mm.instance_count = _flower_count
	var t := Transform2D(0.0, Vector2(x, y))
	mm.set_instance_transform_2d(_flower_count - 1, t)

func _build_debug_toggle() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugToggleLayer"
	add_child(canvas)

	toggle_button = TextureButton.new()
	var debug_formal := "res://assets/art/ui/buttons/btn_debug.png"
	var debug_fallback := "res://assets/temp/ui/btn_debug.png"
	var debug_tex: Texture2D
	if ResourceLoader.exists(debug_formal):
		debug_tex = load(debug_formal)
	else:
		debug_tex = load(debug_fallback)
	toggle_button.texture_normal = debug_tex
	toggle_button.texture_pressed = debug_tex
	toggle_button.texture_hover = debug_tex
	toggle_button.custom_minimum_size = Vector2(96.0, 96.0)
	toggle_button.size = Vector2(96.0, 96.0)
	toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle_button.position = Vector2(-112.0, -112.0)
	toggle_button.pressed.connect(_on_debug_toggle_pressed)
	canvas.add_child(toggle_button)

func _on_debug_toggle_pressed() -> void:
	if debug_panel:
		debug_panel.visible = not debug_panel.visible

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

	_camera.position = Vector2(
		clampf(_camera.position.x, 360.0, 2048.0 - 360.0),
		clampf(_camera.position.y, 640.0, 1536.0 - 640.0)
	)
