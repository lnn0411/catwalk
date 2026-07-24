extends "res://ui/UIPage.gd"
# ============================================================
# S06 孵化屋 —— 概念图 1:1 布局（贴图驱动）
# 结构在 S06_HatchPage.tscn；本脚本负责绑定节点 + 状态驱动 + 交互。
# ============================================================

const CatData := preload("res://core/CatData.gd")

@onready var _back_btn: TextureButton = %BackBtn
@onready var _ad_btn: TextureButton = %AdBtn
@onready var _workshop_link: Label = %WorkshopLink
@onready var _slots_parent: Array = [%Slot0, %Slot1, %Slot2, %Slot3]


func _ready() -> void:
	super._ready()
	_back_btn.pressed.connect(_on_back_pressed)
	_ad_btn.pressed.connect(_speed_up)
	# C1：工坊入口移至花园常驻 FAB，蛋 Tab 内链接隐藏
	if _workshop_link:
		_workshop_link.visible = false
	for i in range(_slots_parent.size()):
		var slot_node = _slots_parent[i]
		# 实例化 HatchSlot 到占位节点
		if slot_node.get_child_count() == 0:
			var packed := load("res://scenes/components/HatchSlot.tscn")
			var slot = packed.instantiate()
			slot.slot_index = i
			if not slot.slot_pressed.is_connected(_on_slot_pressed):
				slot.slot_pressed.connect(_on_slot_pressed)
			slot_node.add_child(slot)
	_build_anticipation_labels()
	_connect_data()
	_refresh_all()


func on_enter(_data: Dictionary = {}) -> void:
	_refresh_all()


# ── C2 期待感（P3）：保底进度 + 品种解锁预告（文字版，B4 进度条皮肤到货后换）──
var _pity_label: Label
var _unlock_label: Label

func _build_anticipation_labels() -> void:
	_pity_label = Label.new()
	_pity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pity_label.position = Vector2(0.0, 1128.0)
	_pity_label.size = Vector2(720.0, 26.0)
	_pity_label.add_theme_font_size_override("font_size", 14)
	_pity_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	add_child(_pity_label)
	_unlock_label = Label.new()
	_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_label.position = Vector2(0.0, 1156.0)
	_unlock_label.size = Vector2(720.0, 26.0)
	_unlock_label.add_theme_font_size_override("font_size", 14)
	_unlock_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	add_child(_unlock_label)

func _refresh_anticipation() -> void:
	if _pity_label == null:
		return
	if HatchEngine:
		var epic_left: int = HatchEngine.get_epic_pity_remaining()
		var leg_left: int = HatchEngine.get_legendary_pity_remaining()
		var epic_text: String = "下一颗必出史诗！" if epic_left <= 0 else "距必出史诗还剩 %d 颗" % epic_left
		var leg_text: String = "下一颗必出传说！" if leg_left <= 0 else "距必出传说还剩 %d 颗" % leg_left
		_pity_label.text = "✨ %s · %s" % [epic_text, leg_text]
	var hint: Dictionary = BreedUnlockEngine.get_next_unlock_hint() if BreedUnlockEngine else {}
	if hint.is_empty():
		_unlock_label.visible = false
	else:
		_unlock_label.visible = true
		_unlock_label.text = "🐾 再孵 %d 只%s，会有新朋友来花园" % [int(hint.get("remaining", 0)), String(hint.get("need_breed_name", ""))]


func handle_back() -> bool:
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
	_refresh_ad_button()
	_refresh_anticipation()


func _refresh_slots() -> void:
	var slots: Array = HatchEngine.get_slots() if HatchEngine else []
	for i in range(_slots_parent.size()):
		var data: Dictionary = Dictionary(slots[i]) if i < slots.size() else {}
		var slot_node = _slots_parent[i].get_child(0) if _slots_parent[i].get_child_count() > 0 else null
		if slot_node and slot_node.has_method("set_data"):
			slot_node.set_data(data)


