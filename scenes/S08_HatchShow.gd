extends "res://ui/UIPage.gd"

# ============================================================
# S08 孵化演出 —— P0 打磨版 + 贴图驱动改造
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
#
# —— 贴图驱动改造（M7）——
# 演出主体改由 TextureRect 节点呈现：蛋壳 / 猫剪影 / 揭晓立绘 / 蛋壳碎片
# / 稀有度光效，以及白闪 ColorRect。原 _draw() 代码绘制全部保留为「贴图
# 未就位时的兜底」，靠 ResourceLoader.exists() 判断逐项回退。裂纹折线与
# 金色汇聚粒子没有静态贴图替代，始终走 _draw()（绘制在蛋贴图之上）。
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
var _common_seeds: Array = []    # common 白光粒子的固定位置/相位（确定性）
var _crack_seeds: Array = []     # 蛋壳裂纹折线偏移（确定性）
# —— M6 演出 P1 ——
var _gold_seeds: Array = []      # 金色汇聚粒子的起始方位/速度相位
var _shards: Array = []          # 蛋壳碎片 [{pos, vel, rot, rot_speed, node}]
var _shard_time := 0.0           # 碎片已飞行时长

# —— 演出主体相对屏幕中心的布局偏移 ——
const EGG_OFFSET := Vector2(0.0, -160.0)   # 蛋中心（720×1280 → 360,480）
const CAT_OFFSET := Vector2(0.0, -80.0)    # 猫/剪影/立绘中心（→ 360,560）
const EGG_SIZE := Vector2(150.0, 150.0)
const SIL_SIZE := Vector2(240.0, 280.0)
const REVEAL_SIZE := Vector2(360.0, 360.0)
const SHARD_SIZE := Vector2(90.0, 54.0)
const FX_COMMON_SIZE := Vector2(320.0, 320.0)
const FX_RARE_SIZE := Vector2(360.0, 360.0)
const FX_EPIC_SIZE := Vector2(140.0, 480.0)
const FX_LEGENDARY_SIZE := Vector2(420.0, 420.0)

# —— 美术资源路径 ——
const ART_BG_PATH := "res://assets/art/ui/hatch_show/hatch_show_bg.png"
const ART_EGG_PATH := "res://assets/art/ui/hatch_show/hatch_egg_whole.png"
const ART_SILHOUETTE_PATH := "res://assets/art/ui/hatch_show/hatch_cat_silhouette.png"
const ART_SHARD_PATHS := [
	"res://assets/art/ui/hatch_show/hatch_shard_01.png",
	"res://assets/art/ui/hatch_show/hatch_shard_02.png",
	"res://assets/art/ui/hatch_show/hatch_shard_03.png",
	"res://assets/art/ui/hatch_show/hatch_shard_04.png",
	"res://assets/art/ui/hatch_show/hatch_shard_05.png",
]
const ART_FX_COMMON := "res://assets/art/ui/hatch_show/fx_common_glow.png"
const ART_FX_RARE := "res://assets/art/ui/hatch_show/fx_rare_star.png"
const ART_FX_EPIC := "res://assets/art/ui/hatch_show/fx_epic_pillar.png"
const ART_FX_LEGENDARY := "res://assets/art/ui/hatch_show/fx_legendary_ring.png"
const ART_REVEAL_PATHS := {
	CatData.BREED_ORANGE: "res://assets/art/cats/portraits/reveal/portrait_orange.png",
	CatData.BREED_BRITISH: "res://assets/art/cats/portraits/reveal/portrait_british.png",
	CatData.BREED_SIAMESE: "res://assets/art/cats/portraits/reveal/portrait_siamese.png",
}
# 兼容保留：蛋壳碎裂/光效序列帧的预期路径（碎裂与光效现已分别由 hatch_shard_*
# 与 fx_*.png 节点驱动，这两个序列帧未启用，仅作占位 + 自检 API 契约保留）。
const ART_EGG_CRACK_SHEET := "res://assets/art/ui/hatch_egg_crack_sheet.png"
const ART_LIGHT_SHEET := "res://assets/art/ui/hatch_light_sheet.png"

# —— 贴图就位标记（任一缺失则该项回退到 _draw()）——
var _art_bg := false
var _art_egg := false
var _art_silhouette := false
var _art_reveal := false
var _art_shard := false
var _art_fx_common := false
var _art_fx_rare := false
var _art_fx_epic := false
var _art_fx_legendary := false

