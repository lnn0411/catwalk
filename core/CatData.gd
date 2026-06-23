extends Resource

class_name CatData

const BREED_ORANGE := "orange"
const BREED_BRITISH := "british"
const BREED_SIAMESE := "siamese"

const RARITY_COMMON := "common"
const RARITY_RARE := "rare"
const RARITY_EPIC := "epic"
const RARITY_LEGENDARY := "legendary"

# 每颗蛋孵化所需能量（energy_required）统一为 4250，不分品种/槽位。
# 依据：孵化能量需求值设计决策 v1.0 / GDD v2.13 §2.2 §17.3 §18.1。
# 注意：4250/15000/30000 是品种「解锁门槛」(total_energy_produced)，
#       与每颗蛋的孵化成本是两回事，解锁门槛见 HatchEngine.get_unlocked_species()。
const HATCH_ENERGY_REQUIRED := 4250

const BREED_COSTS := {
	BREED_ORANGE: HATCH_ENERGY_REQUIRED,
	BREED_BRITISH: HATCH_ENERGY_REQUIRED,
	BREED_SIAMESE: HATCH_ENERGY_REQUIRED,
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

static func create(cat_id: String, species_name: String, cat_rarity: String, index: int):
	var cat = load("res://core/CatData.gd").new()
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

static func get_default_name(species_name: String, _hatch_index_value: int = 1) -> String:
	# GDD §6.2：未命名时存为「未命名+品种」，猫咪正常进入花园
	var zh := OS.get_locale_language() == "zh"
	match species_name:
		BREED_ORANGE:
			return "未命名橘猫" if zh else "Unnamed Orange"
		BREED_BRITISH:
			return "未命名英短" if zh else "Unnamed British"
		BREED_SIAMESE:
			return "未命名暹罗" if zh else "Unnamed Siamese"
		_:
			return "未命名猫咪" if zh else "Unnamed Cat"

static func is_default_name(display_name: String) -> bool:
	return display_name.begins_with("未命名") or display_name.begins_with("Unnamed")

static func get_hatch_cost(species_name: String) -> int:
	return int(BREED_COSTS.get(species_name, BREED_COSTS[BREED_ORANGE]))

static func get_character_script_path(species_name: String) -> String:
	return String(BREED_CHARACTER_SCENES.get(species_name, BREED_CHARACTER_SCENES[BREED_ORANGE]))

static func serialize(cat) -> Dictionary:
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

static func deserialize(data: Dictionary):
	var species_name: String = String(data.get("species", data.get("breed", BREED_ORANGE)))
	var index := int(data.get("hatch_index", 1))
	var cat = load("res://core/CatData.gd").new()
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
