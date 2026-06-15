extends "res://ui/UIPage.gd"

const GardenBackground := preload("res://scenes/GardenBackground.gd")
const BottomNavScene := preload("res://ui/BottomNav.tscn")
const BottomNav := preload("res://ui/BottomNav.gd")

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const HUD_HEIGHT := 130.0  # 顶部HUD灰条高度（内容y=60~120；此值=灰条底边，真机可微调120~140）
const GARDEN_HEIGHT := 1150.0  # 扩大到接近全屏，原来760只覆盖到y=890
const ACTION_HEIGHT := 64.0
const HATCH_HEIGHT := 56.0
const NAV_HEIGHT := 56.0
const CONTENT_SCALE := 0.48  # 仅作相机缩放兜底；实际缩放按真实视口在 _setup_camera 里算
# 花园世界尺寸（与 GardenBackground 美术绘制范围一致；改美术需同步这两个值，真机核对）
const WORLD_WIDTH := 2048.0
const WORLD_HEIGHT := 1536.0
const UI_TEXTURE_PATH := "res://assets/temp/ui/"

# 互动子状态（喂食/抚摸/玩耍/拍照），对应测试 C6-C9
enum SubState { IDLE, INTERACT_FEED, INTERACT_PET, INTERACT_PLAY, INTERACT_PHOTO }

var garden_layer: Node2D
var cat_container: Node2D
var _camera: Camera2D
var _dragging := false
var _drag_start := Vector2.ZERO
var _cam_zoom: float = CONTENT_SCALE  # 运行时按真实视口尺寸重算
var _steps_label: Label
var _energy_bar: EnergyMeter
var _hatch_row: HBoxContainer
var _action_buttons: Array[GardenActionButton] = []
var _slot_views: Array[HatchSlotView] = []
var _empty_label: Label
var _debug_panel: PanelContainer
var _steps_hold_timer: Timer
var _stats_visible := false
var _hatch_navigating := false
var _sub_state: int = SubState.IDLE
var _interact_reset_timer: Timer

func _ready() -> void:
	super()
	# 花园页根节点放行鼠标/触摸事件：UIPage 默认 STOP 会吃掉全屏事件，
	# 导致屏幕拖动(_unhandled_input)收不到。改 IGNORE 让空白区事件穿透；
	# HUD 上的按钮/底部导航是子控件，会优先命中，不受影响。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 开启 2D 物理拾取：CatSprite 用 Area2D.input_event 收点击，
	# 不开这个开关 input_event 永远不触发（点猫弹窗失效的根因）。
	get_viewport().physics_object_picking = true
	_build_garden_layer()
	_build_hud()
	_build_debug_panel()
	_connect_data()
	_refresh_all()

func on_enter(_data: Dictionary = {}) -> void:
	_hatch_navigating = false
	# 无条件重申容器归属（set_cat_container 已幂等：在场的猫先登记不会重复，
	# 漏生成/生成进旧容器的猫会补到当前容器）。
	# 实测：孵化后猫可能生成进中间态的旧容器，有条件判断会漏触发——改为每次回页必重申。
	if CatSpawner and cat_container != null and is_instance_valid(cat_container):
		CatSpawner.set_cat_container(cat_container)
	# 「让它出来」：镜头聚焦到指定猫。
	# 只动 x——横版相机竖直方向是锁定居中的，整体赋值 position 会破坏锁定（黑边回归）。
	# 「让它出来」：镜头聚焦到指定猫。
	# 位置必须在【这里】查——上面的容器重申刚把所有猫 restore 到场上；
	# 在图鉴页预查位置必然失败（花园销毁时登记表已清空）。
	var focus_cat: Variant = _data.get("focus_cat", null)
	if focus_cat != null and CatSpawner and _camera != null:
		var cat_pos: Vector2 = CatSpawner.get_cat_world_position(focus_cat)
		if cat_pos != Vector2.ZERO:
			# 只动 x——横版相机竖直方向锁定居中，整体赋值会破坏锁定（黑边回归）
			_camera.position.x = cat_pos.x
			_clamp_camera_to_world()
			# 镜头到位后让目标猫"打个招呼"（弹跳+♥）——画面里可能有多只猫，
			# 没有这一下玩家不知道哪只是它
			var cat_node = CatSpawner.get_cat_node(focus_cat)
			if cat_node != null and cat_node.has_method("_play_click_feedback"):
				cat_node.call_deferred("_play_click_feedback")

