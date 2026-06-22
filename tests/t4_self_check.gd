extends Node

func _ready() -> void:
	var pc := 0
	var fc := 0
	
	# T4-01
	if FileAccess.file_exists("res://scenes/S07_CarryCatSelect.gd"):
		print("  [OK] T4-01 S07_CarryCatSelect.gd"); pc += 1
	else:
		print("  [XX] T4-01"); fc += 1
	
	# T4-02
	if load("res://core/TutorialManager.gd"):
		print("  [OK] T4-02 TutorialManager"); pc += 1
	else:
		print("  [XX] T4-02"); fc += 1
	
	# T4-03
	var gm = load("res://scenes/S04_GardenMain.gd")
	if gm:
		print("  [OK] T4-03 GardenMain loads"); pc += 1
	else:
		print("  [XX] T4-03"); fc += 1
	
	# T4-04
	if FileAccess.file_exists("res://scenes/ui/CatCard.gd"):
		print("  [OK] T4-04 CatCard.gd"); pc += 1
	else:
		print("  [XX] T4-04"); fc += 1
	
	# T4-05
	if EmotionStateMachine.has_method("is_annoyed"):
		print("  [OK] T4-05 ESM.is_annoyed"); pc += 1
	else:
		print("  [XX] T4-05"); fc += 1
	
	# T4-06
	if ExploreEngine.has_method("get_remaining_seconds"):
		print("  [OK] T4-06 ExploreEngine"); pc += 1
	else:
		print("  [XX] T4-06"); fc += 1
	if FileAccess.file_exists("res://scenes/ui/explore_duration_picker.gd"):
		print("  [OK] T4-06 UI components"); pc += 1
	else:
		print("  [XX] T4-06 UI"); fc += 1
	
	# T4-08
	if FileAccess.file_exists("res://scenes/S12_Shop.gd"):
		print("  [OK] T4-08 Shop page"); pc += 1
	else:
		print("  [XX] T4-08"); fc += 1
	
	# T4-09
	if FileAccess.file_exists("res://scenes/S13_Friends.gd"):
		print("  [OK] T4-09 Friends page"); pc += 1
	else:
		print("  [XX] T4-09"); fc += 1
	
	# T4-10
	if WorkshopData and WorkshopData.has_method("roll_gift"):
		print("  [OK] T4-10 WorkshopData"); pc += 1
	else:
		print("  [XX] T4-10 WorkshopData"); fc += 1
	if WorkshopManager and WorkshopManager.has_method("allocate_energy"):
		print("  [OK] T4-10 WorkshopManager"); pc += 1
	else:
		print("  [XX] T4-10 WorkshopManager"); fc += 1
	if FileAccess.file_exists("res://scenes/WorkshopPage.gd"):
		print("  [OK] T4-10 WorkshopPage"); pc += 1
	else:
		print("  [XX] T4-10 WorkshopPage"); fc += 1
	
	# T4-11
	if RelinquishSystem and RelinquishSystem.has_method("relinquish_cat"):
		var rf = RelinquishSystem.get("RARITY_FACTOR")
		if rf and rf.get("common") == 0.0:
			print("  [OK] T4-11 RelinquishSystem new formula"); pc += 1
		else:
			print("  [XX] T4-11 formula mismatch"); fc += 1
	else:
		print("  [XX] T4-11 RelinquishSystem"); fc += 1
	
	# T4-12
	if FileAccess.file_exists("res://scenes/S10_Album.gd"):
		print("  [OK] T4-12 Postcard album"); pc += 1
	else:
		print("  [XX] T4-12 Postcard album"); fc += 1
	
	# T4-13
	if WeatherTimeManager and WeatherTimeManager.has_method("get_weather_bonus_data"):
		print("  [OK] T4-13 WeatherTimeManager"); pc += 1
	else:
		print("  [XX] T4-13"); fc += 1
	if FileAccess.file_exists("res://shaders/weather_color_grade.gdshader"):
		print("  [OK] T4-13 Weather shader"); pc += 1
	else:
		print("  [XX] T4-13 shader"); fc += 1
	
	# T4-14
	if CatScreenManager and CatScreenManager.has_method("get_visible_cats"):
		print("  [OK] T4-14 CatScreenManager"); pc += 1
	else:
		print("  [XX] T4-14"); fc += 1
	if CatScreenManager and CatScreenManager.has_method("pin_cat"):
		print("  [OK] T4-14 pin/unpin/force_debut"); pc += 1
	else:
		print("  [XX] T4-14 pin/unpin"); fc += 1
	
	# T4-14b
	if load("res://core/CatSpawner.gd"):
		print("  [OK] T4-14b CatSpawner"); pc += 1
	else:
		print("  [XX] T4-14b"); fc += 1
	
	# T4-15
	if BreedUnlockEngine and BreedUnlockEngine.has_method("determine_breed"):
		var b = BreedUnlockEngine.determine_breed()
		print("  [OK] T4-15 BreedUnlockEngine -> " + b); pc += 1
	else:
		print("  [XX] T4-15"); fc += 1
	
	var total = pc + fc
	print("T4自检: " + str(pc) + "/" + str(total) + " PASS, " + str(fc) + " FAIL")
	if fc == 0:
		print("All PASS")
	else:
		print("FAIL items: " + str(fc))
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(fc)
