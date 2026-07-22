extends Control

signal closed

const LOCATION_COLORS := {
	"park": Color(0.6, 0.8, 0.5),
	"street": Color(0.7, 0.7, 0.7),
	"cafe": Color(0.8, 0.6, 0.4),
	"sea": Color(0.4, 0.6, 0.8),
	"bookstore": Color(0.7, 0.5, 0.4),
	"flower": Color(0.9, 0.6, 0.7),
}
const CARD_SIZE := Vector2(750, 500)
const PAPER_COLOR := Color(0.96, 0.93, 0.85)

var _data
var _is_collected: bool = false
var _showing_front: bool = true
var _flipping: bool = false

var _mask: ColorRect
var _card_container: Node2D
var _card_face: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_mask = ColorRect.new()
	_mask.color = Color(0, 0, 0, 0.3)
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	_mask.gui_input.connect(_on_mask_input)
	add_child(_mask)

	_card_container = Node2D.new()
	add_child(_card_container)

	_card_face = Control.new()
	_card_face.custom_minimum_size = CARD_SIZE
	_card_face.size = CARD_SIZE
	_card_face.position = -CARD_SIZE * 0.5
	_card_face.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_face.gui_input.connect(_on_card_input)
	_card_face.draw.connect(_on_card_draw)
	_card_container.add_child(_card_face)

	# 翻转按钮（明信片底部正下方）
	var flip_btn := TextureButton.new()
	var btn_tex := load("res://assets/art/ui/incubation/components/btn_confirm_name.png")
	if btn_tex != null:
		flip_btn.texture_normal = btn_tex
		flip_btn.ignore_texture_size = true
		flip_btn.stretch_mode = TextureButton.STRETCH_SCALE
		flip_btn.custom_minimum_size = Vector2(240, 96)
	flip_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	flip_btn.position += Vector2(-120, 270)  # 卡片底部+20px 居中
	flip_btn.pressed.connect(_flip)
	flip_btn.name = "FlipButton"
	add_child(flip_btn)
	# 翻转按钮文字
	var flip_label := Label.new()
	flip_label.text = "翻  转"
	flip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flip_label.add_theme_font_size_override("font_size", 28)
	flip_label.add_theme_color_override("font_color", Color("#4F453C"))
	flip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flip_btn.add_child(flip_label)

	resized.connect(_recenter)
	_recenter()


func setup(postcard_id: String, is_collected: bool = true) -> void:
	if not is_node_ready():
		await ready
	_data = PostcardData.get_by_id(postcard_id)
	_is_collected = is_collected
	var flip_btn := get_node_or_null("FlipButton")
	if flip_btn:
		flip_btn.visible = _is_collected
	_showing_front = true
	_card_face.queue_redraw()


func set_collected(value: bool) -> void:
	_is_collected = value
	var flip_btn := get_node_or_null("FlipButton")
	if flip_btn:
		flip_btn.visible = _is_collected
	_card_face.queue_redraw()


func _recenter() -> void:
	if _card_container:
		_card_container.position = size * 0.5


func _on_mask_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_collected:
			_flip()


func _flip() -> void:
	if _flipping or not _is_collected:
		return
	_flipping = true
	var tween := create_tween()
	tween.tween_property(_card_container, "scale:x", 0.0, 0.15)
	tween.tween_callback(_swap_face)
	tween.tween_property(_card_container, "scale:x", 1.0, 0.15)
	tween.tween_callback(func(): _flipping = false)


func _swap_face() -> void:
	_showing_front = not _showing_front
	_card_face.queue_redraw()


func _close() -> void:
	closed.emit()
	queue_free()


func _on_card_draw() -> void:
	var c := _card_face
	var rect := Rect2(Vector2.ZERO, CARD_SIZE)
	var font := c.get_theme_default_font()

	if _data == null:
		c.draw_rect(rect, Color(0.5, 0.5, 0.5), true)
		_text(c, font, "数据缺失", 28, Color.WHITE, CARD_SIZE.y * 0.5)
		return

	if not _is_collected:
		# 灰色卡背
		c.draw_rect(rect, Color(0.45, 0.45, 0.45), true)
		c.draw_rect(rect, Color(0.25, 0.25, 0.25), false, 4.0)
		_text(c, font, "?", 90, Color(0.6, 0.6, 0.6), CARD_SIZE.y * 0.45)
		_text(c, font, "尚未获得此明信片", 26, Color(0.85, 0.85, 0.85), CARD_SIZE.y * 0.62)
		_text(c, font, "美术待补", 18, Color(0.7, 0.7, 0.7), CARD_SIZE.y * 0.9)
		return

	if _showing_front:
		_draw_front(c, font, rect)
	else:
		_draw_back(c, font, rect)


