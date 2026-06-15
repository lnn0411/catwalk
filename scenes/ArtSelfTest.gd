extends Node2D
## 美术资产自检场景。F6 运行即可看到全部资产的加载与渲染验收结果。
## 资产按真机尺寸生成（2048x1536 横版花园），本场景把它自适应缩放进 720x1280 竖屏视口。

const VIEWPORT_SIZE := Vector2(720.0, 1280.0)
const CAT_WORLD_POSITION := Vector2(512.0, 1050.0)
const CAT_FRAME_INTERVAL := 0.5

# 资产清单：[显示名, 路径, 期望类型]。type 仅用于汇报。
const ASSETS := [
	["garden_far", "res://assets/art/garden/layers/garden_far.png", "Texture2D"],
	["garden_mid", "res://assets/art/garden/layers/garden_mid.png", "Texture2D"],
	["garden_near", "res://assets/art/garden/layers/garden_near.png", "Texture2D"],
	["garden_master", "res://assets/art/garden/garden_master.png", "Texture2D"],
	["layers_composite_preview", "res://assets/art/garden/layers_composite_preview.png", "Texture2D"],
	["mobile_safe_guides", "res://assets/art/garden/mobile_safe_guides.png", "Texture2D"],
	["idle_00", "res://assets/art/cats/orange_tabby/idle_00.png", "Texture2D"],
	["idle_01", "res://assets/art/cats/orange_tabby/idle_01.png", "Texture2D"],
	["idle_02", "res://assets/art/cats/orange_tabby/idle_02.png", "Texture2D"],
	["idle_sheet", "res://assets/art/cats/orange_tabby/idle_sheet.png", "Texture2D"],
	["action_buttons", "res://assets/art/ui/svg/action_buttons.svg", "Texture2D"],
	["bottom_nav_5_tabs", "res://assets/art/ui/svg/bottom_nav_5_tabs.svg", "Texture2D"],
	["hud_carry_cat_avatar", "res://assets/art/ui/svg/hud_carry_cat_avatar.svg", "Texture2D"],
	["hud_currency", "res://assets/art/ui/svg/hud_currency.svg", "Texture2D"],
	["hud_energy", "res://assets/art/ui/svg/hud_energy.svg", "Texture2D"],
	["hud_steps", "res://assets/art/ui/svg/hud_steps.svg", "Texture2D"],
	["ui_vector_masters_preview", "res://assets/art/ui/svg/ui_vector_masters_preview.svg", "Texture2D"],
	["ui_masters_preview", "res://assets/art/ui/ui_masters_preview.png", "Texture2D"],
]

const GARDEN_LAYER_KEYS := ["garden_far", "garden_mid", "garden_near"]
const CAT_FRAME_KEYS := ["idle_00", "idle_01", "idle_02"]
const SVG_KEYS := [
	"action_buttons", "bottom_nav_5_tabs", "hud_carry_cat_avatar", "hud_currency",
	"hud_energy", "hud_steps", "ui_vector_masters_preview",
]

enum ViewMode { FULL, LEFT, RIGHT }

var _loaded: Dictionary = {}   # name -> Resource (or null on failure)
var _results: Array = []       # [{name, path, ok}]
var _pass_count := 0
var _fail_count := 0

var _camera: Camera2D
var _world_root: Node2D
var _cat_sprite: Sprite2D
var _cat_frames: Array[Texture2D] = []
var _cat_frame_index := 0
var _cat_elapsed := 0.0

var _garden_size := VIEWPORT_SIZE
var _fit_zoom := 1.0
var _view_mode: int = ViewMode.FULL

var _dragging := false
var _drag_last := Vector2.ZERO

var _summary_label: Label
var _svg_label: Label
var _hint_label: Label
var _ui_preview: TextureRect


func _ready() -> void:
	_run_all_stages()


func _run_all_stages() -> void:
	_reset_state()
	_stage1_load_assets()
	_stage2_render_garden()
	_stage3_render_cat()
	_stage5_render_ui()
	_stage4_summary()   # 汇总最后建，便于读取前面阶段的结果


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
	_svg_label = null
	_hint_label = null
	_ui_preview = null


