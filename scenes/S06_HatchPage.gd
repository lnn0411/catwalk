extends "res://ui/UIPage.gd"
# ============================================================
# S06 孵化屋 —— 卡片化重构 v2（节点版）
# 结构在 S06_HatchPage.tscn；本脚本负责绑定节点 + 状态驱动 + 交互。
# 玩法逻辑（孵化/注入/加速/导航/信号）与原版完全一致，未改数值。
# 配色走新 Palette（Style Bible v2.2 §3.1）：PAPER_CREAM 底 + 白卡 + AMBER 主色。
# 美术接入点：HatchSlot 内部的 %FrameArt %EggArt；各按钮可换 TextureButton。
# ============================================================

const CatData := preload("res://core/CatData.gd")
const WORKSHOP_SCENE := "res://scenes/WorkshopPage.gd"

@onready var _back_btn: Button = %BackBtn
@onready var _inject_btn: Button = %InjectBtn
@onready var _ad_btn: Button = %AdBtn
@onready var _workshop_link: Button = %WorkshopLink
@onready var _energy_card: Panel = %EnergyCard
@onready var _reserve_bar_bg: Panel = %ReserveBarBg
@onready var _reserve_bar_fill: ColorRect = %ReserveBarFill
@onready var _reserve_value: Label = %ReserveValue
@onready var _slots: Array = [%Slot0, %Slot1, %Slot2, %Slot3]


func _ready() -> void:
	super._ready()
	_style()
	_back_btn.pressed.connect(_on_back_pressed)
	_inject_btn.pressed.connect(_inject_energy)
	_ad_btn.pressed.connect(_speed_up)
	_workshop_link.pressed.connect(_on_workshop_pressed)
	for i in range(_slots.size()):
		_slots[i].slot_index = i
		if not _slots[i].slot_pressed.is_connected(_on_slot_pressed):
			_slots[i].slot_pressed.connect(_on_slot_pressed)
	_connect_data()
	_refresh_all()


func on_enter(_data: Dictionary = {}) -> void:
	_refresh_all()


func handle_back() -> bool:
	# 返回花园（与原版一致用 replace；Android 返回键也走这里）
	UIManager.replace("res://scenes/S04_GardenMain.tscn")
	return true


func _exit_tree() -> void:
	if HatchEngine:
		if HatchEngine.hatch_progress.is_connected(_on_hatch_progress):
			HatchEngine.hatch_progress.disconnect(_on_hatch_progress)
		if HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
			HatchEngine.hatch_complete.disconnect(_on_hatch_complete)
	if EnergyEngine and EnergyEngine.energy_changed.is_connected(_on_energy_changed):
		EnergyEngine.energy_changed.disconnect(_on_energy_changed)


func _connect_data() -> void:
	if HatchEngine:
		if not HatchEngine.hatch_progress.is_connected(_on_hatch_progress):
			HatchEngine.hatch_progress.connect(_on_hatch_progress)
		if not HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
			HatchEngine.hatch_complete.connect(_on_hatch_complete)
	if EnergyEngine and not EnergyEngine.energy_changed.is_connected(_on_energy_changed):
		EnergyEngine.energy_changed.connect(_on_energy_changed)


# ── 刷新 ──

func _refresh_all() -> void:
	_refresh_slots()
	_refresh_reserve()
	_refresh_ad_button()


func _refresh_slots() -> void:
	var slots: Array = HatchEngine.get_slots() if HatchEngine else []
	for i in range(_slots.size()):
		var data: Dictionary = Dictionary(slots[i]) if i < slots.size() else {}
		_slots[i].set_data(data)


