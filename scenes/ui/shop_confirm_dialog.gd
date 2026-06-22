extends Control

const DIALOG_SIZE := Vector2(507.0, 420.0)
const DESIGN_SIZE := Vector2(720.0, 1280.0)

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
	modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.16)

	var font := ThemeDB.fallback_font
	# Backdrop
	var shade := Color(Palette.TEXT_PRIMARY)
	shade.a = 0.5
	var backdrop := ColorRect.new()
	backdrop.color = shade
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	# Dialog card
	var dialog := PanelContainer.new()
	dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dialog.custom_minimum_size = DIALOG_SIZE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Palette.BG_WARM_WHITE
	bg.set_corner_radius_all(8)
	bg.set_border_width_all(1)
	bg.border_color = Palette.BORDER_DEFAULT
	bg.shadow_color = Palette.UI_SHADOW_MID
	bg.shadow_size = 8
	dialog.add_theme_stylebox_override("panel", bg)
	add_child(dialog)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 8)
	dialog.add_child(vb)

	# Title
	var title := Label.new()
	title.text = "确认购买？"
	title.add_theme_font_size_override("font_size", 21)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	vb.add_child(title)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vb.add_child(spacer)

	# Product info
	var icon := String(product.get("icon", "🎁"))
	var pname := String(product.get("name", ""))
	var pdesc := String(product.get("desc", ""))
	var price := int(product.get("price", 0))
	var cur := String(product.get("cur", "gold"))
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
	nl.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	info.add_child(nl)

	var dl := Label.new()
	dl.text = pdesc
	dl.add_theme_font_size_override("font_size", 14)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	info.add_child(dl)

	var pl := Label.new()
	pl.text = "%s %d" % [cur_icon, price]
	pl.add_theme_font_size_override("font_size", 20)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.add_theme_color_override("font_color", Palette.AMBER)
	info.add_child(pl)

	# Spacer
	vb.add_child(Control.new())

	# Buttons row
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	hb.custom_minimum_size.y = 48
	vb.add_child(hb)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.pressed.connect(_on_cancel_clicked)
	_style_button(cancel_btn, Palette.BG_CEMENT, Palette.TEXT_PRIMARY)
	hb.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "确认购买"
	confirm_btn.custom_minimum_size = Vector2(140, 44)
	confirm_btn.pressed.connect(_on_confirm_clicked)
	_style_button(confirm_btn, Palette.AMBER, Palette.TEXT_ON_AMBER)
	hb.add_child(confirm_btn)

func _style_button(btn: Button, bg_color: Color, text_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_font_size_override("font_size", 16)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = bg_color.darkened(0.15)
	pressed.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)

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