# —— 节点缓存 ——
var _egg_node: TextureRect = null
var _sil_node: TextureRect = null
var _reveal_node: TextureRect = null
var _white_flash: ColorRect = null
var _shard_container: Control = null
var _fx_common: TextureRect = null
var _fx_rare: TextureRect = null
var _fx_epic: TextureRect = null
var _fx_legendary: TextureRect = null
var _shard_textures: Array = []

func _ready() -> void:
	super._ready()
	set_process(true)
	_build_art_layers()
	# rare 星光粒子相位（固定种子，每次演出一致即可）
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260612
	for i in range(10):
		_star_seeds.append(rng.randf_range(0.0, TAU))
	# common 白光粒子 + 裂纹折线偏移（固定种子，每次演出一致）
	var detail_rng := RandomNumberGenerator.new()
	detail_rng.seed = 20260617
	for i in range(7):
		_common_seeds.append({
			"offset": Vector2(detail_rng.randf_range(-170.0, 170.0), detail_rng.randf_range(-170.0, 150.0)),
			"phase": detail_rng.randf_range(0.0, TAU),
			"radius": detail_rng.randf_range(2.0, 4.0),
			"alpha": detail_rng.randf_range(0.5, 0.7),
			"float": detail_rng.randf_range(5.0, 12.0),
			"breath": detail_rng.randf_range(0.7, 1.2),
		})
	for i in range(4):
		var offsets: Array = []
		for j in range(1, 5):
			var mag := detail_rng.randf_range(15.0, 25.0)
			if detail_rng.randf() < 0.5:
				mag = -mag
			offsets.append(mag)
		_crack_seeds.append(offsets)
	# M6：金色汇聚粒子（16颗，从屏幕四周向蛋汇聚）
	for i in range(16):
		_gold_seeds.append({
			"angle": rng.randf_range(0.0, TAU),
			"dist": rng.randf_range(420.0, 640.0),
			"speed": rng.randf_range(0.55, 1.0),
			"phase": rng.randf_range(0.0, 1.0),
		})

# 用 load() 而非 preload()：美术图可能尚未就位，preload 缺文件会编译失败。
# setup()/_on_page_setup() 先于本函数（_ready）执行，故此处 _cat 已可用，
# 揭晓立绘可按品种直接加载。
func _build_art_layers() -> void:
	# —— 缓存节点 ——
	_egg_node = get_node_or_null("%EggWhole")
	_sil_node = get_node_or_null("%CatSilhouette")
	_reveal_node = get_node_or_null("%CatReveal")
	_white_flash = get_node_or_null("%WhiteFlash")
	_shard_container = get_node_or_null("%ShardContainer")
	_fx_common = get_node_or_null("%FxCommon")
	_fx_rare = get_node_or_null("%FxRare")
	_fx_epic = get_node_or_null("%FxEpic")
	_fx_legendary = get_node_or_null("%FxLegendary")

	# —— 背景 ——
	_art_bg = ResourceLoader.exists(ART_BG_PATH)
	if has_node("%Bg"):
		%Bg.visible = _art_bg
		if _art_bg:
			%Bg.texture = load(ART_BG_PATH)

	# —— 蛋 ——
	_art_egg = _egg_node != null and ResourceLoader.exists(ART_EGG_PATH)
	if _egg_node != null:
		if _art_egg:
			_egg_node.texture = load(ART_EGG_PATH)
			_init_texture_node(_egg_node, EGG_SIZE)
			_egg_node.visible = true
		else:
			_egg_node.visible = false

	# —— 猫剪影 ——
	_art_silhouette = _sil_node != null and ResourceLoader.exists(ART_SILHOUETTE_PATH)
	if _sil_node != null:
		if _art_silhouette:
			_sil_node.texture = load(ART_SILHOUETTE_PATH)
			_init_texture_node(_sil_node, SIL_SIZE)
		_sil_node.visible = false

	# —— 揭晓立绘（按品种）——
	var reveal_path := _reveal_texture_path()
	_art_reveal = _reveal_node != null and reveal_path != "" and ResourceLoader.exists(reveal_path)
	if _reveal_node != null:
		if _art_reveal:
			_reveal_node.texture = load(reveal_path)
			_init_texture_node(_reveal_node, REVEAL_SIZE)
		_reveal_node.visible = false

	# —— 白闪 ——
	if _white_flash != null:
		_white_flash.modulate.a = 0.0

	# —— 蛋壳碎片贴图（6 片复用 5 张）——
	_shard_textures.clear()
	var shard_all := _shard_container != null
	for p in ART_SHARD_PATHS:
		if ResourceLoader.exists(p):
			_shard_textures.append(load(p))
		else:
			shard_all = false
	_art_shard = shard_all and _shard_textures.size() > 0

	# —— 稀有度光效 ——
	_art_fx_common = _setup_fx_node(_fx_common, ART_FX_COMMON, FX_COMMON_SIZE)
	_art_fx_rare = _setup_fx_node(_fx_rare, ART_FX_RARE, FX_RARE_SIZE)
	_art_fx_epic = _setup_fx_node(_fx_epic, ART_FX_EPIC, FX_EPIC_SIZE)
	_art_fx_legendary = _setup_fx_node(_fx_legendary, ART_FX_LEGENDARY, FX_LEGENDARY_SIZE)

