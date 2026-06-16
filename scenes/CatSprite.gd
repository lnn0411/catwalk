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
@export var walk_scale_factor: float = 1.02  # 缩放因子：微调走路图片比例（如果画小了，代码自动放大）
@export var idle_scale_factor: float = 0.88  # 缩放因子：微调待机图片比例（如果画大了，代码自动缩小）
@export var turn_scale_factor: float = 0.85  # 再次调低转身缩放，确保转体时视觉尺寸平滑一致

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
var _turn_tween: Tween   # 转身翻转/过渡动画
var _turn_playing := false  # 转身过渡帧播放中（锁住走路换帧防打架）
var _is_move_turn := false  # 当前是否为移动中转向过渡
var _cached_frame_count := 0  # 该品种序列帧数缓存
var _cached_walk_frame_count := 0 # 该品种走路序列帧数缓存
var _stuck_time := 0.0   # 撞障碍累计卡顿时长（超阈值就换方向）
var _move_dir := Vector2.ZERO  # 当前移动方向（平滑转向，走曲线不走折线）
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
	if _turn_playing:
		_facing_left = want_left  # 转身动画进行中，只更新目标朝向，不打断
		return
	_facing_left = want_left
	if _sprite == null:
		return
	# 优先：若该品种有移动转身过渡帧（move_turn_00~04），且当前在移动中，播移动转身
	if is_moving and _has_move_turn_frames():
		_play_turn_sequence(want_left, true)
		return
	# 其次：播静态转身过渡帧（turn_00~04）
	elif _has_turn_frames():
		_play_turn_sequence(want_left, false)
		return
	if _turn_tween and _turn_tween.is_valid():
		_turn_tween.kill()
	# 干净利落翻转：瞬间换朝向 + 轻微弹性回弹给手感（不压扁假装转身）。
	_sprite.flip_h = _facing_left
	_sprite.scale.x = 0.86
	_turn_tween = create_tween()
	_turn_tween.tween_property(_sprite, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# 品种目录名（orange→orange_tabby，其余同名）
func _breed_dir() -> String:
	return "orange_tabby" if breed == "orange" else breed

# 是否存在转身过渡帧（只查首帧，存在即认为整组就绪）
func _has_turn_frames() -> bool:
	return ResourceLoader.exists("res://assets/art/cats/%s/turn_00.png" % _breed_dir())

# 是否存在移动中转身过渡帧
func _has_move_turn_frames() -> bool:
	return ResourceLoader.exists("res://assets/art/cats/%s/move_turn_00.png" % _breed_dir())

# 播放转身过渡序列：左转正序 turn_00→04，右转倒序 turn_04→00（库洛洛只画一套）。
# 播放期间锁住走路换帧（_turn_playing），播完落到目标朝向并恢复。
func _play_turn_sequence(to_left: bool, is_move_turn: bool = false) -> void:
	if _turn_tween and _turn_tween.is_valid():
		_turn_tween.kill()
	_is_move_turn = is_move_turn
	_turn_playing = true
	# 统一应用转身缩放微调，防止转体时猫咪突现“变大”的视觉膨胀感
	var t_scale = turn_scale_factor
	_sprite.scale = Vector2(t_scale, t_scale)
	_sprite.flip_h = false  # 转身帧本身已画好朝向，不用镜像
	var dir := _breed_dir()
	var prefix := "move_turn" if is_move_turn else "turn"
	var order := [0, 1, 2, 3, 4] if to_left else [4, 3, 2, 1, 0]
	_turn_tween = create_tween()
	for idx in order:
		var path := "res://assets/art/cats/%s/%s_%02d.png" % [dir, prefix, idx]
		_turn_tween.tween_callback(func() -> void:
			if _sprite and ResourceLoader.exists(path):
				_sprite.texture = load(path))
		# 移动中转身各帧播放加快，避免拖沓；正面帧（2）稍微停驻
		var interval := (0.11 if idx == 2 else 0.07) if is_move_turn else (0.26 if idx == 2 else 0.10)
		_turn_tween.tween_interval(interval)
	# 播完：重置动画序列，并【立即】强行调用 _update_sprite()，实现零延迟、无缝衔接走路/待机第 0 帧，彻底消灭末尾卡顿！
	_turn_tween.tween_callback(func() -> void:
		_turn_playing = false
		_walk_frame = -1 # 设为 -1，使得 _update_sprite() 累加后完美从第 0 帧 (walk_00/idle_00) 开始播放
		_update_sprite()
		if _sprite:
			_sprite.flip_h = _facing_left)

# 兼容旧调用名（CatSpawner 入场等处用 face_direction）
func face_direction(dx: float) -> void:
	_face_to(dx)

func _count_child_sprites() -> int:
	var n := 0
	for c in get_children():
		if c is Sprite2D:
			n += 1
	return n

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()

	# 防重复：若已有 Sprite 子节点（_ready 重入/重复 instance），先清掉，避免两张图叠着。
	var existing_sprites := 0
	for c in get_children():
		if c is Sprite2D:
			existing_sprites += 1
	if existing_sprites > 0:
		for c in get_children():
			if c is Sprite2D:
				c.queue_free()

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)
	_sprite.flip_h = _facing_left  # 应用 add_child 前（入场）设置的朝向
	_update_sprite()

	# 碰撞层/掩码：让猫之间互相阻挡（没设的话猫互相穿透→避障检测永不触发）
	collision_layer = 2
	collision_mask = 2

	var body_shape := CollisionShape2D.new()
	var body_circle := CircleShape2D.new()
	body_circle.radius = 26.0
	body_shape.shape = body_circle
	add_child(body_shape)

	var area := Area2D.new()
	area.input_pickable = true
	area.collision_layer = 4   # 点击层独立，不和物理猫层混
	area.collision_mask = 0
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

