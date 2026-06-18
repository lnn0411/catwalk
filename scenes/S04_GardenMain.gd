extends "res://ui/UIPage.gd"

const GardenBackground := preload("res://scenes/GardenBackground.gd")
const BottomNavScene := preload("res://ui/BottomNav.tscn")
const BottomNav := preload("res://ui/BottomNav.gd")

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const HUD_HEIGHT := 0.0  # HUD关闭，图标由top_row直接挂root不受裁切
const GARDEN_HEIGHT := 1280.0  # 1280 - HUD_HEIGHT
const ACTION_HEIGHT := 64.0
const HATCH_HEIGHT := 56.0
const NAV_HEIGHT := 56.0
const CONTENT_SCALE := 0.48  # 仅作相机缩放兜底；实际缩放按真实视口在 _setup_camera 里算
# 花园世界尺寸（与 GardenBackground 美术绘制范围一致；改美术需同步这两个值，真机核对）
const WORLD_WIDTH := 2048.0
const WORLD_HEIGHT := 1536.0

# 互动子状态（喂食/抚摸/玩耍/拍照），对应测试 C6-C9
enum SubState { IDLE, INTERACT_FEED, INTERACT_PET, INTERACT_PLAY, INTERACT_PHOTO }

var garden_layer: Node2D
var cat_container: Node2D
var _camera: Camera2D
var _dragging := false
var _drag_start := Vector2.ZERO
var _cam_zoom: float = CONTENT_SCALE  # 运行时按真实视口尺寸重算
var _steps_label: Label
var _energy_label: Label
var _hatch_row: HBoxContainer
var _action_buttons: Array[TextureButton] = []
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
	# 核心修复：监听视口大小改变，手动强制缩放本页面以对齐屏幕物理宽度（解决 CanvasLayer 下 Control 锚点失效、顶栏短一截的问题）
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
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

func _on_viewport_size_changed() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x > 0 and vp_size.y > 0:
		await get_tree().process_frame
		size = vp_size

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
	# SubViewport 隔离花园和 UI 渲染，彻底解决层级问题
	var garden_vp := SubViewport.new()
	garden_vp.name = "GardenViewport"
	garden_vp.size = Vector2(720, 1280 - int(HUD_HEIGHT))  # 与 SubViewportContainer 实际高度一致（顶部被 HUD 占 130）
	garden_vp.transparent_bg = false
	garden_vp.handle_input_locally = false
	
	garden_layer = Node2D.new()
	garden_layer.name = "GardenLayer"
	garden_vp.add_child(garden_layer)
	
	_camera = Camera2D.new()
	garden_layer.add_child(_camera)
	# 核心修复：连接子视口的大小改变信号，当在不同真机/模拟器分辨率下 Stretched 缩放时，自动重新计算相机 zoom 与视口对齐
	garden_vp.size_changed.connect(_setup_camera)
	_setup_camera()
	# make_current 必须在节点入树后调用（否则报 !is_inside_tree 且不生效）。
	# garden_layer 已 add 进 garden_vp，但 garden_vp 此刻还没进主树——
	# 延迟到本帧末，确保整条链入树后再激活相机。
	_camera.call_deferred("make_current")
	
	_build_parallax_background()
	
	cat_container = Node2D.new()
	cat_container.name = "CatContainer"
	cat_container.position = Vector2(0.0, 256.0)
	cat_container.z_index = 3  # 核心修复：确保猫咪渲染在最顶层，不被任何背景元素盖死
	garden_layer.add_child(cat_container)
	
	# SubViewport 的输出贴到 TextureRect 显示
	var garden_display := SubViewportContainer.new()
	garden_display.stretch = true
	garden_display.add_child(garden_vp)
	garden_display.anchor_left = 0.0
	garden_display.anchor_right = 1.0
	garden_display.anchor_top = 0.0
	garden_display.anchor_bottom = 1.0
	garden_display.offset_top = HUD_HEIGHT
	add_child(garden_display)

	if CatSpawner:
		CatSpawner.set_cat_container(cat_container)
		if not CatSpawner.cat_count_changed.is_connected(_on_cat_count_changed):
			CatSpawner.cat_count_changed.connect(_on_cat_count_changed)

