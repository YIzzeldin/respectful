package com.respectful.respectful

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import kotlin.math.max

/**
 * Manages geofence registration/removal for saved masjid locations.
 * Uses Google Play Services GeofencingClient for battery-efficient monitoring.
 */
object GeofenceManager {

    private const val TAG = "RespectfulGeofence"
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val DEFAULT_GEOFENCE_RADIUS_METERS = 150f
    private const val GEOFENCE_DWELL_MS = 30_000L   // 30 seconds dwell before triggering
    private const val GEOFENCE_NOTIFICATION_RESPONSIVENESS_MS = 10_000
    private const val MIN_BOUNDARY_BUFFER_METERS = 20.0
    private const val BOUNDARY_BUFFER_FACTOR = 0.10
    private const val PRESENCE_SYNC_MAX_AGE_MS = 2 * 60 * 1000L // 2 minutes

    /**
     * Register geofences for a list of masjid locations.
     * Each masjid gets a circular geofence with ENTER + EXIT transitions.
     */
    fun registerGeofences(
        context: Context,
        masjids: List<MasjidLocation>,
        onSuccess: (() -> Unit)? = null,
        onFailure: ((String) -> Unit)? = null,
    ) {
        if (masjids.isEmpty()) {
            Log.d(TAG, "No masjids to register")
            onSuccess?.invoke()
            return
        }

        // Check permissions
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "Missing ACCESS_FINE_LOCATION permission")
            onFailure?.invoke("Missing location permission")
            return
        }

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "Missing ACCESS_BACKGROUND_LOCATION permission")
            onFailure?.invoke("Missing background location permission")
            return
        }

        val geofencingClient = LocationServices.getGeofencingClient(context)
        val radiusMeters = getGeofenceRadiusMeters(context)

        val geofenceList = masjids.map { masjid ->
            Geofence.Builder()
                .setRequestId(masjid.id)
                .setCircularRegion(masjid.latitude, masjid.longitude, radiusMeters)
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(
                    Geofence.GEOFENCE_TRANSITION_ENTER or
                    Geofence.GEOFENCE_TRANSITION_DWELL or
                    Geofence.GEOFENCE_TRANSITION_EXIT
                )
                // Ask Android to deliver enter/exit callbacks promptly instead of
                // leaving responsiveness entirely to the default batching policy.
                .setNotificationResponsiveness(GEOFENCE_NOTIFICATION_RESPONSIVENESS_MS)
                .setLoiteringDelay(GEOFENCE_DWELL_MS.toInt())
                .build()
        }

        // Fire INITIAL_TRIGGER_ENTER and INITIAL_TRIGGER_DWELL so Android
        // detects "already inside" after re-registration. ENTER alone is not
        // enough when dwell protection is enabled — GeofenceReceiver ignores
        // plain ENTER in dwell mode, so without the DWELL trigger, users
        // already inside after boot/resume would never get silenced until
        // they leave and re-enter.
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(
                GeofencingRequest.INITIAL_TRIGGER_ENTER or
                GeofencingRequest.INITIAL_TRIGGER_DWELL
            )
            .addGeofences(geofenceList)
            .build()

        val pendingIntent = getGeofencePendingIntent(context)

        geofencingClient.addGeofences(request, pendingIntent)
            .addOnSuccessListener {
                Log.d(TAG, "Registered ${masjids.size} geofences (radius=${radiusMeters}m, initialTrigger=ENTER)")
                NativeEventLog.log(context, "geofenceDebug",
                    "Registered ${masjids.size} geofences: ${masjids.map { it.id }} (radius=${radiusMeters}m)")
                syncRegisteredMasjidPresence(context, masjids, radiusMeters.toDouble())
                onSuccess?.invoke()
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to register geofences: ${e.message}")
                NativeEventLog.log(context, "geofenceDebug",
                    "FAILED to register geofences: ${e.message}")
                onFailure?.invoke(e.message ?: "Unknown error")
            }
    }

    /**
     * Remove all registered geofences.
     */
    fun removeAllGeofences(context: Context, onComplete: (() -> Unit)? = null) {
        val geofencingClient = LocationServices.getGeofencingClient(context)
        geofencingClient.removeGeofences(getGeofencePendingIntent(context))
            .addOnSuccessListener {
                Log.d(TAG, "All geofences removed")
                onComplete?.invoke()
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to remove geofences: ${e.message}")
                onComplete?.invoke() // Still complete even on failure
            }
    }

    private fun getGeofencePendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, GeofenceReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            4000, // Unique request code for geofencing
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
    }

    internal fun comfortablyInsideMasjidIds(
        latitude: Double,
        longitude: Double,
        masjids: List<MasjidLocation>,
        radiusMeters: Double,
    ): Set<String> {
        val insideThresholdMeters = radiusMeters - boundaryBufferMeters(radiusMeters)
        if (insideThresholdMeters <= 0.0) return emptySet()

        val result = FloatArray(1)
        return masjids
            .mapNotNull { masjid ->
                Location.distanceBetween(
                    masjid.latitude,
                    masjid.longitude,
                    latitude,
                    longitude,
                    result,
                )
                if (result[0].toDouble() <= insideThresholdMeters) {
                    masjid.id
                } else {
                    null
                }
            }
            .toSet()
    }

    internal fun applyRegisteredMasjidPresence(
        context: Context,
        prefs: android.content.SharedPreferences,
        volumeService: VolumeControlService,
        insideMasjidIds: Set<String>,
    ) {
        if (insideMasjidIds.isEmpty()) return

        val activeMasjids = prefs.getStringSet("active_masjid_geofences", emptySet())
            ?.toMutableSet()
            ?: mutableSetOf()
        val changed = activeMasjids.addAll(insideMasjidIds)
        val isGeoVisitOverride = SuppressionSessionStore.isGeoVisitOverrideActive(prefs)
        val isAlreadySilencedByGeo = prefs.getBoolean("geo_silenced", false)
        val isSilencedByPrayer = prefs.getBoolean("is_silenced", false)

        // Respect dwell protection: if the user opted in and the phone isn't
        // already geo-silenced, let the DWELL event handle initial silencing
        // rather than silencing immediately from a cached location.
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val requireDwell = flutterPrefs.getBoolean("flutter.require_masjid_dwell_before_silence", false)
        if (requireDwell && !isAlreadySilencedByGeo) {
            NativeEventLog.log(context, "geofenceDebug",
                "Registration presence sync deferred: dwell protection is enabled")
            return
        }

        if (isGeoVisitOverride) {
            if (changed) {
                prefs.edit()
                    .putStringSet("active_masjid_geofences", activeMasjids)
                    .commit()
            }
            return
        }

        if (isAlreadySilencedByGeo && !changed) return

        if (!isAlreadySilencedByGeo && !isSilencedByPrayer) {
            SuppressionSessionStore.captureBaselineIfNeeded(context, prefs, volumeService)
            val silenced = volumeService.applySilence()
            if (!silenced) {
                Log.e(TAG, "Failed to silence during registration presence sync")
                return
            }
        }

        val editor = prefs.edit()
            .putStringSet("active_masjid_geofences", activeMasjids)
        if (!isAlreadySilencedByGeo) {
            editor
                .putBoolean("geo_silenced", true)
                .putLong("geo_silenced_at", System.currentTimeMillis())
        }
        editor.commit()
        GeoExitTrackingCoordinator.sync(context)

        if (!isAlreadySilencedByGeo) {
            NativeEventLog.log(
                context,
                "geofenceEnter",
                "Registered geofences detected an active masjid visit",
            )
        }
    }

    internal fun isLocationFreshAndAccurate(
        locationAgeMs: Long,
        accuracyMeters: Float,
        radiusMeters: Double,
        maxAgeMs: Long = PRESENCE_SYNC_MAX_AGE_MS,
    ): Boolean {
        return locationAgeMs in 0..maxAgeMs && accuracyMeters < radiusMeters
    }

    private fun syncRegisteredMasjidPresence(
        context: Context,
        masjids: List<MasjidLocation>,
        radiusMeters: Double,
    ) {
        if (!isGeofenceSilenceEnabled(context) || masjids.isEmpty()) return

        val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)
        fusedLocationClient.lastLocation
            .addOnSuccessListener { location ->
                if (location == null) return@addOnSuccessListener

                val ageMs = (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000
                if (!isLocationFreshAndAccurate(ageMs, location.accuracy, radiusMeters)) {
                    NativeEventLog.log(context, "geofenceDebug",
                        "Registration presence sync skipped: location age=${ageMs}ms, accuracy=${location.accuracy}m, radius=${radiusMeters}m")
                    return@addOnSuccessListener
                }

                val insideMasjidIds = comfortablyInsideMasjidIds(
                    latitude = location.latitude,
                    longitude = location.longitude,
                    masjids = masjids,
                    radiusMeters = radiusMeters,
                )
                NativeEventLog.log(context, "geofenceDebug",
                    "Registration presence sync: location=(${location.latitude}, ${location.longitude}), age=${ageMs}ms, accuracy=${location.accuracy}m, insideMasjids=$insideMasjidIds")
                if (insideMasjidIds.isEmpty()) return@addOnSuccessListener

                val prefs = context.getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                val volumeService = VolumeControlService(context)
                applyRegisteredMasjidPresence(context, prefs, volumeService, insideMasjidIds)
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "Failed to check current masjid presence after registration: ${e.message}")
            }
    }

    private fun getGeofenceRadiusMeters(context: Context): Float {
        val prefs = context.getSharedPreferences(
            FLUTTER_PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        val radius = prefs.getInt(
            "flutter.masjid_radius_meters",
            DEFAULT_GEOFENCE_RADIUS_METERS.toInt(),
        )
        return radius.coerceIn(50, 1000).toFloat()
    }

    private fun isGeofenceSilenceEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val masterEnabled = prefs.getBoolean("flutter.master_silence_enabled", true)
        val geofenceEnabled = prefs.getBoolean("flutter.geofence_silence_enabled", true)
        return masterEnabled && geofenceEnabled
    }

    private fun boundaryBufferMeters(radiusMeters: Double): Double {
        return max(MIN_BOUNDARY_BUFFER_METERS, radiusMeters * BOUNDARY_BUFFER_FACTOR)
    }
}

/**
 * Simple data class for passing masjid location data to the geofence manager.
 */
data class MasjidLocation(
    val id: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
)
