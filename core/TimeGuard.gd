# TimeGuard — 时间反作弊 (Autoload)
# 不要加 class_name：已注册为同名 autoload，class_name 会与单例命名冲突。
extends Node

const CFG_PATH := "user://timeguard.cfg"
const SECTION := "timeguard"
const SECTION_ACTIONS := "actions"
const SECONDS_PER_DAY := 86400.0

var _config := ConfigFile.new()
var _last_seen: float = 0.0
var _monotonic: bool = true

func _ready() -> void:
	_load()
	get_safe_unix_time()

func is_valid_time() -> bool:
	return _monotonic

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

func days_since_last(action: String) -> int:
	var last := float(_config.get_value(SECTION_ACTIONS, action, -1.0))
	if last < 0.0:
		return -1
	var elapsed := get_safe_unix_time() - last
	if elapsed < 0.0:
		elapsed = 0.0
	return int(elapsed / SECONDS_PER_DAY)

func record_action(action: String) -> void:
	_config.set_value(SECTION_ACTIONS, action, get_safe_unix_time())
	_save()

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
