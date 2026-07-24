# 上线测试整备 · 美术需求总清单 v2.0（生产规格版）

> v2.0 变更：①全部规格改为**从工程现状实测推导**的硬规格（设计分辨率/现有资产
> 尺寸/导入设置）；②新增机器可读清单 `tools/art_check/art_manifest.json`（86 件
> 逐文件定尺寸定名）与**入库预检脚本** `tools/art_check/check_art.py`——美术交付
> 先过脚本、零 ERROR 才允许入库，从流程上压低返修率；③蛋分档定案进上线范围
> （制作人 2026-07-23：「该补的都补上」），C1 花纹蛋一套列入必交；活动蛋仍随
> 首个活动排期。
>
> **交付验收流程（美术侧必读）**：
> 1. 按本文件规格出图，文件名与 `art_manifest.json` 逐一对应（差一个字符都算错）；
> 2. 全部放入一个交付目录（可分子文件夹），运行：
>    `python3 tools/art_check/check_art.py <交付目录>`
> 3. 零 ERROR 后按各类 `target` 路径移入工程，Godot 编辑器扫描生成 `.import`，
>    **PNG 与 .import 一并提交**（工程约定）；
> 4. WARN 项（iCCP 色彩块、清单外文件）需人工确认后放行。

---

## 0. 硬性总则（所有资产一律适用）

| 项 | 规格 | 依据 |
|---|---|---|
| 格式 | PNG，8bit，**RGBA**（color_type 6），非隔行扫描，sRGB，**不嵌 ICC 配置** | 预检脚本强校验 |
| 背景 | **真透明底**（alpha=0），不是白底/棋盘格底/近白底 | 导入开启 `fix_alpha_border`，脏底会裁出毛边 |
| 安全边距 | 主体四边各留 **≥3% 透明边距**，主体居中（九宫格/进度条类除外，清单标 `full_bleed`） | 防出血贴边；脚本按 alpha 包围盒实测 |
| 命名 | 全小写 snake_case，仅 `a-z 0-9 _`，禁中文/空格/大写/连字符 | 与代码 id 一致；脚本正则校验 |
| 动画帧 | 逐帧独立 PNG，`{名}_frame_00.png` 起零填充两位，**同尺寸同锚点**，主体逐帧连续 | 现有猫动画即此约定（`idle_front_frame_00.png`…） |
| 设计基准 | 设计分辨率 **720×1280**（canvas_items/expand）；本清单尺寸≈2x 源图，引擎内缩放 | `project.godot` 实测 |
| 风格 | 日系治愈绘本风；单光源左上；描边与配色遵循 `autoload/Palette.gd`（关键 hex 见 §5） | Style Bible v2.2 |
| 交付物 | 仅 PNG（+A2 的锚点确认稿）；`.import` 由工程侧生成提交 | — |

**给美术 AI 的出图守则**（把返修消灭在生成阶段）：
- 提示词必须含：`transparent background, single centered subject, no drop shadow
  touching edges, no watermark, no text`；
- 一图一物，禁止拼图/九宫格出多物再裁切（裁切必破安全边距与居中）；
- 系列件（16 配饰、8 花卉、5 蛋阶段）**用同一风格种子/参照图**分批出，保持
  线宽、饱和度、视角一致；交付前自查任意两件放在一起是否像同一个游戏；
- 帧动画不要逐帧独立生成——先出关键帧，中间帧以关键帧为参照图生成，锚点漂移
  超过 2px 即返修。

---

## 1. A 组｜P2 前必交（卡工坊上线）

### A1｜工坊配饰 icon ×16 — `256×256` → `assets/art/workshop/icons/`

蛋 icon 现为 256×256，同规格。文件名 `{id}_icon.png`，id 与稀有度：

| id | 名称 | 稀有度 | | id | 名称 | 稀有度 |
|---|---|---|---|---|---|---|
| deco_scarf | 小围巾 | common | | deco_bell | 铃铛项圈 | rare |
| deco_ribbon | 蝴蝶结 | common | | deco_hat | 小礼帽 | rare |
| deco_bowtie | 小领结 | common | | deco_tie | 小领带 | rare |
| deco_straw | 编织草帽 | common | | deco_santa | 圣诞围巾 | rare |
| deco_glasses | 圆框眼镜 | common | | deco_cape | 小披风 | rare |
| deco_tiara | 水晶发饰 | epic | | deco_crown | 星辰王冠 | legendary |
| deco_wings | 天使翅膀 | epic | | deco_moon | 月轮光环 | legendary |
| deco_flowercrown | 花冠 | epic | | deco_boots | 小靴子 | epic |

