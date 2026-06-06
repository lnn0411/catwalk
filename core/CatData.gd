extends RefCounted

class_name CatData

const BREED_ORANGE := "橘猫"
const BREED_BRITISH := "英短"
const BREED_SIAMESE := "暹罗"

const RARITY_COMMON := "common"
const RARITY_RARE := "rare"
const RARITY_EPIC := "epic"
const RARITY_LEGENDARY := "legendary"

const BREED_COSTS := {
	BREED_ORANGE: 4250,
	BREED_BRITISH: 15000,
	BREED_SIAMESE: 30000,
}

const BREED_CHARACTER_SCENES := {
	BREED_ORANGE: "res://characters/CatOrange.gd",
	BREED_BRITISH: "res://characters/CatBritish.gd",
	BREED_SIAMESE: "res://characters/CatSiamese.gd",
}

static func create_cat(cat_id: String, breed: String, rarity: String, hatch_index: int) -> Dictionary:
	return {
		"id": cat_id,
		"breed": breed,
		"rarity": rarity,
		"hatch_index": hatch_index,
		"name": get_default_name(breed, hatch_index),
		"level": 1,
		"exp": 0,
		"friendship": 0,
		"created_at": Time.get_unix_time_from_system(),
	}

static func get_default_name(breed: String, hatch_index: int) -> String:
	match breed:
		BREED_ORANGE:
			return "橘子%d" % hatch_index
		BREED_BRITISH:
			return "绅士%d" % hatch_index
		BREED_SIAMESE:
			return "小话痨%d" % hatch_index
		_:
			return "猫咪%d" % hatch_index

static func get_hatch_cost(breed: String) -> int:
	return int(BREED_COSTS.get(breed, BREED_COSTS[BREED_ORANGE]))

static func get_character_script_path(breed: String) -> String:
	return String(BREED_CHARACTER_SCENES.get(breed, BREED_CHARACTER_SCENES[BREED_ORANGE]))

static func serialize(cat: Dictionary) -> Dictionary:
	return cat.duplicate(true)

static func deserialize(data: Dictionary) -> Dictionary:
	return {
		"id": String(data.get("id", "")),
		"breed": String(data.get("breed", BREED_ORANGE)),
		"rarity": String(data.get("rarity", RARITY_COMMON)),
		"hatch_index": int(data.get("hatch_index", 1)),
		"name": String(data.get("name", get_default_name(String(data.get("breed", BREED_ORANGE)), int(data.get("hatch_index", 1))))),
		"level": int(data.get("level", 1)),
		"exp": int(data.get("exp", 0)),
		"friendship": int(data.get("friendship", 0)),
		"created_at": float(data.get("created_at", Time.get_unix_time_from_system())),
	}
