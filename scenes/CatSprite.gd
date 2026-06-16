extends CharacterBody2D

# ============================================================
# CatSprite —— M4 猫咪活化版
# ------------------------------------------------------------
# 在原版基础上新增（逻辑/信号/贴图加载方式不变）：
#   ① 走路摆动：移动时轻微左右摇 + 颠步起伏
#   ② idle 呼吸：站立时身体缓慢起伏（scale.y 1.0~1.03）
#   ③ 点击反馈：被点瞬间跳一下 + 头顶冒 ♥ 飘起 + 轻震（Juice.tap）
#   ④ 随机小动作：wander 时 25% 概率原地转身（不移动）
# 实现要点：所有动画做在子节点 _sprite 上——根节点的 scale.x
# 被用于左右翻面（±1），动根节点会和翻面打架。
# ============================================================

signal cat_clicked(cat_data)

var cat_data
@export var breed: String = "orange"
@export var move_speed: float = 50.0

var rng: RandomNumberGenerator
var timer: Timer
var sprite_timer: Timer
var target_position: Vector2
var is_moving: bool = false
var _sprite: Sprite2D
var _walk_frame: int = 0

# —— M4 动画状态 ——
var _anim_time := 0.0
var _step_phase := 0.0   # 走路步频相位（摇摆/颠步共用，随速度推进）
var _cur_speed := 0.0    # 当前实际速度（加减速过渡）
var _turn_tween: Tween   # 转身挤压翻转动画
var _stuck_time := 0.0   # 撞障碍累计卡顿时长（超阈值就换方向）
var _bounce_tween: Tween   # 点击弹跳，防重复叠加
# 朝向（修复：CharacterBody2D 不支持负 scale——物理服务器会正交规范化变换，
# move_and_slide 时视觉与物理不一致，移动中位置漂移/瞬移="走着走着消失"。
# 翻面一律走 _sprite.flip_h，根节点 scale 永远保持 (1,1)）
var _facing_left := false

# 公有：按水平方向设置朝向（CatSpawner 入场时会在 add_child 前调用，
# 此时 _sprite 尚未创建，先存状态、_ready 时应用）
# 转向：不再瞬间镜像翻转——做一个"横向挤压→翻面→弹回"的小动画，
# 模拟猫转身的视觉（squash 翻转法，2帧贴图也能有转身感）。
func _face_to(dx: float) -> void:
	if absf(dx) < 0.001:
		return
	var want_left: bool = dx < 0.0
	if want_left == _facing_left and _sprite != null and _sprite.flip_h == want_left:
		return  # 朝向没变，不重复播
	_facing_left = want_left
	if _sprite == null:
		return
	if _turn_tween and _turn_tween.is_valid():
		_turn_tween.kill()
	# 干净利落翻转：瞬间换朝向 + 轻微弹性回弹给手感（不压扁假装转身）。
	# 2D单视角贴图本质是镜像翻转，朴素利落比障眼法自然；真正转身体积感留待美术补帧。
	_sprite.flip_h = _facing_left
	_sprite.scale.x = 0.86
	_turn_tween = create_tween()
	_turn_tween.tween_property(_sprite, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# 兼容旧调用名（CatSpawner 入场等处用 face_direction）
func face_direction(dx: float) -> void:
	_face_to(dx)

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)
	_sprite.flip_h = _facing_left  # 应用 add_child 前（入场）设置的朝向
	_update_sprite()

	var body_shape := CollisionShape2D.new()
	var body_circle := CircleShape2D.new()
	body_circle.radius = 30.0
	body_shape.shape = body_circle
	add_child(body_shape)

	var area := Area2D.new()
	area.input_pickable = true
	add_child(area)

	var click_shape := CollisionShape2D.new()
	var click_circle := CircleShape2D.new()
	click_circle.radius = 40.0
	click_shape.shape = click_circle
	area.add_child(click_shape)
	area.input_event.connect(_on_input_event)

	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_wander_tick)

	sprite_timer = Timer.new()
	sprite_timer.wait_time = 0.16 # 核心优化：将帧率从 0.3s (慢幻灯片) 提升至 0.16s (流畅行走步频)
	sprite_timer.one_shot = false
	add_child(sprite_timer)
	sprite_timer.timeout.connect(_update_sprite)
	sprite_timer.start()

	# 呼吸相位随机偏移：多只猫不同步呼吸，避免"军训感"
	_anim_time = rng.randf_range(0.0, TAU)
	set_process(true)

	_schedule_wander()

