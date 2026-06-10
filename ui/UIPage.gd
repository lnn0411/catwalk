class_name UIPage
extends Control

signal page_ready(data: Dictionary)
signal back_requested

var page_data: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(data: Dictionary = {}) -> void:
	page_data = data.duplicate(true)
	_on_page_setup(page_data)
	page_ready.emit(page_data)

func on_enter(_data: Dictionary = {}) -> void:
	pass

func on_exit() -> void:
	pass

func can_go_back() -> bool:
	return true

func handle_back() -> bool:
	if not can_go_back():
		return true
	return false

func _on_page_setup(_data: Dictionary) -> void:
	pass
