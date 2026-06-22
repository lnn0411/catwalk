extends GridContainer
class_name GiftInventoryGrid

signal gift_selected(gift_id: String)

const GiftItemViewScript := preload("res://ui/GiftItemView.gd")

var _gifts: Array[Dictionary] = []
var _detail_label: Label

func _ready() -> void:
	columns = 3
	visible = false

func populate(gifts: Array[Dictionary]) -> void:
	_gifts = gifts.duplicate(true)
	_clear_grid()
	if _gifts.is_empty():
		var empty := Label.new()
		empty.name = "EmptyStateLabel"
		empty.text = "还没有礼物哦，充满能量来获取吧～"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(360.0, 96.0)
		empty.add_theme_font_size_override("font_size", 16)
		add_child(empty)
		return
	for gift in _gifts:
		var item: Control = GiftItemViewScript.new()
		var item_data: Dictionary = Dictionary(gift.get("item_data", {}))
		var id := String(gift.get("gift_id", item_data.get("id", "")))
		item.setup(id, int(gift.get("count", 0)), item_data)
		item.gift_selected.connect(_on_item_selected)
		add_child(item)

func refresh() -> void:
	visible = true
	populate(_load_inventory_gifts())

func clear() -> void:
	visible = false
	_clear_grid()
	_gifts.clear()
	if _detail_label != null:
		_detail_label.queue_free()
		_detail_label = null

func _clear_grid() -> void:
	for child in get_children():
		if child == _detail_label:
			continue
		child.queue_free()

func _load_inventory_gifts() -> Array[Dictionary]:
	var inventory := _find_gift_inventory()
	if inventory != null and inventory.has_method("get_all_gifts"):
		var loaded = inventory.get_all_gifts()
		if loaded is Array:
			var typed: Array[Dictionary] = []
			for item in loaded:
				if item is Dictionary:
					typed.append(Dictionary(item))
			return typed
	return _gifts.duplicate(true)

func _find_gift_inventory() -> Node:
	var root := get_tree().root
	if root.has_node("GiftInventory"):
		return root.get_node("GiftInventory")
	var current: Node = self
	while current != null:
		if current.has_method("get_all_gifts") and current.has_method("add_gift"):
			return current
		current = current.get_parent()
	return null

func _on_item_selected(selected_gift_id: String) -> void:
	gift_selected.emit(selected_gift_id)
	_show_detail(selected_gift_id)

func _show_detail(selected_gift_id: String) -> void:
	var gift := _find_gift(selected_gift_id)
	var data: Dictionary = Dictionary(gift.get("item_data", {}))
	var name := String(data.get("name", selected_gift_id))
	var rarity := String(data.get("rarity", "common")).capitalize()
	var description := String(data.get("description", ""))
	var cnt := int(gift.get("count", 0))
	var text := "%s\n%s · x%d" % [name, rarity, cnt]
	if description != "":
		text += "\n%s" % description
	if has_node("/root/Popups"):
		var popups := get_node("/root/Popups")
		if popups.has_method("show_info"):
			popups.show_info(text)
			return
	if _detail_label != null:
		_detail_label.queue_free()
	_detail_label = Label.new()
	_detail_label.text = text
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_label.custom_minimum_size = Vector2(300.0, 112.0)
	_detail_label.size = Vector2(300.0, 112.0)
	_detail_label.top_level = true
	_detail_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_label.add_theme_font_size_override("font_size", 15)
	add_child(_detail_label)
	_detail_label.global_position = global_position + Vector2(20.0, 20.0)
	var tween := create_tween()
	_detail_label.modulate.a = 0.0
	tween.tween_property(_detail_label, "modulate:a", 1.0, 0.12)
	tween.tween_interval(2.6)
	tween.tween_property(_detail_label, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func() -> void:
		if _detail_label != null:
			_detail_label.queue_free()
			_detail_label = null)

func _find_gift(selected_gift_id: String) -> Dictionary:
	for gift in _gifts:
		if String(gift.get("gift_id", "")) == selected_gift_id:
			return gift
	return {}
