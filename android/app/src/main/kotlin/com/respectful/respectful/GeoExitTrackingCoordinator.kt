package com.respectful.respectful

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

object GeoExitTrackingCoordinator {
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val FAST_TRACKING_KEY = "flutter.fast_geo_exit_tracking_enabled"
    private const val FAST_TRACKING_CHOICE_KEY = "flutter.fast_geo_exit_tracking_user_choice"
    private const val RUNNING_KEY = "geo_exit_tracking_running"

    fun sync(context: Context) {
        val prefs = context.getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val geoSilenced = prefs.getBoolean("geo_silenced", false)
        val enabled = isEnabled(context)
        val shouldTrack = geoSilenced && enabled
        val isRunning = prefs.getBoolean(RUNNING_KEY, false)

        when {
            shouldTrack && !isRunning -> {
                NativeEventLog.log(context, "geofenceDebug",
                    "GeoExitTracking: STARTING service (geo_silenced=$geoSilenced, enabled=$enabled)")
                start(context)
            }
            !shouldTrack && isRunning -> {
                NativeEventLog.log(context, "geofenceDebug",
                    "GeoExitTracking: STOPPING service (geo_silenced=$geoSilenced, enabled=$enabled)")
                stop(context)
            }
        }
    }

    fun isEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val hasUserChoice = prefs.getBoolean(FAST_TRACKING_CHOICE_KEY, false)
        return if (hasUserChoice) {
            prefs.getBoolean(FAST_TRACKING_KEY, true)
        } else {
            true
        }
    }

    fun markRunning(context: Context, running: Boolean) {
        val prefs = context.getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(RUNNING_KEY, running).commit()
    }

    private fun start(context: Context) {
        val intent = Intent(context, GeoExitTrackingService::class.java).apply {
            action = GeoExitTrackingService.ACTION_START
        }
        ContextCompat.startForegroundService(context, intent)
    }

    private fun stop(context: Context) {
        val intent = Intent(context, GeoExitTrackingService::class.java).apply {
            action = GeoExitTrackingService.ACTION_STOP
        }
        context.stopService(intent)
    }
}
