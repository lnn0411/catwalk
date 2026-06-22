extends Node

# T4-06 自检脚本 — 探索派遣入口 + 返回拆包
# 验证：新文件存在性 + UI场景实例化（不依赖autoload）

var _passed := 0
var _failed := 0

func _ready() -> void:
    print("\n========== T4-06 自检 ==========")
    _test_new_files_exist()
    _test_explore_instances()
    _print_summary()
    var code := 0 if _failed == 0 else 1
    get_tree().quit(code)

func _check(condition: bool, name: String) -> void:
    if condition:
        _passed += 1
        print("  ✓ %s" % name)
    else:
        _failed += 1
        print("  ✗ %s" % name)

func _test_new_files_exist() -> void:
    print("\n--- 新增文件存在性 ---")
    var files := [
        "res://scenes/ui/explore_duration_picker.tscn",
        "res://scenes/ui/explore_duration_picker.gd",
        "res://scenes/ui/explore_confirm_dialog.tscn",
        "res://scenes/ui/explore_confirm_dialog.gd",
        "res://scenes/ui/explore_return_animation.tscn",
        "res://scenes/ui/explore_return_animation.gd",
        "res://scenes/ui/postcard_reveal.tscn",
        "res://scenes/ui/postcard_reveal.gd",
    ]
    for f in files:
        _check(FileAccess.file_exists(f), "文件存在: %s" % f)

func _test_explore_instances() -> void:
    print("\n--- UI 组件实例化 ---")
    var scenes := [
        "res://scenes/ui/explore_duration_picker.tscn",
        "res://scenes/ui/explore_confirm_dialog.tscn",
        "res://scenes/ui/explore_return_animation.tscn",
        "res://scenes/ui/postcard_reveal.tscn",
    ]
    for s in scenes:
        var packed := load(s) as PackedScene
        if packed != null:
            var instance := packed.instantiate()
            _check(instance != null, "%s 实例化成功" % s.get_file())
            if instance != null:
                instance.queue_free()
        else:
            _check(false, "%s 加载失败" % s.get_file())

func _print_summary() -> void:
    print("\n--- 自检汇总 ---")
    print("通过: %d | 失败: %d | 共: %d" % [_passed, _failed, _passed + _failed])
