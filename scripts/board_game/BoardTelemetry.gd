class_name BoardTelemetry
extends RefCounted

# ============================================================
# 猫咪合合乐 · 对局埋点本地缓冲（M4-4.2）
# 每局结束写一条 JSONL 到 user://board_telemetry.jsonl，
# 封顶 MAX_RECORDS 条（超出丢最旧）。当前为本地缓冲，
# 供后续上报通道/运营看板接入；无网络依赖。
# 记录字段见 S14_BoardGame._log_game_telemetry。
# ============================================================

const FILE_PATH := "user://board_telemetry.jsonl"
const MAX_RECORDS := 1000


static func log_game(record: Dictionary) -> void:
	var lines := _read_lines()
	lines.append(JSON.stringify(record))
	while lines.size() > MAX_RECORDS:
		lines.pop_front()
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("BoardTelemetry.log_game: 无法写入 %s" % FILE_PATH)
		return
	for line in lines:
		f.store_line(line)
	f.close()


static func read_all() -> Array:
	"""读出全部埋点记录（解析失败的行跳过）"""
	var records: Array = []
	for line in _read_lines():
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			records.append(parsed)
	return records


static func count() -> int:
	return _read_lines().size()


static func clear() -> void:
	if FileAccess.file_exists(FILE_PATH):
		DirAccess.remove_absolute(FILE_PATH)


static func _read_lines() -> Array:
	var lines: Array = []
	if not FileAccess.file_exists(FILE_PATH):
		return lines
	var f := FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		return lines
	while not f.eof_reached():
		var line := f.get_line()
		if not line.is_empty():
			lines.append(line)
	f.close()
	return lines
