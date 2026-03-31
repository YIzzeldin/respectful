package com.respectful.respectful

import android.content.Context
import android.content.SharedPreferences
import java.util.UUID

object SuppressionSessionStore {
    private const val BASELINE_RINGER_MODE = "baseline_ringer_mode"
    private const val BASELINE_INTERRUPTION_FILTER = "baseline_interruption_filter"
    private const val BASELINE_RING_VOLUME = "baseline_ring_volume"
    private const val BASELINE_NOTIFICATION_VOLUME = "baseline_notification_volume"
    private const val BASELINE_ALARM_VOLUME = "baseline_alarm_volume"
    private const val BASELINE_MEDIA_VOLUME = "baseline_media_volume"
    private const val BASELINE_CAPTURED_AT = "baseline_captured_at"
    private const val BASELINE_CHANGE_TOKEN = "baseline_change_token"

    private const val GEO_VISIT_OVERRIDE_ACTIVE = "geo_visit_override_active"
    private const val GEO_REENTRY_PROBATION_UNTIL = "geo_reentry_probation_until_ms"

    fun captureBaselineIfNeeded(
        context: Context,
        prefs: SharedPreferences,
        volumeService: VolumeControlService,
    ) {
        ensureBaselineAvailable(context, prefs, volumeService)
        if (hasBaseline(prefs)) return

        val state = volumeService.captureCurrentState()
        writeBaseline(prefs, state)
    }

    fun ensureBaselineAvailable(
        context: Context,
        prefs: SharedPreferences,
        volumeService: VolumeControlService,
    ) {
        if (hasBaseline(prefs)) return
        migrateLegacyBaseline(context, prefs, volumeService)
    }

    fun restoreBaseline(
        context: Context,
        prefs: SharedPreferences,
        volumeService: VolumeControlService,
    ): Boolean {
        ensureBaselineAvailable(context, prefs, volumeService)
        val state = readBaseline(prefs) ?: return false
        return volumeService.restoreState(state)
    }

    fun clearBaseline(prefs: SharedPreferences) {
        prefs.edit()
            .remove(BASELINE_RINGER_MODE)
            .remove(BASELINE_INTERRUPTION_FILTER)
            .remove(BASELINE_RING_VOLUME)
            .remove(BASELINE_NOTIFICATION_VOLUME)
            .remove(BASELINE_ALARM_VOLUME)
            .remove(BASELINE_MEDIA_VOLUME)
            .remove(BASELINE_CAPTURED_AT)
            .remove(BASELINE_CHANGE_TOKEN)
            .commit()
    }

    fun maybeClearBaselineIfUnused(prefs: SharedPreferences) {
        val prayerActive = prefs.getBoolean("is_silenced", false)
        val geoActive = prefs.getBoolean("geo_silenced", false)
        if (!prayerActive && !geoActive) {
            clearBaseline(prefs)
        }
    }

    fun clearPrayerSession(
        prefs: SharedPreferences,
        preserveOverride: Boolean = false,
    ) {
        val editor = prefs.edit()
            .putBoolean("is_silenced", false)
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

        if (preserveOverride) {
            editor.putBoolean("user_overridden", true)
        } else {
            editor.putBoolean("user_overridden", false)
        }

        editor.commit()
    }

    fun clearGeoSession(
        prefs: SharedPreferences,
        clearVisitOverride: Boolean = true,
    ) {
        val editor = prefs.edit()
            .putBoolean("geo_silenced", false)
            .remove("geo_silenced_at")
            .remove("active_masjid_geofences")
            .remove("geo_saved_ringer_mode")
            .remove("geo_saved_interruption_filter")
            .remove("geo_saved_ring_volume")
            .remove("geo_saved_notification_volume")
            .remove(GEO_REENTRY_PROBATION_UNTIL)

        if (clearVisitOverride) {
            editor.putBoolean(GEO_VISIT_OVERRIDE_ACTIVE, false)
        }

        editor.commit()
    }

    fun markGeoVisitOverridden(prefs: SharedPreferences) {
        prefs.edit()
            .putBoolean("geo_silenced", false)
            .remove("geo_silenced_at")
            .remove("geo_saved_ringer_mode")
            .remove("geo_saved_interruption_filter")
            .remove("geo_saved_ring_volume")
            .remove("geo_saved_notification_volume")
            .remove(GEO_REENTRY_PROBATION_UNTIL)
            .putBoolean(GEO_VISIT_OVERRIDE_ACTIVE, true)
            .commit()
    }

    fun setGeoReentryProbationUntil(
        prefs: SharedPreferences,
        untilMs: Long,
    ) {
        prefs.edit()
            .putLong(GEO_REENTRY_PROBATION_UNTIL, untilMs)
            .commit()
    }

    fun getGeoReentryProbationUntil(prefs: SharedPreferences): Long {
        return prefs.getLong(GEO_REENTRY_PROBATION_UNTIL, 0L)
    }

    fun setGeoVisitOverrideActive(
        prefs: SharedPreferences,
        active: Boolean,
    ) {
        prefs.edit()
            .putBoolean(GEO_VISIT_OVERRIDE_ACTIVE, active)
            .commit()
    }

    fun isGeoVisitOverrideActive(prefs: SharedPreferences): Boolean {
        return prefs.getBoolean(GEO_VISIT_OVERRIDE_ACTIVE, false)
    }

