import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:respectful/l10n/app_localizations.dart';
import 'package:respectful/models/app_settings.dart';
import 'package:respectful/models/prayer_day.dart';
import 'package:respectful/models/saved_masjid.dart';
import 'package:respectful/models/suppression_state.dart';
import 'package:respectful/providers/app_providers.dart';
import 'package:respectful/screens/home_screen.dart';
import 'package:respectful/screens/settings_screen.dart';
import 'package:respectful/services/event_log_service.dart';
import 'package:respectful/services/location_service.dart';
import 'package:respectful/services/masjid_storage_service.dart';
import 'package:respectful/services/storage_service.dart';
import 'package:respectful/services/volume_controller.dart';

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
  Future<void> rename(String id, String newName) async {
    _masjids = _masjids
        .map(
          (m) => m.id == id
              ? SavedMasjid(
                  id: m.id,
                  name: newName,
                  latitude: m.latitude,
                  longitude: m.longitude,
                  savedAt: m.savedAt,
                )
              : m,
        )
        .toList();
  }
}

class _FakeEventLogService extends EventLogService {
  final List<String> messages = [];

  @override
  Future<void> log(EventType type, String message, {DateTime? at}) async {
    messages.add('${type.name}:$message');
  }
}

class _FakeVolumeController extends VolumeController {
  int disableTimeBasedSilenceCalls = 0;
  int disableGeofenceSilenceCalls = 0;
  int removeGeofencesOnlyCalls = 0;
  int registerGeofencesCalls = 0;
  List<String> removedGeofenceIds = [];
  int clearManualOverridesCalls = 0;
  int clearPrayerOverrideCalls = 0;
  int clearGeoOverrideCalls = 0;
  int clearGeoSilenceCalls = 0;
  int manualExitSilenceModeCalls = 0;
  int syncGeoExitTrackingCalls = 0;
  bool applySilenceForGeoResult = true;
  bool applySilenceForPrayerWindowResult = true;
  bool clearGeoSilenceResult = true;
  bool isGeoSilencedResult = false;
  bool manualExitSilenceModeResult = true;
  Map<String, dynamic> suppressionState = const {};
  List<String> activeMasjidIds = const [];
  int geoSilencedAtMs = 0;
  final List<String?> appliedMasjidIds = [];
  final List<(String, int)> appliedPrayerWindows = [];

  @override
  Future<bool> disableTimeBasedSilence() async {
    disableTimeBasedSilenceCalls += 1;
    final next = Map<String, dynamic>.from(suppressionState);
    next['isPrayerSilenced'] = false;
    next['currentPrayer'] = null;
    suppressionState = next;
    return true;
  }

  @override
  Future<bool> disableGeofenceSilence() async {
    disableGeofenceSilenceCalls += 1;
    final next = Map<String, dynamic>.from(suppressionState);
    next['isGeoSilenced'] = false;
    next['activeMasjidIds'] = const <String>[];
    suppressionState = next;
    activeMasjidIds = const [];
    return true;
  }

  @override
  Future<void> removeGeofencesOnly() async {
    removeGeofencesOnlyCalls += 1;
  }

  @override
  Future<void> removeGeofencesByIds(List<String> ids) async {
    removedGeofenceIds.addAll(ids);
  }

  @override
  Future<bool> registerGeofences(List<Map<String, dynamic>> masjids) async {
    registerGeofencesCalls += 1;
    return true;
  }

  @override
  Future<bool> hasBackgroundLocationPermission() async {
    return true;
  }

  @override
  Future<bool> applySilenceForGeo({String? masjidId}) async {
    appliedMasjidIds.add(masjidId);
    isGeoSilencedResult = applySilenceForGeoResult;
    if (applySilenceForGeoResult) {
      activeMasjidIds = masjidId == null ? const [] : [masjidId];
      geoSilencedAtMs = DateTime.now().millisecondsSinceEpoch;
      suppressionState = {
        ...suppressionState,
        'isGeoSilenced': true,
        'activeMasjidIds': activeMasjidIds,
      };
    }
    return applySilenceForGeoResult;
  }