func _refresh_ad_button() -> void:
	# P1 广告步行放大器：按钮实时显值（总案 §2.6-A 规格：取点击时刻的当日累计值）
	var remaining: int = HatchEngine.ad_speedup_remaining() if HatchEngine else 0
	var today_steps: int = StepEngine.get_today_steps() if StepEngine else 0
	var reward: int = int(HatchEngine.get_ad_speedup_energy()) if HatchEngine else 0
	var low_steps: bool = today_steps < HatchEngine.AD_MIN_STEPS_FOR_BUTTON
	var label := _ad_btn.get_node_or_null("AdLabel") as Label
	if label:
		if low_steps:
			label.text = "今日步行加成  走一走，加成更多"
		else:
			label.text = "今日步行加成 +%d⚡  今日还可%d次" % [reward, remaining]
		var dimmed: bool = low_steps or remaining <= 0
		label.add_theme_color_override("font_color", Color(1,1,1,0.5) if dimmed else Color(1,1,1,1))
	_ad_btn.disabled = low_steps or remaining <= 0


# ── 交互 ──

func _on_back_pressed() -> void:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")


# B3 包满弹窗「去扩容」直购（PackageSystem.try_purchase_next_tier）
func _try_expand() -> void:
	var result: Dictionary = PackageSystem.try_purchase_next_tier() if PackageSystem else {}
	if bool(result.get("success", false)):
		if Popups: Popups.show_toast("扩容成功！花园可以住 %d 只猫咪了" % int(result.get("capacity", 0)))
		_refresh_slots()
		return
	match String(result.get("reason", "")):
		"poor":
			if Popups: Popups.show_toast("金币不足，扩容需要 %d 金币" % int(result.get("cost", 0)))
		"locked":
			if Popups: Popups.show_toast("图鉴集满 %d 格后可扩容" % int(result.get("need_pokedex", 0)))
		_:
			if Popups: Popups.show_toast("已经是最大容量啦")


func _on_slot_pressed(index: int) -> void:
	if HatchEngine == null or index < 0:
		return
	var slots: Array = HatchEngine.get_slots()
	if index >= slots.size():
		return
	var slot_node = _slots_parent[index].get_child(0) if _slots_parent[index].get_child_count() > 0 else null
	if slot_node and slot_node.has_method("_effective_status") and slot_node._effective_status(Dictionary(slots[index])) != "ready":
		return
	# B3 包满引导弹窗（响应主动点击，三 CTA；蛋保持 ready 不卡死）
	if HatchEngine and HatchEngine.is_bag_full():
		if Popups:
			Popups.show_actions("花园住满啦～",
				"送养一只猫咪到云领养中心，\n或扩容猫包，就能迎接新朋友",
				[
					{"label": "去送养", "action": func() -> void: UIManager.push("res://scenes/S10_Album.tscn")},
					{"label": "去扩容", "action": _try_expand},
					{"label": "稍后", "action": Callable()},
				])
		return
	var j := get_node_or_null("/root/Juice")
	if j: j.hit()
	HatchEngine.collect_ready_slot(index)
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
	var reward: float = HatchEngine.get_ad_speedup_energy()
	if reward <= 0.0:
		if Popups: Popups.show_toast("走一走，加成更多")
		return
	HatchEngine.consume_ad_speedup()
	# P1：奖励封顶到当前蛋需求，余量不再回池（v2.2 §2.3，防池满囤积）
	HatchEngine.feed_current_egg(reward)
	if SaveManager:
		SaveManager.save_all()
	_refresh_all()


# ── 信号回调 ──

func _on_hatch_progress(_slot: int, _progress: float) -> void:
	_refresh_slots()


func _on_hatch_complete(cat_data) -> void:
	_refresh_slots()
	_refresh_anticipation()
	UIManager.push("res://scenes/S08_HatchShow.tscn", {"cat": cat_data})
	# C2 解锁演出强化：新品种解锁瞬间明确告知（原先只有静默布尔标记）
	if BreedUnlockEngine and BreedUnlockEngine.is_new_breed_unlocked():
		var breed_name := "新朋友"
		match BreedUnlockEngine.get_last_unlocked_breed():
			"british": breed_name = "英短"
			"siamese": breed_name = "暹罗"
		if Popups:
			Popups.show_toast("🎉 %s解锁！之后的蛋里可能会遇见它" % breed_name)


func _on_energy_changed(_current: float, _pool_max: float) -> void:
	_refresh_ad_button()  # 显值随当日能量实时变化
