extends Node

signal state_changed(cat_id: String, old_state: int, new_state: int)
signal annoyed_entered(cat_id: String)
signal annoyed_exited(cat_id: String)

enum EmotionState { IDLE, COUNTING, ANNOYED, RECOVERY }

# 总案裁决 A1：阈值 4→5——四键一轮（4 次）安全，连刷两轮才触发 annoyed；
# 零食投喂通道不计入本计数（InteractionSystem 侧不调用 register_interaction）。
const INTERACTION_THRESHOLD := 5
const COUNTING_WINDOW_SEC := 3600.0
const ANNOYED_DURATION_SEC := 600.0

static var _cat_states: Dictionary = {}


func _ready() -> void:
	reset_all()


static func _now() -> float:
	return Time.get_unix_time_from_system()


static func _default_state() -> Dictionary:
	return {
		"state": EmotionState.IDLE,
		"count": 0,
		"window_start": 0.0,
		"annoyed_end": 0.0,
	}


static func _get_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/EmotionStateMachine")


static func _emit_state_changed(cat_id: String, old_state: int, new_state: int) -> void:
	if old_state == new_state:
		return
	var node := _get_node()
	if node == null:
		return
	node.state_changed.emit(cat_id, old_state, new_state)
	if new_state == EmotionState.ANNOYED:
		node.annoyed_entered.emit(cat_id)
	elif old_state == EmotionState.ANNOYED:
		node.annoyed_exited.emit(cat_id)


static func _set_state(cat_id: String, data: Dictionary, new_state: int) -> void:
	var old_state := int(data.get("state", EmotionState.IDLE))
	data["state"] = new_state
	_cat_states[cat_id] = data
	_emit_state_changed(cat_id, old_state, new_state)


static func _expire_if_needed(cat_id: String, now: float = -1.0) -> void:
	if not _cat_states.has(cat_id):
		return
	if now < 0.0:
		now = _now()
	var data: Dictionary = _cat_states[cat_id]
	var state := int(data.get("state", EmotionState.IDLE))
	if state == EmotionState.COUNTING:
		var window_start := float(data.get("window_start", now))
		if now - window_start >= COUNTING_WINDOW_SEC:
			_cat_states.erase(cat_id)
			_emit_state_changed(cat_id, EmotionState.COUNTING, EmotionState.IDLE)
	elif state == EmotionState.ANNOYED:
		var annoyed_end := float(data.get("annoyed_end", 0.0))
		if now >= annoyed_end:
			_cat_states.erase(cat_id)
			_emit_state_changed(cat_id, EmotionState.ANNOYED, EmotionState.IDLE)


static func register_interaction(cat_id: String) -> bool:
	var now := _now()
	var data: Dictionary = _cat_states.get(cat_id, _default_state())
	var state := int(data.get("state", EmotionState.IDLE))
	if state == EmotionState.ANNOYED:
		if now >= float(data.get("annoyed_end", 0.0)):
			_cat_states.erase(cat_id)
			_emit_state_changed(cat_id, EmotionState.ANNOYED, EmotionState.IDLE)
			data = _default_state()
			state = EmotionState.IDLE
		else:
			# ANNOYED 仅冻结情绪与冷视觉；经济奖励照常流转（GDD §5.5）。
			return true
	if state == EmotionState.IDLE:
		data["count"] = 1
		data["window_start"] = now
		data["annoyed_end"] = 0.0
		_set_state(cat_id, data, EmotionState.COUNTING)
		return true
	if state == EmotionState.COUNTING:
		var window_start := float(data.get("window_start", now))
		if now - window_start >= COUNTING_WINDOW_SEC:
			data["count"] = 1
			data["window_start"] = now
			data["annoyed_end"] = 0.0
			_cat_states[cat_id] = data
			return true
		data["count"] = int(data.get("count", 0)) + 1
		if int(data["count"]) >= INTERACTION_THRESHOLD:
			data["annoyed_end"] = now + ANNOYED_DURATION_SEC
			_set_state(cat_id, data, EmotionState.ANNOYED)
			return true
		_cat_states[cat_id] = data
		return true
	return true


static func get_state(cat_id: String) -> EmotionState:
	_expire_if_needed(cat_id)
	var data: Dictionary = _cat_states.get(cat_id, _default_state())
	return data.get("state", EmotionState.IDLE)


static func get_interaction_count(cat_id: String) -> int:
	_expire_if_needed(cat_id)
	var data: Dictionary = _cat_states.get(cat_id, _default_state())
	return int(data.get("count", 0))


static func is_annoyed(cat_id: String) -> bool:
	return get_state(cat_id) == EmotionState.ANNOYED


static func reset_cat(cat_id: String) -> void:
	if not _cat_states.has(cat_id):
		return
	var old_state := int(_cat_states[cat_id].get("state", EmotionState.IDLE))
	_cat_states.erase(cat_id)
	_emit_state_changed(cat_id, old_state, EmotionState.IDLE)


static func reset_all() -> void:
	_cat_states.clear()


static func get_emotion(cat_id: String) -> String:
	if get_state(cat_id) == EmotionState.ANNOYED:
		return "annoyed"
	return "idle"


static func is_sleeping(cat_id: String) -> bool:
	return false


static func record_interaction(cat_id: String, type: String = "") -> void:
	register_interaction(cat_id)
