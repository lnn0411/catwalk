extends Node

signal cat_spawned(node)
signal cat_count_changed(count)

const CatData := preload("res://core/CatData.gd")
const MAX_VISIBLE_CATS := 12

# 按花园背景图索引定义猫咪安全走行区（基于视觉分析）
# 格式: { bg_idx: {"x_min", "x_max", "y_min", "y_max"} }
# 索引对应 garden_01~04.png
const GARDEN_WANDER_ZONES := {
	1: { "x_min": 150,  "x_max": 2900, "y_min": 550,  "y_max": 980  },  # 意式庄园
	2: { "x_min": 150,  "x_max": 2800, "y_min": 580,  "y_max": 1024 },  # 英伦花园
	3: { "x_min": 280,  "x_max": 2850, "y_min": 720,  "y_max": 1000 },  # 小镇广场
	4: { "x_min": 180,  "x_max": 2850, "y_min": 480,  "y_max": 1024 },  # 地中海巷弄
}

var _current_zone: Dictionary = GARDEN_WANDER_ZONES[1].duplicate()

class RestingCatPlaceholder:
	extends Node2D
	var cat_data: Variant = null

var cat_container: Node2D
var rng := RandomNumberGenerator.new()
var spawned_cat_ids: Dictionary = {}
var _restoring := false
func _ready() -> void:
	rng.randomize()
	if HatchEngine and not HatchEngine.hatch_complete.is_connected(_on_hatch_complete):
		HatchEngine.hatch_complete.connect(_on_hatch_complete)

# 切换花园背景时同步更新走行区，影响新猫出生和现有猫游荡
func set_wander_zone(bg_index: int) -> void:
	var zone: Dictionary = GARDEN_WANDER_ZONES.get(bg_index, GARDEN_WANDER_ZONES[1])
	_current_zone = zone.duplicate()
	# 同步到场上所有猫的游荡范围
	for child in cat_container.get_children() if cat_container else []:
		if child is Node2D and "cat_data" in child and child.has_method("set_wander_bounds"):
			child.set_wander_bounds(
				float(_current_zone["x_min"]),
				float(_current_zone["x_max"]),
				float(_current_zone["y_min"]),
				float(_current_zone["y_max"])
			)

func set_cat_container(container) -> void:
	print("[CatSpawner] set_cat_container: %s id=%s _restoring=%s" % [container != null, container.get_instance_id() if container else -1, _restoring])
	if _restoring:
		print("[CatSpawner]   └─ 跳过（正在恢复中，防递归）")
		return
	_restoring = true
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
			if child.has_meta("resting_cat_id"):
				continue
			if "cat_data" in child and child.cat_data != null:
				var cid := _get_cat_id(child.cat_data)
				if cid != "":
					spawned_cat_ids[cid] = child
					child.modulate.a = 1.0  # 在场的猫绝不允许隐形
		_restore_cats()
	if HatchEngine:
		print("[CatSpawner] 同步完成: 引擎猫数=%d 场上猫数=%d" % [HatchEngine.get_cats().size(), spawned_cat_ids.size()])
	_restoring = false

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
	# 同步走行区
	if cat_node.has_method("set_wander_bounds"):
		cat_node.set_wander_bounds(
			float(_current_zone.get("x_min", 350.0)),
			float(_current_zone.get("x_max", 1700.0)),
			float(_current_zone.get("y_min", 380.0)),
			float(_current_zone.get("y_max", 640.0))
		)
	cat_node.modulate.a = 0.0
	cat_container.add_child(cat_node)

	if cat_node.has_signal("cat_clicked"):
		cat_node.cat_clicked.connect(_on_cat_clicked)

	var tween := create_tween()
	tween.tween_property(cat_node, "modulate:a", 1.0, 0.5)

	if cat_id != "":
		spawned_cat_ids[cat_id] = cat_node

	print("[CatSpawner] instance_cat DONE: breed=%s spawned_count=%d pos=(%.0f,%.0f)" % [cat_data.species, spawned_cat_ids.size(), cat_node.position.x, cat_node.position.y])
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
	var start_y: float = clampf(target.y + rng.randf_range(-50.0, 50.0),
		float(_current_zone.get("y_min", 380.0)),
		float(_current_zone.get("y_max", 640.0)))
	cat_node.position = Vector2(start_x, start_y)
	cat_node.target_position = target
	cat_node.is_moving = true
	# 朝向走 face_direction（翻 sprite），不能设根节点负 scale——
	# CharacterBody2D 负缩放会导致物理变换异常（猫移动中漂移/消失）
	if cat_node.has_method("face_direction"):
		cat_node.face_direction(target.x - start_x)

