package com.respectful.respectful

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

/**
 * Receives exact alarm events for silence/restore actions.
 * This runs even when the app is killed — it's a manifest-registered receiver.
 *
 * Uses commit() instead of apply() for all critical state writes because
 * the process may be killed immediately after onReceive() returns.
 *
 * Prayer silence (is_silenced) and geo silence (geo_silenced) are tracked
 * independently. The phone restores only when BOTH are inactive.
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "RespectfulAlarm"
        const val ACTION_SILENCE = "com.respectful.ACTION_SILENCE"
        const val ACTION_RESTORE = "com.respectful.ACTION_RESTORE"
        const val ACTION_SAFETY_RESTORE = "com.respectful.ACTION_SAFETY_RESTORE"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_WINDOW_END_MS = "window_end_ms"
        const val PREFS_NAME = "respectful_prefs"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val volumeService = VolumeControlService(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        Log.d(TAG, "AlarmReceiver fired: action=$action")

        when (action) {
            ACTION_SILENCE -> {
                val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "unknown"
                val windowEndMs = intent.getLongExtra(EXTRA_WINDOW_END_MS, 0)
                handleSilence(volumeService, prefs, prayerName, windowEndMs)
            }
            ACTION_RESTORE, ACTION_SAFETY_RESTORE -> {
                handleRestore(volumeService, prefs, action == ACTION_SAFETY_RESTORE)
            }
        }
    }

    private fun handleSilence(
        volumeService: VolumeControlService,
        prefs: SharedPreferences,
        prayerName: String,
        windowEndMs: Long
    ) {
        val isAlreadySilenced = prefs.getBoolean("is_silenced", false)
        val isGeoSilenced = prefs.getBoolean("geo_silenced", false)

        // Only capture snapshot if NOTHING is currently silencing the phone.
        // If geo is active, the geo snapshot already has the pre-silence state.
        if (!isAlreadySilenced && !isGeoSilenced) {
            val state = volumeService.captureCurrentState()
            prefs.edit()
                .putInt("saved_ringer_mode", state["ringerMode"] as Int)
                .putInt("saved_interruption_filter", state["interruptionFilter"] as Int)
                .putInt("saved_ring_volume", state["ringVolume"] as Int)
                .putInt("saved_notification_volume", state["notificationVolume"] as Int)
                .putInt("saved_alarm_volume", state["alarmVolume"] as Int)
                .putInt("saved_media_volume", state["mediaVolume"] as Int)
                .putLong("saved_captured_at", state["capturedAt"] as Long)
                .putString("saved_change_token", state["changeToken"] as String)
                .commit()
        }

        val success = volumeService.applySilence()

        if (!success) {
            Log.e(TAG, "Failed to silence for $prayerName — DND permission likely missing")
            return
        }

        // Mark prayer silence active — don't touch geo state
        prefs.edit()
            .putBoolean("is_silenced", true)
            .putBoolean("user_overridden", false)
            .putString("current_prayer", prayerName)
            .putLong("silenced_at", System.currentTimeMillis())
            .putLong("window_end_ms", windowEndMs)
            .commit()

        Log.d(TAG, "Silenced for $prayerName (geo_active=$isGeoSilenced)")
    }

    private fun handleRestore(
        volumeService: VolumeControlService,
        prefs: SharedPreferences,
        isSafetyRestore: Boolean
    ) {
        val isSilenced = prefs.getBoolean("is_silenced", false)
        val isGeoSilenced = prefs.getBoolean("geo_silenced", false)
        val userOverridden = prefs.getBoolean("user_overridden", false)

        if (!isSilenced && !isGeoSilenced) {
            Log.d(TAG, "Restore called but nothing silenced, skipping")
            return
        }

        if (userOverridden && !isSafetyRestore) {
            Log.d(TAG, "User overridden, skipping restore")
            // Clear only prayer state, leave geo state alone
            clearPrayerSession(prefs)
            return
        }

        // If this is a prayer restore but geo is still active, just clear
        // the prayer flag — phone stays silent because of the geofence.
        if (isSilenced && isGeoSilenced) {
            Log.d(TAG, "Prayer ended but geo still active — staying silent")
            clearPrayerSession(prefs)
            return
        }

        // Determine which saved state to restore from
        val savedState = if (isGeoSilenced) {
            mapOf(
                "ringerMode" to prefs.getInt("geo_saved_ringer_mode", android.media.AudioManager.RINGER_MODE_NORMAL),
                "interruptionFilter" to prefs.getInt("geo_saved_interruption_filter", android.app.NotificationManager.INTERRUPTION_FILTER_ALL),
                "ringVolume" to prefs.getInt("geo_saved_ring_volume", 5),
                "notificationVolume" to prefs.getInt("geo_saved_notification_volume", 5)
            )
        } else {
            mapOf(
                "ringerMode" to prefs.getInt("saved_ringer_mode", android.media.AudioManager.RINGER_MODE_NORMAL),
                "interruptionFilter" to prefs.getInt("saved_interruption_filter", android.app.NotificationManager.INTERRUPTION_FILTER_ALL),
                "ringVolume" to prefs.getInt("saved_ring_volume", 5),
                "notificationVolume" to prefs.getInt("saved_notification_volume", 5)
            )
        }

        val success = volumeService.restoreState(savedState)

        if (success) {
            // Clear only the relevant session — not the other
            if (isSilenced) clearPrayerSession(prefs)
            if (isGeoSilenced) clearGeoSession(prefs)
            Log.d(TAG, "Restored successfully (safety=$isSafetyRestore)")
        } else {
            Log.e(TAG, "Restore FAILED — session left active for retry")
        }
    }

    /** Clear prayer session state only. */
    private fun clearPrayerSession(prefs: SharedPreferences) {
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
    }

    /** Clear geo session state only. */
    private fun clearGeoSession(prefs: SharedPreferences) {
        prefs.edit()
            .putBoolean("geo_silenced", false)
            .remove("active_masjid_geofences")
            .remove("geo_saved_ringer_mode")
            .remove("geo_saved_interruption_filter")
            .remove("geo_saved_ring_volume")
            .remove("geo_saved_notification_volume")
            .commit()
    }
}
