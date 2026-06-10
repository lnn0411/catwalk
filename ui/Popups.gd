extends Node

const DIALOG_SIZE := Vector2(507.0, 240.0)
const TOAST_SIZE := Vector2(507.0, 64.0)

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

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = ThemeDB.fallback_font
		modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.16)
		_build_buttons()

	func _build_buttons() -> void:
		var dialog := Rect2((size - DIALOG_SIZE) * 0.5, DIALOG_SIZE)
		var button_y := dialog.position.y + 168.0
		var button_h := 43.0
		var button_w := 160.0
		
		var cancel_btn := Button.new()
		cancel_btn.text = "取消"
		cancel_btn.flat = true
		cancel_btn.position = dialog.position + Vector2(61.0, 168.0)
		cancel_btn.size = Vector2(button_w, button_h)
		cancel_btn.add_theme_font_size_override("font_size", 16)
		cancel_btn.pressed.connect(_close)
		cancel_btn.z_index = 10
		add_child(cancel_btn)
		
		var confirm_btn := Button.new()
		confirm_btn.text = "确认"
		confirm_btn.flat = true
		confirm_btn.position = dialog.position + Vector2(dialog.size.x - 61.0 - button_w, 168.0)
		confirm_btn.size = Vector2(button_w, button_h)
		confirm_btn.add_theme_font_size_override("font_size", 16)
		confirm_btn.pressed.connect(func():
			if confirm_callback.is_valid():
				confirm_callback.call()
			_close())
		confirm_btn.z_index = 10
		add_child(confirm_btn)
		
		# Style both buttons
		for btn in [cancel_btn, confirm_btn]:
			var bg := StyleBoxFlat.new()
			bg.bg_color = Palette.BG_CEMENT
			bg.set_corner_radius_all(6)
			btn.add_theme_stylebox_override("normal", bg)

	func _draw() -> void:
		var shade := Palette.TEXT_PRIMARY
		shade.a = 0.5
		draw_rect(Rect2(Vector2.ZERO, size), shade, true)

		var dialog := Rect2((size - DIALOG_SIZE) * 0.5, DIALOG_SIZE)
		draw_rect(dialog, Palette.BG_WARM_WHITE, true)
		draw_rect(dialog, Palette.BORDER_DEFAULT, false, 1.0)

		var title_size := 21
		var body_size := 16
		var title_width := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
		draw_string(_font, Vector2(dialog.position.x + (dialog.size.x - title_width) * 0.5, dialog.position.y + 56.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Palette.TEXT_PRIMARY)

		var content_width := _font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, body_size).x
		draw_string(_font, Vector2(dialog.position.x + (dialog.size.x - content_width) * 0.5, dialog.position.y + 112.0), content, HORIZONTAL_ALIGNMENT_LEFT, -1, body_size, Palette.TEXT_SECONDARY)

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
		_panel_rect = Rect2(Vector2((size.x - TOAST_SIZE.x) * 0.5, 24.0), TOAST_SIZE)
		draw_rect(_panel_rect, Palette.BG_WARM_WHITE, true)
		draw_rect(_panel_rect, Palette.BORDER_ACTIVE, false, 1.0)
		draw_circle(_panel_rect.position + Vector2(32.0, 32.0), 12.0, Palette.AMBER)
		draw_circle(_panel_rect.position + Vector2(32.0, 32.0), 5.0, Palette.BG_WARM_WHITE)
		var font_size := 16
		draw_string(_font, _panel_rect.position + Vector2(59.0, 39.0), message, HORIZONTAL_ALIGNMENT_LEFT, _panel_rect.size.x - 80.0, font_size, Palette.TEXT_PRIMARY)
