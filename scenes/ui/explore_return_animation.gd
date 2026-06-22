extends Control

signal finished

var _cat_name := "猫咪"
var _reward_type := "postcard"
var _label: Label
var _reward_label: Label


func _ready() -> void:
	name = "ExploreReturnAnimation"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func play(cat_name: String, reward_type: String) -> void:
	_cat_name = cat_name
	_reward_type = reward_type
	if _label != null:
		_label.text = "%s 回来了" % _cat_name
	if _reward_label != null:
		_reward_label.text = _reward_text(_reward_type)

	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18)
	tween.tween_interval(0.85)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func() -> void:
		finished.emit()
	)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.38)
	add_child(dim)

	var box := VBoxContainer.new()
	_center_control(box, Vector2(520, 220))
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	_label = Label.new()
	_label.text = "%s 回来了" % _cat_name
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_label, 30)
	box.add_child(_label)

	_reward_label = Label.new()
	_reward_label.text = _reward_text(_reward_type)
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_reward_label, 22)
	box.add_child(_reward_label)


func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _reward_text(reward_type: String) -> String:
	match reward_type:
		"ingredient":
			return "带回了食材"
		"decoration":
			return "发现了装饰"
		"hidden":
			return "找到了隐藏惊喜"
		_:
			return "寄回了一张明信片"


func _center_control(control: Control, control_size: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -control_size.x * 0.5
	control.offset_top = -control_size.y * 0.5
	control.offset_right = control_size.x * 0.5
	control.offset_bottom = control_size.y * 0.5
