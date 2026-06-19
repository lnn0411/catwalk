extends "res://ui/UIPage.gd"

# ============================================================
# S08 孵化演出 —— P0 打磨版
# ------------------------------------------------------------
# 对照 GDD §6.1 演出脚本，本版补齐：
#   ① 蛋震动（裂纹越深抖越狠）+ 手机震动三连（Juice.pattern_crack）
#   ② Phase1→2 全屏白闪 250ms
#   ③ 稀有度揭晓分级：common 无 / rare 蓝星光环绕 /
#      epic 紫色光柱 / legendary 彩虹光环×3 + 揭晓前憋 0.5s + 双长震
#   ④ 揭晓弹性：猫 scale 0.8→1.06→1.0
#   ⑤ 删除旁白文字（"蛋壳裂开了/有个身影出现"）——演出自己说话
# 时序结构 / 命名衔接 / pop_to_root 与原版一致，逻辑层未动。
# 依赖：autoload Juice（res://autoload/Juice.gd）。若未注册 Juice，
#       演出仍正常播放，只是没有震动（有判空保护）。
# ============================================================

const CatData := preload("res://core/CatData.gd")

var _cat
var _elapsed := 0.0
var _overlay_shown := false
var _waiting_for_name := false
var _phase := 1

# —— 演出状态 ——
var _flash_alpha := 0.0          # 全屏白闪剩余强度
var _prev_phase := 1             # 用于检测 phase 切换瞬间
var _crack_vibrated := false     # 蛋裂震动只触发一次
var _reveal_vibrated := false    # 揭晓震动只触发一次
var _leg_hold := 0.0             # legendary 揭晓前的"憋"时长（秒）
var _star_seeds: Array = []      # rare 星光粒子的随机相位（确定性）
# —— M6 演出 P1 ——
var _gold_seeds: Array = []      # 金色汇聚粒子的起始方位/速度相位
var _shards: Array = []          # 蛋壳碎片 [{pos, vel, rot, rot_speed}]
var _shard_time := 0.0           # 碎片已飞行时长

# 美术图占位框架：背景就位则用 TextureRect，否则回退到 _draw() 代码铺底。
# 蛋壳碎裂序列 / 稀有度光效是动画逻辑，保持代码绘制；此处只为背景做贴图位。
const ART_BG_PATH := "res://assets/art/ui/hatch_show_bg.png"
const ART_EGG_CRACK_SHEET := "res://assets/art/ui/hatch_egg_crack_sheet.png"  # 预期蛋壳碎裂序列（动画仍代码实现）
const ART_LIGHT_SHEET := "res://assets/art/ui/hatch_light_sheet.png"          # 预期稀有度光效（动画仍代码实现）

var _art_bg := false
var _art_crack_sheet: Texture2D = null  # 蛋壳序列贴图就位则缓存备用，当前演出仍走代码

func _ready() -> void:
	super._ready()
	set_process(true)
	_build_art_layers()
	# rare 星光粒子相位（固定种子，每次演出一致即可）
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260612
	for i in range(10):
		_star_seeds.append(rng.randf_range(0.0, TAU))
	# M6：金色汇聚粒子（16颗，从屏幕四周向蛋汇聚）
	for i in range(16):
		_gold_seeds.append({
			"angle": rng.randf_range(0.0, TAU),
			"dist": rng.randf_range(420.0, 640.0),
			"speed": rng.randf_range(0.55, 1.0),
			"phase": rng.randf_range(0.0, 1.0),
		})

# 用 load() 而非 preload()：美术图可能尚未就位，preload 缺文件会编译失败。
func _build_art_layers() -> void:
	_art_bg = ResourceLoader.exists(ART_BG_PATH)
	%Bg.visible = _art_bg
	if _art_bg:
		%Bg.texture = load(ART_BG_PATH)
	if ResourceLoader.exists(ART_EGG_CRACK_SHEET):
		_art_crack_sheet = load(ART_EGG_CRACK_SHEET)

func _on_page_setup(data: Dictionary) -> void:
	_cat = data.get("cat", null)
	# legendary：揭晓前多停 0.5s（憋一下再爆）
	if _cat != null and String(_cat.rarity) == CatData.RARITY_LEGENDARY:
		_leg_hold = 0.5