# 计算近大远小的透视比例（草地 Y 轴范围 380 ~ 640，对应比例从 0.82 渐变到 1.15）
func _get_perspective_scale() -> float:
	var t := clampf((position.y - 380.0) / (640.0 - 380.0), 0.0, 1.0)
	return lerpf(0.82, 1.15, t)

# ============ M4：每帧动画（全部作用于 _sprite 子节点）============
func _process(delta: float) -> void:
	_anim_time += delta
	if _sprite == null:
		return
	
	# 近大远小透视比例（走上去变小，走下来变大）
	var depth_scale := _get_perspective_scale()
	
	var formal_breed := breed
	if formal_breed == "orange":
		formal_breed = "orange_tabby"
	
	if is_moving:
		# 转身过渡播放时，走路动效全让位（不写 rotation/position/scale），让转身帧干净显示
		var turning: bool = _turn_playing or (_turn_tween != null and _turn_tween.is_valid())
		var speed_ratio: float = clampf(_cur_speed / maxf(move_speed, 1.0), 0.0, 1.0)
		_step_phase += delta * lerpf(5.0, 9.0, speed_ratio)
		if not turning:
			var cycle := sin(_step_phase)
			_sprite.rotation = cycle * 0.025 * speed_ratio
			# 如果 Y 轴纵向移动分量大，增加踏步反弹高度，消除平移像"飘过去"的滑行鬼魂感
			var vertical_bias := lerpf(1.0, 2.5, absf(_move_dir.y))
			_sprite.position.y = -absf(cycle) * 2.0 * speed_ratio * vertical_bias
			
			var ss := (absf(cycle) - 0.5) * 0.02 * speed_ratio
			var s_factor = walk_scale_factor * depth_scale
			_sprite.scale = Vector2(s_factor * (1.0 - ss), s_factor * (1.0 + ss))
	else:
		# idle 待机状态
		_sprite.rotation = lerpf(_sprite.rotation, 0.0, delta * 8.0)
		_sprite.position.y = lerpf(_sprite.position.y, 0.0, delta * 8.0)
		
		if not (_turn_tween != null and _turn_tween.is_valid()):
			var idle_frames := _count_breed_frames(formal_breed)
			var s_factor = idle_scale_factor * depth_scale
			
			if idle_frames > 1:
				# ✨ 核心优化：既然我们已经有了主人给的 10 帧高保真手绘待机/呼吸序列，
				# 我们就 100% 依赖手绘序列来展现自然的呼吸！
				# 此时必须【禁用】代码里的程序化拉伸（breath），防止手绘呼吸与程序拉伸双重叠加，
				# 导致猫咪停顿下来时像气球一样突兀地“吹胀、变大、忽大忽小”！
				_sprite.scale = Vector2(s_factor, s_factor)
			else:
				# 回退低配模式：若没有多帧序列，才用代码程序化拉伸
				var breath := 1.0 + (sin(_anim_time * 1.6) + 1.0) * 0.5 * 0.03
				_sprite.scale = Vector2(s_factor, s_factor * breath)
	
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
	target_position.x = clampf(target_position.x, 350.0, 1700.0)
	target_position.y = clampf(target_position.y, 380.0, 640.0) # 草坪安全区：避开背景下半土区(Y)和左右灌木/小路(X)
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
	target_position.x = clampf(target_position.x, 350.0, 1700.0)
	target_position.y = clampf(target_position.y, 380.0, 640.0) # 草坪安全区：避开背景下半土区(Y)和左右灌木/小路(X)
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
	if _turn_playing:
		return  # 转身过渡帧播放中，不被走路换帧覆盖

	var formal_breed := breed
	if formal_breed == "orange":
		formal_breed = "orange_tabby"

	var prefix := "idle"
	var frame_index := 0
	
	if is_moving:
		var walk_frames := _count_breed_walk_frames(formal_breed)
		if walk_frames > 0:
			prefix = "walk"
			_walk_frame = (_walk_frame + 1) % walk_frames
			frame_index = _walk_frame
		else:
			# 回退模式：若无 walk_*.png，则用传统的 idle_*.png 兼任行走帧
			var max_frames := _count_breed_frames(formal_breed)
			if max_frames == 3:
				_walk_frame = (_walk_frame % 2) + 1
			else:
				_walk_frame = (_walk_frame + 1) % max_frames
			frame_index = _walk_frame
	else:
		# 待机状态：循环播放 10 帧高保真 idle_00~idle_09 呼吸动画，让猫咪真正活过来！
		var idle_frames := _count_breed_frames(formal_breed)
		if idle_frames > 1:
			_walk_frame = (_walk_frame + 1) % idle_frames
			frame_index = _walk_frame
		else:
			_walk_frame = 0
			frame_index = 0

	# 动态自适应步伐时间间隔 (走路 8 帧用 0.08s 快速高频，待机呼吸 10 帧用 0.16s 舒缓慢速)
	if sprite_timer != null:
		var speed_ratio: float = clampf(_cur_speed / maxf(move_speed, 1.0), 0.25, 1.0)
		var base: float = 0.08 if prefix == "walk" else 0.16
		sprite_timer.wait_time = base / speed_ratio

	# 2. 动态生成正式路径：如 res://assets/art/cats/orange_tabby/walk_05.png 或 idle_02.png
	var frame_name := "%s_%02d" % [prefix, frame_index]
	var formal_path := "res://assets/art/cats/%s/%s.png" % [formal_breed, frame_name]
	
	# 3. 动态生成 Fallback 备份名（确保没图时也绝对 100% 绿色不报错）
	var fallback_anim := "idle"
	if is_moving:
		fallback_anim = "walk_a" if (frame_index % 2 == 1) else "walk_b"
	var fallback_path := "res://assets/temp/cats/cat_%s_%s.png" % [breed, fallback_anim]

	if ResourceLoader.exists(formal_path):
		var tex = load(formal_path)
		if tex != null:
			_sprite.texture = tex
	elif _sprite.texture == null:
		var tex = load(fallback_path)
		if tex != null:
			_sprite.texture = tex

