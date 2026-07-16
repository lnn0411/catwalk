extends CharacterBody2D
class_name CatSprite

signal cat_clicked(cat_data)

@export var breed: String = "orange" # orange / orange_tabby / british / siamese
@export var cat_data: Resource

@export_group("Movement")
@export var move_speed: float = 52.0
@export var acceleration: float = 7.0
@export var arrive_distance: float = 12.0
@export var wander_min_distance: float = 80.0
@export var wander_max_distance: float = 260.0
# 游荡范围必须与 CatSpawner 出生范围一致（X:350-1700, Y:380-640）。
# 否则猫出生在草坪却会自己走到 y=780 的泥土区 → 泥潭 bug 复发。
# 改这里务必同步 CatSpawner._pick_spawn_position / _setup_entrance 的同名数值。
@export var wander_x_min: float = 350.0
@export var wander_x_max: float = 1700.0
@export var wander_y_min: float = 380.0
@export var wander_y_max: float = 640.0

@export_group("Animation")
@export var walk_fps: float = 8.0
@export var idle_fps: float = 8.0

# 各动画独立帧率（覆盖全局 idle_fps。空/缺失 → 用全局默认值）
const PER_ANIM_FPS := {
	"british": {
		"idle_side_right": 5.0,
		"idle_back_right": 5.0,
		"idle_back": 5.0,
	},
}
@export var turn_fps: float = 5.0
@export var move_turn_fps: float = 7.0
const TURN_PAUSE := 0.6  # 停顿时慵懒转身的停顿秒数
@export var sprite_scale: float = 1.0
# 整图背景（garden_master.png）无透视梯度，景深缩放会让猫忽大忽小却与平铺草坪脱节。
# 故关闭，让猫在草坪任意位置保持稳定体型。换成带透视的分层背景时再开回 true。
@export var depth_scale_enabled: bool = false
@export var shadow_enabled: bool = true
@export var idle_breath_enabled: bool = true

@export_group("Chroma Key")
@export var chroma_key_enabled: bool = true
@export var chroma_key_threshold: float = 0.22
@export var chroma_key_softness: float = 0.08

const ARCHED_GROUND_Y := 1.0  # 脚底略高于阴影，避免垂直压在阴影上
const WALK_PX_BRITISH := 4.0

# 英短walk帧脚底像素透明度偏低(alpha≈66-87),需要额外下移补偿
const BREED_FOOT_BIAS := {
	"british": 4.0,
	"orange": 4.0,
	"orange_tabby": 4.0,
	"siamese": 0.0,
}

# 各品种视觉缩放系数（帧尺寸差异大时用这里拉齐，不依赖美术重出）
const BREED_VISUAL_SCALE := {
	"british": 0.45,
	"orange": 0.24,
	"orange_tabby": 0.24,
	"siamese": 1.0,
}

# 各品种每方向额外缩放（解决透视差异——侧面矮宽、正面高瘦）
# 数值 = 使该方向猫的视觉高度一致的额外缩放比例
const PER_ANIM_SCALE := {
	# 所有动画按可见高度归一化到76px屏幕高，解决走/停切换时忽大忽小
	"british": {
		"walk_right": 0.3004,
		"walk_up_right": 0.2804,
		"walk_up": 0.2405,
		"walk_down_right": 0.2382,
		"walk_down": 0.2129,
		"idle": 0.3016,
		"idle_front": 0.3016,
		"idle_side_right": 0.3016,
		"idle_front_right": 0.3128,
		"idle_back": 0.2405,
		"turn": 0.2815,
		"move_turn": 0.2815,
	},
	"siamese": {
		"walk_right": 0.2739,
		"walk_up_right": 0.3321,
		"walk_up": 0.2957,
		"walk_down_right": 0.2978,
		"walk_down": 0.2605,
		"idle": 0.2811,
		"idle_front": 0.2811,
		"idle_side_right": 0.2734,
		"idle_front_right": 0.2981,
		"idle_back_right": 0.2725,
		"idle_back": 0.2928,
		"idle_sit": 0.3009,
		"turn": 0.2734,
		"move_turn": 0.2734,
	},
	"orange": {
		"idle": 0.30,
		"idle_front": 0.30,
		"idle_back": 0.2382,
		"idle_back_right": 0.2382,
		"idle_front_right": 0.2382,
		"idle_side_right": 0.2382,
		"move_turn": 0.2382,
		"turn": 0.2382,
		"walk_down": 0.2117,
		"walk_down_right": 0.2382,
		"walk_right": 0.2382,
		"walk_up": 0.2382,
		"walk_up_right": 0.2382,
	},
}

# 预扫描的英短帧脚底y与水平质心偏移（避免运行时逐像素扫描拖慢加载）
const BRITISH_FRAME_METRICS := {
	"back": [{"f": 399, "x": -1.45}, {"f": 399, "x": 0.58}, {"f": 399, "x": 0.21}, {"f": 399, "x": 0.69}],
	"back_right": [{"f": 399, "x": -2.05}, {"f": 399, "x": 11.85}, {"f": 399, "x": 5.55}, {"f": 399, "x": 7.81}],
	"front": [{"f": 399, "x": -1.3}, {"f": 399, "x": 2.74}, {"f": 399, "x": -0.9}, {"f": 399, "x": -0.42}],
	"front_right": [{"f": 399, "x": -3.31}, {"f": 399, "x": 2.21}, {"f": 399, "x": -2.79}, {"f": 399, "x": 0.57}],
	"idle_back": [{"f": 399, "x": 1.15}, {"f": 399, "x": 2.29}, {"f": 399, "x": 0.46}, {"f": 399, "x": 0.89}, {"f": 399, "x": 0.04}, {"f": 399, "x": 0.75}],
	"idle_front": [{"f": 399, "x": 15.29}, {"f": 399, "x": 15.14}, {"f": 399, "x": 15.14}, {"f": 399, "x": 14.72}, {"f": 399, "x": 15.14}, {"f": 399, "x": 15.29}],
	"idle_front_right": [{"f": 480, "x": -1.69}, {"f": 480, "x": -0.82}, {"f": 480, "x": 0.67}, {"f": 480, "x": -0.25}, {"f": 480, "x": 0.03}, {"f": 480, "x": -0.43}, {"f": 480, "x": 0.93}, {"f": 480, "x": -0.31}],
	"idle_side_right": [{"f": 399, "x": -1.83}, {"f": 399, "x": -2.6}, {"f": 399, "x": -3.26}, {"f": 399, "x": -3.04}, {"f": 399, "x": -3.47}, {"f": 399, "x": -3.84}, {"f": 399, "x": -6.05}, {"f": 399, "x": -4.51}],
	"side_right": [{"f": 399, "x": 6.49}, {"f": 399, "x": 2.29}, {"f": 399, "x": 6.95}, {"f": 399, "x": 6.19}],
	"turn": [{"f": 399, "x": 6.17}, {"f": 399, "x": 0.42}],
}

