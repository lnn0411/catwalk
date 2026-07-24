extends "res://ui/UIPage.gd"

const GardenBackground := preload("res://scenes/GardenBackground.gd")
const BottomNavScene := preload("res://ui/BottomNav.tscn")
const BottomNav := preload("res://ui/BottomNav.gd")

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const HUD_HEIGHT := 0.0  # HUD关闭，图标由top_row直接挂root不受裁切
const GARDEN_HEIGHT := 1280.0  # 1280 - HUD_HEIGHT
const ACTION_HEIGHT := 64.0
const FRAME_EMPTY_PATH := "res://assets/art/ui/panels/slot_frame_empty.png"
const FRAME_FILLING_PATH := "res://assets/art/ui/panels/slot_frame_filling.png"
const FRAME_READY_PATH := "res://assets/art/ui/panels/slot_frame_ready.png"
const HATCH_HEIGHT := 98.0
const NAV_HEIGHT := 56.0
const CONTENT_SCALE := 0.48  # 仅作相机缩放兜底；实际缩放按真实视口在 _setup_camera 里算
# 花园世界尺寸（与 GardenBackground 美术绘制范围一致；改美术需同步这两个值，真机核对）
const WORLD_WIDTH := 3072.0
const WORLD_HEIGHT := 1024.0

# 互动子状态（喂食/抚摸/玩耍/拍照），对应测试 C6-C9
# 三级缩放：L1(1.0x) -> L2(2.0x) -> L3(3.5x)，引自 GDD x4.2
const ZOOM_L1 := 1.0
const ZOOM_L2 := 2.0
const ZOOM_L3 := 3.5
const GARDEN_ZOOM_LEVELS := [ZOOM_L1, ZOOM_L2, ZOOM_L3]
const DOUBLE_TAP_TIME := 0.3       # 双击间隔阈值（秒）
const ZOOM_TWEEN_DURATION := 0.3  # 双击平滑过渡时长（秒）
const PINCH_ZOOM_THRESHOLD := 0.08
const CAT_HIT_RADIUS := 92.0

# T4-03 输出给 T4-04 的唯一接口：点击猫咪时发射（仅 L2+），T4-04 监听此信号弹出 CatCard
signal cat_clicked(cat_id: String, screen_position: Vector2)

# slot_frame 纹理缓存（运行时动态加载，文件不存在返回 null）
var _frame_empty: Texture2D
var _frame_filling: Texture2D
var _frame_ready: Texture2D

var garden_layer: Node2D
var _garden_viewport: SubViewport
var cat_container: Node2D
var _camera: Camera2D
var _dragging := false
var _drag_start := Vector2.ZERO
var _cam_zoom: float = CONTENT_SCALE
var _zoom_factor: float = ZOOM_L1
var _last_tap_time: float = -DOUBLE_TAP_TIME
var _last_touch_time: float = -DOUBLE_TAP_TIME
var _zoom_tween: Tween
var _steps_label: Label
var _energy_label: Label
var _hatch_navigating := false
var _empty_label: Label
var _debug_panel: PanelContainer
var _steps_hold_timer: Timer
var _weather_overlay: ColorRect
var _weather_material: ShaderMaterial
var _bg_sprite: Sprite2D
var _bg_index: int = -1
var _rain_particles: CPUParticles2D
var _snow_particles: CPUParticles2D
var _weather_tween: Tween
var _last_blend := -1.0
var _stats_visible := false
var _diary_notification_btn: TextureButton
var _diary_unread_cats: Array = []
var _currency_labels: Array[Label] = []
func _ready() -> void:
	super()
	_load_frame_textures()
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
	if TutorialManager:
		TutorialManager.start(self)
	_hatch_navigating = false
	_refresh_diary_notification()
	_refresh_currency()
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
		# 确保猫在场上可见（可能超出 MAX_VISIBLE_CATS 在休息组）
		CatSpawner.ensure_cat_visible(focus_cat)
		var cat_pos: Vector2 = CatSpawner.get_cat_world_position(focus_cat)
		if cat_pos != Vector2.ZERO:
			# 只动 x——横版相机竖直方向锁定居中，整体赋值会破坏锁定（黑边回归）
			_camera.position.x = cat_pos.x
			_clamp_camera_to_world()
			# 镜头到位后让目标猫"打个招呼"（弹跳+♥）——画面里可能有多只猫，
			# 没有这一下玩家不知道哪只是它
			var cat_node = CatSpawner.get_cat_node(focus_cat)
			if cat_node != null and cat_node.has_method("_play_click_feedback"):
				cat_node._play_click_feedback()

func _load_frame_textures() -> void:
	_frame_empty = _try_load("res://assets/art/ui/panels/slot_frame_empty.png")
	_frame_filling = _try_load("res://assets/art/ui/panels/slot_frame_filling.png")
	_frame_ready = _try_load("res://assets/art/ui/panels/slot_frame_ready.png")

