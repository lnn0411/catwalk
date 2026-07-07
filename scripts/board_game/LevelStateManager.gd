# LevelStateManager — 猫咪合合乐 关卡状态管理器 (Autoload)
# 不要加 class_name：已注册为同名 autoload，class_name 会与单例命名冲突。
# 独立存档 user://cat_merge_save.cfg（ConfigFile），与 InventoryManager 等风格一致。
extends Node

const BoardGame := preload("res://scripts/board_game/BoardGame.gd")
const BoardGameData := preload("res://scripts/board_game/BoardGameData.gd")

const SAVE_PATH := "user://cat_merge_save.cfg"
const SECTION := "session"

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

# 本管理器持有的对局实例（纯逻辑，UI 层通过 game 访问棋盘）
var game: BoardGame = null


func _ready() -> void:
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
	"""删除对局存档。"""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func give_up() -> void:
	"""主动放弃本局：结算安慰奖、清除存档并发出 resigned 信号。"""
	var g := _ensure_game()
	g.give_up()
	delete()
	resigned.emit(CONSOLATION_PRIZE["item"], CONSOLATION_PRIZE["count"], CONSOLATION_PRIZE["text"])


func get_undo_cost() -> Dictionary:
	"""下一次撤销的成本：{free_remaining, diamond_cost}（免费额度内 0，用尽后 10）。"""
	if game == null:
		return {"free_remaining": 0, "diamond_cost": BoardGame.UNDO_DIAMOND_COST}
	return game.get_undo_cost()


# ---------------- 内部方法 ----------------

func _ensure_game() -> BoardGame:
	if game == null:
		game = BoardGame.new()
		game.name = "BoardGame"
		add_child(game)
	if not game.game_won.is_connected(_on_game_won):
		game.game_won.connect(_on_game_won)
	return game


func _on_game_won() -> void:
	won_reward_ready.emit()