func _process(delta: float) -> void:
	if _waiting_for_name:
		queue_redraw()
		return
	_elapsed += delta
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(_flash_alpha - delta * 4.0, 0.0)  # 250ms 内衰减完
	# M6：碎片物理（飞出 + 重力下落，0.9s 后清空）
	if not _shards.is_empty():
		_shard_time += delta
		for s in _shards:
			s["vel"] = Vector2(s["vel"]) + Vector2(0.0, 900.0) * delta
			s["pos"] = Vector2(s["pos"]) + Vector2(s["vel"]) * delta
			s["rot"] = float(s["rot"]) + float(s["rot_speed"]) * delta
		if _shard_time > 0.9:
			_shards.clear()
	_update_phase()
	queue_redraw()

func handle_back() -> bool:
	return true

func _draw() -> void:
	var screen := get_viewport_rect().size
	if not _art_bg:  # 背景美术未就位时才用代码铺底色
		draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_CEMENT)
	var center := screen * 0.5
	match _phase:
		1:
			_draw_cracking_egg(center)
		2:
			_draw_flash_silhouette(center)
		3:
			_draw_reveal(center, _reveal_zoom())
		4:
			var zoom: float = clamp(1.0 - (_elapsed - _phase4_start()) / 1.5 * 0.35, 0.65, 1.0)
			_draw_reveal(center, zoom)
	# M6：蛋壳碎片（盖在场景上、白闪之下）
	if not _shards.is_empty():
		var shard_alpha: float = clampf(1.0 - _shard_time / 0.9, 0.0, 1.0)
		for s in _shards:
			_draw_shard(Vector2(s["pos"]), float(s["rot"]), Color(_cat_color_light(), shard_alpha))
	# 全屏白闪盖在最上层
	if _flash_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(1.0, 1.0, 1.0, _flash_alpha))

# M6：白闪瞬间从蛋位置弹出 6 片蛋壳碎片
func _spawn_shards() -> void:
	var center := get_viewport_rect().size * 0.5 + Vector2(0.0, -80.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260613
	_shards.clear()
	_shard_time = 0.0
	for i in range(6):
		var ang := -PI * 0.5 + rng.randf_range(-1.3, 1.3)  # 大体向上扇形
		var speed := rng.randf_range(420.0, 720.0)
		_shards.append({
			"pos": center + Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-80.0, 40.0)),
			"vel": Vector2(cos(ang), sin(ang)) * speed,
			"rot": rng.randf_range(0.0, TAU),
			"rot_speed": rng.randf_range(-9.0, 9.0),
		})

