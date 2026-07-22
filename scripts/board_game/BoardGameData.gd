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

# 特殊格枚举（D10）
enum SpecialTile { NONE = 0, YARN = 1 }

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

# ============================================================
# D10 兴奋值 / 连击 / 狂欢 配置
# ============================================================

# 兴奋值上限
const EXCITEMENT_MAX := 100

# 按星级合并获得的兴奋值（StarLevel → value）
const EXCITEMENT_MERGE_VALUES := {1: 8, 2: 12, 3: 18, 4: 30}

# 连击额外兴奋值
const EXCITEMENT_COMBO_BONUS := 4

# 三连合额外兴奋值
const EXCITEMENT_TRIPLE_MERGE_BONUS := 10

# 解开毛线格获得的兴奋值
const EXCITEMENT_YARN_BONUS := 20

# 连击判定窗口（秒）
const COMBO_WINDOW_SECONDS := 3.0

# 狂欢免费生成次数（K7 狂欢改为「抵消捣乱」，不再有免费生成）
# const FRENZY_FREE_GENERATIONS := 3

# 每局最大狂欢次数
const FRENZY_MAX_TRIGGERS := 2

# M2-K8: 狂欢二选一模式
enum FrenzyMode { GUARD = 0, HELP = 1 }  # 护卫=抵消下一次捣乱；帮忙=立即免费生成2个主链⭐1

# M2-K8: 「猫猫帮忙」免费生成的主链⭐1数量（不消耗生成器次数）
const FRENZY_HELP_SPAWN_COUNT := 2

# M2: 兴奋值满管后溢出部分的结转比例（50%存入蓄能池，狂欢释放后返还）
const EXCITEMENT_OVERFLOW_CARRY := 0.5

# M2: 连击兴奋值 = COMBO_BONUS × min(连击数-1, 上限倍数)，即 +4/+8/+12 封顶
const EXCITEMENT_COMBO_CAP_MULT := 3

# M2: 捣乱预警提前量（触发点前 N 次点击开始预警）
const MISCHIEF_FOREWARN_CLICKS := 2

# 狂欢持续时间（秒）（K7 狂欢改为「抵消捣乱」，不再有倒计时）
# const FRENZY_DURATION_SECONDS := 10.0

# 目标横幅星级段数
const MAX_STAR_SEGMENTS := 5


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
				"reward_desc": "基础通关奖励",
				"yarn_tile_count": 2,
				"excitement_initial": 0,
			}
		BoardLevel.LV2:
			return {
				"initial_main_min": 4, "initial_main_max": 5,
				"initial_sub_min": 2, "initial_sub_max": 3,
				"mischief_triggers": [7, 14],
				"reward_desc": "奖励更丰厚：装饰与礼包概率提升",
				"yarn_tile_count": 3,
				"excitement_initial": 0,
			}
		BoardLevel.LV3:
			return {
				"initial_main_min": 4, "initial_main_max": 5,
				"initial_sub_min": 2, "initial_sub_max": 3,
				"mischief_triggers": [6, 12, 18],
				"reward_desc": "奖励最丰厚；⭐⭐⭐通关额外+猫罐头×1",
				"yarn_tile_count": 4,
				"excitement_initial": 0,
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
