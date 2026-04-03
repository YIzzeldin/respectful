import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:respectful/models/app_settings.dart';
import 'package:respectful/models/saved_masjid.dart';
import 'package:respectful/providers/app_providers.dart';
import 'package:respectful/services/event_log_service.dart';
import 'package:respectful/services/geofence_recovery_policy.dart';
import 'package:respectful/services/location_service.dart';
import 'package:respectful/services/masjid_storage_service.dart';
import 'package:respectful/services/storage_service.dart';
import 'package:respectful/services/volume_controller.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeStorageService extends StorageService {
  _FakeStorageService(this._settings);
  AppSettings _settings;

  @override
  AppSettings loadSettings() => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }
}

class _FakeMasjidStorageService extends MasjidStorageService {
  _FakeMasjidStorageService(this._masjids);
  List<SavedMasjid> _masjids;

  @override
  List<SavedMasjid> loadAll() => List<SavedMasjid>.from(_masjids);

  @override
  Future<void> add(SavedMasjid masjid) async {
    _masjids = [..._masjids, masjid];
  }

  @override
  Future<void> remove(String id) async {
    _masjids = _masjids.where((m) => m.id != id).toList();
  }

  @override
  Future<void> rename(String id, String newName) async {}
}

class _FakeEventLogService extends EventLogService {
  final List<String> messages = [];

  @override
  Future<void> log(EventType type, String message, {DateTime? at}) async {
    messages.add('${type.name}:$message');
  }
}

class _FakeVolumeController extends VolumeController {
  bool isGeoSilencedResult = false;
  bool clearGeoSilenceResult = true;
  bool applySilenceForGeoResult = true;
  int clearGeoSilenceCalls = 0;
  int removeGeofencesOnlyCalls = 0;
  int registerGeofencesCalls = 0;
  int disableGeofenceSilenceCalls = 0;
  int clearManualOverridesCalls = 0;
  int clearGeoOverrideCalls = 0;
  int clearPrayerOverrideCalls = 0;
  int manualExitSilenceModeCalls = 0;
  Map<String, dynamic> suppressionState = const {};
  final List<String?> appliedMasjidIds = [];

  @override
  Future<bool> isGeoSilenced() async => isGeoSilencedResult;

  @override
  Future<bool> clearGeoSilence() async {
    clearGeoSilenceCalls += 1;
    if (clearGeoSilenceResult) {
      isGeoSilencedResult = false;
    }
    return clearGeoSilenceResult;
  }

  @override
  Future<Map<String, dynamic>> getSuppressionState() async =>
      suppressionState;

  @override
  Future<String> readNativeEvents() async => '[]';

  @override
  Future<void> removeGeofencesOnly() async {
    removeGeofencesOnlyCalls += 1;
  }

  @override
  Future<bool> registerGeofences(List<Map<String, dynamic>> masjids) async {
    registerGeofencesCalls += 1;
    return true;
  }

  @override
  Future<bool> hasBackgroundLocationPermission() async => true;

  @override
  Future<bool> applySilenceForGeo({String? masjidId}) async {
    appliedMasjidIds.add(masjidId);
    if (applySilenceForGeoResult) {
      isGeoSilencedResult = true;
    }
    return applySilenceForGeoResult;
  }

  @override
  Future<List<String>> getActiveMasjidGeofences() async => const [];

  @override
  Future<void> syncGeoExitTracking() async {}

  @override
  Future<bool> disableGeofenceSilence() async {
    disableGeofenceSilenceCalls += 1;
    isGeoSilencedResult = false;
    return true;
  }

  @override
  Future<void> clearManualOverrides() async {
    clearManualOverridesCalls += 1;
  }

  @override
  Future<void> clearGeoOverride() async {
    clearGeoOverrideCalls += 1;
  }

  @override
  Future<void> clearPrayerOverride() async {
    clearPrayerOverrideCalls += 1;
  }

  @override
  Future<bool> manualExitSilenceMode() async {
    manualExitSilenceModeCalls += 1;
    isGeoSilencedResult = false;
    return true;
  }

  @override
  Future<bool> applySilenceForPrayerWindow({
    required String prayerName,
    required int windowEndMs,
  }) async => true;
}

class _FakeLocationService extends LocationService {
  _FakeLocationService(this._positions);
  final List<Position?> _positions;
  int calls = 0;

