extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

var _cat
var _elapsed := 0.0
var _overlay_shown := false
var _waiting_for_name := false
var _phase := 1

func _ready() -> void:
	super._ready()
	set_process(true)

func _on_page_setup(data: Dictionary) -> void:
	_cat = data.get("cat", null)

func _process(delta: float) -> void:
	if _waiting_for_name:
		queue_redraw()
		return
	_elapsed += delta
	_update_phase()
	queue_redraw()

func handle_back() -> bool:
	return true

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_CEMENT)
	var center := screen * 0.5
	match _phase:
		1:
			_draw_cracking_egg(center)
		2:
			_draw_flash_silhouette(center)
		3:
			_draw_reveal(center, 1.0)
		4:
			var zoom: float = clamp(1.0 - (_elapsed - _phase4_start()) / 1.5 * 0.35, 0.65, 1.0)
			_draw_reveal(center, zoom)

func _update_phase() -> void:
	var skip_phase_2 := _is_first_orange()
	if _elapsed < 3.0:
		_phase = 1
	elif not skip_phase_2 and _elapsed < 6.5:
		_phase = 2
	elif _elapsed < _phase4_start():
		_phase = 3
		_show_name_popup_once()
	else:
		_phase = 4
		if _elapsed >= _phase4_start() + 1.5:
			UIManager.pop_to_root()

func _phase4_start() -> float:
	return 5.0 if _is_first_orange() else 8.5

func _show_name_popup_once() -> void:
	if _overlay_shown:
		return
	_overlay_shown = true
	_waiting_for_name = true
	UIManager.show_overlay("res://scenes/S06_NamePopup.tscn", {"cat": _cat, "hatch_show": self})

func resume_after_name_popup() -> void:
	_waiting_for_name = false
	_elapsed = _phase4_start()

func _is_first_orange() -> bool:
	if _cat == null:
		return false
	return String(_cat.species) == CatData.BREED_ORANGE and int(_cat.hatch_index) == 1

func _draw_cracking_egg(center: Vector2) -> void:
	var crack: float = clamp(_elapsed / 3.0, 0.0, 1.0)
	draw_ellipse(center + Vector2(0.0, -80.0), 150.0, 200.0, _cat_color_light())
	for i in range(4):
		var x := center.x - 36.0 + i * 24.0
		draw_line(Vector2(x, center.y - 180.0 + i * 28.0), Vector2(x + 28.0 * crack, center.y - 148.0 + i * 28.0), Palette.TEXT_PRIMARY, 5.0)
	_draw_centered_text("蛋壳裂开了", center.y + 210.0, 30, Palette.TEXT_PRIMARY)

func _draw_flash_silhouette(center: Vector2) -> void:
	var pulse := (sin(_elapsed * 8.0) + 1.0) * 0.5
	draw_circle(center, 310.0 + pulse * 30.0, Color(Palette.RARITY_RARE, 0.35))
	_draw_cat_shape(center, Palette.TEXT_PRIMARY, 1.15)
	_draw_centered_text("有个身影出现", center.y + 270.0, 30, Palette.TEXT_PRIMARY)

func _draw_reveal(center: Vector2, zoom: float) -> void:
	draw_circle(center, 320.0 * zoom, Color(_rarity_color(), 0.22))
	_draw_cat_shape(center, _cat_color_mid(), zoom)
	var cat_name: String = String(_cat.display_name) if _cat != null else "New Cat"
	_draw_centered_text(cat_name, center.y + 300.0 * zoom, 36, Palette.TEXT_PRIMARY)

func _draw_cat_shape(center: Vector2, color: Color, scale_value: float) -> void:
	draw_circle(center + Vector2(0.0, -70.0) * scale_value, 95.0 * scale_value, color)
	draw_circle(center + Vector2(0.0, 84.0) * scale_value, 120.0 * scale_value, color)
	draw_polygon(PackedVector2Array([
		center + Vector2(-70.0, -140.0) * scale_value,
		center + Vector2(-26.0, -198.0) * scale_value,
		center + Vector2(-10.0, -124.0) * scale_value,
	]), PackedColorArray([color, color, color]))
	draw_polygon(PackedVector2Array([
		center + Vector2(70.0, -140.0) * scale_value,
		center + Vector2(26.0, -198.0) * scale_value,
		center + Vector2(10.0, -124.0) * scale_value,
	]), PackedColorArray([color, color, color]))

func _cat_color_mid() -> Color:
	if _cat == null:
		return Palette.CAT_ORANGE_MID
	match String(_cat.species):
		CatData.BREED_BRITISH:
			return Palette.CAT_BRIT_MID
		CatData.BREED_SIAMESE:
			return Palette.CAT_SIAM_BODY
		_:
			return Palette.CAT_ORANGE_MID

func _cat_color_light() -> Color:
	if _cat == null:
		return Palette.CAT_ORANGE_LIGHT
	match String(_cat.species):
		CatData.BREED_BRITISH:
			return Palette.CAT_BRIT_LIGHT
		CatData.BREED_SIAMESE:
			return Palette.CAT_SIAM_HIGH
		_:
			return Palette.CAT_ORANGE_LIGHT

func _rarity_color() -> Color:
	if _cat == null:
		return Palette.AMBER
	match String(_cat.rarity):
		CatData.RARITY_RARE:
			return Palette.RARITY_RARE
		CatData.RARITY_EPIC:
			return Palette.RARITY_EPIC
		CatData.RARITY_LEGENDARY:
			return Palette.RARITY_LEG_A
		_:
			return Palette.AMBER

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((get_viewport_rect().size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