func _setup_fx_node(node: TextureRect, path: String, node_size: Vector2) -> bool:
	if node == null:
		return false
	var ok := ResourceLoader.exists(path)
	if ok:
		node.texture = load(path)
		_init_texture_node(node, node_size)
	node.visible = false
	return ok

# 统一初始化 TextureRect 的尺寸 / 轴心（缩放绕中心）。
func _init_texture_node(node: TextureRect, node_size: Vector2) -> void:
	node.size = node_size
	node.pivot_offset = node_size * 0.5

func _reveal_texture_path() -> String:
	if _cat == null:
		return ""
	return String(ART_REVEAL_PATHS.get(String(_cat.species), ""))

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
		var shard_alpha: float = clampf(1.0 - _shard_time / 0.9, 0.0, 1.0)
		for s in _shards:
			s["vel"] = Vector2(s["vel"]) + Vector2(0.0, 900.0) * delta
			s["pos"] = Vector2(s["pos"]) + Vector2(s["vel"]) * delta
			s["rot"] = float(s["rot"]) + float(s["rot_speed"]) * delta
			var node = s.get("node")
			if node != null and is_instance_valid(node):
				node.rotation = float(s["rot"])
				node.modulate.a = shard_alpha
				node.position = Vector2(s["pos"]) - SHARD_SIZE * 0.5
		if _shard_time > 0.9:
			_free_shards()
	_update_phase()
	_update_art_nodes()
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
	# M6：蛋壳碎片（盖在场景上、白闪之下）——贴图就位时改由节点呈现，此处只画兜底碎片
	if not _shards.is_empty():
		var shard_alpha: float = clampf(1.0 - _shard_time / 0.9, 0.0, 1.0)
		for s in _shards:
			if s.get("node") == null:
				_draw_shard(Vector2(s["pos"]), float(s["rot"]), Color(_cat_color_light(), shard_alpha))
	# 全屏白闪盖在最上层（贴图 ColorRect 未就位时才用代码画）
	if _white_flash == null and _flash_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(1.0, 1.0, 1.0, _flash_alpha))

# ============ 贴图节点逐帧驱动 ============
# 按当前 phase 切换各 TextureRect 的可见/位置/缩放/动画。仅在对应贴图就位时
# 接管；未就位的项保持隐藏，由 _draw() 兜底。
func _update_art_nodes() -> void:
	var screen := get_viewport_rect().size
	var center := screen * 0.5
	var egg_point := center + EGG_OFFSET
	var cat_point := center + CAT_OFFSET

	# 白闪逐帧同步
	if _white_flash != null:
		_white_flash.modulate.a = _flash_alpha

	# 蛋（仅 Phase1，蛋振动 = 移动节点 position）
	if _egg_node != null and _art_egg:
		if _phase == 1:
			_egg_node.visible = true
			var crack: float = clamp(_elapsed / 3.0, 0.0, 1.0)
			var shake_amp := crack * 6.0
			var shake := Vector2(
				sin(_elapsed * 40.0) * shake_amp,
				cos(_elapsed * 37.0) * shake_amp * 0.6
			)
			_place_centered(_egg_node, egg_point + shake, 1.0)
		else:
			_egg_node.visible = false

	# 猫剪影（仅 Phase2）
	if _sil_node != null and _art_silhouette:
		if _phase == 2:
			_sil_node.visible = true
			_place_centered(_sil_node, cat_point, 1.15)
		else:
			_sil_node.visible = false

	# 揭晓立绘（Phase3/4，沿用揭晓弹性 / 缩小缩放）
	if _reveal_node != null and _art_reveal:
		if _phase >= 3:
			_reveal_node.visible = true
			_place_centered(_reveal_node, cat_point, _current_zoom())
		else:
			_reveal_node.visible = false

	_update_fx_nodes(cat_point)

# 把 TextureRect 摆到「中心点 = point、整体缩放 = sc」。
func _place_centered(node: Control, point: Vector2, sc: float) -> void:
	node.scale = Vector2(sc, sc)
	node.position = point - node.size * 0.5

