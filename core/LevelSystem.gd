extends Node

const THRESHOLDS: Array = [0, 5000, 15000, 30000, 50000, 75000, 100000, 120000, 138000, 150000]
const MAX_EXP: int = 150000

static func get_breed_multiplier(breed: String) -> float:
	match breed:
		"orange":
			return 1.0
		"british":
			return 1.2
		"siamese":
			return 1.5
		_:
			return 1.0

static func calc_exp(steps: int, multiplier: float) -> int:
	return int(max(steps, 0) * multiplier)

# P1 经验软拐点（修 A4）：日步数 ≤4000 全额、超出部分 50%；品种系数在拐点后乘。
# 必须以「当日累计步数」调用并做边际差值，不可对 delta 直接套拐点。
const EXP_KNEE_STEPS := 4000
const EXP_OVER_RATIO := 0.5

static func calc_daily_exp(today_steps: int, multiplier: float) -> int:
	var s: int = max(today_steps, 0)
	var effective: float = float(min(s, EXP_KNEE_STEPS)) + float(max(s - EXP_KNEE_STEPS, 0)) * EXP_OVER_RATIO
	return int(effective * multiplier)

static func get_level(exp: int) -> int:
	var level: int = 1
	for i in range(THRESHOLDS.size()):
		if exp >= THRESHOLDS[i]:
			level = i + 1
		else:
			break
	return level

static func is_max_level(exp: int) -> bool:
	return exp >= MAX_EXP

static func get_exp_to_next(exp: int) -> int:
	if is_max_level(exp):
		return 0
	for t in THRESHOLDS:
		if exp < t:
			return t - exp
	return 0

static func reset_all() -> void:
	pass
