extends Node

const DIALOG_SIZE := Vector2(507.0, 240.0)
const TOAST_SIZE := Vector2(507.0, 64.0)

static var POPUP_BG_TEX: Texture2D = load("res://assets/art/ui/panels/popup_bg.png")
static var OVERLAY_MASK_TEX: Texture2D = load("res://assets/art/ui/panels/overlay_mask.png")
static var BTN_CONFIRM_TEX: Texture2D = load("res://assets/art/ui/incubation/components/btn_confirm_name.png")
static var BTN_SEC_TEX: Texture2D = load("res://assets/art/ui/incubation/components/btn_secondary_blank.png")

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
	# Close any existing dialog overlay to prevent stacking
	for child in root.get_children():
		if child is DialogOverlay:
			child.queue_free()
		elif child is CanvasLayer:
			for sub in child.get_children():
				if sub is DialogOverlay:
					child.queue_free()  # 连壳一起清，避免空 CanvasLayer 残留
					break
	var overlay := DialogOverlay.new()
	overlay.title = title
	overlay.content = content
	overlay.confirm_callback = on_confirm
	# Wrap in CanvasLayer(layer=100) to render above UIManager (layer=10)
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(overlay)
	root.add_child(canvas)

static func show_toast(message: String) -> void:
	var root := _get_root()
	if root == null:
		return
	var toast := ToastOverlay.new()
	toast.message = message
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(toast)
	root.add_child(canvas)

static func show_info(message: String) -> void:
	show_confirm("提示", message, Callable())

# 多选项引导弹窗（B3 包满弹窗等）：actions = [{label, action: Callable}, ...]。
# 任一按钮点击后关闭弹窗再执行 action；action 为空 Callable 即「稍后」。
static func show_actions(title: String, content: String, actions: Array) -> void:
	var root := _get_root()
	if root == null:
		return
	for child in root.get_children():
		if child is CanvasLayer:
			for sub in child.get_children():
				if sub is ActionsOverlay:
					child.queue_free()
					break
	var overlay := ActionsOverlay.new()
	overlay.title = title
	overlay.content = content
	overlay.actions = actions
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(overlay)
	root.add_child(canvas)

# 奖励合流（总案 §2.3）：同帧多个离散奖励合并为一条「步数惊喜」提示，
# 全局同屏奖励弹窗 ≤1。各奖励源调用本方法而不是各自 show_toast。
static var _pending_reward_lines: Array[String] = []
static var _reward_flush_scheduled: bool = false

static func queue_reward_line(line: String) -> void:
	if line == "":
		return
	_pending_reward_lines.append(line)
	if _reward_flush_scheduled:
		return
	_reward_flush_scheduled = true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_flush_reward_lines()
		return
	tree.process_frame.connect(_flush_reward_lines, CONNECT_ONE_SHOT)

static func _flush_reward_lines() -> void:
	# v1 实现（评审标注）：toast 文本合并；总案 §2.3 的「步数惊喜卡」
	# 列表式卡片样式随美术 A5_surprise_card 到货后在后续迭代落地。
	_reward_flush_scheduled = false
	if _pending_reward_lines.is_empty():
		return
	var merged := " ＋ ".join(_pending_reward_lines)
	var prefix := "🎉 步数惊喜｜" if _pending_reward_lines.size() >= 2 else "🎉 "
	_pending_reward_lines.clear()
	show_toast(prefix + merged)

static func show_input(title: String, placeholder: String, on_submit: Callable) -> void:
	var root := _get_root()
	if root == null:
		return
	var overlay := InputOverlay.new()
	overlay.title = title
	overlay.placeholder = placeholder
	overlay.submit_callback = on_submit
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(overlay)
	root.add_child(canvas)

static func _get_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root

