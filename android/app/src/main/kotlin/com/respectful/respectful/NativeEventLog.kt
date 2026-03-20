package com.respectful.respectful

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Simple native event logger that writes to SharedPreferences.
 * Flutter reads these on app open and merges into the Dart event log.
 * This ensures events from BroadcastReceivers (when Flutter is dead)
 * are captured with correct timestamps.
 */
object NativeEventLog {
    private const val TAG = "NativeEventLog"
    private const val PREFS_NAME = "respectful_native_events"
    private const val KEY = "events"
    private const val MAX_EVENTS = 100

    fun log(context: Context, type: String, message: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY, "[]") ?: "[]"

        try {
            val array = JSONArray(existing)
            val event = JSONObject().apply {
                put("type", type)
                put("message", message)
                put("timestamp", System.currentTimeMillis())
            }
            array.put(event)

            // Cap at MAX_EVENTS — remove oldest
            while (array.length() > MAX_EVENTS) {
                array.remove(0)
            }

            prefs.edit().putString(KEY, array.toString()).commit()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log event: ${e.message}")
        }
    }

    fun readAndClear(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val events = prefs.getString(KEY, "[]") ?: "[]"
        prefs.edit().putString(KEY, "[]").commit()
        return events
    }
}
