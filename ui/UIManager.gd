extends Node

signal page_changed(page_name: String)

const UIPage := preload("res://ui/UIPage.gd")
const TRANSITION_TIME := 0.25
const OVERLAY_TIME := 0.2
const CANVAS_LAYER := 10

var stack: Array[UIPage] = []
var _canvas_layer: CanvasLayer
var _overlay: UIPage
var _transitioning := false
var _transition_tween: Tween
var _operation_queue: Array = []

func _ready() -> void:
	_ensure_canvas_layer()
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_BACK
	):
		go_back()
		get_viewport().set_input_as_handled()

func push(scene_path: String, data: Dictionary = {}, instant: bool = false) -> UIPage:
	if _transitioning:
		_enqueue(func() -> void: push(scene_path, data, instant))
		return null

	var page := _load_page(scene_path, data)
	if page == null:
		return null

	var outgoing := _current_page()
	stack.append(page)
	_canvas_layer.add_child(page)
	page.on_enter(data)
	if outgoing != null:
		outgoing.on_exit()
	_transitioning = true

	var width := _viewport_width()
	page.position = Vector2(width, 0.0)
	page.modulate.a = 1.0

	if instant or outgoing == null:
		page.position = Vector2.ZERO
		_finish_transition(page)
		return page

	_kill_tween()
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(page, "position:x", 0.0, TRANSITION_TIME)
	_transition_tween.tween_property(outgoing, "position:x", -width * 0.25, TRANSITION_TIME)
	_transition_tween.finished.connect(func() -> void:
		if is_instance_valid(outgoing):
			outgoing.visible = false
			outgoing.position = Vector2.ZERO
		_finish_transition(page)
	)
	return page

func pop(instant: bool = false) -> void:
	if _transitioning:
		_enqueue(func() -> void: pop(instant))
		return
	if stack.size() <= 1:
		page_changed.emit(_current_page_name())
		return

	var outgoing: UIPage = stack.pop_back()
	var incoming: UIPage = _current_page()
	if incoming != null:
		incoming.visible = true
		incoming.position = Vector2.ZERO
		incoming.on_enter(incoming.page_data)

	outgoing.on_exit()
	_transitioning = true
	var width := _viewport_width()

	if instant:
		outgoing.queue_free()
		_finish_transition(incoming)
		return

	_kill_tween()
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(outgoing, "position:x", width, TRANSITION_TIME)
	_transition_tween.tween_property(incoming, "position:x", 0.0, TRANSITION_TIME)
	_transition_tween.finished.connect(func() -> void:
		if is_instance_valid(outgoing):
			outgoing.queue_free()
		_finish_transition(incoming)
	)

func replace(scene_path: String, data: Dictionary = {}, instant: bool = false) -> UIPage:
	if _transitioning:
		_enqueue(func() -> void: replace(scene_path, data, instant))
		return null

	if stack.is_empty():
		return push(scene_path, data, instant)

	var outgoing: UIPage = stack.pop_back()
	var page: UIPage = _load_page(scene_path, data)
	if page == null:
		stack.append(outgoing)
		return null

	stack.append(page)
	_canvas_layer.add_child(page)
	page.on_enter(data)
	outgoing.on_exit()
	_transitioning = true

	var width := _viewport_width()
	page.position = Vector2(width, 0.0)

	if instant:
		outgoing.queue_free()
		page.position = Vector2.ZERO
		_finish_transition(page)
		return page

	_kill_tween()
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(page, "position:x", 0.0, TRANSITION_TIME)
	_transition_tween.tween_property(outgoing, "position:x", width, TRANSITION_TIME)
	_transition_tween.finished.connect(func() -> void:
		if is_instance_valid(outgoing):
			outgoing.queue_free()
		_finish_transition(page)
	)
	return page

func show_overlay(scene_path: String, data: Dictionary = {}) -> UIPage:
	if _transitioning:
		_enqueue(func() -> void: show_overlay(scene_path, data))
		return null
	if _overlay != null and is_instance_valid(_overlay):
		close_overlay()

	var page := _load_page(scene_path, data)
	if page == null:
		return null

	_overlay = page
	_canvas_layer.add_child(page)
	page.on_enter(data)
	page.modulate.a = 0.0
	_transitioning = true

	_kill_tween()
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(page, "modulate:a", 1.0, OVERLAY_TIME)
	_transition_tween.finished.connect(func() -> void:
		_transitioning = false
		_flush_queue()
	)
	return page

func close_overlay() -> void:
	if _transitioning:
		_enqueue(func() -> void: close_overlay())
		return
	if _overlay == null or not is_instance_valid(_overlay):
		_overlay = null
		return

	var page := _overlay
	_overlay = null
	page.on_exit()
	_transitioning = true

	_kill_tween()
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(page, "modulate:a", 0.0, OVERLAY_TIME)
	_transition_tween.finished.connect(func() -> void:
		if is_instance_valid(page):
			page.queue_free()
		_transitioning = false
		_flush_queue()
	)

func get_stack_depth() -> int:
	return stack.size()

# 清掉栈顶所有页面，回到根页面（通常是 S04 花园）。
# 用于孵化演出结束后直接回花园（GDD §6.1 phase4「转场S04」）。
func pop_to_root(instant: bool = false) -> void:
	if _transitioning:
		_enqueue(func() -> void: pop_to_root(instant))
		return
	while stack.size() > 1:
		var page: UIPage = stack.pop_back()
		if is_instance_valid(page):
			page.on_exit()
			page.queue_free()
	var root_page := _current_page()
	if root_page != null:
		root_page.visible = true
		root_page.position = Vector2.ZERO
		root_page.on_enter(root_page.page_data)
	page_changed.emit(_current_page_name())

func go_back() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		close_overlay()
		return

	var page := _current_page()
	if page != null and page.handle_back():
		return
	pop()

func _ensure_canvas_layer() -> void:
	if _canvas_layer != null and is_instance_valid(_canvas_layer):
		return

	var root := get_tree().root
	var existing := root.get_node_or_null("UIManagerCanvasLayer") as CanvasLayer
	if existing != null:
		_canvas_layer = existing
		return

	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "UIManagerCanvasLayer"
	_canvas_layer.layer = CANVAS_LAYER
	root.call_deferred("add_child", _canvas_layer)

func _load_page(scene_path: String, data: Dictionary) -> UIPage:
	_ensure_canvas_layer()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("UIManager could not load scene: %s" % scene_path)
		return null

	var node := packed.instantiate()
	var page := node as UIPage
	if page == null:
		push_error("UI scene must extend UIPage: %s" % scene_path)
		node.queue_free()
		return null

	page.name = scene_path.get_file().get_basename()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.setup(data)
	if not page.back_requested.is_connected(go_back):
		page.back_requested.connect(go_back)
	return page

func _current_page() -> UIPage:
	if stack.is_empty():
		return null
	return stack[stack.size() - 1]

func _current_page_name() -> String:
	var page := _current_page()
	if page == null:
		return ""
	return page.name

func _finish_transition(page: UIPage) -> void:
	if page != null and is_instance_valid(page):
		page.position = Vector2.ZERO
	_transitioning = false
	page_changed.emit(_current_page_name())
	_flush_queue()

func _enqueue(operation: Callable) -> void:
	_operation_queue.append(operation)

func _flush_queue() -> void:
	if _transitioning or _operation_queue.is_empty():
		return
	var operation: Callable = _operation_queue.pop_front()
	operation.call()

func _kill_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()

func _viewport_width() -> float:
	return float(get_viewport().get_visible_rect().size.x)
