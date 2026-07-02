extends Node

signal tutorial_step_changed(step: int)
signal tutorial_completed()

enum Step { OFF = -1, SCAN = 0, ENERGY = 1, HATCH = 2, INTERACT = 3, EXPLORE = 4, DONE = 5 }

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const WORLD_WIDTH := 2048.0
const WORLD_HEIGHT := 1536.0

var current_step: int = Step.OFF
var _garden_page: Node = null
var _overlay: ColorRect = null
var _highlight: PanelContainer = null
var _bubble: PanelContainer = null
var _bubble_label: Label = null
var _bubble_button: Button = null
var _arrow: Polygon2D = null
var _auto_timer: Timer = null
var _cat_hitbox: Area2D = null
var _cat_hitbox_collision: CollisionShape2D = null
var _cat_hitbox_btn: Control = null
var _hatch_bridge: Control = null
var _ring: Control = null
var _scan_tween: Tween = null
var _hatch_pending := false
var _hatch_fired := false
var _hatch_timeout_timer: Timer = null
var _hatch_signal_connected := false
var _waiting_for_actual_hatch := false
var _hatch_completed_during_transition := false  # 场景切换期间孵化已完成
var _waiting_for_cat_detail_close := false
var _last_cat_tap_time := -1.0

## 双击间隔阈值（秒）——与花园一致
const DOUBLE_TAP_TIME := 0.3


func _ready() -> void:
	set_process(false)


func start(garden_page: Node) -> void:
	var save_manager := _save_manager()
	if save_manager != null and bool(save_manager._config.get_value("tutorial", "has_completed_garden_tutorial", false)):
		return

	# 方案 C：如果在 HATCH 步骤时用户去了孵化页并完成了孵化，
	# 场景切换后重新进入此处，跳过 Step 3 直接进 Step 4。
	# 必须放在 hatched_count 迁移检查之前，否则新孵完猫会被当成老用户跳过。
	if _hatch_completed_during_transition:
		_hatch_completed_during_transition = false
		_connect_hatch_signal()
		_garden_page = garden_page
		call_deferred("_step_04_interact")
		return

	# 迁移：已有历史孵化数据的用户自动完成引导
	var hatch_engine := _hatch_engine()
	if hatch_engine != null and hatch_engine.get_hatched_count() > 0:
		_complete()
		return
	if garden_page == null or not is_instance_valid(garden_page):
		return
	var was_running := current_step != Step.OFF and current_step != Step.DONE
	if _garden_page == garden_page and was_running and _garden_ok():
		return

	_cleanup_ui()
	_garden_page = garden_page
	_create_overlay()
	set_process(true)
	_step_01_scan()


func is_running() -> bool:
	return current_step != Step.OFF and current_step != Step.DONE


func is_blocking_garden_input() -> bool:
	return is_running() and current_step != Step.INTERACT


func _process(_delta: float) -> void:
	if current_step == Step.INTERACT:
		_update_cat_hitbox()


func notify_hatch_requested() -> void:
	if current_step != Step.HATCH:
		return
	_clear_step_ui()
	_hatch_pending = true
	# 用户已到孵化页，等点击蛋。超时无操作则重新提示。
	_start_hatch_timeout()


## 方案 C：连接 HatchEngine.hatch_complete 信号，
## 等待用户真正完成孵化。
func _connect_hatch_signal() -> void:
	if _hatch_signal_connected:
		return
	var he := _hatch_engine()
	if he == null:
		return
	if not he.hatch_complete.is_connected(_on_actual_hatch_completed):
		he.hatch_complete.connect(_on_actual_hatch_completed)
	_hatch_signal_connected = true


## 真实孵化完成回调。
## 如果当前正在等待孵化（_waiting_for_actual_hatch），直接进入 Step 4。
## 如果场景切换导致 garden_page 失效，设置标记等重新 start() 时处理。
func _on_actual_hatch_completed(_cat_data) -> void:
	if _waiting_for_actual_hatch:
		_waiting_for_actual_hatch = false
		_hatch_completed_during_transition = true
		if _garden_ok():
			_hatch_completed_during_transition = false
			call_deferred("_step_04_interact")


func _on_cat_hatched() -> void:
	if current_step != Step.HATCH:
		return
	_hatch_pending = false
	_stop_hatch_timeout()
	call_deferred("_step_04_interact")


