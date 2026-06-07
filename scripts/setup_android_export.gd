@tool
extends EditorPlugin

func _enter_tree() -> void:
	var sdk_path = "/home/agentuser/android-sdk"
	var java_path = "/usr/lib/jvm/java-17-openjdk-amd64"
	
	var settings = get_editor_interface().get_editor_settings()
	settings.set("export/android/android_sdk_path", sdk_path)
	settings.set("export/android/java_sdk_path", java_path)
	settings.set("export/android/debug_keystore", "res://../debug.keystore")
	settings.set("export/android/debug_keystore_user", "debug")
	settings.set("export/android/debug_keystore_pass", "android")
	
	get_editor_interface().play_main_scene()
	print("Settings configured, quitting...")
	get_tree().quit()
