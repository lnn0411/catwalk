extends CharacterBody2D

signal cat_clicked(cat_data)

var cat_data
@export var script_path: String = ""
@export var move_speed: float = 50.0

var rng: RandomNumberGenerator
var timer: Timer
var target_position: Vector2
var is_moving: bool = false
var _time: float = 0.0
var _is_walking: bool = false
var leg_swing_offset: float = 0.0

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()

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

	_load_visual()

	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_wander_tick)

	_schedule_wander()

func _load_visual() -> void:
	if script_path.is_empty():
		return

	var visual_script = load(script_path)
	var visual_node := Node2D.new()
	visual_node.set_script(visual_script)
	visual_node.name = "Visual"
	add_child(visual_node)

func _schedule_wander() -> void:
	timer.start(rng.randf_range(3.0, 6.0))

func _on_wander_tick() -> void:
	var wander_distance := rng.randf_range(100.0, 300.0)
	var wander_angle := rng.randf_range(0.0, TAU)
	var offset := Vector2(cos(wander_angle), sin(wander_angle)) * wander_distance
	target_position = position + offset
	target_position.x = clampf(target_position.x, 100.0, 1900.0)
	target_position.y = clampf(target_position.y, 116.0, 1016.0)
	is_moving = true
	_is_walking = true
	if target_position.x < position.x:
		scale.x = -1.0
	else:
		scale.x = 1.0

func _process(delta: float) -> void:
	_time += delta
	_update_leg_animation()
	queue_redraw()
	var visual := get_node_or_null("Visual")
	if visual:
		visual.queue_redraw()

func _update_leg_animation() -> void:
	if _is_walking:
		leg_swing_offset = sin(_time * 8.0) * 6.0
	else:
		leg_swing_offset = lerp(leg_swing_offset, 0.0, 0.15)

func _physics_process(delta: float) -> void:
	if is_moving:
		var direction := (target_position - position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		if position.distance_to(target_position) < 10.0:
			is_moving = false
			_is_walking = false
			velocity = Vector2.ZERO
			_schedule_wander()

func _on_input_event(viewport, event, shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cat_clicked.emit(cat_data)
