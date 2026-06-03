# CatWalk Step Counter - Godot 4.6.3 Android 原型

## 概述
验证 Godot 4.6.3 能否在 Android 上读取系统步数计数器（Sensor.TYPE_STEP_COUNTER）。

**GitHub**: https://github.com/lnn0411/catwalk/tree/godot-prototype  
**CI 状态**: [![Build APK](https://github.com/lnn0411/catwalk/actions/workflows/build-apk.yml/badge.svg?branch=godot-prototype)](https://github.com/lnn0411/catwalk/actions/workflows/build-apk.yml)

## 项目结构

```
catwalk_godot/
├── project.godot              # Godot 项目配置
├── export_presets.cfg         # Android 导出预设
├── scenes/
│   └── main.tscn              # 主场景（步数Label + 权限按钮）
├── scripts/
│   └── main.gd                # GDScript 主逻辑
├── android/
│   ├── build/                 # Gradle 构建模板（含自定义代码）
│   └── plugins/
│       └── step_counter/
│           ├── StepCounterPlugin.kt   # Kotlin Android Plugin
│           └── step_counter.gdap     # Godot Plugin 描述符
└── .github/workflows/
    └── build-apk.yml          # CI/CD: 自动构建 APK
```

## 技术方案

### 步数计桥接
- **方案**: 自定义 Android Plugin (Kotlin)
- **API**: `Sensor.TYPE_STEP_COUNTER` (累计步数，做 baseline 归零)
- **权限**: `android.permission.ACTIVITY_RECOGNITION` (Android 10+)
- **依赖**: `androidx.core:core-ktx:1.13.1`

### Plugin 接口
| 方法 | 说明 |
|------|------|
| `getSteps()` | 获取当前会话步数 |
| `hasActivityRecognitionPermission()` | 检查权限状态 |
| `requestActivityRecognitionPermission()` | 请求权限 |

| 信号 | 参数 | 说明 |
|------|------|------|
| `steps_changed` | int | 步数更新时触发 |
| `permission_result` | bool | 权限请求结果 |

### 构建
- **SDK**: compileSdk 36, minSdk 24, targetSdk 36
- **NDK**: 29.0.14206865
- **Arch**: arm64-v8a

## CI/CD

推送到 `godot-prototype` 分支自动触发 GitHub Actions 构建 APK。
APK 作为 artifact 可从 Actions 页面下载。

## 本地开发

```bash
# 用 Godot Editor 打开项目
/usr/local/bin/godot --path /home/agentuser/catwalk_godot -e

# 命令行导出（需要 Android SDK）
ANDROID_HOME=/path/to/sdk godot --headless --path . --export-debug "Android Debug" out.apk
```
