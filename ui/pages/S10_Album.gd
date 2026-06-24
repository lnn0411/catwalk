extends UIPage
class_name S10_Album

enum Tab { CATS, CARDS, ACH }
var _current_tab := Tab.CATS
var _cats: Array = []
var _card_buttons: Array[Button] = []

func _ready() -> void:
	super._ready()
	_switch_tab(Tab.CATS)

func on_enter(_data: Dictionary = {}) -> void:
	super.on_enter(_data)
	_refresh_cats()

func _refresh_cats() -> void:
	if HatchEngine:
		_cats = HatchEngine.get_cats()
	else:
		_cats = []
	_populate_cat_cards()

func _switch_tab(tab: Tab) -> void:
	_current_tab = tab
	$VBox/Body/Margin/CatsGrid.visible = tab == Tab.CATS
	$VBox/Body/Margin/PostcardsBox.visible = tab == Tab.CARDS
	$VBox/Body/Margin/AchBox.visible = tab == Tab.ACH

	for i in 3:
		var btn := $VBox/Tabs.get_child(i) as Button
		if btn:
			btn.modulate = Color(1, 1, 1, 1.0) if i == tab else Color(1, 1, 1, 0.5)

	if tab == Tab.CATS:
		_refresh_cats()

static func _cat_str(cat, field: String, fallback: String = "") -> String:
	if cat is Dictionary:
		return String(cat.get(field, fallback))
	var v = cat.get(field)
	return String(v) if v != null else fallback

static func _cat_int(cat, field: String, fallback: int = 0) -> int:
	if cat is Dictionary:
		return int(cat.get(field, fallback))
	var v = cat.get(field)
	return int(v) if v != null else fallback

func _cat_to_dict(cat) -> Dictionary:
	if cat is Dictionary:
		return cat.duplicate()
	var d := {}
	for key in ["id", "species", "rarity", "hatch_index", "display_name", "level", "exp", "friendship", "created_at"]:
		var v = cat.get(key)
		if v != null:
			d[key] = v
	d["name"] = d.get("display_name", "")
	d["breed"] = d.get("species", "")
	return d

# ── 稀有度 / 品种配色 ──
static func _rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":  return Color(0.95, 0.75, 0.06)  # gold
		"epic":       return Color(0.56, 0.27, 0.68)  # purple
		"rare":       return Color(0.25, 0.48, 0.82)  # blue
		_:            return Color(0.65, 0.65, 0.65)  # common gray

static func _rarity_bg(rarity: String) -> Color:
	match rarity:
		"legendary":  return Color(0.98, 0.94, 0.75)
		"epic":       return Color(0.92, 0.82, 0.96)
		"rare":       return Color(0.85, 0.90, 0.98)
		_:            return Color(0.93, 0.93, 0.93)

static func _breed_color(species: String) -> Color:
	match species:
		"british_shorthair", "british":  return Color(0.65, 0.75, 0.85)
		"siamese":         return Color(0.92, 0.85, 0.75)
		_:                 return Color(0.95, 0.72, 0.26)  # orange

static func _breed_short(species: String) -> String:
	match species:
		"british_shorthair", "british":  return "英"
		"siamese":         return "暹"
		_:                 return "橘"

func _populate_cat_cards() -> void:
	var grid := $VBox/Body/Margin/CatsGrid as GridContainer
	if grid == null:
		return
	for child in grid.get_children():
		if is_instance_valid(child):
			child.queue_free()
	_card_buttons.clear()

	if _cats.is_empty():
		return

	for i in range(_cats.size()):
		var cat = _cats[i]
		var card := _create_cat_card(cat, i)
		grid.add_child(card)
		_card_buttons.append(card)

const CARD_W := 165
const CARD_H := 120

