extends Node2D
## 美术资产自检场景。F6 运行即可看到全部资产的加载与渲染验收结果。

const CAT_WORLD_POSITION := Vector2(512.0, 1050.0)
const CAT_FRAME_INTERVAL := 0.5

const ASSETS := [
	["garden_far", "res://assets/art/garden/layers/garden_far.png"],
	["garden_mid", "res://assets/art/garden/layers/garden_mid.png"],
	["garden_near", "res://assets/art/garden/layers/garden_near.png"],
	["garden_master", "res://assets/art/garden/garden_master.png"],
	["layers_composite_preview", "res://assets/art/garden/layers_composite_preview.png"],
	["mobile_safe_guides", "res://assets/art/garden/mobile_safe_guides.png"],
	["idle_00", "res://assets/art/cats/orange_tabby/idle_00.png"],
	["idle_01", "res://assets/art/cats/orange_tabby/idle_01.png"],
	["idle_02", "res://assets/art/cats/orange_tabby/idle_02.png"],
	["idle_sheet", "res://assets/art/cats/orange_tabby/idle_sheet.png"],
	["action_buttons", "res://assets/art/ui/svg/action_buttons.svg"],
	["bottom_nav_5_tabs", "res://assets/art/ui/svg/bottom_nav_5_tabs.svg"],
	["hud_carry_cat_avatar", "res://assets/art/ui/svg/hud_carry_cat_avatar.svg"],
	["hud_currency", "res://assets/art/ui/svg/hud_currency.svg"],
	["hud_energy", "res://assets/art/ui/svg/hud_energy.svg"],
	["hud_steps", "res://assets/art/ui/svg/hud_steps.svg"],
	["ui_vector_masters_preview", "res://assets/art/ui/svg/ui_vector_masters_preview.svg"],
	["ui_masters_preview", "res://assets/art/ui/ui_masters_preview.png"],
]

const GARDEN_LAYER_KEYS := ["garden_far", "garden_mid", "garden_near"]
const CAT_FRAME_KEYS := ["idle_00", "idle_01", "idle_02"]

enum ViewMode { FULL, LEFT, RIGHT }

var _loaded: Dictionary = {}
var _results: Array = []
var _pass_count := 0
var _fail_count := 0

var _camera: Camera2D
var _world_root: Node2D
var _cat_sprite: Sprite2D
var _cat_frames: Array[Texture2D] = []
var _cat_frame_index := 0
var _cat_elapsed := 0.0

var _garden_size := Vector2(2048.0, 1536.0)
var _fit_zoom := 1.0
var _view_mode: int = ViewMode.FULL

var _dragging := false
var _drag_last := Vector2.ZERO

var _summary_label: Label
var _hint_label: Label


func _ready() -> void:
	_run_all_stages()


func _run_all_stages() -> void:
	_reset_state()
	_stage1_load_assets()
	_stage2_render_garden()
	_stage3_render_cat()
	_stage4_summary()
	_print_full_report()


func _reset_state() -> void:
	_loaded.clear()
	_results.clear()
	_pass_count = 0
	_fail_count = 0
	for child in get_children():
		child.queue_free()
	_camera = null
	_world_root = null
	_cat_sprite = null
	_cat_frames.clear()
	_cat_frame_index = 0
	_cat_elapsed = 0.0
	_summary_label = null
	_hint_label = null


func _stage1_load_assets() -> void:
	print("=== Stage 1: 资产加载 (%d 个) ===" % ASSETS.size())
	for entry in ASSETS:
		var asset_name: String = entry[0]
		var path: String = entry[1]
		var res: Resource
		if ResourceLoader.exists(path):
			res = load(path)
		var ok := res != null
		_loaded[asset_name] = res
		_results.append({"name": asset_name, "path": path, "ok": ok})
		if ok:
			_pass_count += 1
		else:
			_fail_count += 1
		print("  %s %s" % ["PASS" if ok else "FAIL", asset_name])
	print("Stage 1: %d/%d 通过" % [_pass_count, _fail_count + _pass_count])


