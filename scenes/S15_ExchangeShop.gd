extends "res://ui/UIPage.gd"

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const SHOP_BG_PATH := "res://assets/art/ui/shop_bg.png"
const GARDEN_PATH := "res://scenes/S04_GardenMain.tscn"

const CUR_ICONS := {"gold": "💰", "diamonds": "💎", "petals": "🌸"}
const CUR_NAMES := {"gold": "金币", "diamonds": "钻石", "petals": "爱心花瓣"}

const PRODUCTS := [
	{"id": "energy_small", "name": "小能量包", "icon": "🔋", "price": 50, "cur": "diamonds", "desc": "回复3000能量", "type": "consume_energy", "amt": 3000},
	{"id": "energy_large", "name": "大能量包", "icon": "🔋", "price": 120, "cur": "diamonds", "desc": "回复8000能量", "type": "consume_energy", "amt": 8000},
	{"id": "hatch_boost", "name": "孵化加速器", "icon": "⏩", "price": 30, "cur": "diamonds", "desc": "孵化剩余时间减半", "type": "hatch_boost"},
	{"id": "hatch_instant", "name": "超级孵化器", "icon": "⚡", "price": 80, "cur": "diamonds", "desc": "孵化立即完成", "type": "hatch_instant"},
	{"id": "snack_diamond", "name": "零食礼包", "icon": "🍪", "price": 60, "cur": "diamonds", "desc": "获得5个零食", "type": "add_item_snack", "amt": 5},
	{"id": "deco_box", "name": "装饰礼盒", "icon": "🎁", "price": 100, "cur": "diamonds", "desc": "获得3个装饰碎片", "type": "add_item_deco", "amt": 3},
	{"id": "snack_gold", "name": "零食（单个）", "icon": "🍪", "price": 500, "cur": "gold", "desc": "获得1个零食", "type": "add_item_snack", "amt": 1},
	{"id": "ingredient_pack", "name": "食材碎片包", "icon": "🧩", "price": 300, "cur": "gold", "desc": "获得3个食材碎片", "type": "add_item_ingredient", "amt": 3},
	{"id": "garden_expand", "name": "花园扩展包", "icon": "🏡", "price": 3000, "cur": "petals", "desc": "花园面积扩大·猫上限+2", "type": "garden_expand", "max_purchase": 1},
]

var _currency_labels := {"diamonds": null, "gold": null, "petals": null}
var _buy_buttons: Dictionary = {}
var _product_by_id: Dictionary = {}
var _is_purchasing := false
var _back_rect: Rect2 = Rect2()

func _ready() -> void:
	super._ready()
	_index_products()
	_build_background()
	_build_shop_ui()
	_connect_signals()
	_refresh_currency()
	_refresh_all_buttons()
	queue_redraw()

func on_enter(_data: Dictionary = {}) -> void:
	super.on_enter(_data)
	_refresh_currency()
	_refresh_all_buttons()
	queue_redraw()

func _connect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and not event_bus.currency_changed.is_connected(_on_currency_changed):
		event_bus.currency_changed.connect(_on_currency_changed)

func _on_currency_changed(_gold: int, _diamonds: int, _petals: int) -> void:
	_refresh_currency()

func _index_products() -> void:
	_product_by_id.clear()
	for product in PRODUCTS:
		_product_by_id[String(product.get("id", ""))] = product

func _build_background() -> void:
	var bg := get_node_or_null("%Bg")
	if bg == null:
		return
	bg.show_behind_parent = true
	bg.visible = ResourceLoader.exists(SHOP_BG_PATH)
	if bg.visible:
		bg.texture = load(SHOP_BG_PATH)

func _build_shop_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 24.0
	margin.offset_top = 124.0
	margin.offset_right = -24.0
	margin.offset_bottom = -24.0
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	_build_currency_bar(content)
	_build_section_header(content)
	_build_product_list(content)

func _build_currency_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 64.0
	bar.add_theme_constant_override("separation", 10)
	parent.add_child(bar)

	for data in [["diamonds", CUR_ICONS["diamonds"], Palette.MIST_BLUE], ["gold", CUR_ICONS["gold"], Palette.AMBER], ["petals", CUR_ICONS["petals"], Palette.BRICK_RED]]:
		var key := String(data[0])
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _make_card_style())
		bar.add_child(panel)

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		panel.add_child(row)

		var icon := Label.new()
		icon.text = String(data[1])
		icon.add_theme_font_size_override("font_size", 19)
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(icon)

		var value := Label.new()
		value.text = "0"
		value.add_theme_font_size_override("font_size", 17)
		value.add_theme_color_override("font_color", Color(data[2]))
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(value)
		_currency_labels[key] = value

