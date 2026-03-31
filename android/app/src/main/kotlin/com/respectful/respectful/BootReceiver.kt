package com.respectful.respectful

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.tasks.Tasks
import kotlin.math.max

class BootReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "RespectfulBoot"
        const val MASJID_PREFS_NAME = "FlutterSharedPreferences"
        private const val MIN_BOOT_RECOVERY_BUFFER_METERS = 20.0
        private const val BOOT_RECOVERY_BUFFER_FACTOR = 0.10
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        Log.d(TAG, "Boot completed — checking silence state and re-registering geofences")

        handleSilenceRecovery(context)
        handleGeofenceReregistration(context)
        GeoExitTrackingCoordinator.sync(context)

        Log.d(TAG, "Boot recovery complete")
    }

    private fun handleSilenceRecovery(context: Context) {
        val flutterPrefs = context.getSharedPreferences(MASJID_PREFS_NAME, Context.MODE_PRIVATE)
        if (!flutterPrefs.getBoolean("flutter.master_silence_enabled", true)) {
            return
        }
        val prefs = context.getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val volumeService = VolumeControlService(context)

        recoverPrayerSession(context, prefs, volumeService)
        recoverGeoSession(context, prefs, volumeService)
    }

    private fun recoverPrayerSession(
        context: Context,
        prefs: android.content.SharedPreferences,
        volumeService: VolumeControlService,
    ) {
        if (!prefs.getBoolean("is_silenced", false)) return

        val windowEndMs = prefs.getLong("window_end_ms", 0)
        if (windowEndMs <= 0L) {
            SuppressionSessionStore.clearPrayerSession(prefs)
            SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
            return
        }

        if (System.currentTimeMillis() > windowEndMs) {
            if (prefs.getBoolean("geo_silenced", false)) {
                Log.d(TAG, "Prayer expired during boot but geo silence is still active")
                SuppressionSessionStore.clearPrayerSession(prefs)
            } else {
                val restored = SuppressionSessionStore.restoreBaseline(
                    context,
                    prefs,
                    volumeService,
                )
                if (restored) {
                    SuppressionSessionStore.clearPrayerSession(prefs)
                    SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
                    Log.d(TAG, "Boot restore for expired prayer session succeeded")
                }
            }
            return
        }

        volumeService.applySilence()
        AlarmScheduler.scheduleRestoreAlarm(context, windowEndMs)
        AlarmScheduler.scheduleSafetyRestoreAlarm(context, windowEndMs + 5 * 60 * 1000)
        Log.d(TAG, "Re-applied prayer silence and re-scheduled restore alarm after boot")
    }

    private fun recoverGeoSession(
        context: Context,
        prefs: android.content.SharedPreferences,
        volumeService: VolumeControlService,
    ) {
        val geoActive = prefs.getBoolean("geo_silenced", false)
        val geoVisitOverrideActive = SuppressionSessionStore.isGeoVisitOverrideActive(prefs)
        if (!geoActive && !geoVisitOverrideActive) return

        val flutterPrefs = context.getSharedPreferences(MASJID_PREFS_NAME, Context.MODE_PRIVATE)
        val geofenceEnabled = flutterPrefs.getBoolean("flutter.geofence_silence_enabled", true)
        val masjidJson = flutterPrefs.getString("flutter.saved_masjids", null)
        val masjids = if (masjidJson.isNullOrBlank()) emptyList() else parseMasjidsFromJson(masjidJson)

        if (!geofenceEnabled || masjids.isEmpty()) {
            clearGeoSessionAfterBoot(context, prefs, volumeService)
            Log.d(TAG, "Cleared geo session during boot because geofencing is disabled or empty")
            return
        }

        val stillInside = isStillInsideMasjid(context, flutterPrefs, masjids)
        if (stillInside == true) {
            if (geoActive && !prefs.getBoolean("is_silenced", false)) {
                volumeService.applySilence()
            }
            if (geoActive && prefs.getLong("geo_silenced_at", 0) == 0L) {
                prefs.edit().putLong("geo_silenced_at", System.currentTimeMillis()).commit()
            }
            Log.d(TAG, "Recovered active geo session after boot")
            return
        }

        clearGeoSessionAfterBoot(context, prefs, volumeService)
        Log.d(TAG, "Cleared geo session during boot because device is no longer inside a masjid")
    }

    private fun clearGeoSessionAfterBoot(
        context: Context,
        prefs: android.content.SharedPreferences,
        volumeService: VolumeControlService,
    ) {
        val isPrayerActive = prefs.getBoolean("is_silenced", false)
        val isGeoActive = prefs.getBoolean("geo_silenced", false)
        if (isGeoActive && !isPrayerActive) {
            SuppressionSessionStore.restoreBaseline(context, prefs, volumeService)
        }
        SuppressionSessionStore.clearGeoSession(prefs)
        SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
    }

    private fun handleGeofenceReregistration(context: Context) {
        val flutterPrefs = context.getSharedPreferences(MASJID_PREFS_NAME, Context.MODE_PRIVATE)
        val masjidJson = flutterPrefs.getString("flutter.saved_masjids", null)

        if (masjidJson.isNullOrBlank()) {
            Log.d(TAG, "No saved masjids found — skipping geofence registration")
            return
        }

        val masterEnabled = flutterPrefs.getBoolean("flutter.master_silence_enabled", true)
        val geofenceEnabled = flutterPrefs.getBoolean("flutter.geofence_silence_enabled", true)
        if (!masterEnabled || !geofenceEnabled) {
            Log.d(TAG, "Geofence silence disabled — skipping registration")
            return
        }

        try {
            val masjids = parseMasjidsFromJson(masjidJson)
            if (masjids.isNotEmpty()) {
                GeofenceManager.registerGeofences(
                    context,
                    masjids,
                    onSuccess = {
                        Log.d(TAG, "Re-registered ${masjids.size} geofences after boot")
                    },
                    onFailure = { error ->
                        Log.e(TAG, "Failed to re-register geofences after boot: $error")
                    },
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing masjid data for boot re-registration: ${e.message}")
        }
    }

    private fun isStillInsideMasjid(
        context: Context,
        flutterPrefs: android.content.SharedPreferences,
        masjids: List<MasjidLocation>,
    ): Boolean? {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return null
        }

        val lastLocation = try {
            Tasks.await(LocationServices.getFusedLocationProviderClient(context).lastLocation)
        } catch (_: Exception) {
            null
        } ?: return null

        val radiusMeters = flutterPrefs.getInt("flutter.masjid_radius_meters", 150).toDouble()
        val insideThresholdMeters = radiusMeters + max(
            MIN_BOOT_RECOVERY_BUFFER_METERS,
            radiusMeters * BOOT_RECOVERY_BUFFER_FACTOR,
        )

        val distanceResult = FloatArray(1)
        var nearestDistanceMeters: Double? = null
        for (masjid in masjids) {
            Location.distanceBetween(
                masjid.latitude,
                masjid.longitude,
                lastLocation.latitude,
                lastLocation.longitude,
                distanceResult,
            )
            val distanceMeters = distanceResult[0].toDouble()
            if (nearestDistanceMeters == null || distanceMeters < nearestDistanceMeters) {
                nearestDistanceMeters = distanceMeters
            }
        }

        return nearestDistanceMeters != null && nearestDistanceMeters <= insideThresholdMeters
    }

    private fun parseMasjidsFromJson(json: String): List<MasjidLocation> {
        val masjids = mutableListOf<MasjidLocation>()
        try {
            val array = org.json.JSONArray(json)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                masjids.add(
                    MasjidLocation(
                        id = obj.getString("id"),
                        name = obj.getString("name"),
                        latitude = obj.getDouble("latitude"),
                        longitude = obj.getDouble("longitude"),
                    ),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse masjid JSON: ${e.message}")
        }
        return masjids
    }
}