func _try_load(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		var r: Resource = load(p)
		if r is Texture2D:
			return r
	return null

func _exit_tree() -> void:
	if CatSpawner:
		if CatSpawner.cat_container == cat_container:
			CatSpawner.set_cat_container(null)
		# 容器抹掉 → 后续 hatch_complete 全部丢弃 → "猫不马上出来"。
		# 仅当容器仍指向本页时才清空。
		if CatSpawner.cat_container == cat_container:
			CatSpawner.set_cat_container(null)

func _build_garden_layer() -> void:
	# SubViewport 隔离花园和 UI 渲染，彻底解决层级问题
	var garden_vp := SubViewport.new()
	garden_vp.name = "GardenViewport"
	# 自适应真机分辨率：取实际视口大小，而非固定设计尺寸
	var vp_size := Vector2(720, 1280)
	var vp_ref := get_viewport()
	if vp_ref != null:
		var vr := vp_ref.get_visible_rect().size
		if vr.x > 0 and vr.y > 0:
			vp_size = vr
	garden_vp.size = vp_size
	garden_vp.transparent_bg = false
	garden_vp.handle_input_locally = false
	_garden_viewport = garden_vp
	
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
	_setup_weather_layer()

	if CatSpawner:
		CatSpawner.set_cat_container(cat_container)
		if not CatSpawner.cat_count_changed.is_connected(_on_cat_count_changed):
			CatSpawner.cat_count_changed.connect(_on_cat_count_changed)
		_apply_cat_visibility()

func _setup_weather_layer() -> void:
	# Weather particles: added to self (GardenMain Control layer) - works
	_rain_particles = _create_rain_particles()
	add_child(_rain_particles)
	_snow_particles = _create_snow_particles()
	add_child(_snow_particles)

	# Period tint: use garden_layer.modulate to avoid SubViewport Control/Node2D mixing
	if WeatherTimeManager:
		if not WeatherTimeManager.period_changed.is_connected(_on_weather_period_changed):
			WeatherTimeManager.period_changed.connect(_on_weather_period_changed)
		if not WeatherTimeManager.weather_changed.is_connected(_on_weather_changed):
			WeatherTimeManager.weather_changed.connect(_on_weather_changed)
		_apply_weather_period(WeatherTimeManager.current_period, true)
		_apply_weather_particles(WeatherTimeManager.current_weather)

func _create_rain_particles() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "RainParticles"
	particles.amount = 200
	particles.lifetime = 1.0
	particles.preprocess = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(420.0, 24.0)
	particles.position = Vector2(360.0, -24.0)
	particles.direction = Vector2(-0.3, 1.0).normalized()
	particles.spread = 8.0
	particles.gravity = Vector2(0.0, 1200.0)
	particles.initial_velocity_min = 800.0
	particles.initial_velocity_max = 1000.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 1.5
	particles.texture = load("res://assets/weather/rain_drop.png")
	particles.emitting = false
	return particles

func _create_snow_particles() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "SnowParticles"
	particles.amount = 100
	particles.lifetime = 4.0
	particles.preprocess = 4.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(420.0, 24.0)
	particles.position = Vector2(360.0, -24.0)
	particles.direction = Vector2(0.1, 1.0).normalized()
	particles.spread = 25.0
	particles.gravity = Vector2(0.0, 50.0)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.4
	particles.texture = load("res://assets/weather/snow_flake.png")
	particles.emitting = false
	return particles

func _on_weather_period_changed(period: int) -> void:
	_apply_weather_period(period)

func _on_weather_changed(weather: int) -> void:
	_apply_weather_particles(weather)

func _apply_weather_period(period: int, immediate := false) -> void:
	if garden_layer == null:
		return
	var target: Color
	match period:
		WeatherTimeManager.TimePeriod.SUNSET:
			target = Color(1.08, 0.98, 0.88, 1)
		WeatherTimeManager.TimePeriod.NIGHT:
			target = Color(0.65, 0.70, 0.90, 1)
		_:  # DAY
			target = Color.WHITE

	if immediate or garden_layer.modulate == target:
		garden_layer.modulate = target
		return

	if _weather_tween and _weather_tween.is_valid():
		_weather_tween.kill()
	_weather_tween = create_tween()
	_weather_tween.tween_property(garden_layer, "modulate", target, 1.5).set_ease(Tween.EASE_IN_OUT)

func _apply_weather_particles(weather: int) -> void:
	if _rain_particles != null:
		_rain_particles.emitting = weather == WeatherTimeManager.WeatherType.RAIN
		_rain_particles.visible = _rain_particles.emitting
	if _snow_particles != null:
		_snow_particles.emitting = weather == WeatherTimeManager.WeatherType.SNOW
		_snow_particles.visible = _snow_particles.emitting

func _build_parallax_background() -> void:
	# 夜晚时段默认用夜景背景（garden_05），其他时段随机
	var idx: int
	if WeatherTimeManager and WeatherTimeManager.current_period == WeatherTimeManager.TimePeriod.NIGHT:
		idx = 5
	else:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		idx = rng.randi_range(1, 4)
	var path := "res://assets/art/garden/garden_%02d.png" % idx
	var tex := load(path) as Texture2D
	if tex == null:
		# fallback 到旧背景
		tex = load("res://assets/art/garden/garden_master.png") as Texture2D
	if tex == null:
		push_error("[Garden] 背景图加载失败")
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.position = Vector2.ZERO
	_bg_sprite = sprite
	_bg_index = idx
	garden_layer.add_child(sprite)
	# 按实际背景图尺寸锁相机+重算zoom填满视口
	var tex_size := tex.get_size()
	var vp_size := _garden_viewport.size
	if vp_size.y > 0 and tex_size.y > 0:
		_cam_zoom = vp_size.y / tex_size.y
		_camera.zoom = Vector2(_cam_zoom, _cam_zoom)
	_camera.position = Vector2(tex_size.x * 0.3, tex_size.y * 0.5)
	_camera.limit_smoothed = false
	_camera.limit_left = 0
	_camera.limit_right = int(tex_size.x)
	_camera.limit_top = 0
	_camera.limit_bottom = int(tex_size.y)
	# 同步更新猫咪走行区
	if CatSpawner and CatSpawner.has_method("set_wander_zone"):
		CatSpawner.set_wander_zone(idx)

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

	# 顶栏渐变遮罩（Shader版）：暖白 #FFF8E8，顶部96%硬度→渐隐至0%
	# 节点顺序：背景 → TopFade → HUD图标与文字（作为root的第一个子节点）
	var top_fade := ColorRect.new()
	top_fade.name = "TopFade"
	top_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_code := "shader_type canvas_item;\nuniform vec4 top_color : source_color = vec4(1.0, 0.973, 0.91, 0.96);\nuniform float solid_area = 0.32;\nuniform float fade_end = 0.95;\nvoid fragment() {\n	float alpha;\n	if (UV.y <= solid_area) {\n		alpha = 1.0;\n	} else {\n		alpha = 1.0 - smoothstep(solid_area, fade_end, UV.y);\n	}\n	COLOR = vec4(top_color.rgb, top_color.a * alpha);\n}"
	var s := Shader.new()
	s.code = shader_code
	var mat := ShaderMaterial.new()
	mat.shader = s
	top_fade.material = mat
	var mask_h := int(DESIGN_SIZE.y * 0.20)  # ~256px (240-280区间)
	top_fade.anchor_left = 0.0
	top_fade.anchor_right = 1.0
	top_fade.anchor_top = 0.0
	top_fade.anchor_bottom = 0.0
	top_fade.offset_top = 0.0
	top_fade.offset_bottom = mask_h
	root.add_child(top_fade)

	var debug_btn := Button.new()
	debug_btn.text = "DBG"
	debug_btn.flat = true
	# DBG移到左侧中间
	debug_btn.anchor_left = 0.0
	debug_btn.anchor_right = 0.0
	debug_btn.offset_left = 12.0
	debug_btn.offset_right = 56.0
	debug_btn.offset_top = 580.0
	debug_btn.offset_bottom = 620.0
	debug_btn.add_theme_color_override("font_color", Color.WHITE)
	debug_btn.add_theme_font_size_override("font_size", 14)
	var red_bg := StyleBoxFlat.new()
	red_bg.bg_color = Color.RED
	red_bg.set_corner_radius_all(6)
	debug_btn.add_theme_stylebox_override("normal", red_bg)
	debug_btn.pressed.connect(_toggle_debug_panel)
	root.add_child(debug_btn)

	# 棋盘入口按钮（左下角，首猫孵化后解锁占位）
	var board_btn := Button.new()
	board_btn.text = "🎮 合合乐"
	board_btn.flat = true
	board_btn.anchor_left = 0.0
	board_btn.anchor_right = 0.0
	board_btn.offset_left = 12.0
	board_btn.offset_right = 110.0
	board_btn.offset_top = 640.0
	board_btn.offset_bottom = 680.0
	board_btn.add_theme_color_override("font_color", Color("4F453C"))
	board_btn.add_theme_font_size_override("font_size", 16)
	var board_bg := StyleBoxFlat.new()
	board_bg.bg_color = Color("FAF6F0")
	board_bg.border_color = Color("C9C2B8")
	board_bg.set_border_width_all(2)
	board_bg.set_corner_radius_all(12)
	board_btn.add_theme_stylebox_override("normal", board_bg)
	var board_bg_hover := board_bg.duplicate()
	board_bg_hover.bg_color = Color("EFE4D6")
	board_btn.add_theme_stylebox_override("hover", board_bg_hover)
	board_btn.pressed.connect(func():
		UIManager.push("res://scenes/S14_BoardGame.tscn")
	)
	root.add_child(board_btn)

	# 顶栏：HBoxContainer，紧凑布局
	var top_row := HBoxContainer.new()
	top_row.anchor_right = 1.0
	top_row.offset_top = 16.0
	top_row.offset_bottom = 120.0
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 0)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_row)

	# 左侧间距
	var left_margin := Control.new()
	left_margin.custom_minimum_size = Vector2(16, 1)
	left_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(left_margin)
	# 步数
	var steps_box := HBoxContainer.new()
	steps_box.custom_minimum_size = Vector2(210, 1)
	steps_box.add_theme_constant_override("separation", 5)
	steps_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var steps_icon := TextureRect.new()
	steps_icon.texture = load("res://assets/art/ui/icons/icon_paw.png")
	steps_icon.custom_minimum_size = Vector2(24.0, 24.0)
	steps_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	steps_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	steps_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	steps_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	steps_box.add_child(steps_icon)
	_steps_label = Label.new()
	_steps_label.text = "0"
	_steps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_steps_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_steps_label.add_theme_font_size_override("font_size", 20)
	_steps_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_steps_label.gui_input.connect(_on_steps_label_input)
	steps_box.add_child(_steps_label)
	top_row.add_child(steps_box)
	# 能量
	var energy_box := HBoxContainer.new()
	energy_box.custom_minimum_size = Vector2(110, 1)
	energy_box.add_theme_constant_override("separation", 5)
	energy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var energy_icon := TextureRect.new()
	energy_icon.texture = load("res://assets/art/ui/icons/icon_sprout.png")
	energy_icon.custom_minimum_size = Vector2(24.0, 24.0)
	energy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	energy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	energy_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_box.add_child(energy_icon)
	_energy_label = Label.new()
	_energy_label.add_theme_font_size_override("font_size", 20)
	_energy_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_energy_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_energy_label.text = "0/0"
	energy_box.add_child(_energy_label)
	top_row.add_child(energy_box)
	# 中间弹性空白：让货币组稳定靠右
	var spacer_right := Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer_right)
	# 货币组
	var currency_box := HBoxContainer.new()
	currency_box.custom_minimum_size = Vector2(330, 1)
	currency_box.add_theme_constant_override("separation", 12)
	currency_box.alignment = BoxContainer.ALIGNMENT_END
	currency_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(currency_box)
	_currency_labels = []
	for entry in [
	{"icon": "icon_coin.png", "key": "gold_coins"},
	{"icon": "icon_gem.png", "key": "diamonds"},
	{"icon": "icon_petal.png", "key": "flower_petals"},
	]:
		var item_box := HBoxContainer.new()
		item_box.custom_minimum_size = Vector2(92, 1)
		item_box.add_theme_constant_override("separation", 5)
		item_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var item_icon := TextureRect.new()
		item_icon.texture = load("res://assets/art/ui/icons/" + String(entry["icon"]))
		item_icon.custom_minimum_size = Vector2(24.0, 24.0)
		item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_box.add_child(item_icon)
		var label := Label.new()
		label.text = str(CurrencyManager.get(entry["key"])) if CurrencyManager else "0"
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
		item_box.add_child(label)
		currency_box.add_child(item_box)
		_currency_labels.append(label)
	# 右侧间距（货币不贴边）
	var right_margin := Control.new()
	right_margin.custom_minimum_size = Vector2(16, 1)
	right_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(right_margin)

	# 日记未读提醒图标（贴顶栏右侧），默认隐藏
	_diary_notification_btn = TextureButton.new()
	_diary_notification_btn.name = "DiaryNotificationBtn"
	_diary_notification_btn.texture_normal = load("res://assets/art/ui/icons/icon_diary_notification.png")
	_diary_notification_btn.ignore_texture_size = true
	_diary_notification_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_diary_notification_btn.focus_mode = Control.FOCUS_NONE
	_diary_notification_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_diary_notification_btn.anchor_left = 1.0
	_diary_notification_btn.anchor_right = 1.0
	_diary_notification_btn.anchor_top = 0.0
	_diary_notification_btn.anchor_bottom = 0.0
	_diary_notification_btn.offset_left = -104.0
	_diary_notification_btn.offset_right = -60.0
	_diary_notification_btn.offset_top = 0.0
	_diary_notification_btn.offset_bottom = 44.0
	_diary_notification_btn.visible = false
	_diary_notification_btn.pressed.connect(_on_diary_notification_pressed)
	root.add_child(_diary_notification_btn)

	_empty_label = Label.new()
	_empty_label.text = "多走几步，猫咪就来了"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.position = Vector2(0.0, 620.0)
	_empty_label.size = Vector2(720.0, 56.0)
	_empty_label.add_theme_font_size_override("font_size", 20)
	_empty_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	root.add_child(_empty_label)

	# C1：「爱意工坊」FAB 常驻（右下角、底部导航上方——总案/蓝本 §3.6 位）。
	# 旧摆位（左下 -116~-76）落在 BottomNav 的 118px 带内且被其点击层遮挡，
	# 旧设计里该按钮默认隐藏所以从未暴露；常驻化后必须移出导航区。
	var workshop_btn := Button.new()
	workshop_btn.name = "WorkshopBtn"
	workshop_btn.text = "🎁 爱意工坊"
	workshop_btn.anchor_left = 1.0
	workshop_btn.anchor_right = 1.0
	workshop_btn.anchor_top = 1.0
	workshop_btn.anchor_bottom = 1.0
	workshop_btn.offset_left = -208.0
	workshop_btn.offset_right = -24.0
	workshop_btn.offset_top = -234.0
	workshop_btn.offset_bottom = -174.0
	workshop_btn.add_theme_font_size_override("font_size", 16)
	workshop_btn.visible = true
	root.add_child(workshop_btn)
	_refresh_workshop_fab()
	if workshop_btn.pressed.is_connected(_on_workshop_button):
		pass
	else:
		workshop_btn.pressed.connect(_on_workshop_button)

	# 「随行猫」图标 — 底部导航栏左上方
	var companion_btn := TextureButton.new()
	companion_btn.name = "CompanionBtn"
	companion_btn.texture_normal = load("res://assets/art/ui/companion/icon_follow_cat_normal.png")
	companion_btn.texture_hover = load("res://assets/art/ui/companion/icon_follow_cat_hover.png")
	companion_btn.texture_pressed = load("res://assets/art/ui/companion/icon_follow_cat_pressed.png")
	companion_btn.texture_disabled = load("res://assets/art/ui/companion/icon_follow_cat_disabled.png")
	companion_btn.ignore_texture_size = true
	companion_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	companion_btn.anchor_left = 0.0
	companion_btn.anchor_right = 0.0
	companion_btn.anchor_top = 1.0
	companion_btn.anchor_bottom = 1.0
	companion_btn.offset_left = 12.0
	companion_btn.offset_right = 108.0
	companion_btn.offset_top = -174.0
	companion_btn.offset_bottom = -78.0
	companion_btn.pressed.connect(_on_companion_pressed)
	companion_btn.visible = false
	root.add_child(companion_btn)

	var nav = BottomNavScene.instantiate()
	nav.set_current_tab(0)
	nav.tab_selected.connect(_on_bottom_nav_tab_selected)
	root.add_child(nav)

	_steps_hold_timer = Timer.new()
	_steps_hold_timer.one_shot = true
	_steps_hold_timer.wait_time = 3.0
	_steps_hold_timer.timeout.connect(_toggle_debug_panel)
	add_child(_steps_hold_timer)

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
		["☀️ 切换天气", func() -> void: _toggle_weather()],
		["🌓 切换时段", func() -> void: _toggle_period()],
		["🌙 猫咪睡觉", func() -> void: _toggle_sleep()],
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
	
	# 保存睡眠测试按钮引用
	_sleep_dbg_btn = box.get_child(box.get_child_count() - 1) as Button
	# ── 花园背景切换 ──
	var bg_label := Label.new()
	bg_label.text = "── 花园背景 ──"
	bg_label.add_theme_font_size_override("font_size", 11)
	bg_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	box.add_child(bg_label)
	var bg_btn := Button.new()
	bg_btn.text = "🖼️ 切换花园背景"
	bg_btn.custom_minimum_size = Vector2(0.0, 32.0)
	bg_btn.add_theme_font_size_override("font_size", 11)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.75, 0.85, 0.65, 0.3)
	bg_style.set_corner_radius_all(6)
	bg_btn.add_theme_stylebox_override("normal", bg_style)
	bg_btn.pressed.connect(_cycle_garden_bg)
	box.add_child(bg_btn)
	
	# 增大面板高度
	_debug_panel.size.y = 520

