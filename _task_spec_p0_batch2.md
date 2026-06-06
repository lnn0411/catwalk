# T3-0 Batch 2: GardenBackground + HatchingEgg + EnergyBar + SplashScreen

在 Godot 4.x 项目 /home/agentuser/catwalk_godot/ 中创建以下 4 个 GDScript 文件。严格按规格编写。

项目已有 autoload/Palette.gd（全局色板），所有颜色引用 Palette.XXX。

---

## 文件1: scenes/GardenBackground.gd

花园场景底图。extends Node2D，_draw() 程序化绘制。2048×1536 画布，三层（sky/building/ground），中心区域留空（700-1350 × 700-1100）。

```gdscript
extends Node2D

func _draw():
	# === Layer 1: 天空（画面上25%） ===
	draw_rect(Rect2(0, 0, 2048, 384), Palette.BG_WARM_WHITE)

	# === Layer 2: 远景建筑轮廓 ===
	var building_color = Color("#C8BFB0")
	var buildings = [
		[200, 264, 120, 80],
		[480, 304, 80, 120],
		[800, 224, 160, 100],
		[1200, 284, 100, 180],
		[1600, 244, 140, 90],
	]
	for b in buildings:
		var x = b[0]
		var y_top = b[1]
		var height = b[2]
		var width = b[3]
		draw_rect(Rect2(x, y_top, width, height), building_color)
		# 建筑顶部高光线
		draw_line(Vector2(x, y_top), Vector2(x + width, y_top), Color("#D8CFC4"), 1.0)

	# === Layer 3: 地面（画面下75%） ===
	draw_rect(Rect2(0, 384, 2048, 1152), Palette.BG_CEMENT)

	# 水泥裂缝（左下角，固定seed）
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var crack_color = Color("#C8BFB0")
	for i in range(6):
		var start = Vector2(rng.randf_range(0, 300), rng.randf_range(900, 1536))
		var end = start + Vector2(rng.randf_range(20, 80), rng.randf_range(-20, 20))
		draw_line(start, end, crack_color, 1.0)

	# 右下角裂缝群
	for i in range(6):
		var start = Vector2(rng.randf_range(1700, 2048), rng.randf_range(900, 1536))
		var end = start + Vector2(rng.randf_range(-20, -80), rng.randf_range(-20, 20))
		draw_line(start, end, crack_color, 1.0)

	# 野草（小椭圆簇，分布在边缘，中心留空）
	var grass_color = Palette.MOSS_GREEN
	var grass_positions = [
		Vector2(80, 1200), Vector2(120, 1350), Vector2(160, 1180),
		Vector2(1900, 1100), Vector2(1960, 1300),
		Vector2(300, 500), Vector2(1700, 550),
		Vector2(60, 800), Vector2(1970, 750),
	]
	for pos in grass_positions:
		draw_ellipse(pos, Vector2(8, 4), grass_color)
		draw_ellipse(pos + Vector2(6, -3), Vector2(6, 3), grass_color)
		draw_ellipse(pos + Vector2(-5, -2), Vector2(5, 3), grass_color)

	# 瓷碗（右下区域，固定坐标 1680, 1320）
	var bowl_color = Color("#D4C8BC")
	draw_arc(Vector2(1680, 1320), 24, PI, TAU, 16, bowl_color, 3.0)
	draw_line(Vector2(1656, 1320), Vector2(1704, 1320), bowl_color, 3.0)
```

## 文件2: items/HatchingEgg.gd

孵化蛋。extends Node2D，256×256 区域。@export progress 0→1 驱动外观变化：蛋形+暖光+裂缝。

