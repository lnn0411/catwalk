extends "res://ui/UIPage.gd"

const BoardCell := preload("res://scripts/board_game/BoardCell.gd")
const BoardGame := preload("res://scripts/board_game/BoardGame.gd")
const BoardGameData := preload("res://scripts/board_game/BoardGameData.gd")
const BoardItem := preload("res://scripts/board_game/BoardItem.gd")
const ItemChains := preload("res://scripts/board_game/ItemChains.gd")

# ============================================================
# S14_BoardGame · 猫咪合合乐 棋盘场景
# 花园场景嵌入的迷你二合棋盘：5×5 网格，中心生成器
# 布局：顶部栏（主链目标/退出）+ 棋盘 + 底部工具栏（撤销/重开）
# ============================================================

const DESIGN_SIZE := Vector2(720.0, 1280.0)
const CELL_SIZE := 120.0
const CELL_GAP := 8.0
const UI_TEXT_COLOR := Color("4F453C")

var board: BoardGame
var _cells: Dictionary = {}  # Vector2i -> BoardCell

var _title_label: Label
var _goal_label: Label
var _state_label: Label
var _ticket_label: Label
var _generator_label: Label
var _undo_button: Button
var _restart_button: Button
var _result_overlay: ColorRect
var _result_label: Label
var _result_button: Button


func _ready() -> void:
	super()
	_build_board_logic()
	_build_ui()
	_start_game()


func _build_board_logic() -> void:
	board = BoardGame.new()
	board.name = "BoardGameCore"
	add_child(board)
	board.item_merged.connect(_on_item_merged)
	board.item_moved.connect(_on_item_moved)
	board.generator_clicked.connect(_on_generator_produced)
	board.generator_used.connect(_on_generator_used)
	board.game_won.connect(_on_game_won)
	board.game_lost.connect(_on_game_lost)
	board.undo_performed.connect(_on_undo_performed)


# ---------------- UI 构建 ----------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.PAPER_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.name = "Layout"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	root.add_child(_build_top_bar())

	# 棋盘居中容器
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	center.add_child(_build_grid())

	root.add_child(_build_bottom_bar())
	_build_result_overlay()


func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.MILK_WHITE
	style.border_color = Palette.BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	bar.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.name = "TopBar"
	hbox.add_theme_constant_override("separation", 12)
	bar.add_child(hbox)

	var back := Button.new()
	back.text = "‹ 返回"
	back.custom_minimum_size = Vector2(132, 56)
	back.add_theme_font_size_override("font_size", 20)
	back.add_theme_color_override("font_color", UI_TEXT_COLOR)
	back.add_theme_color_override("font_hover_color", UI_TEXT_COLOR)
	back.add_theme_color_override("font_pressed_color", UI_TEXT_COLOR)
	back.pressed.connect(_on_back_pressed)
	hbox.add_child(back)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_box)

	_title_label = Label.new()
	_title_label.text = "猫咪合合乐"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	title_box.add_child(_title_label)

	_goal_label = Label.new()
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.add_theme_font_size_override("font_size", 16)
	_goal_label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	title_box.add_child(_goal_label)

	_state_label = Label.new()
	_state_label.visible = false
	add_child(_state_label)

	_ticket_label = Label.new()
	_ticket_label.custom_minimum_size = Vector2(132, 56)
	_ticket_label.text = "🎟 ×1"
	_ticket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ticket_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ticket_label.add_theme_font_size_override("font_size", 20)
	_ticket_label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	hbox.add_child(_ticket_label)

	return bar


func _build_grid() -> Control:
	var grid_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BG_CEMENT
	style.border_color = Palette.BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.content_margin_left = CELL_GAP
	style.content_margin_right = CELL_GAP
	style.content_margin_top = CELL_GAP
	style.content_margin_bottom = CELL_GAP
	grid_panel.add_theme_stylebox_override("panel", style)
	grid_panel.custom_minimum_size = Vector2(
		CELL_SIZE * BoardGameData.GRID_SIZE + CELL_GAP * float(BoardGameData.GRID_SIZE + 1),
		CELL_SIZE * BoardGameData.GRID_SIZE + CELL_GAP * float(BoardGameData.GRID_SIZE + 1)
	)

	var grid_container := GridContainer.new()
	grid_container.name = "BoardGrid"
	grid_container.columns = BoardGameData.GRID_SIZE
	grid_container.add_theme_constant_override("h_separation", int(CELL_GAP))
	grid_container.add_theme_constant_override("v_separation", int(CELL_GAP))
	grid_panel.add_child(grid_container)

	for y in range(BoardGameData.GRID_SIZE):
		for x in range(BoardGameData.GRID_SIZE):
			var pos := Vector2i(x, y)
			var cell := BoardCell.new()
			cell.name = "Cell_%d_%d" % [x, y]
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.setup(pos, board)
			cell.cell_clicked.connect(_on_cell_clicked)
			cell.drop_requested.connect(_on_drop_requested)
			grid_container.add_child(cell)
			_cells[pos] = cell

	return grid_panel


