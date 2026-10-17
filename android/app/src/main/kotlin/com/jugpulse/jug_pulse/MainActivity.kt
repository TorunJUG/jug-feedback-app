package com.feedbackapp.feedback_app

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private val channelName = "com.feedbackapp.feedback_app/kiosk"
    private val shakeChannelName = "com.feedbackapp.feedback_app/kiosk_shake"
    private var shakeEventSink: EventChannel.EventSink? = null
    private var accelerometer: Sensor? = null
    private var lastShakeAt = 0L

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDeviceOwner" -> result.success(isDeviceOwner())
                    "isLockTaskActive" -> result.success(isLockTaskActive())
                    "isScreenPinningActive" -> result.success(isScreenPinningActive())
                    "enableLockTask" -> result.success(enableLockTask())
                    "disableLockTask" -> result.success(disableLockTask())
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, shakeChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shakeEventSink = events
                    updateShakeDetection()
                }

                override fun onCancel(arguments: Any?) {
                    shakeEventSink = null
                    stopShakeDetection()
                }
            })
    }

    override fun onResume() {
        super.onResume()
        updateShakeDetection()
    }

    override fun onPause() {
        stopShakeDetection()
        super.onPause()
    }

    private fun updateShakeDetection() {
        val lockTaskActive = isDeviceOwner() && isLockTaskActive()
        if (!lockTaskActive) {
            stopShakeDetection()
            return
        }
        if (accelerometer != null) return
        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        accelerometer?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    private fun stopShakeDetection() {
        accelerometer?.let { sensor ->
            (getSystemService(Context.SENSOR_SERVICE) as SensorManager)
                .unregisterListener(this, sensor)
        }
        accelerometer = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_ACCELEROMETER || shakeEventSink == null) return
        if (!isDeviceOwner() || !isLockTaskActive()) {
            stopShakeDetection()
            return
        }
        val x = event.values[0] / SensorManager.GRAVITY_EARTH
        val y = event.values[1] / SensorManager.GRAVITY_EARTH
        val z = event.values[2] / SensorManager.GRAVITY_EARTH
        val acceleration = kotlin.math.sqrt(x * x + y * y + z * z)
        val now = System.currentTimeMillis()
        if (acceleration > 2.7f && now - lastShakeAt > 2500) {
            lastShakeAt = now
            shakeEventSink?.success(now)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun isDeviceOwner(): Boolean {
        val policy = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return policy.isDeviceOwnerApp(packageName)
    }

    private fun isLockTaskActive(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return activityManager.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_LOCKED
    }

    private fun isScreenPinningActive(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return activityManager.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_PINNED
    }

    private fun enableLockTask(): Boolean {
        if (!isDeviceOwner()) return false
        if (isScreenPinningActive()) return false
        return try {
            val policy = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val admin = ComponentName(this, FeedbackDeviceAdminReceiver::class.java)
            policy.setLockTaskPackages(admin, arrayOf(packageName))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                policy.setLockTaskFeatures(
                    admin,
                    DevicePolicyManager.LOCK_TASK_FEATURE_NONE,
                )
            }
            startLockTask()
            updateShakeDetection()
            true
        } catch (_: SecurityException) {
            false
        }
    }

    private fun disableLockTask(): Boolean {
        if (!isDeviceOwner()) return false
        if (!isLockTaskActive()) return false
        return try {
            stopLockTask()
            stopShakeDetection()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val policy = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                val admin = ComponentName(this, FeedbackDeviceAdminReceiver::class.java)
                policy.setLockTaskFeatures(
                    admin,
                    DevicePolicyManager.LOCK_TASK_FEATURE_HOME or
                        DevicePolicyManager.LOCK_TASK_FEATURE_OVERVIEW or
                        DevicePolicyManager.LOCK_TASK_FEATURE_NOTIFICATIONS or
                        DevicePolicyManager.LOCK_TASK_FEATURE_SYSTEM_INFO,
                )
            }
            // Keep this app allowlisted so leaving Lock Task returns to the
            // organizer screen instead of terminating the kiosk task.
            true
        } catch (_: SecurityException) {
            false
        }
    }
}