  @override
  Future<bool> applySilenceForPrayerWindow({
    required String prayerName,
    required int windowEndMs,
  }) async {
    appliedPrayerWindows.add((prayerName, windowEndMs));
    if (applySilenceForPrayerWindowResult) {
      suppressionState = {
        ...suppressionState,
        'isPrayerSilenced': true,
        'currentPrayer': prayerName,
        'prayerWindowEndMs': windowEndMs,
      };
    }
    return applySilenceForPrayerWindowResult;
  }

  @override
  Future<void> clearManualOverrides() async {
    clearManualOverridesCalls += 1;
  }

  @override
  Future<void> clearPrayerOverride() async {
    clearPrayerOverrideCalls += 1;
  }

  @override
  Future<void> clearGeoOverride() async {
    clearGeoOverrideCalls += 1;
  }

  @override
  Future<Map<String, dynamic>> getSuppressionState() async {
    return suppressionState;
  }

  @override
  Future<String> readNativeEvents() async {
    return '[]';
  }

  @override
  Future<bool> isGeoSilenced() async {
    return isGeoSilencedResult;
  }

  @override
  Future<bool> clearGeoSilence() async {
    clearGeoSilenceCalls += 1;
    if (clearGeoSilenceResult) {
      isGeoSilencedResult = false;
      activeMasjidIds = const [];
      suppressionState = {
        ...suppressionState,
        'isGeoSilenced': false,
        'activeMasjidIds': const <String>[],
      };
    }
    return clearGeoSilenceResult;
  }

  @override
  Future<int> getGeoSilencedAt() async {
    return geoSilencedAtMs;
  }

  @override
  Future<List<String>> getActiveMasjidGeofences() async {
    return activeMasjidIds;
  }

  @override
  Future<bool> manualExitSilenceMode() async {
    manualExitSilenceModeCalls += 1;
    if (manualExitSilenceModeResult) {
      suppressionState = const {};
      activeMasjidIds = const [];
      isGeoSilencedResult = false;
    }
    return manualExitSilenceModeResult;
  }

  @override
  Future<void> syncGeoExitTracking() async {
    syncGeoExitTrackingCalls += 1;
  }
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

ProviderContainer _container({
  required AppSettings settings,
  required List<SavedMasjid> masjids,
  required _FakeVolumeController controller,
  required _FakeLocationService locationService,
  required _FakeEventLogService eventLog,
  List<Override> overrides = const [],
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
      currentMinuteProvider.overrideWith((ref) => Stream.value(_now)),
      ...overrides,
    ],
  );
}

