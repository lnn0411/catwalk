class_name BoardItem
extends RefCounted

# ============================================================
# 猫咪合合乐 · 棋盘物品
# GDScript 无 struct，用 RefCounted 承载；grid 中每格一个实例
# ============================================================

var chain: int = BoardGameData.ItemChain.WEAR  # BoardGameData.ItemChain
var star: int = BoardGameData.StarLevel.ONE    # BoardGameData.StarLevel
var id: String = ""                            # "WEAR_1", "SNACK_3" 等
var grid_pos: Vector2i = Vector2i.ZERO


static func create(p_chain: int, p_star: int, p_pos: Vector2i) -> BoardItem:
	var item := BoardItem.new()
	item.chain = p_chain
	item.star = p_star
	item.id = "%s_%d" % [BoardGameData.chain_name(p_chain), p_star]
	item.grid_pos = p_pos
	return item


func duplicate_item() -> BoardItem:
	return BoardItem.create(chain, star, grid_pos)


func get_display_name() -> String:
	return ItemChains.get_item_info(chain, star)["name"]


func get_icon() -> String:
	return ItemChains.get_item_info(chain, star)["icon"]


func is_max_star() -> bool:
	return star >= BoardGameData.StarLevel.FIVE
