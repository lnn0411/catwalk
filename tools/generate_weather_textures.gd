@tool
extends EditorScript

const WEATHER_DIR := "res://assets/weather"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WEATHER_DIR))
	_save_rain_drop()
	_save_snow_flake()
	print("[WeatherTextures] Generated rain_drop.png and snow_flake.png")

func _save_rain_drop() -> void:
	var image := Image.create(1, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	image.save_png(WEATHER_DIR + "/rain_drop.png")

func _save_snow_flake() -> void:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))

	var center := Vector2(3.5, 3.5)
	var radius := 3.5
	for y in range(8):
		for x in range(8):
			var distance := Vector2(float(x), float(y)).distance_to(center)
			var alpha := clamp(1.0 - (distance / radius), 0.0, 1.0)
			alpha = smoothstep(0.0, 1.0, alpha)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	image.save_png(WEATHER_DIR + "/snow_flake.png")