const SIAMESE_FRAME_METRICS := {
	"back": [{"f": 391, "x": -0.06}, {"f": 391, "x": 0.49}, {"f": 391, "x": -3.25}, {"f": 391, "x": -0.75}, {"f": 391, "x": -0.4}, {"f": 391, "x": 0.04}, {"f": 391, "x": 0.51}, {"f": 391, "x": 0.75}],
	"back_right": [{"f": 394, "x": 19.24}, {"f": 393, "x": 19.77}, {"f": 394, "x": 18.86}, {"f": 393, "x": 16.98}, {"f": 394, "x": 17.92}, {"f": 394, "x": 19.4}, {"f": 393, "x": 17.35}, {"f": 394, "x": 16.34}],
	"front": [{"f": 391, "x": 4.2}, {"f": 390, "x": 5.45}, {"f": 391, "x": 1.16}, {"f": 391, "x": -2.42}],
	"front_right": [{"f": 390, "x": 7.31}, {"f": 390, "x": 7.46}, {"f": 390, "x": 6.28}, {"f": 390, "x": 3.46}],
	"idle_back": [{"f": 392, "x": 0.31}, {"f": 392, "x": 0.39}, {"f": 392, "x": 0.38}, {"f": 392, "x": -0.07}],
	"idle_back_right": [{"f": 399, "x": 13.93}, {"f": 399, "x": 13.52}, {"f": 399, "x": 13.17}, {"f": 399, "x": 10.14}],
	"idle_front": [{"f": 390, "x": 8.17}, {"f": 390, "x": 7.27}, {"f": 390, "x": 7.32}, {"f": 390, "x": 6.94}],
	"idle_front_right": [{"f": 390, "x": 5.07}, {"f": 390, "x": 5.57}, {"f": 390, "x": 4.89}, {"f": 390, "x": 5.11}],
	"idle_side_right": [{"f": 398, "x": 14.03}, {"f": 398, "x": 14.53}, {"f": 398, "x": 15.43}, {"f": 398, "x": 13.7}],
	"side_right": [{"f": 398, "x": 7.64}, {"f": 398, "x": 2.93}, {"f": 399, "x": 6.78}, {"f": 398, "x": 5.67}, {"f": 399, "x": 4.06}, {"f": 398, "x": 6.22}],
	"turn": [{"f": 398, "x": 6.22}, {"f": 398, "x": -2.36}, {"f": 399, "x": 1.4}],
	"idle_sit": [{"f": 389, "x": 6.71}, {"f": 389, "x": 10.33}, {"f": 389, "x": 10.61}, {"f": 389, "x": 7.86}],
}

const ORANGE_FRAME_METRICS := {
	"back": [{"f": 395, "x": 0.9}, {"f": 395, "x": 0.66}, {"f": 395, "x": -2.17}, {"f": 395, "x": -3.97}, {"f": 395, "x": -1.84}, {"f": 395, "x": -2.87}, {"f": 395, "x": -2.04}, {"f": 395, "x": -2.68}],
	"back_right": [{"f": 395, "x": 17.24}, {"f": 395, "x": 19.12}, {"f": 395, "x": 19.05}, {"f": 395, "x": 18.44}, {"f": 395, "x": 16.95}, {"f": 395, "x": 16.49}, {"f": 395, "x": 19.42}, {"f": 395, "x": 18.91}],
	"front": [{"f": 395, "x": -10.29}, {"f": 395, "x": -11.39}, {"f": 395, "x": -12.04}, {"f": 395, "x": -11.17}, {"f": 395, "x": -13.39}, {"f": 395, "x": -12.68}, {"f": 395, "x": -12.33}, {"f": 395, "x": -11.82}],
	"front_right": [{"f": 395, "x": 11.76}, {"f": 395, "x": 10.58}, {"f": 395, "x": 9.99}, {"f": 395, "x": 7.82}, {"f": 395, "x": 15.82}, {"f": 395, "x": 11.17}, {"f": 395, "x": 13.62}, {"f": 395, "x": 10.16}],
	"idle_back": [{"f": 395, "x": 0.97}, {"f": 395, "x": 4.75}, {"f": 395, "x": -2.58}, {"f": 395, "x": -1.97}, {"f": 395, "x": -2.42}, {"f": 395, "x": -2.08}, {"f": 395, "x": -4.05}, {"f": 395, "x": -3.94}],
	"idle_back_right": [{"f": 395, "x": 8.45}, {"f": 395, "x": 9.23}, {"f": 395, "x": 9.09}, {"f": 395, "x": 8.8}, {"f": 395, "x": 8.92}, {"f": 395, "x": 8.73}, {"f": 395, "x": 8.47}, {"f": 395, "x": 9.56}],
	"idle_front": [{"f": 395, "x": 3.65}, {"f": 395, "x": 4.94}, {"f": 395, "x": 5.68}, {"f": 395, "x": 3.73}, {"f": 395, "x": 4.43}, {"f": 395, "x": 4.61}, {"f": 395, "x": 4.64}, {"f": 395, "x": 5.65}],
	"idle_front_right": [{"f": 395, "x": 13.85}, {"f": 395, "x": 14.37}, {"f": 395, "x": 14.93}, {"f": 395, "x": 14.13}, {"f": 395, "x": 14.85}, {"f": 395, "x": 14.58}, {"f": 395, "x": 14.29}, {"f": 395, "x": 15.08}],
	"idle_side_right": [{"f": 395, "x": 9.86}, {"f": 395, "x": 11.69}, {"f": 395, "x": 10.86}, {"f": 395, "x": 10.65}, {"f": 395, "x": 11.38}, {"f": 395, "x": 9.76}, {"f": 395, "x": 10.69}, {"f": 395, "x": 10.44}],
	"side_right": [{"f": 395, "x": 30.98}, {"f": 395, "x": 30.85}, {"f": 395, "x": 32.09}, {"f": 395, "x": 29.57}, {"f": 395, "x": 32.01}, {"f": 395, "x": 31.03}, {"f": 395, "x": 32.47}, {"f": 395, "x": 33.48}],
	"turn": [{"f": 395, "x": -3.84}, {"f": 395, "x": 9.75}, {"f": 395, "x": 3.87}, {"f": 395, "x": 7.3}, {"f": 395, "x": -10.89}, {"f": 395, "x": -6.5}, {"f": 395, "x": 1.19}, {"f": 395, "x": -7.69}],
}

