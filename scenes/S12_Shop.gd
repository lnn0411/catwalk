extends "res://ui/UIPage.gd"

const SHOP_BG_PATH := "res://assets/art/ui/shop_bg.png"

const PRODUCTS := [
	{"id":"small_energy","cat":"钻石","name":"小能量包","desc":"补充3000能量","cur":"diamonds","price":50,"type":"energy","amt":3000},
	{"id":"large_energy","cat":"钻石","name":"大能量包","desc":"补充8000能量","cur":"diamonds","price":120,"type":"energy","amt":8000},
	{"id":"hatch_speedup","cat":"钻石","name":"孵化加速器","desc":"注入3000能量到当前蛋","cur":"diamonds","price":80,"type":"hatch_energy","amt":3000},
	{"id":"super_hatcher","cat":"钻石","name":"超级孵化器","desc":"立即完成当前孵化蛋","cur":"diamonds","price":200,"type":"hatch_complete"},
	{"id":"snack_bundle","cat":"钻石","name":"零食礼包","desc":"获得5个零食","cur":"diamonds","price":60,"type":"item","item":"snack","amt":5},
	{"id":"decor_box","cat":"钻石","name":"装饰礼盒","desc":"获得3个装饰碎片","cur":"diamonds","price":100,"type":"item","item":"decoration_shard","amt":3},
	{"id":"snack","cat":"金币","name":"零食","desc":"获得1个零食","cur":"gold","price":500,"type":"item","item":"snack","amt":1},
	{"id":"ingredient_pack","cat":"金币","name":"食材碎片包","desc":"获得3个食材碎片","cur":"gold","price":300,"type":"item","item":"ingredient_shard","amt":3},
	{"id":"garden_expand","cat":"花瓣","name":"花园扩展包","desc":"上限6→8·仅1次","cur":"petals","price":3000,"type":"garden_expand"},
]

var _cur_labels := {}
var _btns := {}
var _pending := {}
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween

func _ready() -> void:
	super._ready()
	_build_ui()
	_refresh()
	if EventBus and not EventBus.currency_changed.is_connected(_refresh):
		EventBus.currency_changed.connect(_refresh)

func on_enter(_d := {}) -> void: _refresh()

func _refresh() -> void:
	_cur_labels.get("gold", Label.new()).text = str(CurrencyManager.get_gold() if CurrencyManager else 0)
	_cur_labels.get("diamonds", Label.new()).text = str(CurrencyManager.get_diamonds() if CurrencyManager else 0)
	_cur_labels.get("petals", Label.new()).text = str(CurrencyManager.get_petals() if CurrencyManager else 0)
	for p in PRODUCTS:
		var id := String(p.id)
		var btn: Button = _btns.get(id)
		if btn:
			var owned := id == "garden_expand" and SaveManager._config.get_value("shop","garden_expand",false)
			btn.disabled = owned
			btn.text = "已拥有" if owned else "%s %s" % [p.price, {diamonds="💎",gold="💰",petals="🌸"}.get(p.cur,"")]

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 46.0; root.offset_left = 24.0; root.offset_right = -24.0; root.offset_bottom = -24.0
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 56.0
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bar)
	var back := Button.new(); back.text = "← 返回"; back.pressed.connect(func(): UIManager.replace("res://scenes/S04_GardenMain.tscn"))
	bar.add_child(back)
	var title := Label.new(); title.text = "商店"; title.add_theme_font_size_override("font_size",26); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	bar.add_child(Control.new())  # spacer
	
	# Currency bar
	var cbar := HBoxContainer.new()
	cbar.add_theme_constant_override("separation", 8)
	cbar.custom_minimum_size.y = 60.0
	root.add_child(cbar)
	for kv in [["gold","💰金币"],["diamonds","💎钻石"],["petals","🌸花瓣"]]:
		var p := PanelContainer.new(); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := VBoxContainer.new(); b.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(b)
		var l := Label.new(); l.text = kv[1]; l.add_theme_font_size_override("font_size",13); l.add_theme_color_override("font_color",Palette.TEXT_SECONDARY); b.add_child(l)
		var v := Label.new(); v.text = "0"; v.add_theme_font_size_override("font_size",18); v.add_theme_color_override("font_color",Palette.TEXT_PRIMARY); b.add_child(v)
		cbar.add_child(p)
		_cur_labels[kv[0]] = v
	
	# Product list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	root.add_child(scroll)
	
	var last_cat := ""
	for p in PRODUCTS:
		var cat := String(p.cat)
		if cat != last_cat:
			var cl := Label.new(); cl.text = cat; cl.add_theme_font_size_override("font_size",16); cl.add_theme_color_override("font_color",Palette.TEXT_SECONDARY)
			list.add_child(cl)
			last_cat = cat
		# Card
		var card := PanelContainer.new()
		list.add_child(card)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",10)
		card.add_child(row)
		var vi := VBoxContainer.new(); vi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := Label.new(); nl.text = String(p.name); nl.add_theme_font_size_override("font_size",18)
		vi.add_child(nl)
		var dl := Label.new(); dl.text = String(p.desc); dl.add_theme_font_size_override("font_size",14); dl.add_theme_color_override("font_color",Palette.TEXT_SECONDARY)
		vi.add_child(dl)
		row.add_child(vi)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(120, 48)
		row.add_child(buy)
		_btns[String(p.id)] = buy
	
	# Toast
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false; _toast_panel.modulate.a = 0.0; _toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); _toast_panel.offset_top = -100; _toast_panel.offset_bottom = -50
	add_child(_toast_panel)
	_toast_label = Label.new(); _toast_label.add_theme_font_size_override("font_size",15); _toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)
	
	_refresh()

func _toast(t: String) -> void:
	if _toast_tween: _toast_tween.kill()
	_toast_label.text = t; _toast_panel.visible = true; _toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel,"modulate:a",1.0,0.15)
	_toast_tween.tween_interval(1.7)
	_toast_tween.tween_property(_toast_panel,"modulate:a",0.0,0.15)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)
