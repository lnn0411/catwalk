# DebugPanel — 配饰 Slot 校准滑块 (GDD v2.17 §5.6)
# 实时拖拽控制猫咪配饰的 Offset/Scale，输出 JSON 配置
extends Control

var _accessory_target: Node2D
var _sliders := {}

func _ready() -> void:
	_build_sliders()
	_build_output_button()

func _build_sliders() -> void:
	var labels := ["Offset X", "Offset Y", "Scale X", "Scale Y"]
	var defaults := [0.0, 0.0, 1.0, 1.0]
	var mins := [-100.0, -100.0, 0.1, 0.1]
	var maxs := [100.0, 100.0, 2.0, 2.0]
	var steps := [0.5, 0.5, 0.05, 0.05]

	var y_pos := 320.0  # 滑块起始 Y 位置
	for i in range(4):
		var label := Label.new()
		label.text = labels[i]
		label.position = Vector2(510.0, y_pos)
		add_child(label)

		var slider := HSlider.new()
		slider.name = labels[i]
		slider.min_value = mins[i]
		slider.max_value = maxs[i]
		slider.step = steps[i]
		slider.value = defaults[i]
		slider.size = Vector2(180.0, 16.0)
		slider.position = Vector2(510.0, y_pos + 24.0)
		slider.value_changed.connect(_on_slider_changed.bind(i))
		add_child(slider)
		_sliders[i] = slider

		var value_label := Label.new()
		value_label.name = "%s_value" % labels[i]
		value_label.text = str(defaults[i])
		value_label.position = Vector2(700.0, y_pos)
		add_child(value_label)

		y_pos += 60.0

func _build_output_button() -> void:
	var btn := Button.new()
	btn.text = "输出配置"
	btn.position = Vector2(510.0, 580.0)
	btn.size = Vector2(120.0, 40.0)
	btn.pressed.connect(_on_output_config)
	add_child(btn)

func _on_slider_changed(value: float, index: int) -> void:
	var labels := ["Offset X", "Offset Y", "Scale X", "Scale Y"]
	var val_label := get_node_or_null("%s_value" % labels[index]) as Label
	if val_label:
		val_label.text = "%.2f" % value
	_apply_to_accessory()

func _apply_to_accessory() -> void:
	if _accessory_target == null:
		return
	var ox := float((_sliders[0] as HSlider).value)
	var oy := float((_sliders[1] as HSlider).value)
	var sx := float((_sliders[2] as HSlider).value)
	var sy := float((_sliders[3] as HSlider).value)
	_accessory_target.position = Vector2(ox, oy)
	_accessory_target.scale = Vector2(sx, sy)

func set_accessory_target(target: Node2D) -> void:
	_accessory_target = target

func _on_output_config() -> void:
	var ox := float((_sliders[0] as HSlider).value)
	var oy := float((_sliders[1] as HSlider).value)
	var sx := float((_sliders[2] as HSlider).value)
	var sy := float((_sliders[3] as HSlider).value)
	var json_str := '{"slot_offset_x": %.1f, "slot_offset_y": %.1f, "scale_x": %.1f, "scale_y": %.1f}' % [ox, oy, sx, sy]
	print("[DebugPanel] 配饰 Slot 配置:\n", json_str)
