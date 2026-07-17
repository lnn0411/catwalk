# 弹窗规格标准 v1.0

## 📋 按钮规格总表

| 按钮用途 | 贴图路径 | 尺寸 | 文字 | 文字色 | 字号 | 备注 |
|---------|---------|------|------|--------|------|------|
| **确认/好的/收下** | `btn_confirm_name.png` | **170×70** | 自定义（好的/收下/确认） | `#4F453C` | 18 | 通用确认按钮，唯一正操作按钮 |
| **次要/取消** | `btn_secondary_blank.png` | **170×70** | 自定义（取消/返回） | `#4F453C` | 18 | 探索确认弹窗的左按钮 |
| **探索出发** | `btn_explore_*.png` 4态 | **196×62** | 🧭 探索 | `#5A4A3D` | 17 | CatCard 功能行探索按钮 |
| **喂食** | `btn_feed_*.png` 4态 | **126×68** | 🍖 喂食 | `#4F453C` | 18 | CatCard 互动行 |
| **抚摸** | `btn_pet_*.png` 4态 | **126×68** | ✋ 抚摸 | `#4F453C` | 18 | CatCard 互动行 |
| **玩耍** | `btn_play_*.png` 4态 | **126×68** | 🎾 玩耍 | `#4F453C` | 18 | CatCard 互动行 |
| **关闭(X)** | `btn_close_*.png` 4态 | **44×44** | 无 | — | — | 弹窗右上角关闭 |
| **看广告刷新** | `btn_adrefresh_*.png` 4态 | **196×62** | ⚡ 看广告刷新冷却 🎬 | `#5A4A3D` | 16 | CatCard 功能行 |
| **查看详情** | 无贴图（代码按钮） | 120×40 | 查看详情 › | `#5A4A3D` | 15 | CatCard 底部行 |
| **设为随行** | 无贴图（代码按钮） | 140×40 | 设为随行 | `#5A4A3D` | 15 | CatCard 底部行 |
| **💕 送养** | 无贴图（代码按钮） | 140×40 | 💕 送养 | `#5A4A3D` | 15 | CatCard 底部行 |

### 按钮贴图路径前缀

```
assets/art/ui/incubation/components/btn_confirm_name.png       ← 确认
assets/art/ui/incubation/components/btn_secondary_blank.png    ← 次要/取消
assets/art/ui/catcard/btn_explore_normal/hover/pressed/disabled.png
assets/art/ui/catcard/btn_feed_*.png
assets/art/ui/catcard/btn_pet_*.png
assets/art/ui/catcard/btn_play_*.png
assets/art/ui/catcard/btn_close_*.png
assets/art/ui/catcard/btn_adrefresh_*.png
```

### 按钮叠加 Label 通用代码

```gdscript
var btn := TextureButton.new()
btn.custom_minimum_size = Vector2(170, 70)
btn.texture_normal = BTN_CONFIRM
btn.ignore_texture_size = true
btn.stretch_mode = TextureButton.STRETCH_SCALE
panel.add_child(btn)  # 或加进 VBoxContainer

var label := Label.new()
label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
label.mouse_filter = Control.MOUSE_FILTER_IGNORE
label.text = "好的"
label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
label.add_theme_font_size_override("font_size", 18)
label.add_theme_color_override("font_color", Color("#4F453C"))
btn.add_child(label)
```

---

## 基础弹窗（通用消息/确认）

| 项目 | 值 | 说明 |
|------|-----|------|
| 底图贴图 | `assets/art/ui/panels/popup_bg.png` | 居中，无缩放 |
| 弹窗尺寸 | **560×280** | `_center_control(panel, Vector2(560, 280))` |
| 遮罩 | Color(0, 0, 0, 0.5) | 全屏半透明黑 |
| 标题字号 | 27 | 深棕色 `#4F453C`，居中 |
| 副标题/内容字号 | 22 | 浅棕色 `#A2978C`，居中 |
| 确认按钮 | `btn_confirm_name.png` **170×70** | 位置 `(195, 190)` |
| 次要按钮 | `btn_secondary_blank.png` **170×70** | 可选项，左列 |

