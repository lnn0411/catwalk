extends "res://ui/UIPage.gd"

const GardenBackground := preload("res://scenes/GardenBackground.gd")
const CatSpriteScene := preload("res://scenes/CatSprite.tscn")
const BottomNav := preload("res://ui/BottomNav.gd")
const BottomNavScene := preload("res://ui/BottomNav.tscn")

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const HUD_HEIGHT := 192.0
const GARDEN_HEIGHT := 768.0
const ACTION_HEIGHT := 64.0
const HATCH_HEIGHT := 53.0
const NAV_HEIGHT := 37.0
const CONTENT_SCALE := 0.72

var garden_layer: Node2D
var cat_container: Node2D
var _back_rect := Rect2()

# 美术图占位框架：art 就位则用 TextureRect/TextureButton，否则回退到代码绘制的视差花园。
const ART_BG_PATH := "res://assets/art/ui/readonly_bg.png"
const ART_BACK_BTN_PATH := "res://assets/art/ui/buttons/btn_back.png"

var _art_bg := false
var _art_back_btn := false

func _ready() -> void:
	super()
	_build_art_layers()
	_build_garden_layer()
	_restore_read_only_cats()
	_build_hud()

# 用 load() 而非 preload()：美术图可能尚未就位，preload 缺文件会编译失败。
# bg 作为首个子节点加入，绘制顺序在最底，覆盖在其下的视差花园按 _art_bg 跳过。
func _build_art_layers() -> void:
	if ResourceLoader.exists(ART_BG_PATH):
		var bg := TextureRect.new()
		bg.name = "ArtBg"
		bg.texture = load(ART_BG_PATH)
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.show_behind_parent = true
		add_child(bg)
		_art_bg = true
	if ResourceLoader.exists(ART_BACK_BTN_PATH):
		_art_back_btn = true

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

func _build_garden_layer() -> void:
	garden_layer = Node2D.new()
	garden_layer.name = "GardenLayer"
	garden_layer.position = Vector2(0.0, HUD_HEIGHT)
	add_child(garden_layer)

	if not _art_bg:  # 背景美术未就位时才铺代码绘制的视差花园
		var parallax := ParallaxBackground.new()
		garden_layer.add_child(parallax)
		_add_background_layer(parallax, Vector2(0.05, 0.0), GardenBackground.LAYER_FAR)
		_add_background_layer(parallax, Vector2(0.3, 0.0), GardenBackground.LAYER_MID)
		_add_background_layer(parallax, Vector2(0.8, 0.0), GardenBackground.LAYER_NEAR)

	cat_container = Node2D.new()
	cat_container.name = "CatContainer"
	cat_container.position = Vector2(0.0, 256.0)
	garden_layer.add_child(cat_container)

	var camera := Camera2D.new()
	camera.position = Vector2(520.0, 460.0)
	camera.zoom = Vector2(CONTENT_SCALE, CONTENT_SCALE)
	garden_layer.add_child(camera)
	camera.make_current()

func _add_background_layer(parent: ParallaxBackground, motion_scale: Vector2, layer_type: int) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = motion_scale
	parent.add_child(layer)

	var background := GardenBackground.new()
	background.layer_type = layer_type
	layer.add_child(background)

func _restore_read_only_cats() -> void:
	if HatchEngine == null:
		return
	var index := 0
	for cat_data in HatchEngine.get_cats():
		var cat = CatSpriteScene.instantiate()
		cat.cat_data = cat_data
		cat.breed = cat_data.species
		cat.position = Vector2(187.0 + float(index % 3) * 280.0, 280.0 + float(index / 3) * 120.0)
		cat_container.add_child(cat)
		cat.call_deferred("set_process_input", false)
		call_deferred("_disable_cat_input", cat)
		index += 1

