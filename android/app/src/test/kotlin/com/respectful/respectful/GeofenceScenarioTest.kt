package com.respectful.respectful

import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import com.google.android.gms.location.Geofence
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows

/**
 * End-to-end geofence scenario tests that simulate the real-world
 * sequences reported as bugs:
 *   1. Approaching a masjid (ENTER fires)
 *   2. Leaving a masjid (EXIT fires → phone restores)
 *   3. Manual exit while at masjid, then EXIT fires
 *   4. Re-registration while already inside (INITIAL_TRIGGER_ENTER)
 *   5. EXIT after repair-based silence (applySilenceForGeo path)
 *   6. Multiple masjids: exit one, still inside another
 *   7. Delete active masjid, re-register → no phantom re-entry
 */
@RunWith(RobolectricTestRunner::class)
class GeofenceScenarioTest {
    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences
    private lateinit var flutterPrefs: SharedPreferences
    private lateinit var volumeService: VolumeControlService
    private lateinit var receiver: GeofenceReceiver

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        prefs = context.getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        flutterPrefs.edit().clear().commit()
        context.getSharedPreferences("respectful_native_events", Context.MODE_PRIVATE)
            .edit().clear().commit()
        volumeService = VolumeControlService(context)
        receiver = GeofenceReceiver()

        // Grant DND permission so applySilence() succeeds in tests
        val notifManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        Shadows.shadowOf(notifManager).setNotificationPolicyAccessGranted(true)