func _pick_spawn_position(in_view: bool = true) -> Vector2:
	# 走行区同款限界（出生点不能超出猫的活动范围）
	var min_x := float(_current_zone.get("x_min", 350.0))
	var max_x := float(_current_zone.get("x_max", 1700.0))
	var min_y := float(_current_zone.get("y_min", 380.0))
	var max_y := float(_current_zone.get("y_max", 640.0))
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
				min_x = float(_current_zone.get("x_min", 350.0))
				max_x = float(_current_zone.get("x_max", 1700.0))
			if min_y >= max_y:
				min_y = float(_current_zone.get("y_min", 380.0))
				max_y = float(_current_zone.get("y_max", 640.0))
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
	pass

func _restore_cats() -> void:
	if HatchEngine == null:
		return

	var cats: Array = HatchEngine.get_cats()
	cats.sort_custom(_compare_cats_for_restore)
	var visible_cats: Array = cats.slice(0, MAX_VISIBLE_CATS)
	var resting_cats: Array = cats.slice(MAX_VISIBLE_CATS)

	print("[CatSpawner] _restore_cats: 引擎猫数=%d visible=%d resting=%d spawned_has=%s" % [cats.size(), visible_cats.size(), resting_cats.size(), spawned_cat_ids.keys()])
	for cat_data in visible_cats:
		var cat_id := _get_cat_id(cat_data)
		print("[CatSpawner] _restore_cats: cat=%s id=%s" % [cat_data.display_name if cat_data else "null", cat_id])
		instance_cat(cat_data, false, true)
	for cat_data in resting_cats:
		var cat_id := _get_cat_id(cat_data)
		print("[CatSpawner] _restore_cats: resting cat=%s id=%s" % [cat_data.display_name if cat_data else "null", cat_id])
		_instance_resting_placeholder(cat_data)
	print("[CatSpawner] _restore_cats DONE: spawned=%d" % spawned_cat_ids.size())
	# 立即打印每只猫的状态
	if cat_container and is_instance_valid(cat_container):
		for child in cat_container.get_children():
			if child is Node2D and "cat_data" in child:
				print("  猫: pos=(%.0f,%.0f) alpha=%.2f name=%s" % [child.position.x, child.position.y, child.modulate.a, child.name])
	# 打印相机位置（尝试多种方式获取）
	var cam := get_viewport().get_camera_2d() if get_viewport() else null
	if cam:
		print("  相机A: pos=(%.0f,%.0f) zoom=(%.2f,%.2f)" % [cam.position.x, cam.position.y, cam.zoom.x, cam.zoom.y])
	else:
		print("  相机A: 无")
	# 检查猫是否在场景树中
	if cat_container and is_instance_valid(cat_container):
		print("  容器: in_tree=%s visible=%s pos=(%.0f,%.0f)" % [cat_container.is_inside_tree(), cat_container.visible, cat_container.position.x, cat_container.position.y])
		# 检查容器父链
		var p = cat_container.get_parent()
		while p:
			print("  父链: %s in_tree=%s visible=%s" % [p.name, p.is_inside_tree(), p.visible])
			p = p.get_parent()
			if p and p.name == "GardenViewport":
				print("  ∴ 最顶层: SubViewport size=%s transparent_bg=%s" % [str(p.size), p.transparent_bg])
				break
	# 延迟3秒再查一次，看是否被其他系统移除
	var t := get_tree().create_timer(3.0)
	await t.timeout
	print("[CatSpawner] DELAYED_CHECK 3s后: spawned=%d container子节点=%d" % [spawned_cat_ids.size(), cat_container.get_child_count() if cat_container and is_instance_valid(cat_container) else -1])