var _per_frame_foot_y := 395.0
var _per_frame_x_center := 0.0
var _current_frame_size := Vector2(400, 400)
const WALK_PX_ORANGE := 6.5
const WALK_PX_SIAMESE := 7.0

# 方向差异化步幅：side（侧面，脚位移大）/ up_right（斜向，中）/ front（正背面，小）
const WALK_PX_ORANGE_SIDE := 8.0
const WALK_PX_ORANGE_UPRIGHT := 5.5
const WALK_PX_ORANGE_FRONT := 6.0
const WALK_PX_BRITISH_SIDE := 7.0
const WALK_PX_BRITISH_UPRIGHT := 6.0
const WALK_PX_BRITISH_FRONT := 4.0
const WALK_PX_SIAMESE_SIDE := 7.0
const WALK_PX_SIAMESE_UPRIGHT := 6.0
const WALK_PX_SIAMESE_FRONT := 3.5

const BOB_AMPLITUDE := 0.0  # 走路踩地弹跳幅度（视觉像素，橘猫新帧脚底固定，不需弹跳）
const IDLE_HEIGHT_SCALE := 100.0 / 126.0  # ≈0.794

const ANIM_WALK_RIGHT := "walk_right"
const ANIM_WALK_UP_RIGHT := "walk_up_right"
const ANIM_WALK_UP := "walk_up"
const ANIM_WALK_DOWN_RIGHT := "walk_down_right"
const ANIM_WALK_DOWN := "walk_down"
const ANIM_IDLE := "idle"
const ANIM_TURN := "turn"
const ANIM_MOVE_TURN := "move_turn"
const ANIM_IDLE_SIT := "idle_sit"

# 预留的 idle 子动画（暂无对应 spritesheet，缺文件时 _load_frames 会静默跳过）
const ANIM_IDLE_SUB_1 := "idle_sub_1"
const ANIM_IDLE_SUB_2 := "idle_sub_2"
const ANIM_IDLE_SUB_3 := "idle_sub_3"
const ANIM_IDLE_SUB_4 := "idle_sub_4"
const ANIM_IDLE_SUB_5 := "idle_sub_5"

# 每个动画由多张独立 PNG 帧组成（_frameNN.png）。实际帧数以成功加载的贴图数为准，
# 此表仅作缺帧时的回退默认值 / 上限保留。
const ANIM_FRAME_COUNT := {
	ANIM_WALK_RIGHT: 8,
	ANIM_WALK_UP_RIGHT: 8,
	ANIM_WALK_UP: 8,
	ANIM_WALK_DOWN_RIGHT: 8,
	ANIM_WALK_DOWN: 8,
	ANIM_IDLE: 8,
	ANIM_TURN: 8,
	ANIM_MOVE_TURN: 8,
}

# _frames_cache[anim] = {textures: Array[Texture2D],
#                        metrics: Array[{foot_y: float, x_center: float}],
#                        frame_size: Vector2}
var _frames_cache: Dictionary = {}

var rng := RandomNumberGenerator.new()
var target_position := Vector2.ZERO
var is_moving := false

var _sprite: Sprite2D

var _current_anim := ANIM_IDLE
var _current_col := 0
var _frame_accum := 0.0
var _facing_left := false
var _last_motion_dir := Vector2.RIGHT

var _turn_playing := false
var _turn_frames_left := 0
var _turn_forward := true
var _turn_after_anim := ANIM_IDLE
var _turn_after_flip := false

var _move_dir := Vector2.ZERO
var _cur_speed := 0.0
var _idle_phase := 0.0
var _stuck_time := 0.0
var _walk_accum := 0.0
var _walk_px_table: Dictionary = {}
var _last_frame_pos := Vector2.ZERO
var _turn_cooldown := 0.0
var _footprint_timer := 0.0

var _wander_timer: Timer
var _bounce_tween: Tween
var _card_open := false  # CatCard 打开时锁住移动
var _explore_badge: Label  # 探索中头顶徽标（🧭 探索中），由 set_exploring 控制显隐
var _companion_badge: PanelContainer