func _exit_tree() -> void:
	if CatSpawner:
		# 根因修复：queue_free 是延迟的，老页面 _exit_tree 可能在
		# 新页面 _ready 之后执行。无条件置 null 会把新页面刚设好的
		# 容器抹掉 → 后续 hatch_complete 全部丢弃 → "猫不马上出来"。
		# 仅当容器仍指向本页时才清空。
		if CatSpawner.cat_container == cat_container:
			CatSpawner.set_cat_container(null)

func _build_garden_layer() -> void:
	garden_layer = Node2D.new()
	garden_layer.name = "GardenLayer"
	garden_layer.position = Vector2(0.0, HUD_HEIGHT)
	add_child(garden_layer)
	
	# 直接贴 master 合成图验证资产加载
	var tex := load("res://assets/art/garden/garden_master.png") as Texture2D
	if tex:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 50
		garden_layer.add_child(sprite)
		push_warning("[Garden] master PNG loaded: %s" % str(tex.get_size()))
	else:
		push_error("[Garden] FAILED to load garden_master.png!")
	
	cat_container = Node2D.new()
	cat_container.name = "CatContainer"
	cat_container.position = Vector2(0.0, 256.0)
	garden_layer.add_child(cat_container)

	_camera = Camera2D.new()
	garden_layer.add_child(_camera)
	_camera.make_current()
	_setup_camera()

	if CatSpawner:
		CatSpawner.set_cat_container(cat_container)
		if not CatSpawner.cat_count_changed.is_connected(_on_cat_count_changed):
			CatSpawner.cat_count_changed.connect(_on_cat_count_changed)

func _build_parallax_background() -> void:
	var parallax := ParallaxBackground.new()
	garden_layer.add_child(parallax)
	_add_background_layer(parallax, Vector2(0.05, 0.0), GardenBackground.LAYER_FAR)
	_add_background_layer(parallax, Vector2(0.3, 0.0), GardenBackground.LAYER_MID)
	_add_background_layer(parallax, Vector2(0.8, 0.0), GardenBackground.LAYER_NEAR)

func _add_background_layer(parent: ParallaxBackground, motion_scale: Vector2, layer_type: int) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = motion_scale
	parent.add_child(layer)

	var background := GardenBackground.new()
	background.layer_type = layer_type
	layer.add_child(background)