func _draw_front(c: Control, font: Font, rect: Rect2) -> void:
	var ltype: String = _data.location_type if "location_type" in _data else ""
	var lname: String = _data.location_name if "location_name" in _data else String(_data.id)
	
	# 尝试加载明信片贴图
	var tex_path := "res://assets/art/postcards/%s.png" % _data.id
	var tex: Texture2D = null
	# 强制走 Image.load 绝对路径，跳过 .import/.ctex 缓存（防止缓存损坏导致白图）
	var img := Image.new()
	var abs_path := ProjectSettings.globalize_path(tex_path)
	var err := img.load(abs_path)
	print("[PostcardDetail] Image.load path=", abs_path, " err=", err)
	if err == OK:
		tex = ImageTexture.create_from_image(img)
		print("[PostcardDetail] Image loaded, size: ", tex.get_size())
	
	if tex:
		print("[PostcardDetail] drawing texture, tex_size=", tex.get_size(), " card_size=", CARD_SIZE, " rect=", rect, " face_size=", _card_face.size)
		# 先用红色验证绘制位置
		c.draw_rect(rect, Color.RED, true)
		# 有贴图：直接绘制图片 + 叠加信息层
		c.draw_texture_rect(tex, rect, false)
		# 半透明渐变底条（底部信息区可读性）
		var bar := Rect2(0, rect.size.y - 50, rect.size.x, 50)
		c.draw_rect(bar, Color(0, 0, 0, 0.45), true)
		_text(c, font, lname, 28, Color.WHITE, rect.size.y - 16)
	else:
		# 无贴图：回退颜色块
		var col: Color = LOCATION_COLORS.get(ltype, Color(0.6, 0.6, 0.6))
		c.draw_rect(rect, col, true)
		c.draw_rect(rect, Color(1, 1, 1, 0.6), false, 5.0)
		c.draw_rect(Rect2(40, 20, CARD_SIZE.x - 80, CARD_SIZE.y - 40), Color(1, 1, 1, 0.4), false, 2.0)
		_text(c, font, lname, 40, Color(0.1, 0.1, 0.1), CARD_SIZE.y * 0.45)
		_text(c, font, _type_label(ltype), 24, Color(0.2, 0.2, 0.2, 0.85), CARD_SIZE.y * 0.55)


func _draw_back(c: Control, font: Font, rect: Rect2) -> void:
	# 米白纸纹
	c.draw_rect(rect, PAPER_COLOR, true)
	c.draw_rect(rect, Color(0.7, 0.65, 0.55), false, 4.0)

	# 中线分隔 (左文字区, 右地址区)
	var mid_x := CARD_SIZE.x * 0.62
	c.draw_line(Vector2(mid_x, 40), Vector2(mid_x, CARD_SIZE.y - 40), Color(0.7, 0.65, 0.55, 0.6), 2.0)

	# 邮戳 (右上圆形)
	var stamp_c := Vector2(CARD_SIZE.x - 90, 70)
	c.draw_arc(stamp_c, 50, 0, TAU, 32, Color(0.55, 0.35, 0.3, 0.7), 3.0)
	c.draw_arc(stamp_c, 42, 0, TAU, 32, Color(0.55, 0.35, 0.3, 0.5), 2.0)
	var date_str := _today_str()
	var ds_w := font.get_string_size(date_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	c.draw_string(font, stamp_c - Vector2(ds_w * 0.5, -2), date_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.35, 0.3, 0.85))

	# 手写文字区横线
	var sender: String = _data.sender_cat_species if "sender_cat_species" in _data else "一只猫"
	var lname: String = _data.location_name if "location_name" in _data else String(_data.id)
	var msg: String = _data.back_text if "back_text" in _data else "今天的风景很好，想与你分享。"

	var line_y := 125.0
	var line_x0 := 50.0
	var line_x1 := mid_x - 30.0
	for i in range(6):
		c.draw_line(Vector2(line_x0, line_y), Vector2(line_x1, line_y), Color(0.7, 0.65, 0.55, 0.4), 1.5)
		line_y += 30.0

	# 手写正文 (简单换行)
	_draw_wrapped(c, font, msg, 22, Color(0.25, 0.2, 0.15), line_x0 + 4, 120.0, line_x1 - line_x0 - 8, 30.0)

	# 落款
	c.draw_string(font, Vector2(line_x0 + 6, CARD_SIZE.y - 85), "—— 来自 " + sender, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.25, 0.2, 0.15))
	c.draw_string(font, Vector2(line_x0 + 6, CARD_SIZE.y - 65), "寄自 " + lname, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.35, 0.3, 0.25))

	# 收件区
	c.draw_string(font, Vector2(mid_x + 20, 150), "TO:", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.35, 0.3, 0.25))
	c.draw_string(font, Vector2(mid_x + 20, 180), "亲爱的你", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.3, 0.25, 0.2))
	for i in range(3):
		var ly := 210.0 + i * 28.0
		c.draw_line(Vector2(mid_x + 20, ly), Vector2(CARD_SIZE.x - 50, ly), Color(0.7, 0.65, 0.55, 0.4), 1.5)

func _draw_wrapped(c: Control, font: Font, text: String, font_size: int, color: Color, x: float, y: float, max_w: float, line_h: float) -> void:
	var cur := ""
	var oy := y
	for ch in text:
		var test := cur + ch
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w:
			c.draw_string(font, Vector2(x, oy), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			cur = ch
			oy += line_h
		else:
			cur = test
	if cur != "":
		c.draw_string(font, Vector2(x, oy), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text(c: Control, font: Font, text: String, font_size: int, color: Color, y_baseline: float) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	c.draw_string(font, Vector2((CARD_SIZE.x - w) * 0.5, y_baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _type_label(ltype: String) -> String:
	match ltype:
		"park": return "公园"
		"street": return "街道"
		"cafe": return "咖啡馆"
		"sea": return "海边"
		"bookstore": return "书店"
		"flower": return "花田"
		_: return ltype


func _today_str() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d.%02d.%02d" % [d.year, d.month, d.day]