func _build_debug_panel() -> void:
	# Debug panel now built inside _build_hud()
	pass

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
	if EventBus:
		if not EventBus.hatch_activated.is_connected(_on_hatched_activated):
			EventBus.hatch_activated.connect(_on_hatched_activated)
		if not EventBus.currency_changed.is_connected(_on_currency_changed):
			EventBus.currency_changed.connect(_on_currency_changed)
	# C1 工坊 FAB 红点 + A5 奖励合流 + B3 池满温和提示
	if WorkshopManager:
		if not WorkshopManager.box_minted.is_connected(_on_workshop_box_minted):
			WorkshopManager.box_minted.connect(_on_workshop_box_minted)
		if not WorkshopManager.box_opened.is_connected(_on_workshop_box_opened):
			WorkshopManager.box_opened.connect(_on_workshop_box_opened)
	if StepEngine and not StepEngine.step_chest_opened.is_connected(_on_step_chest_opened):
		StepEngine.step_chest_opened.connect(_on_step_chest_opened)
	if EnergyEngine and not EnergyEngine.pool_became_full.is_connected(_on_pool_became_full):
		EnergyEngine.pool_became_full.connect(_on_pool_became_full)
	if CatScreenManager and not CatScreenManager.screen_cats_changed.is_connected(_on_screen_cats_changed):
		CatScreenManager.screen_cats_changed.connect(_on_screen_cats_changed)

