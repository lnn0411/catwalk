extends UIPage
class_name S10_Album

enum Tab { CATS, CARDS, ACH }
var _current_tab := Tab.CATS

func _ready() -> void:
	super._ready()
	_switch_tab(Tab.CATS)

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
	back_requested.emit()
