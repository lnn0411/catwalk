package com.catwalk.stepcounter

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
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
        // 不移除：TYPE_STEP_COUNTER 是硬件级低功耗传感器，
        // 硬件层继续累计，亮屏后读数直接恢复。
        // sensorManager?.unregisterListener(this)
    }

    override fun onMainResume() {
        super.onMainResume()
        if (hasActivityRecognitionPermission()) {
            startStepCounter()
        }
    }

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

    @UsedByGodot
    fun shouldShowRequestPermissionRationale(): Boolean {
        val hostActivity = activity ?: return true
        return ActivityCompat.shouldShowRequestPermissionRationale(
            hostActivity,
            Manifest.permission.ACTIVITY_RECOGNITION
        )
    }

    @UsedByGodot
    fun openAppSettings() {
        val hostActivity = activity ?: return
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = Uri.parse("package:" + hostActivity.packageName)
        hostActivity.startActivity(intent)
    }
}