func _refresh_all() -> void:
	_refresh_steps()
	_refresh_energy()
	_refresh_cat_state()
	_refresh_diary_notification()
	_refresh_currency()

# 扫描所有猫的日记未读标记，驱动顶栏提醒图标的显隐与点击行为
func _refresh_diary_notification() -> void:
	if _diary_notification_btn == null:
		return
	_diary_unread_cats = []
	if HatchEngine:
		for cat in HatchEngine.get_cats():
			var has_unread := false
			if cat is Dictionary:
				has_unread = bool(cat.get("diary_has_unread", false))
			else:
				var v = cat.get("diary_has_unread")
				has_unread = bool(v) if v != null else false
			if has_unread:
				_diary_unread_cats.append(cat)
	_diary_notification_btn.visible = _diary_unread_cats.size() > 0

func _on_diary_notification_pressed() -> void:
	var count: int = _diary_unread_cats.size()
	if count == 0:
		return
	if count == 1:
		var cat = _diary_unread_cats[0]
		var cat_data: Dictionary = cat if cat is Dictionary else _cat_to_dict(cat)
		UIManager.push("res://ui/pages/S10_CatDetail.tscn", {"cat": cat_data})
	else:
		UIManager.replace("res://ui/pages/S10_Album.tscn")

# 将 CatData / Dictionary 统一转为详情页所需的 Dictionary
func _cat_to_dict(cat) -> Dictionary:
	if cat is Dictionary:
		return cat.duplicate()
	var d := {}
	for key in ["id", "species", "rarity", "hatch_index", "display_name", "level", "exp", "friendship", "created_at", "diary_has_unread"]:
		var v = cat.get(key)
		if v != null:
			d[key] = v
	d["name"] = d.get("display_name", "")
	d["breed"] = d.get("species", "")
	return d

