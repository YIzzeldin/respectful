package com.respectful.respectful

import android.content.Context
import android.content.SharedPreferences
import com.google.android.gms.location.Geofence
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class NativeReceiverFlowsTest {
    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences
    private lateinit var flutterPrefs: SharedPreferences
    private lateinit var volumeService: VolumeControlService

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        prefs = context.getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        flutterPrefs.edit().clear().commit()
        context.getSharedPreferences("respectful_native_events", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        volumeService = VolumeControlService(context)
    }

    @Test
    fun geofenceEnter_ignoresDeletedMasjidIds() {
        flutterPrefs.edit()
            .putBoolean("flutter.master_silence_enabled", true)
            .putBoolean("flutter.geofence_silence_enabled", true)
            .putString(
                "flutter.saved_masjids",
                """[{"id":"kept","name":"Kept","latitude":24.7136,"longitude":46.6753}]""",
            )
            .commit()

        invokeGeofenceEnter(
            receiver = GeofenceReceiver(),
            masjidIds = listOf("deleted"),
            transition = Geofence.GEOFENCE_TRANSITION_DWELL,
        )

        assertFalse(prefs.getBoolean("geo_silenced", false))
        assertTrue(
            (
                prefs.getStringSet("active_masjid_geofences", emptySet<String>())
                    ?: emptySet<String>()
                ).isEmpty(),
        )
        assertEquals("[]", NativeEventLog.readAndClear(context))
    }

    @Test
    fun geofenceExit_keepsSilenceWhileStillInsideAnotherMasjid() {
        prefs.edit()
            .putBoolean("geo_silenced", true)
            .putStringSet("active_masjid_geofences", linkedSetOf("masjid-a", "masjid-b"))
            .commit()

        invokeGeofenceExit(
            receiver = GeofenceReceiver(),
            masjidIds = listOf("masjid-a"),
        )

        assertTrue(prefs.getBoolean("geo_silenced", false))
        assertEquals(
            setOf("masjid-b"),
            prefs.getStringSet("active_masjid_geofences", emptySet<String>())
                ?: emptySet<String>(),
        )
    }

    @Test
    fun geofenceExit_closesManualOverrideVisitAfterLeavingLastMasjid() {
        prefs.edit()
            .putBoolean("geo_visit_override_active", true)
            .putStringSet("active_masjid_geofences", linkedSetOf("masjid-a"))
            .commit()

        invokeGeofenceExit(
            receiver = GeofenceReceiver(),
            masjidIds = listOf("masjid-a"),
        )

        assertFalse(prefs.getBoolean("geo_silenced", true))
        assertFalse(prefs.getBoolean("geo_visit_override_active", true))
        assertTrue(
            (
                prefs.getStringSet("active_masjid_geofences", emptySet<String>())
                    ?: emptySet<String>()
                ).isEmpty(),
        )
    }

    @Test
    fun bootRecovery_clearsExpiredPrayerButPreservesGeoSession() {
        prefs.edit()
            .putBoolean("is_silenced", true)
            .putBoolean("geo_silenced", true)
            .putString("current_prayer", "Dhuhr")
            .putLong("window_end_ms", System.currentTimeMillis() - 1_000L)
            .putLong("silenced_at", System.currentTimeMillis() - 10_000L)
            .commit()

        invokeRecoverPrayerSession(BootReceiver())

        assertFalse(prefs.getBoolean("is_silenced", false))
        assertTrue(prefs.getBoolean("geo_silenced", false))
        assertNull(prefs.getString("current_prayer", null))
        assertEquals(0L, prefs.getLong("window_end_ms", 0L))
    }

    private fun invokeGeofenceEnter(
        receiver: GeofenceReceiver,
        masjidIds: List<String>,
        transition: Int,
    ) {
        val method = GeofenceReceiver::class.java.getDeclaredMethod(
            "handleEnterMasjid",
            Context::class.java,
            SharedPreferences::class.java,
            VolumeControlService::class.java,
            List::class.java,
            Int::class.javaPrimitiveType,
        )
        method.isAccessible = true
        method.invoke(receiver, context, prefs, volumeService, masjidIds, transition)
    }

    private fun invokeGeofenceExit(
        receiver: GeofenceReceiver,
        masjidIds: List<String>,
    ) {
        val method = GeofenceReceiver::class.java.getDeclaredMethod(
            "handleExitMasjid",
            Context::class.java,
            SharedPreferences::class.java,
            VolumeControlService::class.java,
            List::class.java,
        )
        method.isAccessible = true
        method.invoke(receiver, context, prefs, volumeService, masjidIds)
    }

    private fun invokeRecoverPrayerSession(receiver: BootReceiver) {
        val method = BootReceiver::class.java.getDeclaredMethod(
            "recoverPrayerSession",
            Context::class.java,
            SharedPreferences::class.java,
            VolumeControlService::class.java,
        )
        method.isAccessible = true
        method.invoke(receiver, context, prefs, volumeService)
    }
}
