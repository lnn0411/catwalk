# T3-0 Batch 1: Palette + 三只猫

在 Godot 4.x 项目 /home/agentuser/catwalk_godot/ 中创建以下 4 个 GDScript 文件。严格按规格编写，不自行取色或修改尺寸。

目录已建：autoload/ characters/ items/ ui/ ui/theme/

---

## 文件1: autoload/Palette.gd

全局色板 autoload 单例。完整内容如下，直接原样写入：

```gdscript
extends Node

# ============================================================
# 猫步天下 · 全局色板 · 临时版 v1.0
# 所有程序化资产唯一取色来源。日后替换为正式版时只改 Hex 值。
# ============================================================

# --- 背景 / 地面 ---
const BG_WARM_WHITE    = Color("#FAF6F0")
const BG_CEMENT        = Color("#F2EDE4")
const BG_NIGHT_OVERLAY = Color("#7A8A9640")
const BG_RAIN_OVERLAY  = Color("#D6E4EC26")

# --- 主色 ---
const AMBER            = Color("#C4894A")
const CITY_GRAY        = Color("#7A8A96")

# --- 辅助色 ---
const MOSS_GREEN       = Color("#7A9E6E")
const BRICK_RED        = Color("#B5553C")
const MIST_BLUE        = Color("#D6E4EC")
const MILK_WHITE       = Color("#FAF6F0")

# --- 猫咪毛色：橘猫 ---
const CAT_ORANGE_MID   = Color("#D4834A")
const CAT_ORANGE_LIGHT = Color("#E8B87A")
const CAT_ORANGE_HIGH  = Color("#F2D4A8")

# --- 猫咪毛色：英短 ---
const CAT_BRIT_MID     = Color("#9AA0A8")
const CAT_BRIT_LIGHT   = Color("#C4C9CE")
const CAT_BRIT_HIGH    = Color("#E4E8EA")

# --- 猫咪毛色：暹罗 ---
const CAT_SIAM_BODY    = Color("#E8D5C0")
const CAT_SIAM_POINT   = Color("#4A3728")
const CAT_SIAM_HIGH    = Color("#F5EDE4")

# --- 文字 ---
const TEXT_PRIMARY     = Color("#2C2926")
const TEXT_SECONDARY   = Color("#7A8A96")
const TEXT_ON_AMBER    = Color("#FAF6F0")

# --- 边框 ---
const BORDER_DEFAULT   = Color("#C8BFB0")
const BORDER_ACTIVE    = Color("#C4894A")

# --- 稀有度光效 ---
const RARITY_RARE      = Color("#9BB8D4")
const RARITY_EPIC      = Color("#8E6FA8")
const RARITY_LEG_A     = Color("#D6E4EC")
const RARITY_LEG_B     = Color("#E8D5C0")
```

## 文件2: characters/CatOrange.gd

橘猫占位角色。extends Node2D，_draw() 绘制。128x128 区域，碰撞体 80x80 居中。

```gdscript
extends Node2D

var body_color    = Palette.CAT_ORANGE_MID
var light_color   = Palette.CAT_ORANGE_LIGHT
var outline_color = Color("#A05A28")

func _ready():
	var static_body = StaticBody2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 80)
	collision.shape = shape
	collision.position = Vector2(0, 4)
	static_body.add_child(collision)
	add_child(static_body)

func _draw():
	# 身体
	draw_ellipse(Vector2(0, 8), Vector2(50, 38), body_color)
	draw_arc(Vector2(0, 8), 50, 0, TAU, 32, outline_color, 1.5)

	# 胸腹浅色区
	draw_ellipse(Vector2(0, 14), Vector2(28, 22), light_color)

	# 头
	draw_circle(Vector2(0, -28), 22, body_color)
	draw_arc(Vector2(0, -28), 22, 0, TAU, 32, outline_color, 1.5)

	# 耳朵
	var ear_l = PackedVector2Array([Vector2(-18, -42), Vector2(-10, -28), Vector2(-26, -28)])
	var ear_r = PackedVector2Array([Vector2(18, -42), Vector2(10, -28), Vector2(26, -28)])
	draw_polygon(ear_l, [body_color])
	draw_polygon(ear_r, [body_color])

	# 眼睛 - 扁椭圆（半眯）
	draw_ellipse(Vector2(-9, -30), Vector2(6, 3), outline_color)
	draw_ellipse(Vector2(9, -30), Vector2(6, 3), outline_color)

	# 鼻子
	draw_polygon(PackedVector2Array([Vector2(0, -24), Vector2(-3, -21), Vector2(3, -21)]),
		[Color("#D4734A")])

	# 尾巴 - 搭在地上
	draw_polyline(PackedVector2Array([
		Vector2(30, 12), Vector2(46, 20), Vector2(54, 16), Vector2(48, 10)
	]), outline_color, 4.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(30, 12), Vector2(46, 20), Vector2(54, 16), Vector2(48, 10)
	]), body_color, 2.5, true)
```

