extends Node

const CAT_CARD_SCENE_PATH := "res://scenes/ui/CatCard.tscn"
const CAT_CARD_LAYER := 100
static var DEBUG_FAST_COOLDOWN := false
const RELEASE_FEED_COOLDOWN := 14400.0
const RELEASE_PET_COOLDOWN := 7200.0
const RELEASE_PLAY_COOLDOWN := 21600.0
const RELEASE_PHOTO_COOLDOWN := 3600.0
const DEBUG_FEED_COOLDOWN := 30.0
const DEBUG_PLAY_COOLDOWN := 60.0
const SAVE_PATH: String = "user://interaction.cfg"

var current_cat_card: Control = null
var _locked_cat_id: String = ""  # CatCard 打开时锁住这只猫的移动
# 每只猫各自的冷却结束时间戳（unix 秒）：
# { "cat_id": { "feed": end_ts, "pet": end_ts, "play": end_ts, "photo": end_ts } }
var _cat_cooldowns: Dictionary = {}
var _bound_garden: Node = null
var _cat_card_layer: CanvasLayer = null
var _affection: Dictionary = {}
func _ready() -> void:
	_load_cooldowns()

	_try_find_garden()
	if _bound_garden == null and UIManager != null:
		var cb := Callable(self, "_on_page_changed")
		if not UIManager.page_changed.is_connected(cb):
			UIManager.page_changed.connect(cb)


func bind_to_garden(garden_node) -> void:
	if garden_node == null or not is_instance_valid(garden_node):
		return
	if not garden_node.has_signal("cat_clicked"):
		return
	if _bound_garden == garden_node:
		return

	var cb := Callable(self, "_on_cat_clicked")
	if _bound_garden != null and is_instance_valid(_bound_garden):
		if _bound_garden.is_connected("cat_clicked", cb):
			_bound_garden.disconnect("cat_clicked", cb)

	_bound_garden = garden_node
	if not _bound_garden.is_connected("cat_clicked", cb):
		_bound_garden.connect("cat_clicked", cb)


