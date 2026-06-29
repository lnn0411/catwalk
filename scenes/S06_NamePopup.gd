extends "res://ui/UIPage.gd"

const CatData := preload("res://core/CatData.gd")

const NAME_POOLS_CN := {
	CatData.BREED_ORANGE: ["大胖", "橘子", "小橘", "阿福", "蛋黄"],
	CatData.BREED_BRITISH: ["绅士", "阿蓝", "小雪", "团团", "圆圆"],
	CatData.BREED_SIAMESE: ["小话痨", "芝麻", "点点", "墨墨", "阿喵"],
}

const NAME_POOLS_EN := {
	CatData.BREED_ORANGE: ["Mango", "Sunny", "Biscuit", "Cheeto", "Marmalade"],
	CatData.BREED_BRITISH: ["Ash", "Slate", "Chester", "Earl", "Sterling"],
	CatData.BREED_SIAMESE: ["Coco", "Pepper", "Mochi", "Sable", "Latte"],
}

const PORTRAIT_PATHS := {
	"orange": "res://assets/art/cats/portraits/reveal/portrait_orange.png",
	"british": "res://assets/art/cats/portraits/reveal/portrait_british.png",
	"siamese": "res://assets/art/cats/portraits/reveal/portrait_siamese.png",
}

signal confirmed(name: String)
signal canceled

var _cat
var _hatch_show
var _rng := RandomNumberGenerator.new()

@onready var _overlay: TextureRect = %OverlayBg
@onready var _popup_bg: TextureRect = %PopupBg
@onready var _portrait: TextureRect = %CatPortrait
@onready var _name_input: LineEdit = %NameInput
@onready var _random_btn: TextureButton = %RandomBtn
@onready var _confirm_btn: TextureButton = %ConfirmBtn


func _ready() -> void:
	super._ready()
	_rng.randomize()
	_overlay.gui_input.connect(_on_overlay_clicked)
	_random_btn.pressed.connect(_random_name_clicked)
	_confirm_btn.pressed.connect(_confirm_name)
	_show_portrait()
	_name_input.grab_focus()


func on_enter(_data: Dictionary = {}) -> void:
	_cat = _data.get("cat", null)
	_hatch_show = _data.get("hatch_show", null)
	_show_portrait()
	_name_input.grab_focus()


func _show_portrait() -> void:
	if _portrait == null:
		return
	if _cat == null:
		_portrait.visible = false
		return
	var species := _cat.species
	var path: String = PORTRAIT_PATHS.get(species, PORTRAIT_PATHS["british"])
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
		_portrait.visible = true
	else:
		_portrait.visible = false


func _random_name_clicked() -> void:
	_name_input.text = _random_name()


func _random_name() -> String:
	var pools: Dictionary = NAME_POOLS_CN if OS.get_locale_language() == "zh" else NAME_POOLS_EN
	var species := _species()
	var pool: Array = Array(pools.get(species, pools[CatData.BREED_ORANGE]))
	return String(pool[_rng.randi_range(0, pool.size() - 1)])


func _species() -> String:
	return String(_cat.species) if _cat != null else CatData.BREED_ORANGE


func _confirm_name() -> void:
	if _cat == null:
		UIManager.close_overlay()
		return
	var value: String = _name_input.text.strip_edges()
	if value.length() < 2:
		value = _random_name()
	if value.length() > 16:
		value = value.substr(0, 16)
	_cat.display_name = value
	if SaveManager:
		SaveManager.save_all()
	if HatchEngine and HatchEngine.current_companion_cat_id == "":
		HatchEngine.current_companion_cat_id = _cat.id
		SaveManager.save_all()
	var j := get_node_or_null("/root/Juice")
	if j: j.hit()
	confirmed.emit(value)
	UIManager.close_overlay()


func _on_overlay_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		canceled.emit()
		UIManager.close_overlay()
