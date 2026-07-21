extends Node

func _ready() -> void:
	var tex_path := "res://assets/art/postcards/conv_store_orange_01.png"
	
	print("=== 明信片图片诊断 ===")
	print("路径: ", tex_path)
	print("文件存在(FileAccess): ", FileAccess.file_exists(tex_path))
	print("资源存在(ResourceLoader): ", ResourceLoader.exists(tex_path))
	
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		print("加载成功: ", tex != null)
		if tex:
			print("尺寸: ", tex.get_width(), "x", tex.get_height())
	else:
		# 尝试 Image 直接读取
		var img := Image.new()
		var from_res := img.load(tex_path)
		print("Image.load(res://): ", "OK" if from_res == OK else "失败(" + str(from_res) + ")")
		
		var abs_path := ProjectSettings.globalize_path(tex_path)
		print("绝对路径: ", abs_path)
		print("绝对路径文件存在: ", FileAccess.file_exists(abs_path))
		var from_abs := img.load(abs_path)
		print("Image.load(绝对路径): ", "OK" if from_abs == OK else "失败(" + str(from_abs) + ")")
		
		if from_abs == OK:
			var tex2 = ImageTexture.create_from_image(img)
			print("ImageTexture创建: ", tex2 != null, " 尺寸: ", img.get_width(), "x", img.get_height())
	
	print("=== 目录扫描 ===")
	var dir := DirAccess.open("res://assets/art/postcards/")
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			print("  文件: ", f)
			f = dir.get_next()
		dir.list_dir_end()
	else:
		print("无法打开目录 res://assets/art/postcards/")
		
		# 试试父目录
		var parent := DirAccess.open("res://assets/art/")
		if parent:
			parent.list_dir_begin()
			var f2 := parent.get_next()
			while f2 != "":
				if parent.current_is_dir():
					print("  子目录: ", f2)
				f2 = parent.get_next()
			parent.list_dir_end()
	
	print("=== 诊断结束 ===")
	get_tree().quit()
