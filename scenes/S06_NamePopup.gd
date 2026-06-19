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
var _panel: PanelContainer
var _name_input: LineEdit
var _rng := RandomNumberGenerator.new()

# 美术图占位框架：art 就位则用 TextureRect/StyleBoxTexture，否则保持现有绘制
const ART_OVERLAY_PATH := "res://assets/art/ui/panels/overlay_mask.png"
const ART_PANEL_PATH := "res://assets/art/ui/panels/popup_bg.png"
const ART_CAT_DIR := "res://assets/art/ui/cats/"

var _art_overlay := false

func _ready() -> void:
	super._ready()
	_rng.randomize()
	_build_art_layers()
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

# 用 load() 而非 preload()：遮罩图可能尚未就位，缺文件不应导致编译失败
func _build_art_layers() -> void:
	if ResourceLoader.exists(ART_OVERLAY_PATH):
		var overlay := TextureRect.new()
		overlay.name = "ArtOverlay"
		overlay.texture = load(ART_OVERLAY_PATH)
		overlay.stretch_mode = TextureRect.STRETCH_SCALE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)
		_art_overlay = true

func _draw() -> void:
	if not _art_overlay:  # 遮罩美术未就位时才用代码绘制暗化层
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(Palette.BG_NIGHT_OVERLAY, 0.72))

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(80.0, 273.0)
	_panel.size = Vector2(560.0, 607.0)
	if ResourceLoader.exists(ART_PANEL_PATH):
		var sb := StyleBoxTexture.new()
		sb.texture = load(ART_PANEL_PATH)
		_panel.add_theme_stylebox_override("panel", sb)
	else:
		_panel.add_theme_stylebox_override("panel", _style(Palette.BG_WARM_WHITE, Palette.BORDER_ACTIVE, 8))
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 15)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 32.0
	box.offset_right = -32.0
	box.offset_top = 29.0
	box.offset_bottom = -29.0
	_panel.add_child(box)

	var title := Label.new()
	title.text = "给猫咪取名"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	box.add_child(title)

	# M5：仪式感副标题
	var subtitle := Label.new()
	subtitle.text = "给它起个名字吧——它会记住的"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	box.add_child(subtitle)

	var image: Control
	var portrait_path := ART_CAT_DIR + _species() + "_portrait.png"
	if ResourceLoader.exists(portrait_path):
		var tex := TextureRect.new()
		tex.texture = load(portrait_path)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image = tex
	else:
		var rect := ColorRect.new()
		rect.color = _cat_color()
		image = rect
	image.custom_minimum_size = Vector2(200.0, 200.0)
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(image)

	var meta := Label.new()
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 16)
	meta.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	meta.text = "%s / %s" % [_breed_text(), _rarity_text()]
	box.add_child(meta)

	_name_input = LineEdit.new()
	_name_input.max_length = 16
	_name_input.custom_minimum_size = Vector2(0.0, 47.0)
	_name_input.add_theme_font_size_override("font_size", 18)
	_name_input.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	_name_input.text = _random_name()
	box.add_child(_name_input)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var random_button := Button.new()
	random_button.text = "随机"
	random_button.custom_minimum_size = Vector2(0.0, 45.0)
	random_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_button.pressed.connect(func() -> void: _name_input.text = _random_name())
	row.add_child(random_button)

	var confirm_button := Button.new()
	confirm_button.text = "确认"
	confirm_button.custom_minimum_size = Vector2(0.0, 45.0)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(_confirm_name)
	row.add_child(confirm_button)

func _apply_cat() -> void:
	if _name_input == null:
		return
	var current := String(_cat.display_name) if _cat != null else ""
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

func _breed_text() -> String:
	match _species():
		CatData.BREED_BRITISH:
			return "英短"
		CatData.BREED_SIAMESE:
			return "暹罗"
		_:
			return "橘猫"

func _rarity_text() -> String:
	return String(_cat.rarity) if _cat != null else CatData.RARITY_COMMON

func _cat_color() -> Color:
	match _species():
		CatData.BREED_BRITISH:
			return Palette.CAT_BRIT_LIGHT
		CatData.BREED_SIAMESE:
			return Palette.CAT_SIAM_HIGH
		_:
			return Palette.CAT_ORANGE_LIGHT

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style