func _build_hud() -> void:
	var root := Control.new()
	root.name = "HUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 全屏 HUD 容器放行：只让真正的按钮/导航(子控件)拦截点击，
	# 空白区域事件穿透到花园(拖动 + 点猫拾取)。
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 顶栏：程序绘制悬浮卡（暖白圆角+柔影），底垫纸纹理模拟手绘纸张感
	var top_paper := TextureRect.new()
	top_paper.texture = load("res://assets/temp/ui/paper_texture.png")
	top_paper.stretch_mode = TextureRect.STRETCH_TILE
	top_paper.anchor_left = 0.0
	top_paper.anchor_right = 1.0
	top_paper.anchor_top = 0.0
	top_paper.anchor_bottom = 0.0
	top_paper.offset_left = 10.0
	top_paper.offset_right = -10.0
	top_paper.offset_top = 8.0
	top_paper.offset_bottom = HUD_HEIGHT - 2.0
	top_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_paper)

	var top_bar := Panel.new()
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(Palette.BG_CEMENT, 0.94)
	top_style.set_corner_radius_all(20)
	top_style.border_width_bottom = 1
	top_style.border_color = Palette.BORDER_DEFAULT
	top_style.shadow_color = Palette.UI_SHADOW
	top_style.shadow_size = 8
	top_style.shadow_offset = Vector2(0.0, 2.0)
	top_bar.add_theme_stylebox_override("panel", top_style)
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 10.0
	top_bar.offset_right = -10.0
	top_bar.offset_top = 8.0
	top_bar.offset_bottom = HUD_HEIGHT - 2.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar)

	var debug_btn := Button.new()
	debug_btn.text = "DBG"
	debug_btn.flat = true
	debug_btn.position = Vector2(670.0, 8.0)
	debug_btn.size = Vector2(44.0, 36.0)
	debug_btn.add_theme_color_override("font_color", Color.WHITE)
	debug_btn.add_theme_font_size_override("font_size", 14)
	var red_bg := StyleBoxFlat.new()
	red_bg.bg_color = Color.RED
	red_bg.set_corner_radius_all(6)
	debug_btn.add_theme_stylebox_override("normal", red_bg)
	debug_btn.pressed.connect(_toggle_debug_panel)
	root.add_child(debug_btn)

	var top_row := HBoxContainer.new()
	top_row.position = Vector2(24.0, 60.0)
	top_row.size = Vector2(656.0, 60.0)
	top_row.add_theme_constant_override("separation", 16)
	root.add_child(top_row)

	var steps_box := HBoxContainer.new()
	steps_box.custom_minimum_size = Vector2(150.0, 50.0)
	steps_box.add_theme_constant_override("separation", 5)
	top_row.add_child(steps_box)

	var steps_icon := TextureRect.new()
	steps_icon.texture = load(UI_TEXTURE_PATH + "icon_steps.png")
	steps_icon.custom_minimum_size = Vector2(30.0, 30.0)
	steps_icon.stretch_mode = TextureRect.STRETCH_SCALE
	steps_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	steps_box.add_child(steps_icon)

	_steps_label = Label.new()
	_steps_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_steps_label.add_theme_font_size_override("font_size", 18)
	_steps_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_steps_label.gui_input.connect(_on_steps_label_input)
	steps_box.add_child(_steps_label)

	var energy_box := HBoxContainer.new()
	energy_box.custom_minimum_size = Vector2(248.0, 50.0)
	energy_box.add_theme_constant_override("separation", 5)
	top_row.add_child(energy_box)

	var energy_icon := TextureRect.new()
	energy_icon.texture = load(UI_TEXTURE_PATH + "icon_energy.png")
	energy_icon.custom_minimum_size = Vector2(30.0, 30.0)
	energy_icon.stretch_mode = TextureRect.STRETCH_SCALE
	energy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_box.add_child(energy_icon)

	_energy_bar = EnergyMeter.new()
	_energy_bar.custom_minimum_size = Vector2(200.0, 36.0)
	energy_box.add_child(_energy_bar)

	var currency_box := HBoxContainer.new()
	currency_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	currency_box.alignment = BoxContainer.ALIGNMENT_END
	currency_box.add_theme_constant_override("separation", 9)
	top_row.add_child(currency_box)
	for entry in ["💰 0", "💎 0", "🌸 0"]:
		var label := Label.new()
		label.text = entry
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		currency_box.add_child(label)

	_empty_label = Label.new()
	_empty_label.text = "多走几步，猫咪就来了"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.position = Vector2(0.0, 499.0)
	_empty_label.size = Vector2(720.0, 56.0)
	_empty_label.add_theme_font_size_override("font_size", 18)
	_empty_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	root.add_child(_empty_label)

	# 互动按钮：右竖排（不挡花园视线）
	var action_col := VBoxContainer.new()
	action_col.position = Vector2(620.0, 380.0)
	action_col.size = Vector2(80.0, 320.0)
	action_col.add_theme_constant_override("separation", 8)
	root.add_child(action_col)
	var action_data := [
		{"title": "喂食", "texture": "btn_feed.png", "state": SubState.INTERACT_FEED},
		{"title": "抚摸", "texture": "btn_pet.png", "state": SubState.INTERACT_PET},
		{"title": "玩耍", "texture": "btn_play.png", "state": SubState.INTERACT_PLAY},
		{"title": "拍照", "texture": "btn_photo.png", "state": SubState.INTERACT_PHOTO},
	]
	for data in action_data:
		var button := GardenActionButton.new()
		button.text = String(data["title"])
		button.custom_minimum_size = Vector2(78.0, 48.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_action_pressed.bind(int(data["state"])))
		action_col.add_child(button)
		_action_buttons.append(button)

	_hatch_row = HBoxContainer.new()
	_hatch_row.position = Vector2(32.0, 1168.0)
	_hatch_row.size = Vector2(656.0, HATCH_HEIGHT)
	_hatch_row.add_theme_constant_override("separation", 12)
	root.add_child(_hatch_row)
	for i in range(4):
		var slot_view := HatchSlotView.new()
		slot_view.slot_index = i
		slot_view.custom_minimum_size = Vector2(160.0, 56.0)
		slot_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_view.slot_pressed.connect(_on_hatch_slot_pressed)
		_hatch_row.add_child(slot_view)
		_slot_views.append(slot_view)

	var nav = BottomNavScene.instantiate()
	nav.set_current_tab(0)
	nav.tab_selected.connect(_on_bottom_nav_tab_selected)
	root.add_child(nav)

	_steps_hold_timer = Timer.new()
	_steps_hold_timer.one_shot = true
	_steps_hold_timer.wait_time = 3.0
	_steps_hold_timer.timeout.connect(_toggle_debug_panel)
	add_child(_steps_hold_timer)

	# 互动子状态在 2 秒后自动回到 IDLE
	_interact_reset_timer = Timer.new()
	_interact_reset_timer.one_shot = true
	_interact_reset_timer.wait_time = 2.0
	_interact_reset_timer.timeout.connect(_on_interact_reset)
	add_child(_interact_reset_timer)

