extends "res://ui/UIPage.gd"
# ============================================================
# S08 落蛋仪式 —— 入场演出（蛋从天而降 + 能量灌注 + 准备就绪）
# 对照原型时序（GDD 落蛋节奏）：
#   0ms   蛋在屏幕上方画外 (y = -160)
#   200ms 蛋弹性下落到 42% 高度，1s，back-out（cubic-bezier(.34,1.3,.5,1) 手感）
#   700ms 能量条 0→100%，1s
#   1700ms 「好像要出来了」文字淡入，0.4s
#   2600ms 演出结束：emit egg_drop_complete；默认自动进入孵化屋 S06
# 用法：UIManager.push("res://scenes/S08_EggDrop.tscn")
#   若由父级接管收尾，连接 egg_drop_complete 并把 auto_navigate 设为 false。
# ============================================================

signal egg_drop_complete

const EGG_W := 160.0
const EGG_H := 160.0

# 收尾后是否自动跳转孵化屋（父级要自己接管时设 false）
@export var auto_navigate: bool = true

@onready var _egg: TextureRect = %Egg
@onready var _bar_fill: ColorRect = %BarFill
@onready var _ready_text: Label = %ReadyText
@onready var _back_btn: Button = %BackBtn

var _completed := false


func _ready() -> void:
	super._ready()
	_bar_fill.color = Palette.AMBER
	if _back_btn:
		_back_btn.pressed.connect(_finish)
	# 蛋水平居中、起点在画外上方
	var vw := get_viewport_rect().size.x
	_egg.position = Vector2((vw - EGG_W) * 0.5, -EGG_H)
	# 能量条从 0 起步
	_bar_fill.anchor_right = 0.0
	_bar_fill.offset_right = 0.0
	_ready_text.modulate.a = 0.0
	_play_sequence()


func handle_back() -> bool:
	_finish()
	return true


func _play_sequence() -> void:
	var vh := get_viewport_rect().size.y
	var egg_target_y := vh * 0.42 - EGG_H * 0.5

	# ① 蛋下落（弹性 back-out）
	var t_egg := create_tween()
	t_egg.tween_interval(0.2)
	t_egg.tween_property(_egg, "position:y", egg_target_y, 1.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# ② 能量条灌注 0→100%
	var t_bar := create_tween()
	t_bar.tween_interval(0.7)
	t_bar.tween_property(_bar_fill, "anchor_right", 1.0, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# ③ 准备就绪文字淡入
	var t_text := create_tween()
	t_text.tween_interval(1.7)
	t_text.tween_property(_ready_text, "modulate:a", 1.0, 0.4)

	# ④ 收尾
	var t_done := create_tween()
	t_done.tween_interval(2.6)
	t_done.tween_callback(_finish)


func _finish() -> void:
	if _completed:
		return
	_completed = true
	egg_drop_complete.emit()
	if auto_navigate:
		UIManager.replace("res://scenes/S06_HatchPage.tscn")


func _style() -> void:
	# 能量条底槽（半透明暖白）
	var bg := %BarBg as Panel
	if bg:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.12)
		sb.set_corner_radius_all(6)
		bg.add_theme_stylebox_override("panel", sb)
	_bar_fill.color = Palette.AMBER
	# 返回键（默认隐藏，演出期间不打扰）
	if _back_btn:
		_back_btn.add_theme_color_override("font_color", Palette.PAPER_CREAM)
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color = Color(1, 1, 1, 0.14)
		sb2.set_corner_radius_all(17)
		_back_btn.add_theme_stylebox_override("normal", sb2)
