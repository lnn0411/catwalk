extends Node

# Headless screenshot renderer for P0_ArtVerify scene
# Usage: godot --headless --path /home/agentuser/catwalk res://scenes/P0_Screenshot.tscn
# Outputs: res://screenshots/p0_verify_01.png through 03.png

var _scene: Node
var _frame_count := 0
var _screenshot_index := 0
var _screenshot_positions := [
	Vector2(1024, 768),   # Screenshot 1: default center
	Vector2(512, 768),    # Screenshot 2: pan left to see garden left + cat
	Vector2(1024, 1050),  # Screenshot 3: pan down to see near layer detail + cat closeup
]

func _ready() -> void:
	# Load and instantiate the P0 verification scene
	var packed := load("res://scenes/P0_ArtVerify.tscn")
	if not packed:
		printerr("FAILED to load P0_ArtVerify.tscn")
		get_tree().quit(1)
		return
	
	_scene = packed.instantiate()
	add_child(_scene)
	
	# Wait for scene to be ready, then take screenshots
	await get_tree().process_frame
	await get_tree().process_frame  # Two frames for layout
	
	_take_screenshots()

func _take_screenshots() -> void:
	var output_dir := "res://screenshots"
	DirAccess.make_dir_recursive_absolute("screenshots")
	
	# Find the camera in the scene
	var camera: Camera2D = _scene.find_child("Camera2D", true, false)
	if not camera:
		printerr("Camera2D not found")
		get_tree().quit(1)
		return
	
	# Find the cat timer to get its current frame
	var timer: Timer = _scene.find_child("CatFrameTimer", true, false)
	
	for i in range(3):
		# Move camera to screenshot position
		camera.position = _screenshot_positions[i]
		camera.make_current()
		
		# Force cat to show specific frames for variety
		var cat_sprites: Array = _scene.get("_cat_sprites")
		if cat_sprites and cat_sprites.size() >= 3:
			for s in cat_sprites:
				s.visible = false
			cat_sprites[i % 3].visible = true
		
		# Update debug label
		var debug_label: Label = _scene.find_child("DebugLabel", true, false)
		if debug_label:
			debug_label.text = "P0 Verify #%d\ncamera: (%.1f, %.1f)" % [i + 1, camera.position.x, camera.position.y]
		
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Capture viewport
		var img := get_viewport().get_texture().get_image()
		var filename := "user://../screenshots/p0_verify_%02d.png" % (i + 1)
		var err := img.save_png(filename)
		if err == OK:
			print("✓ Saved: %s" % filename)
		else:
			printerr("✗ Failed to save %s, error=%d" % [filename, err])
	
	print("Screenshots complete. Quitting.")
	get_tree().quit(0)
