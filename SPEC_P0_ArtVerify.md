# SPEC: P0 正式美术母版工程接入验证场景

## 目标
创建 `scenes/P0_ArtVerify.tscn` + `scenes/P0_ArtVerify.gd`，展示库洛洛交付的P0正式美术母版候选包的所有资产。

## 资产路径（已复制到项目）
- Garden master: `res://assets/art/garden/garden_master.png` (2048x1536)
- Garden far: `res://assets/art/garden/layers/garden_far.png` (2048x1536, alpha)
- Garden mid: `res://assets/art/garden/layers/garden_mid.png` (2048x1536, alpha)
- Garden near: `res://assets/art/garden/layers/garden_near.png` (2048x1536, alpha)
- Cat idle 00: `res://assets/art/cats/orange_tabby/idle_00.png` (512x512)
- Cat idle 01: `res://assets/art/cats/orange_tabby/idle_01.png` (512x512)
- Cat idle 02: `res://assets/art/cats/orange_tabby/idle_02.png` (512x512)

## 场景要求
1. 根节点 Node2D，名为 "P0ArtVerify"
2. 包含 ParallaxBackground，层级顺序：far → mid → near
3. far 层 motion_scale = Vector2(0.05, 0), mid = Vector2(0.3, 0), near = Vector2(0.8, 0)
4. 每层放 Sprite2D，加载对应PNG，scale 适配 720x1280 viewport
5. 在 near 层上方放橘猫 idle 动画：3帧 Sprite2D，0.5秒切换一帧
6. Camera2D 初始位置 (1024, 768)，支持鼠标拖拽平移（参考 GardenScene.gd 的 _unhandled_input）
7. 右上角放调试信息 Label：显示当前帧号、相机位置
8. PNG import 设置：Filter OFF, Mipmap OFF, Repeat OFF

## 代码规范
- GDScript 文件
- 不使用 CanvasLayer（阻断事件传递）
- 猫咪帧切换用 Timer
- 调试信息用 Label 放在独立 Control 节点上（非 CanvasLayer）
- 保留现有 GardenScene 不动，这是新场景
- 场景文件格式参考现有 scenes/GardenScene.tscn

## 项目上下文
- project.godot viewport: 720x1280
- 渲染模式: mobile
- emulate_touch_from_mouse: true

请在 /home/agentuser/catwalk 项目目录中创建文件。