func _step_01_scan() -> void:
	current_step = Step.SCAN
	tutorial_step_changed.emit(current_step)
	_clear_step_ui()
	if not _garden_ok() or _garden_page._camera == null:
		_step_02_energy()
		return
	var camera: Camera2D = _garden_page._camera
	var view := _get_garden_view_size()
	var zoom := maxf(camera.zoom.x, 0.0001)
	var half_w: float = (view.x * 0.5) / zoom
	camera.position = Vector2(half_w + 100.0, WORLD_HEIGHT * 0.5)
	_garden_page._clamp_camera_to_world()
	var target := Vector2(WORLD_WIDTH - half_w - 100.0, WORLD_HEIGHT * 0.5)
	_scan_tween = create_tween()
	_scan_tween.set_trans(Tween.TRANS_CUBIC)
	_scan_tween.set_ease(Tween.EASE_IN_OUT)
	_scan_tween.tween_property(camera, "position", target, 1.5)
	_scan_tween.finished.connect(_step_02_energy)


func _step_02_energy() -> void:
	current_step = Step.ENERGY
	tutorial_step_changed.emit(current_step)
	_clear_step_ui()
	_reset_camera()
	if _garden_ok() and _garden_page._energy_label != null:
		_highlight_control(_garden_page._energy_label)
	_create_bubble("⚡ 这是你的能量，走路就能收集，用来孵化猫咪蛋！", true, 3.0, _below_highlight())


func _step_03_hatch() -> void:
	## 方案 C：蛋已 ready（_assign_tutorial_first_egg 直接灌满），
	## 引导用户去孵化页亲手点击蛋完成孵化。
	current_step = Step.HATCH
	tutorial_step_changed.emit(current_step)
	_clear_step_ui()
	_hatch_pending = false
	_hatch_fired = false
	_connect_hatch_signal()
	_waiting_for_actual_hatch = true
	_hatch_completed_during_transition = false
	_create_bubble("🐣 蛋已经准备好了！点击底部导航的蛋图标，亲手孵化你的第一只猫咪吧~", false, 0.0, _above_highlight())
	# 方案 C：给气泡添加"去孵化"按钮（不用 _create_bubble 默认的"知道了"）
	call_deferred("_add_hatch_action_button")

