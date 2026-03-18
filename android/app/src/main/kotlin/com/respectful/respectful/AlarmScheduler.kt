package com.respectful.respectful

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Schedules exact alarms for silence/restore events.
 */
object AlarmScheduler {

    private const val TAG = "RespectfulScheduler"
    private const val SILENCE_REQUEST_BASE = 1000
    private const val RESTORE_REQUEST_BASE = 2000
    private const val SAFETY_RESTORE_REQUEST = 9999

    fun scheduleSilenceAlarm(
        context: Context,
        triggerAtMs: Long,
        prayerName: String,
        windowEndMs: Long,
        requestCode: Int = SILENCE_REQUEST_BASE
    ) {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_SILENCE
            putExtra(AlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AlarmReceiver.EXTRA_WINDOW_END_MS, windowEndMs)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        scheduleExact(context, triggerAtMs, pendingIntent)
        Log.d(TAG, "Scheduled silence for $prayerName at ${java.util.Date(triggerAtMs)}")
    }

    fun scheduleRestoreAlarm(
        context: Context,
        triggerAtMs: Long,
        requestCode: Int = RESTORE_REQUEST_BASE
    ) {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_RESTORE
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        scheduleExact(context, triggerAtMs, pendingIntent)
        Log.d(TAG, "Scheduled restore at ${java.util.Date(triggerAtMs)}")
    }

    /**
     * Schedule a safety restore alarm using setAlarmClock() — the most reliable alarm type.
     * This is the last line of defense against a phone stuck in DND.
     */
    fun scheduleSafetyRestoreAlarm(context: Context, triggerAtMs: Long) {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_SAFETY_RESTORE
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            SAFETY_RESTORE_REQUEST,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // setAlarmClock is the highest-priority alarm — survives Doze, battery optimization
        val alarmInfo = AlarmManager.AlarmClockInfo(triggerAtMs, pendingIntent)
        alarmManager.setAlarmClock(alarmInfo, pendingIntent)

        Log.d(TAG, "Scheduled SAFETY restore at ${java.util.Date(triggerAtMs)}")
    }

    fun cancelAllAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Cancel silence alarms (we use a range of request codes)
        for (i in SILENCE_REQUEST_BASE..SILENCE_REQUEST_BASE + 10) {
            val intent = Intent(context, AlarmReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context, i, intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            pi?.let { alarmManager.cancel(it) }
        }

        // Cancel restore alarms
        for (i in RESTORE_REQUEST_BASE..RESTORE_REQUEST_BASE + 10) {
            val intent = Intent(context, AlarmReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context, i, intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            pi?.let { alarmManager.cancel(it) }
        }

        // Cancel safety restore
        val safetyIntent = Intent(context, AlarmReceiver::class.java)
        val safetyPi = PendingIntent.getBroadcast(
            context, SAFETY_RESTORE_REQUEST, safetyIntent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        safetyPi?.let { alarmManager.cancel(it) }

        Log.d(TAG, "All alarms cancelled")
    }

    private fun scheduleExact(context: Context, triggerAtMs: Long, pendingIntent: PendingIntent) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            Log.w(TAG, "Cannot schedule exact alarms — permission not granted")
            // Fall back to inexact alarm
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
            return
        }

        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMs,
            pendingIntent
        )
    }
}
