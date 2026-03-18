package com.respectful.respectful

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles timezone and time changes — triggers prayer time recalculation.
 */
class TimezoneReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "RespectfulTimezone"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_TIMEZONE_CHANGED -> {
                Log.d(TAG, "Timezone changed — recalculation needed")
            }
            Intent.ACTION_TIME_CHANGED -> {
                Log.d(TAG, "Time changed — recalculation needed")
            }
        }
        // TODO: In full app, recalculate prayer times and reschedule all alarms
        // For now, this receiver proves the infrastructure works
    }
}