func _physics_process(delta: float) -> void:
	if is_moving:
		# 转身过渡播放时暂停移动：猫停下来回头看，转完再走（移动转身 move_turn 除外，避免顿挫）
		if _turn_playing and not _is_move_turn:
			velocity = Vector2.ZERO
			return
		var to_target := (target_position - position)
		var dist := to_target.length()
		var desired_dir := to_target.normalized()
		
		# 避障/分离力 (Separation force): 避免多只猫咪挤在一起或撞上
		var separation := Vector2.ZERO
		var neighbors_count := 0
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child != self and "is_moving" in child:
					var d := position.distance_to(child.position)
					if d < 180.0 and d > 0.1: # 扩大检测范围到 180 像素，提前避让
						var push: Vector2 = (position - child.position).normalized()
						# 排斥力呈非线性放大，距离越近，力量越是强力（2.5倍力量因子）
						var strength := (1.0 - d / 180.0) * 2.5
						separation += push * strength
						neighbors_count += 1
		
		if neighbors_count > 0:
			separation = (separation / neighbors_count)
			# 强力混合：给予 1.5 倍高权重排斥力，让猫咪极度敏感地偏航、环绕走，绝不硬怼
			desired_dir = (desired_dir + separation * 1.5).normalized()

		# ① 方向曲线化：当前朝向平滑转向目标方向，而不是瞬间对准直线奔过去。
		# 转向有惯性 → 走出来是弧线，不是生硬折线。
		if _move_dir == Vector2.ZERO:
			_move_dir = desired_dir
		_move_dir = _move_dir.lerp(desired_dir, delta * 3.5).normalized()
		# ② 速度起伏：基础速度上叠一层正弦波动 → 踱步的快慢节奏，不再匀速滑行。
		var target_speed := move_speed
		if dist < 90.0:
			target_speed = move_speed * maxf(dist / 90.0, 0.35)  # 临近减速
		var bob := 1.0 + sin(_step_phase * 2.0) * 0.18           # ±18% 踱步起伏
		_cur_speed = lerpf(_cur_speed, target_speed * bob, delta * 5.0)
		velocity = _move_dir * _cur_speed
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
				_move_dir = Vector2.ZERO
				velocity = Vector2.ZERO
				# 立刻换个方向重选目标（往反方向偏，避开障碍）
				_pick_new_target_away_from(_move_dir)
				return
		else:
			_stuck_time = 0.0
		if dist < 14.0:
			is_moving = false
			_cur_speed = 0.0
			_move_dir = Vector2.ZERO
			velocity = Vector2.ZERO
			_update_sprite()
			_schedule_wander()
	# 自愈保险：任何原因出界都拉回活动范围（仅出界时写，避免每帧赋值）
	var cx := clampf(position.x, 350.0, 1700.0)
	var cy := clampf(position.y, 380.0, 640.0) # 草坪安全区：避开背景下半土区(Y)和左右灌木/小路(X)
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
	# 脚下落地影：低透明度+偏冷绿暗色（非纯黑），叠在黄绿草地上不混出"脏泥坑"。
	var shadow_color := Color(0.12, 0.14, 0.06, 0.11)
	var bounce_ratio := 1.0
	if is_moving:
		# 向上跳起时，影子微弱缩小变淡
		bounce_ratio = clampf(1.0 - (absf(_sprite.position.y) / 18.0) * 0.25, 0.75, 1.0)
	
	# 阴影尺寸根据猫咪呼吸/跳跃高度联动缩放
	var shadow_size := Vector2(30.0 * bounce_ratio, 7.0 * bounce_ratio)
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

