extends Node

var passed := 0
var failed := 0
var results: Array[String] = []

const CatData := preload("res://core/CatData.gd")

func _ready() -> void:
	print("========================================")
	print("  T4-14 CatScreenManager 自动化测试")
	print("========================================")

	test_basic_state()
	test_pin_cat()
	test_pin_limit()
	test_unpin_cat()
	test_force_debut()
	test_rotation_timer()
	test_get_cat_visibility()
	test_save_roundtrip()
	test_set_max_cats()
	test_candidate_selection()

	print("\n========================================")
	print("  结果: %d 通过 / %d 失败" % [passed, failed])
	for line in results:
		print(line)
	print("========================================")
	get_tree().quit()

func assert_eq(what: String, expected, actual) -> void:
	if expected == actual:
		passed += 1
		results.append("  ✅ %s" % what)
	else:
		failed += 1
		results.append("  ❌ %s: 期望=%s 实际=%s" % [what, str(expected), str(actual)])

func assert_true(what: String, actual: bool) -> void:
	if actual:
		passed += 1
		results.append("  ✅ %s" % what)
	else:
		failed += 1
		results.append("  ❌ %s: 期望=true 实际=false" % what)

func assert_false(what: String, actual: bool) -> void:
	if not actual:
		passed += 1
		results.append("  ✅ %s" % what)
	else:
		failed += 1
		results.append("  ❌ %s: 期望=false 实际=true" % what)

func assert_visible_order(what: String, visible: Array, expected: Array) -> void:
	var ok := visible.size() == expected.size()
	if ok:
		for i in range(visible.size()):
			if visible[i] != expected[i]:
				ok = false
				break
	if ok:
		passed += 1
		results.append("  ✅ %s" % what)
	else:
		failed += 1
		results.append("  ❌ %s: 期望=%s 实际=%s" % [what, str(expected), str(visible)])

func _ensure_mock_cats(count: int) -> void:
	# 直接清除并重新添加，避免 HatchEngine 已有猫的影响
	var current_ids := {}
	for c in HatchEngine.cats:
		var cid = c.id if c is CatData else ""
		if cid != "":
			current_ids[cid] = true
	var added := 0
	for i in range(count):
		var cid := "test_cat_%d" % i
		if not current_ids.has(cid):
			var cat = CatData.create(cid, CatData.BREED_ORANGE, CatData.RARITY_COMMON, i + 1)
			HatchEngine.cats.append(cat)
			added += 1
	if added > 0:
		print("[Test] added %d mock cats, total=%d" % [added, HatchEngine.cats.size()])

# ── Test Cases ──

func test_basic_state() -> void:
	CatScreenManager.load_state({})
	var visible := CatScreenManager.get_visible_cats()
	assert_eq("初始可见猫为空数组", 0, visible.size())
	assert_eq("max_cats 默认 6", 6, CatScreenManager.max_cats)
	assert_eq("max_rotating 默认 2", 2, CatScreenManager.max_rotating)
	assert_false("初始不触发轮换", CatScreenManager.is_rotation_due())

func test_pin_cat() -> void:
	_ensure_mock_cats(6)
	CatScreenManager.load_state({})

	assert_true("pin 第一只猫成功", CatScreenManager.pin_cat("test_cat_0"))
	assert_true("pin 第二只猫成功", CatScreenManager.pin_cat("test_cat_1"))
	assert_true("pin 第三只猫成功", CatScreenManager.pin_cat("test_cat_2"))
	assert_true("pin 第四只猫成功", CatScreenManager.pin_cat("test_cat_3"))

	var visible := CatScreenManager.get_visible_cats()
	assert_eq("pin 4只后 visible 共6只（4固定+2轮换）", 6, visible.size())
	assert_eq("pinned_cats 共 4 只", 4, CatScreenManager.pinned_cats.size())

func test_pin_limit() -> void:
	CatScreenManager.load_state({})
	_ensure_mock_cats(6)

	CatScreenManager.pin_cat("test_cat_0")
	CatScreenManager.pin_cat("test_cat_1")
	CatScreenManager.pin_cat("test_cat_2")
	CatScreenManager.pin_cat("test_cat_3")
	# 第5次 pin 应该失败
	assert_false("第5次 pin 返回 false", CatScreenManager.pin_cat("test_cat_4"))

func test_unpin_cat() -> void:
	CatScreenManager.load_state({})
	_ensure_mock_cats(6)

	CatScreenManager.pin_cat("test_cat_0")
	CatScreenManager.pin_cat("test_cat_1")
	assert_eq("unpin 前固定2只", 2, CatScreenManager.pinned_cats.size())

	assert_true("unpin 成功", CatScreenManager.unpin_cat("test_cat_0"))
	assert_eq("unpin 后固定1只", 1, CatScreenManager.pinned_cats.size())
	assert_false("unpin 不存在的猫返回 false", CatScreenManager.unpin_cat("nonexistent"))

