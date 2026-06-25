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
var feed_cooldown_active: bool = false
var pet_cooldown_active: bool = false
var play_cooldown_active: bool = false
var photo_cooldown_active: bool = false
var _locked_cat_id: String = ""  # CatCard 打开时锁住这只猫的移动
var _feed_timer: Timer
var _pet_timer: Timer
var _play_timer: Timer
var _photo_timer: Timer
var _bound_garden: Node = null
var _cat_card_layer: CanvasLayer = null
var _affection: Dictionary = {}
func _ready() -> void:
	_feed_timer = Timer.new()
	_feed_timer.name = "FeedCooldownTimer"
	_feed_timer.one_shot = true
	_feed_timer.wait_time = _get_feed_cooldown()
	_feed_timer.timeout.connect(_on_feed_cooldown_done)
	add_child(_feed_timer)

	_pet_timer = Timer.new()
	_pet_timer.name = "PetCooldownTimer"
	_pet_timer.one_shot = true
	_pet_timer.wait_time = _get_pet_cooldown()
	_pet_timer.timeout.connect(_on_pet_cooldown_done)
	add_child(_pet_timer)

	_play_timer = Timer.new()
	_play_timer.name = "PlayCooldownTimer"
	_play_timer.one_shot = true
	_play_timer.wait_time = _get_play_cooldown()
	_play_timer.timeout.connect(_on_play_cooldown_done)
	add_child(_play_timer)

	_photo_timer = Timer.new()
	_photo_timer.name = "PhotoCooldownTimer"
	_photo_timer.one_shot = true
	_photo_timer.wait_time = _get_photo_cooldown()
	_photo_timer.timeout.connect(_on_photo_cooldown_done)
	add_child(_photo_timer)

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


func is_interaction_blocked(type: String) -> bool:
	match type:
		"feed":
			return feed_cooldown_active
		"pet":
			return pet_cooldown_active
		"play":
			return play_cooldown_active
		"photo":
			return photo_cooldown_active
		_:
			return false


func start_cooldown(type: String) -> void:
	match type:
		"feed":
			feed_cooldown_active = true
			_feed_timer.start(_get_feed_cooldown())
		"pet":
			pet_cooldown_active = true
			_pet_timer.start(_get_pet_cooldown())
		"play":
			play_cooldown_active = true
			_play_timer.start(_get_play_cooldown())
		"photo":
			photo_cooldown_active = true
			_photo_timer.start(_get_photo_cooldown())
		_:
			pass
	if current_cat_card != null and is_instance_valid(current_cat_card) and current_cat_card.has_method("refresh_interaction_buttons"):
		current_cat_card.refresh_interaction_buttons()


func _on_feed_cooldown_done() -> void:
	feed_cooldown_active = false
	if current_cat_card != null and is_instance_valid(current_cat_card) and current_cat_card.has_method("refresh_interaction_buttons"):
		current_cat_card.refresh_interaction_buttons()


func _on_pet_cooldown_done() -> void:
	pet_cooldown_active = false
	if current_cat_card != null and is_instance_valid(current_cat_card) and current_cat_card.has_method("refresh_interaction_buttons"):
		current_cat_card.refresh_interaction_buttons()


func _on_play_cooldown_done() -> void:
	play_cooldown_active = false
	if current_cat_card != null and is_instance_valid(current_cat_card) and current_cat_card.has_method("refresh_interaction_buttons"):
		current_cat_card.refresh_interaction_buttons()


func _on_photo_cooldown_done() -> void:
	photo_cooldown_active = false
	if current_cat_card != null and is_instance_valid(current_cat_card) and current_cat_card.has_method("refresh_interaction_buttons"):
		current_cat_card.refresh_interaction_buttons()


func get_cooldown_remaining(type: String) -> float:
	match type:
		"feed":
			return _feed_timer.time_left if feed_cooldown_active else 0.0
		"pet":
			return _pet_timer.time_left if pet_cooldown_active else 0.0
		"play":
			return _play_timer.time_left if play_cooldown_active else 0.0
		"photo":
			return _photo_timer.time_left if photo_cooldown_active else 0.0
		_:
			return 0.0


func try_interact(cat_id: String, type: String) -> bool:
	if cat_id == "" or is_interaction_blocked(type):
		return false
	if EmotionStateMachine != null and EmotionStateMachine.is_annoyed(cat_id):
		return false

	if type in ["feed", "pet", "play", "photo"]:
		start_cooldown(type)
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


# 兼容旧 HUD 按钮冷却判定
func can_interact(_cat_id: String, type: String) -> bool:
	return not is_interaction_blocked(type)


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


static func _get_feed_cooldown() -> float:
	return DEBUG_FEED_COOLDOWN if DEBUG_FAST_COOLDOWN else RELEASE_FEED_COOLDOWN


static func _get_pet_cooldown() -> float:
	return DEBUG_FEED_COOLDOWN if DEBUG_FAST_COOLDOWN else RELEASE_PET_COOLDOWN


static func _get_play_cooldown() -> float:
	return DEBUG_PLAY_COOLDOWN if DEBUG_FAST_COOLDOWN else RELEASE_PLAY_COOLDOWN


static func _get_photo_cooldown() -> float:
	return DEBUG_FEED_COOLDOWN if DEBUG_FAST_COOLDOWN else RELEASE_PHOTO_COOLDOWN


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
