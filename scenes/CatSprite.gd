extends CharacterBody2D
class_name CatSprite

# ============================================================
# CatSprite —— M5 32帧 spritesheet 版
# ------------------------------------------------------------
# 适配规格：
# - 每品种 1 张 spritesheet
# - 8 行 × 4 列 = 32 帧
# - 每格 100×140
# - 脚底 y = 131
# - 背景纯绿 #00FF00，运行时用 shader 色键抠掉
#
# Row 0 walk_right      Walk →  侧身右
# Row 1 walk_up_right   Walk ↗  3/4背侧
# Row 2 walk_up         Walk ↑  纯背
# Row 3 walk_down_right Walk ↘  3/4腹侧
# Row 4 walk_down       Walk ↓  正脸
# Row 5 idle            Idle
# Row 6 turn            Turn
# Row 7 move_turn       Move Turn
#
# 镜像补全：
# ←  = row 0 + flip_h
# ↖ = row 1 + flip_h
# ↙ = row 3 + flip_h
# ============================================================

signal cat_clicked(cat_data)

@export var breed: String = "orange" # orange / orange_tabby / british / siamese
@export var cat_data: Resource = null # CatData resource

@export_group("Movement")
@export var move_speed: float = 52.0
@export var acceleration: float = 7.0
@export var arrive_distance: float = 12.0
@export var wander_min_distance: float = 80.0
@export var wander_max_distance: float = 260.0
@export var wander_x_min: float = 150.0
@export var wander_x_max: float = 1950.0
@export var wander_y_min: float = 380.0
@export var wander_y_max: float = 780.0

@export_group("Animation")
@export var walk_fps: float = 8.0
@export var idle_fps: float = 4.0
@export var turn_fps: float = 10.0
@export var move_turn_fps: float = 10.0
@export var sprite_scale: float = 0.85
@export var depth_scale_enabled: bool = true
@export var shadow_enabled: bool = true

@export_group("Chroma Key")
@export var chroma_key_enabled: bool = true
@export var chroma_key_threshold: float = 0.22
@export var chroma_key_softness: float = 0.08

const FRAME_SIZE := Vector2i(100, 140)
const COLS := 4
const ROWS := 8
const FOOT_Y := 131

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

var rng := RandomNumberGenerator.new()
var target_position := Vector2.ZERO
var is_moving := false

var _sprite: Sprite2D
var _texture: Texture2D
var _config: Dictionary = {}

var _current_anim := ANIM_IDLE
var _current_row := 5
var _current_col := 0
var _frame_accum := 0.0
var _facing_left := false
var _last_motion_dir := Vector2.RIGHT

var _turn_playing := false
var _turn_after_anim := ANIM_IDLE
var _turn_after_flip := false

var _move_dir := Vector2.ZERO
var _cur_speed := 0.0
var _step_phase := 0.0
var _idle_phase := 0.0
var _stuck_time := 0.0

var _wander_timer: Timer
var _bounce_tween: Tween


func _ready() -> void:
	rng.randomize()
	target_position = position

	_setup_sprite()
	_load_spritesheet()
	_setup_collision()
	_setup_click_area()

	_wander_timer = Timer.new()
	_wander_timer.one_shot = true
	add_child(_wander_timer)
	_wander_timer.timeout.connect(_on_wander_tick)

	set_process(true)
	set_physics_process(true)

	_set_anim(ANIM_IDLE, false, true)
	_schedule_wander()


# ------------------------------------------------------------
# Asset loading
# ------------------------------------------------------------

func _breed_dir() -> String:
	if breed == "orange":
		return "orange_tabby"
	return breed


func _texture_path() -> String:
	return "res://assets/art/cats/%s/spritesheet.png" % _breed_dir()


func _config_path() -> String:
	return "res://assets/art/cats/%s/spritesheet.qc.json" % _breed_dir()


func _load_spritesheet() -> void:
	var path := _texture_path()
	if ResourceLoader.exists(path):
		_texture = load(path)
		_sprite.texture = _texture
	else:
		push_error("CatSprite: spritesheet not found: %s" % path)

	var cfg_path := _config_path()
	if ResourceLoader.exists(cfg_path):
		var text := FileAccess.get_file_as_string(cfg_path)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			# Convert QC JSON to CatSprite format
			if parsed.has("layout") and parsed.has("frames"):
				var row_names: Array = parsed["layout"]["row_names"]
				var qc_frames: Array = parsed["frames"]
				var animations := {}
				for f in qc_frames:
					var anim_name: String = row_names[f["row"]]
					var b = f["bbox"]
					if not animations.has(anim_name):
						animations[anim_name] = {"frames": []}
					animations[anim_name]["frames"].append({
						"region": [b["x"], b["y"], b["width"], b["height"]]
					})
				_config = {"animations": animations}
			else:
				_config = parsed
		else:
			push_warning("CatSprite: invalid JSON config: %s" % cfg_path)

	_apply_frame(ANIM_IDLE, 0)


