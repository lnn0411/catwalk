extends Control
## 猫猫图鉴 Tab：ScrollContainer 包裹 3 列 GridContainer，
## 每个品种一个 CatGridCell。点击信号冒泡为 cat_cell_pressed。
## （美术待补）

signal cat_cell_pressed(species_name: String)

const CatGridCellScript := preload("res://scripts/collect_book/cat_grid_cell.gd")

const COLUMNS := 3
const CELL_SIZE := Vector2(200, 170)

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


func set_data(cats: Array, all_species: Array[String]) -> void:
	if _grid == null:
		_build_layout()

	# 清空旧单元格
	for child in _grid.get_children():
		child.queue_free()

	for species in all_species:
		var cat_data = _find_cat(cats, species)
		var is_collected := cat_data != null
		# 品种在列表中 → 至少为“已知”
		var is_known := true

		var cell := CatGridCellScript.new()
		cell.custom_minimum_size = CELL_SIZE
		_grid.add_child(cell)
		cell.setup(species, is_collected, is_known, cat_data, _rarity_color(species))
		cell.cell_pressed.connect(_on_cell_pressed)


func _find_cat(cats: Array, species: String):
	for c in cats:
		var sp := ""
		if typeof(c) == TYPE_DICTIONARY:
			sp = String(c.get("species", ""))
		elif c != null and "species" in c:
			sp = String(c.species)
		if sp == species:
			return c
	return null


func _rarity_color(species: String) -> Color:
	match species:
		"british":
			return Palette.RARITY_RARE
		"siamese":
			return Palette.RARITY_EPIC
		_:
			return Palette.AMBER


func _on_cell_pressed(species_name: String) -> void:
	cat_cell_pressed.emit(species_name)
