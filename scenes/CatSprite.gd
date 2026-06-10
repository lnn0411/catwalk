extends CharacterBody2D

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

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)
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

	_schedule_wander()

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
	if target_position.x < position.x:
		scale.x = -1.0
	else:
		scale.x = 1.0

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

func _on_input_event(viewport, event, shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cat_clicked.emit(cat_data)
