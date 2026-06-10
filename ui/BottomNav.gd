class_name BottomNav
extends Control

signal tab_selected(index: int)

const BAR_HEIGHT := 56.0
const MIN_TOUCH := 48.0
const TABS := [
	{"label": "花园", "page": "res://scenes/S04_GardenMain.tscn", "icon": "home"},
	{"label": "图鉴", "page": "res://scenes/S10_Album.tscn", "icon": "album"},
	{"label": "商店", "page": "", "icon": "shop"},
	{"label": "好友", "page": "", "icon": "friends"},
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
		button.queue_redraw()

func get_target_page(index: int) -> String:
	if index < 0 or index >= TABS.size():
		return ""
	return String(TABS[index]["page"])

func _build_tabs() -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()

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

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(BottomNav.MIN_TOUCH, BottomNav.BAR_HEIGHT)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			nav._on_tab_pressed(index)
			accept_event()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			nav._on_tab_pressed(index)
			accept_event()

	func _draw() -> void:
		var active := index == nav.current_index
		var color: Color = Palette.AMBER if active else Palette.TEXT_SECONDARY
		var bg: Color = Palette.BG_WARM_WHITE
		draw_rect(Rect2(Vector2.ZERO, size), bg, true)

		var center := Vector2(size.x * 0.5, 22.0)
		_draw_icon(center, color)

		var font := ThemeDB.fallback_font
		var label := String(BottomNav.TABS[index]["label"])
		var font_size := 13
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, Vector2((size.x - text_size.x) * 0.5, 48.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

		if active:
			draw_rect(Rect2(0.0, 0.0, size.x, 3.0), Palette.BORDER_ACTIVE, true)

	func _draw_icon(center: Vector2, color: Color) -> void:
		var icon := String(BottomNav.TABS[index]["icon"])
		match icon:
			"home":
				var pts := PackedVector2Array([
					center + Vector2(-11.0, 0.0),
					center + Vector2(0.0, -10.0),
					center + Vector2(11.0, 0.0),
					center + Vector2(11.0, 11.0),
					center + Vector2(-11.0, 11.0),
					center + Vector2(-11.0, 0.0),
				])
				draw_polyline(pts, color, 2.0)
				draw_line(center + Vector2(-3.0, 11.0), center + Vector2(-3.0, 4.0), color, 2.0)
				draw_line(center + Vector2(3.0, 11.0), center + Vector2(3.0, 4.0), color, 2.0)
			"album":
				for x in range(2):
					for y in range(2):
						draw_rect(Rect2(center + Vector2(-11.0 + x * 13.0, -9.0 + y * 13.0), Vector2(8.0, 8.0)), color, false, 2.0)
			"shop":
				draw_rect(Rect2(center + Vector2(-10.0, -3.0), Vector2(20.0, 15.0)), color, false, 2.0)
				draw_arc(center + Vector2(0.0, -3.0), 6.0, PI, TAU, 12, color, 2.0)
			"friends":
				draw_circle(center + Vector2(-6.0, -3.0), 4.0, color)
				draw_circle(center + Vector2(7.0, -4.0), 4.0, color)
				draw_arc(center + Vector2(-6.0, 9.0), 8.0, PI, TAU, 14, color, 2.0)
				draw_arc(center + Vector2(7.0, 9.0), 8.0, PI, TAU, 14, color, 2.0)
			"settings":
				draw_circle(center, 8.0, color)
				draw_circle(center, 4.0, Palette.BG_WARM_WHITE)
				for i in range(8):
					var a := float(i) * TAU / 8.0
					draw_line(center + Vector2(cos(a), sin(a)) * 10.0, center + Vector2(cos(a), sin(a)) * 13.0, color, 2.0)
