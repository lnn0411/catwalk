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
			BoardGameData.StarLevel.ONE: {"name": "毛线球", "desc": "彩色毛线团", "icon": "🧶", "texture": "res://assets/art/board_game/wear_1.png"},
			BoardGameData.StarLevel.TWO: {"name": "小毛线帽", "desc": "露耳小帽", "icon": "🎩", "texture": "res://assets/art/board_game/wear_2.png"},
			BoardGameData.StarLevel.THREE: {"name": "毛线围脖", "desc": "温暖围巾", "icon": "🧣", "texture": "res://assets/art/board_game/wear_3.png"},
			BoardGameData.StarLevel.FOUR: {"name": "毛线披风", "desc": "编织披风", "icon": "🦸", "texture": "res://assets/art/board_game/wear_4.png"},
			BoardGameData.StarLevel.FIVE: {"name": "毛线公主裙", "desc": "小裙礼服", "icon": "👗", "texture": "res://assets/art/board_game/wear_5.png"},
		}
	},
	BoardGameData.ItemChain.SNACK: {
		"name": "零食链",
		"icon": "🐟",
		"items": {
			BoardGameData.StarLevel.ONE: {"name": "小鱼干", "desc": "银灰小鱼干", "icon": "🐟", "texture": "res://assets/art/board_game/snack_1.png"},
			BoardGameData.StarLevel.TWO: {"name": "鲣鱼丝", "desc": "木碗盛装", "icon": "🍜", "texture": "res://assets/art/board_game/snack_2.png"},
			BoardGameData.StarLevel.THREE: {"name": "三文鱼块", "desc": "橙色鱼肉", "icon": "🍣", "texture": "res://assets/art/board_game/snack_3.png"},
			BoardGameData.StarLevel.FOUR: {"name": "金枪鱼排", "desc": "厚切鱼肉", "icon": "🥩", "texture": "res://assets/art/board_game/snack_4.png"},
			BoardGameData.StarLevel.FIVE: {"name": "整条金枪鱼", "desc": "完整大鱼", "icon": "🐋", "texture": "res://assets/art/board_game/snack_5.png"},
		}
	},
	BoardGameData.ItemChain.BED: {
		"name": "床具链",
		"icon": "🛏",
		"items": {
			BoardGameData.StarLevel.ONE: {"name": "小方垫", "desc": "扁平方垫", "icon": "🟫", "texture": "res://assets/art/board_game/bed_1.png"},
			BoardGameData.StarLevel.TWO: {"name": "圆猫垫", "desc": "圆形厚垫", "icon": "🟤", "texture": "res://assets/art/board_game/bed_2.png"},
			BoardGameData.StarLevel.THREE: {"name": "甜甜圈窝", "desc": "环形猫窝", "icon": "🍩", "texture": "res://assets/art/board_game/bed_3.png"},
			BoardGameData.StarLevel.FOUR: {"name": "猫沙发", "desc": "迷你沙发", "icon": "🛋", "texture": "res://assets/art/board_game/bed_4.png"},
			BoardGameData.StarLevel.FIVE: {"name": "猫王座", "desc": "小王座金边", "icon": "👑", "texture": "res://assets/art/board_game/bed_5.png"},
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


static func get_item_texture(chain: int, star: int) -> Texture2D:
	"""按链+星级加载物品贴图；缺失或加载失败返回 null（由调用方回退 emoji）"""
	var info := get_item_info(chain, star)
	var path: String = info.get("texture", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	if res is Texture2D:
		return res
	return null
