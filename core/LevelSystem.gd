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