# ------------------------------------------------------------
# 多选项引导弹窗（复用 popup_bg / btn_confirm_name 贴图规范）
# ------------------------------------------------------------
class ActionsOverlay:
	extends Control

	var title := ""
	var content := ""
	var actions: Array = []

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

		var dim := ColorRect.new()
		dim.color = Color(0.0, 0.0, 0.0, 0.45)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim)

		var panel_h: float = 220.0 + 76.0 * float(actions.size())
		var panel := TextureRect.new()
		panel.texture = load("res://assets/art/ui/panels/popup_bg.png")
		panel.stretch_mode = TextureRect.STRETCH_SCALE
		panel.custom_minimum_size = Vector2(DIALOG_SIZE.x, panel_h)
		panel.anchor_left = 0.5
		panel.anchor_right = 0.5
		panel.anchor_top = 0.5
		panel.anchor_bottom = 0.5
		panel.offset_left = -DIALOG_SIZE.x * 0.5
		panel.offset_right = DIALOG_SIZE.x * 0.5
		panel.offset_top = -panel_h * 0.5
		panel.offset_bottom = panel_h * 0.5
		add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 36.0
		vbox.offset_right = -36.0
		vbox.offset_top = 30.0
		vbox.offset_bottom = -30.0
		vbox.add_theme_constant_override("separation", 14)
		panel.add_child(vbox)

		var title_label := Label.new()
		title_label.text = title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 24)
		title_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		vbox.add_child(title_label)

		var content_label := Label.new()
		content_label.text = content
		content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_label.add_theme_font_size_override("font_size", 16)
		content_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		vbox.add_child(content_label)

		for entry in actions:
			var action: Dictionary = Dictionary(entry)
			var btn := TextureButton.new()
			btn.texture_normal = load("res://assets/art/ui/incubation/components/btn_confirm_name.png")
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_SCALE
			btn.custom_minimum_size = Vector2(280.0, 62.0)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var btn_label := Label.new()
			btn_label.text = String(action.get("label", ""))
			btn_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			btn_label.add_theme_font_size_override("font_size", 18)
			btn_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
			btn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(btn_label)
			var callback: Callable = action.get("action", Callable())
			btn.pressed.connect(func() -> void:
				_close()
				if callback.is_valid():
					callback.call()
			)
			vbox.add_child(btn)

	func _close() -> void:
		var canvas := get_parent()
		if canvas is CanvasLayer:
			canvas.queue_free()
		else:
			queue_free()

