package com.respectful.respectful

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import android.os.SystemClock
import org.json.JSONArray
import kotlin.math.max

class GeoExitTrackingService : Service() {

    companion object {
        const val ACTION_START = "com.respectful.respectful.action.START_GEO_EXIT_TRACKING"
        const val ACTION_STOP = "com.respectful.respectful.action.STOP_GEO_EXIT_TRACKING"

        private const val CHANNEL_ID = "geo_exit_tracking"
        private const val CHANNEL_NAME = "Masjid exit tracking"
        private const val NOTIFICATION_ID = 4101
        private const val UPDATE_INTERVAL_MS = 10_000L
        private const val MIN_BUFFER_METERS = 5.0
        private const val BUFFER_FACTOR = 0.03
        private const val EXIT_CHECKS_BEFORE_RESTORE = 3
        private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
        private const val GEO_REENTRY_PROBATION_MS = 2 * 60 * 1000L
        private const val MAX_LAST_LOCATION_AGE_NS = 60_000_000_000L // 60 seconds
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private lateinit var volumeService: VolumeControlService
    private var isTracking = false
    private var outsideStreak = 0

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        volumeService = VolumeControlService(this)
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val location = result.lastLocation ?: return
                checkForExit(location)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopTrackingAndSelf()
            return START_NOT_STICKY
        }

        if (!GeoExitTrackingCoordinator.isEnabled(this)) {
            stopTrackingAndSelf()
            return START_NOT_STICKY
        }

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        startTracking()
        return START_STICKY
    }

    override fun onDestroy() {
        stopLocationUpdates()
        GeoExitTrackingCoordinator.markRunning(this, false)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    @SuppressLint("MissingPermission")
    private fun startTracking() {
        if (isTracking) return

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            stopTrackingAndSelf()
            return
        }

        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            UPDATE_INTERVAL_MS,
        )
            .setMinUpdateIntervalMillis(10_000L)
            .setWaitForAccurateLocation(false)
            .build()

        fusedLocationClient.requestLocationUpdates(
            request,
            locationCallback,
            Looper.getMainLooper(),
        )

        isTracking = true
        GeoExitTrackingCoordinator.markRunning(this, true)

        // Immediate check using last known location so a restart while
        // already stationary/outside doesn't wait for the next callback.
        // Reject stale locations to avoid false exits from old cached fixes.
        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
            if (location != null) {
                val ageNs = SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos
                if (ageNs <= MAX_LAST_LOCATION_AGE_NS) {
                    checkForExit(location)
                }
            }
        }
    }

    private fun stopTrackingAndSelf() {
        stopLocationUpdates()
        GeoExitTrackingCoordinator.markRunning(this, false)
        stopForegroundCompat()
        stopSelf()
    }

    private fun stopLocationUpdates() {
        if (!isTracking) return
        fusedLocationClient.removeLocationUpdates(locationCallback)
        isTracking = false
        outsideStreak = 0
    }

    private fun checkForExit(location: android.location.Location) {
        val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("geo_silenced", false) || !GeoExitTrackingCoordinator.isEnabled(this)) {
            stopTrackingAndSelf()
            return
        }

        val nearestDistanceMeters = nearestMasjidDistanceMeters(
            latitude = location.latitude,
            longitude = location.longitude,
        ) ?: run {
            stopTrackingAndSelf()
            return
        }

        val radiusMeters = getMasjidRadiusMeters()
        val exitThresholdMeters = radiusMeters + max(MIN_BUFFER_METERS, radiusMeters * BUFFER_FACTOR)

        // Skip low-quality fixes — if the accuracy circle is larger than
        // the exit buffer, the reading cannot reliably distinguish inside
        // from outside. Don't reset outsideStreak either; just wait for
        // a better fix.
        if (location.hasAccuracy() && location.accuracy > exitThresholdMeters) {
            return
        }

        if (nearestDistanceMeters < exitThresholdMeters) {
            if (outsideStreak > 0) {
                NativeEventLog.log(this, "geofenceDebug",
                    "Exit tracking: back inside (dist=${nearestDistanceMeters.toInt()}m < threshold=${exitThresholdMeters.toInt()}m), streak reset")
            }
            outsideStreak = 0
            return
        }

        outsideStreak += 1
        NativeEventLog.log(this, "geofenceDebug",
            "Exit tracking: outside check #$outsideStreak/$EXIT_CHECKS_BEFORE_RESTORE (dist=${nearestDistanceMeters.toInt()}m > threshold=${exitThresholdMeters.toInt()}m)")
        if (outsideStreak < EXIT_CHECKS_BEFORE_RESTORE) return

        val cleared = clearGeoSilenceFromTracking(prefs)
        if (!cleared) return

        NativeEventLog.log(
            this,
            "geofenceExit",
            "Fast exit tracking restored after leaving the masjid area (dist=${nearestDistanceMeters.toInt()}m)",
        )
        stopTrackingAndSelf()
    }

    private fun clearGeoSilenceFromTracking(
        prefs: android.content.SharedPreferences,
    ): Boolean {
        val isPrayerActive = prefs.getBoolean("is_silenced", false)
        val currentFilter = volumeService.getCurrentInterruptionFilter()
        val wasOverridden = currentFilter != android.app.NotificationManager.INTERRUPTION_FILTER_NONE &&
            currentFilter != android.app.NotificationManager.INTERRUPTION_FILTER_PRIORITY

        if (!wasOverridden && !isPrayerActive) {
            val restored = SuppressionSessionStore.restoreBaseline(
                this,
                prefs,
                volumeService,
            )
            if (!restored) return false
        }

        SuppressionSessionStore.clearGeoSession(prefs)
        SuppressionSessionStore.maybeClearBaselineIfUnused(prefs)
        SuppressionSessionStore.setGeoReentryProbationUntil(
            prefs,
            System.currentTimeMillis() + GEO_REENTRY_PROBATION_MS,
        )
        return true
    }

    private fun nearestMasjidDistanceMeters(
        latitude: Double,
        longitude: Double,
    ): Double? {
        val prefs = getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val savedJson = prefs.getString("flutter.saved_masjids", "[]") ?: "[]"
        val array = try {
            JSONArray(savedJson)
        } catch (_: Exception) {
            return null
        }

        var nearest: Double? = null
        val result = FloatArray(1)
        for (i in 0 until array.length()) {
            val masjid = array.optJSONObject(i) ?: continue
            val masjidLat = masjid.optDouble("latitude", Double.NaN)
            val masjidLng = masjid.optDouble("longitude", Double.NaN)
            if (masjidLat.isNaN() || masjidLng.isNaN()) continue

            Location.distanceBetween(
                masjidLat,
                masjidLng,
                latitude,
                longitude,
                result,
            )
            val distanceMeters = result[0].toDouble()
            if (nearest == null || distanceMeters < nearest) {
                nearest = distanceMeters
            }
        }

        return nearest
    }

    private fun getMasjidRadiusMeters(): Double {
        val prefs = getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val radius = prefs.getInt("flutter.masjid_radius_meters", 150)
        return radius.coerceIn(50, 1000).toDouble()
    }

    private fun buildNotification(): Notification {
        val prefs = getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val isArabic = prefs.getString("flutter.language_code", "en") == "ar"
        val title = if (isArabic) {
            "محترم يراقب الخروج من المسجد"
        } else {
            "Respectful is checking for masjid exit"
        }
        val text = if (isArabic) {
            "سيتم استعادة الصوت بسرعة عند المغادرة"
        } else {
            "Sound will restore faster when you leave"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        stopForeground(true)
    }
}
