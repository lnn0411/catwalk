extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

const NAME_POOLS_CN := {
	CatData.BREED_ORANGE: ["大胖", "橘子", "小橘", "阿福", "蛋黄"],
	CatData.BREED_BRITISH: ["绅士", "阿蓝", "小雪", "团团", "圆圆"],
	CatData.BREED_SIAMESE: ["小话痨", "芝麻", "点点", "墨墨", "阿喵"],
}

const NAME_POOLS_EN := {
	CatData.BREED_ORANGE: ["Mango", "Sunny", "Biscuit", "Cheeto", "Marmalade"],
	CatData.BREED_BRITISH: ["Ash", "Slate", "Chester", "Earl", "Sterling"],
	CatData.BREED_SIAMESE: ["Coco", "Pepper", "Mochi", "Sable", "Latte"],
}

var _cat
var _hatch_show
var _panel: Control
var _name_input: LineEdit
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	_rng.randomize()
	_build_ui()
	_apply_cat()
	# M5：弹窗从底部滑入（300ms ease-out，GDD §3.8 同款节奏）
	var final_y := _panel.position.y
	_panel.position.y = get_viewport_rect().size.y
	var t := create_tween()
	t.tween_property(_panel, "position:y", final_y, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _on_page_setup(data: Dictionary) -> void:
	_cat = data.get("cat", null)
	_hatch_show = data.get("hatch_show", null)

func handle_back() -> bool:
	return true

func _draw() -> void:
	# %OverlayBg 已提供暗化遮罩；缺该节点时才回退到代码绘制
	if not has_node("%OverlayBg"):
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(Palette.BG_NIGHT_OVERLAY, 0.72))

func _build_ui() -> void:
	_panel = %PopupBg
	(%NameLabel as Label).text = "给猫咪取名"

	_name_input = %NameInput
	_name_input.text = _random_name()

	(%RandomBtn as TextureButton).pressed.connect(func() -> void: _name_input.text = _random_name())
	(%ConfirmBtn as TextureButton).pressed.connect(_confirm_name)

func _apply_cat() -> void:
	if _name_input == null:
		return
	var current: String = String(_cat.display_name) if _cat != null else ""
	# 「未命名+品种」默认名视为尚未命名 → 预填一个随机建议名给玩家
	if current.length() >= 2 and not CatData.is_default_name(current):
		_name_input.text = current
	else:
		_name_input.text = _random_name()

func _confirm_name() -> void:
	if _cat == null:
		UIManager.close_overlay()
		return
	var value := _name_input.text.strip_edges()
	if value.length() < 2:
		value = _random_name()
	if value.length() > 16:
		value = value.substr(0, 16)
	_cat.display_name = value
	if SaveManager:
		SaveManager.save_all()
	if HatchEngine and HatchEngine.current_companion_cat_id == "":
		HatchEngine.current_companion_cat_id = _cat.id
		SaveManager.save_all()
	# M5：确认瞬间——触觉 + 面板弹一下（"这是我的猫了"的时刻），再继续
	var j := get_node_or_null("/root/Juice")
	if j: j.hit()
	_panel.pivot_offset = _panel.size * 0.5
	var t := create_tween()
	t.tween_property(_panel, "scale", Vector2(1.06, 1.06), 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_IN)
	await t.finished
	if _hatch_show != null and is_instance_valid(_hatch_show) and _hatch_show.has_method("resume_after_name_popup"):
		_hatch_show.call_deferred("resume_after_name_popup")
	UIManager.close_overlay()

func _random_name() -> String:
	var pools := NAME_POOLS_CN if OS.get_locale_language() == "zh" else NAME_POOLS_EN
	var pool := Array(pools.get(_species(), pools[CatData.BREED_ORANGE]))
	return String(pool[_rng.randi_range(0, pool.size() - 1)])

func _species() -> String:
	return String(_cat.species) if _cat != null else CatData.BREED_ORANGE
