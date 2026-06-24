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
	$VBox/Body/CatsGrid.visible = tab == Tab.CATS
	$VBox/Body/PostcardsBox.visible = tab == Tab.CARDS
	$VBox/Body/AchBox.visible = tab == Tab.ACH

	for i in 3:
		var btn := $VBox/Tabs.get_child(i) as Button
		if btn:
			btn.modulate = Color(1, 1, 1, 1.0) if i == tab else Color(1, 1, 1, 0.5)

	if tab == Tab.CATS:
		_refresh_cats()

func _populate_cat_cards() -> void:
	var grid := $VBox/Body/CatsGrid as GridContainer
	if grid == null:
		return

	# Clear existing cards
	for btn in _card_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_card_buttons.clear()

	# Remove static placeholder cards
	for child in grid.get_children():
		if child.name.begins_with("Card"):
			child.queue_free()

	if _cats.is_empty():
		return

	for i in range(_cats.size()):
		var cat = _cats[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_str: String = String(cat.get("name", "猫咪"))
		var breed: String = _breed_label(cat)
		var lv: int = int(cat.get("level", 1))
		btn.text = "%s — %s Lv.%d" % [name_str, breed, lv]
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		var cat_data: Dictionary = {}
		if cat is Dictionary:
			cat_data = cat
		elif cat.has_method("to_dict"):
			cat_data = cat.to_dict()
		else:
			# CatData object: manually convert fields
			for key in ["id", "name", "species", "breed", "level", "rarity", "friendship", "affection_lv", "is_following", "hatch_time"]:
				if cat.get(key) != null:
					cat_data[key] = cat.get(key)

		var idx := i
		btn.pressed.connect(func() -> void:
			_open_cat_detail(idx)
		)
		grid.add_child(btn)
		_card_buttons.append(btn)

func _open_cat_detail(index: int) -> void:
	if index < 0 or index >= _cats.size():
		return
	var cat = _cats[index]
	var cat_data: Dictionary = {}
	if cat is Dictionary:
		cat_data = cat
	elif cat.has_method("to_dict"):
		cat_data = cat.to_dict()
	else:
		for key in ["id", "name", "species", "breed", "level", "rarity", "friendship", "affection_lv", "is_following", "hatch_time"]:
			if cat.get(key) != null:
				cat_data[key] = cat.get(key)

	var ui := get_node_or_null("/root/UIManager") as UIManager
	if ui:
		ui.push("res://ui/pages/S10_CatDetail.tscn", {"cat": cat_data})

func _breed_label(cat) -> String:
	var species: String = String(cat.get("species", "orange")) if cat else "orange"
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