func _refresh_steps() -> void:
	var steps := 0
	if StepEngine:
		steps = StepEngine.get_today_steps()
	_steps_label.text = "今日 %s 步" % _format_int(steps)

func _refresh_energy() -> void:
	var current := 0.0
	var max_value := 15000.0
	if EnergyEngine:
		current = EnergyEngine.energy_pool
		max_value = EnergyEngine.MAX_ENERGY_POOL
	print("[Refresh] energy bar set: %.0f/%.0f" % [current, max_value])
	_energy_label.text = "%d/%d" % [int(current), int(max_value)]

func _refresh_cat_state() -> void:
	var cat_count := 0
	if HatchEngine:
		cat_count = HatchEngine.get_cats().size()
	_empty_label.visible = cat_count == 0

func _on_steps_updated(_delta: int, _total: int) -> void:
	_refresh_steps()

func _on_energy_changed(_current: float, _pool_max: float) -> void:
	_refresh_energy()

func _on_currency_changed(_gold: int, _diamonds: int, _petals: int) -> void:
	_refresh_currency()

func _refresh_currency() -> void:
	if _currency_labels.is_empty() or not CurrencyManager:
		return
	_currency_labels[0].text = str(CurrencyManager.gold_coins)
	_currency_labels[1].text = str(CurrencyManager.diamonds)
	_currency_labels[2].text = str(CurrencyManager.flower_petals)