func _draw_shard(pos: Vector2, rot: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for base in [Vector2(0.0, -22.0), Vector2(18.0, 12.0), Vector2(-16.0, 14.0)]:
		pts.append(pos + base.rotated(rot))
	draw_polygon(pts, PackedColorArray([color, color, color]))

func _update_phase() -> void:
	var skip_phase_2 := _is_first_orange()
	var new_phase := _phase
	if _elapsed < 3.0:
		new_phase = 1
	elif not skip_phase_2 and _elapsed < 6.5 + _leg_hold:
		new_phase = 2
	elif _elapsed < _phase4_start():
		new_phase = 3
	else:
		new_phase = 4

	# —— phase 切换瞬间的一次性效果 ——
	if new_phase != _prev_phase:
		if new_phase == 2 or (skip_phase_2 and new_phase == 3):
			_flash_alpha = 1.0           # 全屏白闪
			_spawn_shards()              # M6：蛋壳碎片弹飞
		if new_phase == 3:
			_on_reveal_moment()          # 揭晓瞬间：震动
		_prev_phase = new_phase
	_phase = new_phase

	if _phase == 1 and _elapsed > 1.2 and not _crack_vibrated:
		_crack_vibrated = true
		_juice_crack()
	if _phase == 3:
		_show_name_popup_once()
	if _phase == 4 and _elapsed >= _phase4_start() + 1.5:
		UIManager.pop_to_root()

func _phase4_start() -> float:
	return 5.0 if _is_first_orange() else 8.5 + _leg_hold

func _on_reveal_moment() -> void:
	if _reveal_vibrated:
		return
	_reveal_vibrated = true
	if _cat != null and String(_cat.rarity) == CatData.RARITY_LEGENDARY:
		_juice_legendary()
	else:
		_juice_reward()

# —— Juice 判空封装（未注册 Juice 时演出照常，只是无震动）——
func _juice_crack() -> void:
	var j := get_node_or_null("/root/Juice")
	if j: j.pattern_crack()

func _juice_reward() -> void:
	var j := get_node_or_null("/root/Juice")
	if j: j.reward()

func _juice_legendary() -> void:
	var j := get_node_or_null("/root/Juice")
	if j: j.pattern_legendary()

func _show_name_popup_once() -> void:
	if _overlay_shown:
		return
	_overlay_shown = true
	_waiting_for_name = true
	UIManager.show_overlay("res://scenes/S06_NamePopup.tscn", {"cat": _cat, "hatch_show": self})

func resume_after_name_popup() -> void:
	_waiting_for_name = false
	_elapsed = _phase4_start()

func _is_first_orange() -> bool:
	if _cat == null:
		return false
	return String(_cat.species) == CatData.BREED_ORANGE and int(_cat.hatch_index) == 1

# ============ Phase 1：蛋震动 + 裂纹加深 ============
func _draw_cracking_egg(center: Vector2) -> void:
	var crack: float = clamp(_elapsed / 3.0, 0.0, 1.0)
	# M6：金色粒子从四周向蛋汇聚（0.5s 后开始，对应 GDD 金色光芒汇聚）
	if _elapsed > 0.5:
		var egg_target := center + Vector2(0.0, -80.0)
		for g in _gold_seeds:
			var travel := fmod((_elapsed - 0.5) * float(g["speed"]) * 0.55 + float(g["phase"]), 1.0)
			var dist: float = float(g["dist"]) * (1.0 - travel)
			var pos: Vector2 = egg_target + Vector2(cos(float(g["angle"])), sin(float(g["angle"]))) * dist
			var p_alpha: float = clampf(travel * 1.6, 0.0, 0.85)
			draw_circle(pos, 3.0 + travel * 2.5, Color(Palette.AMBER, p_alpha))
	# 蛋震动：裂纹越深抖越狠（0→1 时振幅 0→6px，频率约 40Hz）
	var shake_amp := crack * 6.0
	var shake := Vector2(
		sin(_elapsed * 40.0) * shake_amp,
		cos(_elapsed * 37.0) * shake_amp * 0.6
	)
	var egg_center := center + Vector2(0.0, -80.0) + shake
	draw_ellipse(egg_center, 150.0, 200.0, _cat_color_light())
	# 裂纹随蛋一起抖
	for i in range(4):
		var x := egg_center.x - 36.0 + i * 24.0
		draw_line(
			Vector2(x, egg_center.y - 100.0 + i * 28.0),
			Vector2(x + 28.0 * crack, egg_center.y - 68.0 + i * 28.0),
			Palette.TEXT_PRIMARY, 5.0
		)
	# 末段：蛋底部透出稀有度光（预告，憋张力）
	if crack > 0.75:
		var leak := (crack - 0.75) / 0.25
		draw_circle(egg_center + Vector2(0.0, 90.0), 80.0 * leak, Color(_rarity_color(), 0.25 * leak))

# ============ Phase 2：剪影（白闪后浮现）============
func _draw_flash_silhouette(center: Vector2) -> void:
	var pulse := (sin(_elapsed * 8.0) + 1.0) * 0.5
	draw_circle(center, 310.0 + pulse * 30.0, Color(_rarity_color(), 0.30))
	_draw_cat_shape(center, Palette.TEXT_PRIMARY, 1.15)

# ============ Phase 3/4：揭晓 + 稀有度分级特效 ============
func _reveal_zoom() -> float:
	# 揭晓弹性：进入 Phase3 后 0.35s 内 0.8 → 1.06 → 1.0
	var t: float = _elapsed - (3.0 if _is_first_orange() else 6.5 + _leg_hold)
	if t < 0.0:
		return 0.8
	if t < 0.2:
		return lerpf(0.8, 1.06, t / 0.2)
	if t < 0.35:
		return lerpf(1.06, 1.0, (t - 0.2) / 0.15)
	return 1.0

func _draw_reveal(center: Vector2, zoom: float) -> void:
	_draw_rarity_fx(center, zoom)
	draw_circle(center, 320.0 * zoom, Color(_rarity_color(), 0.22))
	_draw_cat_shape(center, _cat_color_mid(), zoom)
	var cat_name: String = String(_cat.display_name) if _cat != null else "New Cat"
	_draw_centered_text(cat_name, center.y + 300.0 * zoom, 36, Palette.TEXT_PRIMARY)

func _draw_rarity_fx(center: Vector2, zoom: float) -> void:
	if _cat == null:
		return
	match String(_cat.rarity):
		CatData.RARITY_RARE:
			_fx_rare_stars(center, zoom)
		CatData.RARITY_EPIC:
			_fx_epic_pillar(center, zoom)
		CatData.RARITY_LEGENDARY:
			_fx_legendary_rings(center, zoom)
		_:
			pass  # common：无特效，对比才有惊喜

# rare：10 颗蓝色星光绕猫旋转
func _fx_rare_stars(center: Vector2, zoom: float) -> void:
	for i in range(_star_seeds.size()):
		var ang: float = _star_seeds[i] + _elapsed * 0.9
		var radius: float = (240.0 + sin(_elapsed * 2.0 + float(i)) * 26.0) * zoom
		var pos := center + Vector2(cos(ang), sin(ang) * 0.82) * radius
		var star_size: float = (3.0 + sin(_elapsed * 5.0 + float(i) * 1.7) * 2.0) * zoom
		draw_circle(pos, maxf(star_size, 1.0), Color(Palette.RARITY_RARE, 0.9))
		draw_circle(pos, maxf(star_size, 1.0) * 2.2, Color(Palette.RARITY_RARE, 0.25))

# epic：紫色光柱从猫底升起 + 顶端呼吸
func _fx_epic_pillar(center: Vector2, zoom: float) -> void:
	var pulse := (sin(_elapsed * 3.0) + 1.0) * 0.5
	var w := (130.0 + pulse * 24.0) * zoom
	var top_y := center.y - (430.0 + pulse * 40.0) * zoom
	var bot_y := center.y + 200.0 * zoom
	# 三层渐窄光柱叠出柔边
	draw_rect(Rect2(center.x - w, top_y, w * 2.0, bot_y - top_y), Color(Palette.RARITY_EPIC, 0.10))
	draw_rect(Rect2(center.x - w * 0.62, top_y, w * 1.24, bot_y - top_y), Color(Palette.RARITY_EPIC, 0.14))
	draw_rect(Rect2(center.x - w * 0.3, top_y, w * 0.6, bot_y - top_y), Color(Palette.RARITY_EPIC, 0.20))

# legendary：彩虹色光环扩散 ×3（错相循环）
func _fx_legendary_rings(center: Vector2, zoom: float) -> void:
	for i in range(3):
		var t := fmod(_elapsed * 0.6 + float(i) / 3.0, 1.0)
		var radius := (180.0 + t * 320.0) * zoom
		var alpha := (1.0 - t) * 0.5
		var hue := fmod(_elapsed * 0.15 + float(i) * 0.33, 1.0)
		var ring_color := Color.from_hsv(hue, 0.45, 1.0, alpha)
		draw_arc(center, radius, 0.0, TAU, 64, ring_color, 10.0 * (1.0 - t * 0.5))
	# 双色底光（用 Palette 的 legendary 双色）
	var p := (sin(_elapsed * 2.2) + 1.0) * 0.5
	draw_circle(center, 360.0 * zoom, Color(Palette.RARITY_LEG_A.lerp(Palette.RARITY_LEG_B, p), 0.16))

# ============ 共用绘制 ============
func _draw_cat_shape(center: Vector2, color: Color, scale_value: float) -> void:
	draw_circle(center + Vector2(0.0, -70.0) * scale_value, 95.0 * scale_value, color)
	draw_circle(center + Vector2(0.0, 84.0) * scale_value, 120.0 * scale_value, color)
	draw_polygon(PackedVector2Array([
		center + Vector2(-70.0, -140.0) * scale_value,
		center + Vector2(-26.0, -198.0) * scale_value,
		center + Vector2(-10.0, -124.0) * scale_value,
	]), PackedColorArray([color, color, color]))
	draw_polygon(PackedVector2Array([
		center + Vector2(70.0, -140.0) * scale_value,
		center + Vector2(26.0, -198.0) * scale_value,
		center + Vector2(10.0, -124.0) * scale_value,
	]), PackedColorArray([color, color, color]))

func _cat_color_mid() -> Color:
	if _cat == null:
		return Palette.CAT_ORANGE_MID
	match String(_cat.species):
		CatData.BREED_BRITISH:
			return Palette.CAT_BRIT_MID
		CatData.BREED_SIAMESE:
			return Palette.CAT_SIAM_BODY
		_:
			return Palette.CAT_ORANGE_MID

func _cat_color_light() -> Color:
	if _cat == null:
		return Palette.CAT_ORANGE_LIGHT
	match String(_cat.species):
		CatData.BREED_BRITISH:
			return Palette.CAT_BRIT_LIGHT
		CatData.BREED_SIAMESE:
			return Palette.CAT_SIAM_HIGH
		_:
			return Palette.CAT_ORANGE_LIGHT

func _rarity_color() -> Color:
	if _cat == null:
		return Palette.AMBER
	match String(_cat.rarity):
		CatData.RARITY_RARE:
			return Palette.RARITY_RARE
		CatData.RARITY_EPIC:
			return Palette.RARITY_EPIC
		CatData.RARITY_LEGENDARY:
			return Palette.RARITY_LEG_A
		_:
			return Palette.AMBER

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((get_viewport_rect().size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
