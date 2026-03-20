package com.respectful.respectful

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
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
                "openBatterySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                    } catch (e: Exception) {
                        val intent = Intent(Settings.ACTION_SETTINGS)
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "registerGeofences" -> {
                    @Suppress("UNCHECKED_CAST")
                    val masjidsRaw = call.argument<List<Map<String, Any>>>("masjids") ?: emptyList()
                    val masjids = masjidsRaw.map { m ->
                        MasjidLocation(
                            id = m["id"] as String,
                            name = m["name"] as String,
                            latitude = (m["latitude"] as Number).toDouble(),
                            longitude = (m["longitude"] as Number).toDouble(),
                        )
                    }
                    GeofenceManager.registerGeofences(
                        this, masjids,
                        onSuccess = { result.success(true) },
                        onFailure = { error -> result.success(false) },
                    )
                }
                "removeAllGeofences" -> {
                    GeofenceManager.removeAllGeofences(this,
                        onComplete = {
                            // Also clear geo state from SharedPreferences
                            val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                            prefs.edit()
                                .putBoolean("geo_silenced", false)
                                .remove("active_masjid_geofences")
                                .remove("geo_saved_ringer_mode")
                                .remove("geo_saved_interruption_filter")
                                .remove("geo_saved_ring_volume")
                                .remove("geo_saved_notification_volume")
                                .commit()
                            result.success(true)
                        }
                    )
                }
                "hasBackgroundLocationPermission" -> {
                    val granted = androidx.core.content.ContextCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "applySilenceForGeo" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val alreadyGeo = prefs.getBoolean("geo_silenced", false)
                    val isPrayerSilenced = prefs.getBoolean("is_silenced", false)

                    // Only capture geo snapshot if nothing is currently silencing.
                    // If prayer is active, the phone is already silenced — capturing
                    // now would store a silenced state as the "restore" target.
                    // Same guard as GeofenceReceiver.handleEnterMasjid.
                    if (!alreadyGeo && !isPrayerSilenced) {
                        val state = volumeService.captureCurrentState()
                        prefs.edit()
                            .putInt("geo_saved_ringer_mode", state["ringerMode"] as Int)
                            .putInt("geo_saved_interruption_filter", state["interruptionFilter"] as Int)
                            .putInt("geo_saved_ring_volume", state["ringVolume"] as Int)
                            .putInt("geo_saved_notification_volume", state["notificationVolume"] as Int)
                            .commit()
                    }

                    val success = volumeService.applySilence()
                    if (success) {
                        prefs.edit().putBoolean("geo_silenced", true).commit()
                    }
                    result.success(success)
                }
                "clearGeoSilence" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val isPrayerActive = prefs.getBoolean("is_silenced", false)

                    if (isPrayerActive) {
                        // Prayer is active — just clear geo flags, keep phone silent
                        prefs.edit()
                            .putBoolean("geo_silenced", false)
                            .remove("active_masjid_geofences")
                            .remove("geo_saved_ringer_mode")
                            .remove("geo_saved_interruption_filter")
                            .remove("geo_saved_ring_volume")
                            .remove("geo_saved_notification_volume")
                            .commit()
                        Log.d("Respectful", "Cleared geo state, prayer still active — staying silent")
                    } else {
                        // Nothing else keeping it silent — restore from geo snapshot
                        val savedState = mapOf(
                            "ringerMode" to prefs.getInt("geo_saved_ringer_mode", android.media.AudioManager.RINGER_MODE_NORMAL),
                            "interruptionFilter" to prefs.getInt("geo_saved_interruption_filter", android.app.NotificationManager.INTERRUPTION_FILTER_ALL),
                            "ringVolume" to prefs.getInt("geo_saved_ring_volume", 5),
                            "notificationVolume" to prefs.getInt("geo_saved_notification_volume", 5)
                        )
                        volumeService.restoreState(savedState)
                        prefs.edit()
                            .putBoolean("geo_silenced", false)
                            .remove("active_masjid_geofences")
                            .remove("geo_saved_ringer_mode")
                            .remove("geo_saved_interruption_filter")
                            .remove("geo_saved_ring_volume")
                            .remove("geo_saved_notification_volume")
                            .commit()
                        Log.d("Respectful", "Cleared geo state and restored phone")
                    }
                    result.success(true)
                }
                "forceRestoreNormal" -> {
                    val nm = getSystemService(android.app.NotificationManager::class.java)
                    val am = getSystemService(android.media.AudioManager::class.java) as android.media.AudioManager
                    try {
                        // Set DND to ALL (normal — allow everything)
                        nm.setInterruptionFilter(android.app.NotificationManager.INTERRUPTION_FILTER_ALL)
                        // Set ringer to NORMAL
                        am.ringerMode = android.media.AudioManager.RINGER_MODE_NORMAL
                        // Clear all silence state
                        val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                        prefs.edit()
                            .putBoolean("is_silenced", false)
                            .putBoolean("geo_silenced", false)
                            .putBoolean("user_overridden", false)
                            .remove("active_masjid_geofences")
                            .remove("current_prayer")
                            .remove("silenced_at")
                            .remove("window_end_ms")
                            .remove("saved_ringer_mode")
                            .remove("saved_interruption_filter")
                            .remove("saved_ring_volume")
                            .remove("saved_notification_volume")
                            .remove("geo_saved_ringer_mode")
                            .remove("geo_saved_interruption_filter")
                            .remove("geo_saved_ring_volume")
                            .remove("geo_saved_notification_volume")
                            .commit()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "readNativeEvents" -> {
                    val events = NativeEventLog.readAndClear(this)
                    result.success(events)
                }
                "isGeoSilenced" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    result.success(prefs.getBoolean("geo_silenced", false))
                }
                "getActiveMasjidGeofences" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val set = prefs.getStringSet("active_masjid_geofences", emptySet()) ?: emptySet()
                    result.success(set.toList())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