func _on_cat_count_changed(_count: int) -> void:
	_refresh_cat_state()
	_apply_cat_visibility()

func _on_screen_cats_changed(_visible_cats: Array) -> void:
	_apply_cat_visibility()

# 按 CatScreenManager 的可见列表刷新场上猫节点的显隐。
# CatScreenManager 不存在时所有猫保持可见（向后兼容）。
func _apply_cat_visibility() -> void:
	# 场上的猫全部可见，不过滤（CatScreenManager的可见性仅用于图鉴/截图系统）
	if cat_container == null or not is_instance_valid(cat_container):
		return
	for child in cat_container.get_children():
		if "cat_data" in child and child.cat_data != null:
			child.visible = true

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
	if TutorialManager and TutorialManager.is_running():
		# 方案 C：Step 3 (HATCH) 阶段允许用户点孵化 tab
		if TutorialManager.current_step == TutorialManager.Step.HATCH:
			var page: String = String(BottomNav.TABS[index]["page"])
			if page == "res://scenes/S06_HatchPage.tscn":
				UIManager.replace(page)
		return
	if index < 0 or index >= BottomNav.TABS.size():
		return
	var page: String = String(BottomNav.TABS[index]["page"])
	if page == scene_file_path:
		return
	if page != "":
		UIManager.replace(page)

func _on_companion_pressed() -> void:
	if TutorialManager and TutorialManager.is_running():
		return
	UIManager.show_overlay("res://scenes/S07_CarryCatSelect.tscn")

func _on_workshop_button() -> void:
	if TutorialManager and TutorialManager.is_running():
		return
	UIManager.push("res://scenes/WorkshopPage.tscn")

func _refresh_workshop_fab() -> void:
	var btn := get_node_or_null("WorkshopBtn") as Button
	if btn == null:
		return
	var unopened: int = WorkshopManager.get_unopened_count() if WorkshopManager else 0
	if unopened > 0:
		btn.text = "🎁 爱意工坊 ×%d" % unopened
		btn.modulate = Color(1, 1, 1, 1)
	else:
		btn.text = "🎁 爱意工坊"
		btn.modulate = Color(1, 1, 1, 0.6)

func _on_workshop_box_minted(_unopened: int) -> void:
	_refresh_workshop_fab()
	if Popups:
		Popups.queue_reward_line("🎁 工坊礼盒做好了，去拆吧")

func _on_workshop_box_opened(_gift_id: String, _dupe_petals: int) -> void:
	_refresh_workshop_fab()

func _on_step_chest_opened(_index: int, gold: int) -> void:
	if Popups:
		Popups.queue_reward_line("📦 今日步数宝箱 +%d金币" % gold)

# B3 池满温和提示（每自然日仅首次；文案分支见总案 §2.6-A）
func _on_pool_became_full() -> void:
	if Popups == null:
		return
	if HatchEngine and HatchEngine.is_bag_full():
		Popups.show_toast("🌸 能量罐满啦～花园住满了，送养或扩容后继续吧")
	else:
		Popups.show_toast("🌸 能量罐满啦～孵颗蛋腾腾地方吧")

func _on_hatched_activated() -> void:
	var btn := get_node_or_null("WorkshopBtn")
	if btn != null:
		btn.visible = false

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


func _cycle_garden_bg() -> void:
	if _bg_sprite == null or not is_instance_valid(_bg_sprite):
		return
	_bg_index = (_bg_index % 5) + 1
	var path := "res://assets/art/garden/garden_%02d.png" % _bg_index
	var tex := load(path) as Texture2D
	if tex != null:
		_bg_sprite.texture = tex
		print("[DBG] 切换花园背景: garden_%02d" % _bg_index)
		# 同步更新猫咪走行区
		if CatSpawner and CatSpawner.has_method("set_wander_zone"):
			CatSpawner.set_wander_zone(_bg_index)
	else:
		print("[DBG] 加载失败: ", path)

func _add_mock_steps(amount: int) -> void:
	if StepEngine:
		StepEngine.add_mock_steps(amount)
	if SaveManager:
		SaveManager.save_all()


func _inject_data() -> void:
	if StepEngine:
		StepEngine.add_mock_steps(10000)
	if EnergyEngine:
		EnergyEngine.energy_pool = EnergyEngine.MAX_ENERGY_POOL
		EnergyEngine.created_at = Time.get_unix_time_from_system()
		EnergyEngine.energy_changed.emit(EnergyEngine.energy_pool, EnergyEngine.MAX_ENERGY_POOL)
	if SaveManager:
		SaveManager.save_all()


func _toggle_weather() -> void:
	var wtm := get_node_or_null("/root/WeatherTimeManager")
	if wtm == null:
		return
	var cur: int = wtm.current_weather
	var next: int = (cur + 1) % 3
	wtm.dbg_set_weather(next)


func _toggle_period() -> void:
	var wtm := get_node_or_null("/root/WeatherTimeManager")
	if wtm == null:
		return
	var cur: int = wtm.current_period
	var next: int = (cur + 1) % 3
	wtm.dbg_set_period(next)


