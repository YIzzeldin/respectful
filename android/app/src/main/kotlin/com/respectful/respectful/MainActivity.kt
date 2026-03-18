package com.respectful.respectful

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.respectful/volume_control"
    private lateinit var volumeService: VolumeControlService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeService = VolumeControlService(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "captureCurrentState" -> {
                    val state = volumeService.captureCurrentState()
                    result.success(state)
                }
                "applySilence" -> {
                    val success = volumeService.applySilence()
                    result.success(success)
                }
                "applyPrioritySilence" -> {
                    val success = volumeService.applyPrioritySilence()
                    result.success(success)
                }
                "restoreState" -> {
                    @Suppress("UNCHECKED_CAST")
                    val state = call.arguments as? Map<String, Any>
                    if (state != null) {
                        val success = volumeService.restoreState(state)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "State map is required", null)
                    }
                }
                "hasDndPermission" -> {
                    result.success(volumeService.hasDndPermission())
                }
                "openDndSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "hasExactAlarmPermission" -> {
                    result.success(volumeService.hasExactAlarmPermission())
                }
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "getCurrentRingerMode" -> {
                    result.success(volumeService.getCurrentRingerMode())
                }
                "getCurrentInterruptionFilter" -> {
                    result.success(volumeService.getCurrentInterruptionFilter())
                }
                "scheduleSilenceAlarm" -> {
                    val triggerAtMs = (call.argument<Number>("triggerAtMs"))?.toLong() ?: 0
                    val prayerName = call.argument<String>("prayerName") ?: "test"
                    val windowEndMs = (call.argument<Number>("windowEndMs"))?.toLong() ?: 0
                    val requestCode = (call.argument<Number>("requestCode"))?.toInt() ?: 1000

                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    prefs.edit().putLong("window_end_ms", windowEndMs).apply()

                    AlarmScheduler.scheduleSilenceAlarm(this, triggerAtMs, prayerName, windowEndMs, requestCode)
                    result.success(true)
                }
                "scheduleRestoreAlarm" -> {
                    val triggerAtMs = (call.argument<Number>("triggerAtMs"))?.toLong() ?: 0
                    val requestCode = (call.argument<Number>("requestCode"))?.toInt() ?: 2000

                    AlarmScheduler.scheduleRestoreAlarm(this, triggerAtMs, requestCode)
                    AlarmScheduler.scheduleSafetyRestoreAlarm(this, triggerAtMs + 5 * 60 * 1000)
                    result.success(true)
                }
                "cancelAllAlarms" -> {
                    AlarmScheduler.cancelAllAlarms(this)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