func _on_cat_clicked(cat_id: String, screen_position: Vector2) -> void:
	_close_cat_card()

	var cat_data = _find_cat_data(cat_id)
	if cat_data == null:
		push_warning("[InteractionSystem] CatData not found for cat_id=%s" % cat_id)
		return

	var packed := load(CAT_CARD_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("[InteractionSystem] CatCard scene missing: %s" % CAT_CARD_SCENE_PATH)
		return

	var node := packed.instantiate()
	current_cat_card = node as Control
	if current_cat_card == null:
		node.queue_free()
		push_warning("[InteractionSystem] CatCard root must be Control.")
		return

	_cat_card_layer = CanvasLayer.new()
	_cat_card_layer.name = "CatCardLayer"
	_cat_card_layer.layer = CAT_CARD_LAYER

	var overlay := Control.new()
	overlay.name = "CatCardOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_on_overlay_gui_input)

	_cat_card_layer.add_child(overlay)
	overlay.add_child(current_cat_card)
	get_tree().root.add_child(_cat_card_layer)

	_set_cat_card_data(current_cat_card, cat_id, cat_data, screen_position)
	# 锁定这只猫的移动，防止弹出 CatCard 时猫跑掉
	_locked_cat_id = cat_id
	_set_cat_move_lock(cat_id, true)


func _try_find_garden() -> void:
	var root := get_tree().root if get_tree() != null else null
	if root == null:
		return
	var garden := _find_garden_in_tree(root)
	if garden != null:
		bind_to_garden(garden)


func _close_cat_card() -> void:
	# 解锁之前锁定的猫
	if _locked_cat_id != "":
		_set_cat_move_lock(_locked_cat_id, false)
		_locked_cat_id = ""
	if _cat_card_layer != null and is_instance_valid(_cat_card_layer):
		_cat_card_layer.queue_free()
	elif current_cat_card != null and is_instance_valid(current_cat_card):
		current_cat_card.queue_free()
	_cat_card_layer = null
	current_cat_card = null


# 这只猫的某个互动类型是否仍在冷却中
func is_interaction_blocked(type: String, cat_id: String) -> bool:
	return cat_cooldown_remaining(cat_id, type) > 0.0


# 开始这只猫的某个互动冷却：记录冷却结束的时间戳
func start_cooldown(type: String, cat_id: String) -> void:
	if cat_id == "":
		return
	var seconds := _get_cooldown_seconds(type)
	if seconds <= 0.0:
		return
	var per_type = _cat_cooldowns.get(cat_id, {})
	if not (per_type is Dictionary):
		per_type = {}
	per_type[type] = Time.get_unix_time_from_system() + seconds
	_cat_cooldowns[cat_id] = per_type
	_save_cooldowns()
	if current_cat_card != null and is_instance_valid(current_cat_card) and current_cat_card.has_method("refresh_interaction_buttons"):
		current_cat_card.refresh_interaction_buttons()


# 这只猫某个互动类型剩余冷却秒数；不在冷却中返回 0
func cat_cooldown_remaining(cat_id: String, type: String) -> float:
	if cat_id == "" or not _cat_cooldowns.has(cat_id):
		return 0.0
	var per_type = _cat_cooldowns[cat_id]
	if not (per_type is Dictionary) or not per_type.has(type):
		return 0.0
	var end_ts = per_type[type]
	var remaining = float(end_ts) - Time.get_unix_time_from_system()
	return remaining if remaining > 0.0 else 0.0


# 兼容旧调用方：返回当前打开的 CatCard 这只猫的剩余冷却
func get_cooldown_remaining(type: String) -> float:
	return cat_cooldown_remaining(_locked_cat_id, type)


func try_interact(cat_id: String, type: String) -> bool:
	if cat_id == "" or is_interaction_blocked(type, cat_id):
		return false
	if EmotionStateMachine != null and EmotionStateMachine.is_annoyed(cat_id):
		return false

	if type in ["feed", "pet", "play", "photo"]:
		start_cooldown(type, cat_id)
		# Accumulate affection
		var gain := _get_affection_gain(type)
		_affection[cat_id] = _affection.get(cat_id, 0) + gain
		# 更新 CatData 的 friendship 和 exp（真实数值，会被存档）
		_update_cat_stats(cat_id, type)

	if EmotionStateMachine != null:
		EmotionStateMachine.record_interaction(cat_id, type)

	if current_cat_card != null and is_instance_valid(current_cat_card) and current_cat_card.has_method("refresh_interaction_buttons"):
		current_cat_card.refresh_interaction_buttons()
	return true

# 互动后更新 CatData 的 friendship 和 exp
func _update_cat_stats(cat_id: String, type: String) -> void:
	var cat = HatchEngine.get_cat_by_id(cat_id) if HatchEngine else null
	if cat == null or not (cat is CatData):
		return
	# 好感度
	match type:
		"feed":
			cat.friendship += 1
		"pet":
			cat.friendship += 1
		"play":
			cat.friendship += 2
		"photo":
			cat.friendship += 1
	# 经验
	var exp_gain = {"feed": 50, "pet": 30, "play": 80, "photo": 20}.get(type, 20)
	cat.exp += exp_gain
	# 升级检查：每10级需要 (level * 100) 经验
	while cat.exp >= cat.level * 100:
		cat.exp -= cat.level * 100
		cat.level += 1
	# 存盘
	if SaveManager:
		SaveManager.save_all()


# 兼容旧调用方（AchievementSystem / GardenMain action buttons）
func do_interact(cat_id: String, type: String) -> int:
	return _get_affection_gain(type) if try_interact(cat_id, type) else 0


func get_affection(cat_id: String) -> int:
	return _affection.get(cat_id, 0)


# 兼容旧 HUD 按钮冷却判定（按猫判定）
func can_interact(cat_id: String, type: String) -> bool:
	return not is_interaction_blocked(type, cat_id)


static func get_cooldown_minutes(type: String) -> int:
	if DEBUG_FAST_COOLDOWN:
		return 0
	match type:
		"feed":
			return int(ceil(_get_feed_cooldown() / 60.0))
		"play":
			return int(ceil(_get_play_cooldown() / 60.0))
		"pet":
			return int(ceil(_get_pet_cooldown() / 60.0))
		"photo":
			return int(ceil(_get_photo_cooldown() / 60.0))
		_:
			return 0


# 互动类型对应的冷却秒数
func _get_cooldown_seconds(type: String) -> float:
	match type:
		"feed":
			return _get_feed_cooldown()
		"pet":
			return _get_pet_cooldown()
		"play":
			return _get_play_cooldown()
		"photo":
			return _get_photo_cooldown()
		_:
			return 0.0


static func _get_feed_cooldown() -> float:
	return DEBUG_FEED_COOLDOWN if DEBUG_FAST_COOLDOWN else RELEASE_FEED_COOLDOWN


static func _get_pet_cooldown() -> float:
	return DEBUG_FEED_COOLDOWN if DEBUG_FAST_COOLDOWN else RELEASE_PET_COOLDOWN


static func _get_play_cooldown() -> float:
	return DEBUG_PLAY_COOLDOWN if DEBUG_FAST_COOLDOWN else RELEASE_PLAY_COOLDOWN


static func _get_photo_cooldown() -> float:
	return DEBUG_FEED_COOLDOWN if DEBUG_FAST_COOLDOWN else RELEASE_PHOTO_COOLDOWN


# ── 存档：把 _cat_cooldowns 以 CSV 形式存进 ConfigFile ──
# 每只猫一行，值形如 "feed:1719300000.0,pet:1719310000.0"
func _save_cooldowns() -> void:
	var cfg := ConfigFile.new()
	for cat_id in _cat_cooldowns.keys():
		var per_type = _cat_cooldowns[cat_id]
		if not (per_type is Dictionary):
			continue
		cfg.set_value("cooldowns", cat_id, _serialize_cooldown_entry(per_type))
	cfg.save(SAVE_PATH)


func _load_cooldowns() -> void:
	_cat_cooldowns = {}
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return
	if not cfg.has_section("cooldowns"):
		return
	for cat_id in cfg.get_section_keys("cooldowns"):
		var raw = cfg.get_value("cooldowns", cat_id, "")
		var entry := _deserialize_cooldown_entry(String(raw))
		if not entry.is_empty():
			_cat_cooldowns[cat_id] = entry


func _serialize_cooldown_entry(per_type: Dictionary) -> String:
	var parts: Array[String] = []
	for type in per_type.keys():
		parts.append("%s:%s" % [String(type), str(per_type[type])])
	return ",".join(parts)


func _deserialize_cooldown_entry(raw: String) -> Dictionary:
	var result: Dictionary = {}
	if raw == "":
		return result
	for pair in raw.split(",", false):
		var kv := pair.split(":", false)
		if kv.size() != 2:
			continue
		result[kv[0]] = float(kv[1])
	return result


# 清空所有冷却与好感（测试 / 重置入口）
func reset_all() -> void:
	_cat_cooldowns.clear()
	_affection.clear()
	_save_cooldowns()


# 清除指定猫的全部冷却（看广告刷新冷却入口）
func clear_cat_cooldowns(cat_id: String) -> void:
	if cat_id == "":
		return
	if _cat_cooldowns.has(cat_id):
		_cat_cooldowns.erase(cat_id)
		_save_cooldowns()
	if current_cat_card != null and is_instance_valid(current_cat_card) and current_cat_card.has_method("refresh_interaction_buttons"):
		current_cat_card.refresh_interaction_buttons()


# 测试辅助：把某只猫某类型「上次互动时间」设为 seconds_ago 秒前
# 在「结束时间戳」模型下等价于 end = now - seconds_ago + cooldown
func _override_last_interact(cat_id: String, type: String, seconds_ago: float) -> void:
	if cat_id == "":
		return
	var per_type = _cat_cooldowns.get(cat_id, {})
	if not (per_type is Dictionary):
		per_type = {}
	per_type[type] = Time.get_unix_time_from_system() - seconds_ago + _get_cooldown_seconds(type)
	_cat_cooldowns[cat_id] = per_type


# 公开好感增益查询（兼容测试）
func get_affection_gain(type: String) -> int:
	return _get_affection_gain(type)


func _on_page_changed(page_name: String) -> void:
	if page_name == "S04_GardenMain" or _bound_garden == null or not is_instance_valid(_bound_garden):
		_try_find_garden()


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_cat_card()
	elif event is InputEventScreenTouch and event.pressed:
		_close_cat_card()


func _find_garden_in_tree(node: Node) -> Node:
	if node == null:
		return null
	if node.has_signal("cat_clicked"):
		return node
	for child in node.get_children():
		var found := _find_garden_in_tree(child)
		if found != null:
			return found
	return null


func _find_cat_data(cat_id: String):
	if HatchEngine == null:
		return null
	for cat_data in HatchEngine.get_cats():
		if cat_data != null and String(cat_data.id) == cat_id:
			return cat_data
	return null


func _set_cat_card_data(card: Control, cat_id: String, cat_data, screen_position: Vector2) -> void:
	if "cat_id" in card:
		card.cat_id = cat_id
	if "cat_data" in card:
		card.cat_data = cat_data
	if "interaction_system" in card:
		card.interaction_system = self
	if "screen_position" in card:
		card.screen_position = screen_position

	if card.has_method("setup"):
		card.setup(cat_id, cat_data, screen_position)
	elif card.has_method("set_cat_data"):
		card.set_cat_data(cat_data)


func _get_affection_gain(type: String) -> int:
	match type:
		"feed":
			return 5
		"pet":
			return 3
		"play":
			return 4
		_:
			return 0

# CatCard 打开/关闭时锁定/恢复猫咪移动
func _set_cat_move_lock(cat_id: String, locked: bool) -> void:
	if not CatSpawner:
		return
	var node = CatSpawner.get_cat_node_by_id(cat_id)
	if node != null and node.has_method("set_card_open"):
		node.set_card_open(locked)
