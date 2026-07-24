# Catwalk（猫步天下）— 项目简报

Godot 4.6 手游：步数驱动的养猫休闲游戏（走路攒能量→孵猫→养成/探索/棋盘小游戏）。
主场景流：`scenes/S00_Splash` → 花园主界面 `S04_GardenMain`，各系统页 S10~S14。

## 目录速查

- `core/` 系统逻辑（Hatch/Step/Energy/Currency/Interaction/Explore 等，多为 autoload）
- `autoload/` 轻量单例（TicketManager 棋盘门票、Juice 手感、Palette 配色）
- `scripts/board_game/` 猫咪合合乐（合成棋盘）全部逻辑——纯逻辑与 UI 分离
- `scenes/S14_BoardGame.gd` 棋盘 UI 层（奖励入库、弹窗、特效在这里）
- `tests/` headless 自检套件（见下）；`tools/econ_sim/` Python 经济蒙特卡洛模拟器
- `specs/cat_merge_iteration_plan.md` 棋盘审计与 M1~M4 迭代方案（含偏差记录）——改棋盘前必读

## 验证（改动后必跑，全绿才可提交）

```bash
# GODOT 指向 4.6.x 可执行文件；无本地 Godot 时可从镜像下载 headless 版
GODOT=godot tests/check_scripts.sh                                  # 编译扫描（类型/标识符错误）
godot --headless res://tests/board_game_selfcheck.tscn              # 棋盘规则自检
godot --headless res://tests/level_state_manager_selfcheck.tscn    # 等级/里程碑/B6
MC_RUNS=1000 godot --headless res://tests/board_montecarlo.tscn    # 分关卡通关率实测
# 改经济数值（奖励/门票/里程碑/B6）时追加：
cd tools/econ_sim && python3 run_sim.py --all --iterations 50      # A7/A8 断言须无新增 FAIL
```

详见 `T4自检使用说明.md`。退出码可接 CI。

## 关键约定（踩过坑的）

- **缩进用 Tab**；GDScript 静态类型：for-in 循环变量等无类型来源处**不要用 `:=`**，显式标注类型
- 跨脚本引用**用 `const X := preload(...)`，不要依赖全局 `class_name`**——headless/未重扫描 class 缓存时会 "Identifier not found"
- `.import` 文件**需要提交**（.gitignore 有注释说明）；`__pycache__` 不提交
- 棋盘存档序列化：新增字段必须进 `serialize_state/deserialize_state` 且旧档缺省兜底；单调时钟（ticks_msec）不可持久化
- 撤销系统：任何合并时的状态变更（兴奋值/蓄能池/三连合）必须进 undo 快照，否则可被"撤销-重做"刷取
- 经济改动同步三处：GDScript 实现、`tools/econ_sim/config/params.json`、必要时 `sim/engine.py`——GDD 与实现的漂移是本项目主要 bug 来源（案例：门票 2票/局 vs 1票/局、B6 无条件转金）
- 通关判定用 `grid[pos_b]` 最终产物（三连合会把 new_item 再升一级——曾因此漏判胜利）
- **UI 层禁止直改 `board.grid`**，一律走引擎方法（含死局重查/进度信号）；
  引擎信号的 UI 处理函数若涉及棋盘物品变化，**必须先 `_refresh_all()` 再播动画**
  （案例：狂欢帮忙生成的道具"看不见"、救局删除绕过死局检查）
- StyleBoxFlat 无 `border_width/corner_radius/content_margin` 聚合属性，
  用 `set_*_all()`——lambda 内的动态属性错误编译扫描抓不到，只在运行时暴露

## 棋盘（猫咪合合乐）现状一句话

5×5 合成棋盘：20 次生成器、主链⭐5 通关（委托局为订单目标）、副链⭐3 出口、
捣乱/狂欢二选一/兴奋值蓄能、三档关卡 + 胜场里程碑 + 每日变异 + 周末委托。
数值特征：通关率≈100%（低失败率设计），**三星率是分层点**（casual 玩家 LV2/3 约 50-57%）。
埋点：`BoardTelemetry`（本地 JSONL 缓冲，上报通道未接）。

## 遗留事项（下一批候选）

- 评星门槛偏松：熟练玩家三星率≈100%，候选方案三星线剩余≥4 → ≥5
- 里程碑「毛线王座/限定明信片」占位入库（decor/hidden_item），待专属美术
- 变异池「双子日」未实装（池结构已支持）；埋点上报通道未接
- econ_sim 既有 FAIL：A2/A3/A4/A6（能量/孵化系统，与棋盘无关，见 tools/econ_sim/README）
