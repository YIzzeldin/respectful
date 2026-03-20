package com.respectful.respectful

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles device boot — checks for stale silence state, reschedules alarms,
 * and re-registers geofences (which are cleared by the OS on reboot).
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "RespectfulBoot"
        const val MASJID_PREFS_NAME = "FlutterSharedPreferences"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        Log.d(TAG, "Boot completed — checking silence state + re-registering geofences")

        handleSilenceRecovery(context)
        handleGeofenceReregistration(context)

        Log.d(TAG, "Boot recovery complete")
    }

    private fun handleSilenceRecovery(context: Context) {
        val prefs = context.getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val isSilenced = prefs.getBoolean("is_silenced", false)
        val isGeoSilenced = prefs.getBoolean("geo_silenced", false)

        if (isSilenced) {
            val windowEndMs = prefs.getLong("window_end_ms", 0)

            if (windowEndMs > 0 && System.currentTimeMillis() > windowEndMs) {
                // Prayer window expired — but check if geo is also active
                if (isGeoSilenced) {
                    // Geo still active — just clear prayer state, stay silent
                    Log.d(TAG, "Prayer expired but geo still active — clearing prayer only")
                    prefs.edit()
                        .putBoolean("is_silenced", false)
                        .remove("current_prayer")
                        .remove("silenced_at")
                        .remove("window_end_ms")
                        .commit()
                } else {
                    // Nothing else keeping it silent — restore
                    Log.d(TAG, "Prayer expired, no geo — restoring")
                    val volumeService = VolumeControlService(context)
                    val savedState = mapOf(
                        "ringerMode" to prefs.getInt("saved_ringer_mode", android.media.AudioManager.RINGER_MODE_NORMAL),
                        "interruptionFilter" to prefs.getInt("saved_interruption_filter", android.app.NotificationManager.INTERRUPTION_FILTER_ALL),
                        "ringVolume" to prefs.getInt("saved_ring_volume", 5),
                        "notificationVolume" to prefs.getInt("saved_notification_volume", 5)
                    )
                    val success = volumeService.restoreState(savedState)
                    if (success) {
                        prefs.edit()
                            .putBoolean("is_silenced", false)
                            .putBoolean("user_overridden", false)
                            .remove("current_prayer")
                            .remove("silenced_at")
                            .remove("window_end_ms")
                            .remove("saved_ringer_mode")
                            .remove("saved_interruption_filter")
                            .remove("saved_ring_volume")
                            .remove("saved_notification_volume")
                            .remove("saved_alarm_volume")
                            .remove("saved_media_volume")
                            .remove("saved_captured_at")
                            .remove("saved_change_token")
                            .commit()
                        Log.d(TAG, "Boot restore successful")
                    }
                }
            } else if (windowEndMs > 0) {
                Log.d(TAG, "Still in silence window — re-scheduling restore alarm")
                AlarmScheduler.scheduleRestoreAlarm(context, windowEndMs)
                AlarmScheduler.scheduleSafetyRestoreAlarm(context, windowEndMs + 5 * 60 * 1000)
            }
        }

        // Also check for stale geo_silenced state (reuse prefs from above)
        val geoSilenced = prefs.getBoolean("geo_silenced", false)
        if (geoSilenced) {
            // Geofences were cleared by reboot, so geo_silenced is stale — clear it
            // The geofences will be re-registered below, and if user is still at the masjid,
            // the INITIAL_TRIGGER_ENTER will re-silence
            Log.d(TAG, "Clearing stale geo_silenced flag (geofences cleared by reboot)")
            prefs.edit()
                .putBoolean("geo_silenced", false)
                .remove("active_masjid_geofences")
                .commit()
        }
    }

    private fun handleGeofenceReregistration(context: Context) {
        // Read saved masjids from Flutter's SharedPreferences
        // Flutter shared_preferences uses "FlutterSharedPreferences" with "flutter." prefix
        val flutterPrefs = context.getSharedPreferences(MASJID_PREFS_NAME, Context.MODE_PRIVATE)
        val masjidJson = flutterPrefs.getString("flutter.saved_masjids", null)

        if (masjidJson == null) {
            Log.d(TAG, "No saved masjids found — skipping geofence registration")
            return
        }

        // Check if geofence silence is enabled
        val geofenceEnabled = flutterPrefs.getString("flutter.geofence_silence_enabled", null)
        if (geofenceEnabled == "false") {
            Log.d(TAG, "Geofence silence disabled — skipping registration")
            return
        }

        try {
            val masjids = parseMasjidsFromJson(masjidJson)
            if (masjids.isNotEmpty()) {
                GeofenceManager.registerGeofences(context, masjids,
                    onSuccess = {
                        Log.d(TAG, "Re-registered ${masjids.size} geofences after boot")
                    },
                    onFailure = { error ->
                        Log.e(TAG, "Failed to re-register geofences after boot: $error")
                    }
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing masjid data for boot re-registration: ${e.message}")
        }
    }

    private fun parseMasjidsFromJson(json: String): List<MasjidLocation> {
        val masjids = mutableListOf<MasjidLocation>()
        try {
            val array = org.json.JSONArray(json)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                masjids.add(MasjidLocation(
                    id = obj.getString("id"),
                    name = obj.getString("name"),
                    latitude = obj.getDouble("latitude"),
                    longitude = obj.getDouble("longitude"),
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse masjid JSON: ${e.message}")
        }
        return masjids
    }
}
