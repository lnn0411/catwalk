extends Control

signal postcard_cell_pressed(postcard_id: String)

const PostcardGridCellScript = preload("res://scripts/collect_book/postcard_grid_cell.gd")
const CELL_SIZE := Vector2(330, 220)
const COLUMNS := 2

var _grid: GridContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_grid)


func set_data(collected_ids: Array) -> void:
	if _grid == null:
		await ready

	for child in _grid.get_children():
		child.queue_free()

	var all_postcards: Array = PostcardData.get_all()
	for postcard in all_postcards:
		var is_collected: bool = collected_ids.has(postcard.id)
		# 已收集 = 彩色卡；未收集 = 黑色 "?" 卡（postcard_grid_cell 已有对应渲染）
		var is_known: bool = is_collected

		var cell := Control.new()
		cell.set_script(PostcardGridCellScript)
		cell.custom_minimum_size = CELL_SIZE
		_grid.add_child(cell)
		cell.setup(postcard, is_collected, is_known)
		cell.cell_pressed.connect(_on_cell_pressed)


func _on_cell_pressed(postcard_id: String) -> void:
	postcard_cell_pressed.emit(postcard_id)