### 代码模板

```gdscript
# 遮罩
var dim := ColorRect.new()
dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
dim.color = Color(0, 0, 0, 0.5)
add_child(dim)

# 弹窗面板
var card := Control.new()
_center_control(card, Vector2(560, 280))
add_child(card)

var panel := TextureRect.new()
panel.texture = POPUP_BG
panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
panel.stretch_mode = TextureRect.STRETCH_SCALE
panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
card.add_child(panel)

# 内容 VBox
var box := VBoxContainer.new()
box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
box.add_theme_constant_override("separation", 10)
panel.add_child(box)

# 标题 / 正文 / ...

# 确认按钮（VBox 内）
var ok_btn := TextureButton.new()
ok_btn.custom_minimum_size = Vector2(170, 70)
ok_btn.texture_normal = BTN_CONFIRM
ok_btn.ignore_texture_size = true
ok_btn.stretch_mode = TextureButton.STRETCH_SCALE
ok_btn.pressed.connect(_on_ok)
box.add_child(ok_btn)

var label := Label.new()
label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
label.mouse_filter = Control.MOUSE_FILTER_IGNORE
label.text = "好的"
label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
label.add_theme_font_size_override("font_size", 18)
label.add_theme_color_override("font_color", Color("#4F453C"))
ok_btn.add_child(label)

# 或用绝对定位（按钮不跟容器）
# ok_btn.position = Vector2((560 - 170) * 0.5, 280 - 90)
# panel.add_child(ok_btn)

# 居中辅助函数
func _center_control(control: Control, control_size: Vector2) -> void:
    control.anchor_left = 0.5
    control.anchor_top = 0.5
    control.anchor_right = 0.5
    control.anchor_bottom = 0.5
    control.offset_left = -control_size.x * 0.5
    control.offset_top = -control_size.y * 0.5
    control.offset_right = control_size.x * 0.5
    control.offset_bottom = control_size.y * 0.5
```

---

## 双按钮弹窗（探索确认、送养）

```gdscript
# 按钮行 VBox
var btn_row := HBoxContainer.new()
btn_row.alignment = HBoxContainer.ALIGNMENT_CENTER
btn_row.add_theme_constant_override("separation", 16)

# 次要按钮（取消）
var cancel_btn := TextureButton.new()
cancel_btn.custom_minimum_size = Vector2(170, 70)
cancel_btn.texture_normal = BTN_SECONDARY
cancel_btn.ignore_texture_size = true
cancel_btn.stretch_mode = TextureButton.STRETCH_SCALE
btn_row.add_child(cancel_btn)

# 确认按钮
var confirm_btn := TextureButton.new()
confirm_btn.custom_minimum_size = Vector2(170, 70)
confirm_btn.texture_normal = BTN_CONFIRM
confirm_btn.ignore_texture_size = true
confirm_btn.stretch_mode = TextureButton.STRETCH_SCALE
btn_row.add_child(confirm_btn)

box.add_child(btn_row)  # 加进弹窗主 VBox
```

---

## 猫咪卡片弹窗（CatCard）

| 项目 | 值 | 说明 |
|------|-----|------|
| 底图贴图 | `assets/art/ui/catcard/catcard_panel.png` | AtlasTexture 600×780 |
| 弹窗定位 | 底部居中 | `anchor_bottom = 1.0`，offset_top = -780 |
| 遮罩 | Color(0, 0, 0, 0.45) | 全屏半透明黑，穿通鼠标 |
| 猫咪立绘 | AnimatedSprite2D @ position(300, 240) | |
| 名称字号 | 24 | `#4F453C` |
| 品种字号 | 16 | `#A2978C` |
| 互动按钮 | `btn_feed` / `btn_pet` / `btn_play` | 126×68 间距 12 |
| 功能按钮 | `btn_explore` / `btn_adrefresh` | 196×62 |
| 底部文字链接 | 代码按钮 | detail / companion / relinquish |
| 关闭按钮 | `btn_close_*.png` | 44×44 |

