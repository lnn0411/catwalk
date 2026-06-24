extends CharacterBody2D
class_name CatSprite

signal cat_clicked(cat_data)

@export var breed: String = "orange" # orange / orange_tabby / british / siamese
@export var cat_data: Resource

@export_group("Movement")
@export var move_speed: float = 52.0
@export var acceleration: float = 7.0
@export var arrive_distance: float = 12.0
@export var wander_min_distance: float = 80.0
@export var wander_max_distance: float = 260.0
# 游荡范围必须与 CatSpawner 出生范围一致（X:350-1700, Y:380-640）。
# 否则猫出生在草坪却会自己走到 y=780 的泥土区 → 泥潭 bug 复发。
# 改这里务必同步 CatSpawner._pick_spawn_position / _setup_entrance 的同名数值。
@export var wander_x_min: float = 350.0
@export var wander_x_max: float = 1700.0
@export var wander_y_min: float = 380.0
@export var wander_y_max: float = 640.0

@export_group("Animation")
@export var walk_fps: float = 8.0
@export var idle_fps: float = 4.0
@export var turn_fps: float = 5.7
@export var move_turn_fps: float = 5.0
@export var sprite_scale: float = 1.0
# 整图背景（garden_master.png）无透视梯度，景深缩放会让猫忽大忽小却与平铺草坪脱节。
# 故关闭，让猫在草坪任意位置保持稳定体型。换成带透视的分层背景时再开回 true。
@export var depth_scale_enabled: bool = false
@export var shadow_enabled: bool = true
@export var idle_breath_enabled: bool = true

@export_group("Chroma Key")
@export var chroma_key_enabled: bool = true
@export var chroma_key_threshold: float = 0.22
@export var chroma_key_softness: float = 0.08

const FRAME_SIZE := Vector2i(100, 140)
const FOOT_Y := 131
const WALK_PX_BRITISH := 4.0
const WALK_PX_ORANGE := 6.5
const WALK_PX_SIAMESE := 7.0

# 方向差异化步幅：side（侧面，脚位移大）/ up_right（斜向，中）/ front（正背面，小）
const WALK_PX_ORANGE_SIDE := 8.0
const WALK_PX_ORANGE_UPRIGHT := 7.0
const WALK_PX_ORANGE_FRONT := 4.0
const WALK_PX_BRITISH_SIDE := 7.0
const WALK_PX_BRITISH_UPRIGHT := 6.0
const WALK_PX_BRITISH_FRONT := 4.0
const WALK_PX_SIAMESE_SIDE := 7.0
const WALK_PX_SIAMESE_UPRIGHT := 6.0
const WALK_PX_SIAMESE_FRONT := 3.5

const BOB_AMPLITUDE := 2.5  # 走路踩地弹跳幅度（视觉像素，乘以深度缩放后使用）
const IDLE_HEIGHT_SCALE := 100.0 / 126.0  # ≈0.794

const ANIM_WALK_RIGHT := "walk_right"
const ANIM_WALK_UP_RIGHT := "walk_up_right"
const ANIM_WALK_UP := "walk_up"
const ANIM_WALK_DOWN_RIGHT := "walk_down_right"
const ANIM_WALK_DOWN := "walk_down"
const ANIM_IDLE := "idle"
const ANIM_TURN := "turn"
const ANIM_MOVE_TURN := "move_turn"

const ANIM_ROWS := {
	ANIM_WALK_RIGHT: 0,
	ANIM_WALK_UP_RIGHT: 1,
	ANIM_WALK_UP: 2,
	ANIM_WALK_DOWN_RIGHT: 3,
	ANIM_WALK_DOWN: 4,
	ANIM_IDLE: 5,
	ANIM_TURN: 6,
	ANIM_MOVE_TURN: 7,
}

const ANIM_FRAME_COUNT := {
	ANIM_WALK_RIGHT: 4,
	ANIM_WALK_UP_RIGHT: 4,
	ANIM_WALK_UP: 4,
	ANIM_WALK_DOWN_RIGHT: 4,
	ANIM_WALK_DOWN: 4,
	ANIM_IDLE: 4,
	ANIM_TURN: 4,
	ANIM_MOVE_TURN: 4,
}
var _frames_cache: Dictionary = {}