Widget _testApp(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

final _now = DateTime(2026, 4, 1, 12, 0);

PrayerDay _samplePrayerDay() {
  return PrayerDay(
    date: DateTime(2026, 4, 1),
    fajr: DateTime(2026, 4, 1, 4, 30),
    dhuhr: DateTime(2026, 4, 1, 12, 10),
    asr: DateTime(2026, 4, 1, 15, 30),
    maghrib: DateTime(2026, 4, 1, 18, 5),
    isha: DateTime(2026, 4, 1, 19, 30),
  );
}

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

void main() {
  group('settings toggle flows', () {
    testWidgets('turning off geofence silence only disables geofence mode', (
      tester,
    ) async {
      final controller = _FakeVolumeController()
        ..suppressionState = {
          'isGeoSilenced': true,
          'activeMasjidIds': ['riyadh'],
        };
      final locationService = _FakeLocationService(const []);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults().copyWith(
          geofenceSilenceEnabled: true,
          timeBasedSilenceEnabled: true,
        ),
        masjids: const [],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_testApp(container, const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).at(0));
      await tester.pumpAndSettle();

      final settings = container.read(settingsProvider);
      expect(settings.masterSilenceEnabled, true);
      expect(settings.geofenceSilenceEnabled, false);
      expect(settings.timeBasedSilenceEnabled, true);
      expect(controller.disableGeofenceSilenceCalls, 1);
      expect(controller.disableTimeBasedSilenceCalls, 0);
    });

    testWidgets('turning off time-based silence only disables prayer mode', (
      tester,
    ) async {
      final controller = _FakeVolumeController()
        ..suppressionState = {
          'isPrayerSilenced': true,
          'currentPrayer': 'Dhuhr',
        };
      final locationService = _FakeLocationService(const []);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults().copyWith(
          geofenceSilenceEnabled: true,
          timeBasedSilenceEnabled: true,
        ),
        masjids: const [],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_testApp(container, const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();

      final settings = container.read(settingsProvider);
      expect(settings.masterSilenceEnabled, true);
      expect(settings.geofenceSilenceEnabled, true);
      expect(settings.timeBasedSilenceEnabled, false);
      expect(controller.disableGeofenceSilenceCalls, 0);
      expect(controller.disableTimeBasedSilenceCalls, 1);
    });

    testWidgets(
      'changing fast exit tracking while geo-silenced does not restore the phone',
      (tester) async {
        final controller = _FakeVolumeController()
          ..isGeoSilencedResult = true
          ..suppressionState = {
            'isGeoSilenced': true,
            'activeMasjidIds': ['riyadh'],
          };
        final locationService = _FakeLocationService(const []);
        final eventLog = _FakeEventLogService();
        final container = _container(
          settings: AppSettings.defaults().copyWith(
            geofenceSilenceEnabled: true,
            fastGeoExitTrackingEnabled: false,
          ),
          masjids: [
            _masjid(id: 'riyadh', latitude: 24.7136, longitude: 46.6753),
          ],
          controller: controller,
          locationService: locationService,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_testApp(container, const SettingsScreen()));
        await tester.pumpAndSettle();

        final fastExitLabel = find.text('Faster Exit Detection');
        await tester.ensureVisible(fastExitLabel);
        await tester.pumpAndSettle();
        final fastExitRow = find.ancestor(
          of: fastExitLabel,
          matching: find.byType(Row),
        );
        await tester.tap(
          find.descendant(of: fastExitRow.first, matching: find.byType(Switch)),
        );
        await tester.pumpAndSettle();

        final settings = container.read(settingsProvider);
        expect(settings.fastGeoExitTrackingEnabled, true);
        expect(controller.syncGeoExitTrackingCalls, 1);
        expect(controller.disableGeofenceSilenceCalls, 0);
        expect(controller.disableTimeBasedSilenceCalls, 0);
        expect(controller.clearGeoSilenceCalls, 0);
      },
    );

    testWidgets(
      'changing pass-through protection while geo-silenced keeps silence active',
      (tester) async {
        final controller = _FakeVolumeController()
          ..isGeoSilencedResult = true
          ..suppressionState = {
            'isGeoSilenced': true,
            'activeMasjidIds': ['riyadh'],
          };
        final locationService = _FakeLocationService(const []);
        final eventLog = _FakeEventLogService();
        final container = _container(
          settings: AppSettings.defaults().copyWith(
            geofenceSilenceEnabled: true,
            requireMasjidDwellBeforeSilence: false,
          ),
          masjids: [
            _masjid(id: 'riyadh', latitude: 24.7136, longitude: 46.6753),
          ],
          controller: controller,
          locationService: locationService,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_testApp(container, const SettingsScreen()));
        await tester.pumpAndSettle();

        final passThroughLabel = find.text('Pass-Through Protection');
        await tester.ensureVisible(passThroughLabel);
        await tester.pumpAndSettle();
        final passThroughRow = find.ancestor(
          of: passThroughLabel,
          matching: find.byType(Row),
        );
        await tester.tap(
          find.descendant(
            of: passThroughRow.first,
            matching: find.byType(Switch),
          ),
        );
        await tester.pumpAndSettle();

        final settings = container.read(settingsProvider);
        expect(settings.requireMasjidDwellBeforeSilence, true);
        expect(controller.disableGeofenceSilenceCalls, 0);
        expect(controller.disableTimeBasedSilenceCalls, 0);
        expect(controller.clearGeoSilenceCalls, 0);
        expect(controller.syncGeoExitTrackingCalls, 0);
      },
    );

    testWidgets(
      'changing silence level while silenced only updates the preference',
      (tester) async {
        final controller = _FakeVolumeController()
          ..isGeoSilencedResult = true
          ..suppressionState = {
            'isGeoSilenced': true,
            'activeMasjidIds': ['riyadh'],
          };
        final locationService = _FakeLocationService(const []);
        final eventLog = _FakeEventLogService();
        final container = _container(
          settings: AppSettings.defaults().copyWith(
            geofenceSilenceEnabled: true,
            silenceLevel: SilenceLevel.totalSilence,
          ),
          masjids: [
            _masjid(id: 'riyadh', latitude: 24.7136, longitude: 46.6753),
          ],
          controller: controller,
          locationService: locationService,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_testApp(container, const SettingsScreen()));
        await tester.pumpAndSettle();

        final prioritySilence = find.textContaining('Priority Silence');
        await tester.scrollUntilVisible(
          prioritySilence,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(prioritySilence);
        await tester.pumpAndSettle();

        final settings = container.read(settingsProvider);
        expect(settings.silenceLevel, SilenceLevel.prioritySilence);
        expect(controller.disableGeofenceSilenceCalls, 0);
        expect(controller.disableTimeBasedSilenceCalls, 0);
        expect(controller.clearGeoSilenceCalls, 0);
      },
    );
  });

  group('master toggle flows', () {
    testWidgets(
      'turning master off restores now without clearing saved mode settings',
      (tester) async {
        final controller = _FakeVolumeController();
        final locationService = _FakeLocationService(const []);
        final eventLog = _FakeEventLogService();
        final prayerDay = _samplePrayerDay();
        final container = _container(
          settings: AppSettings.defaults().copyWith(
            masterSilenceEnabled: true,
            geofenceSilenceEnabled: true,
            timeBasedSilenceEnabled: true,
          ),
          masjids: const [],
          controller: controller,
          locationService: locationService,
          eventLog: eventLog,
          overrides: [
            todayPrayerTimesProvider.overrideWith((ref) => prayerDay),
            nextPrayerProvider.overrideWith(
              (ref) => (PrayerName.asr, prayerDay.asr),
            ),
            activeSilenceWindowProvider.overrideWith((ref) => null),
            suppressionStateProvider.overrideWith(
              (ref) async => const SuppressionState(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_testApp(container, const HomeScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('ON'));
        await tester.pumpAndSettle();

        final settings = container.read(settingsProvider);
        expect(settings.masterSilenceEnabled, false);
        expect(settings.geofenceSilenceEnabled, true);
        expect(settings.timeBasedSilenceEnabled, true);
        expect(controller.clearManualOverridesCalls, 1);
        expect(controller.disableTimeBasedSilenceCalls, 1);
        expect(controller.disableGeofenceSilenceCalls, 1);
        expect(
          eventLog.messages,
          contains('restored:Master toggle OFF — phone restored to normal'),
        );
      },
    );

    testWidgets('turning master on immediately rechecks the current masjid', (
      tester,
    ) async {
      final controller = _FakeVolumeController();
      final locationService = _FakeLocationService([
        _position(latitude: 24.7136, longitude: 46.6753),
      ]);
      final eventLog = _FakeEventLogService();
      final prayerDay = _samplePrayerDay();
      final container = _container(
        settings: AppSettings.defaults().copyWith(
          masterSilenceEnabled: false,
          geofenceSilenceEnabled: true,
          timeBasedSilenceEnabled: false,
        ),
        masjids: [_masjid(id: 'riyadh', latitude: 24.7136, longitude: 46.6753)],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
        overrides: [
          todayPrayerTimesProvider.overrideWith((ref) => prayerDay),
          nextPrayerProvider.overrideWith(
            (ref) => (PrayerName.asr, prayerDay.asr),
          ),
          activeSilenceWindowProvider.overrideWith((ref) => null),
          suppressionStateProvider.overrideWith(
            (ref) async => const SuppressionState(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_testApp(container, const HomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OFF'));
      await tester.pumpAndSettle();

      final settings = container.read(settingsProvider);
      expect(settings.masterSilenceEnabled, true);
      expect(controller.clearManualOverridesCalls, 1);
      expect(controller.appliedMasjidIds, ['riyadh']);
    });
  });
}
