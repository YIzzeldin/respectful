package com.respectful.respectful

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.provider.Settings

class VolumeControlService(private val context: Context) {

    private val audioManager: AudioManager
        get() = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val notificationManager: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    /**
     * Capture the current phone state before silencing.
     * Returns a map with all relevant volume/ringer/DND state.
     */
    fun captureCurrentState(): Map<String, Any> {
        return mapOf(
            "ringerMode" to audioManager.ringerMode,
            "interruptionFilter" to notificationManager.currentInterruptionFilter,
            "ringVolume" to audioManager.getStreamVolume(AudioManager.STREAM_RING),
            "notificationVolume" to audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION),
            "alarmVolume" to audioManager.getStreamVolume(AudioManager.STREAM_ALARM),
            "mediaVolume" to audioManager.getStreamVolume(AudioManager.STREAM_MUSIC),
            "capturedAt" to System.currentTimeMillis(),
            "changeToken" to java.util.UUID.randomUUID().toString()
        )
    }

    /**
     * Apply total silence: RINGER_MODE_SILENT + INTERRUPTION_FILTER_NONE.
     * Returns true if successful, false if missing DND permission.
     */
    fun applySilence(): Boolean {
        if (!hasDndPermission()) return false

        // Set ringer to silent (belt-and-suspenders with DND)
        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT

        // Apply total DND — blocks everything
        notificationManager.setInterruptionFilter(
            NotificationManager.INTERRUPTION_FILTER_NONE
        )

        return true
    }

    /**
     * Apply priority silence: RINGER_MODE_SILENT + INTERRUPTION_FILTER_PRIORITY.
     * Allows alarms and starred contacts through.
     */
    fun applyPrioritySilence(): Boolean {
        if (!hasDndPermission()) return false

        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT

        notificationManager.setInterruptionFilter(
            NotificationManager.INTERRUPTION_FILTER_PRIORITY
        )

        return true
    }

    /**
     * Restore phone to the state captured before silencing.
     */
    fun restoreState(state: Map<String, Any>): Boolean {
        if (!hasDndPermission()) return false

        // Restore DND filter first
        val interruptionFilter = (state["interruptionFilter"] as? Number)?.toInt()
            ?: NotificationManager.INTERRUPTION_FILTER_ALL
        notificationManager.setInterruptionFilter(interruptionFilter)

        // Restore ringer mode
        val ringerMode = (state["ringerMode"] as? Number)?.toInt()
            ?: AudioManager.RINGER_MODE_NORMAL
        audioManager.ringerMode = ringerMode

        // Restore volume levels
        val ringVolume = (state["ringVolume"] as? Number)?.toInt() ?: 0
        val notifVolume = (state["notificationVolume"] as? Number)?.toInt() ?: 0

        audioManager.setStreamVolume(AudioManager.STREAM_RING, ringVolume, 0)
        audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, notifVolume, 0)

        return true
    }

    /**
     * Check if the app has DND (Do Not Disturb) access permission.
     */
    fun hasDndPermission(): Boolean {
        return notificationManager.isNotificationPolicyAccessGranted
    }

    /**
     * Check if exact alarm permission is granted (Android 12+).
     */
    fun hasExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            return alarmManager.canScheduleExactAlarms()
        }
        return true // Pre-Android 12, no runtime permission needed
    }

    /**
     * Get current ringer mode for override detection.
     */
    fun getCurrentRingerMode(): Int {
        return audioManager.ringerMode
    }

    /**
     * Get current interruption filter for override detection.
     */
    fun getCurrentInterruptionFilter(): Int {
        return notificationManager.currentInterruptionFilter
    }
}
