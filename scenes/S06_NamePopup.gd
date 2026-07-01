extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

const NAME_POOLS_CN := {
	CatData.BREED_ORANGE: ["大胖", "橘子", "小橘", "阿福", "蛋黄", "金桔", "糖糖", "布丁", "花生", "年糕", "豆豆", "肥肥", "甜甜", "小黄", "旺财"],
	CatData.BREED_BRITISH: ["绅士", "阿蓝", "小雪", "团团", "圆圆", "灰灰", "银耳", "奶茶", "包子", "滚滚", "汤圆", "毛球", "团子", "小灰", "蓝蓝"],
	CatData.BREED_SIAMESE: ["小话痨", "芝麻", "点点", "墨墨", "阿喵", "煤球", "烟烟", "咖啡", "奥利奥", "熊猫", "炭炭", "黑糖", "巧巧", "乌云", "小煤"],
}

const NAME_POOLS_EN := {
	CatData.BREED_ORANGE: ["Mango", "Sunny", "Biscuit", "Cheeto", "Marmalade", "Ginger", "Peach", "Pumpkin", "Tangerine", "Nacho", "Cheddar", "Nemo", "Simba", "Tiger", "Honey"],
	CatData.BREED_BRITISH: ["Ash", "Slate", "Chester", "Earl", "Sterling", "Smoky", "Blue", "Misty", "Silver", "Stormy", "Pebble", "Dusty", "Shadow", "Cloudy", "Granite"],
	CatData.BREED_SIAMESE: ["Coco", "Pepper", "Mochi", "Sable", "Latte", "Sooty", "Inky", "Noir", "Shadow", "Onyx", "Licorice", "Oreo", "Panda", "Tux", "Binx"],
}

signal confirmed(name: String)
signal canceled

var _cat
var _hatch_show
var _closing := false
var _rng := RandomNumberGenerator.new()

@onready var _overlay: TextureRect = %OverlayBg
@onready var _popup_bg: TextureRect = %PopupBg
@onready var _name_input: LineEdit = %NameInput
@onready var _random_btn: TextureButton = %RandomBtn
@onready var _confirm_btn: TextureButton = %ConfirmBtn


func _ready() -> void:
	super._ready()
	_rng.randomize()
	_overlay.gui_input.connect(_on_overlay_clicked)
	_random_btn.pressed.connect(_random_name_clicked)
	_confirm_btn.pressed.connect(_confirm_name)
	_name_input.grab_focus()


func on_enter(_data: Dictionary = {}) -> void:
	_cat = _data.get("cat", null)
	_hatch_show = _data.get("hatch_show", null)
	_name_input.grab_focus()


func _random_name_clicked() -> void:
	for _attempt in 5:
		_name_input.text = _random_name()
		if not _is_name_taken(_name_input.text):
			return
	_name_input.text = _random_name()


func _random_name() -> String:
	var pools: Dictionary = NAME_POOLS_CN if OS.get_locale_language() == "zh" else NAME_POOLS_EN
	var species := _species()
	var pool: Array = Array(pools.get(species, pools[CatData.BREED_ORANGE]))
	return String(pool[_rng.randi_range(0, pool.size() - 1)])


func _species() -> String:
	return String(_cat.species) if _cat != null else CatData.BREED_ORANGE


func _is_name_taken(name: String) -> bool:
	if not HatchEngine:
		return false
	var my_id: String = String(_cat.id) if _cat != null else ""
	for c in HatchEngine.get_cats():
		var cid: String = String(c.id)
		if cid == my_id:
			continue
		var cname: String = String(c.display_name) if "display_name" in c else String(c.get("name", ""))
		if cname == name:
			return true
	return false


func _confirm_name() -> void:
	if _cat == null:
		UIManager.close_overlay()
		return
	if _closing:
		return
	var value: String = _name_input.text.strip_edges()
	if value.length() < 2:
		value = _random_name()
	if value.length() > 16:
		value = value.substr(0, 16)
	if _is_name_taken(value):
		Popups.show_toast("已有同名猫咪，请换一个名字")
		return
	_closing = true
	_cat.display_name = value
	if SaveManager:
		SaveManager.save_all()
	if HatchEngine and HatchEngine.current_companion_cat_id == "":
		HatchEngine.current_companion_cat_id = _cat.id
		SaveManager.save_all()
	var j := get_node_or_null("/root/Juice")
	if j: j.hit()
	confirmed.emit(value)
	if _hatch_show != null and _hatch_show.has_method(&"resume_after_name_popup"):
		_hatch_show.resume_after_name_popup()
	UIManager.close_overlay()


func _on_overlay_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _closing:
			return
		_closing = true
		canceled.emit()
		if _hatch_show != null and _hatch_show.has_method(&"resume_after_name_popup"):
			_hatch_show.resume_after_name_popup()
		UIManager.close_overlay()