func _emit_cat_count() -> void:
	if HatchEngine:
		cat_count_changed.emit(HatchEngine.get_cats().size())
	else:
		cat_count_changed.emit(0)

func _get_cat_id(cat_data) -> String:
	if cat_data == null:
		return ""
	if typeof(cat_data) == TYPE_DICTIONARY:
		return String(cat_data.get("id", ""))
	return String(cat_data.id)

func _get_cat_created_at(cat_data: Variant) -> float:
	if cat_data == null:
		return 0.0
	if typeof(cat_data) == TYPE_DICTIONARY:
		return float(cat_data.get("created_at", 0.0))
	return float(cat_data.created_at)

func _get_cat_hatch_index(cat_data: Variant) -> int:
	if cat_data == null:
		return 0
	if typeof(cat_data) == TYPE_DICTIONARY:
		return int(cat_data.get("hatch_index", 0))
	return int(cat_data.hatch_index)

func _compare_cats_for_restore(a: Variant, b: Variant) -> bool:
	var created_a: float = _get_cat_created_at(a)
	var created_b: float = _get_cat_created_at(b)
	if not is_equal_approx(created_a, created_b):
		return created_a > created_b

	var hatch_a: int = _get_cat_hatch_index(a)
	var hatch_b: int = _get_cat_hatch_index(b)
	if hatch_a != hatch_b:
		return hatch_a > hatch_b

	return _get_cat_id(a) > _get_cat_id(b)

func _instance_resting_placeholder(cat_data: Variant) -> Node2D:
	if cat_data == null or cat_container == null:
		return null

	var cat_id: String = _get_cat_id(cat_data)
	if cat_id == "":
		return null

	var existing: Node2D = _get_resting_placeholder(cat_id)
	if existing != null:
		existing.set("cat_data", cat_data)
		existing.set_meta("resting_cat_data", cat_data)
		return existing

	var placeholder: RestingCatPlaceholder = RestingCatPlaceholder.new()
	placeholder.name = "RestingCat_%s" % cat_id
	placeholder.cat_data = cat_data
	placeholder.set_meta("resting_cat_id", cat_id)
	placeholder.set_meta("resting_cat_data", cat_data)
	placeholder.visible = false
	cat_container.add_child(placeholder)
	return placeholder

func _get_resting_placeholder(cat_id: String) -> Node2D:
	if cat_container == null:
		return null

	for child in cat_container.get_children():
		if child is Node2D and child.has_meta("resting_cat_id") and String(child.get_meta("resting_cat_id")) == cat_id:
			if not child.is_queued_for_deletion():
				return child
	return null

func _remove_resting_placeholder(cat_id: String) -> void:
	var placeholder: Node2D = _get_resting_placeholder(cat_id)
	if placeholder != null:
		placeholder.queue_free()

func _swap_resting_cat(resting_cat_data: Variant, outgoing_cat_data: Variant = null) -> Variant:
	var resting_cat_id: String = _get_cat_id(resting_cat_data)
	if resting_cat_id == "":
		return null

	if outgoing_cat_data == null:
		for raw_spawned_cat_id in spawned_cat_ids.keys():
			var spawned_cat_id: String = String(raw_spawned_cat_id)
			if spawned_cat_id != resting_cat_id:
				outgoing_cat_data = spawned_cat_ids[spawned_cat_id].cat_data if is_instance_valid(spawned_cat_ids[spawned_cat_id]) and "cat_data" in spawned_cat_ids[spawned_cat_id] else null
				break

	var outgoing_cat_id: String = _get_cat_id(outgoing_cat_data)
	if outgoing_cat_id != "" and spawned_cat_ids.has(outgoing_cat_id):
		var outgoing_node: Variant = spawned_cat_ids[outgoing_cat_id]
		if is_instance_valid(outgoing_node) and not outgoing_node.is_queued_for_deletion():
			spawned_cat_ids.erase(outgoing_cat_id)
			outgoing_node.queue_free()
			_instance_resting_placeholder(outgoing_cat_data)

	_remove_resting_placeholder(resting_cat_id)
	var cat_node: Variant = instance_cat(resting_cat_data, false, true)
	_emit_cat_count()
	return cat_node
