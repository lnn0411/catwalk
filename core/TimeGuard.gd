     1|# TimeGuard — 时间反作弊 (Autoload)
     2|# 不要加 class_name：已注册为同名 autoload，class_name 会与单例命名冲突。
     3|# 用独立的 user://timeguard.cfg 存档，不参与 SaveManager 的 save.cfg。
     4|# 核心思路：维护一个单调递增的 last_seen 时间戳；当系统时间回拨到
     5|# last_seen 之前，判定为玩家篡改设备时间，对外仍返回 last_seen 保证单调。
     6|extends Node
     7|
     8|const CFG_PATH := "user://timeguard.cfg"
     9|const SECTION := "timeguard"
    10|const SECTION_ACTIONS := "actions"
    11|const SECONDS_PER_DAY := 86400.0
    12|
    13|var _config := ConfigFile.new()
    14|# 已知的最大时间戳，对外暴露的安全时间永不低于此值。
    15|var _last_seen: float = 0.0
    16|# 最近一次比对中系统时间是否单调（未被回拨）。
    17|var _monotonic: bool = true
    18|
    19|func _ready() -> void:
    20|	_load()
    21|	# 启动即对齐一次，让 _last_seen 追上当前真实时间（若未被回拨）。
    22|	get_safe_unix_time()
    23|
    24|# 当前设备时间是否单调递增（未检测到回拨）。
    25|func is_valid_time() -> bool:
    26|	return _monotonic
    27|
    28|# 返回安全时间戳：保证单调递增。系统时间正常时即为真实时间；
    29|# 被回拨时返回已记录的最大时间戳，并发出告警。
    30|func get_safe_unix_time() -> float:
    31|	var now := Time.get_unix_time_from_system()
    32|	if now < _last_seen:
    33|		_monotonic = false
    34|		push_warning("TimeGuard: 检测到设备时间回拨 now=%.0f < last_seen=%.0f" % [now, _last_seen])
    35|		EventBus.emit_time_anomaly_detected(_last_seen - now)
    36|		return _last_seen
    37|	_monotonic = true
    38|	if now > _last_seen:
    39|		_last_seen = now
    40|		_save()
    41|	return _last_seen
    42|
    43|# 距离上次某操作过去的天数（向下取整）。从未记录过返回 -1。
    44|func days_since_last(action: String) -> int:
    45|	var last := float(_config.get_value(SECTION_ACTIONS, action, -1.0))
    46|	if last < 0.0:
    47|		return -1
    48|	var elapsed := get_safe_unix_time() - last
    49|	if elapsed < 0.0:
    50|		elapsed = 0.0
    51|	return int(elapsed / SECONDS_PER_DAY)
    52|
    53|# 记录某操作的发生时间（使用安全时间戳）。
    54|func record_action(action: String) -> void:
    55|	_config.set_value(SECTION_ACTIONS, action, get_safe_unix_time())
    56|	_save()
    57|
    58|# ---- 内部 ----
    59|func _load() -> void:
    60|	_config = ConfigFile.new()
    61|	var err := _config.load(CFG_PATH)
    62|	if err != OK:
    63|		_config.clear()
    64|	_last_seen = float(_config.get_value(SECTION, "last_seen", 0.0))
    65|
    66|func _save() -> void:
    67|	_config.set_value(SECTION, "last_seen", _last_seen)
    68|	if _config.save(CFG_PATH) != OK:
    69|		push_error("[TimeGuard] Save failed: %s" % CFG_PATH)
    70|