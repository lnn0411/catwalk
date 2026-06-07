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
	private val stepsChangedSignal = SignalInfo("steps_changed", java.lang.Integer::class.java)
	private val permissionResultSignal = SignalInfo("permission_result", java.lang.Boolean::class.java)
	private val sensorManager by lazy {
		activity?.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
	}

	private var initialSensorSteps: Float? = null
	private var currentSteps = 0

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
		sensorManager?.unregisterListener(this)
	}

	override fun onMainResume() {
		super.onMainResume()
		if (hasActivityRecognitionPermission()) {
			startStepCounter()
		}
	}

	@UsedByGodot
	fun getSteps() = currentSteps

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
		if (requestCode != ACTIVITY_RECOGNITION_REQUEST_CODE) {
			return
		}
		val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
		emitSignal(permissionResultSignal, java.lang.Boolean(granted))
		if (granted) {
			startStepCounter()
		}
	}

	override fun onSensorChanged(event: SensorEvent) {
		val firstReading = initialSensorSteps
		if (firstReading == null) {
			initialSensorSteps = event.values[0]
			currentSteps = 0
		} else {
			currentSteps = (event.values[0] - firstReading).toInt().coerceAtLeast(0)
		}
		emitSignal(stepsChangedSignal, java.lang.Integer(currentSteps))
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