# --- Stage 1: 资产加载验证 ---------------------------------------------------

func _stage1_load_assets() -> void:
	_log("=== Stage 1: 资产加载验证 (%d 个) ===" % ASSETS.size())
	for entry in ASSETS:
		var asset_name: String = entry[0]
		var path: String = entry[1]
		var res: Resource = null
		if ResourceLoader.exists(path):
			res = load(path)
		var ok := res != null
		_loaded[asset_name] = res
		_results.append({"name": asset_name, "path": path, "ok": ok})
		if ok:
			_pass_count += 1
		else:
			_fail_count += 1
		_log("  %s %s" % ["✓" if ok else "✗", asset_name])
	_log("Stage 1 完成: %d 通过 / %d 失败" % [_pass_count, _fail_count])


# --- Stage 2: 花园渲染 -------------------------------------------------------

func _stage2_render_garden() -> void:
	_world_root = Node2D.new()
	_world_root.name = "WorldRoot"
	add_child(_world_root)

	var far := _texture("garden_far")
	if far != null:
		_garden_size = far.get_size()

	# 自适应缩放：让整张花园在竖屏里完整可见（按宽高取较小比例），不硬编码数值。
	_fit_zoom = min(VIEWPORT_SIZE.x / _garden_size.x, VIEWPORT_SIZE.y / _garden_size.y)

	for key in GARDEN_LAYER_KEYS:
		var tex := _texture(key)
		if tex == null:
			continue
		var sprite := Sprite2D.new()
		sprite.name = key
		sprite.texture = tex
		sprite.centered = false
		sprite.position = Vector2.ZERO   # 三层从 (0,0) 直接叠放，far->mid->near
		_world_root.add_child(sprite)

	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	add_child(_camera)
	_camera.make_current()
	_apply_view_mode()   # 默认 FULL，相机覆盖含 x=0 的整张花园


func _apply_view_mode() -> void:
	if _camera == null:
		return
	match _view_mode:
		ViewMode.FULL:
			_camera.zoom = Vector2(_fit_zoom, _fit_zoom)
			_camera.position = _garden_size * 0.5
		ViewMode.LEFT:
			var half_zoom := VIEWPORT_SIZE.x / (_garden_size.x * 0.5)
			_camera.zoom = Vector2(half_zoom, half_zoom)
			_camera.position = Vector2(_garden_size.x * 0.25, _garden_size.y * 0.5)
		ViewMode.RIGHT:
			var hz := VIEWPORT_SIZE.x / (_garden_size.x * 0.5)
			_camera.zoom = Vector2(hz, hz)
			_camera.position = Vector2(_garden_size.x * 0.75, _garden_size.y * 0.5)
	_update_hint()


# --- Stage 3: 橘猫动画 -------------------------------------------------------

func _stage3_render_cat() -> void:
	_cat_frames.clear()
	for key in CAT_FRAME_KEYS:
		var tex := _texture(key)
		if tex != null:
			_cat_frames.append(tex)
	if _cat_frames.is_empty():
		_log("Stage 3: 橘猫帧缺失，跳过动画")
		return
	_cat_sprite = Sprite2D.new()
	_cat_sprite.name = "OrangeTabby"
	_cat_sprite.centered = true
	_cat_sprite.position = CAT_WORLD_POSITION
	_cat_sprite.texture = _cat_frames[0]
	_cat_sprite.z_index = 10   # 永远盖在花园之上
	_world_root.add_child(_cat_sprite)


func _process(delta: float) -> void:
	if _cat_sprite == null or _cat_frames.size() < 2:
		return
	_cat_elapsed += delta
	if _cat_elapsed >= CAT_FRAME_INTERVAL:
		_cat_elapsed -= CAT_FRAME_INTERVAL
		_cat_frame_index = (_cat_frame_index + 1) % _cat_frames.size()
		_cat_sprite.texture = _cat_frames[_cat_frame_index]


