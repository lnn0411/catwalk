class_name BoardCell
extends Control

# ============================================================
# 猫咪合合乐 · 棋盘单格
# 负责：物品渲染、拖拽（_get_drag_data/_can_drop_data/_drop_data）、
#       目标格高亮、生成器角标、点击生成器
# 逻辑判定全部回调 BoardGame，本类不改棋盘状态
# ============================================================

signal cell_clicked(pos: Vector2i)
signal drop_requested(from_pos: Vector2i, to_pos: Vector2i)
signal drag_started(pos: Vector2i)
signal drag_ended(pos: Vector2i)

const COLOR_CELL_BG := Color("FAF6F0")
const COLOR_CELL_BORDER := Color("EFE4D6")
const COLOR_HIGHLIGHT_OK := Color("A6BE84")    # 可放置：sage 高亮
const COLOR_HIGHLIGHT_BAD := Color("B5553C")   # 不可放置：brick 提示
const COLOR_GENERATOR := Color("F2C572")       # 生成器格：amber
const COLOR_GENERATOR_EMPTY := Color("C9C2B8") # 生成器耗尽：变灰
const COLOR_TEXT := Color("4F453C")

var grid_pos: Vector2i = Vector2i.ZERO
var board: BoardGame = null
var is_generator: bool = false

var _bg: Panel
var _icon_label: Label
var _star_label: Label
var _badge_label: Label   # 生成器剩余次数角标
var _highlight: Panel
var _drag_hidden: bool = false  # 拖拽中隐藏本格物品


func _ready() -> void:
	custom_minimum_size = Vector2(120, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_visuals()
	refresh()


func setup(p_pos: Vector2i, p_board: BoardGame) -> void:
	grid_pos = p_pos
	board = p_board
	is_generator = p_pos == BoardGameData.GENERATOR_POS


func _build_visuals() -> void:
	_bg = Panel.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CELL_BG
	style.border_color = COLOR_CELL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	_bg.add_theme_stylebox_override("panel", style)
	add_child(_bg)

	_highlight = Panel.new()
	_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(COLOR_HIGHLIGHT_OK, 0.25)
	hl_style.border_color = COLOR_HIGHLIGHT_OK
	hl_style.set_border_width_all(3)
	hl_style.set_corner_radius_all(12)
	_highlight.add_theme_stylebox_override("panel", hl_style)
	_highlight.visible = false
	add_child(_highlight)

	_icon_label = Label.new()
	_icon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.add_theme_font_size_override("font_size", 44)
	_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_label)

	_star_label = Label.new()
	_star_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_star_label.offset_top = -26.0
	_star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_star_label.add_theme_font_size_override("font_size", 12)
	_star_label.add_theme_color_override("font_color", COLOR_TEXT)
	_star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_star_label)

	_badge_label = Label.new()
	_badge_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_badge_label.offset_left = -36.0
	_badge_label.offset_bottom = 24.0
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.add_theme_font_size_override("font_size", 16)
	_badge_label.add_theme_color_override("font_color", COLOR_TEXT)
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.visible = false
	add_child(_badge_label)


func refresh() -> void:
	"""按棋盘当前状态重绘本格"""
	if board == null:
		return
	var style: StyleBoxFlat = _bg.get_theme_stylebox("panel").duplicate()
	if is_generator:
		var depleted := board.generator_remaining <= 0
		style.bg_color = COLOR_GENERATOR_EMPTY if depleted else COLOR_GENERATOR
		style.border_color = Color("C4894A") if not depleted else COLOR_GENERATOR_EMPTY
		_icon_label.text = "🐾"
		_icon_label.modulate = Color(1, 1, 1, 0.45) if depleted else Color.WHITE
		_star_label.text = "生成器"
		_badge_label.text = "×%d" % board.generator_remaining
		_badge_label.visible = true
	else:
		style.bg_color = COLOR_CELL_BG
		style.border_color = COLOR_CELL_BORDER
		var item: BoardItem = board.get_item(grid_pos)
		if item != null and not _drag_hidden:
			_icon_label.text = item.get_icon()
			_icon_label.modulate = Color.WHITE
			_star_label.text = "%s %s" % [item.get_display_name(), "⭐".repeat(item.star)]
		else:
			_icon_label.text = ""
			_star_label.text = ""
		_badge_label.visible = false
	_bg.add_theme_stylebox_override("panel", style)


