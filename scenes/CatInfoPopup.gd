extends CanvasLayer

signal closed

var cat_data

func _ready() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_clicked)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280.0, 350.0)
	card.add_theme_stylebox_override("panel", UITheme.get_modal_stylebox())
	center.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)

	var name_label := Label.new()
	name_label.text = cat_data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", _get_rarity_color(cat_data.rarity))
	content.add_child(name_label)

	var breed_label := Label.new()
	breed_label.text = "品种: " + _get_species_name(cat_data.species)
	breed_label.add_theme_font_size_override("font_size", 18)
	content.add_child(breed_label)

	var rarity_label := Label.new()
	rarity_label.text = "稀有度: " + _get_rarity_name(cat_data.rarity)
	rarity_label.add_theme_font_size_override("font_size", 18)
	rarity_label.add_theme_color_override("font_color", _get_rarity_color(cat_data.rarity))
	content.add_child(rarity_label)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_on_close)
	close_button.add_theme_stylebox_override("normal", UITheme.get_button_primary())
	content.add_child(close_button)

	var level_label := Label.new()
	level_label.text = "Lv." + str(cat_data.level)
	level_label.add_theme_font_size_override("font_size", 16)
	content.add_child(level_label)

func _get_species_name(species_name: String) -> String:
	match species_name:
		"orange":
			return "橘猫"
		"british":
			return "英短"
		"siamese":
			return "暹罗"
		_:
			return species_name

func _get_rarity_name(rarity: String) -> String:
	match rarity:
		"common":
			return "普通"
		"rare":
			return "稀有"
		"epic":
			return "史诗"
		"legendary":
			return "传说"
		_:
			return rarity

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Palette.RARITY_RARE
		"epic":
			return Palette.RARITY_EPIC
		"legendary":
			return Palette.AMBER
		_:
			return Palette.TEXT_PRIMARY

func _on_overlay_clicked(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close()

func _on_close() -> void:
	closed.emit()
	queue_free()
