extends Node

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var w := get_window()
		if w != null:
			w.size = w.size
