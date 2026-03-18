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
        // Don't overwrite snapshot if already in a silence session
        val isAlreadySilenced = prefs.getBoolean("is_silenced", false)
        if (!isAlreadySilenced) {
            // Capture current state
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
                .commit() // commit() not apply() — process may die after onReceive
        }

        // Apply silence
        val success = volumeService.applySilence()

        if (!success) {
            Log.e(TAG, "Failed to silence for $prayerName — DND permission likely missing")
            return // Don't record a session that never started
        }

        // Update state — persist window_end_ms for boot recovery
        prefs.edit()
            .putBoolean("is_silenced", true)
            .putBoolean("user_overridden", false)
            .putString("current_prayer", prayerName)
            .putLong("silenced_at", System.currentTimeMillis())
            .putLong("window_end_ms", windowEndMs)
            .commit()

        Log.d(TAG, "Silenced for $prayerName, windowEnd=${java.util.Date(windowEndMs)}")
    }

    private fun handleRestore(
        volumeService: VolumeControlService,
        prefs: SharedPreferences,
        isSafetyRestore: Boolean
    ) {
        val isSilenced = prefs.getBoolean("is_silenced", false)
        val userOverridden = prefs.getBoolean("user_overridden", false)

        if (!isSilenced) {
            Log.d(TAG, "Restore called but not silenced, skipping")
            return
        }

        // If user manually overrode and this isn't a safety restore, skip
        if (userOverridden && !isSafetyRestore) {
            Log.d(TAG, "User overridden, skipping restore (safety=$isSafetyRestore)")
            clearSession(prefs)
            return
        }

        // Restore saved state
        val savedState = mapOf(
            "ringerMode" to prefs.getInt("saved_ringer_mode", android.media.AudioManager.RINGER_MODE_NORMAL),
            "interruptionFilter" to prefs.getInt("saved_interruption_filter", android.app.NotificationManager.INTERRUPTION_FILTER_ALL),
            "ringVolume" to prefs.getInt("saved_ring_volume", 5),
            "notificationVolume" to prefs.getInt("saved_notification_volume", 5)
        )

        val success = volumeService.restoreState(savedState)

        if (success) {
            clearSession(prefs)
            Log.d(TAG, "Restored successfully, safety=$isSafetyRestore")
        } else {
            // Don't clear session — restore failed (e.g. DND permission revoked).
            // Leave is_silenced=true so boot receiver / app-open check can retry.
            Log.e(TAG, "Restore FAILED (safety=$isSafetyRestore) — session left active for retry")
        }
    }

    /** Clear all session state. Uses commit() for durability. */
    private fun clearSession(prefs: SharedPreferences) {
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
}