## 文件3: characters/CatBritish.gd

英短占位角色。和橘猫结构相同，差异参数：
- body_color=Palette.CAT_BRIT_MID, light_color=Palette.CAT_BRIT_LIGHT, outline_color=Color("#6E7278")
- 身体椭圆：46x40（圆墩）
- 头圆半径：24px
- 眼睛：圆形 r=5（用 draw_circle 不是椭圆）
- 尾巴：收于身侧，折线向下贴近身体：Vector2(28,10) → Vector2(36,22) → Vector2(32,34) → Vector2(28,38)

完全复制 CatOrange 结构，只改上述参数。

```gdscript
extends Node2D

var body_color    = Palette.CAT_BRIT_MID
var light_color   = Palette.CAT_BRIT_LIGHT
var outline_color = Color("#6E7278")

func _ready():
	var static_body = StaticBody2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 80)
	collision.shape = shape
	collision.position = Vector2(0, 4)
	static_body.add_child(collision)
	add_child(static_body)

func _draw():
	# 身体 - 更圆墩 46x40
	draw_ellipse(Vector2(0, 8), Vector2(46, 40), body_color)
	draw_arc(Vector2(0, 8), 46, 0, TAU, 32, outline_color, 1.5)

	# 胸腹浅色区 - 稍大
	draw_ellipse(Vector2(0, 14), Vector2(26, 24), light_color)

	# 头 - 更大更圆 半径24
	draw_circle(Vector2(0, -28), 24, body_color)
	draw_arc(Vector2(0, -28), 24, 0, TAU, 32, outline_color, 1.5)

	# 耳朵 - 稍小圆润
	var ear_l = PackedVector2Array([Vector2(-20, -44), Vector2(-12, -32), Vector2(-28, -32)])
	var ear_r = PackedVector2Array([Vector2(20, -44), Vector2(12, -32), Vector2(28, -32)])
	draw_polygon(ear_l, [body_color])
	draw_polygon(ear_r, [body_color])

	# 眼睛 - 圆形 r=5
	draw_circle(Vector2(-9, -30), 5, outline_color)
	draw_circle(Vector2(9, -30), 5, outline_color)
	# 高光小点
	draw_circle(Vector2(-9, -31), 2, Color.WHITE)
	draw_circle(Vector2(9, -31), 2, Color.WHITE)

	# 鼻子
	draw_polygon(PackedVector2Array([Vector2(0, -24), Vector2(-3, -21), Vector2(3, -21)]),
		[Color("#D4734A")])

	# 尾巴 - 收于身侧向下
	draw_polyline(PackedVector2Array([
		Vector2(28, 10), Vector2(36, 22), Vector2(32, 34), Vector2(28, 38)
	]), outline_color, 4.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(28, 10), Vector2(36, 22), Vector2(32, 34), Vector2(28, 38)
	]), body_color, 2.5, true)
```

## 文件4: characters/CatSiamese.gd

