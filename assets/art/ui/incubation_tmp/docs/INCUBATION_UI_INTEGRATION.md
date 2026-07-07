# Catwalk 孵化室 UI 资源接入说明

## 1. 包内容

本包是孵化室页面的 UI 组件资源，风格对齐当前孵化蛋：清爽 2D 手绘、奶油底、暖棕描边、轻植物装饰。

目录建议直接复制到 Godot：

```text
res://assets/art/ui/incubation/
  background/
    incubation_room_bg_720x1280.png
    incubation_room_bg_1080x1920.png
  components/
    btn_back.png
    btn_secondary_blank.png
    btn_primary_green_blank.png
    panel_energy_slot.png
    progress_bar_empty.png
  slots/
    slot_card_empty.png
    slot_card_locked.png
    slot_card_incubating.png
    slot_card_ready.png
  eggs/
    egg_orange_tabby.png
    egg_british_shorthair.png
    egg_siamese.png
```

## 2. 文件用途

| 文件 | 尺寸 | 用途 |
|---|---:|---|
| `incubation_room_bg_720x1280.png` | 720×1280 | 低/中分辨率孵化室背景 |
| `incubation_room_bg_1080x1920.png` | 1080×1920 | 推荐主背景 |
| `btn_back.png` | 96×96 | 左上返回按钮 |
| `btn_secondary_blank.png` | 240×96 | 米白小按钮，例如“注入”按钮底图 |
| `btn_primary_green_blank.png` | 620×100 | 底部绿色主按钮底图 |
| `panel_energy_slot.png` | 620×300 | 顶部备用能量槽面板 |
| `progress_bar_empty.png` | 334×28 | 进度条空槽 |
| `slot_card_empty.png` | 334×178 | 空槽卡面 |
| `slot_card_locked.png` | 334×178 | 锁态卡面 |
| `slot_card_incubating.png` | 334×178 | 孵化中卡面 |
| `slot_card_ready.png` | 334×178 | 就绪发光卡面 |
| `egg_orange_tabby.png` | 256×256 | 橘猫蛋 |
| `egg_british_shorthair.png` | 256×256 | 英短蛋 |
| `egg_siamese.png` | 256×256 | 暹罗蛋 |

## 3. Godot 导入设置建议

所有 UI PNG：

```text
Import 类型：Texture2D
Filter：On
Mipmaps：Off
Repeat：Disabled
Compress Mode：Lossless / VRAM Uncompressed（二选一，UI建议 Lossless）
```

背景图：

```text
TextureRect
Layout：Full Rect
Stretch Mode：Keep Aspect Covered
```

按钮与卡片：

```text
TextureRect / TextureButton
Expand Mode：Ignore Size 或 Fit Width Proportional
Stretch Mode：Keep Aspect Centered
```

## 4. 推荐节点结构

```text
IncubationRoom(Control)
├── Bg(TextureRect)
├── BackButton(TextureButton)
├── Title(Label)
├── Subtitle(Label)
├── EnergyPanel(TextureRect)
│   ├── EggIcon(TextureRect)
│   ├── Title(Label)
│   ├── EnergyText(Label)
│   ├── ProgressBg(TextureRect)
│   └── InjectButton(TextureButton)
├── EggGrid(GridContainer)
│   ├── Slot1(TextureButton)
│   │   ├── Egg(TextureRect)
│   │   ├── ProgressBg(TextureRect)
│   │   └── StatusLabel(Label)
│   └── ...
└── BottomEnergyButton(TextureButton)
```

## 5. 状态切换规则

卡槽状态建议用一个 `TextureButton` 或 `TextureRect` 切换底图：

```gdscript
func set_slot_state(slot: TextureRect, state: String) -> void:
    var base = "res://assets/art/ui/incubation/slots/"
    match state:
        "empty":
            slot.texture = load(base + "slot_card_empty.png")
        "locked":
            slot.texture = load(base + "slot_card_locked.png")
        "incubating":
            slot.texture = load(base + "slot_card_incubating.png")
        "ready":
            slot.texture = load(base + "slot_card_ready.png")
```

蛋图标建议单独作为子节点放在卡面上，不建议把文字烘焙进图片：

```gdscript
func set_egg_icon(egg_node: TextureRect, breed_id: String) -> void:
    var base = "res://assets/art/ui/incubation/eggs/"
    match breed_id:
        "orange_tabby":
            egg_node.texture = load(base + "egg_orange_tabby.png")
        "british_shorthair":
            egg_node.texture = load(base + "egg_british_shorthair.png")
        "siamese":
            egg_node.texture = load(base + "egg_siamese.png")
```

## 6. 适配建议

以 720×1280 作为 UI 设计基准时：

```text
背景：Full Rect
顶部标题：Y≈85
能量面板：X≈50, Y≈220, W≈620, H≈260
卡槽：334×178，2列布局
卡槽间距：约24 px
底部主按钮：X≈50, Y≈1120, W≈620, H≈96
```

以 1080×1920 作为 UI 设计基准时，可以整体乘以 1.5。

## 7. 文字规则

本包所有按钮底图都没有文字。文字请在 Godot 中用 `Label` 叠加，方便多语言和状态刷新。

推荐文字色：

```text
主标题/正文：#6B3A1E
弱提示：#9B6A45
绿色按钮文字：#FFFFFF
```



## V2 更新

- `slot_card_empty.png`、`slot_card_locked.png`、`slot_card_incubating.png`、`slot_card_ready.png` 已重新统一为同一张奶油底金边卡面体系。
- `locked`：在统一底图基础上增加居中锁图标。
- `incubating`：在统一底图基础上增加底部轻发光能量线。
- `ready`：在统一底图基础上增加整卡柔和金色发光与星点。