func _ready() -> void:
	rng.randomize()
	target_position = position

	# 探索中徽标（🧭 探索中，头顶右上角显示，默认隐藏）
	var explore_badge := Label.new()
	explore_badge.name = "ExploreBadge"
	explore_badge.text = "🧭 探索中"
	explore_badge.add_theme_color_override("font_color", Color(1, 1, 1))
	explore_badge.add_theme_font_size_override("font_size", 20)
	explore_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explore_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	explore_badge.position = Vector2(20, -80)
	explore_badge.visible = false
	add_child(explore_badge)
	_explore_badge = explore_badge

	_setup_sprite()
	_load_frames()
	_setup_collision()
	_setup_click_area()

	_wander_timer = Timer.new()
	_wander_timer.one_shot = true
	add_child(_wander_timer)
	_wander_timer.timeout.connect(_on_wander_tick)

	# 位移驱动帧：品种 + 方向差异化步幅 + 初始位置
	_walk_px_table = _get_walk_px_per_frame()
	_last_frame_pos = global_position

	set_process(true)
	set_physics_process(true)

	_set_anim(ANIM_IDLE, false, true)
	_schedule_wander()
	_setup_companion_badge()


func _breed_dir() -> String:
	match breed:
		"orange", "orange_tabby":
			return "orange"
		"british":
			return "british"
		"siamese":
			return "siamese"
		_:
			return "orange"


func _anim_to_file_prefix(anim: String) -> String:
	match anim:
		ANIM_WALK_RIGHT:
			return "side_right"
		ANIM_WALK_UP_RIGHT:
			return "back_right"
		ANIM_WALK_UP:
			return "back"
		ANIM_WALK_DOWN_RIGHT:
			return "front_right"
		ANIM_WALK_DOWN:
			return "front"
		ANIM_IDLE:
			return "idle_front"
		ANIM_TURN, ANIM_MOVE_TURN:
			return "turn"
		# 方向化 idle（idle_side_right / idle_back_right / idle_back /
		# idle_front_right / idle_front）本身即文件前缀，原样透传。
		"idle_side_right", "idle_back_right", "idle_back", "idle_front_right", "idle_front":
			return anim
		# idle 子动画：前缀即自身；暂无 spritesheet，加载时缺文件会跳过，
		# 播放时若未加载则由 _apply_frame 回退到 idle_front。
		ANIM_IDLE_SUB_1, ANIM_IDLE_SUB_2, ANIM_IDLE_SUB_3, ANIM_IDLE_SUB_4, ANIM_IDLE_SUB_5:
			return anim
		_:
			return "front"


func _setup_sprite() -> void:
	for c in get_children():
		if c is Sprite2D:
			c.queue_free()

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)

	if chroma_key_enabled:
		_sprite.material = _make_chroma_key_material()


func _load_frames() -> void:
	var dir := _breed_dir()
	_frames_cache.clear()

	# 主要动画：走行各方向 + 正面 idle。每帧一张独立 PNG。
	var primary_anims := [
		ANIM_WALK_RIGHT, ANIM_WALK_UP_RIGHT, ANIM_WALK_UP,
		ANIM_WALK_DOWN_RIGHT, ANIM_WALK_DOWN, ANIM_IDLE,
	]
	for anim in primary_anims:
		var prefix := _anim_to_file_prefix(anim)
		_load_individual_frames(anim, dir, prefix)

	# 方向化 idle（idle_side_right / idle_back_right / idle_back /
	# idle_front_right / idle_front）：文件存在才加载，缺文件静默跳过。
	for idle_anim in ["idle_side_right", "idle_back_right", "idle_back", "idle_front_right", "idle_front"]:
		_try_load_anim(idle_anim, dir, idle_anim)

	# 预留 idle 子动画：多数品种暂无文件，缺文件静默跳过。
	for sub_anim in [ANIM_IDLE_SUB_1, ANIM_IDLE_SUB_2, ANIM_IDLE_SUB_3, ANIM_IDLE_SUB_4, ANIM_IDLE_SUB_5]:
		_try_load_anim(sub_anim, dir, _anim_to_file_prefix(sub_anim))

	# 转身动画（turn / move_turn 共用同一批 turn 帧，仅播放速率不同）
	_try_load_anim(ANIM_TURN, dir, "turn")
	_try_load_anim(ANIM_MOVE_TURN, dir, "turn")

	# 坐姿 idle（可选，文件存在才加载）
	_try_load_anim(ANIM_IDLE_SIT, dir, "idle_sit")

	if not _frames_cache.has(ANIM_IDLE):
		push_error("CatSprite: idle frames missing for breed %s" % dir)

	_apply_frame(ANIM_IDLE, 0)
	_apply_sprite_anchor(1.0, 1.0)


# 逐帧加载 {prefix}_frame_NN.png（NN 从 00 起），存入 _frames_cache[anim]。
# 缺帧即停止累加；一帧都没有则不写入缓存（由调用方判定回退）。
func _load_individual_frames(anim: String, breed_dir: String, prefix: String) -> void:
	var textures: Array[Texture2D] = []
	var metrics: Array[Dictionary] = []
	var frame_count: int = ANIM_FRAME_COUNT.get(anim, 8)
	var frame_w := 0.0
	var frame_h := 0.0

	for i in range(frame_count):
		var path := "res://assets/art/cats/%s/%s_frame_%02d.png" % [breed_dir, prefix, i]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		textures.append(tex)
		frame_w = maxf(frame_w, tex.get_width())
		frame_h = maxf(frame_h, tex.get_height())

		# 查预扫描常量表（每品种独立常量），跳过运行时逐像素扫描提升加载速度
		var breed_metrics := _get_breed_metrics()
		var cached_metrics: Array = breed_metrics.get(prefix, [])
		if i < cached_metrics.size():
			var cm: Dictionary = cached_metrics[i]
			metrics.append({
				"foot_y": float(cm.get("f", frame_h - 1.0)),
				"x_center": float(cm.get("x", 0.0)),
			})
		else:
			var img := tex.get_image()
			if img:
				metrics.append({
					"foot_y": float(_get_foot_offset_full(img)),
					"x_center": _get_x_center_fix_full(img),
				})
			else:
				metrics.append({"foot_y": frame_h - 1.0, "x_center": 0.0})

	if textures.is_empty():
		return

	# 所有帧使用平均 x_center，防止呼吸时猫身左右飘/抖
	var avg_x: float = 0.0
	for m in metrics:
		avg_x += m.get("x_center", 0.0)
	avg_x /= maxi(metrics.size(), 1)
	for m in metrics:
		m["x_center"] = avg_x

	_frames_cache[anim] = {
		"textures": textures,
		"metrics": metrics,
		"frame_size": Vector2(frame_w, frame_h),
	}


