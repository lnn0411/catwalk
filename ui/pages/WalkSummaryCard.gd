extends UIPage
class_name WalkSummaryCard

# 散步小结卡片（B1 D1 伴走系统 / 特性2）
# 由 WalkCompanion 通过 UIManager.push("res://ui/pages/WalkSummaryCard.tscn", data) 拉起。
# data: { "steps": int, "companion_name": String, "breed": String }
# 展示 15 秒后自动关闭，或点击任意处关闭；同一天不重复展示由 WalkCompanion 保证。

const AUTO_DISMISS_SEC := 15.0
const CARD_SIZE := Vector2(560, 320)
const HEAD_SIZE := 96.0
const PORTRAIT_BASE := "res://assets/art/delivery/portraits/portrait_"

# 品种化趣味文案数据源，常驻预载（避免运行时 load）。
const CompanionChatter := preload("res://config/companion_chatter.gd")

var _dismissed := false
var _timer: Timer


func _ready() -> void:
	super._ready()
	_build_ui()
	_start_timer()


func _build_ui() -> void:
	var steps: int = int(page_data.get("steps", 0))
	var companion_name: String = String(page_data.get("companion_name", ""))
	var breed: String = String(page_data.get("breed", "orange"))

	# 全屏半透明遮罩
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var portrait_path := PORTRAIT_BASE + breed + ".png"
	var head := TextureRect.new()
	head.texture = load(portrait_path) if ResourceLoader.exists(portrait_path) else null
	if head.texture == null:
		# 回退品种色圆
		head.custom_minimum_size = Vector2(HEAD_SIZE, HEAD_SIZE)
		head.modulate = {
			"orange": Color(0.95, 0.62, 0.23),
			"british": Color(0.55, 0.60, 0.66),
			"siamese": Color(0.80, 0.68, 0.55),
		}.get(breed, Color(0.95, 0.62, 0.23))
	else:
		head.custom_minimum_size = Vector2(HEAD_SIZE, HEAD_SIZE)
		head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
	steps_label.text = "%d 步" % steps
	steps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	steps_label.add_theme_font_size_override("font_size", 48)
	steps_label.add_theme_color_override("font_color", {
		"orange": Color(0.95, 0.62, 0.23),
		"british": Color(0.55, 0.60, 0.66),
		"siamese": Color(0.80, 0.68, 0.55),
	}.get(breed, Color(0.95, 0.62, 0.23)))
	vbox.add_child(steps_label)

	# 趣味文案
	var msg := Label.new()
	msg.text = _build_message(companion_name, breed)
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


func _make_head_circle(breed: String) -> Control:
	# 用带圆角的 Panel 近似圆形头像占位（32×32 区域放大到可见尺寸），无纹理依赖。
	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(HEAD_SIZE, HEAD_SIZE)
	var st := StyleBoxFlat.new()
	st.bg_color = BREED_COLORS.get(breed, BREED_COLORS["orange"])
	st.set_corner_radius_all(int(HEAD_SIZE / 2.0))
	st.border_color = Color(1, 1, 1, 0.9)
	st.set_border_width_all(4)
	circle.add_theme_stylebox_override("panel", st)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return circle


func _build_message(companion_name: String, breed: String) -> String:
	# CompanionChatter 预载常驻，取品种化趣味文案（静态方法）。
	var flavor: String = String(CompanionChatter.draw_summary_message(breed))
	if companion_name != "":
		return "%s说：%s" % [companion_name, flavor]
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
	if UIManager and UIManager.has_method("pop"):
		UIManager.pop()


# 系统返回键：关闭卡片而非穿透到下层。
func handle_back() -> bool:
	_dismiss()
	return true


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size
