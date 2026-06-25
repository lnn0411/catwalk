extends SceneTree

func _init() -> void:
	var I = root.get_node("/root/InteractionSystem")
	var ok := true
	I.DEBUG_FAST_COOLDOWN = false
	I.reset_all()

	# per-cat isolation: feeding cat A must not block cat B
	ok = _check(ok, "A初始可feed", I.can_interact("catA", "feed"))
	I.start_cooldown("feed", "catA")
	ok = _check(ok, "A feed后被冷却", I.is_interaction_blocked("feed", "catA"))
	ok = _check(ok, "A feed冷却不影响A pet", not I.is_interaction_blocked("pet", "catA"))
	ok = _check(ok, "A feed冷却不影响B feed", not I.is_interaction_blocked("feed", "catB"))
	ok = _check(ok, "B仍可feed", I.can_interact("catB", "feed"))

	# remaining seconds in range
	var rem: float = I.cat_cooldown_remaining("catA", "feed")
	ok = _check(ok, "A feed剩余在(0,14400]", rem > 0.0 and rem <= 14400.0)
	ok = _check(ok, "B feed剩余为0", I.cat_cooldown_remaining("catB", "feed") == 0.0)

	# expiry via override
	I._override_last_interact("catA", "pet", 121 * 60)  # pet冷却120分钟
	ok = _check(ok, "A pet 121分钟前→可用", not I.is_interaction_blocked("pet", "catA"))
	I._override_last_interact("catA", "pet", 119 * 60)
	ok = _check(ok, "A pet 119分钟前→冷却中", I.is_interaction_blocked("pet", "catA"))

	# save/load round-trip (CSV format)
	I.start_cooldown("play", "catC")
	I._save_cooldowns()
	var before: float = I.cat_cooldown_remaining("catC", "play")
	I._cat_cooldowns = {}
	I._load_cooldowns()
	var after: float = I.cat_cooldown_remaining("catC", "play")
	ok = _check(ok, "存档前play冷却>0", before > 0.0)
	ok = _check(ok, "读档后play冷却≈一致", absf(after - before) < 2.0)

	# inspect raw CSV on disk
	var cfg := ConfigFile.new()
	cfg.load(I.SAVE_PATH)
	var raw := String(cfg.get_value("cooldowns", "catC", ""))
	print("  catC CSV = '%s'" % raw)
	ok = _check(ok, "CSV含play:", raw.begins_with("play:"))

	I.reset_all()
	print("RESULT: %s" % ("ALL PASS" if ok else "SOME FAILED"))
	quit(0 if ok else 1)

func _check(prev: bool, label: String, cond: bool) -> bool:
	print("  [%s] %s" % ["✓" if cond else "✗", label])
	return prev and cond
