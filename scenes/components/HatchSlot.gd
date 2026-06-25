extends Control
# ============================================================
# HatchSlot —— 可复用孵化槽组件（节点版，卡片化重构 v2）
# 结构在 HatchSlot.tscn，样式/状态驱动在这里。
# 视觉对齐 Style Bible v2.2：白卡 + 18px 圆角 + 暖棕阴影，配色走新 Palette。
# 状态：locked / empty / incubating / ready
# 美术接入点（拖图即可，无需改代码）：
#   %FrameArt  —— 卡片边框/底纹贴图（贴了图会盖在 Card 之上）
#   %EggArt    —— 蛋壳贴图（孵化中 / ready 显示）；贴图就位时回退层 %EggFallback 让位。
# ============================================================

signal slot_pressed(slot_index: int)

const CatData := preload("res://core/CatData.gd")

# 蛋壳回退色（Palette 已移除 CAT_* 系列，组件内自带一套暖色蛋壳）
const EGG_ORANGE := Color("F2C572")
const EGG_BRITISH := Color("C9D6DE")
const EGG_SIAMESE := Color("EAD9C2")
const EGG_CREAM := Color("F3E7D2")

var slot_index: int = 0

var _card: Panel
var _frame_art: TextureRect
var _glow: Panel
var _egg: Control
var _egg_fallback: Panel
var _egg_art: TextureRect
var _lock_icon: Label
var _title: Label
var _prog_bg: Panel
var _prog_fill: ColorRect
var _status: Label
var _hint: Label

var _is_ready_state := false
var _anim := 0.0
var _egg_home := Vector2.ZERO   # 蛋的静止局部坐标（ready 抖动以此为基准）


func _ready() -> void:
	_card = %Card
	_frame_art = %FrameArt
	_glow = %Glow
	_egg = %Egg
	_egg_fallback = %EggFallback
	_egg_art = %EggArt
	_lock_icon = %LockIcon
	_title = %Title
	_prog_bg = %ProgressBg
	_prog_fill = %ProgressFill
	_status = %StatusLabel
	_hint = %HintLabel
	_egg_home = _egg.position
	_apply_base_style()
	set_process(false)  # 仅 ready 态才开 _process 做抖动/呼吸


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_pressed.emit(slot_index)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		slot_pressed.emit(slot_index)
		accept_event()


# 外部每次刷新调用：根据槽位数据更新所有子节点显示。
func set_data(slot: Dictionary) -> void:
	var status := _effective_status(slot)
	var energy := float(slot.get("energy", 0.0))
	var max_energy := float(slot.get("max_energy", 0.0))
	var species: String = String(slot.get("species", CatData.BREED_ORANGE))
	var progress := 0.0
	if max_energy > 0.0:
		progress = clamp(energy / max_energy, 0.0, 1.0)

	_is_ready_state = status == "ready"
	set_process(_is_ready_state)
	if not _is_ready_state:
		_egg.position = _egg_home
		_egg.scale = Vector2.ONE
		_glow.visible = false

	match status:
		"locked":
			_style_card(false)
			_egg.visible = false
			_glow.visible = false
			_lock_icon.visible = true
			_title.text = ""
			_hint.visible = false
			_prog_bg.visible = false
			_status.text = "孵%d只解锁" % _unlock_count()
			_status.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
		"empty":
			_style_card(false)
			_set_egg_color(species, true)
			_egg.visible = true
			_glow.visible = false
			_lock_icon.visible = false
			_title.text = ""
			_hint.visible = false
			_prog_bg.visible = false
			_status.text = "等待中"
			_status.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
		"ready":
			_style_card(true)
			_set_egg_color(species, false)
			_egg.visible = true
			_egg.scale = Vector2(1.12, 1.12)
			_glow.visible = true
			_lock_icon.visible = false
			_title.text = "蛋 %d" % (slot_index + 1)
			_hint.visible = true
			_hint.add_theme_color_override("font_color", Palette.AMBER_PRESS)
			_prog_bg.visible = false
			_status.text = "好像要出来了"
			_status.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		_:  # incubating
			_style_card(true)
			_set_egg_color(species, false)
			_egg.visible = true
			_glow.visible = false
			_lock_icon.visible = false
			_title.text = "蛋 %d" % (slot_index + 1)
			_hint.visible = false
			_prog_bg.visible = true
			_set_progress(progress)
			_status.text = "%d%%" % int(progress * 100.0) if progress > 0.0 else "等待能量"
			_status.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)


