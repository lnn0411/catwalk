extends UIPage
class_name S10_Album

enum Tab { CATS, CARDS, ACH }

const CARD_W := 330.0
const CARD_H := 200.0
const SLOT_COUNT := 10

const CARD_FILLED := preload("res://assets/art/ui/cat_house/cat_card_filled.png")
const CARD_EMPTY := preload("res://assets/art/ui/cat_house/cat_card_empty.png")
const LEVEL_BADGE := preload("res://assets/art/ui/cat_house/level_badge.png")
const TAB_SELECTED := preload("res://assets/art/ui/cat_house/tab_selected.png")
const TAB_UNSELECTED := preload("res://assets/art/ui/cat_house/tab_unselected.png")
const PORTRAIT_ORANGE := preload("res://assets/art/cats/portraits/reveal/portrait_orange.png")
const PORTRAIT_BRITISH := preload("res://assets/art/cats/portraits/reveal/portrait_british.png")
const PORTRAIT_SIAMESE := preload("res://assets/art/cats/portraits/reveal/portrait_siamese.png")

var _current_tab := Tab.CATS
var _cats: Array = []


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
	$CardScroll.visible = tab == Tab.CATS
	$PostcardsBox.visible = tab == Tab.CARDS
	$AchBox.visible = tab == Tab.ACH

	var buttons: Array[TextureButton] = [
		$TabBar/TabCats,
		$TabBar/TabCards,
		$TabBar/TabAch,
	]
	for i in buttons.size():
		var selected := i == tab
		buttons[i].texture_normal = TAB_SELECTED if selected else TAB_UNSELECTED
		buttons[i].modulate = Color.WHITE if selected else Color(1.0, 1.0, 1.0, 0.78)

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


func _populate_cat_cards() -> void:
	var grid := $CardScroll/CatsGrid as GridContainer
	if grid == null:
		return

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	var owned_count: int = mini(_cats.size(), SLOT_COUNT)
	for i in SLOT_COUNT:
		if i < owned_count:
			grid.add_child(_create_cat_card(_cats[i]))
		else:
			grid.add_child(_create_empty_card())


func _create_cat_card(cat) -> TextureButton:
	var species := _cat_str(cat, "species", _cat_str(cat, "breed", "orange"))
	var name_text := _cat_str(cat, "name", _cat_str(cat, "display_name", _breed_label(species)))
	var level := _cat_int(cat, "level", 1)
	var cat_data := _cat_to_dict(cat)

	var card := TextureButton.new()
	card.name = "CatCard"
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.texture_normal = CARD_FILLED
	card.ignore_texture_size = true
	card.stretch_mode = TextureButton.STRETCH_SCALE
	card.region_enabled = true
	card.region_rect = Rect2(156, 245, 1217, 526)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.pressed.connect(func() -> void:
		_open_cat_detail(cat_data)
	)

	_add_avatar(card, species)
	_add_name(card, name_text, species)
	_add_level_badge(card, level)
	return card


func _create_empty_card() -> TextureRect:
	var card := TextureRect.new()
	card.name = "EmptyCard"
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.texture = CARD_EMPTY
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _add_avatar(card: Control, species: String) -> void:
	var diameter := 143.0
	var center := Vector2(68.0, 97.0)

	var clip := Control.new()
	clip.name = "AvatarClip"
	clip.position = center - Vector2.ONE * diameter * 0.5
	clip.size = Vector2.ONE * diameter
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(clip)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.texture = _portrait_for_species(species)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var circle_material := ShaderMaterial.new()
	var circle_shader := Shader.new()
	circle_shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float edge = 1.0 - smoothstep(0.485, 0.5, distance(UV, vec2(0.5)));
	COLOR = vec4(color.rgb, color.a * edge);
}
"""
	circle_material.shader = circle_shader
	portrait.material = circle_material
	clip.add_child(portrait)


func _add_name(card: Control, name_text: String, species: String) -> void:
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.position = Vector2(126.0, 40.0)
	name_label.size = Vector2(162.0, 38.0)
	name_label.text = name_text
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color("#4f453c"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)

	var breed_label := Label.new()
	breed_label.name = "Breed"
	breed_label.position = Vector2(126.0, 154.0)
	breed_label.size = Vector2(162.0, 28.0)
	breed_label.text = _breed_label(species)
	breed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	breed_label.add_theme_font_size_override("font_size", 15)
	breed_label.add_theme_color_override("font_color", Color(0.42, 0.35, 0.29, 0.78))
	breed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(breed_label)


func _add_level_badge(card: Control, level: int) -> void:
	var badge := TextureRect.new()
	badge.name = "LevelBadge"
	badge.position = Vector2(250.0, 21.0)
	badge.size = Vector2(44.0, 34.0)
	badge.texture = LEVEL_BADGE
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)

	var level_label := Label.new()
	level_label.name = "Level"
	level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_label.text = "Lv.%d" % level
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color("#4f453c"))
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(level_label)


func _portrait_for_species(species: String) -> Texture2D:
	match species:
		"british", "british_shorthair":
			return PORTRAIT_BRITISH
		"siamese":
			return PORTRAIT_SIAMESE
		_:
			return PORTRAIT_ORANGE


func _breed_label(species: String) -> String:
	match species:
		"british", "british_shorthair":
			return "英短"
		"siamese":
			return "暹罗"
		_:
			return "橘猫"


func _open_cat_detail(cat_data: Dictionary) -> void:
	var ui := get_node_or_null("/root/UIManager") as UIManager
	if ui:
		ui.push("res://ui/pages/S10_CatDetail.tscn", {"cat": cat_data})


func _on_tab_cats_pressed() -> void:
	_switch_tab(Tab.CATS)


func _on_tab_cards_pressed() -> void:
	_switch_tab(Tab.CARDS)


func _on_tab_ach_pressed() -> void:
	_switch_tab(Tab.ACH)


func _on_back_pressed() -> void:
	var ui := get_node_or_null("/root/UIManager") as UIManager
	if ui and ui.get_stack_depth() <= 1:
		ui.replace("res://scenes/S04_GardenMain.tscn")
	else:
		back_requested.emit()
