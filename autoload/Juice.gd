extends Node

# ============================================================
# Juice —— 全局触觉反馈（手机震动）autoload
# ------------------------------------------------------------
# 注册：project.godot [autoload] 加一行
#   Juice="*res://autoload/Juice.gd"
# （建议放在 Palette 之后即可，无依赖顺序要求）
#
# 用法（任何脚本一行调用）：
#   Juice.tap()     轻震 20ms   —— 按钮按下、点猫、切Tab
#   Juice.hit()     中震 50ms   —— 蛋裂、获得物品、确认操作
#   Juice.reward()  长震 120ms  —— 揭晓、稀有出货、重要奖励
#   Juice.pattern_crack()   蛋裂三连震（孵化演出 Phase1 专用）
#   Juice.pattern_legendary() legendary 揭晓双长震
#
# 说明：
# - Input.vibrate_handheld 仅在移动端生效；编辑器/桌面自动无害跳过。
# - Android 需要 VIBRATE 权限：Godot 导出预设里勾选 permissions/vibrate
#   （或导出模板默认带）。真机如无震动先查这里。
# - 节流：同类震动 80ms 内不重复触发，避免连点变"电钻"。
# ============================================================

var _last_ms: int = 0
const THROTTLE_MS := 80

func _vibrate(duration_ms: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_ms < THROTTLE_MS:
		return
	_last_ms = now
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)

func tap() -> void:
	_vibrate(20)

func hit() -> void:
	_vibrate(50)

func reward() -> void:
	_vibrate(120)

# 蛋裂三连震：短-短-中，配合 Phase1 裂纹加深
func pattern_crack() -> void:
	_vibrate(30)
	await get_tree().create_timer(0.18).timeout
	_vibrate(30)
	await get_tree().create_timer(0.18).timeout
	_vibrate(60)

# legendary 揭晓：长震-停-长震（"憋一下再爆"的触觉版）
func pattern_legendary() -> void:
	_vibrate(120)
	await get_tree().create_timer(0.25).timeout
	_vibrate(160)
