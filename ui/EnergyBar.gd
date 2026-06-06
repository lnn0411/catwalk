extends Node2D

@export var value: float = 0.0
@export var bar_width: float = 240.0

const HEIGHT = 8.0
const RADIUS = 4.0

func _ready():
	set_process(true)

func _process(_delta):
	queue_redraw()

func _draw():
	var bg_rect = Rect2(0, 0, bar_width, HEIGHT)

	# 背景槽
	_draw_rounded_rect(bg_rect, RADIUS, Color("#DDD5C8"))

	# 填充
	var fill_w = bar_width * clamp(value, 0.0, 1.0)
	if fill_w > RADIUS * 2:
		_draw_rounded_rect(Rect2(0, 0, fill_w, HEIGHT), RADIUS, Palette.AMBER)

	# 满槽发光脉冲（value >= 0.9）
	if value >= 0.9:
		var pulse = (sin(Time.get_ticks_msec() * 0.004) + 1.0) * 0.5
		var glow = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, pulse * 0.5)
		if fill_w > RADIUS * 2:
			_draw_rounded_rect(Rect2(0, 0, fill_w, HEIGHT), RADIUS, glow)

func _draw_rounded_rect(rect: Rect2, radius: float, color: Color):
	draw_rect(Rect2(rect.position.x + radius, rect.position.y,
		rect.size.x - radius * 2, rect.size.y), color)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