func _create_cat_card(cat, index: int) -> Control:
	var species: String = _cat_str(cat, "species", "orange")
	var rarity: String = _cat_str(cat, "rarity", "common")
	var name_str: String = _cat_str(cat, "name", _cat_str(cat, "display_name", "猫咪"))
	var lv: int = _cat_int(cat, "level", 1)

	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_cat_detail(index)
	)

	# Background
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = _rarity_bg(rarity)
	card.add_child(bg)

	# Rarity stripe (top 4px)
	var stripe := ColorRect.new()
	stripe.name = "Stripe"
	stripe.anchor_left = 0.0
	stripe.anchor_right = 1.0
	stripe.anchor_top = 0.0
	stripe.anchor_bottom = 0.0
	stripe.offset_left = 0.0
	stripe.offset_right = 0.0
	stripe.offset_top = 0.0
	stripe.offset_bottom = 4.0
	stripe.color = _rarity_color(rarity)
	card.add_child(stripe)

	# Breed icon (colored circle placeholder)
	var icon := ColorRect.new()
	icon.name = "Icon"
	icon.anchor_left = 0.0
	icon.anchor_right = 0.0
	icon.anchor_top = 0.0
	icon.anchor_bottom = 0.0
	icon.offset_left = (CARD_W - 46.0) * 0.5
	icon.offset_top = 16.0
	icon.offset_right = icon.offset_left + 46.0
	icon.offset_bottom = icon.offset_top + 46.0
	icon.color = _breed_color(species)
	card.add_child(icon)

	var letter := Label.new()
	letter.name = "IconLetter"
	letter.anchor_left = 0.0
	letter.anchor_right = 1.0
	letter.anchor_top = 0.0
	letter.anchor_bottom = 1.0
	letter.offset_left = 0.0
	letter.offset_right = 0.0
	letter.offset_top = 0.0
	letter.offset_bottom = 0.0
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.text = _breed_short(species)
	letter.add_theme_font_size_override("font_size", 20)
	letter.theme_type_variation = &""
	letter.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	letter.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	icon.add_child(letter)

	# Level badge (top-right)
	var badge := ColorRect.new()
	badge.name = "LevelBadge"
	badge.anchor_left = 0.0
	badge.anchor_right = 0.0
	badge.anchor_top = 0.0
	badge.anchor_bottom = 0.0
	badge.offset_left = CARD_W - 42.0
	badge.offset_top = 4.0
	badge.offset_right = badge.offset_left + 36.0
	badge.offset_bottom = badge.offset_top + 18.0
	badge.color = _rarity_color(rarity)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)

	var lv_label := Label.new()
	lv_label.name = "LvText"
	lv_label.anchor_left = 0.0
	lv_label.anchor_right = 1.0
	lv_label.anchor_top = 0.0
	lv_label.anchor_bottom = 1.0
	lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_label.text = "Lv.%d" % lv
	lv_label.add_theme_font_size_override("font_size", 11)
	lv_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	badge.add_child(lv_label)

	# Name label
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.anchor_left = 0.0
	name_label.anchor_right = 1.0
	name_label.anchor_top = 0.0
	name_label.anchor_bottom = 0.0
	name_label.offset_left = 4.0
	name_label.offset_right = -4.0
	name_label.offset_top = 68.0
	name_label.offset_bottom = 88.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text = name_str
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	name_label.autowrap_mode = TextServer.AUTOWORD_WRAP
	card.add_child(name_label)

	# Breed label
	var breed_label := Label.new()
	breed_label.name = "Breed"
	breed_label.anchor_left = 0.0
	breed_label.anchor_right = 1.0
	breed_label.anchor_top = 0.0
	breed_label.anchor_bottom = 0.0
	breed_label.offset_left = 4.0
	breed_label.offset_right = -4.0
	breed_label.offset_top = 90.0
	breed_label.offset_bottom = 106.0
	breed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	breed_label.text = _breed_label(species)
	breed_label.add_theme_font_size_override("font_size", 10)
	breed_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	card.add_child(breed_label)

	return card

func _open_cat_detail(index: int) -> void:
	if index < 0 or index >= _cats.size():
		return
	var cat_data: Dictionary = _cat_to_dict(_cats[index])
	var ui := get_node_or_null("/root/UIManager") as UIManager
	if ui:
		ui.push("res://ui/pages/S10_CatDetail.tscn", {"cat": cat_data})

func _breed_label(species: String) -> String:
	match species:
		"british_shorthair":
			return "英短"
		"siamese":
			return "暹罗"
		_:
			return "橘猫"

func _on_tab_cats_pressed() -> void: _switch_tab(Tab.CATS)
func _on_tab_cards_pressed() -> void: _switch_tab(Tab.CARDS)
func _on_tab_ach_pressed() -> void: _switch_tab(Tab.ACH)

func _on_back_pressed() -> void:
	# Bottom nav uses replace, so stack may have only 1 item → pop does nothing
	# Navigate back to garden directly
	var ui := get_node_or_null("/root/UIManager") as UIManager
	if ui and ui.get_stack_depth() <= 1:
		ui.replace("res://scenes/S04_GardenMain.tscn")
	else:
		back_requested.emit()
