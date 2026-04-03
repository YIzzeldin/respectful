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
                if (!isMasterSilenceEnabled(context)) {
                    SuppressionSessionStore.clearPrayerSession(prefs)
                    SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
                    Log.d(TAG, "Ignoring silence alarm because master silence is OFF")
                    return
                }
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

        if (!isAlreadySilenced && !isGeoSilenced) {
            SuppressionSessionStore.captureBaselineIfNeeded(
                volumeService.context,
                prefs,
                volumeService,
            )
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
            SuppressionSessionStore.clearPrayerSession(prefs)
            SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
            return
        }

        // If this is a prayer restore but geo is still active, just clear
        // the prayer flag — phone stays silent because of the geofence.
        if (isSilenced && isGeoSilenced) {
            Log.d(TAG, "Prayer ended but geo still active — staying silent")
            SuppressionSessionStore.clearPrayerSession(prefs)
            return
        }

        val success = SuppressionSessionStore.restoreBaseline(
            volumeService.context,
            prefs,
            volumeService,
        )

        if (success) {
            if (isSilenced) SuppressionSessionStore.clearPrayerSession(prefs)
            if (isGeoSilenced) SuppressionSessionStore.clearGeoSession(prefs)
            SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
            Log.d(TAG, "Restored successfully (safety=$isSafetyRestore)")
        } else {
            Log.e(TAG, "Restore FAILED — session left active for retry")
        }
    }
    private fun isMasterSilenceEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.master_silence_enabled", true)
    }
}
