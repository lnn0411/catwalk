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
	print("[CatSpawner] set_cat_container: %s id=%s" % [container != null, container.get_instance_id() if container else -1])
	spawned_cat_ids.clear()
	cat_container = container
	if container != null:
		# 幂等保护：容器里已存在的猫先登记，重复调用不会生成重复猫。
		# （页面生命周期下同一容器可能被多次 set，必须可安全重入）
		for child in container.get_children():
			# 跳过"将死"节点（queue_free 延迟到帧末，此刻它还是子节点）——
			# 登记它会在节点死亡后留下死引用，导致该猫永久无法再生成。
			if child.is_queued_for_deletion():
				continue
			if "cat_data" in child and child.cat_data != null:
				var cid := _get_cat_id(child.cat_data)
				if cid != "":
					spawned_cat_ids[cid] = child
					child.modulate.a = 1.0  # 在场的猫绝不允许隐形
		_restore_cats()
		if HatchEngine:
			print("[CatSpawner] 同步完成: 引擎猫数=%d 场上猫数=%d" % [HatchEngine.get_cats().size(), spawned_cat_ids.size()])

func _on_hatch_complete(cat_data) -> void:
	print("[CatSpawner] hatch_complete: %s, container=%s id=%s" % [cat_data.display_name if cat_data else "null", cat_container != null, cat_container.get_instance_id() if cat_container else -1])
	# 新孵化的猫走入场模式：从镜头边缘走进花园（不凭空出现）
	instance_cat(cat_data, true)

func instance_cat(cat_data, entrance: bool = false, in_view: bool = true):
	if cat_data == null:
		return null

	var cat_id := _get_cat_id(cat_data)
	if cat_id != "" and spawned_cat_ids.has(cat_id):
		var existing = spawned_cat_ids[cat_id]
		# 关键修复：登记表可能残留"死引用"（节点已随旧容器/Reset 被 free，
		# 但 key 还占着位）→ 该猫永远不会再生成 → 拖遍世界也找不到。
		# 命中时必须校验引用有效性：活的直接复用；死的清掉、继续往下重新生成。
		if is_instance_valid(existing) and not existing.is_queued_for_deletion():
			existing.modulate.a = 1.0  # 顺手兜底：在场的猫绝不允许隐形
			_emit_cat_count()
			return existing
		spawned_cat_ids.erase(cat_id)

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
	cat_node.position = _pick_spawn_position(in_view)
	if entrance:
		_setup_entrance(cat_node)
	print("[CatSpawner] instance_cat: breed=%s pos=(%.0f,%.0f) entrance=%s" % [cat_data.species, cat_node.position.x, cat_node.position.y, entrance])
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

# 当前镜头可视范围（cat_container 本地坐标）。无相机/容器时返回零 Rect。
func _camera_view_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null or cat_container == null or not is_instance_valid(cat_container):
		return Rect2()
	var vp := get_viewport().get_visible_rect().size
	var center_local: Vector2 = cat_container.to_local(cam.get_screen_center_position())
	var half := Vector2(
		vp.x * 0.5 / maxf(cam.zoom.x, 0.0001),
		vp.y * 0.5 / maxf(cam.zoom.y, 0.0001)
	)
	return Rect2(center_local - half, half * 2.0)

# 入场模式：起点在镜头左/右边缘外一个身位，目标=镜头内出生点，走进来。
# 让"新猫出现"成为一段可见的入场，而不是凭空冒出（解决"呆"+覆盖同步间隙感知）。
func _setup_entrance(cat_node) -> void:
	var view := _camera_view_rect()
	if view.size == Vector2.ZERO:
		return  # 拿不到相机 → 保持普通出生
	var target: Vector2 = cat_node.position  # _pick_spawn_position 已选好镜头内目标
	var from_left: bool = rng.randf() < 0.5
	var start_x: float = (view.position.x - 90.0) if from_left else (view.end.x + 90.0)
	var start_y: float = clampf(target.y + rng.randf_range(-50.0, 50.0), 380.0, 640.0) # 核心修复：入场限制在地面草坪，防飞天
	cat_node.position = Vector2(start_x, start_y)
	cat_node.target_position = target
	cat_node.is_moving = true
	# 朝向走 face_direction（翻 sprite），不能设根节点负 scale——
	# CharacterBody2D 负缩放会导致物理变换异常（猫移动中漂移/消失）
	if cat_node.has_method("face_direction"):
		cat_node.face_direction(target.x - start_x)

