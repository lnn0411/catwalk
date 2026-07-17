extends Control

signal finished

const POPUP_BG := preload("res://assets/art/ui/panels/popup_bg.png")
const BTN_EXPLORE_NORMAL := preload("res://assets/art/ui/catcard/btn_explore_normal.png")
const BTN_EXPLORE_HOVER := preload("res://assets/art/ui/catcard/btn_explore_hover.png")
const BTN_EXPLORE_PRESSED := preload("res://assets/art/ui/catcard/btn_explore_pressed.png")
const PANEL_SIZE := Vector2(560, 280)

var _cat_name := "猫咪"
var _reward_type := "postcard"


func _ready() -> void:
	name = "ExploreReturnAnimation"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func play(cat_name: String, reward_type: String) -> void:
	_cat_name = cat_name
	_reward_type = reward_type
	_refresh_labels()

	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18)
	tween.tween_interval(1.5)

	var ok_btn := get_node_or_null("Panel/OkBtn") as TextureButton
	if ok_btn:
		ok_btn.visible = true
		ok_btn.disabled = false


func _refresh_labels() -> void:
	var name_lbl := get_node_or_null("Panel/Box/NameLabel") as Label
	var reward_lbl := get_node_or_null("Panel/Box/RewardLabel") as Label
	if name_lbl:
		name_lbl.text = "%s 回来了" % _cat_name
	if reward_lbl:
		reward_lbl.text = _reward_text(_reward_type)


func _reward_text(reward_type: String) -> String:
	match reward_type:
		"ingredient":    return "带回了食材"
		"decoration":    return "发现了装饰"
		"postcard":      return "寄回了一张明信片"
		"hidden":        return "找到了隐藏惊喜"
		_:               return "带回了礼物"


func _build_ui() -> void:
	# 遮罩
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(dim)

	# 面板
	var panel := TextureRect.new()
	panel.name = "Panel"
	panel.texture = POPUP_BG
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	_center_control(panel, PANEL_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	# 内容
	var box := VBoxContainer.new()
	box.name = "Box"
	box.anchor_left = 0.0
	box.anchor_top = 0.0
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 28
	box.offset_top = 20
	box.offset_right = -28
	box.offset_bottom = -60
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	# "XXX 回来了"
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color("#4F453C"))
	name_lbl.add_theme_font_size_override("font_size", 28)
	box.add_child(name_lbl)

	# 奖励描述
	var reward_lbl := Label.new()
	reward_lbl.name = "RewardLabel"
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reward_lbl.add_theme_color_override("font_color", Color("#A2978C"))
	reward_lbl.add_theme_font_size_override("font_size", 22)
	box.add_child(reward_lbl)

	# 确定按钮
	var ok_btn := TextureButton.new()
	ok_btn.name = "OkBtn"
	ok_btn.custom_minimum_size = Vector2(200, 50)
	ok_btn.texture_normal = BTN_EXPLORE_NORMAL
	ok_btn.texture_hover = BTN_EXPLORE_HOVER
	ok_btn.texture_pressed = BTN_EXPLORE_PRESSED
	ok_btn.ignore_texture_size = true
	ok_btn.stretch_mode = TextureButton.STRETCH_SCALE
	ok_btn.visible = false
	ok_btn.disabled = true
	ok_btn.position = Vector2((PANEL_SIZE.x - 200) * 0.5, PANEL_SIZE.y - 70)
	ok_btn.pressed.connect(_on_ok)
	panel.add_child(ok_btn)

	var ok_label := Label.new()
	ok_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ok_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ok_label.text = "好的"
	ok_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ok_label.add_theme_font_size_override("font_size", 18)
	ok_label.add_theme_color_override("font_color", Color("#4F453C"))
	ok_btn.add_child(ok_label)


func _on_ok() -> void:
	finished.emit()


func _center_control(control: Control, control_size: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -control_size.x * 0.5
	control.offset_top = -control_size.y * 0.5
	control.offset_right = control_size.x * 0.5
	control.offset_bottom = control_size.y * 0.5