# ============ M4：每帧动画（全部作用于 _sprite 子节点）============
func _process(delta: float) -> void:
	_anim_time += delta
	if _sprite == null:
		return
	if is_moving:
		# 转身动画进行中时，不写 scale（让 _face_to 的挤压翻转独占，否则被覆盖）
		var turning: bool = _turn_tween != null and _turn_tween.is_valid()
		# 10帧贴图已自带腿部动作——代码动效退为"轻微辅助"，避免贴图动+代码晃的双重运动。
		var speed_ratio: float = clampf(_cur_speed / maxf(move_speed, 1.0), 0.0, 1.0)
		_step_phase += delta * lerpf(5.0, 9.0, speed_ratio)
		var cycle := sin(_step_phase)
		_sprite.rotation = cycle * 0.025 * speed_ratio
		_sprite.position.y = -absf(cycle) * 2.0 * speed_ratio
		if not turning:
			var ss := (absf(cycle) - 0.5) * 0.02 * speed_ratio
			_sprite.scale = Vector2(1.0 - ss, 1.0 + ss)
	else:
		# idle：缓慢呼吸（y 轴 1.0~1.03），轻微到"感觉活着"即可
		_sprite.rotation = lerpf(_sprite.rotation, 0.0, delta * 8.0)
		_sprite.position.y = lerpf(_sprite.position.y, 0.0, delta * 8.0)
		var breath := 1.0 + (sin(_anim_time * 1.6) + 1.0) * 0.5 * 0.03
		if not (_turn_tween != null and _turn_tween.is_valid()):
			_sprite.scale = Vector2(1.0, breath)
	
	# 刷新底层扁平椭圆阴影的实时重绘
	queue_redraw()

# 撞障碍后：往"远离障碍"的方向偏着重选目标（在反方向±60°扇形里挑），
# 避免立刻又撞上同一个东西。短距离试探，走得通再说。
func _pick_new_target_away_from(blocked_dir: Vector2) -> void:
	var away := -blocked_dir
	var base_angle := away.angle()
	var ang := base_angle + rng.randf_range(-PI / 3.0, PI / 3.0)
	var d := rng.randf_range(80.0, 200.0)
	var offset := Vector2(cos(ang) * 1.0, sin(ang) * 0.55) * d
	target_position = position + offset
	target_position.x = clampf(target_position.x, 120.0, 1880.0)
	target_position.y = clampf(target_position.y, 620.0, 1080.0)
	is_moving = true
	_face_to(target_position.x - position.x)

func _on_wander_tick() -> void:
	# 35% 原地小动作：转身张望 / 短暂发呆（不移动，添生气）
	if rng.randf() < 0.35:
		if rng.randf() < 0.6:
			_face_to(1.0 if _facing_left else -1.0)  # 转身张望
		_schedule_wander()
		return
	# 距离更碎、更随机：短踱步多、偶尔大步——避免"每次都走同样一段直线"的呆板
	var wander_distance := rng.randf_range(60.0, 340.0)
	var wander_angle := rng.randf_range(0.0, TAU)
	var offset := Vector2(cos(wander_angle) * 1.0, sin(wander_angle) * 0.55) * wander_distance
	target_position = position + offset
	target_position.x = clampf(target_position.x, 120.0, 1880.0)
	target_position.y = clampf(target_position.y, 620.0, 1080.0)
	is_moving = true
	_face_to(target_position.x - position.x)

func _schedule_wander() -> void:
	# 停顿时长随机化：多数短停(像猫边走边改主意)，偶尔长停张望——比固定3~6s自然
	var pause: float
	var r := rng.randf()
	if r < 0.45:
		pause = rng.randf_range(0.3, 1.2)   # 短停，接近连续走
	elif r < 0.85:
		pause = rng.randf_range(1.5, 3.5)   # 中停
	else:
		pause = rng.randf_range(4.0, 7.0)   # 偶尔长停发呆
	timer.start(pause)

func _update_sprite() -> void:
	if _sprite == null:
		return

	# 1. 动态自适应确定当前品种的最大序列帧数（自动扫描文件夹下 idle_*.png 的实际数量）
	var formal_breed := breed
	if formal_breed == "orange":
		formal_breed = "orange_tabby"
		
	var max_frames := _count_breed_frames(formal_breed)

	var frame_index := 0
	if is_moving:
		if max_frames == 3:
			# 3帧经典模式：只在 idle_01 (walk_a) 和 idle_02 (walk_b) 之间循环，剔除站立帧 idle_00，避免漫步时一瘸一拐
			_walk_frame = (_walk_frame % 2) + 1
		else:
			# 多帧序列模式：全序列（0 到 max_frames - 1）均为行走帧
			_walk_frame = (_walk_frame + 1) % max_frames
		frame_index = _walk_frame
	else:
		_walk_frame = 0
		frame_index = 0

	# 动态自适应步伐时间间隔 (多帧小碎步用 0.08s 快帧率以保证极其丝滑；3帧用 0.16s 标准步频)
	if sprite_timer != null:
		var speed_ratio: float = clampf(_cur_speed / maxf(move_speed, 1.0), 0.25, 1.0)
		var base: float = 0.07 if max_frames >= 5 else 0.18  # 10帧用0.07s丝滑
		sprite_timer.wait_time = base / speed_ratio

	# 2. 动态生成正式路径：如 res://assets/art/cats/orange_tabby/idle_05.png
	var frame_name := "idle_%02d" % frame_index
	var formal_path := "res://assets/art/cats/%s/%s.png" % [formal_breed, frame_name]
	
	# 3. 动态生成 Fallback 备份名（确保没图时也绝对 100% 绿色不报错）
	# 如果正式路径下没有 10 帧，奇数帧走 walk_a，偶数帧走 walk_b
	var fallback_anim := "idle"
	if is_moving:
		fallback_anim = "walk_a" if (frame_index % 2 == 1) else "walk_b"
	var fallback_path := "res://assets/temp/cats/cat_%s_%s.png" % [breed, fallback_anim]

	if ResourceLoader.exists(formal_path):
		_sprite.texture = load(formal_path)
	else:
		_sprite.texture = load(fallback_path)

