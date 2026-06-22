extends Node

const CatData := preload("res://core/CatData.gd")

const RARITY_COMMON := CatData.RARITY_COMMON
const RARITY_RARE := CatData.RARITY_RARE
const RARITY_EPIC := CatData.RARITY_EPIC
const RARITY_LEGENDARY := CatData.RARITY_LEGENDARY

const CATEGORY_TOY := "toy"
const CATEGORY_DECO := "deco"
const CATEGORY_FLOWER := "flower"

const EPIC_PITY := 20
const LEGENDARY_PITY := 80

const RARITY_WEIGHTS := {
	RARITY_COMMON: 70,
	RARITY_RARE: 20,
	RARITY_EPIC: 8,
	RARITY_LEGENDARY: 2,
}

const GIFT_CATALOG := {
	"toy_yarn":      { "id": "toy_yarn",      "name": "毛线球",   "category": CATEGORY_TOY,    "rarity": RARITY_COMMON,    "icon_path": "res://assets/temp/workshop/toy_yarn.png",      "description": "最经典的猫咪玩具，永远玩不腻" },
	"toy_wand":      { "id": "toy_wand",      "name": "逗猫棒",   "category": CATEGORY_TOY,    "rarity": RARITY_COMMON,    "icon_path": "res://assets/temp/workshop/toy_wand.png",      "description": "带铃铛和羽毛，猫咪的最爱" },
	"toy_mouse":     { "id": "toy_mouse",     "name": "小老鼠",   "category": CATEGORY_TOY,    "rarity": RARITY_COMMON,    "icon_path": "res://assets/temp/workshop/toy_mouse.png",     "description": "会吱吱叫的发条老鼠" },
	"toy_tunnel":    { "id": "toy_tunnel",    "name": "隧道筒",   "category": CATEGORY_TOY,    "rarity": RARITY_RARE,      "icon_path": "res://assets/temp/workshop/toy_tunnel.png",    "description": "可折叠的猫咪隧道" },
	"toy_laser":     { "id": "toy_laser",     "name": "激光笔",   "category": CATEGORY_TOY,    "rarity": RARITY_RARE,      "icon_path": "res://assets/temp/workshop/toy_laser.png",     "description": "一个红色光点就能让猫咪疯狂" },
	"toy_butterfly": { "id": "toy_butterfly", "name": "电动蝴蝶", "category": CATEGORY_TOY,    "rarity": RARITY_EPIC,      "icon_path": "res://assets/temp/workshop/toy_butterfly.png", "description": "扑翼蝴蝶，自动飞行绕圈" },
	"toy_castle":    { "id": "toy_castle",    "name": "猫城堡",   "category": CATEGORY_TOY,    "rarity": RARITY_EPIC,      "icon_path": "res://assets/temp/workshop/toy_castle.png",    "description": "多层猫爬架微缩版" },
	"toy_mirror":    { "id": "toy_mirror",    "name": "魔法镜球", "category": CATEGORY_TOY,    "rarity": RARITY_LEGENDARY, "icon_path": "res://assets/temp/workshop/toy_mirror.png",    "description": "镜面反射光斑，猫咪永远抓不到" },
	"deco_scarf":    { "id": "deco_scarf",    "name": "小围巾",   "category": CATEGORY_DECO,   "rarity": RARITY_COMMON,    "icon_path": "res://assets/temp/workshop/deco_scarf.png",    "description": "暖色针织围巾" },
	"deco_ribbon":   { "id": "deco_ribbon",   "name": "蝴蝶结",   "category": CATEGORY_DECO,   "rarity": RARITY_COMMON,    "icon_path": "res://assets/temp/workshop/deco_ribbon.png",   "description": "粉色丝绸蝴蝶结" },
	"deco_bell":     { "id": "deco_bell",     "name": "铃铛项圈", "category": CATEGORY_DECO,   "rarity": RARITY_RARE,      "icon_path": "res://assets/temp/workshop/deco_bell.png",     "description": "清脆铃铛，走一步响一声" },
	"deco_hat":      { "id": "deco_hat",      "name": "小礼帽",   "category": CATEGORY_DECO,   "rarity": RARITY_RARE,      "icon_path": "res://assets/temp/workshop/deco_hat.png",      "description": "迷你绅士帽" },
	"deco_tiara":    { "id": "deco_tiara",    "name": "水晶发饰", "category": CATEGORY_DECO,   "rarity": RARITY_EPIC,      "icon_path": "res://assets/temp/workshop/deco_tiara.png",    "description": "闪耀的小皇冠" },
	"deco_wings":    { "id": "deco_wings",    "name": "天使翅膀", "category": CATEGORY_DECO,   "rarity": RARITY_EPIC,      "icon_path": "res://assets/temp/workshop/deco_wings.png",    "description": "纯白小翅膀背饰" },
	"deco_crown":    { "id": "deco_crown",    "name": "星辰王冠", "category": CATEGORY_DECO,   "rarity": RARITY_LEGENDARY, "icon_path": "res://assets/temp/workshop/deco_crown.png",    "description": "星辰之力的证明" },
	"deco_moon":     { "id": "deco_moon",     "name": "月轮光环", "category": CATEGORY_DECO,   "rarity": RARITY_LEGENDARY, "icon_path": "res://assets/temp/workshop/deco_moon.png",     "description": "月光化作的背饰光环" },
	"flower_daisy":      { "id": "flower_daisy",      "name": "小雏菊",   "category": CATEGORY_FLOWER, "rarity": RARITY_COMMON,    "icon_path": "res://assets/temp/workshop/flower_daisy.png",      "description": "路边采的小白花" },
	"flower_sunflower":  { "id": "flower_sunflower",  "name": "向日葵",   "category": CATEGORY_FLOWER, "rarity": RARITY_COMMON,    "icon_path": "res://assets/temp/workshop/flower_sunflower.png",  "description": "金灿灿的向阳花" },
	"flower_lavender":   { "id": "flower_lavender",   "name": "薰衣草",   "category": CATEGORY_FLOWER, "rarity": RARITY_RARE,      "icon_path": "res://assets/temp/workshop/flower_lavender.png",   "description": "淡紫色的安神花朵" },
	"flower_tulip":      { "id": "flower_tulip",      "name": "郁金香",   "category": CATEGORY_FLOWER, "rarity": RARITY_RARE,      "icon_path": "res://assets/temp/workshop/flower_tulip.png",      "description": "优雅的杯状花朵" },
	"flower_rose":       { "id": "flower_rose",       "name": "玫瑰",     "category": CATEGORY_FLOWER, "rarity": RARITY_EPIC,      "icon_path": "res://assets/temp/workshop/flower_rose.png",       "description": "深红玫瑰，爱的象征" },
	"flower_lotus":      { "id": "flower_lotus",      "name": "睡莲",     "category": CATEGORY_FLOWER, "rarity": RARITY_EPIC,      "icon_path": "res://assets/temp/workshop/flower_lotus.png",      "description": "静谧水面上的花朵" },
	"flower_cherry":     { "id": "flower_cherry",     "name": "樱花枝",   "category": CATEGORY_FLOWER, "rarity": RARITY_LEGENDARY, "icon_path": "res://assets/temp/workshop/flower_cherry.png",     "description": "秒速五厘米飘落的樱花" },
	"flower_ether":      { "id": "flower_ether",      "name": "以太花",   "category": CATEGORY_FLOWER, "rarity": RARITY_LEGENDARY, "icon_path": "res://assets/temp/workshop/flower_ether.png",      "description": "只在月光下绽放的梦幻之花" },
}