func test_force_debut() -> void:
	CatScreenManager.load_state({})
	_ensure_mock_cats(6)

	CatScreenManager.pin_cat("test_cat_0")
	assert_true("force_debut 未固定猫成功", CatScreenManager.force_debut("test_cat_1"))
	assert_true("force_debut 已固定猫成功", CatScreenManager.force_debut("test_cat_0"))
	assert_false("force_debut 不存在猫失败", CatScreenManager.force_debut("nonexistent"))

	# 验证 debut 时间被设置
	var vis := CatScreenManager.get_cat_visibility("test_cat_1")
	assert_true("debut 猫 is_debut=true", vis.get("is_debut", false))
	assert_true("debut 猫 debut_until > 0", int(vis.get("debut_until", 0)) > 0)

func test_rotation_timer() -> void:
	CatScreenManager.load_state({})
	var timer := CatScreenManager.get_rotation_timer()
	assert_true("rotation_timer 有 last_rotation", timer.has("last_rotation"))
	assert_true("rotation_timer 有 next_rotation", timer.has("next_rotation"))
	assert_true("rotation_timer 有 seconds_remaining", timer.has("seconds_remaining"))
	assert_true("rotation_timer 有 is_due", timer.has("is_due"))
	assert_eq("interval_minutes = 30", 30, int(timer.get("interval_minutes", 0)))
	assert_false("初始 timer 未到期", timer.get("is_due", true))

func test_get_cat_visibility() -> void:
	CatScreenManager.load_state({})
	_ensure_mock_cats(3)

	CatScreenManager.pin_cat("test_cat_0")

	var vis := CatScreenManager.get_cat_visibility("test_cat_0")
	assert_true("可见性: exists=true", vis.get("exists", false))
	assert_true("可见性: is_pinned=true", vis.get("is_pinned", false))
	assert_true("可见性: is_visible=true", vis.get("is_visible", false))

	var vis2 := CatScreenManager.get_cat_visibility("nonexistent")
	assert_false("不存在猫: exists=false", vis2.get("exists", true))

func test_save_roundtrip() -> void:
	CatScreenManager.load_state({})
	_ensure_mock_cats(6)

	CatScreenManager.pin_cat("test_cat_0")
	CatScreenManager.pin_cat("test_cat_1")
	CatScreenManager.force_debut("test_cat_2")

	var saved := CatScreenManager.save_state()
	assert_eq("save 含 pinned_cats", 2, Array(saved.get("pinned_cats", [])).size())
	assert_true("save 含 cat_debut_times", Dictionary(saved.get("cat_debut_times", {})).size() > 0)
	assert_eq("save 含 max_cats=6", 6, int(saved.get("max_cats", 0)))

	# reload
	CatScreenManager.load_state(saved)
	var visible := CatScreenManager.get_visible_cats()
	assert_eq("reload 后 visible 共4只（2固定+2轮换）", 4, visible.size())
	assert_true("reload 后 test_cat_0 可见", visible.has("test_cat_0"))

	# 空 data 重置
	CatScreenManager.load_state({})
	assert_eq("空 data 重置后 0 只固定", 0, CatScreenManager.pinned_cats.size())

func test_set_max_cats() -> void:
	CatScreenManager.load_state({})

	CatScreenManager.set_max_cats(8)
	assert_eq("set_max_cats(8) 后 max_cats=8", 8, CatScreenManager.max_cats)
	assert_eq("set_max_cats(8) 后 max_rotating=4", 4, CatScreenManager.max_rotating)

	CatScreenManager.set_max_cats(6)
	assert_eq("set_max_cats(6) 后 max_cats=6", 6, CatScreenManager.max_cats)
	assert_eq("set_max_cats(6) 后 max_rotating=2", 2, CatScreenManager.max_rotating)

	CatScreenManager.set_max_cats(100)
	assert_eq("set_max_cats(100) 被 clamp 到 8", 8, CatScreenManager.max_cats)

	CatScreenManager.set_max_cats(5)
	assert_eq("set_max_cats(5) 被 clamp 到 6", 6, CatScreenManager.max_cats)

func test_candidate_selection() -> void:
	CatScreenManager.load_state({})
	_ensure_mock_cats(6)

	# 没有固定猫时，候选池应有 2 只 rotating
	CatScreenManager._fill_rotating_gaps()
	assert_eq("候选填充后 rotating 有 2 只", 2, CatScreenManager.rotating_cats.size())
