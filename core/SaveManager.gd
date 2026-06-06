extends Node

const CatData := preload("res://core/CatData.gd")
const SAVE_PATH := "user://save.cfg"

var _config := ConfigFile.new()
var _is_applying: bool = false

func _ready() -> void:
	load_and_apply()
	_connect_auto_save()

func save_all() -> void:
	_write_steps()
	_write_energy()
	_write_hatch()
	_config.save(SAVE_PATH)

func load_and_apply() -> void:
	_config = ConfigFile.new()
	var err := _config.load(SAVE_PATH)
	if err != OK:
		_config.clear()

	_is_applying = true
	StepEngine.apply_save(_read_steps())
	EnergyEngine.apply_save(_read_energy())
	HatchEngine.apply_save(_read_hatch())
	_is_applying = false

func reset_all() -> void:
	_config.clear()
	_config.save(SAVE_PATH)
	_is_applying = true
	StepEngine.apply_save({})
	EnergyEngine.apply_save({})
	HatchEngine.apply_save({})
	_is_applying = false
	save_all()

func _connect_auto_save() -> void:
	if EnergyEngine and not EnergyEngine.energy_changed.is_connected(_on_auto_save):
		EnergyEngine.energy_changed.connect(_on_auto_save)
	if HatchEngine and not HatchEngine.hatch_complete.is_connected(_on_hatch_complete_auto_save):
		HatchEngine.hatch_complete.connect(_on_hatch_complete_auto_save)

func _on_auto_save(_current = null, _pool_max = null, _backup = null) -> void:
	if _is_applying:
		return
	save_all()

func _on_hatch_complete_auto_save(_cat_data) -> void:
	if _is_applying:
		return
	save_all()

func _read_steps() -> Dictionary:
	return {
		"today_steps": int(_config.get_value("steps", "today_steps", 0)),
		"total_steps": int(_config.get_value("steps", "total_steps", 0)),
		"last_plugin_steps": int(_config.get_value("steps", "last_plugin_steps", 0)),
		"last_step_date": String(_config.get_value("steps", "last_step_date", "")),
	}

func _write_steps() -> void:
	var data := StepEngine.get_save_data()
	_config.set_value("steps", "today_steps", int(data.get("today_steps", 0)))
	_config.set_value("steps", "total_steps", int(data.get("total_steps", 0)))
	_config.set_value("steps", "last_plugin_steps", int(data.get("last_plugin_steps", 0)))
	_config.set_value("steps", "last_step_date", String(data.get("last_step_date", "")))

func _read_energy() -> Dictionary:
	return {
		"energy_pool": float(_config.get_value("energy", "energy_pool", 0.0)),
		"reserve_tank": float(_config.get_value("energy", "reserve_tank", 0.0)),
		"total_energy_produced": float(_config.get_value("energy", "total_energy_produced", 0.0)),
		"today_energy": float(_config.get_value("energy", "today_energy", 0.0)),
		"today_steps_processed": int(_config.get_value("energy", "today_steps_processed", 0)),
		"created_at": float(_config.get_value("energy", "created_at", Time.get_unix_time_from_system())),
		"last_energy_date": String(_config.get_value("energy", "last_energy_date", "")),
	}

func _write_energy() -> void:
	var data := EnergyEngine.get_save_data()
	_config.set_value("energy", "energy_pool", float(data.get("energy_pool", 0.0)))
	_config.set_value("energy", "reserve_tank", float(data.get("reserve_tank", 0.0)))
	_config.set_value("energy", "total_energy_produced", float(data.get("total_energy_produced", 0.0)))
	_config.set_value("energy", "today_energy", float(data.get("today_energy", 0.0)))
	_config.set_value("energy", "today_steps_processed", int(data.get("today_steps_processed", 0)))
	_config.set_value("energy", "created_at", float(data.get("created_at", Time.get_unix_time_from_system())))
	_config.set_value("energy", "last_energy_date", String(data.get("last_energy_date", "")))

func _read_hatch() -> Dictionary:
	var cat_count := int(_config.get_value("hatch", "cat_count", 0))
	var cats: Array = []
	for i in range(cat_count):
		cats.append(_read_cat("cat_%d" % i))

	return {
		"slots": Array(_config.get_value("hatch", "slots", [])),
		"cats": cats,
		"hatched_count": int(_config.get_value("hatch", "hatched_count", cat_count)),
	}

func _write_hatch() -> void:
	var data := HatchEngine.get_save_data()
	var cats: Array = Array(data.get("cats", []))
	_clear_cat_sections()
	_config.set_value("hatch", "slots", Array(data.get("slots", [])))
	_config.set_value("hatch", "hatched_count", int(data.get("hatched_count", cats.size())))
	_config.set_value("hatch", "cat_count", cats.size())
	for i in range(cats.size()):
		_write_cat("cat_%d" % i, cats[i])

func _read_cat(section: String) -> Dictionary:
	return {
		"id": String(_config.get_value(section, "id", "")),
		"species": String(_config.get_value(section, "species", CatData.BREED_ORANGE)),
		"rarity": String(_config.get_value(section, "rarity", CatData.RARITY_COMMON)),
		"hatch_index": int(_config.get_value(section, "hatch_index", 1)),
		"display_name": String(_config.get_value(section, "display_name", "")),
		"level": int(_config.get_value(section, "level", 1)),
		"exp": int(_config.get_value(section, "exp", 0)),
		"friendship": int(_config.get_value(section, "friendship", 0)),
		"created_at": float(_config.get_value(section, "created_at", Time.get_unix_time_from_system())),
	}

func _write_cat(section: String, cat_value) -> void:
	var data: Dictionary = CatData.serialize(cat_value) if cat_value is CatData else Dictionary(cat_value)
	_config.set_value(section, "id", String(data.get("id", "")))
	_config.set_value(section, "species", String(data.get("species", CatData.BREED_ORANGE)))
	_config.set_value(section, "rarity", String(data.get("rarity", CatData.RARITY_COMMON)))
	_config.set_value(section, "hatch_index", int(data.get("hatch_index", 1)))
	_config.set_value(section, "display_name", String(data.get("display_name", "")))
	_config.set_value(section, "level", int(data.get("level", 1)))
	_config.set_value(section, "exp", int(data.get("exp", 0)))
	_config.set_value(section, "friendship", int(data.get("friendship", 0)))
	_config.set_value(section, "created_at", float(data.get("created_at", Time.get_unix_time_from_system())))

func _clear_cat_sections() -> void:
	for section in _config.get_sections():
		if String(section).begins_with("cat_"):
			_config.erase_section(section)