# ------------------------------------------------------------
# 输入弹窗（贴图版）
# ------------------------------------------------------------
class InputOverlay:
	extends Control

	var title := ""
	var placeholder := ""
	var submit_callback: Callable
	var _input: LineEdit

	func _ready() -> void:
		var _popup_bg: Texture2D = load("res://assets/art/ui/panels/popup_bg.png")
		var _overlay_mask: Texture2D = load("res://assets/art/ui/panels/overlay_mask.png")
		var _btn_confirm: Texture2D = load("res://assets/art/ui/incubation/components/btn_confirm_name.png")
		var _btn_sec: Texture2D = load("res://assets/art/ui/incubation/components/btn_secondary_blank.png")

		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.16)

		# Shade
		var shade := TextureRect.new()
		shade.texture = _overlay_mask
		shade.modulate.a = 1.0
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)

		# Popup container — 600×300
		var popup := Control.new()
		popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		popup.offset_left = -300
		popup.offset_top = -150
		popup.offset_right = 300
		popup.offset_bottom = 150
		popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(popup)

		# Popup bg — stretch to 600×300
		var bg := TextureRect.new()
		bg.texture = _popup_bg
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(bg)

		# Title
		var title_label := Label.new()
		title_label.text = title
		title_label.anchor_left = 0.0
		title_label.anchor_right = 1.0
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.offset_left = 60
		title_label.offset_right = -60
		title_label.offset_top = 35
		title_label.offset_bottom = 75
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.add_theme_font_size_override("font_size", 22)
		title_label.add_theme_color_override("font_color", Color(0.36, 0.23, 0.12, 1))
		popup.add_child(title_label)

		# Input field — 560px wide
		_input = LineEdit.new()
		_input.placeholder_text = placeholder
		_input.anchor_left = 0.0
		_input.anchor_right = 1.0
		_input.offset_left = 20
		_input.offset_right = -20
		_input.offset_top = 95
		_input.offset_bottom = 136
		_input.add_theme_font_size_override("font_size", 16)
		_input.add_theme_color_override("font_color", Color(0.36, 0.23, 0.12, 1))
		# StyleBox for input
		var input_bg := StyleBoxFlat.new()
		input_bg.bg_color = Color(0.98, 0.96, 0.93, 1)
		input_bg.border_width_left = 2
		input_bg.border_width_top = 2
		input_bg.border_width_right = 2
		input_bg.border_width_bottom = 2
		input_bg.border_color = Color(0.84, 0.79, 0.70, 1)
		input_bg.set_corner_radius_all(12)
		_input.add_theme_stylebox_override("normal", input_bg)
		_input.max_length = 16
		_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_input.caret_blink = true
		popup.add_child(_input)
		_input.grab_focus()

		# Cancel button
		var cancel_btn := TextureButton.new()
		cancel_btn.texture_normal = _btn_sec
		cancel_btn.offset_left = 75
		cancel_btn.offset_top = 210
		cancel_btn.offset_right = 230
		cancel_btn.offset_bottom = 274
		cancel_btn.ignore_texture_size = true
		cancel_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		cancel_btn.pressed.connect(_close)
		popup.add_child(cancel_btn)

		var cancel_label := Label.new()
		cancel_label.text = "取消"
		cancel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cancel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cancel_label.offset_left = 75
		cancel_label.offset_top = 210
		cancel_label.offset_right = 230
		cancel_label.offset_bottom = 274
		cancel_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		cancel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cancel_label.add_theme_font_size_override("font_size", 18)
		cancel_label.add_theme_color_override("font_color", Color(0.36, 0.23, 0.12, 1))
		popup.add_child(cancel_label)

		# Confirm button
		var confirm_btn := TextureButton.new()
		confirm_btn.texture_normal = _btn_confirm
		confirm_btn.offset_left = 350
		confirm_btn.offset_top = 210
		confirm_btn.offset_right = 505
		confirm_btn.offset_bottom = 274
		confirm_btn.ignore_texture_size = true
		confirm_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		confirm_btn.pressed.connect(_on_submit)
		popup.add_child(confirm_btn)

		var confirm_label := Label.new()
		confirm_label.text = "确认"
		confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		confirm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		confirm_label.offset_left = 350
		confirm_label.offset_top = 210
		confirm_label.offset_right = 505
		confirm_label.offset_bottom = 274
		confirm_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		confirm_label.add_theme_font_size_override("font_size", 18)
		confirm_label.add_theme_color_override("font_color", Color("#4F453C"))
		popup.add_child(confirm_label)

	func _on_submit() -> void:
		var text := _input.text.strip_edges()
		if text.is_empty():
			return
		if submit_callback.is_valid():
			submit_callback.call(text)
		_close()

	func _close() -> void:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.14)
		tween.finished.connect(func() -> void:
			var p := get_parent()
			if p is CanvasLayer:
				p.queue_free()
			else:
				queue_free()
		)

