# LevelStateManager — 猫咪合合乐 关卡状态管理器 (Autoload)
# 不要加 class_name：已注册为同名 autoload，class_name 会与单例命名冲突。
# 独立存档 user://cat_merge_save.cfg（ConfigFile），与 InventoryManager 等风格一致。
extends Node

const BoardGame := preload("res://scripts/board_game/BoardGame.gd")
const BoardGameData := preload("res://scripts/board_game/BoardGameData.gd")

const SAVE_PATH := "user://cat_merge_save.cfg"
const SECTION := "session"
const META_SECTION := "meta"  # 累计胜场 / 棋盘等级（跨对局持久化，仅升不降）

# 主动放弃本局的安慰奖（与 BoardGame 的 CONSOLATION_* 常量保持一致）
const CONSOLATION_PRIZE := {
	"item": "小鱼干",
	"count": 1,
	"text": "猫咪们说：没关系，下次再来喵",
}

# 生命周期信号
signal game_started
signal saved
signal loaded
signal resigned(item_name: String, count: int, message: String)
signal won_reward_ready
signal first_three_star_bonus_reward(item_name: String, count: int)  # D4
# 棋盘升档（旧等级 -> 新等级）；record_win 触发升级时发出
signal level_up(old_level: int, new_level: int)

# 本管理器持有的对局实例（纯逻辑，UI 层通过 game 访问棋盘）
var game: BoardGame = null

# 跨对局累计的进度（持久化在 SAVE_PATH 的 [meta] section）
var total_wins: int = 0
var board_level: int = BoardGameData.BoardLevel.LV1
var first_three_star_claimed: bool = false  # D4


func _ready() -> void:
	_load_meta()
	_ensure_game()


# ---------------- 生命周期 ----------------

func start_new_game() -> void:
	"""开新一局：作废旧存档并重置棋盘。"""
	var g := _ensure_game()
	delete()
	g.start_new_game()
	game_started.emit()


func save() -> bool:
	"""把当前对局状态写入 ConfigFile。返回是否成功。"""
	if game == null:
		return false
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # 保留已有的 [meta] section，避免被整体覆盖
	cfg.set_value(SECTION, "state", game.serialize_state())
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("LevelStateManager.save 失败: %d" % err)
		return false
	saved.emit()
	return true


func load() -> bool:
	"""从存档恢复对局。无有效存档时返回 false。"""
	if not has_saved():
		return false
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	var g := _ensure_game()
	g.deserialize_state(cfg.get_value(SECTION, "state", {}))
	loaded.emit()
	return true


func has_saved() -> bool:
	"""是否存在可恢复的对局存档。"""
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	return cfg.has_section_key(SECTION, "state")


func delete() -> void:
	"""删除对局存档，但保留 [meta]（累计胜场/棋盘等级不因开新局而清空）。"""
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		DirAccess.remove_absolute(SAVE_PATH)
		return
	if cfg.has_section(SECTION):
		cfg.erase_section(SECTION)
	cfg.save(SAVE_PATH)


func give_up() -> void:
	"""主动放弃本局：由 BoardGame 处理安慰奖，管理器只清除存档。"""
	var g := _ensure_game()
	g.give_up()
	delete()


func get_undo_cost() -> Dictionary:
	"""下一次撤销的成本：{free_remaining, diamond_cost}（免费额度内 0，用尽后 10）。"""
	if game == null:
		return {"free_remaining": 0, "diamond_cost": BoardGame.UNDO_DIAMOND_COST}
	return game.get_undo_cost()


# ---------------- 累计进度 / 棋盘等级 ----------------

func get_total_wins() -> int:
	"""累计胜场（跨对局）。"""
	return total_wins


func get_board_level() -> int:
	"""当前棋盘等级（持久化，仅升不降）。"""
	return board_level


func record_win() -> int:
	"""记录一次胜利：累计胜场 +1，按新胜场重算等级。
	若发生升档返回新等级（并发出 level_up 信号），否则返回 -1。等级只升不降。"""
	total_wins += 1
	var new_level := BoardGameData.calc_board_level(total_wins)
	var leveled_up := -1
	if new_level > board_level:
		var old_level := board_level
		board_level = new_level
		leveled_up = new_level
	_save_meta()
	if leveled_up > 0:
		level_up.emit(board_level - 1, board_level)
	return leveled_up


# M2-2.1: 首次三星里程碑奖励（一次性）——大礼包×3 + 钻石，与放弃安慰奖拉开梯度
const FIRST_THREE_STAR_ITEM := "猫罐头大礼包"
const FIRST_THREE_STAR_COUNT := 3
const FIRST_THREE_STAR_DIAMONDS := 20


# D4: Handle first three-star win bonus and persist the one-time claim.
func on_game_won_with_stars(rating: int) -> Dictionary:
	"""Handle star rating after win. Returns bonus info if any."""
	var bonus := {"has_bonus": false, "item_name": "", "count": 0, "diamonds": 0}
	if rating >= 3 and not first_three_star_claimed:
		first_three_star_claimed = true
		_save_meta()
		# M2-2.1: 钻石在管理器内直接入账（单一结算点），物品由 UI 层入库
		if CurrencyManager != null:
			CurrencyManager.add_diamonds(FIRST_THREE_STAR_DIAMONDS, "board_first_three_star")
		bonus = {
			"has_bonus": true,
			"item_name": FIRST_THREE_STAR_ITEM,
			"count": FIRST_THREE_STAR_COUNT,
			"diamonds": FIRST_THREE_STAR_DIAMONDS,
		}
		first_three_star_bonus_reward.emit(FIRST_THREE_STAR_ITEM, FIRST_THREE_STAR_COUNT)
	return bonus


# ---------------- 内部方法 ----------------

func _load_meta() -> void:
	"""从 [meta] section 载入累计胜场与棋盘等级。旧存档无该 section 时用默认值。"""
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	total_wins = int(cfg.get_value(META_SECTION, "total_wins", 0))
	board_level = int(cfg.get_value(META_SECTION, "board_level", BoardGameData.BoardLevel.LV1))
	first_three_star_claimed = bool(cfg.get_value(META_SECTION, "first_three_star_claimed", false))  # D4
	# 自愈：即便 board_level 丢失/损坏，也不低于当前胜场应有的等级（仍保证不降级）
	board_level = maxi(board_level, BoardGameData.calc_board_level(total_wins))


func _save_meta() -> void:
	"""把累计胜场与棋盘等级写回 [meta]，保留其它 section（如 session/state）。"""
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # 载入已有内容以保留 session 存档
	cfg.set_value(META_SECTION, "total_wins", total_wins)
	cfg.set_value(META_SECTION, "board_level", board_level)
	cfg.set_value(META_SECTION, "first_three_star_claimed", first_three_star_claimed)  # D4
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("LevelStateManager._save_meta 失败: %d" % err)


func _ensure_game() -> BoardGame:
	if game == null:
		game = BoardGame.new()
		game.name = "BoardGame"
		add_child(game)
	if not game.game_won.is_connected(_on_game_won):
		game.game_won.connect(_on_game_won)
	return game


func _on_game_won() -> void:
	var star_rating: int = game.star_rating if game != null else 0  # D4
	on_game_won_with_stars(star_rating)  # D4
	won_reward_ready.emit()