func _setup_sprite() -> void:
	for c in get_children():
		if c is Sprite2D:
			c.queue_free()

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.region_enabled = true
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)

	if chroma_key_enabled:
		_sprite.material = _make_chroma_key_material()


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


# ------------------------------------------------------------
# Collision / click
# ------------------------------------------------------------

func _setup_collision() -> void:
	collision_layer = 2
	collision_mask = 2

	var body_shape := CollisionShape2D.new()
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
	add_child(area)

	var click_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 42.0
	click_shape.shape = circle
	area.add_child(click_shape)

	area.input_event.connect(_on_input_event)


# ------------------------------------------------------------
# Animation
# ------------------------------------------------------------

func _process(delta: float) -> void:
	_idle_phase += delta
	_step_phase += delta * maxf(_cur_speed / maxf(move_speed, 1.0), 0.25) * 8.0

	_advance_animation(delta)
	_apply_visual_motion(delta)

	if shadow_enabled:
		queue_redraw()


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
			else:
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
	_current_row = ANIM_ROWS.get(anim_name, 5)
	_current_col = 0
	_frame_accum = 0.0
	_facing_left = flip_left
	_sprite.flip_h = _facing_left
	_apply_frame(_current_anim, _current_col)


func _apply_frame(anim_name: String, col: int) -> void:
	if _sprite == null:
		return

	var row: int = ANIM_ROWS.get(anim_name, 5)
	var region := Rect2i(col * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)

	# 如果 JSON 里有 region，则优先使用 JSON；否则使用标准 100×140 网格。
	var json_region := _get_region_from_config(anim_name, col)
	if json_region.size() == 4:
		region = Rect2i(
			int(json_region[0]),
			int(json_region[1]),
			int(json_region[2]),
			int(json_region[3])
		)

	_sprite.region_rect = region


func _get_region_from_config(anim_name: String, col: int) -> Array:
	if _config.is_empty():
		return []
	if not _config.has("animations"):
		return []
	var animations: Dictionary = _config["animations"]
	if not animations.has(anim_name):
		return []
	var anim: Dictionary = animations[anim_name]
	var frames: Array = anim.get("frames", [])
	if col < 0 or col >= frames.size():
		return []
	var frame: Dictionary = frames[col]
	return frame.get("region", [])


func _apply_visual_motion(delta: float) -> void:
	if _sprite == null:
		return

	var depth_scale := 1.0
	if depth_scale_enabled:
		var t := clampf((position.y - wander_y_min) / maxf(wander_y_max - wander_y_min, 1.0), 0.0, 1.0)
		depth_scale = lerpf(0.82, 1.15, t)

	var breed_scale := 1.0
	match breed:
		"orange", "orange_tabby": breed_scale = 0.82
		"british": breed_scale = 0.82
		_: breed_scale = 1.0

	var base_scale := sprite_scale * depth_scale * breed_scale

	if is_moving:
		var speed_ratio := clampf(_cur_speed / maxf(move_speed, 1.0), 0.0, 1.0)
		var cycle := sin(_step_phase)
		var bounce_y := -absf(cycle) * 2.0 * speed_ratio
		var squash := (absf(cycle) - 0.5) * 0.018 * speed_ratio
		_sprite.rotation = lerpf(_sprite.rotation, cycle * 0.02 * speed_ratio, delta * 10.0)
		_sprite.scale = Vector2(base_scale * (1.0 - squash), base_scale * (1.0 + squash))
		_sprite.position.y = -((FRAME_SIZE.y * 0.5) - FOOT_Y) * (base_scale - 1.0) + bounce_y
	else:
		var breath := 1.0 + sin(_idle_phase * 1.8) * 0.012
		_sprite.rotation = lerpf(_sprite.rotation, 0.0, delta * 8.0)
		_sprite.scale = Vector2(base_scale, base_scale * breath)
		_sprite.position.y = -((FRAME_SIZE.y * 0.5) - FOOT_Y) * (base_scale * breath - 1.0)


func _start_turn_anim(move_turn: bool, after_anim: String, after_flip: bool) -> void:
	_turn_playing = true
	_turn_after_anim = after_anim
	_turn_after_flip = after_flip
	_set_anim(ANIM_MOVE_TURN if move_turn else ANIM_TURN, after_flip, true)