# 仅当首帧文件存在且尺寸合理(≥200px，排除旧100×140帧)时才加载该动画。
func _try_load_anim(anim: String, breed_dir: String, prefix: String) -> void:
	var path := "res://assets/art/cats/%s/%s_frame_00.png" % [breed_dir, prefix]
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if tex == null or tex.get_width() < 150:
		return
	_load_individual_frames(anim, breed_dir, prefix)


func _make_chroma_key_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec3 key_color = vec3(0.0, 1.0, 0.0);
uniform float threshold = 0.22;
uniform float softness = 0.08;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float d = distance(tex.rgb, key_color);
	float a = smoothstep(threshold, threshold + softness, d);
	COLOR = vec4(tex.rgb, tex.a * a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("threshold", chroma_key_threshold)
	mat.set_shader_parameter("softness", chroma_key_softness)
	return mat


func _setup_collision() -> void:
	collision_layer = 2
	collision_mask = 0

	var body_shape := CollisionShape2D.new()
	body_shape.position = Vector2(0, -42)
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	body_shape.shape = circle
	add_child(body_shape)


func _setup_click_area() -> void:
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	area.collision_layer = 4
	area.collision_mask = 0
	area.position = Vector2(0, -58)
	add_child(area)

	var click_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 44.0
	click_shape.shape = circle
	area.add_child(click_shape)

	area.input_event.connect(_on_input_event)


func _process(delta: float) -> void:
	if _card_open:
		return  # CatCard 打开时冻结移动
	_idle_phase += delta
	_turn_cooldown = maxf(0.0, _turn_cooldown - delta)

	_update_companion_badge()

	# Walk 动画：位移驱动（脚随身体走）；其他：时间驱动
	if _is_walk_anim(_current_anim):
		_advance_walk_by_distance()
	else:
		_advance_animation(delta)

	_apply_visual_motion(delta)
	_last_frame_pos = global_position

	if shadow_enabled:
		queue_redraw()


func _get_walk_px_per_frame() -> Dictionary:
	var side: float
	var up_right: float
	var front: float
	if breed == "british":
		side = WALK_PX_BRITISH_SIDE
		up_right = WALK_PX_BRITISH_UPRIGHT
		front = WALK_PX_BRITISH_FRONT
	elif breed == "orange" or breed == "orange_tabby":
		side = WALK_PX_ORANGE_SIDE
		up_right = WALK_PX_ORANGE_UPRIGHT
		front = WALK_PX_ORANGE_FRONT
	else:
		side = WALK_PX_SIAMESE_SIDE
		up_right = WALK_PX_SIAMESE_UPRIGHT
		front = WALK_PX_SIAMESE_FRONT
	return {
		ANIM_WALK_RIGHT: side,
		ANIM_WALK_DOWN_RIGHT: side,
		ANIM_WALK_UP_RIGHT: up_right,
		ANIM_WALK_UP: front,
		ANIM_WALK_DOWN: front,
	}


func _current_walk_px() -> float:
	return _walk_px_table.get(_current_anim, WALK_PX_ORANGE)


func _is_walk_anim(anim_name: String) -> bool:
	# 走路动画以 "walk_" 开头；idle/turn/move_turn/方向性idle 均不走位移驱动
	return anim_name.begins_with("walk_")


# 当前动画实际帧数：优先取已加载的贴图数，回退到 ANIM_FRAME_COUNT。
func _frame_count(anim_name: String) -> int:
	var entry: Dictionary = _frames_cache.get(anim_name, {})
	var textures: Array = entry.get("textures", [])
	if not textures.is_empty():
		return textures.size()
	return ANIM_FRAME_COUNT.get(anim_name, 8)


func _advance_walk_by_distance() -> void:
	var moved := global_position.distance_to(_last_frame_pos)
	_walk_accum += moved

	var px_per_frame := _current_walk_px()
	var max_frames: int = _frame_count(_current_anim)
	while _walk_accum >= px_per_frame:
		_walk_accum -= px_per_frame
		if _turn_playing and not _turn_forward:
			_current_col -= 1
			if _current_col < 0:
				_current_col = max_frames - 1
		else:
			_current_col += 1
		if _current_col >= max_frames:
			_current_col = 0
			if _turn_playing:
				_turn_playing = false
				_set_anim(_turn_after_anim, _turn_after_flip, true)
				return
		_apply_frame(_current_anim, _current_col)
		if _turn_playing:
			_turn_frames_left -= 1
			if _turn_frames_left <= 0:
				_turn_playing = false
				_set_anim(_turn_after_anim, _turn_after_flip, true)
				return


func _advance_animation(delta: float) -> void:
	var fps := _get_anim_fps(_current_anim)
	if fps <= 0.0:
		return

	_frame_accum += delta
	var frame_time := 1.0 / fps
	while _frame_accum >= frame_time:
		_frame_accum -= frame_time
		var max_frames: int = _frame_count(_current_anim)
		if _turn_playing and not _turn_forward:
			_current_col -= 1
			if _current_col < 0:
				_current_col = max_frames - 1
		else:
			_current_col += 1
		if _current_col >= max_frames:
			if _turn_playing:
				_turn_playing = false
				_set_anim(_turn_after_anim, _turn_after_flip, true)
				return
			_current_col = 0

		_apply_frame(_current_anim, _current_col)
		if _turn_playing:
			_turn_frames_left -= 1
			if _turn_frames_left <= 0:
				_turn_playing = false
				_set_anim(_turn_after_anim, _turn_after_flip, true)
				return


# 查品种对应的预扫描帧度量表（无表则返回空字典，走运行时扫描）
func _get_breed_metrics() -> Dictionary:
	match breed:
		"british", "british_shorthair":
			return BRITISH_FRAME_METRICS
		"siamese":
			return SIAMESE_FRAME_METRICS
		"orange":
			return ORANGE_FRAME_METRICS
		_:
			return {}


func _get_anim_fps(anim_name: String) -> float:
	# 先查 PER_ANIM_FPS 独立帧率（右下/右上 idle 加速等）
	var per_fps_breed: Dictionary = PER_ANIM_FPS.get(breed, {})
	if per_fps_breed.has(anim_name):
		return per_fps_breed[anim_name]
	if anim_name == ANIM_IDLE:
		return idle_fps
	if anim_name == ANIM_TURN:
		return turn_fps
	if anim_name == ANIM_MOVE_TURN:
		return move_turn_fps
	return walk_fps


func _set_anim(anim_name: String, flip_left: bool, force: bool = false) -> void:
	if _turn_playing and not force:
		return
	if not force and _current_anim == anim_name and _facing_left == flip_left:
		return

	_current_anim = anim_name
	_current_col = 0
	_frame_accum = 0.0
	_walk_accum = 0.0
	_facing_left = flip_left
	_sprite.flip_h = _facing_left
	_apply_frame(_current_anim, _current_col)


# 从底部向上扫描整张贴图，找到第一行含不透明像素（alpha>0.05），返回其 y。
func _get_foot_offset_full(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h - 1, -1, -1):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				return y
	return h - 1


# 扫描整张贴图不透明像素的水平质心，返回相对贴图中心的偏移（像素）。
func _get_x_center_fix_full(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var sum_x := 0.0
	var count := 0
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				sum_x += x
				count += 1
	if count > 0:
		return sum_x / float(count) - float(w) * 0.5
	return 0.0


func _apply_frame(anim: String, frame: int) -> void:
	_current_anim = anim
	var entry: Dictionary = _frames_cache.get(anim, {})
	if entry.is_empty():
		# 未加载（如 idle 子动画暂无文件）时回退到 idle_front。
		entry = _frames_cache.get(ANIM_IDLE, {})
		if entry.is_empty():
			return

	var textures: Array = entry.get("textures", [])
	if textures.is_empty():
		return

	var idx := frame % textures.size()
	var tex: Texture2D = textures[idx]

	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, tex.get_width(), tex.get_height())

	# 锚点用的每帧脚底/水平质心（整图局部坐标），加载时已预扫描。
	var metrics: Array = entry.get("metrics", [])
	if idx < metrics.size():
		var m: Dictionary = metrics[idx]
		_per_frame_foot_y = m.get("foot_y", tex.get_height() - 1.0)
		_per_frame_x_center = m.get("x_center", 0.0)
	else:
		_per_frame_foot_y = tex.get_height() - 1.0
		_per_frame_x_center = 0.0
	_current_frame_size = Vector2(tex.get_width(), tex.get_height())


func _apply_visual_motion(_delta: float) -> void:
	var depth_scale := 1.0
	if depth_scale_enabled:
		var t := clampf((position.y - wander_y_min) / maxf(wander_y_max - wander_y_min, 1.0), 0.0, 1.0)
		depth_scale = lerpf(0.82, 1.15, t)

	var sx := sprite_scale * depth_scale
	var sy := sx

	# 优先按每方向精确缩放（解决透视拉长/压扁差异），无则退到品种级
	var per_anim_breed: Dictionary = PER_ANIM_SCALE.get(breed, {})
	var per_anim_scale: float = per_anim_breed.get(_current_anim, 0.0)
	if per_anim_scale > 0.0:
		sx *= per_anim_scale
		sy *= per_anim_scale
	else:
		var breed_scale: float = BREED_VISUAL_SCALE.get(breed, 1.0)
		sx *= breed_scale
		sy *= breed_scale

	# IDLE_HEIGHT_SCALE 是为旧系统(100×140帧)设计的，新帧通过 PER_ANIM_SCALE 已包含idle缩放
	# 方向性 idle（idle_front/idle_side_right等）也应触发此回退
	if (_current_anim == ANIM_IDLE or _current_anim.begins_with("idle_")) and per_anim_scale <= 0.0:
		sx *= IDLE_HEIGHT_SCALE
		sy *= IDLE_HEIGHT_SCALE

	z_index = int(position.y)

	_sprite.rotation = 0.0
	_sprite.scale = Vector2(sx, sy)
	_apply_sprite_anchor(sx, sy)

	# 走路弹跳：每个位移帧内做一次半正弦踩地，只偏移 sprite 的 y，不动根节点
	if _is_walk_anim(_current_anim):
		var px := _current_walk_px()
		var phase := _walk_accum / px * PI
		_sprite.position.y += sin(phase) * BOB_AMPLITUDE * sy


func _apply_sprite_anchor(sx: float, sy: float) -> void:
	# Sprite2D region_enabled=true + centered=false：region 以其左上角对齐节点原点绘制
	# （region_rect.position 只选取源子矩形，不平移 sprite）。因此用 region 局部坐标锚定：
	# 把 region 水平居中于节点，并让脚底像素落在 ARCHED_GROUND_Y。frame_size 取自当前帧 region。
	var foot_bias: float = BREED_FOOT_BIAS.get(breed, 0.0)
	var fs := _current_frame_size
	_sprite.position = Vector2(
		-fs.x * 0.5 * sx - _per_frame_x_center * sx,
		-_per_frame_foot_y * sy + ARCHED_GROUND_Y + foot_bias
	)


func _idle_for_current_direction() -> String:
	# 根据最后移动方向选择对应的方向性待机动画
	# 只在新帧(400×400)存在时才切换，否则回退到正面idle
	var idle_name := ANIM_IDLE
	match _current_anim:
		ANIM_WALK_RIGHT:
			idle_name = "idle_side_right"
		ANIM_WALK_UP_RIGHT:
			idle_name = "idle_back_right"
		ANIM_WALK_UP:
			idle_name = "idle_back"
		ANIM_WALK_DOWN_RIGHT:
			idle_name = "idle_front_right"
		ANIM_WALK_DOWN:
			idle_name = "idle_front"
	
	# 校验方向性idle是否为400×400新帧，不是则用正面idle
	if idle_name != ANIM_IDLE:
		var entry: Dictionary = _frames_cache.get(idle_name, {})
		var textures: Array = entry.get("textures", [])
		if not textures.is_empty():
			var tex: Texture2D = textures[0]
			if tex.get_width() < 200:  # 旧帧100px宽，新帧400px
				idle_name = ANIM_IDLE
	
	# 15%概率坐下（需要idle_sit帧存在）
	if _frames_cache.has(ANIM_IDLE_SIT) and rng.randf() < 0.15:
		idle_name = ANIM_IDLE_SIT
	
	return idle_name

func _anim_to_turn_idx(anim: String) -> int:
	# 根据当前动画返回最近的转身帧起始索引
	# turn 帧序列: 00(背)→01(背右)→02(侧/背右)→03(前右)→04(正)→05(前左)→06(背左)→07(背)
	var dir := anim
	if dir.begins_with("walk_"):
		dir = dir.trim_prefix("walk_")
	elif dir.begins_with("idle_"):
		dir = dir.trim_prefix("idle_")
	match dir:
		"down", "front":      return 4
		"down_right", "front_right": return 3
		"right", "side_right": return 2
		"up_right", "back_right": return 1
		"up", "back":         return 0
	return 0


func _start_turn_anim(move_turn: bool, after_anim: String, after_flip: bool) -> void:
	# 行走中变方向 → 不播转身序列帧，直接切朝向+走
	if move_turn:
		_set_anim(after_anim, after_flip, true)
		return
	
	# 停顿时慵懒转身：保持当前姿态，短暂停顿后切到目标朝向
	_turn_playing = true
	var tw := create_tween()
	tw.tween_interval(TURN_PAUSE)
	tw.tween_callback(func():
		_set_anim(after_anim, after_flip, true)
		_turn_playing = false
	)


func _select_anim_from_direction(dir: Vector2) -> Dictionary:
	if dir.length() < 0.001:
		return {"anim": ANIM_IDLE, "flip": _facing_left}

	var deg := rad_to_deg(dir.angle())
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


func _physics_process(delta: float) -> void:
	if not is_moving:
		velocity = velocity.lerp(Vector2.ZERO, delta * acceleration)
		_cur_speed = velocity.length()
		return

	var to_target := target_position - position
	var dist := to_target.length()
	if dist <= arrive_distance:
		is_moving = false
		velocity = Vector2.ZERO
		_cur_speed = 0.0
		_move_dir = Vector2.ZERO
		_set_anim(_idle_for_current_direction(), _facing_left)
		_schedule_wander()
		return

	var desired_dir := to_target.normalized()
	desired_dir = _apply_separation(desired_dir)

	_move_dir = desired_dir if _move_dir == Vector2.ZERO else _move_dir.lerp(desired_dir, delta * 4.0).normalized()

	var target_speed := move_speed
	if dist < 90.0:
		target_speed = move_speed * maxf(dist / 90.0, 0.35)

	velocity = velocity.lerp(_move_dir * target_speed, delta * acceleration)
	_cur_speed = velocity.length()

	var before := position
	move_and_slide()
	var moved := position.distance_to(before)

	if moved > 0.01:
		_last_motion_dir = (position - before).normalized()
		var selected := _select_anim_from_direction(_last_motion_dir)
		var next_anim: String = selected["anim"]
		var next_flip: bool = selected["flip"]
		if next_flip != _facing_left and not _turn_playing and _turn_cooldown <= 0.0:
			_start_turn_anim(true, next_anim, next_flip)
			_turn_cooldown = 0.5
		else:
			_set_anim(next_anim, next_flip)

	_check_stuck(delta, moved)
	_clamp_to_wander_area()


func _apply_separation(desired_dir: Vector2) -> Vector2:
	var parent := get_parent()
	if parent == null:
		return desired_dir

	var separation := Vector2.ZERO
	var count := 0
	for child in parent.get_children():
		if child == self or not (child is Node2D):
			continue
		var d := position.distance_to(child.position)
		if d > 0.1 and d < 160.0:
			var push: Vector2 = (position - child.position).normalized()
			separation += push * ((1.0 - d / 160.0) * 3.0)
			count += 1

	if count == 0:
		return desired_dir

	separation /= count
	var dot_prod := separation.dot(desired_dir)
	if dot_prod < 0.0:
		separation -= dot_prod * desired_dir

	return (desired_dir + separation * 1.2).normalized()


func _check_stuck(delta: float, moved: float) -> void:
	var expected := maxf(_cur_speed * delta, 0.001)
	if expected > 1.0 and moved < expected * 0.35:
		_stuck_time += delta
	else:
		_stuck_time = 0.0

	if _stuck_time > 0.35:
		_stuck_time = 0.0
		_pick_new_target_away_from(_move_dir)


func _pick_new_target_away_from(blocked_dir: Vector2) -> void:
	var away := -blocked_dir
	if away.length() < 0.001:
		away = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))

	var angle := away.angle() + rng.randf_range(-PI / 3.0, PI / 3.0)
	var dist := rng.randf_range(wander_min_distance, wander_max_distance)
	target_position = position + Vector2(cos(angle), sin(angle) * 0.65) * dist
	target_position.x = clampf(target_position.x, wander_x_min, wander_x_max)
	target_position.y = clampf(target_position.y, wander_y_min, wander_y_max)
	is_moving = true