func _build_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.name = "BottomBar"
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)
	bar.custom_minimum_size = Vector2(0, 96)

	_generator_label = Label.new()
	_generator_label.custom_minimum_size = Vector2(200, 64)
	_generator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_generator_label.add_theme_font_size_override("font_size", 22)
	_generator_label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	bar.add_child(_generator_label)

	_undo_button = Button.new()
	_undo_button.custom_minimum_size = Vector2(200, 64)
	_undo_button.add_theme_font_size_override("font_size", 22)
	_undo_button.add_theme_color_override("font_color", UI_TEXT_COLOR)
	_undo_button.add_theme_color_override("font_hover_color", UI_TEXT_COLOR)
	_undo_button.add_theme_color_override("font_pressed_color", UI_TEXT_COLOR)
	_undo_button.add_theme_color_override("font_disabled_color", UI_TEXT_COLOR)
	_undo_button.pressed.connect(_on_undo_pressed)
	bar.add_child(_undo_button)

	_restart_button = Button.new()
	_restart_button.text = "🔄 重新开始"
	_restart_button.custom_minimum_size = Vector2(200, 64)
	_restart_button.add_theme_font_size_override("font_size", 22)
	_restart_button.add_theme_color_override("font_color", UI_TEXT_COLOR)
	_restart_button.add_theme_color_override("font_hover_color", UI_TEXT_COLOR)
	_restart_button.add_theme_color_override("font_pressed_color", UI_TEXT_COLOR)
	_restart_button.pressed.connect(_start_game)
	bar.add_child(_restart_button)

	return bar


func _build_result_overlay() -> void:
	_result_overlay = ColorRect.new()
	_result_overlay.color = Color(0, 0, 0, 0.5)
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.visible = false
	add_child(_result_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PAPER_CREAM
	style.set_corner_radius_all(24)
	style.content_margin_left = 48.0
	style.content_margin_right = 48.0
	style.content_margin_top = 36.0
	style.content_margin_bottom = 36.0
	panel.add_theme_stylebox_override("panel", style)
	_result_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 30)
	_result_label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	vbox.add_child(_result_label)

	_result_button = Button.new()
	_result_button.text = "再来一局"
	_result_button.custom_minimum_size = Vector2(220, 64)
	_result_button.add_theme_font_size_override("font_size", 22)
	_result_button.add_theme_color_override("font_color", UI_TEXT_COLOR)
	_result_button.add_theme_color_override("font_hover_color", UI_TEXT_COLOR)
	_result_button.add_theme_color_override("font_pressed_color", UI_TEXT_COLOR)
	_result_button.pressed.connect(func():
		_result_overlay.visible = false
		_start_game()
	)
	vbox.add_child(_result_button)


# ---------------- 对局流程 ----------------

func _start_game() -> void:
	if TicketManager != null:
		if TicketManager.get_tickets() <= 0:
			_result_label.text = "门票不足\n请先获取门票"
			_show_result()
			_refresh_ticket_label()
			return
		TicketManager.spend_ticket()
	board.start_new_game()
	_result_overlay.visible = false
	var main_name: String = ItemChains.get_chain_display_name(board.current_main_chain)
	var sub_name: String = ItemChains.get_chain_display_name(board.current_sub_chain)
	_goal_label.text = "目标：合出 %s ⭐5 ｜ 副链：%s" % [main_name, sub_name]
	_refresh_all()


func _refresh_all() -> void:
	for pos in _cells:
		_cells[pos].refresh()
	_state_label.text = "🐾 ×%d" % board.generator_remaining
	_generator_label.text = "生成器 ×%d" % board.generator_remaining
	_undo_button.text = "↩ 撤销 (%d)" % board.undo_free_count
	_undo_button.disabled = not board.can_undo()
	_refresh_ticket_label()


func _refresh_ticket_label() -> void:
	if TicketManager != null:
		_ticket_label.text = "🎟 ×%d" % TicketManager.get_tickets()


# ---------------- 交互回调 ----------------

func _on_cell_clicked(pos: Vector2i) -> void:
	if board.is_generator_pos(pos):
		if board.click_generator():
			Juice.tap()


func _on_drop_requested(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var target: BoardItem = board.get_item(to_pos)
	if target != null:
		if board.merge_items(from_pos, to_pos):
			Juice.reward()
	else:
		if board.move_item(from_pos, to_pos):
			Juice.tap()


func _on_item_merged(pos: Vector2i, _new_item: BoardItem) -> void:
	_refresh_all()
	if _cells.has(pos):
		_cells[pos].play_merge_anim()


func _on_item_moved(_from_pos: Vector2i, _to_pos: Vector2i) -> void:
	_refresh_all()


func _on_generator_produced(pos: Vector2i, _item: BoardItem) -> void:
	_refresh_all()
	if _cells.has(pos):
		_cells[pos].play_spawn_anim()


func _on_generator_used(_count: int) -> void:
	_refresh_all()


func _on_undo_pressed() -> void:
	# 免费次数用完后应扣钻石；当前版本仅提示（钻石扣费接 CurrencyManager 时补）
	if board.undo():
		Juice.tap()


func _on_undo_performed(_action: Dictionary) -> void:
	_refresh_all()


func _on_game_won() -> void:
	_refresh_all()
	var item_name: String = ItemChains.get_item_info(
		board.current_main_chain, BoardGameData.StarLevel.FIVE)["name"]
	_result_label.text = "🎉 通关！\n合成了「%s」" % item_name
	_show_result()
	Juice.pattern_legendary()


func _on_game_lost() -> void:
	_refresh_all()
	_result_label.text = "😿 死局了…\n没有可合并的物品"
	_show_result()
	Juice.hit()


func _show_result() -> void:
	_result_overlay.visible = true
	_result_overlay.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_result_overlay, "modulate:a", 1.0, 0.25)


func _on_back_pressed() -> void:
	UIManager.pop()
