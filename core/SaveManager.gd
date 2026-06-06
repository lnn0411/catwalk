extends Node

const SAVE_PATH := "user://catwalk_save.json"
const NEW_PLAYER_DAYS := 7

var data: Dictionary = {}

func _ready() -> void:
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _default_data()
		save_game()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		data = _default_data()
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		data = parsed
	else:
		data = _default_data()

	_ensure_defaults()

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))

func is_new_player() -> bool:
	var created_at := float(data.get("created_at", Time.get_unix_time_from_system()))
	var age_seconds := Time.get_unix_time_from_system() - created_at
	return age_seconds < float(NEW_PLAYER_DAYS * 24 * 60 * 60)

func get_step_state() -> Dictionary:
	return Dictionary(data.get("steps", {})).duplicate(true)

func set_step_state(state: Dictionary) -> void:
	data["steps"] = state.duplicate(true)
	save_game()

func get_energy_state() -> Dictionary:
	return Dictionary(data.get("energy", {})).duplicate(true)

func set_energy_state(state: Dictionary) -> void:
	data["energy"] = state.duplicate(true)
	save_game()

func get_hatch_state() -> Dictionary:
	return Dictionary(data.get("hatch", {})).duplicate(true)

func set_hatch_state(state: Dictionary) -> void:
	data["hatch"] = state.duplicate(true)
	save_game()

func reset_game() -> void:
	data = _default_data()
	save_game()

func _ensure_defaults() -> void:
	var defaults := _default_data()
	for key in defaults.keys():
		if not data.has(key):
			data[key] = defaults[key]

func _default_data() -> Dictionary:
	return {
		"version": 1,
		"created_at": Time.get_unix_time_from_system(),
		"steps": {
			"today_steps": 0,
			"total_steps": 0,
			"last_plugin_steps": 0,
		},
		"energy": {
			"energy_pool": 0,
			"energy_reserve": 0,
			"total_energy_produced": 0,
			"today_energy": 0,
		},
		"hatch": {
			"slots": [],
			"cats": [],
			"hatched_count": 0,
		},
	}