func _build_parallax_background() -> void:
	# 花园背景用整图 garden_master.png（2048×1536，无透明区）。
	# 不用 layers/ 下的三张分层图——near 层导出错误（棋盘格被画成实心、
	# 100%不透明盖死下层），master 是完整干净的单图。
	var tex := load("res://assets/art/garden/garden_master.png") as Texture2D
	if tex == null:
		push_error("[Garden] 背景图加载失败: garden_master.png")
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.position = Vector2.ZERO
	garden_layer.add_child(sprite)

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
	# 全屏 HUD 容器放行：只让真正的按钮/导航(子控件)拦截点击，
	# 空白区域事件穿透到花园(拖动 + 点猫拾取)。
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# 核心修复：必须先 add_child 进场景树，再设置全屏锚点，否则在不同真机分辨率下无法拉伸对齐宽度！
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var debug_btn := Button.new()
	debug_btn.text = "DBG"
	debug_btn.flat = true
	# 核心修复：DBG 按钮采用右对齐锚点，动态适应不同真机/模拟器屏幕宽度
	debug_btn.anchor_left = 1.0
	debug_btn.anchor_right = 1.0
	debug_btn.anchor_top = 0.0
	debug_btn.anchor_bottom = 0.0
	debug_btn.offset_left = -54.0
	debug_btn.offset_right = -10.0
	debug_btn.offset_top = 8.0
	debug_btn.offset_bottom = 44.0
	debug_btn.add_theme_color_override("font_color", Color.WHITE)
	debug_btn.add_theme_font_size_override("font_size", 14)
	var red_bg := StyleBoxFlat.new()
	red_bg.bg_color = Color.RED
	red_bg.set_corner_radius_all(6)
	debug_btn.add_theme_stylebox_override("normal", red_bg)
	debug_btn.pressed.connect(_toggle_debug_panel)
	root.add_child(debug_btn)

	# 顶栏：HBoxContainer，用两个 spacer 实现 左|中|右 布局
	var top_row := HBoxContainer.new()
	top_row.anchor_right = 1.0
	top_row.offset_top = 30.0
	top_row.offset_bottom = 70.0
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 0)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_row)

	# 步数
	var steps_box := HBoxContainer.new()
	steps_box.add_theme_constant_override("separation", 6)
	steps_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var steps_icon := TextureRect.new()
	steps_icon.texture = load("res://assets/art/ui/icons/icon_paw.png")
	steps_icon.custom_minimum_size = Vector2(36.0, 36.0)
	steps_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	steps_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	steps_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	steps_box.add_child(steps_icon)
	_steps_label = Label.new()
	_steps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_steps_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_steps_label.add_theme_font_size_override("font_size", 18)
	_steps_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_steps_label.gui_input.connect(_on_steps_label_input)
	steps_box.add_child(_steps_label)

	# 能量
	var energy_box := HBoxContainer.new()
	energy_box.add_theme_constant_override("separation", 2)
	energy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var energy_icon := TextureRect.new()
	energy_icon.texture = load("res://assets/art/ui/icons/icon_sprout.png")
	energy_icon.custom_minimum_size = Vector2(28.0, 28.0)
	energy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	energy_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_box.add_child(energy_icon)
	_energy_label = Label.new()
	_energy_label.add_theme_font_size_override("font_size", 16)
	_energy_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_energy_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energy_label.text = "0/0"
	energy_box.add_child(_energy_label)

	# spacer-left：steps 贴左，推 energy 居中
	top_row.add_child(steps_box)

	var spacer_mid := Control.new()
	spacer_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer_mid)

	top_row.add_child(energy_box)

	# spacer-right：推 currency 贴右
	var spacer_right := Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer_right)
	var currency_box := HBoxContainer.new()
	currency_box.add_theme_constant_override("separation", 6)
	currency_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(currency_box)
	for entry in [{"icon": "icon_coin.png", "value": "0"}, {"icon": "icon_gem.png", "value": "0"}, {"icon": "icon_petal.png", "value": "0"}]:
		var item_box := HBoxContainer.new()
		item_box.add_theme_constant_override("separation", 3)
		item_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var item_icon := TextureRect.new()
		item_icon.texture = load("res://assets/art/ui/icons/" + String(entry["icon"]))
		item_icon.custom_minimum_size = Vector2(18.0, 18.0)
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_box.add_child(item_icon)
		var label := Label.new()
		label.text = String(entry["value"])
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		item_box.add_child(label)
		currency_box.add_child(item_box)

	_empty_label = Label.new()
	_empty_label.text = "多走几步，猫咪就来了"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.position = Vector2(0.0, 620.0)
	_empty_label.size = Vector2(720.0, 56.0)
	_empty_label.add_theme_font_size_override("font_size", 18)
	_empty_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	root.add_child(_empty_label)

	# 互动按钮：右竖排（不挡花园视线）
	var action_col := VBoxContainer.new()
	action_col.position = Vector2(640.0, 380.0)
	action_col.size = Vector2(46.0, 280.0)
	action_col.add_theme_constant_override("separation", 20)
	root.add_child(action_col)
	var action_data := [
		{"title": "喂食", "texture": "btn_feed.png", "state": SubState.INTERACT_FEED},
		{"title": "抚摸", "texture": "btn_pet.png", "state": SubState.INTERACT_PET},
		{"title": "玩耍", "texture": "btn_play.png", "state": SubState.INTERACT_PLAY},
		{"title": "拍照", "texture": "btn_photo.png", "state": SubState.INTERACT_PHOTO},
	]
	for data in action_data:
		var button := TextureButton.new()
		button.texture_normal = load("res://assets/art/ui/buttons/" + String(data["texture"]))
		button.custom_minimum_size = Vector2(42.0, 54.0)
		button.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
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
		["重播Onboarding", func() -> void: _replay_onboarding()],
		["注入数据", func() -> void: _inject_data()],
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
	_energy_label.text = "%d/%d" % [int(current), int(max_value)]

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
		button.disabled = cat_count <= 0

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
	# SubState 枚举 → InteractionSystem 类型字符串
	var type := ""
	match state:
		SubState.INTERACT_FEED:
			type = "feed"
		SubState.INTERACT_PET:
			type = "pet"
		SubState.INTERACT_PLAY:
			type = "play"
		SubState.INTERACT_PHOTO:
			type = "photo"
	var cat_id := _get_first_cat_id()
	if type != "" and cat_id != "":
		if not InteractionSystem.can_interact(cat_id, type):
			print("[Interact] %s 冷却中：%s" % [type, _get_cooldown_remaining_text(cat_id, type)])
			return
		var gain := InteractionSystem.do_interact(cat_id, type)
		print("[Interact] %s +%d 好感（总 %d）" % [type, gain, InteractionSystem.get_affection(cat_id)])
	_sub_state = state
	_interact_reset_timer.start()

