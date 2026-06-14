# TimeGuard — 时间反作弊 (Autoload)
# 不要加 class_name：已注册为同名 autoload，class_name 会与单例命名冲突。
# 用独立的 user://timeguard.cfg 存档，不参与 SaveManager 的 save.cfg。
# 核心思路：维护一个单调递增的 last_seen 时间戳；当系统时间回拨到
# last_seen 之前，判定为玩家篡改设备时间，对外仍返回 last_seen 保证单调。
extends Node

const CFG_PATH := "user://timeguard.cfg"
const SECTION := "timeguard"
const SECTION_ACTIONS := "actions"
const SECONDS_PER_DAY := 86400.0

var _config := ConfigFile.new()
# 已知的最大时间戳，对外暴露的安全时间永不低于此值。
var _last_seen: float = 0.0
# 最近一次比对中系统时间是否单调（未被回拨）。
var _monotonic: bool = true

func _ready() -> void:
	_load()
	# 启动即对齐一次，让 _last_seen 追上当前真实时间（若未被回拨）。
	get_safe_unix_time()

# 当前设备时间是否单调递增（未检测到回拨）。
func is_valid_time() -> bool:
	return _monotonic

# 返回安全时间戳：保证单调递增。系统时间正常时即为真实时间；
# 被回拨时返回已记录的最大时间戳，并发出告警。
func get_safe_unix_time() -> float:
	var now := Time.get_unix_time_from_system()
	if now < _last_seen:
		_monotonic = false
		push_warning("TimeGuard: 检测到设备时间回拨 now=%.0f < last_seen=%.0f" % [now, _last_seen])
		return _last_seen
	_monotonic = true
	if now > _last_seen:
		_last_seen = now
		_save()
	return _last_seen

# 距离上次某操作过去的天数（向下取整）。从未记录过返回 -1。
func days_since_last(action: String) -> int:
	var last := float(_config.get_value(SECTION_ACTIONS, action, -1.0))
	if last < 0.0:
		return -1
	var elapsed := get_safe_unix_time() - last
	if elapsed < 0.0:
		elapsed = 0.0
	return int(elapsed / SECONDS_PER_DAY)

# 记录某操作的发生时间（使用安全时间戳）。
func record_action(action: String) -> void:
	_config.set_value(SECTION_ACTIONS, action, get_safe_unix_time())
	_save()

# ---- 内部 ----
func _load() -> void:
	_config = ConfigFile.new()
	var err := _config.load(CFG_PATH)
	if err != OK:
		_config.clear()
	_last_seen = float(_config.get_value(SECTION, "last_seen", 0.0))

func _save() -> void:
	_config.set_value(SECTION, "last_seen", _last_seen)
	if _config.save(CFG_PATH) != OK:
		push_error("[TimeGuard] Save failed: %s" % CFG_PATH)
