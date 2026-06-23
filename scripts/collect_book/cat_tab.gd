extends Control
## 猫猫图鉴 Tab：ScrollContainer 包裹 3 列 GridContainer，
## 每只猫一个 CatGridCell。点击信号冒泡为 cat_cell_pressed。
## （美术待补）

signal cat_cell_pressed(cat_data)

const CatGridCellScript: GDScript = preload("res://scripts/collect_book/cat_grid_cell.gd")

const COLUMNS: int = 3
const CELL_SIZE: Vector2 = Vector2(200, 170)

var _scroll: ScrollContainer
var _grid: GridContainer


func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)


func set_data(cats: Array) -> void:
	if _grid == null:
		_build_layout()

	# 清空旧单元格
	for child in _grid.get_children():
		child.queue_free()

	for cat_data in cats:
		var cell: Control = CatGridCellScript.new()
		cell.custom_minimum_size = CELL_SIZE
		_grid.add_child(cell)
		cell.setup(cat_data)
		cell.cell_pressed.connect(_on_cell_pressed)


func _on_cell_pressed(cat_data: Variant) -> void:
	cat_cell_pressed.emit(cat_data)
