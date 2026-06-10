extends Node

const DIALOG_SIZE := Vector2(760.0, 360.0)
const TOAST_SIZE := Vector2(760.0, 96.0)

static func show_exit_confirm() -> void:
	show_confirm("离开花园", "确定要离开花园吗？", func() -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.quit()
	)

static func show_confirm(title: String, content: String, on_confirm: Callable) -> void:
	var root := _get_root()
	if root == null:
		return
	var overlay := DialogOverlay.new()
	overlay.title = title
	overlay.content = content
	overlay.confirm_callback = on_confirm
	root.add_child(overlay)

static func show_toast(message: String) -> void:
	var root := _get_root()
	if root == null:
		return
	var toast := ToastOverlay.new()
	toast.message = message
	root.add_child(toast)

static func show_info(message: String) -> void:
	show_confirm("提示", message, Callable())

static func _get_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root

class DialogOverlay:
	extends Control

	var title := ""
	var content := ""
	var confirm_callback: Callable
	var _font: Font
	var _cancel_rect := Rect2()
	var _confirm_rect := Rect2()

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = ThemeDB.fallback_font
		modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.16)

	func _gui_input(event: InputEvent) -> void:
		var pressed := false
		var point := Vector2.ZERO
		if event is InputEventScreenTouch and event.pressed:
			pressed = true
			point = event.position
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed = true
			point = event.position
		if not pressed:
			return

		if _cancel_rect.has_point(point):
			_close()
			accept_event()
		elif _confirm_rect.has_point(point):
			if confirm_callback.is_valid():
				confirm_callback.call()
			_close()
			accept_event()

	func _draw() -> void:
		var shade := Palette.TEXT_PRIMARY
		shade.a = 0.5
		draw_rect(Rect2(Vector2.ZERO, size), shade, true)

		var dialog := Rect2((size - DIALOG_SIZE) * 0.5, DIALOG_SIZE)
		draw_rect(dialog, Palette.BG_WARM_WHITE, true)
		draw_rect(dialog, Palette.BORDER_DEFAULT, false, 2.0)

		var title_size := 32
		var body_size := 24
		var button_size := 24
		var title_width := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
		draw_string(_font, Vector2(dialog.position.x + (dialog.size.x - title_width) * 0.5, dialog.position.y + 84.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Palette.TEXT_PRIMARY)

		var content_width := _font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, body_size).x
		draw_string(_font, Vector2(dialog.position.x + (dialog.size.x - content_width) * 0.5, dialog.position.y + 168.0), content, HORIZONTAL_ALIGNMENT_LEFT, -1, body_size, Palette.TEXT_SECONDARY)

		_cancel_rect = Rect2(dialog.position + Vector2(92.0, 252.0), Vector2(240.0, 64.0))
		_confirm_rect = Rect2(dialog.position + Vector2(dialog.size.x - 332.0, 252.0), Vector2(240.0, 64.0))
		_draw_button(_cancel_rect, "取消", false, button_size)
		_draw_button(_confirm_rect, "确认", true, button_size)

	func _draw_button(rect: Rect2, text: String, active: bool, font_size: int) -> void:
		draw_rect(rect, Palette.AMBER if active else Palette.BG_CEMENT, true)
		draw_rect(rect, Palette.BORDER_ACTIVE if active else Palette.BORDER_DEFAULT, false, 2.0)
		var color := Palette.TEXT_ON_AMBER if active else Palette.TEXT_PRIMARY
		var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(_font, Vector2(rect.position.x + (rect.size.x - text_size.x) * 0.5, rect.position.y + 41.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	func _close() -> void:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.14)
		tween.finished.connect(queue_free)

class ToastOverlay:
	extends Control

	var message := ""
	var _font: Font
	var _panel_rect := Rect2()

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font
		position.y = -TOAST_SIZE.y
		modulate.a = 0.0
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position:y", 0.0, 0.2)
		tween.parallel().tween_property(self, "modulate:a", 1.0, 0.2)
		tween.tween_interval(3.0)
		tween.tween_property(self, "modulate:a", 0.0, 0.25)
		tween.parallel().tween_property(self, "position:y", -TOAST_SIZE.y, 0.25)
		tween.finished.connect(queue_free)

	func _draw() -> void:
		_panel_rect = Rect2(Vector2((size.x - TOAST_SIZE.x) * 0.5, 36.0), TOAST_SIZE)
		draw_rect(_panel_rect, Palette.BG_WARM_WHITE, true)
		draw_rect(_panel_rect, Palette.BORDER_ACTIVE, false, 2.0)
		draw_circle(_panel_rect.position + Vector2(48.0, 48.0), 18.0, Palette.AMBER)
		draw_circle(_panel_rect.position + Vector2(48.0, 48.0), 8.0, Palette.BG_WARM_WHITE)
		var font_size := 24
		draw_string(_font, _panel_rect.position + Vector2(88.0, 58.0), message, HORIZONTAL_ALIGNMENT_LEFT, _panel_rect.size.x - 120.0, font_size, Palette.TEXT_PRIMARY)
