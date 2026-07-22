extends Control

signal closed

const POPUP_BG := preload("res://assets/art/ui/panels/popup_bg.png")
const BTN_CONFIRM := preload("res://assets/art/ui/incubation/components/btn_confirm_name.png")

var _cat_name := "猫咪"
var _reward_type := "postcard"
var _title: Label
var _body: Label
var _card: Control
var _spotlight_badge: ColorRect
var _spotlight_active := false
var _postcard_id := ""
var _art_placeholder: ColorRect
var _art_texture: TextureRect


func _ready() -> void:
	name = "PostcardReveal"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_text()


func reveal(cat_name: String, reward_type: String, spotlight_location_type: String = "", postcard_data: Dictionary = {}, postcard_id: String = "") -> void:
	_cat_name = cat_name
	_reward_type = reward_type
	_postcard_id = postcard_id
	if spotlight_location_type != "" or not postcard_data.is_empty():
		set_spotlight(spotlight_location_type, postcard_data)
	if is_inside_tree():
		_refresh_text()
	_load_postcard_image(_postcard_id)


func set_spotlight(spotlight_location_type: String, postcard_data: Dictionary = {}) -> void:
	var active := false
	var postcard_location := String(postcard_data.get("location_type", ""))
	if postcard_location != "":
		active = postcard_location == spotlight_location_type
	else:
		active = false
	_spotlight_active = active
	if is_inside_tree():
		_refresh_spotlight_visual()


func _build_ui() -> void:
	# 遮罩
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	add_child(dim)

	_card = Control.new()
	_center_control(_card, Vector2(560, 320))
	add_child(_card)

	# 面板底图
	var panel := TextureRect.new()
	panel.texture = POPUP_BG
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	# 顶部内边距容器
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 30)
	top_margin.add_theme_constant_override("margin_left", 24)
	top_margin.add_theme_constant_override("margin_right", 24)
	box.add_child(top_margin)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_theme_constant_override("separation", 12)
	top_margin.add_child(inner_vbox)

	# 标题
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color("#4F453C"))
	_title.add_theme_font_size_override("font_size", 27)
	inner_vbox.add_child(_title)

	# 图片区（占位 + 明信片贴图）
	_art_placeholder = ColorRect.new()
	_art_placeholder.custom_minimum_size = Vector2(0, 100)
	_art_placeholder.color = Color(0.92, 0.88, 0.82, 0.6)
	_art_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(_art_placeholder)

	_art_texture = TextureRect.new()
	_art_texture.custom_minimum_size = Vector2(0, 300)
	_art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art_texture.visible = false
	inner_vbox.add_child(_art_texture)

	# 描述
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", Color("#7A6E63"))
	_body.add_theme_font_size_override("font_size", 16)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(_body)

	# 收下按钮
	var ok_btn := TextureButton.new()
	ok_btn.name = "OkBtn"
	ok_btn.custom_minimum_size = Vector2(170, 70)
	ok_btn.texture_normal = BTN_CONFIRM
	ok_btn.ignore_texture_size = true
	ok_btn.stretch_mode = TextureButton.STRETCH_SCALE
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(func() -> void:
		closed.emit()
	)
	inner_vbox.add_child(ok_btn)

	# Text label for button (normal label since btn_explore has no text)
	var ok_label := Label.new()
	ok_label.name = "OkLabel"
	ok_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ok_label.text = "收下"
	ok_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ok_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ok_label.add_theme_color_override("font_color", Color("#4F453C"))
	ok_label.add_theme_font_size_override("font_size", 18)
	ok_btn.add_child(ok_label)

	# 聚光灯角标
	_spotlight_badge = ColorRect.new()
	_spotlight_badge.custom_minimum_size = Vector2(60, 60)
	_spotlight_badge.size = Vector2(60, 60)
	_spotlight_badge.anchor_left = 1.0
	_spotlight_badge.anchor_top = 0.0
	_spotlight_badge.anchor_right = 1.0
	_spotlight_badge.anchor_bottom = 0.0
	_spotlight_badge.offset_left = -76
	_spotlight_badge.offset_top = 16
	_spotlight_badge.offset_right = -16
	_spotlight_badge.offset_bottom = 76
	_spotlight_badge.color = Color(1.0, 0.85, 0.4, 0.9)
	_spotlight_badge.visible = false
	_card.add_child(_spotlight_badge)

	var badge_label := Label.new()
	badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge_label.text = "🌟 本周聚光"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badge_label.add_theme_color_override("font_color", Color.WHITE)
	badge_label.add_theme_font_size_override("font_size", 11)
	_spotlight_badge.add_child(badge_label)
	_refresh_spotlight_visual()


func _load_postcard_image(postcard_id: String) -> void:
	if _art_texture == null:
		return
	if postcard_id == "":
		_art_texture.visible = false
		if _art_placeholder != null:
			_art_placeholder.visible = true
		return
	var tex: Texture2D = null
	var res_path := "res://assets/art/postcards/" + postcard_id + ".png"
	if ResourceLoader.exists(res_path):
		tex = load(res_path) as Texture2D
	if tex == null:
		var img := Image.new()
		var abs_path := ProjectSettings.globalize_path(res_path)
		if img.load(abs_path) == OK:
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_art_texture.texture = tex
		_art_texture.visible = true
		if _art_placeholder != null:
			_art_placeholder.visible = false
	else:
		_art_texture.visible = false
		if _art_placeholder != null:
			_art_placeholder.visible = true


func _refresh_text() -> void:
	if _title == null or _body == null:
		return
	_title.text = _title_text(_reward_type)
	_body.text = "%s %s" % [_cat_name, _body_text(_reward_type)]
	_refresh_spotlight_visual()


func _refresh_spotlight_visual() -> void:
	if _spotlight_badge != null:
		_spotlight_badge.visible = _spotlight_active


func _title_text(reward_type: String) -> String:
	match reward_type:
		"ingredient": return "新食材"
		"decoration": return "新装饰"
		"hidden":     return "隐藏发现"
		_:           return "城市明信片"


func _body_text(reward_type: String) -> String:
	match reward_type:
		"ingredient": return "带回了一份可以收藏的探索食材。"
		"decoration": return "找到了适合小窝的新装饰灵感。"
		"hidden":     return "发现了一处平时看不见的秘密角落。"
		_:           return "从城市的一角寄回了新的风景。"


func _center_control(control: Control, control_size: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -control_size.x * 0.5
	control.offset_top = -control_size.y * 0.5
	control.offset_right = control_size.x * 0.5
	control.offset_bottom = control_size.y * 0.5