var _sleep_dbg_btn: Button
var _sleep_override := false
func _toggle_sleep() -> void:
	_sleep_override = not _sleep_override
	if CatSchedule:
		if _sleep_override:
			CatSchedule.set_time_override(12)  # 中午 → 橘猫/英短睡觉
		else:
			CatSchedule.reset_all()
	if _sleep_dbg_btn:
		_sleep_dbg_btn.text = "☀️ 猫咪醒来" if _sleep_override else "🌙 猫咪睡觉"


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

func _unhandled_input(event: InputEvent) -> void:
	if TutorialManager and TutorialManager.is_blocking_garden_input():
		_dragging = false
		return
	# 捏合缩放
	if event is InputEventMagnifyGesture:
		if _is_in_garden(event.position):
			_handle_magnify_gesture(event)
		return
	# 鼠标左键
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_in_garden(event.position):
			get_viewport().set_input_as_handled()
			# 双击检测（仅用本地时间，Windows 可能在单次点击同时发 mouse 和 touch 两个事件）
			var now := Time.get_ticks_msec() / 1000.0
			var is_double_tap := now - _last_tap_time < DOUBLE_TAP_TIME and now - _last_touch_time >= 0.05
			_last_tap_time = now
			if is_double_tap:
				# 双击猫咪 → 弹 CatCard；双击背景 → 缩放
				if _emit_cat_click_at(event.position):
					_dragging = false
					return
				_cycle_garden_zoom(event.position)
				_dragging = false
				return
			# 单击：命中猫咪先飘爱心（任意缩放级别 L1/L2+ 都飘）
			_play_cat_click_heart_at(event.position)
			# L2+ 单击猫咪 → 在飘爱心之外，再弹 CatCard
			if _zoom_factor >= ZOOM_L2 and _emit_cat_click_at(event.position):
				_dragging = false
				return
			_dragging = true
			_drag_start = event.position
		else:
			_dragging = false
	# 鼠标拖拽
	elif event is InputEventMouseMotion and _dragging and _camera:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_dragging = false
		else:
			var drag_delta: Vector2 = event.position - _drag_start
			_camera.position.x -= drag_delta.x / _get_camera_zoom()
			_clamp_camera_to_world()
			_drag_start = event.position
	# 触摸事件（移动端）
	elif event is InputEventScreenTouch:
		if event.pressed and _is_in_garden(event.position):
			get_viewport().set_input_as_handled()
			var now := Time.get_ticks_msec() / 1000.0
			var is_double_tap := now - _last_touch_time < DOUBLE_TAP_TIME and now - _last_tap_time >= 0.05
			_last_touch_time = now
			if is_double_tap:
				# 双击猫咪 → 弹 CatCard；双击背景 → 缩放
				if _emit_cat_click_at(event.position):
					_dragging = false
					return
				_cycle_garden_zoom(event.position)
				_dragging = false
				return
			# 单击：命中猫咪先飘爱心（任意缩放级别 L1/L2+ 都飘）
			_play_cat_click_heart_at(event.position)
			# L2+ 单击猫咪 → 在飘爱心之外，再弹 CatCard
			if _zoom_factor >= ZOOM_L2 and _emit_cat_click_at(event.position):
				_dragging = false
				return
			_dragging = true
			_drag_start = event.position
		else:
			_dragging = false
	elif event is InputEventScreenDrag and _dragging and _camera:
		if _is_in_garden(event.position):
			var drag_delta: Vector2 = event.position - _drag_start
			_camera.position.x -= drag_delta.x / _get_camera_zoom()
			_clamp_camera_to_world()
			_drag_start = event.position
		else:
			_dragging = false

func _is_in_garden(pos: Vector2) -> bool:
	var vp_height := DESIGN_SIZE.y
	var vp := get_viewport()
	if vp != null and vp.get_visible_rect().size.y > 0.0:
		vp_height = vp.get_visible_rect().size.y
	return pos.y >= HUD_HEIGHT and pos.y <= vp_height

func _handle_magnify_gesture(event: InputEventMagnifyGesture) -> void:
	if _camera == null:
		return
	var cur_level := _get_garden_zoom_level()
	if event.factor >= 1.0 + PINCH_ZOOM_THRESHOLD:
		_set_garden_zoom_level(cur_level + 1, event.position)
	elif event.factor <= 1.0 - PINCH_ZOOM_THRESHOLD:
		_set_garden_zoom_level(cur_level - 1, event.position)

# 双击切换 L1<->L2（0.3s 平滑 Tween）
func _cycle_garden_zoom(anchor_screen_pos: Vector2) -> void:
	var target := ZOOM_L2 if _zoom_factor < 1.5 else ZOOM_L1
	var old_zoom := _zoom_factor
	_zoom_factor = target  # 立即更新，让后续 cat click 检测马上命中
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_method(_set_garden_zoom_factor, old_zoom, target, ZOOM_TWEEN_DURATION).set_ease(Tween.EASE_OUT)

func _set_garden_zoom_level(level: int, anchor_screen_pos: Vector2 = Vector2.ZERO) -> void:
	if GARDEN_ZOOM_LEVELS.is_empty():
		return
	var clamped_level: int = clampi(level, 0, GARDEN_ZOOM_LEVELS.size() - 1)
	_set_garden_zoom_factor(float(GARDEN_ZOOM_LEVELS[clamped_level]), anchor_screen_pos)

