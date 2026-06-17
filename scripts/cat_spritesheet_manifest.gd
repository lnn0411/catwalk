extends RefCounted
class_name CatSpritesheetManifest

const FRAME_SIZE := Vector2i(100, 140)
const FOOT_Y := 131

const SPECIES := {
	"orange_tabby": {
		"texture_path": "res://assets/art/cats/orange_tabby/orange_tabby_32frame_green_fixed.png",
		"config_path": "res://assets/art/cats/orange_tabby/orange_tabby_32frame_godot.json"
	},
	"british": {
		"texture_path": "res://assets/art/cats/british/british_32frame_green_fixed.png",
		"config_path": "res://assets/art/cats/british/british_32frame_godot.json"
	},
	"siamese": {
		"texture_path": "res://assets/art/cats/siamese/siamese_32frame_green_fixed.png",
		"config_path": "res://assets/art/cats/siamese/siamese_32frame_godot.json"
	}
}