```gdscript
extends Node2D

@export var progress: float = 0.0

func _ready():
	set_process(true)

func _process(_delta):
	queue_redraw()

func _draw():
	var center = Vector2(128, 128)

	# 蛋体形状
	var egg_points = _get_egg_shape(center, 56, 72)
	draw_colored_polygon(egg_points, Palette.BG_WARM_WHITE)
	draw_polyline(egg_points + PackedVector2Array([egg_points[0]]), Color("#C8BFB0"), 1.5, true)

	# 内部暖光（progress > 0.5 开始出现，渐强）
	if progress > 0.5:
		var glow_alpha = (progress - 0.5) * 2.0
		var glow_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, glow_alpha * 0.35)
		draw_colored_polygon(egg_points, glow_color)

	# 裂缝（progress >= 0.25 开始出现，随进度增多）
	if progress >= 0.25:
		_draw_cracks(center, progress)

func _get_egg_shape(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(24):
		var angle = i * TAU / 24.0
		var r_y = ry if sin(angle) > 0 else ry * 0.82
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * r_y))
	return points

func _draw_cracks(center: Vector2, p: float):
	var crack_color = Color("#B0A898")

	# 第一道裂缝（progress >= 0.25）
	draw_line(center + Vector2(-8, -20), center + Vector2(4, -8), crack_color, 1.0)

	# 第二道（progress >= 0.5）
	if p >= 0.5:
		draw_line(center + Vector2(10, -14), center + Vector2(20, 2), crack_color, 1.0)
		draw_line(center + Vector2(10, -14), center + Vector2(6, -28), crack_color, 1.0)

	# 第三道（progress >= 0.75，蛋壳剥落感）
	if p >= 0.75:
		draw_line(center + Vector2(-16, 0), center + Vector2(-4, 14), crack_color, 1.5)
		draw_line(center + Vector2(-4, 14), center + Vector2(8, 10), crack_color, 1.5)
```

## 文件3: ui/EnergyBar.gd

能量条。extends Node2D，240×8px。@export value 0→1，圆角琥珀填充，满槽脉冲动画。

```gdscript
extends Node2D

@export var value: float = 0.0
@export var bar_width: float = 240.0

const HEIGHT = 8.0
const RADIUS = 4.0

func _ready():
	set_process(true)

func _process(_delta):
	queue_redraw()

func _draw():
	var bg_rect = Rect2(0, 0, bar_width, HEIGHT)

	# 背景槽
	_draw_rounded_rect(bg_rect, RADIUS, Color("#DDD5C8"))

	# 填充
	var fill_w = bar_width * clamp(value, 0.0, 1.0)
	if fill_w > RADIUS * 2:
		_draw_rounded_rect(Rect2(0, 0, fill_w, HEIGHT), RADIUS, Palette.AMBER)

	# 满槽发光脉冲（value >= 0.9）
	if value >= 0.9:
		var pulse = (sin(Time.get_ticks_msec() * 0.004) + 1.0) * 0.5
		var glow = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, pulse * 0.5)
		if fill_w > RADIUS * 2:
			_draw_rounded_rect(Rect2(0, 0, fill_w, HEIGHT), RADIUS, glow)

func _draw_rounded_rect(rect: Rect2, radius: float, color: Color):
	draw_rect(Rect2(rect.position.x + radius, rect.position.y,
		rect.size.x - radius * 2, rect.size.y), color)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
```

## 文件4: scenes/SplashScreen.gd

启动页 S00。extends Node2D，全屏 BG_CEMENT + 居中猫爪印 logo。

```gdscript
extends Node2D

func _draw():
	var screen = get_viewport_rect().size

	# 背景
	draw_rect(Rect2(Vector2.ZERO, screen), Palette.BG_CEMENT)

	# 猫爪印 logo（一个大爪垫 + 四个小趾垫，居中偏上）
	var center = screen / 2.0

	# 主掌垫（椭圆，宽48，高38）
	draw_ellipse(center + Vector2(0, 24), Vector2(48, 38), Palette.AMBER)

	# 四个趾垫（小圆，半径12，排成弧形）
	var toe_offsets = [
		Vector2(-36, -14),
		Vector2(-14, -34),
		Vector2(14, -34),
		Vector2(36, -14),
	]
	for offset in toe_offsets:
		draw_circle(center + offset, 12, Palette.AMBER)

	# 底部文字占位「猫步天下」
	var font_size = 28
	# 用简单线条代替文字（等正式字体资源到位后替换）
	var text_y = center.y + 90
	var text_center = center.x
	var line_width = 120.0
	draw_line(Vector2(text_center - line_width / 2, text_y), Vector2(text_center + line_width / 2, text_y), Palette.TEXT_PRIMARY, 2.0)
```

---

## 执行要求

1. 将上述4个文件原样写入对应路径
2. 确保缩进正确、语法有效
3. 写完后验证每个文件存在并报告行数
4. 不要修改、增删或重命名任何内容