  @override
  Future<Position?> getCurrentPosition() async {
    if (_positions.isEmpty) return null;
    final index = calls < _positions.length ? calls : _positions.length - 1;
    calls += 1;
    return _positions[index];
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Position _position({required double latitude, required double longitude}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 0,
  );
}

SavedMasjid _masjid({
  required String id,
  required double latitude,
  required double longitude,
}) {
  return SavedMasjid(
    id: id,
    name: id,
    latitude: latitude,
    longitude: longitude,
    savedAt: DateTime(2025, 1, 1),
  );
}

ProviderContainer _container({
  required AppSettings settings,
  required List<SavedMasjid> masjids,
  required _FakeVolumeController controller,
  required _FakeLocationService locationService,
  required _FakeEventLogService eventLog,
}) {
  final storage = _FakeStorageService(settings);
  final masjidStorage = _FakeMasjidStorageService(masjids);
  return ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((ref) => SettingsNotifier(storage)),
      savedMasjidsProvider.overrideWith(
        (ref) => SavedMasjidsNotifier(masjidStorage),
      ),
      volumeControllerProvider.overrideWithValue(controller),
      locationServiceProvider.overrideWithValue(locationService),
      eventLogServiceProvider.overrideWithValue(eventLog),
      currentMinuteProvider.overrideWith((ref) => Stream.value(DateTime.now())),
    ],
  );
}