func _select_anim_from_direction(dir: Vector2) -> Dictionary:
	if dir.length() < 0.001:
		return {"anim": ANIM_IDLE, "flip": _facing_left}

	var deg := rad_to_deg(dir.angle())

	# Godot 2D: right=0, down=90, up=-90.
	if deg >= -22.5 and deg < 22.5:
		return {"anim": ANIM_WALK_RIGHT, "flip": false}
	elif deg >= 22.5 and deg < 67.5:
		return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": false}
	elif deg >= 67.5 and deg < 112.5:
		return {"anim": ANIM_WALK_DOWN, "flip": false}
	elif deg >= 112.5 and deg < 157.5:
		return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": true}
	elif deg >= 157.5 or deg < -157.5:
		return {"anim": ANIM_WALK_RIGHT, "flip": true}
	elif deg >= -157.5 and deg < -112.5:
		return {"anim": ANIM_WALK_UP_RIGHT, "flip": true}
	elif deg >= -112.5 and deg < -67.5:
		return {"anim": ANIM_WALK_UP, "flip": false}
	else:
		return {"anim": ANIM_WALK_UP_RIGHT, "flip": false}


# ------------------------------------------------------------
# Movement / wander
# ------------------------------------------------------------

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

	if _move_dir == Vector2.ZERO:
		_move_dir = desired_dir
	else:
		_move_dir = _move_dir.lerp(desired_dir, delta * 4.0).normalized()

	var target_speed := move_speed
	if dist < 90.0:
		target_speed = move_speed * maxf(dist / 90.0, 0.35)

	var target_velocity := _move_dir * target_speed
	velocity = velocity.lerp(target_velocity, delta * acceleration)
	_cur_speed = velocity.length()

	var before := position
	move_and_slide()
	var moved := position.distance_to(before)

	if moved > 0.01:
		_last_motion_dir = (position - before).normalized()
		var selected := _select_anim_from_direction(_last_motion_dir)
		var next_anim: String = selected["anim"]
		var next_flip: bool = selected["flip"]

		if next_flip != _facing_left and not _turn_playing:
			_start_turn_anim(true, next_anim, next_flip)
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
		if child == self:
			continue
		if not (child is Node2D):
			continue

		var d := position.distance_to(child.position)
		if d > 0.1 and d < 160.0:
			var push: Vector2 = (position - child.position).normalized()
			var strength := (1.0 - d / 160.0) * 1.8
			separation += push * strength
			count += 1

	if count == 0:
		return desired_dir

	separation /= count

	# 不允许被 separation 往后推，只保留侧向绕行分量。
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
	# 小概率原地转身/张望。
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
	if _wander_timer == null:
		return

	var r := rng.randf()
	var pause := 0.0
	if r < 0.45:
		pause = rng.randf_range(0.4, 1.2)
	elif r < 0.85:
		pause = rng.randf_range(1.5, 3.5)
	else:
		pause = rng.randf_range(4.0, 7.0)

	_wander_timer.start(pause)


func _clamp_to_wander_area() -> void:
	var x := clampf(position.x, wander_x_min, wander_x_max)
	var y := clampf(position.y, wander_y_min, wander_y_max)
	if x != position.x or y != position.y:
		position = Vector2(x, y)


# ------------------------------------------------------------
# Public helpers
# ------------------------------------------------------------

func face_direction(dx: float) -> void:
	_face_to(dx)


func _face_to(dx: float) -> void:
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
	_load_spritesheet()
	_set_anim(ANIM_IDLE, false, true)


# ------------------------------------------------------------
# Click feedback
# ------------------------------------------------------------

func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_click_feedback()
		cat_clicked.emit(cat_data)


func _play_click_feedback() -> void:
	var j := get_node_or_null("/root/Juice")
	if j:
		j.tap()

	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()

	_bounce_tween = create_tween()
	_bounce_tween.tween_property(_sprite, "position:y", _sprite.position.y - 16.0, 0.10).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_sprite, "position:y", _sprite.position.y, 0.16).set_ease(Tween.EASE_IN)

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


# ------------------------------------------------------------
# Shadow
# ------------------------------------------------------------

func _draw() -> void:
	if not shadow_enabled:
		return

	var bounce_ratio := 1.0
	if _sprite:
		bounce_ratio = clampf(1.0 - absf(_sprite.position.y) / 28.0 * 0.25, 0.75, 1.0)

	var shadow_color := Color(0.12, 0.14, 0.06, 0.11)
	var shadow_size := Vector2(30.0 * bounce_ratio, 7.0 * bounce_ratio)
	var shadow_y := _get_shadow_y()
	_draw_oval(Vector2(0.0, shadow_y), shadow_size, shadow_color)


func _get_shadow_y() -> float:
	if _sprite == null:
		return FOOT_Y - FRAME_SIZE.y * 0.5 + 8.0

	var foot_local_y := FOOT_Y - FRAME_SIZE.y * 0.5
	return _sprite.position.y + foot_local_y + 8.0


func _draw_oval(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 24
	for i in range(steps):
		var angle := float(i) / steps * TAU
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	draw_colored_polygon(points, color)