func _build_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.visible = false
	_debug_panel.position = Vector2(40.0, 220.0)
	_debug_panel.size = Vector2(280.0, 240.0)
	_debug_panel.z_index = 20
	_debug_panel.add_theme_stylebox_override("panel", _make_box_style(Palette.BG_WARM_WHITE, Palette.BORDER_ACTIVE, 8))
	add_child(_debug_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	_debug_panel.add_child(box)

	for item in [
		["+100 steps", func() -> void: _add_mock_steps(100)],
		["+1000 steps", func() -> void: _add_mock_steps(1000)],
		["+5000 steps", func() -> void: _add_mock_steps(5000)],
		["+10000 steps", func() -> void: _add_mock_steps(10000)],
		["Reset Save", func() -> void: _reset_save()],
		["清空数据", func() -> void: _clear_cache()],
		["Show/Hide stats", func() -> void: _toggle_stats()],
	]:
		var button := Button.new()
		button.text = String(item[0])
		button.custom_minimum_size = Vector2(0.0, 37.0)
		button.add_theme_font_size_override("font_size", 13)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Palette.BG_CEMENT
		bg.set_corner_radius_all(6)
		button.add_theme_stylebox_override("normal", bg)
		button.pressed.connect(item[1])
		box.add_child(button)

func _make_box_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style

func _connect_data() -> void:
	if StepEngine and not StepEngine.steps_updated.is_connected(_on_steps_updated):
		StepEngine.steps_updated.connect(_on_steps_updated)
	if EnergyEngine and not EnergyEngine.energy_changed.is_connected(_on_energy_changed):
		EnergyEngine.energy_changed.connect(_on_energy_changed)
	if HatchEngine:
		if not HatchEngine.hatch_progress.is_connected(_on_hatch_progress):
			HatchEngine.hatch_progress.connect(_on_hatch_progress)
		if not HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
			HatchEngine.hatch_complete.connect(_on_hatch_complete)

func _refresh_all() -> void:
	_refresh_steps()
	_refresh_energy()
	_refresh_slots()
	_refresh_cat_state()

func _refresh_steps() -> void:
	var steps := 0
	if StepEngine:
		steps = StepEngine.get_today_steps()
	_steps_label.text = "%s 步" % _format_int(steps)

func _refresh_energy() -> void:
	var current := 0.0
	var max_value := 15000.0
	if EnergyEngine:
		current = EnergyEngine.energy_pool
		max_value = EnergyEngine.MAX_ENERGY_POOL
	print("[Refresh] energy bar set: %.0f/%.0f" % [current, max_value])
	_energy_bar.set_energy(current, max_value)

func _refresh_slots() -> void:
	var slots := []
	if HatchEngine:
		slots = HatchEngine.get_slots()
	for i in range(_slot_views.size()):
		var data := {}
		if i < slots.size():
			data = Dictionary(slots[i])
		_slot_views[i].set_slot_data(data)

func _refresh_cat_state() -> void:
	var cat_count := 0
	if HatchEngine:
		cat_count = HatchEngine.get_cats().size()
	_empty_label.visible = cat_count == 0
	for button in _action_buttons:
		button.set_enabled(cat_count > 0)

func _on_steps_updated(_delta: int, _total: int) -> void:
	_refresh_steps()

func _on_energy_changed(_current: float, _pool_max: float, _backup: float) -> void:
	_refresh_energy()

func _on_hatch_progress(_slot: int, _progress: float) -> void:
	_refresh_slots()

func _on_hatch_complete(_cat_data) -> void:
	_refresh_slots()
	_refresh_cat_state()

func _on_cat_count_changed(_count: int) -> void:
	_refresh_cat_state()

func _on_hatch_slot_pressed(_slot_index: int) -> void:
	if _hatch_navigating:
		return
	_hatch_navigating = true
	UIManager.push("res://scenes/S06_HatchPage.tscn")

func _on_action_pressed(state: int) -> void:
	# 没有猫时按钮本就 disabled，这里双保险
	if _empty_label.visible:
		return
	var prev := _sub_state
	_sub_state = state
	print("[Interact] %s → %s" % [SubState.keys()[prev], SubState.keys()[_sub_state]])
	# TODO: 在此触发对应猫咪动画 / 反馈表现
	_interact_reset_timer.start()

func _on_interact_reset() -> void:
	var prev := _sub_state
	_sub_state = SubState.IDLE
	if prev != SubState.IDLE:
		print("[Interact] %s → IDLE" % SubState.keys()[prev])

func _on_bottom_nav_tab_selected(index: int) -> void:
	if index < 0 or index >= BottomNav.TABS.size():
		return
	var page := String(BottomNav.TABS[index]["page"])
	if page == scene_file_path:
		return
	if page != "":
		UIManager.replace(page)

func _on_steps_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_steps_hold_timer.start()
		else:
			_steps_hold_timer.stop()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_steps_hold_timer.start()
		else:
			_steps_hold_timer.stop()

func _toggle_debug_panel() -> void:
	if not OS.is_debug_build():
		return
	_debug_panel.visible = not _debug_panel.visible

func _add_mock_steps(amount: int) -> void:
	if StepEngine:
		StepEngine.add_mock_steps(amount)
	if SaveManager:
		SaveManager.save_all()

func _reset_save() -> void:
	print("[Reset] before: steps=%d energy=%.0f" % [StepEngine.get_today_steps(), EnergyEngine.energy_pool])
	if SaveManager:
		SaveManager.reset_all()
	print("[Reset] after: steps=%d energy=%.0f" % [StepEngine.get_today_steps(), EnergyEngine.energy_pool])
	# 清除画面上的猫
	if cat_container:
		for child in cat_container.get_children():
			child.queue_free()
	if CatSpawner:
		CatSpawner.spawned_cat_ids.clear()
	_refresh_all()

func _clear_cache() -> void:
	_reset_save()
	# 物理删除存档文件
	var dir = DirAccess.open("user://")
	if dir:
		dir.remove("save.cfg")
	# 清理内存中的 ConfigFile
	if SaveManager:
		SaveManager._config.clear()
	print("[ClearCache] 存档文件已删除，重启游戏将恢复初始状态")

func _toggle_stats() -> void:
	_stats_visible = not _stats_visible
	if Popups:
		var text := "Steps %d / Energy %.0f / Cats %d" % [
			StepEngine.get_today_steps() if StepEngine else 0,
			EnergyEngine.energy_pool if EnergyEngine else 0.0,
			HatchEngine.get_cats().size() if HatchEngine else 0,
		]
		Popups.show_info(text if _stats_visible else "stats hidden")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_in_garden(event.position):
			_dragging = true
			_drag_start = event.position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging and _camera:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_dragging = false
		else:
			var drag_delta := event.position - _drag_start
			_camera.position.x -= drag_delta.x / _cam_zoom
			_clamp_camera_to_world()
			_drag_start = event.position

func _is_in_garden(pos: Vector2) -> bool:
	return pos.y >= HUD_HEIGHT and pos.y <= HUD_HEIGHT + GARDEN_HEIGHT

# 横版花园相机：按真实视口尺寸算缩放，让世界高度恰好填满可视高度（消除上下黑边）；
# 世界比屏幕宽 → 只支持左右滚动，竖直居中锁定。aspect=expand 下视口尺寸随设备变化，
# 故用 get_viewport_rect() 取真实尺寸，不写死。
func _setup_camera() -> void:
	if _camera == null:
		return
	var view: Vector2 = get_viewport_rect().size
	# 虚拟花园尺寸: 2048x1536, 竖屏希望高度填满
	if view.y > 0.0 and WORLD_HEIGHT > 0.0:
		_cam_zoom = view.y / WORLD_HEIGHT
	else:
		_cam_zoom = CONTENT_SCALE
	_camera.zoom = Vector2(_cam_zoom, _cam_zoom)
	_camera.position = Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.5)
	push_warning("[Camera] view=%s zoom=%.3f" % [str(view), _cam_zoom])
	_clamp_camera_to_world()
	push_warning("[Camera] final pos=%s" % str(_camera.position))
	
	# 可视诊断标签
	var dbg := Label.new()
	dbg.text = "CAM zoom=%.2f pos=%s" % [_cam_zoom, str(_camera.position)]
	dbg.add_theme_font_size_override("font_size", 24)
	dbg.add_theme_color_override("font_color", Color.RED)
	dbg.position = Vector2(10, 10)
	dbg.z_index = 200
	garden_layer.add_child(dbg)