主体占画布 70–80%，icon 内**不画稀有度光效**（光效由引擎按 Palette 稀有度色叠加）。

### A2｜配饰上猫挂件 ×16 — `400×400` → `assets/art/workshop/wear/`

- 文件名 `{id}_wear.png`；画布 = 猫立绘帧画布（实测 400×400），**以橘猫 catcard
  idle 正面姿态为底稿作画**（底稿由工程侧从 `assets/art/cats/portraits/catcard/
  orange/catcard_orange_idle_frame_00.png` 提供），交付时删除底稿层只留挂件。
- 挂件在 400×400 画布上的位置即最终佩戴位置——**不允许居中交付再由工程摆位**
  （这是挂件类返修的最大来源）。英短/暹罗用工程侧偏移配置适配，不出品种分版。
- 范围（上线版）：挂件仅在**猫卡界面**渲染，不上花园行走帧——范围锁定，勿画
  多角度版本。
- 本类**豁免居中检查**但仍须 3% 边距（挂件位于头/颈区，天然不贴边）。

### A3｜工坊花卉 ×8 — icon `256×256` + 花园精灵 `128×128`（樱花枝 `128×256`）

→ icon 入 `assets/art/workshop/icons/`（`{id}_icon.png`），
精灵入 `assets/art/workshop/garden/`（`{id}.png`）：

| id | 名称 | 稀有度 | 精灵尺寸 | | id | 名称 | 稀有度 | 精灵尺寸 |
|---|---|---|---|---|---|---|---|---|
| flower_daisy | 小雏菊 | common | 128×128 | | flower_rose | 玫瑰 | epic | 128×128 |
| flower_sunflower | 向日葵 | common | 128×128 | | flower_lotus | 睡莲 | epic | 128×128 |
| flower_lavender | 薰衣草 | rare | 128×128 | | flower_cherry | 樱花枝 | legendary | **128×256** |
| flower_tulip | 郁金香 | rare | 128×128 | | flower_ether | 以太花 | legendary | 128×128 |

- 花园网格 64px/格，精灵按 2x 出（128=1 格宽），**锚点=底边中心**（贴地），
  植株根部贴画布下边缘内 3% 处；
- 樱花枝为立枝（1×2 格高），必须与棋盘「樱花树」（现有 `sakura_tree.png`）
  明显区分体量——枝非树。

### A4｜礼盒与 FAB → `assets/art/workshop/box/`

| 文件 | 尺寸 | 说明 |
|---|---|---|
| gift_box_closed.png / gift_box_open.png | 512×512 ×2 | 单一盒型；稀有度光效引擎叠加（Palette §5），**不出四套盒** |
| gift_box_open_frame_00~07.png | 512×512 ×8 | 拆盒序列：轻晃(0-2)→盖开(3-5)→光效爆点(6)→定格(7)；总时长 ≤1.0s；盒体锚点逐帧不动 |
| fab_workshop_idle.png / fab_workshop_active.png | 96×96 ×2 | 粉色礼盒 FAB；idle=去饱和 60%；红点与数字由引擎绘制，**图内不画** |

### A5｜HUD 与 UI 状态件

| 文件 | 尺寸 | target | 说明 |
|---|---|---|---|
| hud_energy_normal / warm / full.png | 96×96 ×3 | `assets/art/delivery/hatch/components/` | 能量罐三态：常态（AMBER 主色）/ 将满暖金 / 满态**粉色光泽**（成就感非警告，用 LOVE_PETAL 色系） |
| egg_lock_overlay.png | 96×96 | 同上 | 包满锁图标，叠加于 ready 蛋卡右上；线色 TEXT_PRIMARY |
| surprise_card_panel.png | 620×720 | `assets/art/ui/` | 步数惊喜卡面板；`full_bleed`，四角 40px 圆角可九宫格拉伸；内容区留白由 UI 排 2/3 项布局 |
| chest_daily_closed / open.png | 120×120 ×2 | `assets/art/ui/` | 今日步数宝箱两态（棋盘 icon 同规格 120）；进度环引擎绘制，**图内不画环** |

---

## 2. B 组｜P3 前必交（内容层）

