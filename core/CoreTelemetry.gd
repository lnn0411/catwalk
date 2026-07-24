class_name CoreTelemetry
extends RefCounted

# ============================================================
# 核心循环埋点本地缓冲（G4 上线测试门槛 / launch_overhaul_master_plan）
# 与 BoardTelemetry 同款：JSONL 本地缓冲、封顶丢最旧、上报通道未接。
# 事件字典（G4）：
#   hatch        {species, rarity, egg_no}
#   adopt        {petals, gold, level}
#   pool_full    {}                    ← 能量截断（每日首次）
#   ad_speedup   {reward}              ← 广告位#1 今日步行加成
#   box_open     {gift_id, dupe_petals}
#   step_chest   {index, gold}
# ============================================================

const FILE_PATH := "user://core_telemetry.jsonl"
const MAX_RECORDS := 2000


static func log_event(event: String, payload: Dictionary = {}) -> void:
	var record := payload.duplicate()
	record["e"] = event
	record["t"] = Time.get_unix_time_from_system()
	var lines := _read_lines()
	lines.append(JSON.stringify(record))
	while lines.size() > MAX_RECORDS:
		lines.pop_front()
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("CoreTelemetry.log_event: 无法写入 %s" % FILE_PATH)
		return
	for line in lines:
		f.store_line(line)
	f.close()


static func read_all() -> Array:
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