# incubating 且已满 → 视为 ready（沿用原 _slot_status 语义）
func _effective_status(slot: Dictionary) -> String:
	var status: String = String(slot.get("status", "empty"))
	var energy := float(slot.get("energy", 0.0))
	var max_energy := float(slot.get("max_energy", 0.0))
	if status == "incubating" and max_energy > 0.0 and energy >= max_energy:
		return "ready"
	return status


# 该槽解锁所需的累计孵化只数（来自 HatchEngine 配置，判空兜底）
func _unlock_count() -> int:
	if HatchEngine and slot_index < HatchEngine.SLOT_UNLOCK_HATCH_COUNTS.size():
		return int(HatchEngine.SLOT_UNLOCK_HATCH_COUNTS[slot_index])
	return slot_index


func _process(delta: float) -> void:
	if not _is_ready_state:
		return
	_anim += delta
	# 蛋轻微震动（沿用原演出手感）
	_egg.position = _egg_home + Vector2(sin(_anim * 18.0) * 2.0, cos(_anim * 15.0) * 1.5)
	# 光晕呼吸 + AMBER→PETAL 流转
	var pulse := (sin(_anim * 3.4) + 1.0) * 0.5
	var glow_color := Palette.AMBER.lerp(Palette.SPRING_PETAL, pulse)
	_set_panel_bg(_glow, glow_color, 80)
	_glow.modulate.a = 0.22 + pulse * 0.26


# ── 进度条填充（ProgressFill 为 ProgressBg 子节点，靠 anchor_right 比例填充，天然随宽度自适配）──
func _set_progress(p: float) -> void:
	var ratio := clamp(p, 0.0, 1.0)
	_prog_fill.anchor_right = ratio
	_prog_fill.offset_right = 0.0


func _set_egg_color(species: String, faint: bool) -> void:
	var c := EGG_ORANGE
	match species:
		CatData.BREED_BRITISH:
			c = EGG_BRITISH
		CatData.BREED_SIAMESE:
			c = EGG_SIAMESE
		CatData.BREED_ORANGE:
			c = EGG_ORANGE
		_:
			c = EGG_CREAM
	# 空槽：蛋影淡淡的剪影
	if faint:
		c = EGG_CREAM
		_egg.modulate.a = 0.45
	else:
		_egg.modulate.a = 1.0
	_style_egg(c)


# ── 基础样式（一次性）──
func _apply_base_style() -> void:
	_style_card(false)
	_set_panel_bg(_glow, Palette.AMBER, 80)
	_glow.modulate.a = 0.2
	_glow.visible = false
	_style_egg(EGG_CREAM)
	# 进度槽
	_set_panel_bg(_prog_bg, Color("EDE7D8"), 5)
	_prog_fill.color = Palette.AMBER
	_lock_icon.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_title.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)


# 卡片样式：active=孵化中/ready 用纯白卡 + 描边；否则浅奶油 + 浅描边（空/锁）
func _style_card(active: bool) -> void:
	if _card == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE if active else Palette.PAPER_CREAM
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2 if active else 1)
	sb.border_color = Palette.AMBER if active else Palette.BORDER
	# 暖棕柔阴影
	sb.shadow_color = Palette.UI_SHADOW
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	_card.add_theme_stylebox_override("panel", sb)


# 蛋壳回退面板：椭圆感（高圆角）
func _style_egg(c: Color) -> void:
	if _egg_fallback == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.corner_radius_top_left = 34
	sb.corner_radius_top_right = 34
	sb.corner_radius_bottom_left = 40
	sb.corner_radius_bottom_right = 40
	sb.border_color = c.darkened(0.12)
	sb.set_border_width_all(2)
	_egg_fallback.add_theme_stylebox_override("panel", sb)


func _set_panel_bg(p: Panel, c: Color, radius: int) -> void:
	if p == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)