func _refresh_reserve() -> void:
	var current := EnergyEngine.reserve_tank if EnergyEngine else 0.0
	var max_value := EnergyEngine.MAX_RESERVE_TANK if EnergyEngine else 6000.0
	var ratio: float = clamp(current / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	# 用 anchor_right 比例填充，天然随卡片宽度自适配（不再依赖固定像素宽）
	_reserve_bar_fill.anchor_right = ratio
	_reserve_bar_fill.offset_right = 0.0
	_reserve_value.text = "%.0f / %.0f" % [current, max_value]


func _refresh_ad_button() -> void:
	var remaining: int = HatchEngine.ad_speedup_remaining() if HatchEngine else 0
	_ad_btn.text = "📺 补充能量 +3,000  今日还可 %d次" % remaining
	_ad_btn.add_theme_color_override("font_color", Palette.TEXT_SECONDARY if remaining <= 0 else Palette.MOSS)
	_ad_btn.disabled = false


# ── 交互 ──

func _on_back_pressed() -> void:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")


func _on_workshop_pressed() -> void:
	UIManager.push(WORKSHOP_SCENE)


func _on_slot_pressed(index: int) -> void:
	if HatchEngine == null or index < 0:
		return
	var slots: Array = HatchEngine.get_slots()
	if index >= slots.size():
		return
	if _slots[index]._effective_status(Dictionary(slots[index])) != "ready":
		return
	var j := get_node_or_null("/root/Juice")
	if j: j.hit()
	HatchEngine.collect_ready_slot(index)
	if SaveManager:
		SaveManager.save_all()
	_refresh_slots()


func _inject_energy() -> void:
	if HatchEngine == null or EnergyEngine == null:
		return
	if max(EnergyEngine.reserve_tank, 0.0) <= 0.0:
		if Popups: Popups.show_toast("暂无备用能量")
		return
	if not HatchEngine.has_filling_egg():
		if Popups: Popups.show_toast("当前没有正在孵化的蛋")
		return
	if Popups:
		Popups.show_confirm("注入备用能量", "将备用能量注入当前孵化的蛋？", _do_inject)
	else:
		_do_inject()


func _do_inject() -> void:
	if HatchEngine == null or EnergyEngine == null:
		return
	var reserve: float = max(EnergyEngine.reserve_tank, 0.0)
	if reserve <= 0.0:
		return
	var used: float = HatchEngine.feed_current_egg(reserve)
	EnergyEngine.reserve_tank = max(reserve - used, 0.0)
	EnergyEngine.energy_changed.emit(EnergyEngine.energy_pool, EnergyEngine.MAX_ENERGY_POOL, EnergyEngine.reserve_tank)
	if SaveManager:
		SaveManager.save_all()
	_refresh_slots()


func _speed_up() -> void:
	if HatchEngine == null:
		return
	if not HatchEngine.has_filling_egg():
		if Popups: Popups.show_toast("当前没有正在孵化的蛋")
		return
	if not HatchEngine.can_ad_speedup():
		if Popups: Popups.show_toast("今日加速次数已用完")
		return
	HatchEngine.consume_ad_speedup()
	var used: float = HatchEngine.feed_current_egg(HatchEngine.AD_SPEEDUP_ENERGY)
	var leftover: float = HatchEngine.AD_SPEEDUP_ENERGY - used
	if leftover > 0.0 and EnergyEngine:
		EnergyEngine.add_pool_with_overflow(leftover)
	if SaveManager:
		SaveManager.save_all()
	_refresh_all()


# ── 信号回调 ──

func _on_hatch_progress(_slot: int, _progress: float) -> void:
	_refresh_slots()


func _on_hatch_complete(cat_data) -> void:
	_refresh_slots()
	UIManager.push("res://scenes/S08_HatchShow.tscn", {"cat": cat_data})


func _on_energy_changed(_current: float, _pool_max: float, _backup: float) -> void:
	_refresh_reserve()


# ── 样式（Palette 上色，美术图就位后可逐步替换）──

func _style() -> void:
	_style_card(_energy_card)
	_set_panel_bg(_reserve_bar_bg, Color("EDE7D8"), 5)
	_reserve_bar_fill.color = Palette.MOSS
	# 返回键：白底圆形
	_style_button(_back_btn, Color.WHITE, Palette.BORDER, Palette.TEXT_PRIMARY, 17, 1)
	# 注入：幽灵按钮（白底 + AMBER 描边）
	_style_button(_inject_btn, Color.WHITE, Palette.AMBER, Palette.TEXT_PRIMARY, 12, 2)
	# 看广告补能量：浅 moss 底 + MOSS 字
	_style_button(_ad_btn, Palette.MOSS.lerp(Color.WHITE, 0.82), Palette.MOSS.lerp(Color.WHITE, 0.55), Palette.MOSS, 14, 1)
	# 工坊链接：扁平文字链
	_workshop_link.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_workshop_link.add_theme_color_override("font_hover_color", Palette.TEXT_PRIMARY)


func _style_card(p: Panel) -> void:
	if p == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(1)
	sb.border_color = Palette.BORDER
	sb.shadow_color = Palette.UI_SHADOW
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", sb)


func _set_panel_bg(p: Panel, c: Color, radius: int) -> void:
	if p == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)


func _style_button(b: Button, bg: Color, border: Color, fg: Color, radius: int, border_w: int) -> void:
	if b == null:
		return
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg if state != "pressed" else bg.darkened(0.10)
		sb.set_corner_radius_all(radius)
		if border_w > 0:
			sb.set_border_width_all(border_w)
			sb.border_color = border
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 6.0
		b.add_theme_stylebox_override(state, sb)
