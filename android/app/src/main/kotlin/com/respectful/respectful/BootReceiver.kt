package com.respectful.respectful

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles device boot — checks for stale silence state and triggers reschedule.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "RespectfulBoot"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        Log.d(TAG, "Boot completed — checking silence state")

        val prefs = context.getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val isSilenced = prefs.getBoolean("is_silenced", false)

        if (isSilenced) {
            // Phone was silenced when it rebooted — check if we should restore
            val volumeService = VolumeControlService(context)
            val windowEndMs = prefs.getLong("window_end_ms", 0)

            if (windowEndMs > 0 && System.currentTimeMillis() > windowEndMs) {
                // Silence window has passed — restore immediately
                Log.d(TAG, "Silence window expired during reboot — restoring")
                val savedState = mapOf(
                    "ringerMode" to prefs.getInt("saved_ringer_mode", android.media.AudioManager.RINGER_MODE_NORMAL),
                    "interruptionFilter" to prefs.getInt("saved_interruption_filter", android.app.NotificationManager.INTERRUPTION_FILTER_ALL),
                    "ringVolume" to prefs.getInt("saved_ring_volume", 5),
                    "notificationVolume" to prefs.getInt("saved_notification_volume", 5)
                )
                val success = volumeService.restoreState(savedState)
                if (success) {
                    // Full session cleanup using commit() for durability
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
                    Log.d(TAG, "Boot restore successful — session cleared")
                } else {
                    Log.e(TAG, "Boot restore FAILED — session left active for retry")
                }
            } else if (windowEndMs > 0) {
                // Still in silence window — re-register the restore alarm
                Log.d(TAG, "Still in silence window — re-scheduling restore alarm")
                AlarmScheduler.scheduleRestoreAlarm(context, windowEndMs)
                AlarmScheduler.scheduleSafetyRestoreAlarm(context, windowEndMs + 5 * 60 * 1000)
            }
        }

        // TODO: In full app, recalculate prayer times and reschedule all alarms
        Log.d(TAG, "Boot recovery complete")
    }
}