# Phase3/4 共用的揭晓缩放（驱动立绘与光效）。
func _current_zoom() -> float:
	if _phase == 4:
		return clamp(1.0 - (_elapsed - _phase4_start()) / 1.5 * 0.35, 0.65, 1.0)
	return _reveal_zoom()

# 稀有度光效节点：仅在 Phase3/4 且匹配稀有度且贴图就位时显示。
func _update_fx_nodes(cat_point: Vector2) -> void:
	for n in [_fx_common, _fx_rare, _fx_epic, _fx_legendary]:
		if n != null:
			n.visible = false
	if _phase < 3 or _cat == null:
		return
	var zoom := _current_zoom()
	match String(_cat.rarity):
		CatData.RARITY_RARE:
			if _fx_rare != null and _art_fx_rare:
				_fx_rare.visible = true
				var pulse := (sin(_elapsed * 4.0) + 1.0) * 0.5
				_place_centered(_fx_rare, cat_point, zoom)
				_fx_rare.rotation = _elapsed * 0.9
				_fx_rare.modulate.a = 0.7 + pulse * 0.3
		CatData.RARITY_EPIC:
			if _fx_epic != null and _art_fx_epic:
				_fx_epic.visible = true
				var pulse := (sin(_elapsed * 3.0) + 1.0) * 0.5
				_place_centered(_fx_epic, cat_point + Vector2(0.0, -40.0), zoom * (1.0 + pulse * 0.08))
				_fx_epic.modulate.a = 0.6 + pulse * 0.3
		CatData.RARITY_LEGENDARY:
			if _fx_legendary != null and _art_fx_legendary:
				_fx_legendary.visible = true
				var p := (sin(_elapsed * 2.2) + 1.0) * 0.5
				_place_centered(_fx_legendary, cat_point, zoom * (1.0 + 0.1 * p))
				_fx_legendary.rotation = _elapsed * 0.5
				_fx_legendary.modulate.a = 0.7 + 0.3 * p
		_:
			if _fx_common != null and _art_fx_common:
				_fx_common.visible = true
				var breath := (sin(_elapsed * 1.5) + 1.0) * 0.5
				_place_centered(_fx_common, cat_point, zoom * (1.0 + breath * 0.06))
				_fx_common.modulate.a = 0.45 + breath * 0.25

# M6：白闪瞬间从蛋位置弹出 6 片蛋壳碎片
# 贴图就位时创建 TextureRect 作为 %ShardContainer 子节点（物理逻辑不变），
# 否则保留纯 _shards 数据由 _draw_shard() 兜底绘制。
func _spawn_shards() -> void:
	var center := get_viewport_rect().size * 0.5 + EGG_OFFSET
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260613
	_free_shards()
	_shard_time = 0.0
	for i in range(6):
		var ang := -PI * 0.5 + rng.randf_range(-1.3, 1.3)  # 大体向上扇形
		var speed := rng.randf_range(420.0, 720.0)
		var pos := center + Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-80.0, 40.0))
		var rot := rng.randf_range(0.0, TAU)
		var s := {
			"pos": pos,
			"vel": Vector2(cos(ang), sin(ang)) * speed,
			"rot": rot,
			"rot_speed": rng.randf_range(-9.0, 9.0),
			"node": null,
		}
		if _art_shard and _shard_container != null:
			var tr := TextureRect.new()
			tr.texture = _shard_textures[i % _shard_textures.size()]
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.size = SHARD_SIZE
			tr.pivot_offset = SHARD_SIZE * 0.5
			tr.position = pos - SHARD_SIZE * 0.5
			tr.rotation = rot
			_shard_container.add_child(tr)
			s["node"] = tr
		_shards.append(s)

func _free_shards() -> void:
	for s in _shards:
		var node = s.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	_shards.clear()

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
	# S06_NamePopup 衔接已验证：接收 cat/hatch_show，确认后 deferred 恢复 S08 并关闭 overlay。
	UIManager.show_overlay("res://scenes/S06_NamePopup.tscn", {"cat": _cat, "hatch_show": self})

func resume_after_name_popup() -> void:
	_waiting_for_name = false
	_elapsed = _phase4_start()

func _is_first_orange() -> bool:
	if _cat == null:
		return false
	return String(_cat.species) == CatData.BREED_ORANGE and int(_cat.hatch_index) == 1

