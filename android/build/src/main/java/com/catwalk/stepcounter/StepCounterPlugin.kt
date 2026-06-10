package com.catwalk.stepcounter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class StepCounterPlugin(godot: Godot) : GodotPlugin(godot), SensorEventListener {

    private val stepsChangedSignal = SignalInfo("steps_changed", Integer::class.java)
    private val permissionResultSignal = SignalInfo("permission_result", java.lang.Boolean::class.java)

    private val sensorManager by lazy {
        activity?.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    }

    // 硬件累计步数（TYPE_STEP_COUNTER：自设备开机以来的总步数）。
    // -1 表示尚未拿到任何传感器读数 —— 此时 getSteps() 返回 -1，
    // Godot 侧 StepEngine 会跳过，避免把"还没读到"误判为设备重启。
    // 不要在这里维护"本次会话基准/增量"，否则进程被杀重启后基准重置，
    // 进程死亡期间走的步会被吸收进新基准而丢失（这是原实现的 bug）。
    private var rawSensorSteps = -1

    override fun getPluginName() = "StepCounter"

    override fun getPluginSignals() = setOf(stepsChangedSignal, permissionResultSignal)

    override fun onGodotMainLoopStarted() {
        super.onGodotMainLoopStarted()
        if (hasActivityRecognitionPermission()) {
            startStepCounter()
        }
    }

    override fun onMainPause() {
        super.onMainPause()
        // 退后台时注销监听省电；硬件计步器仍在固件层继续累计，
        // 回前台重新注册后第一帧读数即为最新累计值，不会丢步。
        sensorManager?.unregisterListener(this)
    }

    override fun onMainResume() {
        super.onMainResume()
        if (hasActivityRecognitionPermission()) {
            startStepCounter()
        }
    }

    // 返回硬件累计步数（自开机）。-1 = 尚无读数。
    // 差值与每日重置由 Godot 侧 StepEngine 负责。
    @UsedByGodot
    fun getSteps() = rawSensorSteps

    @UsedByGodot
    fun hasActivityRecognitionPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return true
        }
        val hostActivity = activity ?: return false
        return ContextCompat.checkSelfPermission(
            hostActivity,
            Manifest.permission.ACTIVITY_RECOGNITION
        ) == PackageManager.PERMISSION_GRANTED
    }

    @UsedByGodot
    fun requestActivityRecognitionPermission() {
        val hostActivity = activity ?: return
        if (hasActivityRecognitionPermission()) {
            emitSignal(permissionResultSignal, java.lang.Boolean(true))
            startStepCounter()
            return
        }
        ActivityCompat.requestPermissions(
            hostActivity,
            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            ACTIVITY_RECOGNITION_REQUEST_CODE
        )
    }

    override fun onMainRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        if (requestCode != ACTIVITY_RECOGNITION_REQUEST_CODE) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        emitSignal(permissionResultSignal, java.lang.Boolean(granted))
        if (granted) startStepCounter()
    }

    override fun onSensorChanged(event: SensorEvent) {
        // event.values[0] = 自设备开机以来的累计步数（Float，硬件维护，进程死了也照常累加）。
        // 直接透传，由 StepEngine 做差值/重启判断。
        rawSensorSteps = event.values[0].toInt().coerceAtLeast(0)
        emitSignal(stepsChangedSignal, Integer(rawSensorSteps))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun startStepCounter() {
        val sensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return
        sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    companion object {
        private const val ACTIVITY_RECOGNITION_REQUEST_CODE = 2101
    }
}
