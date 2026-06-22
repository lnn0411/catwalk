extends Control
class_name BoxOpenAnimation

signal animation_finished(slot_index: int, gift_id: String)

var slot_index: int = 0
var gift_id: String = ""
var gift_rarity: String = "common"
var gift_name: String = ""
var gift_category: String = ""
var inventory_position: Vector2 = Vector2.ZERO

var _animating := false
var _anim_time := 0.0
var _fly_progress := 0.0
var _skip_button: Button
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_build_skip_button()

func setup(new_slot_index: int, new_gift_id: String, new_gift_rarity: String = "common", new_gift_name: String = "", new_gift_category: String = "", target_position: Vector2 = Vector2.ZERO) -> void:
	slot_index = new_slot_index; gift_id = new_gift_id; gift_rarity = new_gift_rarity
	gift_name = new_gift_name; gift_category = new_gift_category; inventory_position = target_position
	mouse_filter = Control.MOUSE_FILTER_IGNORE; queue_redraw()

func play(new_slot_index: int = -1, new_gift_id: String = "", new_gift_rarity: String = "", new_gift_name: String = "", new_gift_category: String = "", target_position: Vector2 = Vector2.INF) -> void:
	if new_slot_index >= 0: slot_index = new_slot_index
	if new_gift_id != "": gift_id = new_gift_id
	if new_gift_rarity != "": gift_rarity = new_gift_rarity
	if new_gift_name != "": gift_name = new_gift_name
	if new_gift_category != "": gift_category = new_gift_category
	if target_position != Vector2.INF: inventory_position = target_position
	_anim_time = 0.0; _fly_progress = 0.0; _animating = true
	visible = true; mouse_filter = Control.MOUSE_FILTER_STOP; set_process(true)
	_skip_button.visible = true
	if _tween != null: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_anim_time", 0.3, 0.3)
	_tween.tween_property(self, "_anim_time", 0.5, 0.2)
	_tween.tween_property(self, "_anim_time", 0.8, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_anim_time", 1.0, 0.2)
	_tween.tween_property(self, "_fly_progress", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.finished.connect(_finish_animation)

func skip() -> void:
	if not _animating: return
	if _tween != null: _tween.kill()
	_anim_time = 1.0; _fly_progress = 1.0; queue_redraw(); _finish_animation()

func _process(_delta: float) -> void:
	if _animating: queue_redraw()

func _draw() -> void:
	if not visible: return
	var flash_alpha := _flash_alpha()
	var shade_alpha := 0.48 if _animating else 0.0
	if shade_alpha > 0.0: draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, shade_alpha), true)
	_draw_rarity_effects()
	_draw_box()
	_draw_gift()
	if flash_alpha > 0.0: draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, flash_alpha), true)

func _build_skip_button() -> void:
	_skip_button = Button.new()
	_skip_button.text = "Skip"; _skip_button.flat = true
	_skip_button.size = Vector2(70.0, 30.0); _skip_button.position = Vector2(14.0, 14.0)
	_skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_button.add_theme_font_size_override("font_size", 13)
	_skip_button.pressed.connect(skip); _skip_button.visible = false
	add_child(_skip_button)

func _finish_animation() -> void:
	if not _animating: return
	_animating = false; _anim_time = 0.0; _fly_progress = 0.0
	visible = false; mouse_filter = Control.MOUSE_FILTER_IGNORE; set_process(false)
	_skip_button.visible = false; queue_redraw()
	animation_finished.emit(slot_index, gift_id)