func _on_wander_tick() -> void:
	if rng.randf() < 0.12:
		_start_turn_anim(false, ANIM_IDLE, not _facing_left)
		_facing_left = not _facing_left
		_schedule_wander()
		return

	var dist := rng.randf_range(wander_min_distance, wander_max_distance)
	var angle := rng.randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle) * 0.65) * dist
	target_position = position + offset
	target_position.x = clampf(target_position.x, wander_x_min, wander_x_max)
	target_position.y = clampf(target_position.y, wander_y_min, wander_y_max)
	is_moving = true


func _schedule_wander() -> void:
	var r := rng.randf()
	var pause := rng.randf_range(0.4, 1.2) if r < 0.45 else (rng.randf_range(1.5, 3.5) if r < 0.85 else rng.randf_range(4.0, 7.0))
	_wander_timer.start(pause)


func _clamp_to_wander_area() -> void:
	position.x = clampf(position.x, wander_x_min, wander_x_max)
	position.y = clampf(position.y, wander_y_min, wander_y_max)


func face_direction(dx: float) -> void:
	if absf(dx) < 0.001:
		return
	var want_left := dx < 0.0
	if want_left == _facing_left:
		return
	_facing_left = want_left
	if is_moving:
		_start_turn_anim(true, _current_anim, want_left)
	else:
		_start_turn_anim(false, ANIM_IDLE, want_left)


