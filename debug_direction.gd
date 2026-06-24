extends Node

const ANIM_WALK_RIGHT := "walk_right"
const ANIM_WALK_UP_RIGHT := "walk_up_right"
const ANIM_WALK_UP := "walk_up"
const ANIM_WALK_DOWN_RIGHT := "walk_down_right"
const ANIM_WALK_DOWN := "walk_down"

const ANIM_ROWS := {
	ANIM_WALK_RIGHT: 0,
	ANIM_WALK_UP_RIGHT: 1,
	ANIM_WALK_UP: 2,
	ANIM_WALK_DOWN_RIGHT: 3,
	ANIM_WALK_DOWN: 4,
}

func _walk_dir_key(anim_name: String, flip_left: bool, breed: String) -> String:
	var breed_swapped := breed.begins_with("british")
	var actual_left := flip_left
	if breed_swapped:
		actual_left = not flip_left
	match anim_name:
		ANIM_WALK_RIGHT:
			return "side_left" if actual_left else "side_right"
		ANIM_WALK_UP_RIGHT:
			return "back_left" if actual_left else "back_right"
		ANIM_WALK_DOWN_RIGHT:
			return "front_left" if actual_left else "front_right"
		ANIM_WALK_UP:
			return "back"
		ANIM_WALK_DOWN:
			return "front"
	return ""

func _select_anim_from_direction(dir_deg: float) -> Dictionary:
	var deg := dir_deg
	if deg >= -22.5 and deg < 22.5:
		return {"anim": ANIM_WALK_RIGHT, "flip": false}
	elif deg >= 22.5 and deg < 67.5:
		return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": false}
	elif deg >= 67.5 and deg < 112.5:
		return {"anim": ANIM_WALK_DOWN, "flip": false}
	elif deg >= 112.5 and deg < 157.5:
		return {"anim": ANIM_WALK_DOWN_RIGHT, "flip": true}
	elif deg >= 157.5 or deg < -157.5:
		return {"anim": ANIM_WALK_RIGHT, "flip": true}
	elif deg >= -157.5 and deg < -112.5:
		return {"anim": ANIM_WALK_UP_RIGHT, "flip": true}
	elif deg >= -112.5 and deg < -67.5:
		return {"anim": ANIM_WALK_UP, "flip": false}
	else:
		return {"anim": ANIM_WALK_UP_RIGHT, "flip": false}

func _ready() -> void:
	var dirs := [0, 45, 90, 135, 180, -135, -90, -45]
	var dir_names := ["RIGHT(0)", "DOWN-RIGHT(45)", "DOWN(90)", "DOWN-LEFT(135)", "LEFT(180)", "UP-LEFT(-135)", "UP(-90)", "UP-RIGHT(-45)"]
	
	print("=== British cat direction test ===")
	for i in len(dirs):
		var d := _select_anim_from_direction(dirs[i])
		var key := _walk_dir_key(d["anim"], d["flip"], "british")
		print("  " + dir_names[i] + " → anim=" + d["anim"] + " flip=" + str(d["flip"]) + " → frame_dir=" + key)
	
	print("\n=== Orange cat (reference) ===")
	for i in len(dirs):
		var d := _select_anim_from_direction(dirs[i])
		var key := _walk_dir_key(d["anim"], d["flip"], "orange")
		print("  " + dir_names[i] + " → anim=" + d["anim"] + " flip=" + str(d["flip"]) + " → frame_dir=" + key)
	
	get_tree().quit()