func _on_interact_reset() -> void:
	var prev := _sub_state
	_sub_state = SubState.IDLE
	if prev != SubState.IDLE:
		print("[Interact] %s → IDLE" % SubState.keys()[prev])

func _get_first_cat_id() -> String:
	var cats := []
	if HatchEngine:
		cats = HatchEngine.get_cats()
	if cats.is_empty():
		return ""
	return String(cats[0].id)

func _get_cooldown_remaining_text(cat_id: String, type: String) -> String:
	var cfg := ConfigFile.new()
	cfg.load(InteractionSystem.SAVE_PATH)
	var last: float = cfg.get_value("last", cat_id + "_" + type, -1.0)
	if last < 0.0:
		return "可互动"
	var cooldown: float = InteractionSystem.get_cooldown_minutes(type) * 60.0
	var remaining: float = cooldown - (Time.get_unix_time_from_system() - last)
	if remaining <= 0.0:
		return "可互动"
	var total_min := int(remaining / 60.0)
	var hours := total_min / 60
	var minutes := total_min % 60
	if hours > 0:
		return "冷却中：%d小时%d分" % [hours, minutes]
	return "冷却中：%d分" % minutes

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


func _inject_data() -> void:
	if StepEngine:
		StepEngine.add_mock_steps(10000)
	if EnergyEngine:
		EnergyEngine.energy_pool = EnergyEngine.MAX_ENERGY
		EnergyEngine.created_at = Time.get_unix_time_from_system()
	if SaveManager:
		SaveManager.save_all()


func _replay_onboarding() -> void:
	_debug_panel.visible = false
	if SaveManager:
		SaveManager.reset_all()
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("save.cfg")
	EnergyEngine.created_at = 0.0
	UIManager.replace("res://scenes/S00_Splash.tscn")


func _reset_save() -> void:
	print("[Reset] before: steps=%d energy=%.0f" % [StepEngine.get_today_steps(), EnergyEngine.energy_pool])
	if SaveManager:
		SaveManager.reset_all()
	# 重置后补时间戳+存盘，防止下次启动误判为首次
	EnergyEngine.created_at = Time.get_unix_time_from_system()
	if SaveManager:
		SaveManager.save_all()
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
			var drag_delta: Vector2 = event.position - _drag_start
			_camera.position.x -= drag_delta.x / _cam_zoom
			_clamp_camera_to_world()
			_drag_start = event.position

