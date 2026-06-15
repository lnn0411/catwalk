# TimeGuard — 时间反作弊 (Autoload)
extends Node

const CFG_PATH := "user://timeguard.cfg"
const SECTION := "timeguard"
const SECTION_ACTIONS := "actions"
const SECONDS_PER_DAY := 86400.0
const MAX_FORWARD_JUMP := 86400.0
const MIN_VALID_UNIX_TIME := 1704067200.0

var _config := ConfigFile.new()
var _last_seen: float = 0.0
var _tampered: bool = false
var _loaded := false

func _ready() -> void:
	_load()
	_peek_safe_time()

func is_valid_time() -> bool:
	return not _tampered

func get_safe_unix_time() -> float:
	var t := _peek_safe_time()
	if not _tampered and not _loaded:
		_loaded = true
	return t

func _peek_safe_time() -> float:
	var now := Time.get_unix_time_from_system()

	if now < MIN_VALID_UNIX_TIME:
		_tampered = true
		push_error("TimeGuard: 系统时间异常(早于2024年) now=%.0f" % now)
		return max(now, _last_seen)

	if _last_seen > 0.0:
		if now < _last_seen:
			_tampered = true
			push_warning("TimeGuard: 检测到设备时间回拨 now=%.0f < last_seen=%.0f" % [now, _last_seen])
			return _last_seen

		if now - _last_seen > MAX_FORWARD_JUMP:
			_tampered = true
			push_warning("TimeGuard: 检测到设备时间大幅前跳 %.0fs" % (now - _last_seen))
			return _last_seen

	if now > _last_seen:
		_last_seen = now
		_save()
	return _last_seen

func days_since_last(action: String) -> int:
	var last := float(_config.get_value(SECTION_ACTIONS, action, -1.0))
	if last < 0.0:
		return -1
	var elapsed := _peek_safe_time() - last
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
