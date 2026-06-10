extends Node

signal cat_spawned(node)
signal cat_count_changed(count)

const CatData := preload("res://core/CatData.gd")

var cat_container: Node2D
var rng := RandomNumberGenerator.new()
var spawned_cat_ids := {}

func _ready() -> void:
	rng.randomize()
	if HatchEngine and not HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
		HatchEngine.hatch_complete.connect(_on_hatch_complete)

func set_cat_container(container) -> void:
	print("[CatSpawner] set_cat_container: %s" % [container != null])
	cat_container = container
	_restore_cats()

func _on_hatch_complete(cat_data) -> void:
	print("[CatSpawner] hatch_complete: %s, container=%s" % [cat_data.display_name if cat_data else "null", cat_container != null])
	instance_cat(cat_data)

func instance_cat(cat_data):
	if cat_data == null:
		return null

	var cat_id := _get_cat_id(cat_data)
	if cat_id != "" and spawned_cat_ids.has(cat_id):
		_emit_cat_count()
		return spawned_cat_ids[cat_id]

	if cat_container == null:
		_emit_cat_count()
		return null

	if not ResourceLoader.exists("res://scenes/CatSprite.tscn"):
		_emit_cat_count()
		return null

	var packed_scene := load("res://scenes/CatSprite.tscn")
	if packed_scene == null:
		_emit_cat_count()
		return null

	var cat_node = packed_scene.instantiate()
	cat_node.cat_data = cat_data
	cat_node.breed = cat_data.species
	cat_node.position = _pick_spawn_position()
	print("[CatSpawner] instance_cat: breed=%s pos=(%.0f,%.0f)" % [cat_data.species, cat_node.position.x, cat_node.position.y])
	cat_node.modulate.a = 0.0
	cat_container.add_child(cat_node)

	if cat_node.has_signal("cat_clicked"):
		cat_node.cat_clicked.connect(_on_cat_clicked)

	var tween := create_tween()
	tween.tween_property(cat_node, "modulate:a", 1.0, 0.5)

	if cat_id != "":
		spawned_cat_ids[cat_id] = cat_node

	cat_spawned.emit(cat_node)
	_emit_cat_count()
	return cat_node

func _pick_spawn_position() -> Vector2:
	var position := Vector2.ZERO
	for i in range(10):
		position = Vector2(rng.randf_range(100.0, 1900.0), rng.randf_range(116.0, 1016.0))
		if not _is_position_occupied(position):
			return position
	return position

func _is_position_occupied(pos: Vector2) -> bool:
	if cat_container == null:
		return false

	for child in cat_container.get_children():
		if child is Node2D and child.position.distance_to(pos) < 80.0:
			return true
	return false

func _on_cat_clicked(cat_data) -> void:
	if not ResourceLoader.exists("res://scenes/CatInfoPopup.tscn"):
		return

	var packed_scene := load("res://scenes/CatInfoPopup.tscn")
	if packed_scene == null:
		return

	var popup = packed_scene.instantiate()
	popup.cat_data = cat_data
	get_tree().root.add_child(popup)
	if popup.has_signal("closed"):
		popup.closed.connect(popup.queue_free)

func _restore_cats() -> void:
	if HatchEngine == null:
		return

	for cat_data in HatchEngine.get_cats():
		instance_cat(cat_data)

func _emit_cat_count() -> void:
	if HatchEngine:
		cat_count_changed.emit(HatchEngine.get_cats().size())
	else:
		cat_count_changed.emit(0)

func _get_cat_id(cat_data) -> String:
	if cat_data == null:
		return ""
	return String(cat_data.id)
