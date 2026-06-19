extends "res://ui/UIPage.gd"
# ============================================================
# S06 孵化室 —— B2 节点版（替代原 _draw 绘制）
# 结构在 S06_HatchPage.tscn；本脚本只负责绑定节点 + 状态驱动 + 交互。
# 逻辑（孵化/注入/加速/导航/信号）与原 _draw 版完全一致，未改玩法。
# 美术接入点：%Bg(整页背景) / HatchSlot 内部的 %FrameArt %EggArt / 各按钮可换 TextureButton。
# ============================================================

const CatData := preload("res://core/CatData.gd")
const RESERVE_BAR_W := 400.0

@onready var _bg: TextureRect = %Bg
@onready var _back_btn: Button = %BackBtn
@onready var _inject_btn: Button = %InjectBtn
@onready var _ad_btn: Button = %AdBtn
@onready var _reserve_panel: Panel = %ReservePanel
@onready var _reserve_bar_bg: Panel = %ReserveBarBg
@onready var _reserve_bar_fill: Panel = %ReserveBarFill
@onready var _reserve_value: Label = %ReserveValue
@onready var _slots: Array = [%Slot0, %Slot1, %Slot2, %Slot3]


func _ready() -> void:
	super._ready()
	_style()
	_back_btn.pressed.connect(_on_back_pressed)
	_inject_btn.pressed.connect(_inject_energy)
	_ad_btn.pressed.connect(_speed_up)
	for i in range(_slots.size()):
		_slots[i].slot_index = i
		if not _slots[i].slot_pressed.is_connected(_on_slot_pressed):
			_slots[i].slot_pressed.connect(_on_slot_pressed)
	# 背景美术就位才显示 TextureRect，否则透明露出 BgFallback 底色
	_bg.visible = _bg.texture != null
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
	_reserve_bar_fill.size = Vector2(_reserve_bar_bg.size.x * ratio, _reserve_bar_bg.size.y)
	_reserve_value.text = "%.0f / %.0f" % [current, max_value]


func _refresh_ad_button() -> void:
	var remaining: int = HatchEngine.ad_speedup_remaining() if HatchEngine else 0
	var limit: int = HatchEngine.AD_SPEEDUP_DAILY_LIMIT if HatchEngine else 3
	_ad_btn.text = "看广告加速 %d/%d" % [remaining, limit]
	_ad_btn.add_theme_color_override("font_color", Palette.TEXT_SECONDARY if remaining <= 0 else Palette.TEXT_PRIMARY)


# ── 交互 ──

func _on_back_pressed() -> void:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")


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
	_style_panel(_reserve_panel, Palette.BG_CEMENT, Palette.BORDER_DEFAULT, 5, 1)
	_style_panel(_reserve_bar_bg, Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, 5, 1)
	_style_panel(_reserve_bar_fill, Palette.AMBER, Palette.AMBER, 5, 0)
	_style_button(_back_btn, Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_style_button(_inject_btn, Palette.AMBER, Palette.AMBER, Palette.TEXT_ON_AMBER)
	_style_button(_ad_btn, Palette.BG_CEMENT, Palette.BORDER_ACTIVE, Palette.TEXT_PRIMARY)


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


func _style_button(b: Button, bg: Color, border: Color, fg: Color) -> void:
	if b == null:
		return
	b.add_theme_color_override("font_color", fg)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg if state != "pressed" else bg.darkened(0.12)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = border
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		b.add_theme_stylebox_override(state, sb)
