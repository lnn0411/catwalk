class_name BottomNav
extends Control

signal tab_selected(index: int)

const BAR_HEIGHT := 56.0
const MIN_TOUCH := 48.0
const UI_TEXTURE_PATH := "res://assets/temp/ui/"
const TABS := [
	{"icon": "garden", "page": "res://scenes/S04_GardenMain.tscn"},
	{"icon": "book", "page": "res://scenes/S10_Album.tscn"},
	{"icon": "shop", "page": ""},
	{"icon": "friends", "page": ""},
	{"icon": "settings", "page": "res://scenes/S11_Settings.tscn"},
]

var current_index := 0
var _buttons: Array[Control] = []

func _ready() -> void:
	custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = -BAR_HEIGHT
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_tabs()

func set_current_tab(index: int) -> void:
	current_index = clampi(index, 0, TABS.size() - 1)
	for button in _buttons:
		button.update_state()

func get_target_page(index: int) -> String:
	if index < 0 or index >= TABS.size():
		return ""
	return String(TABS[index]["page"])

func _build_tabs() -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()

	# 导航底：nav_bg.png 整图缩放铺底
	var nav_paper := TextureRect.new()
	nav_paper.texture = load("res://assets/art/ui/nav/nav_bg.png")
	nav_paper.stretch_mode = TextureRect.STRETCH_SCALE
	nav_paper.custom_minimum_size = Vector2(720.0, 56.0)
	nav_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nav_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nav_paper)

	var bg := Panel.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(Palette.BG_CEMENT, 0.97)
	bg_style.corner_radius_top_left = 24
	bg_style.corner_radius_top_right = 24
	bg_style.border_width_top = 1
	bg_style.border_color = Palette.BORDER_DEFAULT
	bg_style.shadow_color = Palette.UI_SHADOW
	bg_style.shadow_size = 10
	bg_style.shadow_offset = Vector2(0.0, -3.0)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	add_child(box)

	for i in range(TABS.size()):
		var tab := NavTab.new()
		tab.index = i
		tab.nav = self
		tab.custom_minimum_size = Vector2(MIN_TOUCH, BAR_HEIGHT)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(tab)
		_buttons.append(tab)

func _on_tab_pressed(index: int) -> void:
	set_current_tab(index)
	tab_selected.emit(index)
	if index == 2 or index == 3:
		Popups.show_info("即将开放")

class NavTab:
	extends Control

	var index := 0
	var nav: BottomNav
	var _icon: TextureRect
	var _active_bar: ColorRect

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(BottomNav.MIN_TOUCH, BottomNav.BAR_HEIGHT)
		_build_visuals()
		update_state()

	func _build_visuals() -> void:
		_active_bar = ColorRect.new()
		_active_bar.color = Palette.BORDER_ACTIVE
		_active_bar.anchor_right = 1.0
		_active_bar.offset_bottom = 3.0
		_active_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_active_bar)

		_icon = TextureRect.new()
		_icon.custom_minimum_size = Vector2(50.0, 50.0)
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.anchor_left = 0.5
		_icon.anchor_right = 0.5
		_icon.offset_left = -25.0
		_icon.offset_right = 25.0
		_icon.offset_top = 6.0
		_icon.offset_bottom = 56.0
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)

	func update_state() -> void:
		if _icon == null:
			return
		var active := index == nav.current_index
		var icon_name := String(BottomNav.TABS[index]["icon"])
		var suffix := "_off" if not active else ""
		var file_name := "nav_%s%s.png" % [icon_name, suffix]
		var formal_path := "res://assets/art/ui/nav/" + file_name
		var fallback_path := BottomNav.UI_TEXTURE_PATH + file_name
		if ResourceLoader.exists(formal_path):
			_icon.texture = load(formal_path)
		else:
			_icon.texture = load(fallback_path)
		_active_bar.visible = active

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			nav._on_tab_pressed(index)
			accept_event()
