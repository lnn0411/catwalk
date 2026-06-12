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
	spawned_cat_ids.clear()
	cat_container = container
	if container != null:
		# 幂等保护：容器里已存在的猫先登记，重复调用不会生成重复猫。
		# （页面生命周期下同一容器可能被多次 set，必须可安全重入）
		for child in container.get_children():
			if "cat_data" in child and child.cat_data != null:
				var cid := _get_cat_id(child.cat_data)
				if cid != "":
					spawned_cat_ids[cid] = child
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
	# wander 同款世界限界（出生点不能超出猫的活动范围）
	var min_x := 100.0
	var max_x := 1900.0
	var min_y := 116.0
	var max_y := 1016.0
	# 新猫出生在【当前镜头可视范围】内——新手孵出首猫回花园必须立刻看到它，
	# 出生在屏幕外会被当成 BUG。拿不到相机/容器时退回全图随机。
	var cam := get_viewport().get_camera_2d()
	if cam != null and cat_container != null and is_instance_valid(cat_container):
		var vp := get_viewport().get_visible_rect().size
		var center_local: Vector2 = cat_container.to_local(cam.get_screen_center_position())
		var half_w: float = vp.x * 0.5 / maxf(cam.zoom.x, 0.0001)
		var half_h: float = vp.y * 0.5 / maxf(cam.zoom.y, 0.0001)
		# 收 15% 边距：避免出生在屏幕边缘只露半个身位
		min_x = maxf(min_x, center_local.x - half_w * 0.85)
		max_x = minf(max_x, center_local.x + half_w * 0.85)
		min_y = maxf(min_y, center_local.y - half_h * 0.85)
		max_y = minf(max_y, center_local.y + half_h * 0.85)
		# 可视区与活动范围无交集（异常情况）→ 退回全图
		if min_x >= max_x:
			min_x = 100.0
			max_x = 1900.0
		if min_y >= max_y:
			min_y = 116.0
			max_y = 1016.0
	var position := Vector2.ZERO
	for i in range(10):
		position = Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_y, max_y))
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
