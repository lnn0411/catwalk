class_name BoardRewardSystem
extends RefCounted

const REWARDS := {
	"fish_dried": {"name": "小鱼干", "weight": 30, "type": "snack"},
	"cat_can": {"name": "猫罐头", "weight": 20, "type": "snack"},
	"yarn_ball": {"name": "逗猫毛线团", "weight": 20, "type": "toy"},
	"cat_wand": {"name": "逗猫棒", "weight": 15, "type": "toy"},
	"cat_tree": {"name": "猫爬架", "weight": 8, "type": "decoration"},
	"cherry_tree": {"name": "樱花树", "weight": 5, "type": "decoration"},
	"cat_can_pack": {"name": "猫罐头大礼包", "weight": 2, "type": "snack_pack"},
}

const DAILY_SNACK_LIMIT := 3

static func roll_reward() -> Dictionary:
	var total := 0
	for k in REWARDS: total += REWARDS[k].weight
	var roll := randi() % total
	var cum := 0
	for k in REWARDS:
		cum += REWARDS[k].weight
		if roll < cum:
			var item = REWARDS[k].duplicate()
			item["id"] = k
			return item
	return {"id": "fish_dried", "name": "小鱼干", "weight": 30, "type": "snack"}

static func can_feed_cat(cat_id: String, day_feed_count: Dictionary) -> bool:
	return day_feed_count.get(cat_id, 0) < DAILY_SNACK_LIMIT