# ------------------------------------------------------------
# 确认弹窗（贴图版）
# ------------------------------------------------------------
class DialogOverlay:
	extends Control

	var title := ""
	var content := ""
	var confirm_callback: Callable

	func _ready() -> void:
		var _popup_bg: Texture2D = load("res://assets/art/ui/panels/popup_bg.png")
		var _overlay_mask: Texture2D = load("res://assets/art/ui/panels/overlay_mask.png")
		var _btn_confirm: Texture2D = load("res://assets/art/ui/incubation/components/btn_confirm_name.png")
		var _btn_sec: Texture2D = load("res://assets/art/ui/incubation/components/btn_secondary_blank.png")

		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.16)

		# Shade
		var shade := TextureRect.new()
		shade.texture = _overlay_mask
		shade.modulate.a = 1.0
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)

		# Popup container — 600×300
		var popup := Control.new()
		popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		popup.offset_left = -300
		popup.offset_top = -150
		popup.offset_right = 300
		popup.offset_bottom = 150
		popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(popup)

		# Popup bg — stretch to 600×300
		var bg := TextureRect.new()
		bg.texture = _popup_bg
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(bg)

		# Title
		var title_label := Label.new()
		title_label.text = title
		title_label.anchor_left = 0.0
		title_label.anchor_right = 1.0
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.offset_left = 60
		title_label.offset_right = -60
		title_label.offset_top = 35
		title_label.offset_bottom = 75
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.add_theme_font_size_override("font_size", 22)
		title_label.add_theme_color_override("font_color", Color(0.36, 0.23, 0.12, 1))
		popup.add_child(title_label)

		# Content
		var content_label := Label.new()
		content_label.text = content
		content_label.anchor_left = 0.0
		content_label.anchor_right = 1.0
		content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_label.offset_left = 60
		content_label.offset_right = -60
		content_label.offset_top = 85
		content_label.offset_bottom = 185
		content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_label.add_theme_font_size_override("font_size", 16)
		content_label.add_theme_color_override("font_color", Color(0.36, 0.23, 0.12, 1))
		popup.add_child(content_label)

		# Cancel button
		var cancel_btn := TextureButton.new()
		cancel_btn.texture_normal = _btn_sec
		cancel_btn.offset_left = 75
		cancel_btn.offset_top = 210
		cancel_btn.offset_right = 230
		cancel_btn.offset_bottom = 274
		cancel_btn.ignore_texture_size = true
		cancel_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		cancel_btn.pressed.connect(_close)
		popup.add_child(cancel_btn)

		var cancel_label := Label.new()
		cancel_label.text = "取消"
		cancel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cancel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cancel_label.offset_left = 75
		cancel_label.offset_top = 210
		cancel_label.offset_right = 230
		cancel_label.offset_bottom = 274
		cancel_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		cancel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cancel_label.add_theme_font_size_override("font_size", 18)
		cancel_label.add_theme_color_override("font_color", Color(0.36, 0.23, 0.12, 1))
		popup.add_child(cancel_label)

		# Confirm button
		var confirm_btn := TextureButton.new()
		confirm_btn.texture_normal = _btn_confirm
		confirm_btn.offset_left = 350
		confirm_btn.offset_top = 210
		confirm_btn.offset_right = 505
		confirm_btn.offset_bottom = 274
		confirm_btn.ignore_texture_size = true
		confirm_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		confirm_btn.pressed.connect(func():
			if confirm_callback.is_valid():
				confirm_callback.call()
			_close())
		popup.add_child(confirm_btn)

		var confirm_label := Label.new()
		confirm_label.text = "确认"
		confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		confirm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		confirm_label.offset_left = 350
		confirm_label.offset_top = 210
		confirm_label.offset_right = 505
		confirm_label.offset_bottom = 274
		confirm_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		confirm_label.add_theme_font_size_override("font_size", 18)
		confirm_label.add_theme_color_override("font_color", Color("#4F453C"))
		popup.add_child(confirm_label)

	func _close() -> void:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.14)
		tween.finished.connect(func() -> void:
			var p := get_parent()
			if p is CanvasLayer:
				p.queue_free()
			else:
				queue_free()
		)

# ------------------------------------------------------------
# 吐司弹窗（保持 draw_rect 不变，不影响外观）
# ------------------------------------------------------------
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
		tween.finished.connect(_dismiss)

	func _dismiss() -> void:
		var p := get_parent()
		if p is CanvasLayer:
			p.queue_free()
		else:
			queue_free()

	func _draw() -> void:
		_panel_rect = Rect2(Vector2((size.x - TOAST_SIZE.x) * 0.5, 24.0), TOAST_SIZE)
		draw_rect(_panel_rect, Color(0.98, 0.96, 0.93, 1), true)
		draw_rect(_panel_rect, Color(0.84, 0.79, 0.70, 1), false, 1.0)
		draw_circle(_panel_rect.position + Vector2(32.0, 32.0), 12.0, Color(0.95, 0.76, 0.45, 1))
		draw_circle(_panel_rect.position + Vector2(32.0, 32.0), 5.0, Color(0.98, 0.96, 0.93, 1))
		var font_size := 16
		draw_string(_font, _panel_rect.position + Vector2(59.0, 39.0), message, HORIZONTAL_ALIGNMENT_LEFT, _panel_rect.size.x - 80.0, font_size, Color(0.3, 0.26, 0.22, 1))