func _build_section_header(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "兑换"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	parent.add_child(header)

func _build_product_list(parent: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var last_cur := ""
	for product in PRODUCTS:
		var cur := String(product.get("cur", ""))
		if last_cur != "" and cur != last_cur:
			var separator := HSeparator.new()
			separator.add_theme_color_override("separator", Palette.BORDER_DEFAULT)
			list.add_child(separator)
		_build_product_card(list, product)
		last_cur = cur

func _build_product_card(parent: VBoxContainer, product: Dictionary) -> void:
	var product_id := String(product.get("id", ""))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style())
	parent.add_child(card)

	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 82.0
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icon := Label.new()
	icon.text = String(product.get("icon", "🎁"))
	icon.custom_minimum_size.x = 54.0
	icon.add_theme_font_size_override("font_size", 30)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = String(product.get("name", product_id))
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = String(product.get("desc", ""))
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.y = 34.0
	info.add_child(desc_label)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(124.0, 48.0)
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.pressed.connect(_on_buy_pressed.bind(product_id))
	_style_buy_button(buy_btn)
	row.add_child(buy_btn)
	_buy_buttons[product_id] = buy_btn

func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BG_WARM_WHITE
	style.border_color = Palette.BORDER_DEFAULT
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style

func _style_buy_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.AMBER
	normal.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Palette.AMBER
	hover.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Palette.UI_PRESSED_AMBER
	pressed.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Palette.CITY_GRAY
	disabled.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", Palette.TEXT_ON_AMBER)
	btn.add_theme_color_override("font_hover_color", Palette.TEXT_ON_AMBER)
	btn.add_theme_color_override("font_pressed_color", Palette.TEXT_ON_AMBER)
	btn.add_theme_color_override("font_disabled_color", Palette.TEXT_ON_AMBER)
	btn.add_theme_font_size_override("font_size", 16)

func _refresh_currency() -> void:
	var currency := get_node_or_null("/root/CurrencyManager")
	if currency == null:
		return
	if _currency_labels["diamonds"]:
		_currency_labels["diamonds"].text = str(currency.get_diamonds())
	if _currency_labels["gold"]:
		_currency_labels["gold"].text = str(currency.get_gold())
	if _currency_labels["petals"]:
		_currency_labels["petals"].text = str(currency.get_petals())

func _refresh_all_buttons() -> void:
	for product_id in _buy_buttons.keys():
		var btn: Button = _buy_buttons[product_id]
		if btn == null:
			continue
		var product: Dictionary = _product_by_id.get(product_id, {})
		btn.text = _get_button_text(product)
		btn.disabled = _is_purchasing or _is_product_owned(product)

func _get_button_text(product: Dictionary) -> String:
	if _is_product_owned(product):
		return "已拥有"
	var cur := String(product.get("cur", ""))
	var icon := String(CUR_ICONS.get(cur, ""))
	return "%s%d" % [icon, int(product.get("price", 0))]

func _is_product_owned(product: Dictionary) -> bool:
	if String(product.get("type", "")) != "garden_expand":
		return false
	var hatch := get_node_or_null("/root/HatchEngine")
	if hatch == null:
		return false
	return bool(hatch.garden_expand_purchased)

func _on_buy_pressed(product_id: String) -> void:
	if _is_purchasing:
		return
	var product: Dictionary = _product_by_id.get(product_id, {})
	if product.is_empty():
		return
	if not _can_purchase_product(product):
		return

	_is_purchasing = true
	_refresh_all_buttons()

	var spent := _spend_currency(product)
	if not spent:
		_is_purchasing = false
		_show_toast("%s不足" % String(CUR_NAMES.get(String(product.get("cur", "")), "货币")))
		_refresh_all_buttons()
		return

	_grant_product(product)
	_save_all()
	_refresh_currency()
	_is_purchasing = false
	_refresh_all_buttons()
	_show_toast("兑换成功")
	_play_obtain_animation(product)

func _can_purchase_product(product: Dictionary) -> bool:
	match String(product.get("type", "")):
		"hatch_boost", "hatch_instant":
			var hatch := get_node_or_null("/root/HatchEngine")
			if hatch == null or not hatch.has_filling_egg():
				_show_toast("暂无进行中的孵化")
				return false
		"garden_expand":
			if _is_product_owned(product):
				_show_toast("已拥有")
				_refresh_all_buttons()
				return false
	return true

func _spend_currency(product: Dictionary) -> bool:
	var currency := get_node_or_null("/root/CurrencyManager")
	if currency == null:
		return false
	var price := int(product.get("price", 0))
	match String(product.get("cur", "")):
		"gold":
			return currency.spend_gold(price)
		"diamonds":
			return currency.spend_diamonds(price)
		"petals":
			return currency.spend_petals(price)
	return false

func _grant_product(product: Dictionary) -> void:
	var amount := int(product.get("amt", 0))
	match String(product.get("type", "")):
		"consume_energy":
			var energy := get_node_or_null("/root/EnergyEngine")
			if energy and energy.has_method("add_pool_with_overflow"):
				energy.add_pool_with_overflow(amount)
		"hatch_boost":
			var hatch := get_node_or_null("/root/HatchEngine")
			if hatch and hatch.has_method("reduce_hatch_time"):
				hatch.reduce_hatch_time(0.5)
		"hatch_instant":
			var hatch := get_node_or_null("/root/HatchEngine")
			if hatch and hatch.has_method("_force_hatch_complete"):
				hatch._force_hatch_complete()
		"add_item_snack":
			_add_inventory_item("snack", amount)
		"add_item_deco":
			_add_inventory_item("decoration_shard", amount)
		"add_item_ingredient":
			_add_inventory_item("ingredient_shard", amount)
		"garden_expand":
			_grant_garden_expand()

func _add_inventory_item(item_id: String, amount: int) -> void:
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory and inventory.has_method("add_item"):
		inventory.add_item(item_id, amount)

func _grant_garden_expand() -> void:
	var hatch := get_node_or_null("/root/HatchEngine")
	if hatch:
		hatch.garden_expand_purchased = true
	var package_system := get_node_or_null("/root/PackageSystem")
	if package_system and package_system.has_method("set_capacity"):
		package_system.set_capacity(36)

func _save_all() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("save_all"):
		save_manager.save_all()

func _play_obtain_animation(product: Dictionary) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var shade := ColorRect.new()
	shade.color = Color(Palette.TEXT_PRIMARY, 0.28)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)

	var icon := Label.new()
	icon.text = String(product.get("icon", "🎁"))
	icon.add_theme_font_size_override("font_size", 58)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -60.0
	icon.offset_top = -66.0
	icon.offset_right = 60.0
	icon.offset_bottom = 6.0
	overlay.add_child(icon)

	var text := Label.new()
	text.text = "获得！"
	text.add_theme_font_size_override("font_size", 24)
	text.add_theme_color_override("font_color", Palette.TEXT_ON_AMBER)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	text.offset_left = -90.0
	text.offset_top = 12.0
	text.offset_right = 90.0
	text.offset_bottom = 62.0
	overlay.add_child(text)

	icon.pivot_offset = Vector2(60.0, 36.0)
	icon.scale = Vector2.ZERO
	text.modulate.a = 0.0

	var tween := create_tween().set_parallel(false)
	tween.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.08)
	tween.tween_property(text, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.75)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
	)

func _show_toast(msg: String) -> void:
	var popups := get_node_or_null("/root/Popups")
	if popups and popups.has_method("show_toast"):
		popups.show_toast(msg)

func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var bg := get_node_or_null("%Bg")
	if bg == null or not bg.visible:
		draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE, true)
	_draw_top_bar()

func _draw_top_bar() -> void:
	_back_rect = Rect2(Vector2(28.0, 59.0), Vector2(85.0, 48.0))
	_draw_button(_back_rect, "返回", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_centered_text("兑换商店", 91.0, 24, Palette.TEXT_PRIMARY)

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

func _gui_input(event: InputEvent) -> void:
	if _is_back_event(event):
		_go_back()
		accept_event()
		return

	var pos: Variant = _released_position(event)
	if pos == null:
		return
	var point: Vector2 = pos
	if _back_rect.has_point(point):
		_go_back()
		accept_event()

func _go_back() -> void:
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager and ui_manager.has_method("replace"):
		ui_manager.replace(GARDEN_PATH)

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