func _clamp_camera_to_world() -> void:
	if _camera == null:
		return
	var view: Vector2 = get_viewport_rect().size
	var half_w: float = (view.x * 0.5) / max(_cam_zoom, 0.0001)
	var min_x: float = half_w
	var max_x: float = WORLD_WIDTH - half_w
	if min_x > max_x:
		# 世界比可视区还窄（理论上不会，保险）→ 水平居中
		_camera.position.x = WORLD_WIDTH * 0.5
	else:
		_camera.position.x = clampf(_camera.position.x, min_x, max_x)
	# 竖直锁定居中（横版不上下滚动，世界高度已填满可视区）
	_camera.position.y = WORLD_HEIGHT * 0.5

func _format_int(value: int) -> String:
	var raw: String = str(value)
	var result: String = ""
	var count: int = 0
	for i in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = raw[i] + result
		count += 1
	return result

class EnergyMeter:
	extends Control

	var current: float = 0.0
	var max_value: float = 15000.0
	var _label: Label

	func set_energy(value: float, limit: float) -> void:
		current = maxf(value, 0.0)
		max_value = maxf(limit, 1.0)
		queue_redraw()
		if _label:
			_label.text = "%s/%s" % [_fmt(int(current)), _fmt(int(max_value))]

	func _ready() -> void:
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 15)
		# 文字压在能量条上（左半棕橙AMBER/右半浅米），用白字+深色描边
		# 保证在两种底色上都清晰可读
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_color_override("font_outline_color", Palette.TEXT_PRIMARY)
		_label.add_theme_constant_override("outline_size", 4)
		_label.size = Vector2(200.0, 36.0)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

	func _draw() -> void:
		var bar_rect := Rect2(0.0, 8.0, 200.0, 16.0)
		draw_rect(bar_rect, Palette.BORDER_DEFAULT, true)
		var ratio: float = clampf(current / max_value, 0.0, 1.0)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), Palette.AMBER, true)
		draw_rect(bar_rect, Palette.BORDER_ACTIVE, false, 2.0)

	func _fmt(value: int) -> String:
		var raw: String = str(value)
		var result: String = ""
		var count: int = 0
		for i in range(raw.length() - 1, -1, -1):
			if count > 0 and count % 3 == 0:
				result = "," + result
			result = raw[i] + result
			count += 1
		return result

