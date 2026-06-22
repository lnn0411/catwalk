extends "res://ui/UIPage.gd"

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const SHOP_BG_PATH := "res://assets/art/ui/shop_bg.png"

# 商品表（对齐 GDD §12.1）
const PRODUCTS := [
	# 钻石商品
	{id="energy_small",   name="小能量包",   icon="🔋", price=50,  cur="diamonds", desc="回复3000能量",        type="consume_energy",  amt=3000},
	{id="energy_large",   name="大能量包",   icon="🔋", price=120, cur="diamonds", desc="回复8000能量",        type="consume_energy",  amt=8000},
	{id="hatch_boost",    name="孵化加速器", icon="⏩", price=80,  cur="diamonds", desc="孵化剩余时间减半",    type="hatch_boost"},
	{id="hatch_instant",  name="超级孵化器", icon="⚡", price=200, cur="diamonds", desc="孵化立即完成",        type="hatch_instant"},
	{id="snack_diamond",  name="零食礼包",   icon="🍪", price=60,  cur="diamonds", desc="获得5个零食",         type="add_item_snack",  amt=5},
	{id="deco_box",       name="装饰礼盒",   icon="🎁", price=100, cur="diamonds", desc="获得3个装饰碎片",      type="add_item_deco",   amt=3},
	# 金币商品
	{id="snack_gold",     name="零食（单个）", icon="🍪", price=500, cur="gold",    desc="获得1个零食",         type="add_item_snack",  amt=1},
	{id="ingredient_pack",name="食材碎片包",   icon="🧩", price=300, cur="gold",    desc="获得3个食材碎片",      type="add_item_ingredient", amt=3},
	# 花瓣商品（特殊）
	{id="garden_expand",  name="花园扩展包",   icon="🏡", price=3000,cur="petals",  desc="花园面积扩大·猫上限6→8", type="garden_expand", max_purchase=1},
]

const CUR_ICONS := {"gold": "💰", "diamonds": "💎", "petals": "🌸"}
const CUR_NAMES := {"gold": "金币", "diamonds": "钻石", "petals": "爱心花瓣"}

var _currency_labels := {"gold": null, "diamonds": null, "petals": null}
var _buy_buttons := {}  # product_id → Button
var _is_purchasing := false
var _back_rect: Rect2 = Rect2()

# ── 生命周期 ──

func _ready() -> void:
	super._ready()
	_build_background()
	_build_shop_ui()
	_refresh_currency()
	_refresh_all_buttons()
	_connect_signals()

func on_enter(_data: Dictionary = {}) -> void:
	super.on_enter(_data)
	_refresh_currency()
	_refresh_all_buttons()

func _connect_signals() -> void:
	if EventBus and not EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.connect(_on_currency_changed)

func _on_currency_changed(_g: int, _d: int, _p: int) -> void:
	_refresh_currency()

# ── 背景 ──

func _build_background() -> void:
	%Bg.visible = ResourceLoader.exists(SHOP_BG_PATH)
	if %Bg.visible:
		%Bg.texture = load(SHOP_BG_PATH)

# ── UI 构建 ──

func _build_shop_ui() -> void:
	# 主内容容器（保留 _draw_top_bar 区域）
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_top = 46.0   # 留给 _draw_top_bar
	margin.offset_left = 12.0
	margin.offset_right = -12.0
	margin.offset_bottom = -12.0
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	# 货币条
	_build_currency_bar(vb)

	# 商品列表（ScrollContainer）
	_build_product_list(vb)

	# 获得动画容器（覆盖全屏，初始隐藏）
	_build_obtain_overlay()

func _build_currency_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 56.0
	bar.add_theme_constant_override("separation", 6)
	parent.add_child(bar)

	var width := DESIGN_SIZE.x - 24.0  # margin 左右各 12
	var col_width := width / 3.0

	for kv in [["gold", "💰", Palette.AMBER], ["diamonds", "💎", Palette.MIST_BLUE], ["petals", "🌸", Palette.BRICK_RED]]:
		var key := String(kv[0])
		var icon := String(kv[1])
		var col := Color(kv[2])

		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size.x = col_width - 4
		var bg := StyleBoxFlat.new()
		bg.bg_color = Palette.BG_WARM_WHITE
		bg.set_corner_radius_all(6)
		bg.set_border_width_all(1)
		bg.border_color = Palette.BORDER_DEFAULT
		panel.add_theme_stylebox_override("panel", bg)

		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 4)
		panel.add_child(hb)

		var icon_label := Label.new()
		icon_label.text = icon
		icon_label.add_theme_font_size_override("font_size", 18)
		hb.add_child(icon_label)

		var val := Label.new()
		val.text = "0"
		val.add_theme_font_size_override("font_size", 16)
		val.add_theme_color_override("font_color", col)
		hb.add_child(val)

		bar.add_child(panel)
		_currency_labels[key] = val