func _physics_process(delta: float) -> void:
	if is_moving:
		var direction := (target_position - position).normalized()
		var dist := position.distance_to(target_position)
		# 起步平滑加速、临近目标减速（不再瞬间满速/急停）
		var target_speed := move_speed
		if dist < 80.0:
			target_speed = move_speed * maxf(dist / 80.0, 0.35)
		_cur_speed = lerpf(_cur_speed, target_speed, delta * 6.0)
		velocity = direction * _cur_speed
		var before := position
		move_and_slide()
		# 撞障碍检测：实际移动远小于预期（被其他猫/边界挡住）→ 累计卡顿；
		# 连续卡几帧就放弃当前目标、换个方向重新溜达（轻量避障，不做 A* 绕路）。
		var moved := position.distance_to(before)
		var expected := _cur_speed * delta
		if expected > 1.0 and moved < expected * 0.4:
			_stuck_time += delta
			if _stuck_time > 0.25:
				_stuck_time = 0.0
				is_moving = false
				_cur_speed = 0.0
				velocity = Vector2.ZERO
				# 立刻换个方向重选目标（_on_wander_tick 会避开，往反方向偏）
				_pick_new_target_away_from(direction)
				return
		else:
			_stuck_time = 0.0
		if dist < 10.0:
			is_moving = false
			_cur_speed = 0.0
			velocity = Vector2.ZERO
			_update_sprite()
			_schedule_wander()
	# 自愈保险：任何原因出界都拉回活动范围（仅出界时写，避免每帧赋值）
	var cx := clampf(position.x, 100.0, 1900.0)
	var cy := clampf(position.y, 620.0, 1080.0) # 与 wander 纵深一致(620~1080)，否则自愈把猫拉回旧边界=卡成横线
	if cx != position.x or cy != position.y:
		position = Vector2(cx, cy)

func _on_input_event(viewport, event, shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_click_feedback()
		cat_clicked.emit(cat_data)

# ============ M4：点击反馈（弹跳 + ♥ 飘起 + 轻震）============
func _play_click_feedback() -> void:
	# 轻震（Juice 未注册时安全跳过）
	var j := get_node_or_null("/root/Juice")
	if j: j.tap()
	# 弹跳：_sprite 快速上跳回落（不动物理体，纯视觉）
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(_sprite, "position:y", -18.0, 0.10).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_sprite, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN)
	# ♥ 从头顶飘起渐隐
	var heart := Label.new()
	heart.text = "♥"
	heart.add_theme_font_size_override("font_size", 30)
	heart.add_theme_color_override("font_color", Color("#D98E8E"))
	heart.position = Vector2(-12.0, -86.0)
	add_child(heart)
	var ht := create_tween()
	ht.set_parallel(true)
	ht.tween_property(heart, "position:y", heart.position.y - 44.0, 0.7).set_ease(Tween.EASE_OUT)
	ht.tween_property(heart, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	ht.chain().tween_callback(heart.queue_free)

# ============ 动态椭圆阴影绘制 ============
func _draw() -> void:
	# 绘制一个扁平椭圆半透明黑影子，坐落在猫咪脚底中心
	var shadow_color := Color(0, 0, 0, 0.16)
	var bounce_ratio := 1.0
	if is_moving:
		# 向上跳起时，影子微弱缩小变淡
		bounce_ratio = clampf(1.0 - (absf(_sprite.position.y) / 18.0) * 0.25, 0.75, 1.0)
	
	# 阴影尺寸根据猫咪呼吸/跳跃高度联动缩放
	var shadow_size := Vector2(35.0 * bounce_ratio, 9.0 * bounce_ratio)
	# 阴影圆心位于猫咪脚底下边缘
	draw_oval(Vector2(0, 60.0), shadow_size, shadow_color)

# 绘制扁平椭圆形影子的辅助方法（Godot 4 兼容）
func draw_oval(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 24
	for i in range(steps):
		var angle := float(i) / steps * TAU
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	draw_colored_polygon(points, color)

# 动态计算该猫种正式目录下实际存在的 idle_*.png 帧数，实现全自动智能兼容
func _count_breed_frames(breed_name: String) -> int:
	var path := "res://assets/art/cats/" + breed_name + "/"
	var dir := DirAccess.open(path)
	if dir == null:
		return 3 # 无法打开目录则安全 fallback 到 3 帧
		
	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("idle_") and file_name.ends_with(".png"):
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# 如果没有正式序列帧，返回 3 帧以进行 fallback
	return count if count > 0 else 3
