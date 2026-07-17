extends Control

signal finished

const CATCARD_PANEL := preload("res://assets/art/ui/catcard/catcard_panel.png")
const CLOSE_NORMAL := preload("res://assets/art/ui/catcard/btn_close_normal.png")
const CLOSE_HOVER := preload("res://assets/art/ui/catcard/btn_close_hover.png")
const PANEL_SIZE := Vector2(600, 320)
const BTN_CLOSE_SIZE := Vector2(44, 44)

var _cat_name := "猫咪"
var _reward_type := "postcard"
var _cat_species := ""
var _cat_level := 1


func _ready() -> void:
	name = "ExploreReturnAnimation"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func play(cat_name: String, reward_type: String, species: String = "", level: int = 1) -> void:
	_cat_name = cat_name
	_reward_type = reward_type
	_cat_species = species
	_cat_level = level
	_refresh_labels()

	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18)
	tween.tween_interval(1.5)
	var close_btn := get_node_or_null("Panel/CloseBtn") as TextureButton
	if close_btn:
		close_btn.disabled = false
		close_btn.visible = true


func _refresh_labels() -> void:
	var name_lbl := get_node_or_null("Panel/Margin/VBox/NameLabel") as Label
	var reward_lbl := get_node_or_null("Panel/Margin/VBox/RewardLabel") as Label
	_set_text(name_lbl, "%s 回来了" % _cat_name)
	_set_text(reward_lbl, _reward_text(_reward_type))


func _set_text(label: Label, text: String) -> void:
	if label:
		label.text = text


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
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(dim)

	# 面板容器
	var panel := TextureRect.new()
	panel.name = "Panel"
	panel.texture = CATCARD_PANEL
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	# 关闭按钮
	var close_btn := TextureButton.new()
	close_btn.name = "CloseBtn"
	close_btn.texture_normal = CLOSE_NORMAL
	close_btn.texture_hover = CLOSE_HOVER
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.custom_minimum_size = BTN_CLOSE_SIZE
	close_btn.position = Vector2(PANEL_SIZE.x - BTN_CLOSE_SIZE.x - 10, 10)
	close_btn.disabled = true
	close_btn.visible = false
	close_btn.pressed.connect(_on_close)
	panel.add_child(close_btn)

	# 内容区
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# "XXX 回来了"
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(0.31, 0.27, 0.24, 1))
	name_lbl.add_theme_font_size_override("font_size", 30)
	vbox.add_child(name_lbl)

	# 奖励描述
	var reward_lbl := Label.new()
	reward_lbl.name = "RewardLabel"
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reward_lbl.add_theme_color_override("font_color", Color(0.64, 0.59, 0.55, 1))
	reward_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(reward_lbl)


func _on_close() -> void:
	finished.emit()