暹罗猫占位角色。差异：
- body_color=Palette.CAT_SIAM_BODY, light_color=Palette.CAT_SIAM_HIGH, outline_color=Palette.CAT_SIAM_POINT
- 身体椭圆：42x34（修长）
- 头圆半径：20px
- 眼睛：杏仁形高=宽x0.6。draw_ellipse(Vector2(-9,-30), Vector2(5,4), outline_color)
- 瞳孔：内部小暗椭圆 draw_ellipse(Vector2(-9,-30), Vector2(2,3), Color.BLACK)
- 尾巴：高翘上扬 Vector2(28,8) → Vector2(44,-8) → Vector2(52,-18) → Vector2(46,-24)
- **重点色**：脸部深色遮罩椭圆(宽14高10居中在脸上，fill CAT_SIAM_POINT)；耳内侧 CAT_SIAM_POINT
- 四肢末端：前爪小椭圆用 CAT_SIAM_POINT

```gdscript
extends Node2D

var body_color    = Palette.CAT_SIAM_BODY
var light_color   = Palette.CAT_SIAM_HIGH
var outline_color = Palette.CAT_SIAM_POINT

func _ready():
	var static_body = StaticBody2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 80)
	collision.shape = shape
	collision.position = Vector2(0, 4)
	static_body.add_child(collision)
	add_child(static_body)

func _draw():
	# 身体 - 修长 42x34
	draw_ellipse(Vector2(0, 8), Vector2(42, 34), body_color)
	draw_arc(Vector2(0, 8), 42, 0, TAU, 32, outline_color, 1.5)

	# 胸腹浅色区
	draw_ellipse(Vector2(0, 14), Vector2(22, 20), light_color)

	# 头
	draw_circle(Vector2(0, -28), 20, body_color)
	draw_arc(Vector2(0, -28), 20, 0, TAU, 32, outline_color, 1.5)

	# 脸部重点色遮罩（椭圆，宽14高10，居中在脸上）
	draw_ellipse(Vector2(0, -28), Vector2(14, 10), outline_color)

	# 耳朵
	var ear_l = PackedVector2Array([Vector2(-15, -40), Vector2(-8, -30), Vector2(-22, -30)])
	var ear_r = PackedVector2Array([Vector2(15, -40), Vector2(8, -30), Vector2(22, -30)])
	draw_polygon(ear_l, [body_color])
	draw_polygon(ear_r, [body_color])
	# 耳内侧深色
	var ear_inner_l = PackedVector2Array([Vector2(-15, -38), Vector2(-10, -32), Vector2(-20, -32)])
	var ear_inner_r = PackedVector2Array([Vector2(15, -38), Vector2(10, -32), Vector2(20, -32)])
	draw_polygon(ear_inner_l, [outline_color])
	draw_polygon(ear_inner_r, [outline_color])

	# 眼睛 - 杏仁形 高=宽x0.6
	draw_ellipse(Vector2(-9, -30), Vector2(5, 4), outline_color)
	draw_ellipse(Vector2(9, -30), Vector2(5, 4), outline_color)
	# 瞳孔 - 细长暗椭圆
	draw_ellipse(Vector2(-9, -30), Vector2(2, 3), Color.BLACK)
	draw_ellipse(Vector2(9, -30), Vector2(2, 3), Color.BLACK)

	# 鼻子
	draw_polygon(PackedVector2Array([Vector2(0, -22), Vector2(-3, -19), Vector2(3, -19)]),
		[Color("#D4734A")])

	# 前爪 - CAT_SIAM_POINT
	draw_ellipse(Vector2(-20, 22), Vector2(8, 6), outline_color)
	draw_ellipse(Vector2(20, 22), Vector2(8, 6), outline_color)

	# 尾巴 - 高翘上扬
	draw_polyline(PackedVector2Array([
		Vector2(28, 8), Vector2(44, -8), Vector2(52, -18), Vector2(46, -24)
	]), outline_color, 4.0, true)
	draw_polyline(PackedVector2Array([
		Vector2(28, 8), Vector2(44, -8), Vector2(52, -18), Vector2(46, -24)
	]), body_color, 2.5, true)
```

---

## 执行要求

1. 将上述4个文件原样写入对应路径
2. 确保缩进正确、语法有效
3. 写完后验证：列出每个文件的路径和行数
4. 不要修改、增删或重命名任何内容