func _stage2_render_garden() -> void:
	_world_root = Node2D.new()
	_world_root.name = "WorldRoot"
	add_child(_world_root)

	var far = _loaded.get("garden_far")
	if far is Texture2D:
		_garden_size = far.get_size()

	for key in GARDEN_LAYER_KEYS:
		var raw = _loaded.get(key)
		if raw is Texture2D:
			var tex: Texture2D = raw
			var sprite := Sprite2D.new()
			sprite.name = key
			sprite.texture = tex
			sprite.centered = false
			_world_root.add_child(sprite)

	var vp := get_viewport_rect().size
	_fit_zoom = min(vp.x / _garden_size.x, vp.y / _garden_size.y) * 0.9

	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.make_current()
	add_child(_camera)
	_apply_view_mode()


func _apply_view_mode() -> void:
	if _camera == null:
		return
	var vp := get_viewport_rect().size
	match _view_mode:
		ViewMode.FULL:
			_camera.zoom = Vector2(_fit_zoom, _fit_zoom)
			_camera.position = _garden_size * 0.5
		ViewMode.LEFT:
			var hz := vp.x / (_garden_size.x * 0.5)
			_camera.zoom = Vector2(hz, hz)
			_camera.position = Vector2(_garden_size.x * 0.25, _garden_size.y * 0.5)
		ViewMode.RIGHT:
			var hz := vp.x / (_garden_size.x * 0.5)
			_camera.zoom = Vector2(hz, hz)
			_camera.position = Vector2(_garden_size.x * 0.75, _garden_size.y * 0.5)


func _stage3_render_cat() -> void:
	for key in CAT_FRAME_KEYS:
		var raw = _loaded.get(key)
		if raw is Texture2D:
			_cat_frames.append(raw)
	if _cat_frames.is_empty():
		return
	_cat_sprite = Sprite2D.new()
	_cat_sprite.name = "OrangeTabby"
	_cat_sprite.centered = true
	_cat_sprite.position = CAT_WORLD_POSITION
	_cat_sprite.texture = _cat_frames[0]
	_cat_sprite.z_index = 10
	_world_root.add_child(_cat_sprite)


func _stage4_summary() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 100
	add_child(hud)

	var vp := get_viewport_rect().size
	var all_pass := _fail_count == 0
	var total: int = ASSETS.size()

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.position = Vector2.ZERO
	bg.size = Vector2(vp.x, 60.0)
	hud.add_child(bg)

	_summary_label = Label.new()
	_summary_label.name = "Summary"
	_summary_label.position = Vector2(16.0, 10.0)
	_summary_label.add_theme_font_size_override("font_size", 22)
	_summary_label.add_theme_color_override("font_color", Color.GREEN if all_pass else Color.RED)
	_summary_label.text = "TOTAL=%d  PASS=%d  FAIL=%d  %s" % [total, _pass_count, _fail_count, "ALL OK" if all_pass else "HAS FAILURES"]
	hud.add_child(_summary_label)

	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.position = Vector2(16.0, vp.y - 28.0)
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_hint_label.text = "拖动平移 | Space切换视图 | R重载"
	hud.add_child(_hint_label)


func _print_full_report() -> void:
	var all_pass := _fail_count == 0
	print("=============== ART SELF TEST ===============")
	for r in _results:
		print("%s  %s  %s" % ["[PASS]" if r.ok else "[FAIL]", r.name, r.path])
	print("TOTAL=%d PASS=%d FAIL=%d -> %s" % [ASSETS.size(), _pass_count, _fail_count, "ALL OK" if all_pass else "HAS FAILURES"])
	print("==============================================")


func _process(delta: float) -> void:
	if _cat_sprite == null or _cat_frames.size() < 2:
		return
	_cat_elapsed += delta
	if _cat_elapsed >= CAT_FRAME_INTERVAL:
		_cat_elapsed -= CAT_FRAME_INTERVAL
		_cat_frame_index = (_cat_frame_index + 1) % _cat_frames.size()
		_cat_sprite.texture = _cat_frames[_cat_frame_index]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_drag_last = event.position
	elif event is InputEventMouseMotion and _dragging:
		_pan_camera(event.relative)
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		_drag_last = event.position
	elif event is InputEventScreenDrag:
		_pan_camera(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_view_mode = (_view_mode + 1) % ViewMode.size()
			_apply_view_mode()
		elif event.keycode == KEY_R:
			_run_all_stages()


func _pan_camera(screen_delta: Vector2) -> void:
	if _camera == null:
		return
	_camera.position -= screen_delta / _camera.zoom