func _pick_spawn_position(in_view: bool = true) -> Vector2:
	# wander 同款世界限界（出生点不能超出猫的活动范围）
	var min_x := 350.0
	var max_x := 1700.0
	var min_y := 380.0   # 核心修复：出生限制在地面草坪，防飞天
	var max_y := 640.0  # 核心修复：出生限制在地面草坪，防飞天
	# in_view=true：出生在【当前镜头可视范围】内（新孵化猫的入场目标/保底首只）。
	# in_view=false：全花园随机散布（重启恢复的猫——它们一直住在这里，
	# 不该全挤在首屏，玩家拖动镜头逐渐发现才自然）。
	if in_view:
		var view := _camera_view_rect()
		if view.size != Vector2.ZERO:
			# 收 15% 边距：避免出生在屏幕边缘只露半个身位
			var inset := view.grow_individual(-view.size.x * 0.15, -view.size.y * 0.15, -view.size.x * 0.15, -view.size.y * 0.15)
			min_x = maxf(min_x, inset.position.x)
			max_x = minf(max_x, inset.end.x)
			min_y = maxf(min_y, inset.position.y)
			max_y = minf(max_y, inset.end.y)
			# 可视区与活动范围无交集（异常情况）→ 退回全图
			if min_x >= max_x:
				min_x = 350.0
				max_x = 1700.0
			if min_y >= max_y:
				min_y = 380.0
				max_y = 640.0
	var position := Vector2.ZERO
	if not in_view:
		# 刻意避开镜头区：恢复的猫要"拖动才发现"，不赌随机概率。
		# （可视区约占世界一半，纯随机时猫少容易恰好全落在首屏）
		var view := _camera_view_rect()
		if view.size != Vector2.ZERO:
			for i in range(12):
				position = Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_y, max_y))
				if not view.has_point(position) and not _is_position_occupied(position):
					return position
			# 12 次都没找到镜头外空位（异常）→ 落回普通随机
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

# 查询某只猫的场上节点（不在场/死引用返回 null）
func get_cat_node(cat_data):
	if cat_data == null:
		return null
	var cat_id := _get_cat_id(cat_data)
	if cat_id == "" or not spawned_cat_ids.has(cat_id):
		return null
	var node = spawned_cat_ids[cat_id]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		spawned_cat_ids.erase(cat_id)
		return null
	return node

# 查询某只猫的位置（返回【相机同坐标系=garden_layer 坐标】，猫不在场返回 Vector2.ZERO）。
# 注意：不要用 to_global()——那是含页面/CanvasLayer 偏移的全局坐标，
# 直接赋给 _camera.position 会错位。容器是 garden_layer 直接子节点且无旋转缩放，
# 猫局部坐标 + 容器偏移 即相机坐标系。
func get_cat_world_position(cat_data) -> Vector2:
	var node = get_cat_node(cat_data)
	if node == null:
		return Vector2.ZERO
	if cat_container and is_instance_valid(cat_container):
		return node.position + cat_container.position
	return Vector2.ZERO

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

	# T4-14b: 用 CatScreenManager 筛选可见猫
	var visible_ids: Array = []
	if CatScreenManager:
		visible_ids = CatScreenManager.get_visible_cats()

	var first := true
	for cat_data in HatchEngine.get_cats():
		var cat_id := _get_cat_id(cat_data)
		if visible_ids.size() > 0 and not visible_ids.has(cat_id):
			# 不在可见列表 → 移除已存在的节点
			if spawned_cat_ids.has(cat_id):
				var old = spawned_cat_ids[cat_id]
				if is_instance_valid(old):
					old.queue_free()
				spawned_cat_ids.erase(cat_id)
			continue
		var was_new: bool = not spawned_cat_ids.has(cat_id)
		instance_cat(cat_data, false, first)
		if was_new:
			first = false

func _emit_cat_count() -> void:
	if HatchEngine:
		cat_count_changed.emit(HatchEngine.get_cats().size())
	else:
		cat_count_changed.emit(0)

func _get_cat_id(cat_data) -> String:
	if cat_data == null:
		return ""
	return String(cat_data.id)
