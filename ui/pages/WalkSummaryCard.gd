extends UIPage
class_name WalkSummaryCard

# 散步小结卡片（B1 D1 伴走系统 / 特性2）
# 由 WalkCompanion 通过 UIManager.push("res://ui/pages/WalkSummaryCard.tscn", data) 拉起。
# data: { "steps": int, "companion_name": String, "breed": String }
# 展示 15 秒后自动关闭，或点击任意处关闭；同一天不重复展示由 WalkCompanion 保证。

const AUTO_DISMISS_SEC := 15.0
const CARD_SIZE := Vector2(500, 400)
const HEAD_SIZE := 96.0

# 品种化趣味文案数据源，常驻预载（避免运行时 load）。
const CompanionChatter := preload("res://config/companion_chatter.gd")

# 品种色，作为猫头占位圆的颜色（无美术依赖）。
const BREED_COLORS := {
	"orange": Color(0.95, 0.62, 0.23),
	"british": Color(0.55, 0.60, 0.66),
	"siamese": Color(0.80, 0.68, 0.55),
}

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
	# IGNORE：让点击穿透到根节点的 _gui_input，实现点击遮罩任意处关闭。
	# 若设为 STOP，遮罩会吞掉点击，tap-to-dismiss 失效。
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# 居中卡片
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	# 不用 PRESET_CENTER（会和手动 position 冲突，推偏到右下角）
	card.pivot_offset = CARD_SIZE * 0.5
	card.position = Vector2(
		(_viewport_size().x - CARD_SIZE.x) * 0.5,
		(_viewport_size().y - CARD_SIZE.y) * 0.5
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.97, 0.92)
	style.set_corner_radius_all(28)
	style.set_content_margin_all(28)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 12
	card.add_theme_stylebox_override("panel", style)
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	# 随行猫头（占位彩色圆）
	var head_wrap := CenterContainer.new()
	vbox.add_child(head_wrap)
	var head := _make_head_circle(breed)
	head_wrap.add_child(head)

	# 标题
	var title := Label.new()
	title.text = "今日散步"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.28, 0.24, 0.20))
	vbox.add_child(title)

	# 步数（大号）
	var steps_label := Label.new()
	steps_label.text = "%d 步" % steps
	steps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	steps_label.add_theme_font_size_override("font_size", 48)
	steps_label.add_theme_color_override("font_color", BREED_COLORS.get(breed, BREED_COLORS["orange"]))
	vbox.add_child(steps_label)

	# 趣味文案
	var msg := Label.new()
	msg.text = _build_message(companion_name, breed)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(CARD_SIZE.x - 80, 0)
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(0.42, 0.38, 0.34))
	vbox.add_child(msg)

	# 点击关闭提示
	var hint := Label.new()
	hint.text = "点击任意处关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.60, 0.56, 0.52))
	vbox.add_child(hint)


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
