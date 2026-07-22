extends Control
class_name WalkSummaryCard

# 散步小结卡片（B1 D1 伴走系统 / 特性2）
# 由 WalkCompanion 创建 CanvasLayer 叠加到花园场景之上。
# data: { "steps": int, "companion_name": String, "breed": String }
# 展示 15 秒后自动关闭，或点击任意处关闭；同一天不重复展示由 WalkCompanion 保证。

const AUTO_DISMISS_SEC := 15.0
const CARD_SIZE := Vector2(560, 320)
const HEAD_SIZE := 80.0
const PORTRAIT_BASE := "res://assets/art/delivery/portraits/portrait_"

# 品种化趣味文案数据源，常驻预载（避免运行时 load）。
const CompanionChatter := preload("res://config/companion_chatter.gd")

var _dismissed := false
var _timer: Timer
var _steps := 0
var _companion_name := ""
var _breed := "orange"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_start_timer()


func setup(steps: int, companion_name: String, breed: String) -> void:
	_steps = steps
	_companion_name = companion_name
	_breed = breed
	if is_inside_tree():
		_build_ui()


func _build_ui() -> void:
	# 清空旧内容，支持热更新
	for child in get_children():
		child.queue_free()

	# 全屏半透明遮罩（花园场景可见）
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(overlay)

	# 弹窗底图（popup_bg.png）
	var panel := TextureRect.new()
	panel.texture = load("res://assets/art/ui/panels/popup_bg.png")
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	_center_control(panel, CARD_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 40)
	vbox.add_theme_constant_override("margin_right", 40)
	vbox.add_theme_constant_override("margin_top", 20)
	vbox.add_theme_constant_override("margin_bottom", 20)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# 随行猫头像（图鉴同款贴图）
	var portrait_path := PORTRAIT_BASE + _breed + ".png"
	var head := TextureRect.new()
	head.texture = load(portrait_path) if ResourceLoader.exists(portrait_path) else null
	if head.texture == null:
		head.queue_free()
		var circle := Panel.new()
		circle.custom_minimum_size = Vector2(HEAD_SIZE, HEAD_SIZE)
		circle.size = Vector2(HEAD_SIZE, HEAD_SIZE)
		circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var st := StyleBoxFlat.new()
		st.bg_color = {
			"orange": Color(0.95, 0.62, 0.23),
			"british": Color(0.55, 0.60, 0.66),
			"siamese": Color(0.80, 0.68, 0.55),
		}.get(_breed, Color(0.95, 0.62, 0.23))
		st.set_corner_radius_all(int(HEAD_SIZE / 2.0))
		st.border_color = Color(1, 1, 1, 0.9)
		st.set_border_width_all(4)
		circle.add_theme_stylebox_override("panel", st)
		circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head_center := CenterContainer.new()
		head_center.add_child(circle)
		vbox.add_child(head_center)
	else:
		head.custom_minimum_size = Vector2(HEAD_SIZE, HEAD_SIZE)
		head.size = Vector2(HEAD_SIZE, HEAD_SIZE)
		head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var head_center := CenterContainer.new()
		head_center.add_child(head)
		vbox.add_child(head_center)

	# 标题
	var title := Label.new()
	title.text = "今日散步"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("#4F453C"))
	vbox.add_child(title)

	# 步数
	var steps_label := Label.new()
	steps_label.text = "%d 步" % _steps
	steps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	steps_label.add_theme_font_size_override("font_size", 48)
	steps_label.add_theme_color_override("font_color", {
		"orange": Color(0.95, 0.62, 0.23),
		"british": Color(0.55, 0.60, 0.66),
		"siamese": Color(0.80, 0.68, 0.55),
	}.get(_breed, Color(0.95, 0.62, 0.23)))
	vbox.add_child(steps_label)

	# 趣味文案
	var msg := Label.new()
	msg.text = _build_message()
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(460, 0)
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color("#A2978C"))
	vbox.add_child(msg)

	# 关闭提示
	var hint := Label.new()
	hint.text = "点击任意处关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#A2978C"))
	vbox.add_child(hint)


func _center_control(control: Control, control_size: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -control_size.x * 0.5
	control.offset_top = -control_size.y * 0.5
	control.offset_right = control_size.x * 0.5
	control.offset_bottom = control_size.y * 0.5


func _build_message() -> String:
	var flavor: String = String(CompanionChatter.draw_summary_message(_breed))
	if _companion_name != "":
		return "%s说：%s" % [_companion_name, flavor]
	return flavor


func _start_timer() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = AUTO_DISMISS_SEC
	add_child(_timer)
	_timer.timeout.connect(_dismiss)
	_timer.start()


func _gui_input(event: InputEvent) -> void:
	if _is_tap(event):
		_dismiss()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _is_tap(event):
		_dismiss()
		get_viewport().set_input_as_handled()


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false


func _dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	if _timer and is_instance_valid(_timer):
		_timer.stop()
	# 移除整个 CanvasLayer 宿主
	var p := get_parent()
	if is_instance_valid(p):
		p.queue_free()