var epic_pity_count: int = 0
var legendary_pity_count: int = 0

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func roll_gift() -> String:
	var rarity := _roll_rarity()
	var gift_ids := get_gift_ids_by_rarity(rarity)
	if gift_ids.is_empty():
		return ""
	return String(gift_ids[_rng.randi_range(0, gift_ids.size() - 1)])

func reset_pity() -> void:
	epic_pity_count = 0
	legendary_pity_count = 0

func get_save_data() -> Dictionary:
	return {
		"epic_pity_count": epic_pity_count,
		"legendary_pity_count": legendary_pity_count,
	}

func apply_save(data: Dictionary) -> void:
	epic_pity_count = max(int(data.get("epic_pity_count", 0)), 0)
	legendary_pity_count = max(int(data.get("legendary_pity_count", 0)), 0)

func get_gift_data(gift_id: String) -> Dictionary:
	var d := Dictionary(GIFT_CATALOG.get(gift_id, {}))
	return d.duplicate(true)

func has_gift(gift_id: String) -> bool:
	return GIFT_CATALOG.has(gift_id)

func get_all_gift_ids() -> Array[String]:
	var ids: Array[String] = []
	for gift_id in GIFT_CATALOG.keys():
		ids.append(String(gift_id))
	ids.sort()
	return ids

func get_gift_ids_by_category(category: String) -> Array[String]:
	var ids: Array[String] = []
	for gift_id in GIFT_CATALOG.keys():
		var gift := get_gift_data(String(gift_id))
		if String(gift.get("category", "")) == category:
			ids.append(String(gift_id))
	ids.sort()
	return ids

func get_gift_ids_by_rarity(rarity: String) -> Array[String]:
	var ids: Array[String] = []
	for gift_id in GIFT_CATALOG.keys():
		var gift := get_gift_data(String(gift_id))
		if String(gift.get("rarity", "")) == rarity:
			ids.append(String(gift_id))
	ids.sort()
	return ids

func _roll_rarity() -> String:
	var result := _base_roll_rarity()
	if legendary_pity_count >= LEGENDARY_PITY:
		result = RARITY_LEGENDARY
	elif epic_pity_count >= EPIC_PITY and _rarity_rank(result) < _rarity_rank(RARITY_EPIC):
		result = RARITY_EPIC
	_update_pity_counters(result)
	return result

func _base_roll_rarity() -> String:
	var total_weight := 0
	for weight in RARITY_WEIGHTS.values():
		total_weight += int(weight)
	var roll := _rng.randi_range(1, total_weight)
	var cursor := 0
	for rarity in [RARITY_COMMON, RARITY_RARE, RARITY_EPIC, RARITY_LEGENDARY]:
		cursor += int(RARITY_WEIGHTS[rarity])
		if roll <= cursor:
			return rarity
	return RARITY_LEGENDARY

func _update_pity_counters(result: String) -> void:
	if result == RARITY_LEGENDARY:
		legendary_pity_count = 0
	else:
		legendary_pity_count += 1
	if _rarity_rank(result) >= _rarity_rank(RARITY_EPIC):
		epic_pity_count = 0
	else:
		epic_pity_count += 1

func _rarity_rank(rarity: String) -> int:
	match rarity:
		RARITY_LEGENDARY:
			return 3
		RARITY_EPIC:
			return 2
		RARITY_RARE:
			return 1
		_:
			return 0