---

## 探索返回弹窗

| 项目 | 值 | 说明 |
|------|-----|------|
| 底图贴图 | `popup_bg.png` | |
| 弹窗尺寸 | **560×280** | |
| 标题 | "XXX 回来了" | 字号 27，色 `#4F453C` |
| 副标题 | "带回了XXX" | 字号 22，色 `#A2978C` |
| 确认按钮 | `btn_confirm_name.png` | 170×70 |
| 按钮文字 | "好的" | 字号 18 |
| 按钮出现时机 | 弹入动画后 1.5s | |

---

## 礼物揭晓弹窗（明信片/食材/装饰）

| 项目 | 值 | 说明 |
|------|-----|------|
| 底图贴图 | `popup_bg.png` | |
| 弹窗尺寸 | **560×320** | 比基础弹窗高 40px（容纳图片区） |
| 标题 | "新食材" / "新装饰" / "城市明信片" | 字号 27，色 `#4F453C` |
| 图片占位 | ColorRect 100px 高 | 色 `#ECE8E0`，60% 透明 |
| 描述文本 | "橘子 带回了一份可以收藏的探索食材。" | 字号 16，色 `#7A6E63` |
| 确认按钮 | `btn_confirm_name.png` | 170×70 |
| 按钮文字 | "收下" | 字号 18 |

---

## 成就解锁通知横幅

| 项目 | 值 | 说明 |
|------|-----|------|
| 类型 | **顶部通知横幅** | 非交互式，不遮挡游戏中心区域 |
| 定位 | `PRESET_CENTER_TOP` | 水平居中，顶部下拉动画 |
| 底色 | `StyleBoxFlat` #FAF0D6 98% 18px圆角 | 有阴影（12px） |
| 尺寸 | 620×120（offset_left=-310, offset_right=310） | 居中于屏幕顶部 |
| 动画 | 从 y=-120 滑入到 y=24，0.4s Cubic EaseOut | |
| 自动消失 | **5秒** | Timer触发，无需用户确认 |
| 内容 | 成就分类图标(64×64金色方块) + 标题"成就解锁 · XX" + 奖励文字 | |
| 按钮 | 有"知道了"按钮（88×44）但非必须操作 | 用户也可以等5秒自动消失 |
| 用途 | 成就解锁、收集完成等**被动通知** | 不打断用户当前操作 |

## 文字色板

| 用途 | 色值 | 名称 |
|------|------|------|
| 标题/按钮文字/主要 | `#4F453C` | 深棕 |
| 副标题/说明 | `#A2978C` | 浅棕 |
| 描述/详情 | `#7A6E63` | 中灰棕 |
| CatCard 探索按钮 | `#5A4A3D` | 中深棕 |
| 品种/状态标签 | `#A2978C` | 浅棕 |

---

## 贴图资源索引

| 资源路径 | 用途 |
|----------|------|
| `assets/art/ui/panels/popup_bg.png` | 通用弹窗底图 |
| `assets/art/ui/catcard/catcard_panel.png` | CatCard 卡片底图 |
| `assets/art/ui/incubation/components/btn_confirm_name.png` | 确认/好的/收下 按钮 |
| `assets/art/ui/incubation/components/btn_secondary_blank.png` | 次要/取消 按钮 |
| `assets/art/ui/catcard/btn_close_*.png` | 关闭按钮（4态） |
| `assets/art/ui/catcard/btn_explore_*.png` | 探索按钮（4态） |
| `assets/art/ui/catcard/btn_feed_*.png` | 喂食按钮（4态） |
| `assets/art/ui/catcard/btn_pet_*.png` | 抚摸按钮（4态） |
| `assets/art/ui/catcard/btn_play_*.png` | 玩耍按钮（4态） |
| `assets/art/ui/catcard/btn_adrefresh_*.png` | 广告刷新按钮（4态） |