func _is_in_garden(pos: Vector2) -> bool:
	return pos.y >= HUD_HEIGHT and pos.y <= HUD_HEIGHT + GARDEN_HEIGHT

# 横版花园相机：按真实视口尺寸算缩放，让世界高度恰好填满可视高度（消除上下黑边）；
# 世界比屏幕宽 → 只支持左右滚动，竖直居中锁定。aspect=expand 下视口尺寸随设备变化，
# 故用 get_viewport() 取真实尺寸，不写死。
func _setup_camera() -> void:
	if _camera == null:
		return
	# 核心安全修复：防止节点未入树时 get_viewport() 报空指针，入树前用设计尺寸保底，入树后自动刷新真实尺寸
	var vp := _camera.get_viewport()
	var view: Vector2
	if vp != null:
		view = vp.get_visible_rect().size
	else:
		view = Vector2(DESIGN_SIZE.x, DESIGN_SIZE.y - HUD_HEIGHT)
	
	if view.y <= 0.0:
		view = Vector2(DESIGN_SIZE.x, DESIGN_SIZE.y - HUD_HEIGHT)
	
	# 虚拟花园尺寸: 2048x1536, 竖屏希望高度填满
	if view.y > 0.0 and WORLD_HEIGHT > 0.0:
		_cam_zoom = view.y / WORLD_HEIGHT
	else:
		_cam_zoom = CONTENT_SCALE
	_camera.zoom = Vector2(_cam_zoom, _cam_zoom)
	# 初始显示花园左半部分（从 x=0 开始）
	var half_visible_w: float = (view.x * 0.5) / max(_cam_zoom, 0.0001)
	_camera.position = Vector2(half_visible_w, WORLD_HEIGHT * 0.5)
	_clamp_camera_to_world()

func _clamp_camera_to_world() -> void:
	if _camera == null:
		return
	# 核心安全修复：防止节点未入树时 get_viewport() 报空指针
	var vp := _camera.get_viewport()
	var view: Vector2 = Vector2(DESIGN_SIZE.x, DESIGN_SIZE.y - HUD_HEIGHT)
	if vp != null and vp.get_visible_rect().size.y > 0.0:
		view = vp.get_visible_rect().size
		
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
	var _fill: TextureRect

	func set_energy(value: float, limit: float) -> void:
		current = maxf(value, 0.0)
		max_value = maxf(limit, 1.0)
		if _label:
			_label.text = "%s/%s" % [_fmt(int(current)), _fmt(int(max_value))]
		if _fill:
			var ratio: float = clampf(current / max_value, 0.0, 1.0)
			_fill.size.x = _fill.custom_minimum_size.x * ratio

	func _ready() -> void:
		var bar_bg := TextureRect.new()
		bar_bg.texture = load("res://assets/art/ui/progress/progress_empty.png")
		bar_bg.custom_minimum_size = Vector2(200.0, 16.0)
		bar_bg.stretch_mode = TextureRect.STRETCH_SCALE
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar_bg)

		_fill = TextureRect.new()
		_fill.texture = load("res://assets/art/ui/progress/progress_fill.png")
		_fill.custom_minimum_size = Vector2(200.0, 16.0)
		_fill.stretch_mode = TextureRect.STRETCH_SCALE
		_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fill)

		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 15)
		_label.add_theme_color_override("font_color", Color.WHITE)
		_label.add_theme_color_override("font_outline_color", Palette.TEXT_PRIMARY)
		_label.add_theme_constant_override("outline_size", 4)
		_label.size = Vector2(200.0, 36.0)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

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
	var _icon: TextureRect
	var _detail_label: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		# 槽位底框：临时贴图 → 程序绘制（按状态换样式），不再依赖 slot_frame_*.png
		_frame = Panel.new()
		_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame)

		_icon = TextureRect.new()
		_icon.position = Vector2(11.0, 5.0)
		_icon.size = Vector2(28.0, 24.0)
		_icon.texture = load("res://assets/art/ui/icons/icon_sprout.png")
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)

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

		var detail := ""
		if not unlocked:
			_icon.modulate = Color(0.35, 0.35, 0.35, 1.0)
			detail = ""
		elif status == "ready":
			_icon.modulate = Color.WHITE
			detail = "点击孵化"
		elif status == "incubating":
			_icon.modulate = Color.WHITE
			detail = "等待能量填充" if progress <= 0.0 else "%d%%" % int(progress * 100.0)
		else:
			_icon.modulate = Color.WHITE
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
		_detail_label.text = detail