func _build_product_list(parent: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	# 分类分隔
	var last_prefix := ""
	for p in PRODUCTS:
		var prefix := String(p.cur)
		if prefix != last_prefix:
			if last_prefix != "":
				# 分隔线
				var sep := HSeparator.new()
				list.add_child(sep)
			last_prefix = prefix
			var cat_label := Label.new()
			cat_label.text = CUR_NAMES.get(prefix, prefix)
			cat_label.add_theme_font_size_override("font_size", 16)
			cat_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
			list.add_child(cat_label)

		# 商品卡片
		var card := PanelContainer.new()
		var card_bg := StyleBoxFlat.new()
		card_bg.bg_color = Palette.BG_WARM_WHITE
		card_bg.set_corner_radius_all(6)
		card_bg.set_border_width_all(1)
		card_bg.border_color = Palette.BORDER_DEFAULT
		card.add_theme_stylebox_override("panel", card_bg)
		list.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size.y = 64.0
		card.add_child(row)

		# 图标
		var icon_label := Label.new()
		icon_label.text = String(p.get("icon", "🎁"))
		icon_label.add_theme_font_size_override("font_size", 28)
		icon_label.custom_minimum_size.x = 44
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(icon_label)

		# 信息
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name_label := Label.new()
		name_label.text = String(p.name)
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		info.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = "%s %s" % [CUR_ICONS.get(String(p.cur), "💎"), String(p.desc)]
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
		info.add_child(desc_label)

		# 购买按钮
		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(100, 48)
		var pid := String(p.id)
		buy_btn.pressed.connect(_on_buy_pressed.bind(pid))
		_style_buy_button(buy_btn)
		row.add_child(buy_btn)
		_buy_buttons[pid] = buy_btn

func _style_buy_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.AMBER
	normal.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", Palette.TEXT_ON_AMBER)
	btn.add_theme_font_size_override("font_size", 15)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Palette.CITY_GRAY
	disabled.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Palette.TEXT_ON_AMBER)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Palette.UI_PRESSED_AMBER
	pressed.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)

func _build_obtain_overlay() -> void:
	# 获得动画覆盖层（懒创建，首次购买时实例化）
	pass  # 在 _play_obtain_animation 中动态创建

# ── 数据刷新 ──

func _refresh_currency() -> void:
	if CurrencyManager == null:
		return
	if _currency_labels["gold"]:
		_currency_labels["gold"].text = str(CurrencyManager.get_gold())
	if _currency_labels["diamonds"]:
		_currency_labels["diamonds"].text = str(CurrencyManager.get_diamonds())
	if _currency_labels["petals"]:
		_currency_labels["petals"].text = str(CurrencyManager.get_petals())

func _refresh_all_buttons() -> void:
	var is_expand_owned := false
	if HatchEngine:
		is_expand_owned = HatchEngine.garden_expand_purchased

	for p in PRODUCTS:
		var pid := String(p.id)
		var btn: Button = _buy_buttons.get(pid)
		if btn == null:
			continue

		var owned := (pid == "garden_expand" and is_expand_owned)
		btn.disabled = owned
		btn.text = "已拥有" if owned else "购买"

		if not owned:
			# 货币不足检查
			var cur := String(p.cur)
			var price := int(p.price)
			var can_afford := false
			match cur:
				"gold":
					can_afford = CurrencyManager and CurrencyManager.gold_coins >= price
				"diamonds":
					can_afford = CurrencyManager and CurrencyManager.diamonds >= price
				"petals":
					can_afford = CurrencyManager and CurrencyManager.flower_petals >= price
			btn.disabled = not can_afford and pid != "garden_expand"

func _get_product(pid: String) -> Dictionary:
	for p in PRODUCTS:
		if String(p.id) == pid:
			return p
	return {}

# ── 购买流程 ──

func _on_buy_pressed(pid: String) -> void:
	if _is_purchasing:
		return

	var p := _get_product(pid)
	if p.is_empty():
		return

	var cur := String(p.cur)
	var price := int(p.price)

	# 查看加速/立即孵化：检查是否有进行中的孵化
	if String(p.type) in ["hatch_boost", "hatch_instant"]:
		if HatchEngine == null or not HatchEngine.has_filling_egg():
			Popups.show_toast("暂无进行中的孵化")
			return

	# 花园扩展包：已拥有
	if pid == "garden_expand" and HatchEngine and HatchEngine.garden_expand_purchased:
		Popups.show_toast("已拥有花园扩展包")
		return

	# 检查货币
	if not _can_afford(cur, price):
		_show_insufficient_toast(cur)
		return

	# 弹出确认窗
	_is_purchasing = true
	var dialog = load("res://scenes/ui/shop_confirm_dialog.tscn").instantiate()
	dialog.setup(p, func(): _execute_purchase(p), func(): _is_purchasing = false)
	add_child(dialog)

func _can_afford(cur: String, price: int) -> bool:
	if CurrencyManager == null:
		return false
	match cur:
		"gold":
			return CurrencyManager.gold_coins >= price
		"diamonds":
			return CurrencyManager.diamonds >= price
		"petals":
			return CurrencyManager.flower_petals >= price
	return false

