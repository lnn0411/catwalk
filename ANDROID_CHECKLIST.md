# Android Build 重建 Checklist

删除 `android/build/` 后必须按顺序执行：

1. **复制插件源码**
   ```powershell
   New-Item -ItemType Directory -Force -Path android\build\src\main\java\com\catwalk\stepcounter
   Copy-Item android\plugins\step_counter\StepCounterPlugin.kt android\build\src\main\java\com\catwalk\stepcounter\
   ```

2. **确认 AndroidManifest.xml 有 v2 插件 meta-data**
   ```xml
   <meta-data
       android:name="org.godotengine.plugin.v2.StepCounter"
       android:value="com.catwalk.stepcounter.StepCounterPlugin" />
   ```

3. **确认 local.properties 有 sdk.dir**（或设 ANDROID_HOME 环境变量）
   ```
   sdk.dir=C\:\\android-sdk
   ```

4. **确认 gradle.properties 有**
   ```
   android.suppressUnsupportedCompileSdk=36
   ```

5. **Export settings**
   - 只勾 arm64-v8a（除非要兼容 32 位老手机）
   - Debug 测试 / Release 上线

## 常见报错速查

| 报错 | 原因 | 解决 |
|------|------|------|
| plugin only available on android | 缺少 meta-data 注册 | 见步骤 2 |
| configuration errors (空) | headless Godot 限制 | GUI 模式导出 |
| cannot connect to daemon tcp:5037 | adb 未运行（导出时不影响） | 忽略 |
| APK 150MB+ | 多架构 + 含 AAR | 只勾 arm64-v8a + 删 build/libs/ |
