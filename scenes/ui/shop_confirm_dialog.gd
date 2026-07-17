extends Control

const POPUP_BG := preload("res://assets/art/ui/panels/popup_bg.png")
const BTN_CONFIRM := preload("res://assets/art/ui/incubation/components/btn_confirm_name.png")
const BTN_SECONDARY := preload("res://assets/art/ui/incubation/components/btn_secondary_blank.png")
const DIALOG_SIZE := Vector2(560, 380)
const TEXT_PRIMARY := Color("#4F453C")
const TEXT_SECONDARY := Color("#A2978C")

var product: Dictionary = {}
var on_confirm: Callable
var on_cancel: Callable


func setup(p: Dictionary, confirm_cb: Callable, cancel_cb: Callable) -> void:
	product = p
	on_confirm = confirm_cb
	on_cancel = cancel_cb
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 淡入
	modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.16)

	# 遮罩
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_backdrop_input)
	add_child(shade)

	# 弹窗面板
	var card := Control.new()
	_center_control(card, DIALOG_SIZE)
	add_child(card)

	var panel := TextureRect.new()
	panel.texture = POPUP_BG
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(panel)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 30)
	outer_margin.add_theme_constant_override("margin_right", 30)
	outer_margin.add_theme_constant_override("margin_top", 30)
	outer_margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(outer_margin)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	outer_margin.add_child(vb)

	# Title
	var title := Label.new()
	title.text = "确认购买？"
	title.add_theme_font_size_override("font_size", 27)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	vb.add_child(title)

	# Spacer
	vb.add_child(Control.new())

	# Product info
	var icon: String = String(product.get("icon", "🎁"))
	var pname: String = String(product.get("name", ""))
	var pdesc: String = String(product.get("desc", ""))
	var price := int(product.get("price", 0))
	var cur: String = String(product.get("cur", "gold"))
	var cur_icon: String = String({"diamonds": "💎", "gold": "💰", "petals": "🌸"}.get(cur, "💎"))

	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	vb.add_child(info)

	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(icon_label)

	var nl := Label.new()
	nl.text = pname
	nl.add_theme_font_size_override("font_size", 18)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.add_theme_color_override("font_color", TEXT_PRIMARY)
	info.add_child(nl)

	var dl := Label.new()
	dl.text = pdesc
	dl.add_theme_font_size_override("font_size", 14)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.add_theme_color_override("font_color", TEXT_SECONDARY)
	info.add_child(dl)

	var pl := Label.new()
	pl.text = "%s %d" % [cur_icon, price]
	pl.add_theme_font_size_override("font_size", 20)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.add_theme_color_override("font_color", Color("#D89B42"))
	info.add_child(pl)

	# 撑满
	vb.add_child(Control.new())

	# 按钮行
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)

	# 取消按钮
	var cancel_btn := TextureButton.new()
	cancel_btn.custom_minimum_size = Vector2(170, 70)
	cancel_btn.texture_normal = BTN_SECONDARY
	cancel_btn.ignore_texture_size = true
	cancel_btn.stretch_mode = TextureButton.STRETCH_SCALE
	cancel_btn.pressed.connect(_on_cancel_clicked)
	hb.add_child(cancel_btn)

	var cancel_label := Label.new()
	cancel_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cancel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cancel_label.text = "取消"
	cancel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cancel_label.add_theme_font_size_override("font_size", 18)
	cancel_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	cancel_btn.add_child(cancel_label)

	# 确认购买按钮
	var confirm_btn := TextureButton.new()
	confirm_btn.custom_minimum_size = Vector2(170, 70)
	confirm_btn.texture_normal = BTN_CONFIRM
	confirm_btn.ignore_texture_size = true
	confirm_btn.stretch_mode = TextureButton.STRETCH_SCALE
	confirm_btn.pressed.connect(_on_confirm_clicked)
	hb.add_child(confirm_btn)

	var confirm_label := Label.new()
	confirm_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_label.text = "确认购买"
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirm_label.add_theme_font_size_override("font_size", 18)
	confirm_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	confirm_btn.add_child(confirm_label)


func _center_control(control: Control, control_size: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -control_size.x * 0.5
	control.offset_top = -control_size.y * 0.5
	control.offset_right = control_size.x * 0.5
	control.offset_bottom = control_size.y * 0.5


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel_clicked()


func _on_confirm_clicked() -> void:
	if on_confirm.is_valid():
		on_confirm.call()
	_close()


func _on_cancel_clicked() -> void:
	if on_cancel.is_valid():
		on_cancel.call()
	_close()


func _close() -> void:
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.14)
	fade.finished.connect(queue_free)
