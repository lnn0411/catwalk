# 猫步天下 · 开发铁律

> **版本**：v1.0 · 2026-06-14 | **制定者**：主人 + 莫老五
> **效力**：莫老五所有代码提交必须满足以下全部规则，违例直接拒绝合入。

---

## 一、分支隔离

| 分支 | 用途 | 规则 |
|------|------|------|
| `main` | 核心循环 + 所有不依赖美术的新模块 | T1 渐进灌注不得推入此分支 |
| `feature/progressive-energy` | T1 渐进灌注（EnergyEngine/HatchEngine 修改） | 独立开发，主人亲自合并验证 |

**铁律**：`main` 上不碰 `core/EnergyEngine.gd` 和 `core/HatchEngine.gd`。新模块全部为独立新增文件。

---

## 二、每次 push 必附带自检报告

push 前必须：

```bash
# 1. 自检脚本（场景模式，加载 autoload）
godot --headless tests/t3_runtime_selfcheck.tscn 2>&1 | grep "结果"

# 2. git diff 自证
git diff origin/main --stat
```

**判定标准**：
- 自检 ≥ 97 通过（当前 main 基准线：97/99，2 项 HatchEngine 槽位轮询为既有问题）
- 低于 97 → block，修复后重跑
- `git diff --stat` 出现 `core/EnergyEngine.gd` 或 `core/HatchEngine.gd` → 禁止 push（除非在 feature/progressive-energy 分支）

**当前基准线（2026-06-14）**：97/99 通过。2 项既有失败：
- `轮询: collect slot0 后轮到 slot1=ready`（期望 ready，实际 incubating）
- `轮询: slot1 满 4250`（期望 4250，实际 0）

---

## 三、代码审计

每个模块完成后的流程：
1. **Codex (gpt-5.5)** 编码 → 写文件
2. **Claude Opus 4.8** 审计 → P0/P1 分类
3. P0 > 0 或 P1 > 0 → Codex 修复 → 再审
4. P0 = 0 且 P1 = 0 → git add 具体文件 → commit → 跑自检 → push

**禁止手势修代码**（sed/patch/write_file），必须 Codex 全量修。

---

## 四、P0 开发顺序

```
Day 1: 底座层
  ├── EventBus 核验
  ├── 货币系统 CurrencyManager
  ├── 背包道具 InventoryManager
  ├── 时间反作弊 TimeGuard
  ├── 明信片配置表
  └── T1 渐进灌注（feature/progressive-energy 分支）

Day 2: 核心系统
  ├── 探索状态机 + 计时
  ├── 探索奖励 Roll + 概率
  └── 猫咪情绪状态机

Day 3: 养成 + 周期
  ├── 猫咪作息时间表
  ├── 猫咪等级/EXP 系统
  ├── 猫咪互动冷却系统
  └── 签到系统

Day 4: 数据 + 配置
  ├── 成就系统
  ├── 猫咪日记数据框架
  └── 存档迁移 + SaveManager 增强
```

---

## 五、项目信息

- **仓库**：`lnn0411/catwalk` (HTTPS: `https://github.com/lnn0411/catwalk.git`)
- **Godot**：4.6.3.stable
- **自检脚本**：`tests/t3_runtime_selfcheck.gd`（522 行，108 项断言）
- **GDD 权威版**：v2.15（2026-06-12）
- **程序规格书**：v1.2（token: JwModIXVEomLhZxri6EcUP4Mneh）
