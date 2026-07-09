extends Control

# 随行碎碎念浮层（B1 D1 伴走系统 / 特性1 的可见化）
# 作为 autoload 常驻，_ready 时订阅 WalkCompanion.chatter_triggered，
# 触发时弹出一条居中气泡短语：淡入 → 停留 ~2.5s → 淡出，自动消失。
# 根节点全屏且 mouse_filter=IGNORE，不拦截任何输入；气泡置于高层 CanvasLayer，
# 始终盖在 UI 页面（UIManager layer=10）之上。

const FADE_IN := 0.25
const HOLD := 2.5
const FADE_OUT := 0.4

@onready var _bubble: PanelContainer = $Layer/Bubble
@onready var _label: Label = $Layer/Bubble/Phrase

var _tween: Tween


func _ready() -> void:
	_bubble.visible = false
	_bubble.modulate.a = 0.0
	var wc := get_node_or_null("/root/WalkCompanion")
	if wc and wc.has_signal("chatter_triggered"):
		if not wc.chatter_triggered.is_connected(_on_chatter):
			wc.chatter_triggered.connect(_on_chatter)


func _on_chatter(_breed: String, phrase: String) -> void:
	if phrase == "":
		return
	_label.text = phrase
	_bubble.visible = true
	_bubble.modulate.a = 0.0

	# 新气泡打断上一条的淡出，避免叠加/闪烁。
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(_bubble, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_property(_bubble, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(_hide_bubble)


func _hide_bubble() -> void:
	_bubble.visible = false