# 核心缩放方法：设 _zoom_factor，保持锚点位置
func _set_garden_zoom_factor(factor: float, anchor_screen_pos: Vector2 = Vector2.ZERO) -> void:
	if _camera == null:
		return
	var clamped_factor := clampf(factor, ZOOM_L1, ZOOM_L3)
	if is_equal_approx(clamped_factor, _zoom_factor) and is_equal_approx(_camera.zoom.x, _get_camera_zoom()):
		return
	var keep_anchor := anchor_screen_pos != Vector2.ZERO and _is_in_garden(anchor_screen_pos)
	var before_world := _screen_to_garden_world(anchor_screen_pos) if keep_anchor else Vector2.ZERO
	_zoom_factor = clamped_factor
	_camera.zoom = Vector2(_get_camera_zoom(), _get_camera_zoom())
	if keep_anchor:
		var after_world := _screen_to_garden_world(anchor_screen_pos)
		_camera.position.x += before_world.x - after_world.x
	_clamp_camera_to_world()

# 首猫孵化回来后：显示引导提示，3 秒后自动消失
func _show_hatch_guide_tip() -> void:
	if not is_inside_tree():
		return
	var tip := Label.new()
	tip.name = "HatchGuideTip"
	tip.text = "🐱 点击猫咪可以互动哦！"
	tip.add_theme_font_size_override("font_size", 26)
	tip.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	tip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	tip.add_theme_constant_override("shadow_outline_size", 2)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tip.offset_top = 200.0
	tip.offset_bottom = 260.0
	add_child(tip)
	# 淡入
	tip.modulate.a = 0.0
	var fade_in: Tween = create_tween()
	fade_in.tween_property(tip, "modulate:a", 1.0, 0.3)
	# 3 秒后淡出
	var fade_out: Tween = create_tween()
	fade_out.set_delay(3.0)
	fade_out.tween_property(tip, "modulate:a", 0.0, 0.5)
	fade_out.tween_callback(tip.queue_free)

# 找最接近当前 _zoom_factor 的级别索引
func _get_garden_zoom_level() -> int:
	var closest_level := 0
	var closest_delta := INF
	for i in range(GARDEN_ZOOM_LEVELS.size()):
		var delta := absf(_zoom_factor - float(GARDEN_ZOOM_LEVELS[i]))
		if delta < closest_delta:
			closest_delta = delta
			closest_level = i
	return closest_level

func _get_camera_zoom() -> float:
	return _cam_zoom * _zoom_factor

func _screen_to_garden_world(screen_pos: Vector2) -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	var vp := _camera.get_viewport()
	var view := Vector2(DESIGN_SIZE.x, DESIGN_SIZE.y - HUD_HEIGHT)
	if vp != null and vp.get_visible_rect().size.y > 0.0:
		view = vp.get_visible_rect().size
	var zoom := maxf(_get_camera_zoom(), 0.0001)
	return _camera.position + (screen_pos - view * 0.5) / zoom

func _emit_cat_click_at(screen_pos: Vector2) -> bool:
	var best_cat = _find_cat_at(screen_pos)
	if best_cat == null:
		return false
	var cid := str(best_cat.id) if best_cat != null else ""
	cat_clicked.emit(cid, screen_pos)
	return true

# 单击命中猫咪时让它飘爱心（弹跳+♥），不发射信号、不弹 CatCard。
# L1/L2+ 单击都会调用：L1 仅飘心，L2+ 飘心之外另走 _emit_cat_click_at 弹卡。
func _play_cat_click_heart_at(screen_pos: Vector2) -> void:
	var cat = _find_cat_at(screen_pos)
	if cat == null:
		return
	var cat_node = CatSpawner.get_cat_node(cat) if CatSpawner else null
	if cat_node != null and cat_node.has_method("_play_click_feedback"):
		cat_node._play_click_feedback()

# 检测指定屏幕位置是否有猫咪（不发射信号）
func _find_cat_at(screen_pos: Vector2):
	if HatchEngine == null or CatSpawner == null:
		return null
	var world_pos := _screen_to_garden_world(screen_pos)
	var best_cat = null
	var best_dist := INF
	for cat_data in HatchEngine.get_cats():
		var cat_world_pos: Vector2 = CatSpawner.get_cat_world_position(cat_data)
		if cat_world_pos == Vector2.ZERO:
			continue
		var dist := world_pos.distance_to(cat_world_pos)
		if dist <= CAT_HIT_RADIUS and dist < best_dist:
			best_dist = dist
			best_cat = cat_data
	return best_cat

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
	# 优先用实际加载的背景图高度，否则退到 WORLD_HEIGHT
	var bg_h := WORLD_HEIGHT
	if _bg_sprite != null and _bg_sprite.texture != null:
		bg_h = _bg_sprite.texture.get_size().y
	if view.y > 0.0 and bg_h > 0.0:
		_cam_zoom = view.y / bg_h
	else:
		_cam_zoom = CONTENT_SCALE
	var zoom := _get_camera_zoom()
	_camera.zoom = Vector2(zoom, zoom)
	# 初始显示花园左半部分（从 x=0 开始）
	var _half_visible_w: float = (view.x * 0.5) / max(zoom, 0.0001)
	_camera.position = Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.5)
	_clamp_camera_to_world()

func _clamp_camera_to_world() -> void:
	if _camera == null:
		return
	# 核心安全修复：防止节点未入树时 get_viewport() 报空指针
	var vp := _camera.get_viewport()
	var view: Vector2 = Vector2(DESIGN_SIZE.x, DESIGN_SIZE.y - HUD_HEIGHT)
	if vp != null and vp.get_visible_rect().size.y > 0.0:
		view = vp.get_visible_rect().size
		
	var half_w: float = (view.x * 0.5) / max(_get_camera_zoom(), 0.0001)
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