func _draw_box() -> void:
	if _fly_progress > 0.0: return
	var center := size * 0.5 + Vector2(0.0, 42.0)
	var progress := clampf(_anim_time, 0.0, 1.0)
	var scale_value := 1.0; var rotation := 0.0
	if progress < 0.3:
		var p := progress / 0.3; scale_value = lerpf(1.0, 1.2, p); rotation = deg_to_rad(_shake_degrees(p))
	elif progress < 0.5:
		scale_value = 1.2
	else:
		scale_value = lerpf(1.12, 1.0, clampf((progress - 0.5) / 0.3, 0.0, 1.0))
	draw_set_transform(center, rotation, Vector2(scale_value, scale_value))
	if progress < 0.5: _draw_closed_box(Vector2.ZERO)
	else: _draw_open_box(Vector2.ZERO, clampf((progress - 0.5) / 0.3, 0.0, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_gift() -> void:
	var appear := clampf((_anim_time - 0.5) / 0.3, 0.0, 1.0)
	if appear <= 0.0 and _fly_progress <= 0.0: return
	var start := size * 0.5 + Vector2(0.0, -44.0)
	var target := inventory_position
	if target == Vector2.ZERO: target = Vector2(size.x - 56.0, 56.0)
	var center := start.lerp(target, _fly_progress)
	var pop_scale := _gift_pop_scale(appear)
	var fly_scale := lerpf(1.0, 0.42, _fly_progress)
	var alpha := 1.0 - _fly_progress * 0.15
	draw_set_transform(center, 0.0, Vector2(pop_scale * fly_scale, pop_scale * fly_scale))
	_draw_gift_icon(Vector2.ZERO, alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _anim_time >= 0.8 and _fly_progress <= 0.0: _draw_gift_label(start + Vector2(0.0, 74.0))

func _draw_rarity_effects() -> void:
	if _anim_time < 0.8 or _fly_progress > 0.0: return
	var center := size * 0.5 + Vector2(0.0, -44.0)
	var p := clampf((_anim_time - 0.8) / 0.2, 0.0, 1.0)
	match gift_rarity:
		"rare":
			for i in range(16):
				var angle := TAU * float(i) / 16.0; var radius := 42.0 + 38.0 * p + float(i % 3) * 5.0
				draw_circle(center + Vector2(cos(angle), sin(angle)) * radius, 3.5, _c("#76B8FF", 0.2 + p * 0.65))
		"epic":
			draw_rect(Rect2(center + Vector2(-42.0, -220.0), Vector2(84.0, 360.0)), _c("#8E6FA8", 0.16 * p), true)
			draw_line(center + Vector2(-32.0, 120.0), center + Vector2(-8.0, -210.0), _c("#C9A7FF", 0.55 * p), 4.0)
			draw_line(center + Vector2(30.0, 118.0), center + Vector2(8.0, -205.0), _c("#FFFFFF", 0.35 * p), 3.0)
		"legendary":
			for i in range(7):
				var hue := float(i) / 7.0
				draw_arc(center, 58.0 + float(i) * 4.0, TAU * p + hue, TAU * p + hue + PI * 1.45, 80, Color.from_hsv(hue, 0.75, 1.0, 0.72 * p), 4.0)

func _draw_closed_box(center: Vector2) -> void:
	var body := Rect2(center + Vector2(-58.0, -16.0), Vector2(116.0, 74.0))
	var lid := Rect2(center + Vector2(-66.0, -48.0), Vector2(132.0, 32.0))
	draw_rect(body, Color("#FFD166")); draw_rect(lid, Color("#FFE08A"))
	draw_rect(Rect2(body.position.x + body.size.x * 0.43, body.position.y, body.size.x * 0.14, body.size.y), Color("#FF6B6B"))
	draw_rect(Rect2(lid.position.x, lid.position.y + lid.size.y * 0.35, lid.size.x, lid.size.y * 0.26), Color("#FF6B6B"))
	draw_line(center + Vector2(-8.0, -48.0), center + Vector2(-42.0, -82.0), Color("#FF6B6B"), 6.0)
	draw_line(center + Vector2(8.0, -48.0), center + Vector2(42.0, -82.0), Color("#FF6B6B"), 6.0)
	draw_line(center + Vector2(-42.0, -82.0), center + Vector2(-8.0, -82.0), Color("#FF6B6B"), 6.0)
	draw_line(center + Vector2(42.0, -82.0), center + Vector2(8.0, -82.0), Color("#FF6B6B"), 6.0)

func _draw_open_box(center: Vector2, open_p: float) -> void:
	var body := Rect2(center + Vector2(-60.0, -6.0), Vector2(120.0, 64.0))
	draw_rect(body, Color("#D6A54E"))
	draw_rect(Rect2(body.position.x + body.size.x * 0.43, body.position.y, body.size.x * 0.14, body.size.y), Color("#D9534F"))
	var flap_color := Color("#FFE08A")
	var lo := Vector2(-68.0 * open_p, -42.0 * open_p); var ro := Vector2(68.0 * open_p, -42.0 * open_p)
	var lf := PackedVector2Array([center + Vector2(-60.0, -6.0), center + Vector2(-20.0, -38.0) + lo, center + Vector2(0.0, -6.0), center + Vector2(-28.0, 8.0)])
	var rf := PackedVector2Array([center + Vector2(60.0, -6.0), center + Vector2(20.0, -38.0) + ro, center + Vector2(0.0, -6.0), center + Vector2(28.0, 8.0)])
	draw_colored_polygon(lf, flap_color); draw_colored_polygon(rf, flap_color.lightened(0.08))
	draw_polyline(lf + PackedVector2Array([lf[0]]), Color("#9C7340"), 2.0)
	draw_polyline(rf + PackedVector2Array([rf[0]]), Color("#9C7340"), 2.0)

func _draw_gift_icon(center: Vector2, alpha: float) -> void:
	var color := _r(gift_rarity)
	if color.a <= 0.0: color = Color("#FFD166"); color.a *= alpha
	match gift_category:
		"toy":
			draw_circle(center, 28.0, color)
			draw_arc(center, 18.0, -0.4, PI + 0.5, 40, _c("#FFFFFF", alpha), 4.0)
			draw_arc(center + Vector2(2.0, 2.0), 25.0, PI * 0.15, PI * 1.2, 40, color.darkened(0.28), 3.0)
		"flower":
			for i in range(7):
				var a := TAU * float(i) / 7.0
				draw_circle(center + Vector2(cos(a), sin(a)) * 17.0, 12.0, color)
			draw_circle(center, 10.0, _c("#FFD166", alpha))
		_:
			draw_circle(center, 30.0, color); draw_circle(center, 13.0, _c("#FFFFFF", alpha)); draw_circle(center, 6.0, color.darkened(0.2))

func _draw_gift_label(center: Vector2) -> void:
	var text := gift_name if gift_name != "" else gift_id
	var font := get_theme_default_font()
	draw_string(font, center + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22).x * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color.WHITE)
	var rarity_text := gift_rarity.capitalize()
	draw_string(font, center + Vector2(-font.get_string_size(rarity_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x * 0.5, 24.0), rarity_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, _r(gift_rarity))

func _flash_alpha() -> float:
	if _anim_time < 0.3 or _anim_time > 0.5: return 0.0
	return sin((_anim_time - 0.3) / 0.2 * PI) * 0.85

func _shake_degrees(p: float) -> float:
	var wave := sin(p * TAU * 3.0); var amp := 15.0
	if p > 0.66: amp = 3.0
	elif p > 0.33: amp = 8.0
	return wave * amp

func _gift_pop_scale(p: float) -> float:
	if p <= 0.0: return 0.0
	if p < 0.78: return lerpf(0.0, 1.1, 1.0 - pow(1.0 - p / 0.78, 3.0))
	return lerpf(1.1, 1.0, (p - 0.78) / 0.22)

func _r(rarity: String) -> Color:
	match rarity:
		"rare": return Color("#9BB8D4")
		"epic": return Color("#8E6FA8")
		"legendary": return Color("#FFD700")
		_: return Color("#E8D9BA")

func _c(html: String, alpha: float) -> Color:
	var color := Color(html); color.a = alpha; return color
