# T3-0 Batch 3: UITheme + PostcardPlaceholder + RarityParticles (P1)

在 Godot 4.x 项目 /home/agentuser/catwalk_godot/ 中创建以下 3 个 GDScript 文件。严格按规格编写。

---

## 文件1: ui/theme/UITheme.gd

UI 卡片/弹窗 StyleBoxFlat 工具类。class_name UITheme，提供静态方法返回各种 StyleBox。

```gdscript
extends Node

class_name UITheme

static func get_card_stylebox() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Palette.BG_WARM_WHITE
	s.border_color = Palette.BORDER_DEFAULT
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(16)
	return s

static func get_modal_stylebox() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Palette.BG_WARM_WHITE
	s.border_color = Palette.BORDER_DEFAULT
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(20)
	return s

static func get_button_primary() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Palette.AMBER
	s.set_corner_radius_all(8)
	s.set_content_margin_all(12)
	return s

static func get_button_secondary() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = Palette.AMBER
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(12)
	return s
```

## 文件2: ui/PostcardPlaceholder.gd

明信片占位。extends Node2D，750×500 画布。按地点类型填不同背景色。

```gdscript
extends Node2D

const POSTCARD_COLORS = {
	"convenience_store": Color("#E8E4DC"),
	"park":              Color("#DDE8D8"),
	"subway":            Color("#DCE0E8"),
	"bookstore":         Color("#E8E0D4"),
	"cafe":              Color("#EDE4D8"),
	"hospital":          Color("#E4E8E8"),
	"overpass":          Color("#E0E4EC"),
	"night_market":      Color("#F0E8D8"),
	"playground":        Color("#E8ECE0"),
	"rainy":             Color("#DDE4EC"),
}

@export var location_type: String = "park"
@export var cat_breed: String = "orange"

func _draw():
	var bg = POSTCARD_COLORS.get(location_type, Palette.BG_CEMENT)

	# 背景
	draw_rect(Rect2(0, 0, 750, 500), bg)

	# 右侧白卡区（文案区）
	draw_rect(Rect2(500, 0, 250, 500), Palette.BG_WARM_WHITE)
	draw_line(Vector2(500, 0), Vector2(500, 500), Palette.BORDER_DEFAULT, 1.0)

	# 邮票占位（右上角，60×80px）
	draw_rect(Rect2(624, 16, 60, 80), Palette.BG_CEMENT)
	draw_rect(Rect2(624, 16, 60, 80), Palette.BORDER_DEFAULT, false, 1.0)

	# 文案占位线（灰色横线，4条）
	for i in range(4):
		var y = 200 + i * 28
		draw_line(Vector2(520, y), Vector2(720, y), Palette.BORDER_DEFAULT, 1.0)

	# 猫咪占位图标（右下，缩小版猫咪，坐标约 650, 420）
	_draw_mini_cat(Vector2(620, 400))

func _draw_mini_cat(pos: Vector2):
	var cat_color = Palette.CAT_ORANGE_MID
	var outline_color = Color("#A05A28")

	# 身体（小椭圆）
	draw_ellipse(pos + Vector2(0, 14), Vector2(20, 16), cat_color)
	# 头（小圆）
	draw_circle(pos + Vector2(0, -8), 10, cat_color)
	# 耳朵
	var ear_l = PackedVector2Array([pos + Vector2(-8, -16), pos + Vector2(-4, -10), pos + Vector2(-12, -10)])
	var ear_r = PackedVector2Array([pos + Vector2(8, -16), pos + Vector2(4, -10), pos + Vector2(12, -10)])
	draw_polygon(ear_l, [cat_color])
	draw_polygon(ear_r, [cat_color])
	# 眼睛
	draw_ellipse(pos + Vector2(-4, -10), Vector2(3, 2), outline_color)
	draw_ellipse(pos + Vector2(4, -10), Vector2(3, 2), outline_color)
	# 尾巴（后摆）
	draw_polyline(PackedVector2Array([
		pos + Vector2(16, 12), pos + Vector2(28, 22), pos + Vector2(36, 18)
	]), outline_color, 2.0, true)
```

## 文件3: items/RarityParticles.gd

稀有度光效粒子。extends Node2D，代码配置 GPUParticles2D。

```gdscript
extends Node2D

@export var rarity: String = "common"

func _ready():
	setup_particles()

func setup_particles():
	var particles = GPUParticles2D.new()
	particles.one_shot = false
	particles.explosiveness = 0.0

	match rarity:
		"common":
			particles.emitting = false
			add_child(particles)
			return

		"rare":
			particles.amount = 24
			particles.lifetime = 2.0
			particles.emitting = true
			var mat = ParticleProcessMaterial.new()
			mat.color = Palette.RARITY_RARE
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			mat.emission_sphere_radius = 60.0
			mat.initial_velocity_min = 20.0
			mat.initial_velocity_max = 50.0
			mat.scale_min = 2.0
			mat.scale_max = 5.0
			particles.process_material = mat

		"epic":
			particles.amount = 40
			particles.lifetime = 1.5
			particles.emitting = true
			var mat = ParticleProcessMaterial.new()
			mat.color = Palette.RARITY_EPIC
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			mat.emission_ring_radius = 80.0
			mat.emission_ring_inner_radius = 60.0
			mat.initial_velocity_min = 60.0
			mat.initial_velocity_max = 100.0
			mat.scale_min = 3.0
			mat.scale_max = 7.0
			particles.process_material = mat

		"legendary":
			particles.amount = 60
			particles.lifetime = 3.0
			particles.emitting = true
			var mat = ParticleProcessMaterial.new()
			mat.color_ramp = _make_legendary_gradient()
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			mat.emission_sphere_radius = 100.0
			mat.initial_velocity_min = 40.0
			mat.initial_velocity_max = 120.0
			mat.scale_min = 4.0
			mat.scale_max = 10.0
			particles.process_material = mat

	add_child(particles)

func _make_legendary_gradient() -> Gradient:
	var g = Gradient.new()
	g.colors = PackedColorArray([Palette.RARITY_LEG_A, Palette.RARITY_LEG_B, Palette.RARITY_LEG_A])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	return g
```

---

## 执行要求

1. 将上述3个文件原样写入对应路径
2. 确保缩进正确、语法有效
3. 写完后验证每个文件存在并报告行数
4. 不要修改、增删或重命名任何内容
