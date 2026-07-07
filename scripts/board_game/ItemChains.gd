class_name ItemChains
extends RefCounted

# ============================================================
# 猫咪合合乐 · 三链物品表
# 每条链5个星级：物品名 + 描述 + 显示用 emoji
# ============================================================

const CHAIN_DATA := {
	BoardGameData.ItemChain.WEAR: {
		"name": "穿戴链",
		"icon": "🧶",
		"items": {
			BoardGameData.StarLevel.ONE: {"name": "毛线球", "desc": "彩色毛线团", "icon": "🧶"},
			BoardGameData.StarLevel.TWO: {"name": "小毛线帽", "desc": "露耳小帽", "icon": "🎩"},
			BoardGameData.StarLevel.THREE: {"name": "毛线围脖", "desc": "温暖围巾", "icon": "🧣"},
			BoardGameData.StarLevel.FOUR: {"name": "毛线披风", "desc": "编织披风", "icon": "🦸"},
			BoardGameData.StarLevel.FIVE: {"name": "毛线公主裙", "desc": "小裙礼服", "icon": "👗"},
		}
	},
	BoardGameData.ItemChain.SNACK: {
		"name": "零食链",
		"icon": "🐟",
		"items": {
			BoardGameData.StarLevel.ONE: {"name": "小鱼干", "desc": "银灰小鱼干", "icon": "🐟"},
			BoardGameData.StarLevel.TWO: {"name": "鲣鱼丝", "desc": "木碗盛装", "icon": "🍜"},
			BoardGameData.StarLevel.THREE: {"name": "三文鱼块", "desc": "橙色鱼肉", "icon": "🍣"},
			BoardGameData.StarLevel.FOUR: {"name": "金枪鱼排", "desc": "厚切鱼肉", "icon": "🥩"},
			BoardGameData.StarLevel.FIVE: {"name": "整条金枪鱼", "desc": "完整大鱼", "icon": "🐋"},
		}
	},
	BoardGameData.ItemChain.BED: {
		"name": "床具链",
		"icon": "🛏",
		"items": {
			BoardGameData.StarLevel.ONE: {"name": "小方垫", "desc": "扁平方垫", "icon": "🟫"},
			BoardGameData.StarLevel.TWO: {"name": "圆猫垫", "desc": "圆形厚垫", "icon": "🟤"},
			BoardGameData.StarLevel.THREE: {"name": "甜甜圈窝", "desc": "环形猫窝", "icon": "🍩"},
			BoardGameData.StarLevel.FOUR: {"name": "猫沙发", "desc": "迷你沙发", "icon": "🛋"},
			BoardGameData.StarLevel.FIVE: {"name": "猫王座", "desc": "小王座金边", "icon": "👑"},
		}
	},
}


static func get_item_info(chain: int, star: int) -> Dictionary:
	if CHAIN_DATA.has(chain) and CHAIN_DATA[chain]["items"].has(star):
		return CHAIN_DATA[chain]["items"][star]
	return {"name": "?", "desc": "", "icon": "❓"}


static func get_chain_display_name(chain: int) -> String:
	if CHAIN_DATA.has(chain):
		return CHAIN_DATA[chain]["name"]
	return ""


static func get_chain_icon(chain: int) -> String:
	if CHAIN_DATA.has(chain):
		return CHAIN_DATA[chain]["icon"]
	return "❓"
