extends Node

var passed := 0
var failed := 0
var results: Array[String] = []

const CatData := preload("res://core/CatData.gd")

func _ready() -> void:
	print("========================================")
	print("  T4-14 CatScreenManager 调试测试")
	print("========================================")

	# 验证 HatchEngine 可用
	print("[DEBUG] HatchEngine 存在: %s" % (HatchEngine != null))
	print("[DEBUG] HatchEngine.cats 数量: %d" % HatchEngine.get_cats().size())
	print("[DEBUG] HatchEngine.get_cats(): %s" % str(HatchEngine.get_cats()))

	# 手动添加一只猫并验证
	var cat = CatData.create("debug_cat_0", CatData.BREED_ORANGE, CatData.RARITY_COMMON, 1)
	HatchEngine.cats.append(cat)
	print("[DEBUG] 添加后 HatchEngine.cats: %d" % HatchEngine.get_cats().size())

	# 验证 get_cat_by_id
	var found = HatchEngine.get_cat_by_id("debug_cat_0")
	print("[DEBUG] get_cat_by_id('debug_cat_0'): %s" % (found != null))

	# 验证 HatchEngine 内部 cats 数组
	print("[DEBUG] HatchEngine.cats 直接: %s" % str(HatchEngine.cats))
	print("[DEBUG] cats[0].id: %s" % str(HatchEngine.cats[0].id if HatchEngine.cats.size() > 0 else "N/A"))

	# 验证 CatScreenManager._cat_exists
	print("[DEBUG] _cat_exists('debug_cat_0'): %s" % CatScreenManager._cat_exists("debug_cat_0"))
	print("[DEBUG] _get_cat_data('debug_cat_0'): %s" % (CatScreenManager._get_cat_data("debug_cat_0") != null))

	# 测试 pin
	var pin_ok = CatScreenManager.pin_cat("debug_cat_0")
	print("[DEBUG] pin_cat('debug_cat_0'): %s" % pin_ok)

	print("\n========================================")
	print("  调试完成")
	print("========================================")
	get_tree().quit()
