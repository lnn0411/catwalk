extends "res://ui/UIPage.gd"

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const SHOP_BG_PATH := "res://assets/art/ui/shop_bg.png"
const GARDEN_PATH := "res://scenes/S04_GardenMain.tscn"
const EXCHANGE_PATH := "res://scenes/S15_ExchangeShop.tscn"

const CUR_ICON_PATHS := {
	"diamonds": "res://assets/art/ui/icons/icon_gem.png",
	"gold": "res://assets/art/ui/icons/icon_coin.png",
	"petals": "res://assets/art/ui/icons/icon_petal.png",
}

var _currency_labels := {"diamonds": null, "gold": null, "petals": null}
var _buy_buttons: Dictionary = {}
var _is_purchasing := false
var _back_rect: Rect2 = Rect2()
var _exchange_rect: Rect2 = Rect2()
var _last_purchase_sku := ""

func _ready() -> void:
	super._ready()
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

	var iap := _get_iap_provider()
	if iap and not iap.purchase_completed.is_connected(_on_purchase_completed):
		iap.purchase_completed.connect(_on_purchase_completed)

func _on_currency_changed(_gold: int, _diamonds: int, _petals: int) -> void:
	_refresh_currency()

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

	for data in [["diamonds", CUR_ICON_PATHS["diamonds"], Palette.MIST_BLUE], ["gold", CUR_ICON_PATHS["gold"], Palette.AMBER], ["petals", CUR_ICON_PATHS["petals"], Palette.BRICK_RED]]:
		var key := String(data[0])
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _make_card_style())
		bar.add_child(panel)

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		panel.add_child(row)

		var icon := TextureRect.new()
		icon.texture = load(String(data[1]))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(28, 28)
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
	header.text = "IAP商店"
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

	var iap := _get_iap_provider()
	if iap == null:
		return

	var skus: Dictionary = iap.SKUS
	for sku_id in skus.keys():
		var sku: Dictionary = skus[sku_id]
		_build_product_card(list, String(sku_id), sku)

func _build_product_card(parent: VBoxContainer, sku_id: String, sku: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style())
	parent.add_child(card)

	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 82.0
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icon: Control
	var emoji := String(sku.get("icon", "🎁"))
	var tex_path := _emoji_to_icon_path(emoji)
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tr := TextureRect.new()
		tr.texture = load(tex_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(40, 40)
		icon = tr
	else:
		var lb := Label.new()
		lb.text = emoji
		lb.add_theme_font_size_override("font_size", 30)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon = lb
	icon.custom_minimum_size.x = 54.0
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = String(sku.get("name", sku_id))
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = String(sku.get("desc", ""))
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.y = 34.0
	info.add_child(desc_label)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(112.0, 48.0)
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.pressed.connect(_on_buy_pressed.bind(sku_id))
	_style_buy_button(buy_btn)
	row.add_child(buy_btn)
	_buy_buttons[sku_id] = buy_btn

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
	var iap := _get_iap_provider()
	if iap == null:
		return
	var skus: Dictionary = iap.SKUS
	for sku_id in _buy_buttons.keys():
		var btn: Button = _buy_buttons[sku_id]
		if btn == null:
			continue
		var sku: Dictionary = skus.get(sku_id, {})
		var state := _get_button_state(String(sku_id), sku)
		btn.text = String(state.get("text", "购买"))
		btn.disabled = bool(state.get("disabled", false)) or _is_purchasing

func _get_button_state(sku_id: String, sku: Dictionary) -> Dictionary:
	var iap := _get_iap_provider()
	var price_text := "¥%d" % int(sku.get("price_yuan", 0))
	if iap == null:
		return {"text": price_text, "disabled": true}

	match sku_id:
		"remove_ads":
			if iap.is_ads_removed():
				return {"text": "已去广告", "disabled": true}
		"garden_expand":
			if iap.is_owned("garden_expand"):
				return {"text": "已拥有", "disabled": true}
		"breed_unlock":
			if iap.is_owned("breed_unlock"):
				return {"text": "已解锁", "disabled": true}
		"newbie_pack":
			if iap.is_owned("newbie_pack"):
				return {"text": "已购买", "disabled": true}
		"limited_skin":
			if iap.is_owned("limited_skin"):
				return {"text": "已拥有", "disabled": true}
		"monthly_card":
			var days_left := int(iap.get_monthly_card_days_left())
			if days_left > 0:
				return {"text": "已激活(%d天)" % days_left, "disabled": true}
	return {"text": price_text, "disabled": false}

func _on_buy_pressed(sku_id: String) -> void:
	if _is_purchasing:
		return
	var iap := _get_iap_provider()
	if iap == null:
		_show_toast("购买失败")
		return

	_is_purchasing = true
	_last_purchase_sku = sku_id
	_refresh_all_buttons()
	iap.purchase(sku_id)

func _on_purchase_completed(sku_id: String, success: bool) -> void:
	if _last_purchase_sku != "" and sku_id != _last_purchase_sku:
		return
	_is_purchasing = false
	_last_purchase_sku = ""

	if success:
		_show_toast("购买成功")
		_refresh_currency()
		_refresh_all_buttons()
		_play_obtain_animation(sku_id)
	else:
		_show_toast("购买失败")
		_refresh_all_buttons()

	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("save_all"):
		save_manager.save_all()

func _emoji_to_icon_path(emoji: String) -> String:
	match emoji:
		"💎": return "res://assets/art/ui/icons/icon_gem.png"
		"💰": return "res://assets/art/ui/icons/icon_coin.png"
		"🌸": return "res://assets/art/ui/icons/icon_petal.png"
	return ""


func _play_obtain_animation(sku_id: String) -> void:
	var iap := _get_iap_provider()
	var sku: Dictionary = {}
	if iap:
		sku = iap.SKUS.get(sku_id, {})

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var shade := ColorRect.new()
	shade.color = Color(Palette.TEXT_PRIMARY, 0.28)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)

	var icon: Control
	var emoji := String(sku.get("icon", "🎁"))
	var tex_path := _emoji_to_icon_path(emoji)
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tr := TextureRect.new()
		tr.texture = load(tex_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(80, 80)
		icon = tr
	else:
		var lb := Label.new()
		lb.text = emoji
		lb.add_theme_font_size_override("font_size", 58)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon = lb
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

func _get_iap_provider() -> Node:
	return get_node_or_null("/root/IAPProvider")

# ── 绘制（导航栏） ──

func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var bg := get_node_or_null("%Bg")
	if bg == null or not bg.visible:
		draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_WARM_WHITE, true)
	_draw_top_bar()

func _draw_top_bar() -> void:
	_back_rect = Rect2(Vector2(28.0, 59.0), Vector2(85.0, 48.0))
	_draw_button(_back_rect, "返回", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)
	_draw_centered_text("商店", 91.0, 24, Palette.TEXT_PRIMARY)
	_exchange_rect = Rect2(Vector2(DESIGN_SIZE.x - 120.0, 59.0), Vector2(90.0, 48.0))
	_draw_button(_exchange_rect, "兑换", Palette.BG_WARM_WHITE, Palette.BORDER_DEFAULT, Palette.TEXT_PRIMARY)

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
	_go_back()

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
	elif _exchange_rect.has_point(point):
		_go_exchange()
		accept_event()

func _go_back() -> void:
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager and ui_manager.has_method("replace"):
		ui_manager.replace(GARDEN_PATH)

func _go_exchange() -> void:
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager and ui_manager.has_method("replace"):
		ui_manager.replace(EXCHANGE_PATH)

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