func set_breed(new_breed: String) -> void:
	breed = new_breed
	_load_frames()
	_walk_px_table = _get_walk_px_per_frame()
	_set_anim(ANIM_IDLE, false, true)

# 按花园背景切换走行区
func set_wander_bounds(x_min: float, x_max: float, y_min: float, y_max: float) -> void:
	wander_x_min = x_min
	wander_x_max = x_max
	wander_y_min = y_min
	wander_y_max = y_max
	# 如果猫当前在范围外，拉回
	position.x = clampf(position.x, wander_x_min, wander_x_max)
	position.y = clampf(position.y, wander_y_min, wander_y_max)


# 显隐「探索中」头顶徽标（猫被派遣探索时显示）
func set_exploring(exploring: bool) -> void:
	if _explore_badge == null:
		return
	_explore_badge.visible = exploring


# CatCard 打开/关闭时冻结/恢复移动
func set_card_open(open: bool) -> void:
	_card_open = open
	if open:
		is_moving = false
		_wander_timer.stop()
	else:
		_schedule_wander()


func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_click_feedback()
		cat_clicked.emit(cat_data)


func _update_companion_icon() -> void:
	var icon := get_node_or_null("CompanionIcon") as Label
	if icon == null:
		return
	var is_companion: bool = false
	if HatchEngine and cat_data != null:
		var cid: String = String(cat_data.id)
		is_companion = cid != "" and cid == HatchEngine.current_companion_cat_id
	icon.visible = is_companion