var rng := RandomNumberGenerator.new()
var target_position := Vector2.ZERO
var is_moving := false

var _sprite: Sprite2D
var _texture: Texture2D
var _config: Dictionary = {}

var _current_anim := ANIM_IDLE
var _current_col := 0
var _frame_accum := 0.0
var _facing_left := false
var _last_motion_dir := Vector2.RIGHT

var _turn_playing := false
var _turn_after_anim := ANIM_IDLE
var _turn_after_flip := false

var _move_dir := Vector2.ZERO
var _cur_speed := 0.0
var _idle_phase := 0.0
var _stuck_time := 0.0
var _walk_accum := 0.0
var _walk_px_table: Dictionary = {}
var _last_frame_pos := Vector2.ZERO
var _turn_cooldown := 0.0

var _wander_timer: Timer
var _bounce_tween: Tween


func _ready() -> void:
	rng.randomize()
	target_position = position

	# 随行中图标（绿色爪印，头顶显示）
	var companion_icon := Label.new()
	companion_icon.name = "CompanionIcon"
	companion_icon.text = "🐾"
	companion_icon.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	companion_icon.add_theme_font_size_override("font_size", 20)
	companion_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	companion_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	companion_icon.position = Vector2(-12, -90)
	companion_icon.size = Vector2(24, 24)
	companion_icon.visible = false
	add_child(companion_icon)

	_setup_sprite()
	_load_frames()
	_setup_collision()
	_setup_click_area()

	_wander_timer = Timer.new()
	_wander_timer.one_shot = true
	add_child(_wander_timer)
	_wander_timer.timeout.connect(_on_wander_tick)

	# 位移驱动帧：品种 + 方向差异化步幅 + 初始位置
	_walk_px_table = _get_walk_px_per_frame()
	_last_frame_pos = global_position

	set_process(true)
	set_physics_process(true)

	_set_anim(ANIM_IDLE, false, true)
	_schedule_wander()


func _breed_dir() -> String:
	match breed:
		"orange", "orange_tabby":
			return "orange"
		"british":
			return "british"
		"siamese":
			return "siamese"
		_:
			return "orange"


func _texture_path(anim: String, frame: int) -> String:
	var dir := _breed_dir()
	var base_name := _anim_to_file_prefix(anim)
	return "res://assets/art/cats/%s/%s_frame_%02d.png" % [dir, base_name, frame]


func _config_path() -> String:
	return ""


func _anim_to_file_prefix(anim: String) -> String:
	# British frames are mirrored compared to orange/siamese
	var is_british_inverted := breed == "british"
	match anim:
		"walk_right":
			return "side_left" if is_british_inverted else "side_right"
		"walk_up_right":
			return "back_left" if is_british_inverted else "back_right"
		"walk_up":
			return "back"
		"walk_down_right":
			return "front_left" if is_british_inverted else "front_right"
		"walk_down":
			return "front"
		"idle":
			return "idle_front"
		"turn", "move_turn":
			return "idle_front"
		_:
			return "front"


func _setup_sprite() -> void:
	for c in get_children():
		if c is Sprite2D:
			c.queue_free()

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)

	if chroma_key_enabled:
		_sprite.material = _make_chroma_key_material()


func _load_frames() -> void:
	var dir := _breed_dir()
	for anim in [ANIM_WALK_RIGHT, ANIM_WALK_UP_RIGHT, ANIM_WALK_UP, ANIM_WALK_DOWN_RIGHT, ANIM_WALK_DOWN, ANIM_IDLE, "turn", "move_turn"]:
		var prefix := _anim_to_file_prefix(anim)
		var frames: Array[Texture2D] = []
		var frame_count: int = ANIM_FRAME_COUNT.get(anim, 4)
		for i in range(frame_count):
			var path := "res://assets/art/cats/%s/%s_frame_%02d.png" % [dir, prefix, i]
			if ResourceLoader.exists(path):
				frames.append(load(path))
		if frames.is_empty():
			push_error("CatSprite: no frames loaded for anim %s breed %s" % [anim, dir])
		_frames_cache[anim] = frames
	_apply_frame(ANIM_IDLE, 0)
	_apply_sprite_anchor(0.5, 1.0)


