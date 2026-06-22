extends Node2D
class_name AngrySymbol

var cat_id: String = ""

@onready var _label: Label = $Symbol
@onready var _timer: Timer = $FlashTimer

var _timeout_connected := false


func _ready() -> void:
	_label.visible = false
	_timer.wait_time = 0.5
	_timer.one_shot = false
	_ensure_timeout_connected()


func start_flashing(p_cat_id: String) -> void:
	cat_id = p_cat_id
	_label.visible = true
	_timer.wait_time = 0.5
	_timer.one_shot = false
	_ensure_timeout_connected()
	_timer.start()


func stop_flashing() -> void:
	_label.visible = false
	_timer.stop()


func _ensure_timeout_connected() -> void:
	if _timeout_connected:
		return

	_timer.timeout.connect(func() -> void:
		_label.visible = not _label.visible
	)
	_timeout_connected = true
