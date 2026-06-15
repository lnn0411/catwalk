extends Node2D

const LAYER_FAR := 0
const LAYER_MID := 1
const LAYER_NEAR := 2

const FAR_TEXTURE_PATH := "res://assets/art/garden/layers/garden_far.png"
const MID_TEXTURE_PATH := "res://assets/art/garden/layers/garden_mid.png"
const NEAR_TEXTURE_PATH := "res://assets/art/garden/layers/garden_near.png"

var layer_type: int:
	get:
		return _layer_type
	set(value):
		set_layer_type(value)

var _layer_type := LAYER_FAR
var _sprite: Sprite2D


func _ready() -> void:
	_ensure_sprite()
	_reload_layer_texture()
	push_warning("[GardenBG] layer=%d texture=%s size=%s" % [_layer_type, str(_sprite.texture != null), str(_sprite.texture.get_size() if _sprite.texture else Vector2.ZERO)])


func set_layer_type(value: int) -> void:
	_layer_type = value
	if is_node_ready():
		_reload_layer_texture()


func _ensure_sprite() -> void:
	if _sprite:
		return

	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 100
	add_child(_sprite)


func _reload_layer_texture() -> void:
	_ensure_sprite()
	_sprite.texture = _load_layer_texture()


func _load_layer_texture() -> Texture2D:
	var texture_path := FAR_TEXTURE_PATH

	match _layer_type:
		LAYER_MID:
			texture_path = MID_TEXTURE_PATH
		LAYER_NEAR:
			texture_path = NEAR_TEXTURE_PATH

	var texture := load(texture_path) as Texture2D
	assert(texture != null, "Missing asset: " + texture_path)
	return texture