func _add_hatch_action_button() -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		return
	var box := _find_bubble_content_box()
	if box == null:
		return
	var btn := Button.new()
	btn.text = "去孵化 ▶"
	btn.custom_minimum_size = Vector2(140.0, 44.0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.pressed.connect(_on_dismiss_hatch_bubble)
	box.add_child(btn)

func _find_bubble_content_box() -> VBoxContainer:
	if _bubble == null or not is_instance_valid(_bubble):
		return null
	for child in _bubble.get_children():
		if child is VBoxContainer:
			return child
	return null

## 用户点击"去孵化"：关闭气泡、遮罩和高亮，然后显示孵化 tab 指引
func _on_dismiss_hatch_bubble() -> void:
	_cleanup_ui()
	_highlight_hatch_tab()
	_create_bubble("👉 点击这里进入孵化室，蛋在等你~", true, 5.0, _above_hatch_tab())

## 高亮底部导航孵化 tab（索引 2，居中 tab）
func _highlight_hatch_tab() -> void:
	var rect := _get_bottom_nav_global_rect(2)
	if rect.size != Vector2.ZERO:
		_highlight_rect(rect)

## 气泡定位到孵化 tab 上方
func _above_hatch_tab() -> Vector2:
	var rect := _get_bottom_nav_global_rect(2)
	if rect.size == Vector2.ZERO:
		return Vector2(360.0, 1100.0)
	return Vector2(rect.position.x + rect.size.x * 0.5 - 230.0, rect.position.y - 100.0)


func _step_04_interact() -> void:
	## 方案 C：孵化回来后，镜头已由 GardenMain.on_enter focus_cat 对准猫咪
	current_step = Step.INTERACT
	tutorial_step_changed.emit(current_step)
	_clear_step_ui()
	call_deferred("_create_overlay")
	call_deferred("_create_cat_hitbox")
	call_deferred("_update_cat_hitbox")
	call_deferred("_create_interact_bubble")

func _create_interact_bubble() -> void:
	_create_bubble("👆 点击猫咪可以和它互动哦~", false, 0.0, _bubble_near_cat())

## 镜头移动到第一只猫的前方（猫在屏幕左1/3，右侧留气泡空间）
func _center_camera_on_first_cat() -> void:
	if not _garden_ok() or _garden_page._camera == null:
		return
	var cat_spawner := _cat_spawner()
	var hatch_engine := _hatch_engine()
	if cat_spawner == null or hatch_engine == null:
		return
	var cats: Array = hatch_engine.get_cats()
	if cats.is_empty():
		return
	if not cat_spawner.has_method("get_cat_world_position"):
		return
	var cat_world_pos: Vector2 = cat_spawner.get_cat_world_position(cats[0])
	# 如果猫还没生成（位置为零），等一帧再试
	if cat_world_pos == Vector2.ZERO or (abs(cat_world_pos.x) < 1.0 and abs(cat_world_pos.y) < 1.0):
		await get_tree().process_frame
		if not _garden_ok() or _garden_page._camera == null:
			return
		cat_world_pos = cat_spawner.get_cat_world_position(cats[0])
	var cam: Camera2D = _garden_page._camera
	var view := _get_garden_view_size()
	var zoom := maxf(cam.zoom.x, 0.0001)
	# 猫在屏幕左1/3处（猫 x + 1/3 视口 = 画面中心）
	var target := Vector2(
		cat_world_pos.x - view.x * 0.33 / zoom,
		cat_world_pos.y
	)
	# 不超出花园边界（用 WorldWidth/Height 常量，不从节点名查找）
	var world_w := 3072.0
	var world_h := 1024.0
	target.x = clampf(target.x, view.x * 0.5 / zoom, world_w - view.x * 0.5 / zoom)
	target.y = clampf(target.y, view.y * 0.5 / zoom, world_h - view.y * 0.5 / zoom)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(cam, "position", target, 0.6)


func _step_05_explore() -> void:
	current_step = Step.EXPLORE
	tutorial_step_changed.emit(current_step)
	_clear_step_ui()
	var rect := _get_explore_nav_global_rect()
	if rect.size != Vector2.ZERO:
		_highlight_rect(rect)
	_create_bubble("🌍 猫咪还可以外出探索，带回来明信片和礼物！", true, 5.0, _above_highlight())


func _complete() -> void:
	current_step = Step.DONE
	_cleanup_ui()
	var save_manager := _save_manager()
	if save_manager != null:
		save_manager._config.set_value("tutorial", "has_completed_garden_tutorial", true)
		save_manager.save_all()
	set_process(false)
	tutorial_completed.emit()


func _create_overlay() -> ColorRect:
	if not _garden_ok():
		return null
	_overlay = ColorRect.new()
	_overlay.name = "TutorialOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 100
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_garden_page.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _overlay


func _highlight_control(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	_highlight_rect(Rect2(control.global_position, control.size))


func _highlight_rect(rect: Rect2) -> void:
	if not _garden_ok():
		return
	_clear_highlight()
	_highlight = PanelContainer.new()
	_highlight.name = "TutorialHighlight"
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.z_index = 150
	_highlight.position = rect.position - Vector2(4.0, 4.0)
	_highlight.size = rect.size + Vector2(8.0, 8.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	style.border_color = Color.YELLOW
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	_highlight.add_theme_stylebox_override("panel", style)
	_garden_page.add_child(_highlight)


func _create_bubble(text: String, has_button: bool, auto_dismiss: float, preferred_pos: Vector2 = Vector2.ZERO) -> void:
	if not _garden_ok():
		return
	_clear_bubble()
	_bubble = PanelContainer.new()
	_bubble.name = "TutorialBubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.z_index = 170
	_bubble.custom_minimum_size = Vector2(460.0, 0.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(1.0, 0.96, 0.86, 0.98)
	panel_style.border_color = Color(0.95, 0.72, 0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	_bubble.add_theme_stylebox_override("panel", panel_style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_bubble.add_child(box)

	_bubble_label = Label.new()
	_bubble_label.text = text
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.add_theme_font_size_override("font_size", 22)
	_bubble_label.add_theme_color_override("font_color", Color(0.18, 0.13, 0.09))
	box.add_child(_bubble_label)

	if has_button:
		_bubble_button = Button.new()
		_bubble_button.text = "知道了"
		_bubble_button.custom_minimum_size = Vector2(120.0, 42.0)
		_bubble_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		_bubble_button.pressed.connect(_advance_from_ack)
		box.add_child(_bubble_button)

	_garden_page.add_child(_bubble)
	_bubble.size = _bubble.custom_minimum_size
	await get_tree().process_frame
	if _bubble == null or not is_instance_valid(_bubble):
		return
	_bubble.size = Vector2(460.0, maxf(_bubble.get_combined_minimum_size().y, 84.0))
	_bubble.position = _clamp_to_screen(preferred_pos, _bubble.size)

	if auto_dismiss > 0.0:
		_auto_timer = Timer.new()
		_auto_timer.one_shot = true
		_auto_timer.wait_time = auto_dismiss
		_auto_timer.timeout.connect(_advance_from_ack)
		add_child(_auto_timer)
		_auto_timer.start()


func _advance_from_ack() -> void:
	if current_step == Step.ENERGY:
		_step_03_hatch()
	elif current_step == Step.HATCH:
		# 用户看到了孵化 tab 高亮，关闭提示气泡，高亮保持
		_clear_bubble()
	elif current_step == Step.EXPLORE:
		_complete()


func _cleanup_ui() -> void:
	_clear_step_ui()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _clear_step_ui() -> void:
	_kill_scan_tween()
	_stop_hatch_timeout()
	_clear_highlight()
	_clear_bubble()
	if _arrow != null and is_instance_valid(_arrow):
		_arrow.queue_free()
	_arrow = null
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
	if _cat_hitbox != null and is_instance_valid(_cat_hitbox):
		_cat_hitbox.queue_free()
	_cat_hitbox = null
	if _cat_hitbox_btn != null and is_instance_valid(_cat_hitbox_btn):
		_cat_hitbox_btn.queue_free()
	_cat_hitbox_btn = null
	_cat_hitbox_collision = null
	if _hatch_bridge != null and is_instance_valid(_hatch_bridge):
		_hatch_bridge.queue_free()
	_hatch_bridge = null


func _garden_ok() -> bool:
	return _garden_page != null and is_instance_valid(_garden_page)


func _kill_scan_tween() -> void:
	if _scan_tween != null and is_instance_valid(_scan_tween):
		_scan_tween.kill()
	_scan_tween = null


func _start_hatch_timeout() -> void:
	_stop_hatch_timeout()
	_hatch_timeout_timer = Timer.new()
	_hatch_timeout_timer.one_shot = true
	_hatch_timeout_timer.wait_time = 30.0
	_hatch_timeout_timer.timeout.connect(_on_hatch_timeout)
	add_child(_hatch_timeout_timer)
	_hatch_timeout_timer.start()


func _stop_hatch_timeout() -> void:
	if _hatch_timeout_timer != null and is_instance_valid(_hatch_timeout_timer):
		_hatch_timeout_timer.stop()
		_hatch_timeout_timer.queue_free()
	_hatch_timeout_timer = null


func _on_hatch_timeout() -> void:
	if current_step != Step.HATCH or not _hatch_pending:
		return
	_hatch_pending = false
	# 用户超时未操作蛋 → 回退到花园重新显示引导气泡
	if _garden_ok():
		_step_03_hatch()


func _clear_highlight() -> void:
	if _highlight != null and is_instance_valid(_highlight):
		_highlight.queue_free()
	_highlight = null


func _clear_bubble() -> void:
	if _auto_timer != null and is_instance_valid(_auto_timer):
		_auto_timer.stop()
		_auto_timer.queue_free()
	_auto_timer = null
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null
	_bubble_label = null
	_bubble_button = null


func _create_hatch_bridge() -> void:
	# 孵化现在通过底部导航进入，跳过高亮
	pass


func _on_hatch_bridge_input(event: InputEvent) -> void:
	if current_step != Step.HATCH or _hatch_fired:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if not pressed:
		return
	_hatch_fired = true
	if _hatch_bridge != null and is_instance_valid(_hatch_bridge):
		_hatch_bridge.accept_event()
	if _garden_ok() and _garden_page.has_method("_on_hatch_slot_pressed"):
		_garden_page._on_hatch_slot_pressed(0)


func _create_cat_hitbox() -> void:
	if not _garden_ok():
		return
	# P0 修复：用 Control（GUI 通道）替代 Area2D（物理拾取），
	# 这样 hitbox 置于 overlay（z=100）之上时可正常接收点击。
	_cat_hitbox = Area2D.new()  # 保留类型用于 pointer，实际用 _cat_hitbox_btn
	_cat_hitbox.name = "TutorialCatHitbox"
	_cat_hitbox.z_index = 200
	_cat_hitbox_collision = CollisionShape2D.new()
	_cat_hitbox_collision.shape = CircleShape2D.new()
	_cat_hitbox_collision.shape.radius = 1.0  # 禁用物理碰撞，只保留节点标记
	_cat_hitbox.add_child(_cat_hitbox_collision)
	_garden_page.add_child(_cat_hitbox)

	# 实际点击接收用 Control，在 overlay 之上走 GUI 通道
	var btn := Control.new()
	btn.name = "TutorialCatBtn"
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.z_index = 200
	btn.custom_minimum_size = Vector2(160.0, 160.0)
	btn.gui_input.connect(_on_cat_hitbox_input)
	_garden_page.add_child(btn)
	_cat_hitbox_btn = btn

	_ring = RingHighlight.new()
	_ring.name = "TutorialCatRing"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.z_index = 160
	_ring.size = Vector2(170.0, 170.0)
	_garden_page.add_child(_ring)

	_arrow = Polygon2D.new()
	_arrow.name = "TutorialCatArrow"
	_arrow.polygon = PackedVector2Array([Vector2(0.0, 0.0), Vector2(-20.0, -36.0), Vector2(20.0, -36.0)])
	_arrow.color = Color(1.0, 0.9, 0.1)
	_arrow.z_index = 165
	_garden_page.add_child(_arrow)


func _on_cat_hitbox_input(event: InputEvent) -> void:
	if current_step != Step.INTERACT:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if not pressed:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_cat_tap_time < DOUBLE_TAP_TIME:
		# 双击：弹出猫咪详情页
		_last_cat_tap_time = -1.0
		_show_cat_detail_for_tutorial()
	else:
		# 首次点击：记录时间，显示"再点一次"引导
		_last_cat_tap_time = now
		if _bubble_label != null and is_instance_valid(_bubble_label):
			_bubble_label.text = "👆 再点一次进入猫咪详情~"
		else:
			# 气泡可能已消失，补一个短暂的
			_create_bubble("👆 再点一次进入猫咪详情~", false, 1.5, _bubble_near_cat())

## 引导 Step 4：双击猫后弹出 CatCard 互动面板
## 用户关闭后（tree_exited），推进到 Step 5。
func _show_cat_detail_for_tutorial() -> void:
	_clear_step_ui()
	var he := _hatch_engine()
	var cats: Array = he.get_cats() if he != null else []
	if cats.is_empty():
		_step_05_explore()
		return
	var packed := load("res://scenes/ui/CatCard.tscn")
	if packed == null:
		_step_05_explore()
		return
	var card = packed.instantiate()
	card.tree_exited.connect(_on_cat_detail_closed)
	if not _garden_ok():
		return
	_garden_page.add_child(card)
	# 把卡片注册到 InteractionSystem，这样关闭动画时 _close_cat_card 能真正 free 它
	var isys := _interaction_system()
	if isys != null:
		isys.current_cat_card = card
	# 用 CatCard.setup() 初始化
	var cid := ""
	if typeof(cats[0]) == TYPE_DICTIONARY:
		cid = cats[0].get("id", "")
	elif cats[0] != null:
		cid = cats[0].id
	card.setup(cid, cats[0], Vector2.ZERO)

func _on_cat_detail_closed() -> void:
	_step_05_explore()

## 猫数据统一转为 Dictionary（CatData 对象或已有 Dict 都能处理）
func _cat_to_dict(cat_data) -> Dictionary:
	if typeof(cat_data) == TYPE_DICTIONARY:
		return cat_data
	if cat_data != null and cat_data.has_method("serialize"):
		return cat_data.serialize()
	return {}


func _update_cat_hitbox() -> void:
	var cat_screen := _get_cat_screen_pos()
	if not bool(cat_screen.get("valid", false)):
		return
	var pos: Vector2 = cat_screen["pos"]
	if _cat_hitbox != null and is_instance_valid(_cat_hitbox):
		_cat_hitbox.position = pos
	if _cat_hitbox_btn != null and is_instance_valid(_cat_hitbox_btn):
		_cat_hitbox_btn.position = pos - Vector2(80.0, 80.0)
	if _ring != null and is_instance_valid(_ring):
		_ring.position = pos - _ring.size * 0.5
	if _arrow != null and is_instance_valid(_arrow):
		_arrow.position = pos + Vector2(0.0, -90.0)
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.position = _clamp_to_screen(pos + Vector2(-230.0, 110.0), _bubble.size)

func _get_cat_screen_pos() -> Dictionary:
	var hatch_engine := _hatch_engine()
	var cat_spawner := _cat_spawner()
	if not _garden_ok() or hatch_engine == null or cat_spawner == null or _garden_page._camera == null:
		return {"valid": false, "pos": Vector2.ZERO}
	var cats: Array = hatch_engine.get_cats()
	if cats.is_empty():
		return {"valid": false, "pos": Vector2.ZERO}
	if cat_spawner.has_method("get_cat_node"):
		var cat_node = cat_spawner.get_cat_node(cats[0])
		if cat_node == null or not is_instance_valid(cat_node):
			return {"valid": false, "pos": Vector2.ZERO}
	var cat_world_pos: Vector2 = cat_spawner.get_cat_world_position(cats[0])
	var cam: Camera2D = _garden_page._camera
	var viewport_size := _get_garden_view_size()
	return {"valid": true, "pos": (cat_world_pos - cam.position) * cam.zoom + viewport_size * 0.5}


func _save_manager() -> Node:
	return SaveManager


func _hatch_engine() -> Node:
	return HatchEngine


func _cat_spawner() -> Node:
	return CatSpawner


func _interaction_system() -> Node:
	return InteractionSystem


func _get_bottom_nav_global_rect(index: int) -> Rect2:
	if not _garden_ok():
		return Rect2()
	var nav := _find_node_by_name(_garden_page, "BottomNav")
	if nav == null or not ("_buttons" in nav):
		return Rect2()
	var buttons: Array = nav._buttons
	if index < 0 or index >= buttons.size():
		return Rect2()
	var button = buttons[index]
	if button is Control:
		return Rect2(button.global_position, button.size)
	return Rect2()


func _get_explore_nav_global_rect() -> Rect2:
	if not _garden_ok():
		return Rect2()
	var nav := _find_node_by_name(_garden_page, "BottomNav")
	if nav != null and ("_buttons" in nav) and nav.has_method("get_target_page"):
		var tab_count = nav._buttons.size()
		for i in range(tab_count):
			var page: String = String(nav.get_target_page(i)).to_lower()
			if page.find("explore") != -1:
				return _get_bottom_nav_global_rect(i)
		var buttons: Array = nav._buttons
		if buttons.size() > 3:
			return _get_bottom_nav_global_rect(3)
		if not buttons.is_empty():
			return _get_bottom_nav_global_rect(buttons.size() - 1)
	return Rect2()


func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _reset_camera() -> void:
	if _garden_ok() and _garden_page.has_method("_setup_camera"):
		_garden_page._setup_camera()


func _get_garden_view_size() -> Vector2:
	if _garden_ok() and _garden_page._camera != null:
		var viewport: Viewport = _garden_page._camera.get_viewport()
		if viewport != null:
			var size: Vector2 = viewport.get_visible_rect().size
			if size.x > 0.0 and size.y > 0.0:
				return size
	return DESIGN_SIZE


func _below_highlight() -> Vector2:
	if _highlight != null and is_instance_valid(_highlight):
		return _highlight.position + Vector2(0.0, _highlight.size.y + 16.0)
	return Vector2(40.0, 120.0)


func _above_highlight() -> Vector2:
	if _highlight != null and is_instance_valid(_highlight):
		return _highlight.position - Vector2(0.0, 116.0)
	return Vector2(40.0, 980.0)


func _bubble_near_cat() -> Vector2:
	var cat_screen := _get_cat_screen_pos()
	if not bool(cat_screen.get("valid", false)):
		return Vector2(130.0, 760.0)
	var pos: Vector2 = cat_screen["pos"]
	return pos + Vector2(-230.0, 110.0)


func _clamp_to_screen(pos: Vector2, element_size: Vector2) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = DESIGN_SIZE
	return Vector2(
		clampf(pos.x, 16.0, maxf(16.0, vp.x - element_size.x - 16.0)),
		clampf(pos.y, 16.0, maxf(16.0, vp.y - element_size.y - 16.0))
	)


class RingHighlight:
	extends Control

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		draw_arc(center, 76.0, 0.0, TAU, 96, Color.YELLOW, 4.0)
