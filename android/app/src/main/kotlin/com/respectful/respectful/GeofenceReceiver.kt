package com.respectful.respectful

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

/**
 * Receives geofence transition events (ENTER/EXIT masjid locations).
 * Silences the phone on ENTER/DWELL, restores on EXIT.
 */
class GeofenceReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "RespectfulGeofence"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent)
        if (event == null) {
            Log.e(TAG, "GeofencingEvent is null")
            return
        }
        if (event.hasError()) {
            Log.e(TAG, "Geofence error: ${event.errorCode}")
            return
        }

        val transition = event.geofenceTransition
        val triggeringGeofences = event.triggeringGeofences ?: emptyList()
        val masjidIds = triggeringGeofences.map { it.requestId }

        Log.d(TAG, "Geofence transition=$transition, masjids=$masjidIds")

        val prefs = context.getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val volumeService = VolumeControlService(context)

        when (transition) {
            Geofence.GEOFENCE_TRANSITION_ENTER,
            Geofence.GEOFENCE_TRANSITION_DWELL -> {
                handleEnterMasjid(context, prefs, volumeService, masjidIds, transition)
            }
            Geofence.GEOFENCE_TRANSITION_EXIT -> {
                handleExitMasjid(context, prefs, volumeService, masjidIds)
            }
        }
    }

    private fun handleEnterMasjid(
        context: Context,
        prefs: android.content.SharedPreferences,
        volumeService: VolumeControlService,
        masjidIds: List<String>,
        transition: Int,
    ) {
        if (transition == Geofence.GEOFENCE_TRANSITION_ENTER &&
            requiresMasjidDwellBeforeSilence(context)
        ) {
            Log.d(TAG, "Ignoring ENTER transition because dwell protection is enabled")
            return
        }

        // Only process masjid IDs that actually exist in the saved list.
        // Geofence re-registration can fire INITIAL_TRIGGER_ENTER with stale
        // IDs from deleted masjids — ignore those.
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val savedJson = flutterPrefs.getString("flutter.saved_masjids", "[]") ?: "[]"
        val savedIds = mutableSetOf<String>()
        try {
            val array = org.json.JSONArray(savedJson)
            for (i in 0 until array.length()) {
                savedIds.add(array.getJSONObject(i).getString("id"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse saved masjids: ${e.message}")
        }

        val validIds = masjidIds.filter { it in savedIds }
        if (validIds.isEmpty()) {
            Log.d(TAG, "Ignoring geofence enter for deleted masjid IDs: $masjidIds")
            return
        }

        // Track which masjids we're inside
        val activeMasjids = prefs.getStringSet("active_masjid_geofences", mutableSetOf())?.toMutableSet()
            ?: mutableSetOf()
        activeMasjids.addAll(validIds)

        val isAlreadySilencedByGeo = prefs.getBoolean("geo_silenced", false)

        if (!isAlreadySilencedByGeo) {
            // First masjid entry — capture state and silence
            val isSilencedByPrayer = prefs.getBoolean("is_silenced", false)

            if (!isSilencedByPrayer) {
                // Not already silenced by prayer — capture state
                val state = volumeService.captureCurrentState()
                prefs.edit()
                    .putInt("geo_saved_ringer_mode", state["ringerMode"] as Int)
                    .putInt("geo_saved_interruption_filter", state["interruptionFilter"] as Int)
                    .putInt("geo_saved_ring_volume", state["ringVolume"] as Int)
                    .putInt("geo_saved_notification_volume", state["notificationVolume"] as Int)
                    .commit()
            }

            // Silence the phone
            volumeService.applySilence()
        }

        prefs.edit()
            .putBoolean("geo_silenced", true)
            .putLong("geo_silenced_at", System.currentTimeMillis())
            .putStringSet("active_masjid_geofences", activeMasjids)
            .commit()
        GeoExitTrackingCoordinator.sync(context)

        Log.d(TAG, "Entered masjid(s): $masjidIds, active set: $activeMasjids")
        NativeEventLog.log(context, "geofenceEnter", "Entered masjid — phone silenced")
    }

    private fun handleExitMasjid(
        context: Context,
        prefs: android.content.SharedPreferences,
        volumeService: VolumeControlService,
        masjidIds: List<String>,
    ) {
        val activeMasjids = prefs.getStringSet("active_masjid_geofences", mutableSetOf())?.toMutableSet()
            ?: mutableSetOf()
        activeMasjids.removeAll(masjidIds.toSet())

        if (activeMasjids.isEmpty()) {
            // Left all masjids — restore if not silenced by prayer time
            val isSilencedByPrayer = prefs.getBoolean("is_silenced", false)

            // Check if user manually changed DND while at the masjid
            // (same pattern as prayer-time user_overridden)
            val currentFilter = volumeService.getCurrentInterruptionFilter()
            val wasOverridden = currentFilter != android.app.NotificationManager.INTERRUPTION_FILTER_NONE
                    && currentFilter != android.app.NotificationManager.INTERRUPTION_FILTER_PRIORITY

            if (wasOverridden) {
                // User manually changed DND during visit — respect their choice
                Log.d(TAG, "Exited masjid but user overrode DND — respecting override")
            } else if (!isSilencedByPrayer) {
                // Restore to pre-masjid state
                val savedState = mapOf(
                    "ringerMode" to prefs.getInt("geo_saved_ringer_mode", android.media.AudioManager.RINGER_MODE_NORMAL),
                    "interruptionFilter" to prefs.getInt("geo_saved_interruption_filter", android.app.NotificationManager.INTERRUPTION_FILTER_ALL),
                    "ringVolume" to prefs.getInt("geo_saved_ring_volume", 5),
                    "notificationVolume" to prefs.getInt("geo_saved_notification_volume", 5),
                )
                volumeService.restoreState(savedState)
                Log.d(TAG, "Exited all masjids — restored phone state")
                NativeEventLog.log(context, "geofenceExit", "Left masjid — phone restored")
            } else {
                Log.d(TAG, "Exited all masjids but prayer silence active — keeping silent")
                NativeEventLog.log(context, "geofenceExit", "Left masjid — prayer still active")
            }

            // Clean up geo state
            prefs.edit()
                .putBoolean("geo_silenced", false)
                .remove("active_masjid_geofences")
                .remove("geo_saved_ringer_mode")
                .remove("geo_saved_interruption_filter")
                .remove("geo_saved_ring_volume")
                .remove("geo_saved_notification_volume")
                .commit()
            GeoExitTrackingCoordinator.sync(context)
        } else {
            // Still inside other masjids — stay silent
            prefs.edit()
                .putStringSet("active_masjid_geofences", activeMasjids)
                .commit()
            GeoExitTrackingCoordinator.sync(context)
            Log.d(TAG, "Exited masjid(s): $masjidIds, still in: $activeMasjids")
        }
    }

    private fun requiresMasjidDwellBeforeSilence(context: Context): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.require_masjid_dwell_before_silence", false)
    }
}
