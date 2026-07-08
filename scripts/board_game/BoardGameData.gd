class_name BoardGameData
extends RefCounted

# ============================================================
# 猫咪合合乐 · 数据定义
# 物品链数据、初始掉落配置、生成器配置（S14_BoardGame）
# ============================================================

# 物品星级枚举
enum StarLevel { ONE = 1, TWO = 2, THREE = 3, FOUR = 4, FIVE = 5 }

# 物品链枚举
# 链A(穿戴): 毛线球→小毛线帽→毛线围脖→毛线披风→毛线公主裙
# 链B(零食): 小鱼干→鲣鱼丝→三文鱼块→金枪鱼排→整条金枪鱼
# 链C(床具): 小方垫→圆猫垫→甜甜圈窝→猫沙发→猫王座
enum ItemChain { WEAR = 0, SNACK = 1, BED = 2 }

# 对局状态
enum GameState { PLAYING = 0, WON = 1, LOST = 2 }

# 生成器配置: 每局20次，第5/10/15/20次出副链，其余出主链
const GENERATOR_TOTAL := 20

# 确定性掉落序列: true=主链, false=副链（索引0为第1次点击）
const DROP_SEQUENCE := [
	true, true, true, true, false,
	true, true, true, true, false,
	true, true, true, true, false,
	true, true, true, true, false,
]

# 初始掉落: 主链4-6个 + 副链2-3个（随机范围，均为1星）
const INITIAL_MAIN_MIN := 4
const INITIAL_MAIN_MAX := 6
const INITIAL_SUB_MIN := 2
const INITIAL_SUB_MAX := 3

# 棋盘尺寸
const GRID_SIZE := 5  # 5×5
const GENERATOR_POS := Vector2i(2, 2)  # 中心格

# 撤销：每局免费次数（超出后由 UI 层扣钻石）
const UNDO_FREE_COUNT := 3


static func chain_name(chain: int) -> String:
	match chain:
		ItemChain.WEAR:
			return "WEAR"
		ItemChain.SNACK:
			return "SNACK"
		ItemChain.BED:
			return "BED"
	return ""


static func all_chains() -> Array:
	return [ItemChain.WEAR, ItemChain.SNACK, ItemChain.BED]


static func is_valid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE


static func all_cells() -> Array:
	var cells: Array = []
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			cells.append(Vector2i(x, y))
	return cells


# 棋盘关卡枚举（按累计胜场划分）
enum BoardLevel { LV1 = 1, LV2 = 2, LV3 = 3 }


# 关卡配置：{level: {initial_main_min, initial_main_max, initial_sub_min, initial_sub_max, mischief_triggers: [generator_click_indices]}}
static func get_level_config(level: int) -> Dictionary:
	match level:
		BoardLevel.LV1:
			return {
				"initial_main_min": 5, "initial_main_max": 6,
				"initial_sub_min": 2, "initial_sub_max": 3,
				"mischief_triggers": [10],
			}
		BoardLevel.LV2:
			return {
				"initial_main_min": 4, "initial_main_max": 5,
				"initial_sub_min": 2, "initial_sub_max": 3,
				"mischief_triggers": [7, 14],
			}
		BoardLevel.LV3:
			return {
				"initial_main_min": 4, "initial_main_max": 5,
				"initial_sub_min": 2, "initial_sub_max": 3,
				"mischief_triggers": [6, 12, 18],
			}
		_:
			return get_level_config(BoardLevel.LV1)


# 关卡解锁所需胜场数
static func get_wins_for_level(level: int) -> int:
	match level:
		BoardLevel.LV2:
			return 5
		BoardLevel.LV3:
			return 15
		_:
			return 0


# 根据累计胜场计算当前关卡等级
static func calc_board_level(total_wins: int) -> int:
	if total_wins >= get_wins_for_level(BoardLevel.LV3):
		return BoardLevel.LV3
	if total_wins >= get_wins_for_level(BoardLevel.LV2):
		return BoardLevel.LV2
	return BoardLevel.LV1