    fun hasBaseline(prefs: SharedPreferences): Boolean {
        return prefs.contains(BASELINE_CHANGE_TOKEN) &&
            prefs.contains(BASELINE_CAPTURED_AT)
    }

    private fun readBaseline(prefs: SharedPreferences): Map<String, Any>? {
        if (!hasBaseline(prefs)) return null

        return mapOf(
            "ringerMode" to prefs.getInt(
                BASELINE_RINGER_MODE,
                android.media.AudioManager.RINGER_MODE_NORMAL,
            ),
            "interruptionFilter" to prefs.getInt(
                BASELINE_INTERRUPTION_FILTER,
                android.app.NotificationManager.INTERRUPTION_FILTER_ALL,
            ),
            "ringVolume" to prefs.getInt(BASELINE_RING_VOLUME, 5),
            "notificationVolume" to prefs.getInt(BASELINE_NOTIFICATION_VOLUME, 5),
            "alarmVolume" to prefs.getInt(BASELINE_ALARM_VOLUME, 5),
            "mediaVolume" to prefs.getInt(BASELINE_MEDIA_VOLUME, 5),
            "capturedAt" to prefs.getLong(BASELINE_CAPTURED_AT, System.currentTimeMillis()),
            "changeToken" to (prefs.getString(BASELINE_CHANGE_TOKEN, null)
                ?: UUID.randomUUID().toString()),
        )
    }

    private fun writeBaseline(
        prefs: SharedPreferences,
        state: Map<String, Any>,
    ) {
        prefs.edit()
            .putInt(BASELINE_RINGER_MODE, (state["ringerMode"] as Number).toInt())
            .putInt(
                BASELINE_INTERRUPTION_FILTER,
                (state["interruptionFilter"] as Number).toInt(),
            )
            .putInt(BASELINE_RING_VOLUME, (state["ringVolume"] as Number).toInt())
            .putInt(
                BASELINE_NOTIFICATION_VOLUME,
                (state["notificationVolume"] as Number).toInt(),
            )
            .putInt(BASELINE_ALARM_VOLUME, (state["alarmVolume"] as Number).toInt())
            .putInt(BASELINE_MEDIA_VOLUME, (state["mediaVolume"] as Number).toInt())
            .putLong(BASELINE_CAPTURED_AT, (state["capturedAt"] as Number).toLong())
            .putString(BASELINE_CHANGE_TOKEN, state["changeToken"] as String)
            .commit()
    }

    private fun migrateLegacyBaseline(
        context: Context,
        prefs: SharedPreferences,
        volumeService: VolumeControlService,
    ) {
        val hasPrayerSnapshot = prefs.contains("saved_change_token") ||
            prefs.contains("saved_captured_at") ||
            prefs.contains("saved_ringer_mode")
        val hasGeoSnapshot = prefs.contains("geo_saved_ringer_mode") ||
            prefs.contains("geo_saved_interruption_filter") ||
            prefs.contains("geo_saved_ring_volume") ||
            prefs.contains("geo_saved_notification_volume")

        if (!hasPrayerSnapshot && !hasGeoSnapshot) return

        val currentState = volumeService.captureCurrentState()
        val state = if (hasPrayerSnapshot) {
            mapOf(
                "ringerMode" to prefs.getInt(
                    "saved_ringer_mode",
                    (currentState["ringerMode"] as Number).toInt(),
                ),
                "interruptionFilter" to prefs.getInt(
                    "saved_interruption_filter",
                    (currentState["interruptionFilter"] as Number).toInt(),
                ),
                "ringVolume" to prefs.getInt(
                    "saved_ring_volume",
                    (currentState["ringVolume"] as Number).toInt(),
                ),
                "notificationVolume" to prefs.getInt(
                    "saved_notification_volume",
                    (currentState["notificationVolume"] as Number).toInt(),
                ),
                "alarmVolume" to prefs.getInt(
                    "saved_alarm_volume",
                    (currentState["alarmVolume"] as Number).toInt(),
                ),
                "mediaVolume" to prefs.getInt(
                    "saved_media_volume",
                    (currentState["mediaVolume"] as Number).toInt(),
                ),
                "capturedAt" to prefs.getLong(
                    "saved_captured_at",
                    System.currentTimeMillis(),
                ),
                "changeToken" to (prefs.getString("saved_change_token", null)
                    ?: UUID.randomUUID().toString()),
            )
        } else {
            mapOf(
                "ringerMode" to prefs.getInt(
                    "geo_saved_ringer_mode",
                    (currentState["ringerMode"] as Number).toInt(),
                ),
                "interruptionFilter" to prefs.getInt(
                    "geo_saved_interruption_filter",
                    (currentState["interruptionFilter"] as Number).toInt(),
                ),
                "ringVolume" to prefs.getInt(
                    "geo_saved_ring_volume",
                    (currentState["ringVolume"] as Number).toInt(),
                ),
                "notificationVolume" to prefs.getInt(
                    "geo_saved_notification_volume",
                    (currentState["notificationVolume"] as Number).toInt(),
                ),
                "alarmVolume" to (currentState["alarmVolume"] as Number).toInt(),
                "mediaVolume" to (currentState["mediaVolume"] as Number).toInt(),
                "capturedAt" to System.currentTimeMillis(),
                "changeToken" to "legacy-geo-${UUID.randomUUID()}",
            )
        }

        writeBaseline(prefs, state)
    }
}
