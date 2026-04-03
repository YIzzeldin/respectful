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
    private val GEO_REENTRY_PROBATION_MS = 2 * 60 * 1000L
    private lateinit var volumeService: VolumeControlService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeService = VolumeControlService(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "captureCurrentState" -> {
                    result.success(volumeService.captureCurrentState())
                }

                "applySilence" -> {
                    result.success(volumeService.applySilence())
                }

                "restoreState" -> {
                    @Suppress("UNCHECKED_CAST")
                    val state = call.arguments as? Map<String, Any>
                    if (state != null) {
                        result.success(volumeService.restoreState(state))
                    } else {
                        result.error("INVALID_ARGS", "State map is required", null)
                    }
                }

                "hasDndPermission" -> {
                    result.success(volumeService.hasDndPermission())
                }

                "openDndSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                    result.success(true)
                }

                "hasExactAlarmPermission" -> {
                    result.success(volumeService.hasExactAlarmPermission())
                }

                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
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
                    val triggerAtMs = (call.argument<Number>("triggerAtMs"))?.toLong() ?: 0L
                    val prayerName = call.argument<String>("prayerName") ?: "test"
                    val windowEndMs = (call.argument<Number>("windowEndMs"))?.toLong() ?: 0L
                    val requestCode = (call.argument<Number>("requestCode"))?.toInt() ?: 1000

                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    prefs.edit().putLong("window_end_ms", windowEndMs).commit()

                    AlarmScheduler.scheduleSilenceAlarm(this, triggerAtMs, prayerName, windowEndMs, requestCode)
                    result.success(true)
                }

                "scheduleRestoreAlarm" -> {
                    val triggerAtMs = (call.argument<Number>("triggerAtMs"))?.toLong() ?: 0L
                    val requestCode = (call.argument<Number>("requestCode"))?.toInt() ?: 2000

                    AlarmScheduler.scheduleRestoreAlarm(this, triggerAtMs, requestCode)
                    AlarmScheduler.scheduleSafetyRestoreAlarm(this, triggerAtMs + 5 * 60 * 1000)
                    result.success(true)
                }

                "cancelAllAlarms" -> {
                    AlarmScheduler.cancelAllAlarms(this)
                    result.success(true)
                }

                "disableTimeBasedSilence" -> {
                    AlarmScheduler.cancelAllAlarms(this)
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val isPrayerActive = prefs.getBoolean("is_silenced", false)
                    val isGeoActive = prefs.getBoolean("geo_silenced", false)

                    if (isPrayerActive && !isGeoActive) {
                        val restored = SuppressionSessionStore.restoreBaseline(
                            this,
                            prefs,
                            volumeService,
                        )
                        if (!restored) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                    }

                    SuppressionSessionStore.clearPrayerSession(prefs)
                    SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
                    result.success(true)
                }

                "applySilenceForPrayerWindow" -> {
                    val prayerName = call.argument<String>("prayerName") ?: "unknown"
                    val windowEndMs = (call.argument<Number>("windowEndMs"))?.toLong() ?: 0L
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val isPrayerSilenced = prefs.getBoolean("is_silenced", false)
                    val isGeoSilenced = prefs.getBoolean("geo_silenced", false)

                    val success = when {
                        isPrayerSilenced -> true
                        isGeoSilenced -> true
                        else -> {
                            SuppressionSessionStore.captureBaselineIfNeeded(this, prefs, volumeService)
                            volumeService.applySilence()
                        }
                    }

                    if (success) {
                        prefs.edit()
                            .putBoolean("is_silenced", true)
                            .putBoolean("user_overridden", false)
                            .putString("current_prayer", prayerName)
                            .putLong("silenced_at", System.currentTimeMillis())
                            .putLong("window_end_ms", windowEndMs)
                            .commit()
                    }

                    result.success(success)
                }

                "openBatterySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    } catch (_: Exception) {
                        startActivity(Intent(Settings.ACTION_SETTINGS))
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
                        this,
                        masjids,
                        onSuccess = { result.success(true) },
                        onFailure = { result.success(false) },
                    )
                }

                "removeAllGeofences" -> {
                    GeofenceManager.removeAllGeofences(
                        this,
                        onComplete = {
                            val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                            SuppressionSessionStore.clearGeoSession(prefs)
                            SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
                            GeoExitTrackingCoordinator.sync(this)
                            result.success(true)
                        },
                    )
                }

                "disableGeofenceSilence" -> {
                    GeofenceManager.removeAllGeofences(
                        this,
                        onComplete = {
                            val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                            val isPrayerActive = prefs.getBoolean("is_silenced", false)
                            val isGeoActive = prefs.getBoolean("geo_silenced", false)
                            val restored = if (isGeoActive && !isPrayerActive) {
                                SuppressionSessionStore.restoreBaseline(
                                    this,
                                    prefs,
                                    volumeService,
                                )
                            } else {
                                true
                            }

                            if (!restored) {
                                result.success(false)
                            } else {
                                SuppressionSessionStore.clearGeoSession(prefs)
                                SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
                                GeoExitTrackingCoordinator.sync(this)
                                result.success(true)
                            }
                        },
                    )
                }

                "removeGeofencesOnly" -> {
                    GeofenceManager.removeAllGeofences(
                        this,
                        onComplete = { result.success(true) },
                    )
                }

                "hasBackgroundLocationPermission" -> {
                    val granted = androidx.core.content.ContextCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }

                "applySilenceForGeo" -> {
                    val masjidId = call.argument<String>("masjidId")
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val alreadyGeo = prefs.getBoolean("geo_silenced", false)
                    val isPrayerSilenced = prefs.getBoolean("is_silenced", false)
                    val geoVisitOverrideActive = SuppressionSessionStore.isGeoVisitOverrideActive(prefs)

                    val activeMasjids = prefs.getStringSet("active_masjid_geofences", mutableSetOf())
                        ?.toMutableSet()
                        ?: mutableSetOf()
                    if (masjidId != null) {
                        activeMasjids.add(masjidId)
                    }

                    if (geoVisitOverrideActive) {
                        prefs.edit()
                            .putStringSet("active_masjid_geofences", activeMasjids)
                            .commit()
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    val success = when {
                        alreadyGeo -> true
                        isPrayerSilenced -> true
                        else -> {
                            SuppressionSessionStore.captureBaselineIfNeeded(this, prefs, volumeService)
                            volumeService.applySilence()
                        }
                    }

                    if (success) {
                        prefs.edit()
                            .putBoolean("geo_silenced", true)
                            .putLong("geo_silenced_at", System.currentTimeMillis())
                            .putStringSet("active_masjid_geofences", activeMasjids)
                            .commit()
                        GeoExitTrackingCoordinator.sync(this)
                    }
                    result.success(success)
                }

                "clearGeoSilenceForMasjid" -> {
                    val masjidId = call.argument<String>("masjidId") ?: ""
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val wasGeoSilenced = prefs.getBoolean("geo_silenced", false)
                    val geoVisitOverrideActive = SuppressionSessionStore.isGeoVisitOverrideActive(prefs)

                    if (!wasGeoSilenced && !geoVisitOverrideActive) {
                        result.success("not_silenced")
                        return@setMethodCallHandler
                    }

                    val activeMasjids = prefs.getStringSet("active_masjid_geofences", mutableSetOf())
                        ?.toMutableSet()
                        ?: mutableSetOf()

                    if (activeMasjids.isEmpty()) {
                        Log.d("Respectful", "Active set empty but geo session exists on delete of $masjidId")
                    } else {
                        val wasInSet = activeMasjids.remove(masjidId)
                        if (!wasInSet) {
                            result.success("not_at_deleted")
                            return@setMethodCallHandler
                        }
                    }

                    if (activeMasjids.isNotEmpty()) {
                        prefs.edit()
                            .putStringSet("active_masjid_geofences", activeMasjids)
                            .commit()
                        GeoExitTrackingCoordinator.sync(this)
                        result.success("still_at_other")
                        return@setMethodCallHandler
                    }

                    val isPrayerActive = prefs.getBoolean("is_silenced", false)
                    if (geoVisitOverrideActive) {
                        SuppressionSessionStore.clearGeoSession(prefs)
                        SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
                        Log.d("Respectful", "Deleted active masjid $masjidId — cleared geo override")
                    } else if (!isPrayerActive) {
                        val restored = SuppressionSessionStore.restoreBaseline(
                            this,
                            prefs,
                            volumeService,
                        )
                        if (!restored) {
                            result.success("not_silenced")
                            return@setMethodCallHandler
                        }
                        SuppressionSessionStore.clearGeoSession(prefs)
                        SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
                        Log.d("Respectful", "Deleted active masjid $masjidId — restored phone")
                    } else {
                        SuppressionSessionStore.clearGeoSession(prefs)
                        Log.d("Respectful", "Deleted active masjid $masjidId — prayer active, keeping silent")
                    }
                    GeoExitTrackingCoordinator.sync(this)
                    result.success("restored")
                }

                "clearGeoSilence" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val isPrayerActive = prefs.getBoolean("is_silenced", false)

                    if (isPrayerActive) {
                        SuppressionSessionStore.clearGeoSession(prefs)
                        Log.d("Respectful", "Cleared geo state, prayer still active — staying silent")
                    } else {
                        val restored = SuppressionSessionStore.restoreBaseline(
                            this,
                            prefs,
                            volumeService,
                        )
                        if (!restored) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        SuppressionSessionStore.clearGeoSession(prefs)
                        SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
                        Log.d("Respectful", "Cleared geo state and restored phone")
                    }
                    SuppressionSessionStore.setGeoReentryProbationUntil(
                        prefs,
                        System.currentTimeMillis() + GEO_REENTRY_PROBATION_MS,
                    )
                    GeoExitTrackingCoordinator.sync(this)
                    result.success(true)
                }

                "manualExitSilenceMode" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val isPrayerActive = prefs.getBoolean("is_silenced", false)
                    val isGeoActive = prefs.getBoolean("geo_silenced", false)

                    if (!isPrayerActive && !isGeoActive) {
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    val restored = SuppressionSessionStore.restoreBaseline(
                        this,
                        prefs,
                        volumeService,
                    )
                    if (!restored) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    if (isPrayerActive) {
                        SuppressionSessionStore.clearPrayerSession(
                            prefs,
                            preserveOverride = true,
                        )
                    }
                    if (isGeoActive) {
                        SuppressionSessionStore.markGeoVisitOverridden(prefs)
                    }
                    SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
                    GeoExitTrackingCoordinator.sync(this)
                    result.success(true)
                }

                "clearManualOverrides" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    prefs.edit()
                        .putBoolean("user_overridden", false)
                        .putBoolean("geo_visit_override_active", false)
                        .remove("geo_reentry_probation_until_ms")
                        .commit()
                    result.success(true)
                }

                "clearPrayerOverride" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    prefs.edit()
                        .putBoolean("user_overridden", false)
                        .commit()
                    result.success(true)
                }

                "clearGeoOverride" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    prefs.edit()
                        .putBoolean("geo_visit_override_active", false)
                        .remove("geo_reentry_probation_until_ms")
                        .commit()
                    result.success(true)
                }

                "forceRestoreNormal" -> {
                    val notificationManager = getSystemService(android.app.NotificationManager::class.java)
                    val audioManager =
                        getSystemService(android.media.AudioManager::class.java) as android.media.AudioManager

                    try {
                        notificationManager.setInterruptionFilter(
                            android.app.NotificationManager.INTERRUPTION_FILTER_ALL,
                        )
                        audioManager.ringerMode = android.media.AudioManager.RINGER_MODE_NORMAL

                        val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                        prefs.edit()
                            .putBoolean("is_silenced", false)
                            .putBoolean("geo_silenced", false)
                            .putBoolean("user_overridden", false)
                            .putBoolean("geo_visit_override_active", false)
                            .remove("active_masjid_geofences")
                            .remove("current_prayer")
                            .remove("silenced_at")
                            .remove("window_end_ms")
                            .remove("geo_silenced_at")
                            .remove("geo_reentry_probation_until_ms")
                            .remove("saved_ringer_mode")
                            .remove("saved_interruption_filter")
                            .remove("saved_ring_volume")
                            .remove("saved_notification_volume")
                            .remove("saved_alarm_volume")
                            .remove("saved_media_volume")
                            .remove("saved_captured_at")
                            .remove("saved_change_token")
                            .remove("geo_saved_ringer_mode")
                            .remove("geo_saved_interruption_filter")
                            .remove("geo_saved_ring_volume")
                            .remove("geo_saved_notification_volume")
                            .commit()
                        SuppressionSessionStore.clearBaseline(prefs)
                        GeoExitTrackingCoordinator.sync(this)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                "readNativeEvents" -> {
                    result.success(NativeEventLog.readAndClear(this))
                }

                "getSuppressionState" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val activeMasjidIds = prefs.getStringSet("active_masjid_geofences", emptySet())
                        ?.toList()
                        ?: emptyList()
                    result.success(
                        mapOf(
                            "isPrayerSilenced" to prefs.getBoolean("is_silenced", false),
                            "isGeoSilenced" to prefs.getBoolean("geo_silenced", false),
                            "currentPrayer" to prefs.getString("current_prayer", null),
                            "prayerWindowEndMs" to prefs.getLong("window_end_ms", 0),
                            "prayerSilencedAtMs" to prefs.getLong("silenced_at", 0),
                            "geoSilencedAtMs" to prefs.getLong("geo_silenced_at", 0),
                            "userOverridden" to prefs.getBoolean("user_overridden", false),
                            "geoVisitOverrideActive" to SuppressionSessionStore.isGeoVisitOverrideActive(prefs),
                            "geoReentryProbationUntilMs" to SuppressionSessionStore.getGeoReentryProbationUntil(prefs),
                            "activeMasjidIds" to activeMasjidIds,
                        ),
                    )
                }

                "isGeoSilenced" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    result.success(prefs.getBoolean("geo_silenced", false))
                }

                "getGeoSilencedAt" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    result.success(prefs.getLong("geo_silenced_at", 0))
                }

                "getActiveMasjidGeofences" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, MODE_PRIVATE)
                    val set = prefs.getStringSet("active_masjid_geofences", emptySet()) ?: emptySet()
                    result.success(set.toList())
                }

                "syncGeoExitTracking" -> {
                    GeoExitTrackingCoordinator.sync(this)
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