class GardenActionButton:
	extends Button

	var _label: Label

	func _ready() -> void:
		# 修复：flat=true 会让 Godot 忽略 StyleBox 覆盖——按钮此前没有底色，
		# 四个白字直接飘在草地上。flat 必须为 false 样式才生效。
		flat = false
		focus_mode = Control.FOCUS_NONE
		_label = Label.new()
		_label.text = self.text
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 16)
		_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
		set_enabled(true)

	func set_enabled(value: bool) -> void:
		disabled = not value
		if _label:
			_label.add_theme_color_override("font_color", Palette.TEXT_ON_AMBER if value else Palette.TEXT_SECONDARY)
		# 立体胶囊：琥珀底 + 深色底边（厚度感）+ 柔影；按下时下沉（去影去底边）
		var bg := StyleBoxFlat.new()
		bg.bg_color = Palette.AMBER
		bg.set_corner_radius_all(24)
		bg.border_width_bottom = 3
		bg.border_color = Palette.AMBER.darkened(0.25)
		bg.shadow_color = Palette.UI_SHADOW
		bg.shadow_size = 5
		bg.shadow_offset = Vector2(0.0, 2.0)
		var pressed_style: StyleBoxFlat = bg.duplicate()
		pressed_style.bg_color = Palette.UI_PRESSED_AMBER
		pressed_style.shadow_size = 0
		pressed_style.border_width_bottom = 0
		var dis := StyleBoxFlat.new()
		dis.bg_color = Color(Palette.BORDER_DEFAULT, 0.75)
		dis.set_corner_radius_all(14)
		add_theme_stylebox_override("normal", bg if value else dis)
		add_theme_stylebox_override("hover", bg if value else dis)
		add_theme_stylebox_override("pressed", pressed_style if value else dis)
		add_theme_stylebox_override("disabled", dis)

