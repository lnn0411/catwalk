extends UIPage
class_name S10_Album

enum Tab { CATS, CARDS, ACH }
var _current_tab := Tab.CATS

func _ready() -> void:
	super._ready()
	_switch_tab(Tab.CATS)
	_setup_cards()

func _setup_cards() -> void:
	var grid := $VBox/Body/CatsGrid
	for i in grid.get_child_count():
		var card := grid.get_child(i) as ColorRect
		if card:
			var btn := Button.new()
			btn.flat = true
			btn.size = Vector2(160, 180)
			btn.pressed.connect(func(): _on_card_pressed(i))
			card.add_child(btn)

func _on_card_pressed(index: int) -> void:
	var data := {"name": "猫咪%d" % (index + 1), "breed": "普通", "level": 4 - index}
	UIManager.replace("res://ui/pages/S10_CatDetail.tscn", data)

func _switch_tab(tab: Tab) -> void:
	_current_tab = tab
	$VBox/Body/CatsGrid.visible = tab == Tab.CATS
	$VBox/Body/PostcardsBox.visible = tab == Tab.CARDS
	$VBox/Body/AchBox.visible = tab == Tab.ACH
	
	for i in 3:
		var btn := $VBox/Tabs.get_child(i) as Button
		if btn:
			btn.modulate = Color(1, 1, 1, 1.0) if i == tab else Color(1, 1, 1, 0.5)

func _on_tab_cats_pressed() -> void: _switch_tab(Tab.CATS)
func _on_tab_cards_pressed() -> void: _switch_tab(Tab.CARDS)
func _on_tab_ach_pressed() -> void: _switch_tab(Tab.ACH)

func _on_back_pressed() -> void:
	UIManager.replace("res://scenes/S04_GardenMain.tscn")
