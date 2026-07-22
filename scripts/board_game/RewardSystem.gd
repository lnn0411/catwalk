class_name BoardRewardSystem
extends RefCounted

const BoardGameData := preload("res://scripts/board_game/BoardGameData.gd")

# M1-5: 通关奖励按棋盘等级分表——兑现升档文案「奖励更丰厚」。
# LV3 装饰类合计权重 21%（LV1 为 13%）、大礼包 5%；小鱼干占比随关卡下降。
const REWARDS_LV1 := {
	"fish_dried": {"name": "小鱼干", "weight": 30, "type": "snack"},
	"cat_can": {"name": "猫罐头", "weight": 20, "type": "snack"},
	"yarn_ball": {"name": "逗猫毛线团", "weight": 20, "type": "toy"},
	"cat_wand": {"name": "逗猫棒", "weight": 15, "type": "toy"},
	"cat_tree": {"name": "猫爬架", "weight": 8, "type": "decoration"},
	"cherry_tree": {"name": "樱花树", "weight": 5, "type": "decoration"},
	"cat_can_pack": {"name": "猫罐头大礼包", "weight": 2, "type": "snack_pack"},
}

const REWARDS_LV2 := {
	"fish_dried": {"name": "小鱼干", "weight": 24, "type": "snack"},
	"cat_can": {"name": "猫罐头", "weight": 22, "type": "snack"},
	"yarn_ball": {"name": "逗猫毛线团", "weight": 20, "type": "toy"},
	"cat_wand": {"name": "逗猫棒", "weight": 15, "type": "toy"},
	"cat_tree": {"name": "猫爬架", "weight": 10, "type": "decoration"},
	"cherry_tree": {"name": "樱花树", "weight": 6, "type": "decoration"},
	"cat_can_pack": {"name": "猫罐头大礼包", "weight": 3, "type": "snack_pack"},
}

const REWARDS_LV3 := {
	"fish_dried": {"name": "小鱼干", "weight": 18, "type": "snack"},
	"cat_can": {"name": "猫罐头", "weight": 24, "type": "snack"},
	"yarn_ball": {"name": "逗猫毛线团", "weight": 18, "type": "toy"},
	"cat_wand": {"name": "逗猫棒", "weight": 14, "type": "toy"},
	"cat_tree": {"name": "猫爬架", "weight": 12, "type": "decoration"},
	"cherry_tree": {"name": "樱花树", "weight": 9, "type": "decoration"},
	"cat_can_pack": {"name": "猫罐头大礼包", "weight": 5, "type": "snack_pack"},
}

const REWARDS_BY_LEVEL := {
	BoardGameData.BoardLevel.LV1: REWARDS_LV1,
	BoardGameData.BoardLevel.LV2: REWARDS_LV2,
	BoardGameData.BoardLevel.LV3: REWARDS_LV3,
}

# 兼容旧引用：LV1 表即原平权表
const REWARDS := REWARDS_LV1

const DAILY_SNACK_LIMIT := 3

static func roll_reward(level: int = BoardGameData.BoardLevel.LV1) -> Dictionary:
	var table: Dictionary = REWARDS_BY_LEVEL.get(level, REWARDS_LV1)
	var total := 0
	for k in table: total += table[k].weight
	var roll := randi() % total
	var cum := 0
	for k in table:
		cum += table[k].weight
		if roll < cum:
			var item = table[k].duplicate()
			item["id"] = k
			return item
	return {"id": "fish_dried", "name": "小鱼干", "weight": 30, "type": "snack"}

static func can_feed_cat(cat_id: String, day_feed_count: Dictionary) -> bool:
	return day_feed_count.get(cat_id, 0) < DAILY_SNACK_LIMIT
