# 成就解锁横幅弹窗
# 独立脚本，监听 AchievementSystem.achievement_unlocked signal
# 接管原 AchievementSystem.gd 第482-636行的 UI 代码
# 遵循 popup-spec.md 顶部通知横幅规范

extends CanvasLayer
# 无 class_name：已注册为同名 autoload，class_name 会与单例命名冲突。

const MAX_POPUPS_PER_SESSION := 2
const BANNER_WIDTH := 620
const BANNER_HEIGHT := 120
const FONT_SIZE_TITLE := 20
const FONT_SIZE_REWARD := 15
const FONT_COLOR_TITLE := Color("#4f453c")
const FONT_COLOR_REWARD := Color("#7a6e63")
const PANEL_BG := Color(0.98, 0.94, 0.84, 0.98)
const PANEL_CORNER := 18.0
const SHADOW_SIZE := 12
const SHADOW_COLOR := Color(0.15, 0.1, 0.05, 0.24)
const ICON_SIZE := 64.0
const BTN_CONFIRM_SIZE := Vector2(64.0, 64.0)
const AUTO_DISMISS_TIME := 5.0

const ICON_MAP := {
	"steps": "res://assets/art/delivery/achievement/ach_icon_steps.png",
	"collection": "res://assets/art/delivery/achievement/ach_icon_collection.png",
	"growth": "res://assets/art/delivery/achievement/ach_icon_growth.png",
	"postcards": "res://assets/art/delivery/achievement/ach_icon_postcard.png",
	"easter_egg": "res://assets/art/delivery/achievement/ach_icon_easter.png",
}

var _queue: Array[Dictionary] = []
var _active := false
var _shown_count := 0


func _ready() -> void:
	if AchievementSystem and not AchievementSystem.achievement_unlocked.is_connected(_on_achievement_unlocked):
		AchievementSystem.achievement_unlocked.connect(_on_achievement_unlocked)


func _on_achievement_unlocked(id: String, reward: Dictionary) -> void:
	if _shown_count >= MAX_POPUPS_PER_SESSION:
		return
	_queue.append({"id": id, "reward": reward.duplicate(true)})
	_try_show_next()


func _try_show_next() -> void:
	if _active or _queue.is_empty() or not is_inside_tree():
		return
	_active = true
	_shown_count += 1
	var data: Dictionary = _queue.pop_front()
	show_banner(data.id, data.reward)


