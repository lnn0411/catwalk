extends "res://ui/UIPage.gd"

const BoardCell := preload("res://scripts/board_game/BoardCell.gd")
const BoardGame := preload("res://scripts/board_game/BoardGame.gd")
const BoardGameData := preload("res://scripts/board_game/BoardGameData.gd")
const BoardItem := preload("res://scripts/board_game/BoardItem.gd")
const BoardRewardSystem := preload("res://scripts/board_game/RewardSystem.gd")
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
var _ad_rescue_overlay: ColorRect
var _ad_rescue_action_layer: Control
var _ad_rescue_remove_button: Button
var _ad_rescue_selected: Dictionary = {}  # Vector2i -> true
var _ad_rescue_highlights: Dictionary = {}  # Vector2i -> Panel
var _ad_rescue_mode: bool = false
var _dbg_ticket_btn: Button


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
	board.sub_chain_completed.connect(_on_sub_chain_completed)
	board.undo_performed.connect(_on_undo_performed)
	board.mischief_warning.connect(_on_mischief_warning)
	board.mischief_triggered.connect(_on_mischief_triggered)
	board.mischief_cat_apology.connect(_on_cat_apology)


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
	_build_ad_rescue_dialog()
	_build_debug_ticket_button()


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


func _build_ad_rescue_dialog() -> void:
	_ad_rescue_overlay = ColorRect.new()
	_ad_rescue_overlay.color = Color(0, 0, 0, 0.55)
	_ad_rescue_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ad_rescue_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_ad_rescue_overlay.visible = false
	add_child(_ad_rescue_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PAPER_CREAM
	style.set_corner_radius_all(24)
	style.content_margin_left = 42.0
	style.content_margin_right = 42.0
	style.content_margin_top = 34.0
	style.content_margin_bottom = 34.0
	panel.add_theme_stylebox_override("panel", style)
	_ad_rescue_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = "猫咪把东西拍飞了！看个广告帮你找回来？"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(430, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	vbox.add_child(label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	vbox.add_child(buttons)

	var watch_button := Button.new()
	watch_button.text = "看广告"
	watch_button.custom_minimum_size = Vector2(180, 60)
	watch_button.add_theme_font_size_override("font_size", 22)
	watch_button.add_theme_color_override("font_color", UI_TEXT_COLOR)
	watch_button.add_theme_color_override("font_hover_color", UI_TEXT_COLOR)
	watch_button.add_theme_color_override("font_pressed_color", UI_TEXT_COLOR)
	watch_button.pressed.connect(_enter_ad_rescue_mode)
	buttons.add_child(watch_button)

	var give_up_button := Button.new()
	give_up_button.text = "放弃"
	give_up_button.custom_minimum_size = Vector2(180, 60)
	give_up_button.add_theme_font_size_override("font_size", 22)
	give_up_button.add_theme_color_override("font_color", UI_TEXT_COLOR)
	give_up_button.add_theme_color_override("font_hover_color", UI_TEXT_COLOR)
	give_up_button.add_theme_color_override("font_pressed_color", UI_TEXT_COLOR)
	give_up_button.pressed.connect(_on_ad_rescue_give_up_pressed)
	buttons.add_child(give_up_button)


func _build_debug_ticket_button() -> void:
	# 仅 debug 构建可见：右下角快速加 3 张门票
	if not OS.is_debug_build():
		return
	_dbg_ticket_btn = Button.new()
	_dbg_ticket_btn.text = "🎟+3"
	_dbg_ticket_btn.custom_minimum_size = Vector2(64, 40)
	_dbg_ticket_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dbg_ticket_btn.offset_left = -80.0
	_dbg_ticket_btn.offset_top = -60.0
	_dbg_ticket_btn.add_theme_font_size_override("font_size", 16)
	_dbg_ticket_btn.add_theme_color_override("font_color", Color.WHITE)
	_dbg_ticket_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_dbg_ticket_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	_dbg_ticket_btn.add_theme_stylebox_override("normal", style)
	_dbg_ticket_btn.pressed.connect(func():
		if TicketManager != null:
			TicketManager.tickets += 3
			TicketManager.tickets_changed.emit(TicketManager.tickets)
		_refresh_ticket_label()
	)
	add_child(_dbg_ticket_btn)


# ---------------- 对局流程 ----------------

func _start_game() -> void:
	_exit_ad_rescue_mode()
	if TicketManager != null:
		if TicketManager.get_tickets() <= 0:
			_result_label.text = "门票不足\n请先获取门票"
			_show_result()
			_refresh_ticket_label()
			return
		TicketManager.spend_ticket()
	var board_level := _get_board_level()
	var cat_name := _get_companion_cat_name()
	board.start_new_game(board_level, cat_name)
	_result_overlay.visible = false
	var main_name: String = ItemChains.get_chain_display_name(board.current_main_chain)
	var sub_name: String = ItemChains.get_chain_display_name(board.current_sub_chain)
	_goal_label.text = "目标：合出 %s ⭐5 ｜ 副链：%s ⭐3" % [main_name, sub_name]
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


func _get_total_board_wins() -> int:
	if LevelStateManager != null:
		if LevelStateManager.has_method("get_total_wins"):
			return int(LevelStateManager.call("get_total_wins"))
		var wins: Variant = LevelStateManager.get("total_wins")
		if wins != null:
			return int(wins)
	return 0


func _get_board_level() -> int:
	# 用持久化的 board_level（仅升不降）；无 LevelStateManager 时回退到按胜场计算
	if LevelStateManager != null and LevelStateManager.has_method("get_board_level"):
		return int(LevelStateManager.call("get_board_level"))
	return BoardGameData.calc_board_level(_get_total_board_wins())


func _get_companion_cat_name() -> String:
	if HatchEngine == null:
		return "猫咪"
	var cat = null
	var companion_id := String(HatchEngine.get("current_companion_cat_id"))
	if not companion_id.is_empty() and HatchEngine.has_method("get_cat_by_id"):
		cat = HatchEngine.get_cat_by_id(companion_id)
	if cat == null and HatchEngine.has_method("get_cats"):
		var cats: Array = HatchEngine.get_cats()
		if not cats.is_empty():
			cat = cats[0]
	if cat == null:
		return "猫咪"
	if cat is Dictionary:
		return String(cat.get("display_name", cat.get("name", "猫咪")))
	var display_name := String(cat.get("display_name"))
	if not display_name.is_empty():
		return display_name
	var fallback_name := String(cat.get("name"))
	return fallback_name if not fallback_name.is_empty() else "猫咪"


# ---------------- 交互回调 ----------------

func _on_cell_clicked(pos: Vector2i) -> void:
	if _ad_rescue_mode:
		_toggle_ad_rescue_selection(pos)
		return
	if board.is_generator_pos(pos):
		if board.click_generator():
			Juice.tap()


func _on_drop_requested(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if _ad_rescue_mode:
		return
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


func _on_mischief_warning(pos: Vector2i) -> void:
	if _cells.has(pos):
		var cell: Control = _cells[pos]
		var tween := create_tween()
		tween.set_loops(2)
		tween.tween_property(cell, "modulate", Color(1.0, 0.3, 0.3, 0.7), 0.2)
		tween.tween_property(cell, "modulate", Color.WHITE, 0.2)


func _on_mischief_triggered(_pos: Vector2i, _item: BoardItem) -> void:
	_refresh_all()


func _on_cat_apology(_cat_name: String) -> void:
	pass


func _on_game_won() -> void:
	_refresh_all()

	# 记录累计胜场；若触发升档则弹出说明卡（等级仅升不降，持久化）
	_record_win_and_maybe_upgrade()

	var reward: Dictionary = BoardRewardSystem.roll_reward()
	var reward_id: String = String(reward.get("id", ""))
	var reward_name: String = String(reward.get("name", "小鱼干"))

	# 奖励入库
	_add_reward_to_inventory(reward_id, reward_name)

	var display_text := reward_name
	if reward_id == "cat_can_pack":
		display_text = "猫罐头×3"

	_result_label.text = "🎉 通关！\n获得「%s」" % display_text
	_show_result()
	Juice.pattern_legendary()


func _record_win_and_maybe_upgrade() -> void:
	if LevelStateManager == null or not LevelStateManager.has_method("record_win"):
		return
	var new_level := int(LevelStateManager.call("record_win"))
	if new_level > BoardGameData.BoardLevel.LV1:
		_show_level_up_popup(new_level)


func _show_level_up_popup(new_level: int) -> void:
	# 升档说明卡（§19.9 D8）：纯参数提升，无惩罚无降级
	var content := ""
	match new_level:
		BoardGameData.BoardLevel.LV2:
			content = "进入成长期 🐾\n捣乱增加但奖励更丰厚"
		BoardGameData.BoardLevel.LV3:
			content = "进入挑战期 ⭐\n难度最高但收益最大"
		_:
			content = "棋盘参数已提升"
	var reward_desc := String(BoardGameData.get_level_config(new_level).get("reward_desc", ""))
	if not reward_desc.is_empty():
		content += "\n奖励：%s" % reward_desc
	if Popups != null:
		Popups.show_confirm("🎉 棋盘升级！", content, Callable())


func _on_sub_chain_completed(_item: BoardItem) -> void:
	# 副链⭐3出口奖励：奖励小鱼干×1
	_add_reward_to_inventory("fish_dried", "小鱼干")
	Popups.show_toast("副链出口！获得小鱼干×1")


# 奖励类型→InventoryManager 映射
func _add_reward_to_inventory(reward_id: String, _reward_name: String) -> void:
	if InventoryManager == null:
		return
	match reward_id:
		"fish_dried":  # 小鱼干 → snack
			InventoryManager.add_item("snack", 1)
		"cat_can":  # 猫罐头 → snack
			InventoryManager.add_item("snack", 1)
		"cat_can_pack":  # 猫罐头大礼包 → 自动拆分为3个snack
			InventoryManager.add_item("snack", 3)
		"yarn_ball":  # 逗猫毛线团 → decoration_shard（占位，Phase 2再细分类）
			InventoryManager.add_item("decoration_shard", 1)
		"cat_wand":  # 逗猫棒 → decoration_shard（占位）
			InventoryManager.add_item("decoration_shard", 1)
		"cat_tree":  # 猫爬架 → decor（占位）
			InventoryManager.add_item("decor", 1)
		"cherry_tree":  # 樱花树 → decor（占位）
			InventoryManager.add_item("decor", 1)


func _on_game_lost() -> void:
	_refresh_all()
	if board.ad_rescue_restore_used or board.swiped_items.is_empty():
		_show_failure_result()
		return
	_show_ad_rescue_dialog()
	Juice.hit()


func _show_ad_rescue_dialog() -> void:
	_ad_rescue_overlay.visible = true
	_ad_rescue_overlay.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_ad_rescue_overlay, "modulate:a", 1.0, 0.2)


func _show_failure_result() -> void:
	_exit_ad_rescue_mode()
	_ad_rescue_overlay.visible = false
	var cat: String = board.cat_name if not board.cat_name.is_empty() else "猫咪"
	if board.is_give_up:
		_result_label.text = "😿 你放弃了这局…\n%s蹭过来蹭蹭你，好像在说'下次一定行喵'" % cat
	elif board.ad_rescue_restore_used:
		_result_label.text = "😿 还是死局了…\n%s低着头蹭过来，心虚地喵了一声" % cat
	else:
		_result_label.text = "😿 死局了…\n%s把东西拍飞了，蹭过来道歉中…" % cat
	_show_result()


func _enter_ad_rescue_mode() -> void:
	_ad_rescue_overlay.visible = false
	board.ad_rescue_restore()
	_refresh_all()


func _on_ad_rescue_give_up_pressed() -> void:
	board.give_up()
	_show_failure_result()


func _toggle_ad_rescue_selection(pos: Vector2i) -> void:
	var item: BoardItem = board.get_item(pos)
	if item == null or item.star > BoardGameData.StarLevel.TWO:
		return
	if _ad_rescue_selected.has(pos):
		_ad_rescue_selected.erase(pos)
	elif _ad_rescue_selected.size() < 3:
		_ad_rescue_selected[pos] = true
	_refresh_ad_rescue_highlights()
	_update_ad_rescue_remove_button()


func _remove_selected_items() -> void:
	if _ad_rescue_selected.is_empty():
		return
	_ad_rescue_remove_button.disabled = true
	var selected_positions: Array = _ad_rescue_selected.keys()
	var tween := create_tween()
	tween.set_parallel(true)
	for pos in selected_positions:
		if _cells.has(pos):
			var cell: Control = _cells[pos]
			cell.pivot_offset = cell.size / 2.0
			tween.tween_property(cell, "scale", Vector2(0.08, 0.08), 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(cell, "modulate:a", 0.0, 0.18)
	await tween.finished
	for pos in selected_positions:
		board.grid.erase(pos)
		if _cells.has(pos):
			var cell: Control = _cells[pos]
			cell.scale = Vector2.ONE
			cell.modulate = Color.WHITE
	board.ad_rescue()
	_exit_ad_rescue_mode()
	_refresh_all()


func _exit_ad_rescue_mode() -> void:
	_ad_rescue_mode = false
	_ad_rescue_selected.clear()
	if _ad_rescue_overlay != null:
		_ad_rescue_overlay.visible = false
	if _ad_rescue_action_layer != null:
		_ad_rescue_action_layer.visible = false
	for pos in _ad_rescue_highlights.keys():
		var panel: Panel = _ad_rescue_highlights[pos]
		if is_instance_valid(panel):
			panel.queue_free()
	_ad_rescue_highlights.clear()
	_update_ad_rescue_remove_button()


func _refresh_ad_rescue_highlights() -> void:
	for pos in _cells:
		var cell: Control = _cells[pos]
		var item: BoardItem = board.get_item(pos)
		var panel: Panel = _ad_rescue_highlights.get(pos)
		if item == null:
			if panel != null and is_instance_valid(panel):
				panel.queue_free()
			_ad_rescue_highlights.erase(pos)
			continue
		if panel == null or not is_instance_valid(panel):
			panel = Panel.new()
			panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(panel)
			_ad_rescue_highlights[pos] = panel
		var selectable := item.star <= BoardGameData.StarLevel.TWO
		var selected := _ad_rescue_selected.has(pos)
		var color := Color(0.2, 0.8, 0.2) if selectable else Color(0.35, 0.35, 0.35)
		if selected:
			color = Color(0.95, 0.15, 0.12)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color, 0.18 if selectable else 0.28)
		style.border_color = color
		style.set_border_width_all(5 if selected else 4)
		style.set_corner_radius_all(12)
		panel.add_theme_stylebox_override("panel", style)
		panel.visible = true


func _update_ad_rescue_remove_button() -> void:
	if _ad_rescue_remove_button == null:
		return
	_ad_rescue_remove_button.disabled = _ad_rescue_selected.is_empty()


func _show_result() -> void:
	_result_overlay.visible = true
	_result_overlay.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_result_overlay, "modulate:a", 1.0, 0.25)


func _on_back_pressed() -> void:
	UIManager.pop()
