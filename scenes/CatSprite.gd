extends CharacterBody2D

signal cat_clicked(cat_data)

var cat_data
@export var script_path: String = ""
@export var move_speed: float = 80.0

var rng: RandomNumberGenerator
var timer: Timer
var target_position: Vector2
var is_moving: bool = false

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
	target_position = Vector2(rng.randf_range(100.0, 1900.0), rng.randf_range(500.0, 1400.0))
	is_moving = true
	if target_position.x < position.x:
		scale.x = -1.0
	else:
		scale.x = 1.0

func _physics_process(delta: float) -> void:
	if is_moving:
		var direction := (target_position - position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		if position.distance_to(target_position) < 10.0:
			is_moving = false
			velocity = Vector2.ZERO
			_schedule_wander()

func _on_input_event(viewport, event, shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cat_clicked.emit(cat_data)
