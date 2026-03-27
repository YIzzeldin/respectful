package com.respectful.respectful

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

/**
 * Manages geofence registration/removal for saved masjid locations.
 * Uses Google Play Services GeofencingClient for battery-efficient monitoring.
 */
object GeofenceManager {

    private const val TAG = "RespectfulGeofence"
    private const val DEFAULT_GEOFENCE_RADIUS_METERS = 200f
    private const val GEOFENCE_DWELL_MS = 30_000L   // 30 seconds dwell before triggering

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
                .setLoiteringDelay(GEOFENCE_DWELL_MS.toInt())
                .build()
        }

        // NO initial trigger — only fire on actual boundary crossing.
        // GPS calibration (Mode 2) handles "already inside" detection.
        // INITIAL_TRIGGER_ENTER caused phantom re-entries during
        // re-registration after delete, re-setting geo_silenced.
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(0) // no initial trigger
            .addGeofences(geofenceList)
            .build()

        val pendingIntent = getGeofencePendingIntent(context)

        geofencingClient.addGeofences(request, pendingIntent)
            .addOnSuccessListener {
                Log.d(TAG, "Registered ${masjids.size} geofences")
                onSuccess?.invoke()
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to register geofences: ${e.message}")
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

    private fun getGeofenceRadiusMeters(context: Context): Float {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        val radius = prefs.getInt(
            "flutter.masjid_radius_meters",
            DEFAULT_GEOFENCE_RADIUS_METERS.toInt(),
        )
        return radius.coerceIn(50, 1000).toFloat()
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
