package com.respectful.respectful

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

/**
 * Receives exact alarm events for silence/restore actions.
 * This runs even when the app is killed — it's a manifest-registered receiver.
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
                handleSilence(volumeService, prefs, prayerName)
            }
            ACTION_RESTORE, ACTION_SAFETY_RESTORE -> {
                handleRestore(volumeService, prefs, action == ACTION_SAFETY_RESTORE)
            }
        }
    }

    private fun handleSilence(
        volumeService: VolumeControlService,
        prefs: SharedPreferences,
        prayerName: String
    ) {
        // Don't overwrite snapshot if already in a silence session
        val isAlreadySilenced = prefs.getBoolean("is_silenced", false)
        if (!isAlreadySilenced) {
            // Capture current state
            val state = volumeService.captureCurrentState()
            val editor = prefs.edit()
            editor.putInt("saved_ringer_mode", state["ringerMode"] as Int)
            editor.putInt("saved_interruption_filter", state["interruptionFilter"] as Int)
            editor.putInt("saved_ring_volume", state["ringVolume"] as Int)
            editor.putInt("saved_notification_volume", state["notificationVolume"] as Int)
            editor.putInt("saved_alarm_volume", state["alarmVolume"] as Int)
            editor.putInt("saved_media_volume", state["mediaVolume"] as Int)
            editor.putLong("saved_captured_at", state["capturedAt"] as Long)
            editor.putString("saved_change_token", state["changeToken"] as String)
            editor.apply()
        }

        // Apply silence
        val success = volumeService.applySilence()

        // Update state
        val editor = prefs.edit()
        editor.putBoolean("is_silenced", true)
        editor.putBoolean("user_overridden", false)
        editor.putString("current_prayer", prayerName)
        editor.putLong("silenced_at", System.currentTimeMillis())
        editor.apply()

        Log.d(TAG, "Silenced for $prayerName, success=$success")
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
            // Still clear the silenced state
            prefs.edit().putBoolean("is_silenced", false).apply()
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

        // Clear silenced state
        val editor = prefs.edit()
        editor.putBoolean("is_silenced", false)
        editor.putBoolean("user_overridden", false)
        editor.remove("current_prayer")
        editor.remove("silenced_at")
        editor.apply()

        Log.d(TAG, "Restored, safety=$isSafetyRestore, success=$success")
    }
}