func _disable_cat_input(node: Node) -> void:
	if node is Area2D:
		node.input_pickable = false
	for child in node.get_children():
		_disable_cat_input(child)

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top_bar := ColorRect.new()
	top_bar.color = Palette.BG_WARM_WHITE
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.size = Vector2(DESIGN_SIZE.x, HUD_HEIGHT)
	root.add_child(top_bar)

	_back_rect = Rect2(Vector2(28.0, 59.0), Vector2(85.0, 48.0))
	if _art_back_btn:
		var back_art := TextureButton.new()
		back_art.name = "ArtBackBtn"
		back_art.texture_normal = load(ART_BACK_BTN_PATH)
		back_art.texture_pressed = back_art.texture_normal
		back_art.texture_hover = back_art.texture_normal
		back_art.stretch_mode = TextureButton.STRETCH_SCALE
		back_art.position = _back_rect.position
		back_art.size = _back_rect.size
		back_art.pressed.connect(UIManager.go_back)
		root.add_child(back_art)
	else:
		var back := Button.new()
		back.text = "返回"
		back.flat = true
		back.position = _back_rect.position
		back.size = _back_rect.size
		back.add_theme_font_size_override("font_size", 16)
		back.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		back.pressed.connect(UIManager.go_back)
		root.add_child(back)

	var top_row := HBoxContainer.new()
	top_row.position = Vector2(113.0, 63.0)
	top_row.size = Vector2(DESIGN_SIZE.x - 134.0, 61.0)
	top_row.add_theme_constant_override("separation", 16)
	root.add_child(top_row)

	var steps := Label.new()
	steps.text = "👣 --- 步"
	steps.custom_minimum_size = Vector2(167.0, 48.0)
	steps.add_theme_font_size_override("font_size", 19)
	steps.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	top_row.add_child(steps)

	var energy := ReadOnlyEnergyMeter.new()
	energy.custom_minimum_size = Vector2(200.0, 32.0)
	top_row.add_child(energy)

	var currency := Label.new()
	currency.text = "💰 ---   💎 ---   🌸 ---"
	currency.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	currency.add_theme_font_size_override("font_size", 16)
	currency.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	top_row.add_child(currency)

	var message := Label.new()
	message.text = "它们走不过来了。去设置里开一扇门 →"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.position = Vector2(0.0, HUD_HEIGHT + GARDEN_HEIGHT * 0.42)
	message.size = Vector2(DESIGN_SIZE.x, 53.0)
	message.add_theme_font_size_override("font_size", 16)
	message.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	root.add_child(message)

	var action_row := HBoxContainer.new()
	action_row.position = Vector2(32.0, HUD_HEIGHT + GARDEN_HEIGHT + 9.0)
	action_row.size = Vector2(DESIGN_SIZE.x - 64.0, ACTION_HEIGHT)
	action_row.add_theme_constant_override("separation", 11)
	root.add_child(action_row)
	for title in ["喂食", "抚摸", "玩耍", "拍照"]:
		var button := DisabledActionButton.new()
		button.text = title
		button.disabled = true
		button.custom_minimum_size = Vector2(147.0, 43.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(button)

	var hatch_row := HBoxContainer.new()
	hatch_row.position = Vector2(21.0, DESIGN_SIZE.y - NAV_HEIGHT - HATCH_HEIGHT)
	hatch_row.size = Vector2(DESIGN_SIZE.x - 43.0, HATCH_HEIGHT)
	hatch_row.add_theme_constant_override("separation", 8)
	root.add_child(hatch_row)
	for i in range(4):
		var slot := LockedSlotView.new()
		slot.custom_minimum_size = Vector2(160.0, HATCH_HEIGHT)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hatch_row.add_child(slot)

	var nav = BottomNavScene.instantiate()
	nav.set_current_tab(0)
	nav.tab_selected.connect(_on_bottom_nav_tab_selected)
	root.add_child(nav)

func _on_bottom_nav_tab_selected(index: int) -> void:
	if index < 0 or index >= BottomNav.TABS.size():
		return
	var page := String(BottomNav.TABS[index]["page"])
	if page != "":
		UIManager.replace(page)

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

class ReadOnlyEnergyMeter:
	extends Control

	func _draw() -> void:
		var bar_rect := Rect2(0.0, 8.0, 200.0, 16.0)
		draw_rect(bar_rect, Palette.BORDER_DEFAULT, true)
		draw_rect(bar_rect, Palette.TEXT_SECONDARY, false, 1.0)
		var font := ThemeDB.fallback_font
		var text := "---/---"
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(font, Vector2((bar_rect.size.x - text_size.x) * 0.5, 21.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.TEXT_SECONDARY)

class DisabledActionButton:
	extends Button

	func _ready() -> void:
		flat = true
		add_theme_font_size_override("font_size", 16)
		add_theme_color_override("font_color", Palette.TEXT_SECONDARY)

	func _draw() -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.BORDER_DEFAULT
		style.border_color = Palette.BORDER_DEFAULT
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		draw_style_box(style, Rect2(Vector2.ZERO, size))

class LockedSlotView:
	extends Control

	func _draw() -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.BG_WARM_WHITE
		style.border_color = Palette.BORDER_DEFAULT
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		draw_style_box(style, Rect2(Vector2.ZERO, size))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(12.0, 23.0), "🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.TEXT_SECONDARY)
		draw_rect(Rect2(11.0, size.y - 13.0, size.x - 21.0, 5.0), Palette.BORDER_DEFAULT, true)