void main() {
  // Masjid at (24.7136, 46.6753).
  final nearMasjid = _masjid(
    id: 'riyadh',
    latitude: 24.7136,
    longitude: 46.6753,
  );

  // ~12km away — clearly outside any geofence radius
  final farPosition = _position(latitude: 24.8000, longitude: 46.8000);

  // Right at the masjid — clearly inside
  final insidePosition = _position(latitude: 24.7136, longitude: 46.6753);

  setUp(() {
    resetGeoExitRecoveryStreak();
  });

  group('checkGeoExitRecovery — Dart-side exit detection', () {
    test(
      'runs even when fastGeoExitTrackingEnabled is true (dual-layer fix)',
      () async {
        final controller = _FakeVolumeController()
          ..isGeoSilencedResult = true;
        final locationService =
            _FakeLocationService(List.filled(10, farPosition));
        final eventLog = _FakeEventLogService();

        final container = _container(
          settings: AppSettings.defaults().copyWith(
            fastGeoExitTrackingEnabled: true, // <-- KEY: would have bailed out before fix
          ),
          masjids: [nearMasjid],
          controller: controller,
          locationService: locationService,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        // First call: streak=1, not enough to clear yet
        final result1 = await checkGeoExitRecovery(container);
        expect(result1, false);
        expect(locationService.calls, 1,
            reason: 'GPS should have been checked, NOT bailed out');
        expect(controller.clearGeoSilenceCalls, 0);

        // Build streak to threshold
        for (var i = 1;
            i < GeofenceRecoveryPolicy.exitChecksBeforeRestore - 1;
            i++) {
          expect(await checkGeoExitRecovery(container), false);
        }

        // Final call: reaches threshold, clears
        final resultFinal = await checkGeoExitRecovery(container);
        expect(resultFinal, true);
        expect(controller.clearGeoSilenceCalls, 1,
            reason: 'Should have cleared geo silence after '
                '${GeofenceRecoveryPolicy.exitChecksBeforeRestore} outside checks');
        expect(
          eventLog.messages
              .any((m) => m.contains('Dart exit recovery cleared')),
          true,
        );
      },
    );

    test('resets streak when GPS says user is back inside', () async {
      final controller = _FakeVolumeController()..isGeoSilencedResult = true;
      final locationService = _FakeLocationService([
        farPosition, // outside
        insidePosition, // back inside
        ...List.filled(GeofenceRecoveryPolicy.exitChecksBeforeRestore + 1, farPosition),
      ]);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults(),
        masjids: [nearMasjid],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      // Call 1: outside → streak=1
      await checkGeoExitRecovery(container);
      expect(controller.clearGeoSilenceCalls, 0);

      // Call 2: inside → streak resets to 0
      await checkGeoExitRecovery(container);
      expect(controller.clearGeoSilenceCalls, 0);

      // Calls 3..N: outside, build streak from 0 again
      for (var i = 0;
          i < GeofenceRecoveryPolicy.exitChecksBeforeRestore - 1;
          i++) {
        expect(await checkGeoExitRecovery(container), false,
            reason: 'Streak was reset by inside, should be ${i + 1} not ${i + 3}');
      }

      // Final: reaches threshold → clears
      expect(await checkGeoExitRecovery(container), true);
      expect(controller.clearGeoSilenceCalls, 1);
    });

    test('does not run when geo silence is not active', () async {
      final controller = _FakeVolumeController()
        ..isGeoSilencedResult = false;
      final locationService = _FakeLocationService([farPosition]);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults(),
        masjids: [nearMasjid],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      final result = await checkGeoExitRecovery(container);

      expect(result, false);
      expect(locationService.calls, 0,
          reason: 'Should not check GPS when not geo-silenced');
    });

    test('does not run when no masjids are saved', () async {
      final controller = _FakeVolumeController()..isGeoSilencedResult = true;
      final locationService = _FakeLocationService([farPosition]);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults(),
        masjids: const [],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      final result = await checkGeoExitRecovery(container);

      expect(result, false);
      expect(locationService.calls, 0);
    });

    test('does not run when master silence is disabled', () async {
      final controller = _FakeVolumeController()..isGeoSilencedResult = true;
      final locationService = _FakeLocationService([farPosition]);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults().copyWith(masterSilenceEnabled: false),
        masjids: [nearMasjid],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      final result = await checkGeoExitRecovery(container);

      expect(result, false);
      expect(locationService.calls, 0);
    });

    test('logs intermediate streak progress', () async {
      final controller = _FakeVolumeController()..isGeoSilencedResult = true;
      final locationService = _FakeLocationService([farPosition]);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults(),
        masjids: [nearMasjid],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      await checkGeoExitRecovery(container);

      expect(
        eventLog.messages.any((m) => m.contains('outside check #1/')),
        true,
        reason: 'Should log streak progress',
      );
    });
  });

  group('repairMasjidPresence — Dart-side enter detection', () {
    test('silences when GPS detects user inside masjid but native missed it',
        () async {
      final controller = _FakeVolumeController()
        ..isGeoSilencedResult = false;
      final locationService = _FakeLocationService([insidePosition]);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults(),
        masjids: [nearMasjid],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      final repaired = await repairMasjidPresence(
        container,
        attempts: 1,
        retryDelay: Duration.zero,
      );

      expect(repaired, true);
      expect(locationService.calls, 1);
      expect(controller.appliedMasjidIds, ['riyadh']);
    });

    test('does nothing when user is far from any masjid', () async {
      final controller = _FakeVolumeController()
        ..isGeoSilencedResult = false;
      final locationService = _FakeLocationService([farPosition]);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults(),
        masjids: [nearMasjid],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      final repaired = await repairMasjidPresence(
        container,
        attempts: 1,
        retryDelay: Duration.zero,
      );

      expect(repaired, false);
      expect(locationService.calls, 1);
      expect(controller.appliedMasjidIds, isEmpty);
    });
  });

  group('end-to-end scenario: approach → leave → return', () {
    test('full cycle via Dart-side repair and exit recovery', () async {
      // Phase 1: User near masjid — GPS repair detects it
      final controller = _FakeVolumeController()
        ..isGeoSilencedResult = false;
      final locationService = _FakeLocationService([
        insidePosition, // repair: inside → silence
        ...List.filled(GeofenceRecoveryPolicy.exitChecksBeforeRestore, farPosition),
        insidePosition, // repair: return → silence again
      ]);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults().copyWith(
          fastGeoExitTrackingEnabled: true,
        ),
        masjids: [nearMasjid],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      // Phase 1: GPS repair detects user inside masjid
      final repaired = await repairMasjidPresence(
        container,
        attempts: 1,
        retryDelay: Duration.zero,
      );
      expect(repaired, true);
      expect(locationService.calls, 1);
      expect(controller.appliedMasjidIds, ['riyadh'],
          reason: 'Phase 1: GPS repair should silence');

      // Phase 2: User leaves — exit recovery runs
      controller.isGeoSilencedResult = true;

      // Build exit streak to threshold
      for (var i = 0;
          i < GeofenceRecoveryPolicy.exitChecksBeforeRestore;
          i++) {
        final r = await checkGeoExitRecovery(container);
        if (i < GeofenceRecoveryPolicy.exitChecksBeforeRestore - 1) {
          expect(r, false);
        } else {
          expect(r, true);
        }
      }
      expect(controller.clearGeoSilenceCalls, 1,
          reason: 'Phase 2: Exit recovery should restore phone');

      // Phase 3: User returns — GPS repair re-detects
      controller.isGeoSilencedResult = false;
      controller.appliedMasjidIds.clear();
      final repaired2 = await repairMasjidPresence(
        container,
        attempts: 1,
        retryDelay: Duration.zero,
      );
      expect(repaired2, true);
      // 1 (calibration) + exitChecks + 1 (return calibration)
      expect(locationService.calls,
          1 + GeofenceRecoveryPolicy.exitChecksBeforeRestore + 1);
      expect(controller.appliedMasjidIds, ['riyadh'],
          reason: 'Phase 3: Return should re-silence');
    });
  });

  group('real-world journey: the exact bug scenario', () {
    // Masjid at (24.71360, 46.67530), radius 150m.
    // Recovery policy: enter threshold = 150 - max(20, 150*0.10) = 130m
    //                  exit threshold  = 150 + max(5, 150*0.03) = 155m
    //
    // GPS positions along the user's walk:
    //   300m away  → outside, no action
    //   100m away  → inside enter threshold (130m), should silence
    //   0m (at masjid) → clearly inside
    //   200m away  → outside exit threshold (155m)
    //   500m away  → clearly outside

    // ~300m north of masjid
    final pos300mAway = _position(latitude: 24.71630, longitude: 46.67530);
    // ~100m north of masjid
    final pos100mAway = _position(latitude: 24.71450, longitude: 46.67530);
    // At the masjid
    final posAtMasjid = _position(latitude: 24.71360, longitude: 46.67530);
    // ~200m north (just past exit threshold)
    final pos200mAway = _position(latitude: 24.71540, longitude: 46.67530);
    // ~500m north (clearly gone)
    final pos500mAway = _position(latitude: 24.71810, longitude: 46.67530);

    test(
      'outside → approach → silence → manual exit → toggle off/on → '
      're-silence → walk away → phone restores',
      () async {
        // ---------------------------------------------------------------
        // Setup: User has one saved masjid, fast exit tracking enabled.
        // GPS positions will be fed in order as the scenario progresses.
        // ---------------------------------------------------------------
        final controller = _FakeVolumeController();
        final locationService = _FakeLocationService([
          // Step 1: GPS calibration while 300m away → should NOT silence
          pos300mAway,
          // Step 3: Toggle ON triggers reEvaluateCurrentSuppression → GPS check
          //         Now at 100m → inside enter threshold → silence
          pos100mAway,
          // Steps 5+: Exit recovery checks → walking away → CLEAR
          ...List.filled(GeofenceRecoveryPolicy.exitChecksBeforeRestore, pos500mAway),
        ]);
        final eventLog = _FakeEventLogService();
        final container = _container(
          settings: AppSettings.defaults().copyWith(
            fastGeoExitTrackingEnabled: true,
            geofenceSilenceEnabled: true,
          ),
          masjids: [nearMasjid],
          controller: controller,
          locationService: locationService,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        // ---------------------------------------------------------------
        // Step 1: User is 300m away. GPS calibration runs.
        //         Should NOT silence (300m > 130m enter threshold).
        // ---------------------------------------------------------------
        final repair1 = await repairMasjidPresence(
          container,
          attempts: 1,
          retryDelay: Duration.zero,
        );
        expect(repair1, false,
            reason: 'Step 1: 300m away — should NOT silence');
        expect(controller.appliedMasjidIds, isEmpty);
        expect(controller.isGeoSilencedResult, false);

        // ---------------------------------------------------------------
        // Step 2: User approaches, now 100m away. The native geofence
        //         SHOULD have fired ENTER, but it didn't (the original bug).
        //         User opens app and toggles geofence OFF then ON.
        //
        //         Toggle OFF: disableGeofenceSilence clears state.
        // ---------------------------------------------------------------
        await container
            .read(settingsProvider.notifier)
            .setGeofenceSilenceEnabled(false);
        await controller.disableGeofenceSilence();

        expect(controller.disableGeofenceSilenceCalls, 1);
        expect(controller.isGeoSilencedResult, false);

        // ---------------------------------------------------------------
        // Step 3: Toggle ON: reEvaluateCurrentSuppression runs, which
        //         calls repairMasjidPresence. GPS now reads 100m away
        //         → inside enter threshold → phone silences.
        // ---------------------------------------------------------------
        await container
            .read(settingsProvider.notifier)
            .setGeofenceSilenceEnabled(true);
        await reEvaluateCurrentSuppression(
          container,
          checkPrayer: false,
          checkGeo: true,
          clearPrayerOverride: false,
          clearGeoOverride: true,
        );

        expect(controller.appliedMasjidIds, ['riyadh'],
            reason: 'Step 3: Toggle ON → GPS at 100m → should silence');
        expect(controller.isGeoSilencedResult, true);

        // ---------------------------------------------------------------
        // Step 4: User is at the masjid, prays, then starts walking away.
        //         The native geofence EXIT doesn't fire (second bug).
        //         Dart-side exit recovery kicks in.
        // ---------------------------------------------------------------
        // (controller.isGeoSilencedResult is already true from Step 3)

        // ---------------------------------------------------------------
        // Steps 5+: Exit recovery — GPS reads far away repeatedly.
        //           After enough consecutive outside checks → RESTORE.
        // ---------------------------------------------------------------
        for (var i = 0;
            i < GeofenceRecoveryPolicy.exitChecksBeforeRestore;
            i++) {
          final r = await checkGeoExitRecovery(container);
          if (i < GeofenceRecoveryPolicy.exitChecksBeforeRestore - 1) {
            expect(r, false,
                reason: 'Step ${5 + i}: Outside check ${i + 1}, need ${GeofenceRecoveryPolicy.exitChecksBeforeRestore}');
          } else {
            expect(r, true,
                reason: 'Step ${5 + i}: Final outside check → phone should restore');
          }
        }
        expect(controller.clearGeoSilenceCalls, 1);
        expect(controller.isGeoSilencedResult, false,
            reason: 'Phone should be back to normal after leaving');

        // ---------------------------------------------------------------
        // Verify the event log tells the full story
        // ---------------------------------------------------------------
        expect(
          eventLog.messages
              .any((m) => m.contains('Immediate masjid presence check')),
          true,
          reason: 'Should log the GPS-based enter repair',
        );
        expect(
          eventLog.messages
              .any((m) => m.contains('Dart exit recovery cleared')),
          true,
          reason: 'Should log the exit recovery restore',
        );
      },
    );

    test(
      'outside → approach → silence → manual exit silence button → '
      'leave masjid → override clears automatically',
      () async {
        // ---------------------------------------------------------------
        // This tests the scenario where the user presses "Exit Silence
        // Mode" while at the masjid, then physically leaves.
        // The geo_visit_override should prevent re-silence, and when
        // the user walks away the override should clear.
        // ---------------------------------------------------------------
        final controller = _FakeVolumeController();
        final locationService = _FakeLocationService([
          posAtMasjid, // Step 1: GPS repair → at masjid → silence
          pos500mAway, // Step 3: Exit recovery → far away
          pos500mAway, // Step 4: Exit recovery → still far → clear
        ]);
        final eventLog = _FakeEventLogService();
        final container = _container(
          settings: AppSettings.defaults().copyWith(
            fastGeoExitTrackingEnabled: true,
          ),
          masjids: [nearMasjid],
          controller: controller,
          locationService: locationService,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        // Step 1: Arrive at masjid — GPS repair silences
        final repaired = await repairMasjidPresence(
          container,
          attempts: 1,
          retryDelay: Duration.zero,
        );
        expect(repaired, true, reason: 'Step 1: At masjid → silence');

        // Step 2: User presses "Exit Silence Mode" button
        await controller.manualExitSilenceMode();
        expect(controller.manualExitSilenceModeCalls, 1);
        expect(controller.isGeoSilencedResult, false,
            reason: 'Step 2: Manual exit → phone restored');

        // Step 3-4: User walks away. Exit recovery runs but phone
        //           is already not silenced. Should be a no-op.
        final exit1 = await checkGeoExitRecovery(container);
        expect(exit1, false,
            reason: 'Step 3: Not geo-silenced, exit recovery is no-op');
        expect(controller.clearGeoSilenceCalls, 0,
            reason: 'No geo silence to clear');
      },
    );
  });
}
