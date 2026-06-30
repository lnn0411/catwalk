extends Control
# ============================================================
# HatchSlot —— 可复用孵化槽组件
# 状态：locked / empty / incubating / ready
# 卡片与蛋的主体视觉由 incubation 目录下的贴图驱动。
# ============================================================

signal slot_pressed(slot_index: int)

const CatData := preload("res://core/CatData.gd")

const SLOT_CARD_TEXTURES: Dictionary = {
	"locked": preload("res://assets/art/ui/incubation/slots/slot_card_locked.png"),
	"empty": preload("res://assets/art/ui/incubation/slots/slot_card_empty.png"),
	"incubating": preload("res://assets/art/ui/incubation/slots/slot_card_incubating.png"),
	"ready": preload("res://assets/art/ui/incubation/slots/slot_card_ready.png"),
}

const EGG_TEXTURES: Dictionary = {
	"orange": preload("res://assets/art/ui/incubation/eggs/egg_orange_tabby.png"),
	"orange_tabby": preload("res://assets/art/ui/incubation/eggs/egg_orange_tabby.png"),
	"british": preload("res://assets/art/ui/incubation/eggs/egg_british_shorthair.png"),
	"british_shorthair": preload("res://assets/art/ui/incubation/eggs/egg_british_shorthair.png"),
	"siamese": preload("res://assets/art/ui/incubation/eggs/egg_siamese.png"),
}

const DARK_BROWN := Color("5C3A1E")
const PROGRESS_INSET := 3.0   # 裁剪后腔体从x=3开始, SCALE下 3*(268/285)=2.82→3.0

var slot_index: int = 0

@onready var _card: Panel = %Card
@onready var _frame_art: TextureRect = %FrameArt
@onready var _glow: Panel = %Glow
@onready var _title_row: HBoxContainer = %TitleRow
@onready var _title: Label = %Title
@onready var _egg: Control = %Egg
@onready var _egg_fallback: Panel = %EggFallback
@onready var _egg_art: TextureRect = %EggArt
@onready var _prog_bg: TextureRect = %ProgressBg
@onready var _prog_fill: ColorRect = %ProgressFill
@onready var _status: Label = %StatusLabel
@onready var _hint: Label = %HintLabel

var _is_ready_state := false
var _anim := 0.0
var _egg_home := Vector2.ZERO


func _ready() -> void:
	_egg_home = _egg.position
	_apply_base_style()
	set_process(false)


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
	var species: String = String(slot.get("species", slot.get("breed", CatData.BREED_ORANGE)))
	var progress := 0.0
	if max_energy > 0.0:
		progress = clamp(energy / max_energy, 0.0, 1.0)

	#_frame_art.texture = SLOT_CARD_TEXTURES.get(status, SLOT_CARD_TEXTURES["incubating"])
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
			_title_row.visible = false
			_hint.visible = false
			_prog_bg.visible = false
			_status.visible = true
			_status.text = "孵%d只解锁" % _unlock_count()
			_status.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
		"empty":
			_style_card(false)
			_set_egg_color(species, true)
			_egg.visible = true
			_glow.visible = false
			_title_row.visible = true
			_title.text = "蛋 %d" % (slot_index + 1)
			_hint.visible = false
			_prog_bg.visible = false
			_status.visible = true
			_status.text = "等待能量"
			_status.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
		"ready":
			_style_card(true)
			_set_egg_color(species, false)
			_egg.visible = true
			_egg.scale = Vector2(1.12, 1.12)
			_glow.visible = true
			_title_row.visible = true
			_title.text = "蛋 %d" % (slot_index + 1)
			_hint.visible = true
			_hint.add_theme_color_override("font_color", Palette.AMBER_PRESS)
			_prog_bg.visible = false
			_status.visible = false
			_status.text = "好像要出来了"
			_status.add_theme_color_override("font_color", DARK_BROWN)
		_:  # incubating
			_style_card(true)
			_set_egg_color(species, false)
			_egg.visible = true
			_glow.visible = false
			_title_row.visible = true
			_title.text = "蛋 %d" % (slot_index + 1)
			_hint.visible = false
			_prog_bg.visible = true
			_set_progress(progress)
			_status.visible = true
			_status.text = "%d%%" % int(progress * 100.0) if progress > 0.0 else "等待能量"
			_status.add_theme_color_override("font_color", DARK_BROWN)


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


# 进度填充保留比例逻辑，并避开进度槽贴图四周的 4px 边框。
func _set_progress(p: float) -> void:
	var ratio: float = clamp(p, 0.0, 1.0)
	var inner_width := maxf(_prog_bg.size.x - PROGRESS_INSET * 2.0, 0.0)
	_prog_fill.anchor_right = 0.0
	_prog_fill.offset_left = PROGRESS_INSET
	_prog_fill.offset_right = PROGRESS_INSET + inner_width * ratio
	_prog_fill.offset_top = 3.0      # 贴图腔体垂直范围 y≈3.5→24, SCALE下对齐
	_prog_fill.offset_bottom = 21.0


# 品种色现由对应的完整蛋巢贴图表达；faint 仅用于空槽淡化。
func _set_egg_color(species: String, faint: bool) -> void:
	var breed_key := species.to_lower()
	_egg_art.texture = EGG_TEXTURES.get(breed_key, EGG_TEXTURES["orange_tabby"])
	_egg_art.visible = _egg_art.texture != null
	_egg_fallback.visible = not _egg_art.visible
	_egg.modulate.a = 0.45 if faint else 1.0


func _apply_base_style() -> void:
	_style_card(false)
	_set_panel_bg(_glow, Palette.AMBER, 80)
	_glow.modulate.a = 0.2
	_glow.visible = false
	_prog_fill.color = Palette.AMBER
	_title.add_theme_color_override("font_color", DARK_BROWN)
	_status.add_theme_color_override("font_color", DARK_BROWN)


# 卡片主体由 FrameArt 绘制，这里只切换边框色。
func _style_card(active: bool) -> void:
	if _card == null:
		return
	var sb := _card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = Color.TRANSPARENT
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(1)
	sb.border_color = Palette.AMBER if active else Palette.BORDER
	_card.add_theme_stylebox_override("panel", sb)


func _set_panel_bg(panel: Panel, color: Color, radius: int) -> void:
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", sb)
