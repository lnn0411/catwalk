# 弹窗规格标准 v1.0

## 基础弹窗（通用消息/确认）

| 项目 | 值 | 说明 |
|------|-----|------|
| 底图贴图 | `assets/art/ui/panels/popup_bg.png` | 居中，无缩放 |
| 弹窗尺寸 | **560×280** | `_center_control(panel, Vector2(560, 280))` |
| 遮罩 | Color(0, 0, 0, 0.5) | 全屏半透明黑 |
| 标题字号 | 27 | 深棕色 `#4F453C`，居中 |
| 副标题/内容字号 | 22 | 浅棕色 `#A2978C`，居中 |
| 确认按钮贴图 | `assets/art/ui/incubation/components/btn_confirm_name.png` |
| 按钮尺寸 | **170×70** | `custom_minimum_size = Vector2(170, 70)` |
| 按钮文字色 | `#4F453C` | 深棕 |
| 按钮字号 | 18 | 居中 |
| 按钮位置 | `Vector2((PANEL_SIZE.x - 170) * 0.5, PANEL_SIZE.y - 90)` |

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

# 确认按钮
var ok_btn := TextureButton.new()
ok_btn.custom_minimum_size = Vector2(170, 70)
ok_btn.texture_normal = BTN_CONFIRM
ok_btn.ignore_texture_size = true
ok_btn.stretch_mode = TextureButton.STRETCH_SCALE
ok_btn.position = Vector2((560 - 170) * 0.5, 280 - 90)
panel.add_child(ok_btn)

var ok_label := Label.new()
ok_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
ok_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
ok_label.text = "好的"
ok_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
ok_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
ok_label.add_theme_font_size_override("font_size", 18)
ok_label.add_theme_color_override("font_color", Color("#4F453C"))
ok_btn.add_child(ok_label)

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

## 猫咪卡片弹窗（CatCard）

| 项目 | 值 | 说明 |
|------|-----|------|
| 底图贴图 | `assets/art/ui/catcard/catcard_panel.png` | AtlasTexture 600×780 |
| 弹窗定位 | 底部居中 | `anchor_bottom = 1.0`，offset_top = -780 |
| 遮罩 | Color(0, 0, 0, 0.45) | 全屏半透明黑，穿通鼠标 |
| 猫咪立绘 | AnimatedSprite2D @ position(300, 240) |
| 名称字号 | 24 | `#4F453C` |
| 品种字号 | 16 | `#A2978C` |
| 互动按钮贴图 | `btn_*_normal/hover/pressed` | feed/pet/play |
| 探索按钮贴图 | `btn_explore_*.png` |
| 功能按钮尺寸 | 196×62 | `custom_minimum_size = Vector2(196, 62)` |
| 探索确认按钮 | `btn_confirm_name.png` | 尺寸 170×70 |
| 关闭按钮 | `btn_close_*.png` | 44×44 |

---

## 探索返回弹窗

| 项目 | 值 | 说明 |
|------|-----|------|
| 底图贴图 | `popup_bg.png` |
| 弹窗尺寸 | **560×280** |
| 标题 | "XXX 回来了" | 字号 27，色 `#4F453C` |
| 副标题 | "带回了XXX" | 字号 22，色 `#A2978C` |
| 确认按钮 | `btn_confirm_name.png` | 170×70 |
| 按钮文字 | "好的" | 字号 18 |
| 按钮出现时机 | 弹入动画后 1.5s |

---

## 礼物揭晓弹窗（明信片/食材/装饰）

| 项目 | 值 | 说明 |
|------|-----|------|
| 底图贴图 | `popup_bg.png` |
| 弹窗尺寸 | **560×320** | （比基础弹窗高 40px，容纳图片区） |
| 标题 | "新食材" / "新装饰" / "城市明信片" | 字号 27，色 `#4F453C` |
| 图片占位 | ColorRect 100px 高 | 色 `#ECE8E0`，60% 透明 |
| 描述文本 | "橘子 带回了一份可以收藏的探索食材。" | 字号 16，色 `#7A6E63` |
| 确认按钮 | `btn_confirm_name.png` | 170×70 |
| 按钮文字 | "收下" | 字号 18 |

---

## 关键贴图资源索引

| 资源路径 | 用途 |
|----------|------|
| `assets/art/ui/panels/popup_bg.png` | 通用弹窗底图 |
| `assets/art/ui/catcard/catcard_panel.png` | CatCard 卡片底图 |
| `assets/art/ui/incubation/components/btn_confirm_name.png` | 确认/好的/收下 按钮 |
| `assets/art/ui/catcard/btn_close_*.png` | 关闭按钮（4态） |
| `assets/art/ui/catcard/btn_explore_*.png` | 探索按钮（4态） |
| `assets/art/ui/catcard/btn_feed_*.png` | 喂食按钮（4态） |
| `assets/art/ui/catcard/btn_pet_*.png` | 抚摸按钮（4态） |
| `assets/art/ui/catcard/btn_play_*.png` | 玩耍按钮（4态） |

---

## 文字色板

| 用途 | 色值 | 名称 |
|------|------|------|
| 标题/主要文字 | `#4F453C` | 深棕 |
| 副标题/说明 | `#A2978C` | 浅棕 |
| 描述/详情 | `#7A6E63` | 中灰棕 |
| 按钮内文字 | `#4F453C` | 深棕 |