func _make_chroma_key_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec3 key_color = vec3(0.0, 1.0, 0.0);
uniform float threshold = 0.22;
uniform float softness = 0.08;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float d = distance(tex.rgb, key_color);
	float a = smoothstep(threshold, threshold + softness, d);
	COLOR = vec4(tex.rgb, tex.a * a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("threshold", chroma_key_threshold)
	mat.set_shader_parameter("softness", chroma_key_softness)
	return mat


func _setup_collision() -> void:
	collision_layer = 2
	collision_mask = 0

	var body_shape := CollisionShape2D.new()
	body_shape.position = Vector2(0, -42)
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	body_shape.shape = circle
	add_child(body_shape)


func _setup_click_area() -> void:
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	area.collision_layer = 4
	area.collision_mask = 0
	area.position = Vector2(0, -58)
	add_child(area)

	var click_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 44.0
	click_shape.shape = circle
	area.add_child(click_shape)

	area.input_event.connect(_on_input_event)


func _process(delta: float) -> void:
	_idle_phase += delta
	_turn_cooldown = maxf(0.0, _turn_cooldown - delta)
	# 随行图标更新
	_update_companion_icon()

	# Walk 动画：位移驱动（脚随身体走）；其他：时间驱动
	if _is_walk_anim(_current_anim):
		_advance_walk_by_distance()
	else:
		_advance_animation(delta)

	_apply_visual_motion(delta)
	_last_frame_pos = global_position

	if shadow_enabled:
		queue_redraw()


func _get_walk_px_per_frame() -> Dictionary:
	var side: float
	var up_right: float
	var front: float
	if breed == "british":
		side = WALK_PX_BRITISH_SIDE
		up_right = WALK_PX_BRITISH_UPRIGHT
		front = WALK_PX_BRITISH_FRONT
	elif breed == "orange" or breed == "orange_tabby":
		side = WALK_PX_ORANGE_SIDE
		up_right = WALK_PX_ORANGE_UPRIGHT
		front = WALK_PX_ORANGE_FRONT
	else:
		side = WALK_PX_SIAMESE_SIDE
		up_right = WALK_PX_SIAMESE_UPRIGHT
		front = WALK_PX_SIAMESE_FRONT
	return {
		ANIM_WALK_RIGHT: side,
		ANIM_WALK_DOWN_RIGHT: side,
		ANIM_WALK_UP_RIGHT: up_right,
		ANIM_WALK_UP: front,
		ANIM_WALK_DOWN: front,
	}


func _current_walk_px() -> float:
	return _walk_px_table.get(_current_anim, WALK_PX_ORANGE)


func _is_walk_anim(anim_name: String) -> bool:
	return anim_name != ANIM_IDLE and anim_name != ANIM_TURN and anim_name != ANIM_MOVE_TURN


func _advance_walk_by_distance() -> void:
	var moved := global_position.distance_to(_last_frame_pos)
	_walk_accum += moved

	var px_per_frame := _current_walk_px()
	var max_frames: int = ANIM_FRAME_COUNT.get(_current_anim, 4)
	while _walk_accum >= px_per_frame:
		_walk_accum -= px_per_frame
		_current_col += 1
		if _current_col >= max_frames:
			_current_col = 0
			if _turn_playing:
				_turn_playing = false
				_set_anim(_turn_after_anim, _turn_after_flip, true)
				return
		_apply_frame(_current_anim, _current_col)


func _advance_animation(delta: float) -> void:
	var fps := _get_anim_fps(_current_anim)
	if fps <= 0.0:
		return

	_frame_accum += delta
	var frame_time := 1.0 / fps
	while _frame_accum >= frame_time:
		_frame_accum -= frame_time
		var max_frames: int = ANIM_FRAME_COUNT.get(_current_anim, 4)
		_current_col += 1

		if _current_col >= max_frames:
			if _turn_playing:
				_turn_playing = false
				_set_anim(_turn_after_anim, _turn_after_flip, true)
				return
			_current_col = 0

		_apply_frame(_current_anim, _current_col)


func _get_anim_fps(anim_name: String) -> float:
	if anim_name == ANIM_IDLE:
		return idle_fps
	if anim_name == ANIM_TURN:
		return turn_fps
	if anim_name == ANIM_MOVE_TURN:
		return move_turn_fps
	return walk_fps


func _set_anim(anim_name: String, flip_left: bool, force: bool = false) -> void:
	if _turn_playing and not force:
		return
	if not force and _current_anim == anim_name and _facing_left == flip_left:
		return

	_current_anim = anim_name
	_current_col = 0
	_frame_accum = 0.0
	_walk_accum = 0.0
	_facing_left = flip_left
	_sprite.flip_h = _facing_left
	_apply_frame(_current_anim, _current_col)


var _foot_cache: Dictionary = {}

func _get_foot_offset(resource_path: String) -> int:
	if _foot_cache.has(resource_path):
		return _foot_cache[resource_path]
	var img := Image.new()
	var abs_path := ProjectSettings.globalize_path(resource_path)
	if img.load(abs_path) == OK:
		var h := img.get_height()
		var foot_y := h - 1
		for y in range(h - 1, -1, -1):
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.05:
					foot_y = y
					_foot_cache[resource_path] = h - 1 - foot_y
					return _foot_cache[resource_path]
	_foot_cache[resource_path] = 0
	return 0


func _apply_frame(anim: String, frame: int) -> void:
	_current_anim = anim
	var frames: Array = _frames_cache.get(anim, [])
	var tex: Texture2D = frames[frame % maxi(frames.size(), 1)] if not frames.is_empty() else null
	if tex != _sprite.texture:
		_sprite.texture = tex
	if tex != null:
		_sprite.region_enabled = true
		_sprite.region_rect = Rect2(Vector2.ZERO, tex.get_size())
		# Auto-align foot to bottom: scan texture's source image for lowest non-transparent pixel
		var foot_offset := _get_foot_offset(tex.resource_path)
		_sprite.position.y = float(foot_offset)


func _get_region_from_config(anim_name: String, col: int) -> Array:
	if _config.is_empty() or not _config.has("animations"):
		return []
	var animations: Dictionary = _config["animations"]
	if not animations.has(anim_name):
		return []
	var anim: Dictionary = animations[anim_name]
	var frames: Array = anim.get("frames", [])
	if col < 0 or col >= frames.size():
		return []
	return frames[col].get("region", [])


func _apply_visual_motion(_delta: float) -> void:
	var depth_scale := 1.0
	if depth_scale_enabled:
		var t := clampf((position.y - wander_y_min) / maxf(wander_y_max - wander_y_min, 1.0), 0.0, 1.0)
		depth_scale = lerpf(0.82, 1.15, t)

	var sx := sprite_scale * depth_scale
	var sy := sx

	# 橘猫视觉略小
	if breed == "orange" or breed == "orange_tabby":
		sx *= 0.93
		sy *= 0.93

	if _current_anim == ANIM_IDLE:
		sx *= IDLE_HEIGHT_SCALE
		sy *= IDLE_HEIGHT_SCALE

	z_index = int(position.y)

	_sprite.rotation = 0.0
	_sprite.scale = Vector2(sx, sy)
	_apply_sprite_anchor(sx, sy)

	# 走路弹跳：每个位移帧内做一次半正弦踩地，只偏移 sprite 的 y，不动根节点
	if _is_walk_anim(_current_anim):
		var px := _current_walk_px()
		var phase := _walk_accum / px * PI
		_sprite.position.y += sin(phase) * BOB_AMPLITUDE * sy


func _apply_sprite_anchor(sx: float, sy: float) -> void:
	# Sprite2D centered=false 时，纹理局部坐标 (50, 131) 是脚底锚点。
	# 这里让脚底锚点永远落在 CatSprite 根节点原点，避免猫漂浮。
	_sprite.position = Vector2(-FRAME_SIZE.x * 0.5 * sx, -FOOT_Y * sy)


func _start_turn_anim(move_turn: bool, after_anim: String, after_flip: bool) -> void:
	_turn_playing = true
	_turn_after_anim = after_anim
	_turn_after_flip = after_flip
	_set_anim(ANIM_MOVE_TURN if move_turn else ANIM_TURN, after_flip, true)


func _select_anim_from_direction(dir: Vector2) -> Dictionary:
	if dir.length() < 0.001:
		return {"anim": ANIM_IDLE, "flip": _facing_left}

	var deg := rad_to_deg(dir.angle())
	if deg >= -22.5 and deg < 22.5:
		# 英短 walk_right 帧无交替迈步，用斜向帧代替
		if breed.begins_with("british"):
			return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": false}
		return {"anim": ANIM_WALK_RIGHT, "flip": false}
	elif deg >= 22.5 and deg < 67.5:
		return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": false}
	elif deg >= 67.5 and deg < 112.5:
		# 橘猫 walk_down 帧无迈步动画，用斜向帧代替
		if breed.begins_with("orange"):
			return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": _facing_left}
		return {"anim": ANIM_WALK_DOWN, "flip": false}
	elif deg >= 112.5 and deg < 157.5:
		return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": true}
	elif deg >= 157.5 or deg < -157.5:
		# 英短 walk_left 帧无交替迈步，用斜向帧代替
		if breed.begins_with("british"):
			return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": true}
		return {"anim": ANIM_WALK_RIGHT, "flip": true}
	elif deg >= -157.5 and deg < -112.5:
		# 英短 walk_up_left 帧无交替迈步，用斜向帧代替
		if breed.begins_with("british"):
			return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": true}
		return {"anim": ANIM_WALK_UP_RIGHT, "flip": true}
	elif deg >= -112.5 and deg < -67.5:
		return {"anim": ANIM_WALK_UP, "flip": false}
	else:
		# 英短 walk_up_right 帧无交替迈步，用斜向帧代替
		if breed.begins_with("british"):
			return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": false}
		return {"anim": ANIM_WALK_UP_RIGHT, "flip": false}


func _physics_process(delta: float) -> void:
	if not is_moving:
		velocity = velocity.lerp(Vector2.ZERO, delta * acceleration)
		_cur_speed = velocity.length()
		return

	var to_target := target_position - position
	var dist := to_target.length()
	if dist <= arrive_distance:
		is_moving = false
		velocity = Vector2.ZERO
		_cur_speed = 0.0
		_move_dir = Vector2.ZERO
		_set_anim(ANIM_IDLE, _facing_left)
		_schedule_wander()
		return

	var desired_dir := to_target.normalized()
	desired_dir = _apply_separation(desired_dir)

	_move_dir = desired_dir if _move_dir == Vector2.ZERO else _move_dir.lerp(desired_dir, delta * 4.0).normalized()

	var target_speed := move_speed
	if dist < 90.0:
		target_speed = move_speed * maxf(dist / 90.0, 0.35)

	velocity = velocity.lerp(_move_dir * target_speed, delta * acceleration)
	_cur_speed = velocity.length()

	var before := position
	move_and_slide()
	var moved := position.distance_to(before)

	if moved > 0.01:
		_last_motion_dir = (position - before).normalized()
		var selected := _select_anim_from_direction(_last_motion_dir)
		var next_anim: String = selected["anim"]
		var next_flip: bool = selected["flip"]
		if next_flip != _facing_left and not _turn_playing and _turn_cooldown <= 0.0:
			_start_turn_anim(true, next_anim, next_flip)
			_turn_cooldown = 0.5
		else:
			_set_anim(next_anim, next_flip)

	_check_stuck(delta, moved)
	_clamp_to_wander_area()


func _apply_separation(desired_dir: Vector2) -> Vector2:
	var parent := get_parent()
	if parent == null:
		return desired_dir

	var separation := Vector2.ZERO
	var count := 0
	for child in parent.get_children():
		if child == self or not (child is Node2D):
			continue
		var d := position.distance_to(child.position)
		if d > 0.1 and d < 160.0:
			var push: Vector2 = (position - child.position).normalized()
			separation += push * ((1.0 - d / 160.0) * 3.0)
			count += 1

	if count == 0:
		return desired_dir

	separation /= count
	var dot_prod := separation.dot(desired_dir)
	if dot_prod < 0.0:
		separation -= dot_prod * desired_dir

	return (desired_dir + separation * 1.2).normalized()


func _check_stuck(delta: float, moved: float) -> void:
	var expected := maxf(_cur_speed * delta, 0.001)
	if expected > 1.0 and moved < expected * 0.35:
		_stuck_time += delta
	else:
		_stuck_time = 0.0

	if _stuck_time > 0.35:
		_stuck_time = 0.0
		_pick_new_target_away_from(_move_dir)


func _pick_new_target_away_from(blocked_dir: Vector2) -> void:
	var away := -blocked_dir
	if away.length() < 0.001:
		away = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))

	var angle := away.angle() + rng.randf_range(-PI / 3.0, PI / 3.0)
	var dist := rng.randf_range(wander_min_distance, wander_max_distance)
	target_position = position + Vector2(cos(angle), sin(angle) * 0.65) * dist
	target_position.x = clampf(target_position.x, wander_x_min, wander_x_max)
	target_position.y = clampf(target_position.y, wander_y_min, wander_y_max)
	is_moving = true


