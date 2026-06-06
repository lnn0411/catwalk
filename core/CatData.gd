extends Resource

class_name CatData

const BREED_ORANGE := "orange"
const BREED_BRITISH := "british"
const BREED_SIAMESE := "siamese"

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

@export var id: String = ""
@export var species: String = BREED_ORANGE
@export var rarity: String = RARITY_COMMON
@export var hatch_index: int = 1
@export var display_name: String = ""
@export var level: int = 1
@export var exp: int = 0
@export var friendship: int = 0
@export var created_at: float = 0.0

static func create(cat_id: String, species_name: String, cat_rarity: String, index: int) -> CatData:
	var cat := CatData.new()
	cat.id = cat_id
	cat.species = species_name
	cat.rarity = cat_rarity
	cat.hatch_index = index
	cat.display_name = get_default_name(species_name, index)
	cat.level = 1
	cat.exp = 0
	cat.friendship = 0
	cat.created_at = Time.get_unix_time_from_system()
	return cat

static func get_default_name(species_name: String, hatch_index_value: int) -> String:
	match species_name:
		BREED_ORANGE:
			return "Orange %d" % hatch_index_value
		BREED_BRITISH:
			return "British %d" % hatch_index_value
		BREED_SIAMESE:
			return "Siamese %d" % hatch_index_value
		_:
			return "Cat %d" % hatch_index_value

static func get_hatch_cost(species_name: String) -> int:
	return int(BREED_COSTS.get(species_name, BREED_COSTS[BREED_ORANGE]))

static func get_character_script_path(species_name: String) -> String:
	return String(BREED_CHARACTER_SCENES.get(species_name, BREED_CHARACTER_SCENES[BREED_ORANGE]))

static func serialize(cat: CatData) -> Dictionary:
	if cat == null:
		return {}
	return {
		"id": cat.id,
		"species": cat.species,
		"rarity": cat.rarity,
		"hatch_index": cat.hatch_index,
		"display_name": cat.display_name,
		"level": cat.level,
		"exp": cat.exp,
		"friendship": cat.friendship,
		"created_at": cat.created_at,
	}

static func deserialize(data: Dictionary) -> CatData:
	var species_name := String(data.get("species", data.get("breed", BREED_ORANGE)))
	var index := int(data.get("hatch_index", 1))
	var cat := CatData.new()
	cat.id = String(data.get("id", ""))
	cat.species = species_name
	cat.rarity = String(data.get("rarity", RARITY_COMMON))
	cat.hatch_index = index
	cat.display_name = String(data.get("display_name", data.get("name", get_default_name(species_name, index))))
	cat.level = int(data.get("level", 1))
	cat.exp = int(data.get("exp", 0))
	cat.friendship = int(data.get("friendship", 0))
	cat.created_at = float(data.get("created_at", Time.get_unix_time_from_system()))
	return cat