func _show_insufficient_toast(cur: String) -> void:
	var msg := ""
	match cur:
		"gold":
			msg = "金币不足，快去走路赚金币吧！"
		"diamonds":
			msg = "钻石不足，完成成就获取更多钻石吧！"
		"petals":
			msg = "爱心花瓣不足，送养猫咪获得花瓣吧！"
		_:
			msg = "货币不足"
	Popups.show_toast(msg)

func _execute_purchase(p: Dictionary) -> void:
	_is_purchasing = true
	var cur := String(p.cur)
	var price := int(p.price)

	# 扣货币
	var spent := false
	match cur:
		"gold":
			spent = CurrencyManager.spend_gold(price)
		"diamonds":
			spent = CurrencyManager.spend_diamonds(price)
		"petals":
			spent = CurrencyManager.spend_petals(price)
	if not spent:
		_is_purchasing = false
		_show_insufficient_toast(cur)
		return

	# 发放物品/效果
	_grant_product(p)

	# 存档
	if SaveManager:
		SaveManager.save_all()

	# 刷新UI
	_refresh_currency()
	_refresh_all_buttons()

	# 获得动画
	_play_obtain_animation(p)

func _grant_product(p: Dictionary) -> void:
	var ptype := String(p.type)
	var amt := int(p.get("amt", 0))

	match ptype:
		"consume_energy":
			if EnergyEngine:
				var add_amt := min(float(amt), EnergyEngine.MAX_ENERGY_POOL - EnergyEngine.energy_pool)
				EnergyEngine.energy_pool += add_amt
				EnergyEngine._emit_energy_changed()
		"hatch_boost":
			if HatchEngine:
				HatchEngine.reduce_hatch_time(0.5)
		"hatch_instant":
			if HatchEngine:
				HatchEngine._force_hatch_complete()
		"add_item_snack":
			if InventoryManager:
				InventoryManager.add_item("snack", amt)
		"add_item_deco":
			if InventoryManager:
				InventoryManager.add_item("decoration_shard", amt)
		"add_item_ingredient":
			if InventoryManager:
				InventoryManager.add_item("ingredient_shard", amt)
		"garden_expand":
			_apply_garden_expand()

func _apply_garden_expand() -> void:
	if HatchEngine:
		HatchEngine.garden_expand_purchased = true
		HatchEngine.backpack_max_capacity = 36
		EventBus.backpack_capacity_expanded.emit(36)
	# 持久化到存档
	if SaveManager:
		SaveManager._config.set_value("shop", "garden_expand_purchased", true)
		SaveManager.save_all()

func _play_obtain_animation(p: Dictionary) -> void:
	# 创建覆盖层
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 半透明背景
	var shade := ColorRect.new()
	shade.color = Color(Palette.TEXT_PRIMARY, 0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)

	# 图标
	var icon := Label.new()
	icon.text = String(p.get("icon", "🎁"))
	icon.add_theme_font_size_override("font_size", 56)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_top = -40
	icon.offset_bottom = 16
	overlay.add_child(icon)

	# "获得！" 文字
	var text := Label.new()
	text.text = "获得！"
	text.add_theme_font_size_override("font_size", 24)
	text.add_theme_color_override("font_color", Palette.TEXT_ON_AMBER)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	text.offset_top = 36
	overlay.add_child(text)

	# 动画
	icon.scale = Vector2.ZERO
	text.modulate.a = 0.0

	var tween := create_tween().set_parallel(false)
	tween.tween_callback(func(): _is_purchasing = true)
	# 图标放大弹入
	tween.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.08)
	# 文字浮现
	tween.tween_property(text, "modulate:a", 1.0, 0.15)
	# 停留
	tween.tween_interval(0.8)
	# 淡出（续接到同一序列）
	tween.tween_property(overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
		_is_purchasing = false
	)

# ── 绘制（导航栏） ──

func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	if not %Bg.visible:
		draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE, true)
	_draw_top_bar()

func _draw_top_bar() -> void:
	_back_rect = Rect2(Vector2(28.0, 59.0), Vector2(85.0, 48.0))
	_draw_button(_back_rect, "返回", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_centered_text("商店", 91.0, 24, Palette.TEXT_PRIMARY)

func _draw_button(rect: Rect2, text: String, bg: Color, border: Color, text_color: Color) -> void:
	draw_rect(rect, bg, true)
	draw_rect(rect, border, false, 1.0)
	_draw_centered_in_rect(text, rect, 16, text_color)

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((DESIGN_SIZE.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_centered_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y + text_size.y) * 0.5 - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

# ── 交互（返回） ──

func _on_back() -> void:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")

func _gui_input(event: InputEvent) -> void:
	if _is_back_event(event):
		UIManager.replace("res://scenes/S04_GardenMain.tscn")
		accept_event()
		return

	var pos: Variant = _released_position(event)
	if pos == null:
		return
	var point: Vector2 = pos
	if _back_rect.has_point(point):
		UIManager.replace("res://scenes/S04_GardenMain.tscn")

func _released_position(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch and not event.pressed:
		return event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		return event.position
	return null

func _is_back_event(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_BACK
	)
