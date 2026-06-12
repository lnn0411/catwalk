class_name BottomNav
extends Control

signal tab_selected(index: int)

const BAR_HEIGHT := 56.0
const MIN_TOUCH := 48.0
const UI_TEXTURE_PATH := "res://assets/temp/ui/"
const TABS := [
	{"label": "花园", "page": "res://scenes/S04_GardenMain.tscn", "icon": "home"},
	{"label": "图鉴", "page": "res://scenes/S10_Album.tscn", "icon": "album"},
	{"label": "商店", "page": "", "icon": "shop"},
	{"label": "好友", "page": "", "icon": "friend"},
	{"label": "设置", "page": "res://scenes/S11_Settings.tscn", "icon": "settings"},
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

	# 导航底：程序绘制圆角浮岛 + 纸纹理底（深暖棕配色不变）
	var nav_paper := TextureRect.new()
	nav_paper.texture = load("res://assets/temp/ui/paper_texture.png")
	nav_paper.stretch_mode = TextureRect.STRETCH_TILE
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
	var _label: Label
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
		_icon.custom_minimum_size = Vector2(28.0, 28.0)
		_icon.stretch_mode = TextureRect.STRETCH_SCALE
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.anchor_left = 0.5
		_icon.anchor_right = 0.5
		_icon.offset_left = -14.0
		_icon.offset_right = 14.0
		_icon.offset_top = 8.0
		_icon.offset_bottom = 36.0
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)

		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 13)
		_label.anchor_right = 1.0
		_label.offset_top = 36.0
		_label.offset_bottom = BottomNav.BAR_HEIGHT
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

	func update_state() -> void:
		if _icon == null or _label == null:
			return
		var active := index == nav.current_index
		var icon_name := String(BottomNav.TABS[index]["icon"])
		var suffix := "_active" if active else ""
		_icon.texture = load(BottomNav.UI_TEXTURE_PATH + "nav_%s%s.png" % [icon_name, suffix])
		_label.text = String(BottomNav.TABS[index]["label"])
		_label.add_theme_color_override("font_color", Palette.AMBER if active else Palette.TEXT_SECONDARY)
		_active_bar.visible = active

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			nav._on_tab_pressed(index)
			accept_event()
