extends Control

signal cell_pressed(postcard_id: String)

const LOCATION_COLORS := {
	"convenience_store": Color(0.9, 0.7, 0.3),
	"park_bench": Color(0.5, 0.8, 0.5),
	"subway_station": Color(0.6, 0.6, 0.7),
	"bookstore": Color(0.6, 0.5, 0.4),
	"cafe": Color(0.8, 0.5, 0.4),
	"hospital_corridor": Color(0.7, 0.7, 0.8),
	"sky_bridge": Color(0.4, 0.6, 0.8),
	"night_market": Color(0.8, 0.5, 0.5),
	"playground": Color(0.7, 0.8, 0.4),
	"rainy_day": Color(0.5, 0.6, 0.7),
	"hidden": Color(0.8, 0.6, 0.8),
	"seasonal": Color(0.6, 0.8, 0.8),
	"achievement": Color(0.8, 0.7, 0.3),
}

var _postcard_id: String = ""
var _location_name: String = ""
var _location_type: String = ""
var _is_collected: bool = false
var _is_known: bool = false
var _tex: Texture2D = null


func _ready() -> void:
	custom_minimum_size = Vector2(330, 220)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	# 圆角底框（StyleBoxFlat，同孵化室风格）
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.4, 0.35, 0.28, 0.6)
	sb.corner_detail = 12
	add_theme_stylebox_override("panel", sb)


func setup(postcard_data, is_collected: bool, is_known: bool) -> void:
	_postcard_id = postcard_data.id
	_location_name = postcard_data.location_name if "location_name" in postcard_data else String(postcard_data.id)
	_location_type = postcard_data.location_type if "location_type" in postcard_data else ""
	_is_collected = is_collected
	_is_known = is_known
	_load_texture()
	queue_redraw()


func _load_texture() -> void:
	_tex = null
	if not _is_collected:
		return
	var tex_path := "res://assets/art/postcards/%s.png" % _postcard_id
	# 优先走 Godot 资源缓存
	if ResourceLoader.exists(tex_path, "Texture2D"):
		_tex = load(tex_path) as Texture2D
		if _tex != null:
			return
	# 缓存未命中：从文件系统直接读取（绕过 Godot 导入系统）
	var img := Image.new()
	var abs_path := ProjectSettings.globalize_path(tex_path)
	if img.load(abs_path) == OK:
		_tex = ImageTexture.create_from_image(img)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cell_pressed.emit(_postcard_id)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var font := get_theme_default_font()
	var font_size := 22
	var small_size := 16

	if _is_collected:
		# 圆角底框
		var sb := get_theme_stylebox("panel")
		if sb:
			draw_style_box(sb, rect)
		if _tex:
			draw_texture_rect(_tex, rect, false)
			# 四角画背景色圆遮住图片的直角
			var r := 12.0
			var bg := Color(0.96, 0.94, 0.88)
			for c in [Vector2(r, r), Vector2(size.x - r, r), Vector2(r, size.y - r), Vector2(size.x - r, size.y - r)]:
				draw_circle(c, r, bg)
		else:
			var col: Color = LOCATION_COLORS.get(_location_type, Color(0.6, 0.6, 0.6))
			draw_rect(rect, col, true)
			_draw_centered_text(font, _location_name, font_size, Color(0.1, 0.1, 0.1), size.y * 0.45)
			_draw_centered_text(font, "美术待补", small_size, Color(0.2, 0.2, 0.2, 0.7), size.y * 0.75)
		# 底部地点名条
		var bar := Rect2(0, rect.size.y - 36, rect.size.x, 36)
		draw_rect(bar, Color(0, 0, 0, 0.45), true)
		_draw_centered_text(font, _location_name, 18, Color.WHITE, rect.size.y - 8)
		# 收集标记 (右上角圆点)
		draw_circle(Vector2(size.x - 28, 28), 12, Color(1, 1, 1, 0.9))
		draw_circle(Vector2(size.x - 28, 28), 7, Color(0.3, 0.7, 0.4))
	elif _is_known:
		draw_rect(rect, Color(0.55, 0.55, 0.55), true)
		draw_rect(rect, Color(0.3, 0.3, 0.3), false, 3.0)
		_draw_centered_text(font, _location_name, font_size, Color(0.2, 0.2, 0.2), size.y * 0.45)
		_draw_lock(Vector2(size.x - 30, 30))
		_draw_centered_text(font, "美术待补", small_size, Color(0.25, 0.25, 0.25, 0.7), size.y * 0.75)
	else:
		draw_rect(rect, Color(0.1, 0.1, 0.1), true)
		draw_rect(rect, Color(0.3, 0.3, 0.3), false, 3.0)
		_draw_centered_text(font, "?", 60, Color(0.6, 0.6, 0.6), size.y * 0.55)
		_draw_centered_text(font, "美术待补", small_size, Color(0.5, 0.5, 0.5, 0.7), size.y * 0.85)


func _draw_centered_text(font: Font, text: String, font_size: int, color: Color, y_baseline: float) -> void:
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2((size.x - text_w) * 0.5, y_baseline)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_lock(center: Vector2) -> void:
	var body := Rect2(center.x - 11, center.y - 2, 22, 18)
	draw_rect(body, Color(0.85, 0.75, 0.3), true)
	# 锁环
	draw_arc(Vector2(center.x, center.y - 2), 8, PI, TAU, 16, Color(0.85, 0.75, 0.3), 3.0)