func _on_wander_tick() -> void:
	if rng.randf() < 0.12:
		_start_turn_anim(false, ANIM_IDLE, not _facing_left)
		_facing_left = not _facing_left
		_schedule_wander()
		return

	var dist := rng.randf_range(wander_min_distance, wander_max_distance)
	var angle := rng.randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle) * 0.65) * dist
	target_position = position + offset
	target_position.x = clampf(target_position.x, wander_x_min, wander_x_max)
	target_position.y = clampf(target_position.y, wander_y_min, wander_y_max)
	is_moving = true


func _schedule_wander() -> void:
	var r := rng.randf()
	var pause := rng.randf_range(0.4, 1.2) if r < 0.45 else (rng.randf_range(1.5, 3.5) if r < 0.85 else rng.randf_range(4.0, 7.0))
	_wander_timer.start(pause)


func _clamp_to_wander_area() -> void:
	position.x = clampf(position.x, wander_x_min, wander_x_max)
	position.y = clampf(position.y, wander_y_min, wander_y_max)


func face_direction(dx: float) -> void:
	if absf(dx) < 0.001:
		return
	var want_left := dx < 0.0
	if want_left == _facing_left:
		return
	_facing_left = want_left
	if is_moving:
		_start_turn_anim(true, _current_anim, want_left)
	else:
		_start_turn_anim(false, ANIM_IDLE, want_left)


