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
var _bounce_tween: Tween   # 点击弹跳，防重复叠加
# 朝向（修复：CharacterBody2D 不支持负 scale——物理服务器会正交规范化变换，
# move_and_slide 时视觉与物理不一致，移动中位置漂移/瞬移="走着走着消失"。
# 翻面一律走 _sprite.flip_h，根节点 scale 永远保持 (1,1)）
var _facing_left := false

# 公有：按水平方向设置朝向（CatSpawner 入场时会在 add_child 前调用，
# 此时 _sprite 尚未创建，先存状态、_ready 时应用）
func face_direction(dx: float) -> void:
	if absf(dx) < 0.001:
		return
	_facing_left = dx < 0.0
	if _sprite != null:
		_sprite.flip_h = _facing_left

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
	sprite_timer.wait_time = 0.3
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
		# 走路：左右轻摇 + 颠步起伏（频率与步频感匹配）
		_sprite.rotation = sin(_anim_time * 9.0) * 0.06
		_sprite.position.y = -absf(sin(_anim_time * 9.0)) * 3.0
		_sprite.scale = Vector2.ONE
	else:
		# idle：缓慢呼吸（y 轴 1.0~1.03），轻微到"感觉活着"即可
		_sprite.rotation = lerpf(_sprite.rotation, 0.0, delta * 8.0)
		_sprite.position.y = lerpf(_sprite.position.y, 0.0, delta * 8.0)
		var breath := 1.0 + (sin(_anim_time * 1.6) + 1.0) * 0.5 * 0.03
		_sprite.scale = Vector2(1.0, breath)

func _schedule_wander() -> void:
	timer.start(rng.randf_range(3.0, 6.0))

func _on_wander_tick() -> void:
	# M4：25% 概率不移动，只原地转个身（小动作，添生气）
	if rng.randf() < 0.25:
		face_direction(1.0 if _facing_left else -1.0)  # 原地转身=翻面取反
		_schedule_wander()
		return
	var wander_distance := rng.randf_range(100.0, 300.0)
	var wander_angle := rng.randf_range(0.0, TAU)
	var offset := Vector2(cos(wander_angle), sin(wander_angle)) * wander_distance
	target_position = position + offset
	target_position.x = clampf(target_position.x, 100.0, 1900.0)
	target_position.y = clampf(target_position.y, 116.0, 1016.0)
	is_moving = true
	face_direction(target_position.x - position.x)

func _update_sprite() -> void:
	if _sprite == null:
		return

	var animation_name := "idle"
	if is_moving:
		_walk_frame = (_walk_frame + 1) % 3
		match _walk_frame:
			1:
				animation_name = "walk_a"
			2:
				animation_name = "walk_b"
			_:
				animation_name = "idle"
	else:
		_walk_frame = 0

	_sprite.texture = load('res://assets/temp/cats/cat_%s_%s.png' % [breed, animation_name])

func _physics_process(delta: float) -> void:
	if is_moving:
		var direction := (target_position - position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		if position.distance_to(target_position) < 10.0:
			is_moving = false
			velocity = Vector2.ZERO
			_update_sprite()
			_schedule_wander()
	# 自愈保险：任何原因出界都拉回活动范围（仅出界时写，避免每帧赋值）
	var cx := clampf(position.x, 100.0, 1900.0)
	var cy := clampf(position.y, 116.0, 1016.0)
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