# --- Stage 5: UI SVG 验证 ----------------------------------------------------

func _stage5_render_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	# 底部 UI 矢量预览缩略图。
	_ui_preview = TextureRect.new()
	_ui_preview.name = "UIPreview"
	_ui_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ui_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ui_preview.size = Vector2(VIEWPORT_SIZE.x - 40.0, 180.0)
	_ui_preview.position = Vector2(20.0, VIEWPORT_SIZE.y - 200.0)
	var preview_tex := _texture("ui_masters_preview")
	if preview_tex != null:
		_ui_preview.texture = preview_tex
	layer.add_child(_ui_preview)

	# SVG 加载状态列表。
	_svg_label = Label.new()
	_svg_label.name = "SVGStatus"
	_svg_label.position = Vector2(20.0, VIEWPORT_SIZE.y - 470.0)
	_svg_label.add_theme_font_size_override("font_size", 18)
	_svg_label.add_theme_color_override("font_color", Color.WHITE)
	_svg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_svg_label.add_theme_constant_override("outline_size", 4)
	var lines := ["UI SVG:"]
	for key in SVG_KEYS:
		var ok: bool = _loaded.get(key) != null
		lines.append("  %s %s" % ["✓" if ok else "✗", key])
	_svg_label.text = "\n".join(lines)
	layer.add_child(_svg_label)

	# 操作提示。
	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.position = Vector2(20.0, VIEWPORT_SIZE.y - 28.0)
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color.WHITE)
	_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_hint_label)
	_update_hint()


func _update_hint() -> void:
	if _hint_label == null:
		return
	var mode_name: String = ["全景", "左半", "右半"][_view_mode]
	_hint_label.text = "拖动平移 · Space 切换视图(当前:%s) · R 重新加载" % mode_name


# --- Stage 4: 结果汇总 -------------------------------------------------------

func _stage4_summary() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		hud = CanvasLayer.new()
		hud.name = "HUD"
		add_child(hud)

	_summary_label = Label.new()
	_summary_label.name = "Summary"
	_summary_label.position = Vector2(20.0, 20.0)
	_summary_label.add_theme_font_size_override("font_size", 24)
	_summary_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_summary_label.add_theme_constant_override("outline_size", 5)
	var all_pass := _fail_count == 0
	_summary_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4) if all_pass else Color(1.0, 0.35, 0.35))
	var total: int = ASSETS.size()
	_summary_label.text = "美术资产自检\n总数 %d · 通过 %d · 失败 %d" % [total, _pass_count, _fail_count]
	hud.add_child(_summary_label)

	# headless 模式下把完整结果打到 stdout。
	if DisplayServer.get_name() == "headless":
		print("==================== ART SELF TEST ====================")
		for r in _results:
			print("%s  %-28s %s" % ["[PASS]" if r.ok else "[FAIL]", r.name, r.path])
		print("-------------------------------------------------------")
		print("TOTAL=%d PASS=%d FAIL=%d -> %s" % [total, _pass_count, _fail_count, "ALL OK" if all_pass else "HAS FAILURES"])
		print("=======================================================")


# --- Stage 6: 交互 -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_drag_last = event.position
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		_drag_last = event.position
	elif event is InputEventMouseMotion and _dragging:
		_pan_camera(event.relative)
	elif event is InputEventScreenDrag:
		_pan_camera(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_view_mode = (_view_mode + 1) % ViewMode.size()
			_apply_view_mode()
		elif event.keycode == KEY_R:
			_log("R 按下：重新加载所有资产")
			_run_all_stages()


func _pan_camera(screen_delta: Vector2) -> void:
	if _camera == null:
		return
	# 屏幕位移换算到世界位移（除以 zoom），反向移动相机以跟手。
	_camera.position -= screen_delta / _camera.zoom


# --- 工具 --------------------------------------------------------------------

func _texture(asset_name: String) -> Texture2D:
	var res: Variant = _loaded.get(asset_name)
	return res as Texture2D


func _log(msg: String) -> void:
	print(msg)