func set_breed(new_breed: String) -> void:
	breed = new_breed
	_config.clear()
	_load_frames()
	_set_anim(ANIM_IDLE, false, true)


func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_click_feedback()
		cat_clicked.emit(cat_data)


func _update_companion_icon() -> void:
	var icon := get_node_or_null("CompanionIcon") as Label
	if icon == null:
		return
	var is_companion: bool = false
	if HatchEngine and cat_data != null:
		var cid: String = String(cat_data.id)
		is_companion = cid != "" and cid == HatchEngine.current_companion_cat_id
	icon.visible = is_companion


func _play_click_feedback() -> void:
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()

	_bounce_tween = create_tween()
	_bounce_tween.tween_property(_sprite, "position:y", _sprite.position.y - 12.0, 0.10).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_callback(func() -> void:
		_apply_visual_motion(0.0)
	)

	var heart := Label.new()
	heart.text = "♥"
	heart.add_theme_font_size_override("font_size", 30)
	heart.add_theme_color_override("font_color", Color("#D98E8E"))
	heart.position = Vector2(-12.0, -96.0)
	add_child(heart)

	var ht := create_tween()
	ht.set_parallel(true)
	ht.tween_property(heart, "position:y", heart.position.y - 44.0, 0.7).set_ease(Tween.EASE_OUT)
	ht.tween_property(heart, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	ht.chain().tween_callback(heart.queue_free)


func _draw() -> void:
	if not shadow_enabled:
		return
	_draw_oval(Vector2(0, 3), Vector2(30, 7), Color(0.12, 0.14, 0.06, 0.11))


func _draw_oval(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := float(i) / 24.0 * TAU
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	draw_colored_polygon(points, color)