func play_merge_anim() -> void:
	"""合并成功：缩放弹跳 + 星光粒子"""
	_icon_label.pivot_offset = _icon_label.size / 2.0
	_icon_label.scale = Vector2(0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(_icon_label, "scale", Vector2(1.25, 1.25), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_icon_label, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spawn_merge_particles()


func play_spawn_anim() -> void:
	"""生成器产出：从生成器方向弹入"""
	_icon_label.pivot_offset = _icon_label.size / 2.0
	_icon_label.scale = Vector2(0.1, 0.1)
	var tween := create_tween()
	tween.tween_property(_icon_label, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_reject_anim() -> void:
	"""放置失败：左右抖动回弹"""
	var origin := _icon_label.position
	var tween := create_tween()
	tween.tween_property(_icon_label, "position:x", origin.x - 8.0, 0.05)
	tween.tween_property(_icon_label, "position:x", origin.x + 8.0, 0.05)
	tween.tween_property(_icon_label, "position:x", origin.x, 0.05)


func _spawn_merge_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.position = size / 2.0
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 14
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.gravity = Vector2(0, 240)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color("F2C572")
	add_child(particles)
	get_tree().create_timer(0.8).timeout.connect(particles.queue_free)


# ---------------- 输入：点击生成器 ----------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cell_clicked.emit(grid_pos)


# ---------------- 拖拽系统 ----------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	if board == null or is_generator:
		return null
	if board.game_state != BoardGameData.GameState.PLAYING:
		return null
	var item: BoardItem = board.get_item(grid_pos)
	if item == null:
		return null
	# 拖拽预览：物品图标跟手
	var preview := Label.new()
	preview.text = item.get_icon()
	preview.add_theme_font_size_override("font_size", 52)
	preview.modulate = Color(1, 1, 1, 0.9)
	var wrapper := Control.new()
	wrapper.add_child(preview)
	preview.position = -preview.get_minimum_size() / 2.0
	set_drag_preview(wrapper)
	# 拖拽中原格半透明
	_drag_hidden = true
	_icon_label.modulate = Color(1, 1, 1, 0.3)
	_icon_label.text = item.get_icon()
	drag_started.emit(grid_pos)
	return {"type": "board_item", "from_pos": grid_pos}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok := _is_valid_drop(data)
	if data is Dictionary and data.get("type") == "board_item":
		_show_highlight(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_highlight.visible = false
	drop_requested.emit(data["from_pos"], grid_pos)


func _is_valid_drop(data: Variant) -> bool:
	if not (data is Dictionary and data.get("type") == "board_item"):
		return false
	if board == null or is_generator:
		return false
	var from_pos: Vector2i = data["from_pos"]
	if from_pos == grid_pos:
		return false
	var dragged: BoardItem = board.get_item(from_pos)
	if dragged == null:
		return false
	var target: BoardItem = board.get_item(grid_pos)
	if target == null:
		return true  # 空格：可移动
	return board.can_merge(dragged, target)  # 有物品：仅同链同星可合并


func _show_highlight(can_drop: bool) -> void:
	var hl_style: StyleBoxFlat = _highlight.get_theme_stylebox("panel").duplicate()
	var color := COLOR_HIGHLIGHT_OK if can_drop else COLOR_HIGHLIGHT_BAD
	hl_style.bg_color = Color(color, 0.22)
	hl_style.border_color = color
	_highlight.add_theme_stylebox_override("panel", hl_style)
	_highlight.visible = true
	# 鼠标移走后自动隐藏
	if not mouse_exited.is_connected(_hide_highlight):
		mouse_exited.connect(_hide_highlight)


func _hide_highlight() -> void:
	_highlight.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# 拖拽结束（无论成功与否）：恢复本格显示；失败时物品回弹
		_highlight.visible = false
		if _drag_hidden:
			_drag_hidden = false
			_icon_label.modulate = Color.WHITE
			refresh()
			if not is_drag_successful():
				play_reject_anim()
			drag_ended.emit(grid_pos)