# ============ Phase 1：蛋震动 + 裂纹加深 ============
# 金色汇聚粒子 + 裂纹折线无静态贴图替代，始终代码绘制（画在蛋贴图之上，
# 因 %EggWhole 设了 show_behind_parent）。椭圆蛋仅在蛋贴图未就位时兜底。
func _draw_cracking_egg(center: Vector2) -> void:
	var crack: float = clamp(_elapsed / 3.0, 0.0, 1.0)
	# M6：金色粒子从四周向蛋汇聚（0.5s 后开始，对应 GDD 金色光芒汇聚）
	if _elapsed > 0.5:
		var egg_target := center + EGG_OFFSET
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
	var egg_center := center + EGG_OFFSET + shake
	if not _art_egg:  # 蛋贴图未就位时才画椭圆蛋兜底
		draw_ellipse(egg_center, 150.0, 200.0, _cat_color_light())
	# 裂纹随蛋一起抖（始终绘制）
	for i in range(4):
		var x := egg_center.x - 36.0 + i * 24.0
		var start := Vector2(x, egg_center.y - 100.0 + i * 28.0)
		var points := PackedVector2Array([start])
		var offsets: Array = _crack_seeds[i] if i < _crack_seeds.size() else []
		for j in range(1, 5):
			var t := float(j) / 4.0
			var zigzag := float(offsets[j - 1]) if j - 1 < offsets.size() else 0.0
			points.append(start + Vector2(28.0 * t, -32.0 * t + zigzag) * crack)
		draw_polyline(points, Palette.TEXT_PRIMARY, 5.0)
	# 末段：蛋底部透出稀有度光（预告，憋张力）
	if crack > 0.75:
		var leak := (crack - 0.75) / 0.25
		draw_circle(egg_center + Vector2(0.0, 90.0), 80.0 * leak, Color(_rarity_color(), 0.25 * leak))

# ============ Phase 2：剪影（白闪后浮现）============
# 脉冲光环无静态贴图替代，始终绘制（位于剪影之后）；猫形状仅在剪影贴图未就位时兜底。
func _draw_flash_silhouette(center: Vector2) -> void:
	var cat_point := center + CAT_OFFSET
	var pulse := (sin(_elapsed * 8.0) + 1.0) * 0.5
	draw_circle(cat_point, 310.0 + pulse * 30.0, Color(_rarity_color(), 0.30))
	if not _art_silhouette:
		_draw_cat_shape(cat_point, Palette.TEXT_PRIMARY, 1.15)

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

# 稀有度光晕底色无静态贴图替代，始终绘制（位于立绘之后）；猫形状仅在立绘贴图未就位时兜底。
func _draw_reveal(center: Vector2, zoom: float) -> void:
	var cat_point := center + CAT_OFFSET
	_draw_rarity_fx(cat_point, zoom)
	draw_circle(cat_point, 320.0 * zoom, Color(_rarity_color(), 0.22))
	if not _art_reveal:
		_draw_cat_shape(cat_point, _cat_color_mid(), zoom)
	var cat_name: String = String(_cat.display_name) if _cat != null else "New Cat"
	_draw_centered_text(cat_name, cat_point.y + 300.0 * zoom, 36, Palette.TEXT_PRIMARY)

# 各稀有度特效仅在对应 fx 贴图未就位时走代码绘制（就位则由 _update_fx_nodes 接管）。
func _draw_rarity_fx(center: Vector2, zoom: float) -> void:
	if _cat == null:
		return
	match String(_cat.rarity):
		CatData.RARITY_RARE:
			if not _art_fx_rare:
				_fx_rare_stars(center, zoom)
		CatData.RARITY_EPIC:
			if not _art_fx_epic:
				_fx_epic_pillar(center, zoom)
		CatData.RARITY_LEGENDARY:
			if not _art_fx_legendary:
				_fx_legendary_rings(center, zoom)
		_:
			if not _art_fx_common:
				_fx_common_glow(center, zoom)

# common：7 颗白色柔光点在猫身附近轻微漂浮
func _fx_common_glow(center: Vector2, zoom: float) -> void:
	for i in range(_common_seeds.size()):
		var s: Dictionary = _common_seeds[i]
		var phase := float(s["phase"])
		var breath := (sin(_elapsed * float(s["breath"]) + phase) + 1.0) * 0.5
		var radius := (float(s["radius"]) + breath * 0.45) * zoom
		var alpha := (float(s["alpha"]) + (breath - 0.5) * 0.12) * 0.85
		var pos := center + Vector2(s["offset"]) * zoom
		pos.y += sin(_elapsed * 1.2 + phase) * float(s["float"]) * zoom
		draw_circle(pos, maxf(radius * 2.4, 1.0), Color(1.0, 1.0, 1.0, alpha * 0.16))
		draw_circle(pos, maxf(radius, 1.0), Color(1.0, 1.0, 1.0, alpha))

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
