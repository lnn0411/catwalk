extends Node2D

const GardenBackground := preload("res://scenes/GardenBackground.gd")

var cat_container: Node2D
var debug_panel
var toggle_button: Button

func _ready() -> void:
	_build_parallax_background()
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

func _connect_cat_spawner() -> void:
	if CatSpawner:
		CatSpawner.set_cat_container(cat_container)

func _build_debug_panel() -> void:
	var packed = load("res://scenes/DebugPanel.tscn")
	if packed:
		debug_panel = packed.instantiate()
		debug_panel.visible = false
		add_child(debug_panel)

func _build_debug_toggle() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugToggleLayer"
	add_child(canvas)

	toggle_button = Button.new()
	toggle_button.text = "⚙️"
	toggle_button.custom_minimum_size = Vector2(48.0, 48.0)
	toggle_button.size = Vector2(48.0, 48.0)
	toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle_button.position = Vector2(-64.0, -64.0)
	toggle_button.pressed.connect(_on_debug_toggle_pressed)
	_style_toggle_button(toggle_button)
	canvas.add_child(toggle_button)

func _style_toggle_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.11, 0.1, 0.5)
	normal.set_corner_radius_all(24)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.12, 0.11, 0.1, 0.7)
	hover.set_corner_radius_all(24)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.12, 0.11, 0.1, 0.85)
	pressed.set_corner_radius_all(24)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	button.add_theme_font_size_override("font_size", 24)

func _on_debug_toggle_pressed() -> void:
	if debug_panel:
		debug_panel.visible = not debug_panel.visible
