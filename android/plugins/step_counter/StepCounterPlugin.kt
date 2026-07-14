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
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.LocalDate
import java.time.ZoneId
import java.time.Instant
import android.os.Handler
import android.os.Looper
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class StepCounterPlugin(godot: Godot) : GodotPlugin(godot), SensorEventListener {

    private val stepsChangedSignal = SignalInfo("steps_changed", Integer::class.java)
    private val permissionResultSignal = SignalInfo("permission_result", java.lang.Boolean::class.java)
    private val healthConnectStepsSignal = SignalInfo("health_connect_steps", Integer::class.java)

    private val sensorManager by lazy {
        activity?.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    }

    // Health Connect 日桶步数数据源（与 TYPE_STEP_COUNTER 互补，不替代硬件传感器读取）。
    private var healthConnectClient: HealthConnectClient? = null
    private var healthConnectTodaySteps: Int = -1  // -1 = not available / not yet read

    // 硬件累计步数（TYPE_STEP_COUNTER：自设备开机以来的总步数）。
    // -1 表示尚未拿到任何传感器读数 —— 此时 getSteps() 返回 -1，
    // Godot 侧 StepEngine 会跳过，避免把"还没读到"误判为设备重启。
    private var rawSensorSteps = -1

    override fun getPluginName() = "StepCounter"

    override fun getPluginSignals() = setOf(stepsChangedSignal, permissionResultSignal, healthConnectStepsSignal)

    override fun onGodotMainLoopStarted() {
        super.onGodotMainLoopStarted()
        if (hasActivityRecognitionPermission()) {
            startStepCounter()
        }

        // 尝试初始化 Health Connect
        try {
            healthConnectClient = HealthConnectClient.getOrCreate(activity!!)
            readHealthConnectTodaySteps()
        } catch (e: Exception) {
            // Health Connect not available — silently fall back to TYPE_STEP_COUNTER
            healthConnectTodaySteps = -1
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
        if (requestCode == ACTIVITY_RECOGNITION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            emitSignal(permissionResultSignal, java.lang.Boolean(granted))
            if (granted) startStepCounter()
            return
        }
        if (requestCode == HEALTH_CONNECT_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted) {
                readHealthConnectTodaySteps()
            }
            return
        }
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

    private fun readHealthConnectTodaySteps() {
        Thread {
            try {
                val client = healthConnectClient ?: return@Thread
                val permissions = setOf(
                    HealthPermission.getReadPermission(StepsRecord::class)
                )

                // Check if we have permission
                val grantedPermissions = client.permissionController.getGrantedPermissions()
                if (!grantedPermissions.containsAll(permissions)) {
                    healthConnectTodaySteps = -1
                    return@Thread
                }

                val today = LocalDate.now()
                val zoneId = ZoneId.systemDefault()
                val startOfDay = today.atStartOfDay(zoneId).toInstant()
                val endOfDay = today.plusDays(1).atStartOfDay(zoneId).toInstant()

                val request = AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(startOfDay, endOfDay)
                )

                val response = client.aggregate(request)
                val steps = response[StepsRecord.COUNT_TOTAL] ?: 0
                healthConnectTodaySteps = steps.toInt().coerceAtLeast(0)

                Handler(Looper.getMainLooper()).post {
                    emitSignal(healthConnectStepsSignal, Integer(healthConnectTodaySteps))
                }
            } catch (e: Exception) {
                healthConnectTodaySteps = -1
            }
        }.start()
    }

    @UsedByGodot
    fun getHealthConnectTodaySteps(): Int = healthConnectTodaySteps

    @UsedByGodot
    fun isHealthConnectAvailable(): Boolean = healthConnectClient != null

    @UsedByGodot
    fun requestHealthConnectPermission() {
        if (healthConnectClient == null) return
        // Health Connect runtime permission is requested via system health permissions.
        // On Android 14+, HEALTH_READ_STEPS is part of the normal permission system.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val hostActivity = activity ?: return
            ActivityCompat.requestPermissions(
                hostActivity,
                arrayOf("android.permission.health.READ_STEPS"),
                HEALTH_CONNECT_REQUEST_CODE
            )
        } else {
            // Pre-Android 14: Health Connect uses its own permission flow
            // which requires ActivityResultContract — not supported in GodotPlugin.
            // Fall back to TYPE_STEP_COUNTER only.
            healthConnectTodaySteps = -1
        }
    }

    companion object {
        private const val ACTIVITY_RECOGNITION_REQUEST_CODE = 2101
        private const val HEALTH_CONNECT_REQUEST_CODE = 2103
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