func show_banner(achievement_id: String, reward: Dictionary) -> void:
	layer = 100

	var definition := _find_definition(achievement_id)
	if definition.is_empty():
		_active = false
		return

	var ach_name := String(definition.get("name", achievement_id))
	var ach_category := String(definition.get("category", ""))

	# 遮罩背景效果 — 用半透明底（不阻隔操作）
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.3)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 穿通点击
	add_child(dim)

	# Banner 面板
	var banner := PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -BANNER_WIDTH * 0.5
	banner.offset_right = BANNER_WIDTH * 0.5
	banner.offset_top = -120.0
	banner.offset_bottom = -120.0 + BANNER_HEIGHT

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.corner_radius_top_left = PANEL_CORNER
	style.corner_radius_top_right = PANEL_CORNER
	style.corner_radius_bottom_left = PANEL_CORNER
	style.corner_radius_bottom_right = PANEL_CORNER
	style.shadow_color = SHADOW_COLOR
	style.shadow_size = SHADOW_SIZE
	banner.add_theme_stylebox_override("panel", style)
	add_child(banner)

	# 内容容器
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	banner.add_child(margin)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	# 分类图标
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = ICON_MAP.get(ach_category, "res://assets/art/delivery/achievement/ach_icon_steps.png")
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		icon.modulate = Color(0.88, 0.65, 0.28, 1.0)
	content.add_child(icon)

	# 文字区
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(copy)

	var title := Label.new()
	title.text = "成就解锁 · " + ach_name
	title.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", FONT_COLOR_TITLE)
	copy.add_child(title)

	var reward_label := Label.new()
	reward_label.text = _format_reward_text(reward)
	reward_label.add_theme_font_size_override("font_size", FONT_SIZE_REWARD)
	reward_label.add_theme_color_override("font_color", FONT_COLOR_REWARD)
	copy.add_child(reward_label)

	# 确认按钮（正方形，保留圆角；按下状态对齐命名弹窗确认按钮）
	var confirm := Button.new()
	confirm.custom_minimum_size = BTN_CONFIRM_SIZE
	confirm.focus_mode = Control.FOCUS_NONE
	
	# 松开状态 — 保持原有暖褐手绘风
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color("#d4b896")
	btn_normal.set_corner_radius_all(22)
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color("#5a4f45")
	btn_normal.content_margin_left = 8
	btn_normal.content_margin_right = 8
	btn_normal.content_margin_top = 4
	btn_normal.content_margin_bottom = 4
	confirm.add_theme_stylebox_override("normal", btn_normal)
	confirm.add_theme_color_override("font_color", Color("#4f453c"))
	
	# 按下状态 — 灰绿色、白字（匹配 btn_confirm_name）
	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color8(181, 197, 150)
	btn_pressed.set_corner_radius_all(22)
	btn_pressed.border_width_left = 2
	btn_pressed.border_width_top = 2
	btn_pressed.border_width_right = 2
	btn_pressed.border_width_bottom = 2
	btn_pressed.border_color = Color8(180, 118, 40)
	btn_pressed.content_margin_left = 8
	btn_pressed.content_margin_right = 8
	btn_pressed.content_margin_top = 4
	btn_pressed.content_margin_bottom = 4
	confirm.add_theme_stylebox_override("pressed", btn_pressed)
	confirm.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	
	confirm.add_theme_font_size_override("font_size", 14)
	confirm.text = "知道了"
	content.add_child(confirm)

	var auto_dismiss := Timer.new()
	auto_dismiss.one_shot = true
	auto_dismiss.wait_time = AUTO_DISMISS_TIME
	add_child(auto_dismiss)

	confirm.pressed.connect(_dismiss.bind(banner, dim, auto_dismiss))
	auto_dismiss.timeout.connect(_dismiss.bind(banner, dim, auto_dismiss))

	# 入场动画
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "offset_top", 24.0, 0.4)
	tween.tween_property(banner, "offset_bottom", float(24 + BANNER_HEIGHT), 0.4)
	auto_dismiss.start()


func _dismiss(banner: PanelContainer, dim: ColorRect, timer: Timer) -> void:
	if not is_instance_valid(banner) or banner.has_meta("dismissing"):
		return
	banner.set_meta("dismissing", true)
	timer.stop()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(banner, "offset_top", -120.0, 0.15)
	tween.tween_property(banner, "offset_bottom", -120.0 + BANNER_HEIGHT, 0.15)
	tween.tween_property(dim, "modulate:a", 0.0, 0.15)
	tween.set_parallel(false)
	tween.tween_callback(_finish.bind(banner, dim))


func _finish(_banner: PanelContainer, _dim: ColorRect) -> void:
	# Clear all content
	for child in get_children():
		if is_instance_valid(child):
			child.queue_free()
	_active = false
	_try_show_next()


func _find_definition(id: String) -> Dictionary:
	if not AchievementSystem or not AchievementSystem.has_method("get_definitions"):
		return {}
	for def_dict in AchievementSystem.get_definitions():
		if String(def_dict.get("id", "")) == id:
			return def_dict
	return {}


func _format_reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	var labels := {
		"gold_coins": "金币", "diamonds": "钻石", "title": "称号",
		"treasure_box": "宝箱", "makeup_card": "补签卡",
		"garden_decor": "花园装饰", "hatch_accelerator": "孵化加速器",
		"cat_collar": "猫项圈", "album_cover": "图鉴封面",
		"hidden_diary": "隐藏日记", "hidden_diary_5": "隐藏日记",
	}
	for key in reward:
		var label := String(labels.get(key, key))
		var value: Variant = reward[key]
		parts.append("%s %s" % [label, str(value)])
	return "奖励：" + "、".join(parts) if not parts.is_empty() else ""