| 文件 | 尺寸 | target | 说明 |
|---|---|---|---|
| stamp_frame.png | 264×192 | `assets/art/postcards/` | 旅行邮票框模板：锯齿邮票边+内透明窗 224×150 居中（明信片 750×500 缩至 0.3 嵌入）；`full_bleed` |
| stamp_icon.png | 96×96 | `assets/art/ui/` | 邮票通用 icon |
| icon_love_petal.png | 96×96 | `assets/art/ui/` | 爱心花瓣=**心形**，基色 `E58AA8`（Palette.LOVE_PETAL） |
| icon_spring_petal.png | 96×96 | `assets/art/ui/` | 活动花瓣=**樱花五瓣形+活动缎带边框**，基色 `F2A8BE`（SPRING_PETAL）——与爱心花瓣轮廓+构件双重区分（总案 B6） |
| icon_affection.png | 64×64 | `assets/art/ui/` | 好感 ❤（当下的关怀） |
| icon_bond.png | 64×64 | `assets/art/ui/` | 羁绊 🐾 脚印（同行的岁月） |
| icon_bond_star.png | 32×32 | `assets/art/ui/` | 羁绊星（★×3 满） |
| pity_bar_bg / fill.png | 334×28 ×2 | `assets/art/delivery/hatch/components/` | 保底进度条，沿用现有 `progress_bar_empty.png` 同规格；`full_bleed` |
| silhouette_british / siamese.png | 256×256 ×2 | 同上 | 品种解锁预告**纯剪影**（TEXT_PRIMARY 单色 85% 不透明度），不可辨认细节——神秘感载体 |
| placeholder_postcard_orange / british / siamese.png | 224×150 ×3 | `assets/art/postcards/` | 图鉴占位灰剪影「需要一只 XX」 |

---

## 3. C 组｜蛋分档（已定案进上线，P3 前交付）

| 文件 | 尺寸 | target | 说明 |
|---|---|---|---|
| egg_patterned_stage_01~04.png | 256×256 ×4 | `assets/art/delivery/hatch/eggs/` | 花纹蛋四阶段蛋壳渐进（GDD §8.2 硬规格）：素壳→纹样浮现→纹样发光→细裂纹；与现有 `egg_orange_tabby.png` 同尺寸**同锚点同蛋形轮廓**（只换壳面，不改剪影） |
| egg_patterned_ready.png | 256×256 | 同上 | ready 发光态 |

活动蛋（egg_event_*）不在本单，随首个活动排期，规格同上 5 帧。

---

## 4. D 组｜遗留（上线测试后，不阻塞）

毛线王座专属美术（棋盘 100 胜）、限定明信片（200 胜）、羁绊入账/升星演出（v1.1）。

---

## 5. 色板速查（出图对色用，权威=`autoload/Palette.gd`）

| 用途 | hex | | 用途 | hex |
|---|---|---|---|---|
| 背景奶油 PAPER_CREAM | `F6EFE2` | | 金币 COIN | `EAB94F` |
| 主色琥珀 AMBER | `F2C572` | | 钻石 DIAMOND | `86C0DC` |
| 花园鼠尾草 SOFT_SAGE | `A6BE84` | | 爱心花瓣 LOVE_PETAL | `E58AA8` |
| 文字主色 TEXT_PRIMARY | `4F453C` | | 活动花瓣 SPRING_PETAL | `F2A8BE` |
| 深描边 AMBER_PRESS | `C4894A` | | 稀有度 rare | `9BB8D4` |
| 成功/生机 MOSS | `7A9E6E` | | 稀有度 epic | `8E6FA8` |
| 警示 BRICK | `B5553C` | | 稀有度 legendary | `D6E4EC`/`E8D5C0` 双色 |

---

## 6. 数量与交付节奏

| 组 | 期限 | 文件数（manifest 精确计数） | 阻塞 |
|---|---|---|---|
| A | P2 开工前 | 67（icon32 + 挂件16 + 花卉16* + 盒/FAB12 + HUD/UI7）*含双尺寸 | 工坊/惊喜卡/HUD |
| B | P3 开工前 | 14 | 内容层 |
| C | P3 前 | 5 | 蛋分档 |
| **合计** | | **86**（`art_manifest.json` 为唯一权威计数） | |

> 预检命令（可只查单组）：
> `python3 tools/art_check/check_art.py <交付目录> --class A1_gift_icons`
> 美术确认排期后在本表回填「预计交付日」列；A 组任何一件延期即顺延 P2。
