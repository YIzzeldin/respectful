package com.respectful.respectful

import android.content.Context
import android.content.SharedPreferences
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class GeofenceManagerPresenceSyncTest {
    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences
    private lateinit var volumeService: VolumeControlService

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        prefs = context.getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        volumeService = VolumeControlService(context)
    }

    @Test
    fun comfortablyInsideMasjidIds_returnsOnlyMasjidsInsideBufferedThreshold() {
        val masjids = listOf(
            MasjidLocation(
                id = "inside",
                name = "Inside",
                latitude = 24.7136,
                longitude = 46.6753,
            ),
            MasjidLocation(
                id = "outside",
                name = "Outside",
                latitude = 24.7164,
                longitude = 46.6753,
            ),
        )

        val ids = GeofenceManager.comfortablyInsideMasjidIds(
            latitude = 24.7136,
            longitude = 46.6753,
            masjids = masjids,
            radiusMeters = 150.0,
        )

        assertEquals(setOf("inside"), ids)
    }

    @Test
    fun applyRegisteredMasjidPresence_marksGeoSilencedWhilePrayerSilenceIsActive() {
        prefs.edit()
            .putBoolean("is_silenced", true)
            .commit()

        GeofenceManager.applyRegisteredMasjidPresence(
            context = context,
            prefs = prefs,
            volumeService = volumeService,
            insideMasjidIds = setOf("riyadh"),
        )

        assertTrue(prefs.getBoolean("geo_silenced", false))
        assertEquals(
            setOf("riyadh"),
            prefs.getStringSet("active_masjid_geofences", emptySet<String>())
                ?: emptySet<String>(),
        )
        assertTrue(prefs.getLong("geo_silenced_at", 0L) > 0L)
    }

    @Test
    fun isLocationFreshAndAccurate_acceptsFreshAndAccurateLocation() {
        assertTrue(
            GeofenceManager.isLocationFreshAndAccurate(
                locationAgeMs = 60_000,    // 1 minute old
                accuracyMeters = 20f,      // 20m accuracy
                radiusMeters = 150.0,      // 150m geofence
            )
        )
    }

    @Test
    fun isLocationFreshAndAccurate_rejectsStaleLocation() {
        assertFalse(
            GeofenceManager.isLocationFreshAndAccurate(
                locationAgeMs = 300_000,   // 5 minutes old
                accuracyMeters = 20f,      // 20m accuracy
                radiusMeters = 150.0,
            )
        )
    }

    @Test
    fun isLocationFreshAndAccurate_rejectsInaccurateLocation() {
        assertFalse(
            GeofenceManager.isLocationFreshAndAccurate(
                locationAgeMs = 60_000,    // 1 minute old
                accuracyMeters = 500f,     // 500m coarse fix
                radiusMeters = 150.0,
            )
        )
    }

    @Test
    fun isLocationFreshAndAccurate_rejectsStaleAndInaccurateLocation() {
        assertFalse(
            GeofenceManager.isLocationFreshAndAccurate(
                locationAgeMs = 300_000,
                accuracyMeters = 500f,
                radiusMeters = 150.0,
            )
        )
    }

    @Test
    fun isLocationFreshAndAccurate_rejectsAtExactMaxAge() {
        // At exactly the threshold + 1ms, should reject
        assertFalse(
            GeofenceManager.isLocationFreshAndAccurate(
                locationAgeMs = 120_001,   // 2min + 1ms
                accuracyMeters = 20f,
                radiusMeters = 150.0,
            )
        )
    }

    @Test
    fun isLocationFreshAndAccurate_acceptsAtExactMaxAge() {
        // At exactly 2 minutes, should accept
        assertTrue(
            GeofenceManager.isLocationFreshAndAccurate(
                locationAgeMs = 120_000,
                accuracyMeters = 20f,
                radiusMeters = 150.0,
            )
        )
    }

    @Test
    fun isLocationFreshAndAccurate_rejectsNegativeAge() {
        assertFalse(
            GeofenceManager.isLocationFreshAndAccurate(
                locationAgeMs = -1,
                accuracyMeters = 20f,
                radiusMeters = 150.0,
            )
        )
    }

    @Test
    fun isLocationFreshAndAccurate_rejectsAccuracyEqualToRadius() {
        assertFalse(
            GeofenceManager.isLocationFreshAndAccurate(
                locationAgeMs = 60_000,
                accuracyMeters = 150f,     // accuracy == radius
                radiusMeters = 150.0,
            )
        )
    }

    @Test
    fun isLocationFreshAndAccurate_respectsCustomMaxAge() {
        assertTrue(
            GeofenceManager.isLocationFreshAndAccurate(
                locationAgeMs = 250_000,
                accuracyMeters = 20f,
                radiusMeters = 150.0,
                maxAgeMs = 300_000,        // 5 min custom threshold
            )
        )
    }

    @Test
    fun applyRegisteredMasjidPresence_respectsGeoVisitOverride() {
        prefs.edit()
            .putBoolean("geo_visit_override_active", true)
            .commit()

        GeofenceManager.applyRegisteredMasjidPresence(
            context = context,
            prefs = prefs,
            volumeService = volumeService,
            insideMasjidIds = setOf("riyadh"),
        )

        assertFalse(prefs.getBoolean("geo_silenced", false))
        assertEquals(
            setOf("riyadh"),
            prefs.getStringSet("active_masjid_geofences", emptySet<String>())
                ?: emptySet<String>(),
        )
    }
}