func _play_click_feedback() -> void:
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()

	_bounce_tween = create_tween()
	_bounce_tween.tween_property(_sprite, "position:y", _sprite.position.y - 12.0, 0.10).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_callback(func() -> void:
		_apply_visual_motion(0.0)
	)

	var heart := Label.new()
	heart.text = "♥"
	heart.add_theme_font_size_override("font_size", 30)
	heart.add_theme_color_override("font_color", Color("#D98E8E"))
	heart.position = Vector2(-12.0, -96.0)
	add_child(heart)

	var ht := create_tween()
	ht.set_parallel(true)
	ht.tween_property(heart, "position:y", heart.position.y - 44.0, 0.7).set_ease(Tween.EASE_OUT)
	ht.tween_property(heart, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	ht.chain().tween_callback(heart.queue_free)


# 随行猫脚印粒子：走路时脚下弹出 🐾 浮标，上升淡出
func _spawn_footprint() -> void:
	if not _is_companion():
		return
	var fp := Label.new()
	fp.text = "🐾"
	fp.add_theme_font_size_override("font_size", 18)
	fp.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85, 0.9))
	fp.position = Vector2(-9, -5)
	fp.size = Vector2(18, 18)
	fp.z_index = -1
	add_child(fp)
	# 光晕层（大尺寸半透明）
	var glow := Label.new()
	glow.text = "🐾"
	glow.add_theme_font_size_override("font_size", 28)
	glow.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85, 0.2))
	glow.position = Vector2(-14, -10)
	glow.size = Vector2(28, 28)
	glow.z_index = -2
	add_child(glow)
	# 闪光星点
	var star := Label.new()
	star.text = "✦"
	star.add_theme_font_size_override("font_size", 10)
	star.add_theme_color_override("font_color", Color(0.6, 1.0, 0.95, 0.9))
	star.position = Vector2(-14, -18)
	star.size = Vector2(10, 10)
	star.z_index = -1
	add_child(star)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(fp, "position:y", fp.position.y - 18.0, 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(fp, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	t.tween_property(glow, "position:y", glow.position.y - 12.0, 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(glow, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	t.tween_property(star, "position", star.position + Vector2(4, -14), 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(star, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(func():
		fp.queue_free()
		glow.queue_free()
		star.queue_free()
	)


func _is_companion() -> bool:
	if not HatchEngine or cat_data == null:
		return false
	var cid: String = String(cat_data.id)
	return cid != "" and cid == HatchEngine.current_companion_cat_id


func _update_companion_badge() -> void:
	if _companion_badge == null:
		return
	_companion_badge.visible = _is_companion()


func _setup_companion_badge() -> void:
	_companion_badge = PanelContainer.new()
	_companion_badge.name = "CompanionBadge"
	_companion_badge.visible = false
	_companion_badge.position = Vector2(-60, -96)
	_companion_badge.size = Vector2(0, 0)
	_companion_badge.z_index = 20
	_companion_badge.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	_companion_badge.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/art/ui/icons/icon_paw.png") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(22, 22)
	row.add_child(icon)
	var label := Label.new()
	label.text = "随行中"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	add_child(_companion_badge)


func _draw() -> void:
	if shadow_enabled:
		_draw_oval(Vector2(0, 3), Vector2(24, 6), Color(0.12, 0.14, 0.06, 0.13))


func _draw_oval(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := float(i) / 24.0 * TAU
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	draw_colored_polygon(points, color)
