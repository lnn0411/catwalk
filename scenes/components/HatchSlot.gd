extends Control
# ============================================================
# HatchSlot —— 可复用孵化槽组件（节点版，替代 S06 原 _draw 绘制）
# 结构在 HatchSlot.tscn，样式/状态驱动在这里。
# 美术接入点（库洛洛拖图即可，无需改代码）：
#   %FrameArt  —— 槽位边框贴图（locked/empty/filling/ready 可用 modulate 或换图）
#   %EggArt    —— 蛋壳贴图（孵化中/ready 显示）
#   贴了图后，对应的代码回退层（%FramePanel / %EggFallback）会自动让位。
# ============================================================

signal slot_pressed(slot_index: int)

const CatData := preload("res://core/CatData.gd")

var slot_index: int = 0

var _frame_panel: Panel
var _frame_art: TextureRect
var _glow: Panel
var _egg: Control
var _egg_fallback: Panel
var _egg_art: TextureRect
var _title: Label
var _prog_bg: Panel
var _prog_fill: Panel
var _status: Label

var _is_ready_state := false
var _anim := 0.0
var _egg_home := Vector2.ZERO   # 蛋的静止局部坐标（ready 抖动以此为基准）


func _ready() -> void:
	_frame_panel = %FramePanel
	_frame_art = %FrameArt
	_glow = %Glow
	_egg = %Egg
	_egg_fallback = %EggFallback
	_egg_art = %EggArt
	_title = %Title
	_prog_bg = %ProgressBg
	_prog_fill = %ProgressFill
	_status = %Status
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
	var unlocked := bool(slot.get("unlocked", slot_index == 0))
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
		_glow.visible = false

	match status:
		"locked":
			_frame_panel.modulate = Color(0.5, 0.5, 0.5, 1.0)
			_egg.visible = false
			_glow.visible = false
			_title.text = ""
			_status.text = "未解锁"
			_status.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
			_prog_bg.visible = false
		"empty":
			_frame_panel.modulate = Color.WHITE
			_egg.visible = false
			_glow.visible = false
			_title.text = ""
			_status.text = "空槽"
			_status.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
			_prog_bg.visible = false
		"ready":
			_frame_panel.modulate = Color.WHITE
			_egg.visible = true
			_glow.visible = true
			_set_egg_color(species)
			_title.text = "蛋 %d" % (slot_index + 1)
			_status.text = "点击孵化"
			_status.add_theme_color_override("font_color", Palette.AMBER)
			_prog_bg.visible = true
			_set_progress(1.0)
		_:  # incubating
			_frame_panel.modulate = Color.WHITE
			_egg.visible = true
			_glow.visible = false
			_set_egg_color(species)
			_title.text = "蛋 %d" % (slot_index + 1)
			_status.text = "%d%%" % int(progress * 100.0) if progress > 0.0 else "等待能量"
			_status.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
			_prog_bg.visible = true
			_set_progress(progress)


# incubating 且已满 → 视为 ready（沿用原 _slot_status 语义）
func _effective_status(slot: Dictionary) -> String:
	var status: String = String(slot.get("status", "empty"))
	var energy := float(slot.get("energy", 0.0))
	var max_energy := float(slot.get("max_energy", 0.0))
	if status == "incubating" and max_energy > 0.0 and energy >= max_energy:
		return "ready"
	return status


func _process(delta: float) -> void:
	if not _is_ready_state:
		return
	_anim += delta
	# 蛋震动（沿用原演出手感）
	_egg.position = _egg_home + Vector2(sin(_anim * 30.0) * 3.0, cos(_anim * 26.0) * 2.0)
	# 金色光晕呼吸
	var pulse := (sin(_anim * 4.0) + 1.0) * 0.5
	_glow.modulate.a = 0.18 + pulse * 0.22


# ── 进度条填充宽度（_prog_fill 为 _prog_bg 子节点，左对齐，按比例设宽）──
func _set_progress(p: float) -> void:
	var track_w := _prog_bg.size.x
	_prog_fill.size = Vector2(maxf(track_w * clamp(p, 0.0, 1.0), 0.0), _prog_bg.size.y)


func _set_egg_color(species: String) -> void:
	var c := Palette.CAT_ORANGE_LIGHT
	match species:
		CatData.BREED_BRITISH:
			c = Palette.CAT_BRIT_LIGHT
		CatData.BREED_SIAMESE:
			c = Palette.CAT_SIAM_BODY
	_style_panel(_egg_fallback, c, c, 40, 0)


# ── 基础样式（一次性）──
func _apply_base_style() -> void:
	_style_panel(_frame_panel, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 10, 2)
	_style_panel(_glow, Palette.AMBER, Palette.AMBER, 80, 0)
	_glow.modulate.a = 0.2
	_glow.visible = false
	_style_panel(_egg_fallback, Palette.CAT_ORANGE_LIGHT, Palette.CAT_ORANGE_LIGHT, 40, 0)
	_style_panel(_prog_bg, Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, 5, 0)
	_style_panel(_prog_fill, Palette.AMBER, Palette.AMBER, 5, 0)


func _style_panel(p: Panel, bg: Color, border: Color, radius: int, border_w: int) -> void:
	if p == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border
	p.add_theme_stylebox_override("panel", sb)