# 动态计算该猫种正式目录下实际存在的 walk_*.png 帧数
func _count_breed_walk_frames(breed_name: String) -> int:
	if _cached_walk_frame_count > 0:
		return _cached_walk_frame_count
	var count := 0
	for i in range(64):
		if ResourceLoader.exists("res://assets/art/cats/%s/walk_%02d.png" % [breed_name, i]):
			count += 1
		else:
			break
	_cached_walk_frame_count = count
	return _cached_walk_frame_count

# 动态计算该猫种正式目录下实际存在的 idle_*.png 帧数，实现全自动智能兼容
func _count_breed_frames(breed_name: String) -> int:
	# 用 ResourceLoader.exists 逐帧探测真实帧数——DirAccess 在运行时/导出后
	# 列不出导入的 png（Godot 转成 .ctex 缓存），会导致帧数算错→帧索引越界→
	# 美术图与占位图高频交替闪（"两张图同时显示"的真因）。
	# 结果缓存到 _cached_frame_count，避免每次换帧都探测。
	if _cached_frame_count > 0:
		return _cached_frame_count
	var count := 0
	for i in range(64):  # 上限64帧足够
		if ResourceLoader.exists("res://assets/art/cats/%s/idle_%02d.png" % [breed_name, i]):
			count += 1
		else:
			break  # 连续编号，遇到缺口即停
	_cached_frame_count = count if count > 0 else 3
	return _cached_frame_count