class DebugTextureButton:
	extends TextureButton

	var label_text := ""

	func _ready() -> void:
		var label := Label.new()
		label.text = label_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

class HatchSlotView:
	extends Control

	signal slot_pressed(slot_index: int)

	var slot_index := 0
	var slot_data: Dictionary = {}
	var _frame: Panel
	var _icon_label: Label
	var _detail_label: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		# 槽位底框：临时贴图 → 程序绘制（按状态换样式），不再依赖 slot_frame_*.png
		_frame = Panel.new()
		_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame)

		_icon_label = Label.new()
		_icon_label.position = Vector2(11.0, 5.0)
		_icon_label.size = Vector2(28.0, 24.0)
		_icon_label.add_theme_font_size_override("font_size", 16)
		_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon_label)

		_detail_label = Label.new()
		_detail_label.position = Vector2(41.0, 5.0)
		_detail_label.size = Vector2(104.0, 24.0)
		_detail_label.add_theme_font_size_override("font_size", 12)
		_detail_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
		_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_detail_label)

	func set_slot_data(data: Dictionary) -> void:
		slot_data = data
		_refresh()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			slot_pressed.emit(slot_index)
			accept_event()
		elif event is InputEventScreenTouch and event.pressed:
			slot_pressed.emit(slot_index)
			accept_event()

	func _refresh() -> void:
		if _frame == null:
			return
		var unlocked := bool(slot_data.get("unlocked", slot_index == 0))
		var status := String(slot_data.get("status", "empty" if slot_index == 0 else "locked"))
		var energy := float(slot_data.get("energy", 0.0))
		var max_energy := float(slot_data.get("max_energy", 0.0))
		var progress: float = 0.0
		if max_energy > 0.0:
			progress = clamp(energy / max_energy, 0.0, 1.0)

		var icon := "🔒"
		var detail := ""
		if unlocked and status == "ready":
			icon = "🥚"
			detail = "点击孵化"
		elif unlocked and status == "incubating":
			icon = "🥚"
			detail = "等待能量填充" if progress <= 0.0 else "%d%%" % int(progress * 100.0)
		elif unlocked:
			icon = "🥚"
			detail = "等待能量填充"

		var fs := StyleBoxFlat.new()
		fs.set_corner_radius_all(24)
		if not unlocked:
			fs.bg_color = Color(Palette.CITY_GRAY, 0.30)
			fs.border_color = Color(Palette.BORDER_DEFAULT, 0.6)
			fs.set_border_width_all(1)
		elif status == "ready" or (status == "incubating" and progress >= 1.0):
			fs.bg_color = Color(Palette.AMBER, 0.22)
			fs.border_color = Palette.AMBER
			fs.set_border_width_all(2)
		elif status == "incubating":
			fs.bg_color = Color(Palette.BG_WARM_WHITE, 0.90)
			fs.border_color = Color(Palette.AMBER, 0.55)
			fs.set_border_width_all(1)
		else:
			fs.bg_color = Color(Palette.BG_WARM_WHITE, 0.75)
			fs.border_color = Color(Palette.BORDER_DEFAULT, 0.8)
			fs.set_border_width_all(1)
		_frame.add_theme_stylebox_override("panel", fs)
		_icon_label.text = icon
		_icon_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY if unlocked else Palette.TEXT_SECONDARY)
		_detail_label.text = detail