        // Enable geofence silence by default
        flutterPrefs.edit()
            .putBoolean("flutter.master_silence_enabled", true)
            .putBoolean("flutter.geofence_silence_enabled", true)
            .putString(
                "flutter.saved_masjids",
                """[{"id":"masjid-a","name":"Masjid A","latitude":24.7136,"longitude":46.6753},
                    {"id":"masjid-b","name":"Masjid B","latitude":24.7200,"longitude":46.6800}]""",
            )
            .commit()
    }

    // ========================================================================
    // Scenario 1: Normal approach → enter → silence
    // ========================================================================
    @Test
    fun scenario1_approachMasjid_enterSilences() {
        assertFalse(prefs.getBoolean("geo_silenced", false))

        invokeEnter(listOf("masjid-a"))

        assertTrue(prefs.getBoolean("geo_silenced", false))
        assertTrue(prefs.getLong("geo_silenced_at", 0L) > 0L)
        assertEquals(
            setOf("masjid-a"),
            prefs.getStringSet("active_masjid_geofences", emptySet()),
        )
    }

    // ========================================================================
    // Scenario 2: Enter → leave → phone restores
    // ========================================================================
    @Test
    fun scenario2_enterThenExit_restoresPhone() {
        invokeEnter(listOf("masjid-a"))
        assertTrue(prefs.getBoolean("geo_silenced", false))

        invokeExit(listOf("masjid-a"))

        assertFalse(prefs.getBoolean("geo_silenced", false))
        assertTrue(
            (prefs.getStringSet("active_masjid_geofences", emptySet()) ?: emptySet()).isEmpty(),
        )
    }

    // ========================================================================
    // Scenario 3: Manual exit while at masjid → geo_visit_override blocks
    //             re-silence, then EXIT clears the override visit
    // ========================================================================
    @Test
    fun scenario3_manualExitThenLeave_clearsOverride() {
        // Enter masjid
        invokeEnter(listOf("masjid-a"))
        assertTrue(prefs.getBoolean("geo_silenced", false))

        // User manually exits silence mode → sets geo_visit_override
        SuppressionSessionStore.markGeoVisitOverridden(prefs)
        assertFalse(prefs.getBoolean("geo_silenced", false))
        assertTrue(SuppressionSessionStore.isGeoVisitOverrideActive(prefs))

        // A new ENTER fires (e.g., from DWELL or re-registration) — should NOT re-silence
        invokeEnter(listOf("masjid-a"), Geofence.GEOFENCE_TRANSITION_DWELL)
        assertFalse(prefs.getBoolean("geo_silenced", false))

        // User leaves the masjid → EXIT should clear the override
        invokeExit(listOf("masjid-a"))
        assertFalse(SuppressionSessionStore.isGeoVisitOverrideActive(prefs))
        assertFalse(prefs.getBoolean("geo_silenced", false))
    }

    // ========================================================================
    // Scenario 4: Re-registration while inside (simulates INITIAL_TRIGGER_ENTER)
    //             Phone should remain silenced, active set updated
    // ========================================================================
    @Test
    fun scenario4_reRegistrationWhileInside_maintainsSilence() {
        // Already silenced by previous enter
        invokeEnter(listOf("masjid-a"))
        assertTrue(prefs.getBoolean("geo_silenced", false))

        // Re-registration fires INITIAL_TRIGGER_ENTER for same masjid
        invokeEnter(listOf("masjid-a"))
        assertTrue(prefs.getBoolean("geo_silenced", false))
        assertEquals(
            setOf("masjid-a"),
            prefs.getStringSet("active_masjid_geofences", emptySet()),
        )
    }

    // ========================================================================
    // Scenario 5: Repair-based silence (applySilenceForGeo from Dart side)
    //             followed by native EXIT → should restore phone
    // ========================================================================
    @Test
    fun scenario5_repairSilenceThenNativeExit_restores() {
        // Simulate Dart-side repair: sets geo_silenced=true + active set
        prefs.edit()
            .putBoolean("geo_silenced", true)
            .putLong("geo_silenced_at", System.currentTimeMillis())
            .putStringSet("active_masjid_geofences", mutableSetOf("masjid-a"))
            .commit()

        // Native EXIT fires for the same masjid
        invokeExit(listOf("masjid-a"))

        assertFalse(prefs.getBoolean("geo_silenced", false))
    }

    // ========================================================================
    // Scenario 6: Inside two masjids, exit one → stays silent
    //             Exit second → restores
    // ========================================================================
    @Test
    fun scenario6_multipleMasjids_exitOneByOne() {
        invokeEnter(listOf("masjid-a"))
        invokeEnter(listOf("masjid-b"))
        assertTrue(prefs.getBoolean("geo_silenced", false))
        assertEquals(
            setOf("masjid-a", "masjid-b"),
            prefs.getStringSet("active_masjid_geofences", emptySet()),
        )

        // Exit masjid-a — still in masjid-b
        invokeExit(listOf("masjid-a"))
        assertTrue(prefs.getBoolean("geo_silenced", false))
        assertEquals(
            setOf("masjid-b"),
            prefs.getStringSet("active_masjid_geofences", emptySet()),
        )

        // Exit masjid-b — restores
        invokeExit(listOf("masjid-b"))
        assertFalse(prefs.getBoolean("geo_silenced", false))
    }

    // ========================================================================
    // Scenario 7: Delete active masjid → re-register → no phantom silence
    //             from deleted masjid ID
    // ========================================================================
    @Test
    fun scenario7_deletedMasjidDoesNotCausePhantomSilence() {
        // Update saved masjids to only contain masjid-b
        flutterPrefs.edit()
            .putString(
                "flutter.saved_masjids",
                """[{"id":"masjid-b","name":"Masjid B","latitude":24.7200,"longitude":46.6800}]""",
            )
            .commit()

        // INITIAL_TRIGGER_ENTER fires for deleted masjid-a — should be ignored
        invokeEnter(listOf("masjid-a"))
        assertFalse(prefs.getBoolean("geo_silenced", false))
        assertTrue(
            (prefs.getStringSet("active_masjid_geofences", emptySet()) ?: emptySet()).isEmpty(),
        )
    }

    // ========================================================================
    // Scenario 8: Enter while prayer is already active → geo_silenced set
    //             but phone not double-silenced. Exit geo while prayer active
    //             → stays silent (prayer keeps it).
    // ========================================================================
    @Test
    fun scenario8_enterDuringPrayer_exitGeoDuringPrayer() {
        // Prayer is already silencing the phone
        prefs.edit()
            .putBoolean("is_silenced", true)
            .putString("current_prayer", "Dhuhr")
            .commit()

        invokeEnter(listOf("masjid-a"))
        assertTrue(prefs.getBoolean("geo_silenced", false))
        assertTrue(prefs.getBoolean("is_silenced", false))

        // Exit masjid while prayer is still active — geo clears but phone stays silent
        invokeExit(listOf("masjid-a"))
        assertFalse(prefs.getBoolean("geo_silenced", false))
        assertTrue(prefs.getBoolean("is_silenced", false))
    }

    // ========================================================================
    // Scenario 9: Manual exit at masjid, return to silence by entering another
    //             masjid (override should block new entries within same visit)
    // ========================================================================
    @Test
    fun scenario9_manualExitThenEnterAnotherMasjid_overrideBlocks() {
        invokeEnter(listOf("masjid-a"))
        assertTrue(prefs.getBoolean("geo_silenced", false))

        // Manual exit
        SuppressionSessionStore.markGeoVisitOverridden(prefs)

        // Enter a different masjid — should be blocked by visit override
        invokeEnter(listOf("masjid-b"), Geofence.GEOFENCE_TRANSITION_DWELL)
        assertFalse(prefs.getBoolean("geo_silenced", false))

        // But active set should include both (for tracking)
        val active = prefs.getStringSet("active_masjid_geofences", emptySet()) ?: emptySet()
        assertTrue(active.contains("masjid-b"))
    }

    // ========================================================================
    // Scenario 10: Geofence disabled → ENTER with non-saved IDs ignored
    //              (The isGeofenceSilenceEnabled check lives in onReceive(),
    //               not handleEnterMasjid(). This test verifies the saved-ID
    //               filter by using an ID not in saved_masjids.)
    // ========================================================================
    @Test
    fun scenario10_unsavedMasjidId_transitionIgnored() {
        // Only masjid-a and masjid-b are saved; "unknown" is not
        invokeEnter(listOf("unknown"))

        assertFalse(prefs.getBoolean("geo_silenced", false))
        assertTrue(
            (prefs.getStringSet("active_masjid_geofences", emptySet()) ?: emptySet()).isEmpty(),
        )
    }

    // ========================================================================
    // Helpers — invoke receiver methods via reflection
    // ========================================================================

    private fun invokeEnter(
        masjidIds: List<String>,
        transition: Int = Geofence.GEOFENCE_TRANSITION_DWELL,
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

    private fun invokeExit(masjidIds: List<String>) {
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
}
