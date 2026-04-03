import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:respectful/models/app_settings.dart';
import 'package:respectful/models/prayer_day.dart';
import 'package:respectful/models/saved_masjid.dart';
import 'package:respectful/models/silence_window.dart';
import 'package:respectful/providers/app_providers.dart';
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
  int removeGeofencesOnlyCalls = 0;
  int registerGeofencesCalls = 0;
  final List<String?> appliedMasjidIds = [];
  final List<(String, int)> appliedPrayerWindows = [];
  bool applySilenceForGeoResult = true;
  bool applySilenceForPrayerWindowResult = true;
  Map<String, dynamic> suppressionState = const {};
  int clearManualOverridesCalls = 0;
  int clearPrayerOverrideCalls = 0;
  int clearGeoOverrideCalls = 0;

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
  Future<bool> hasBackgroundLocationPermission() async {
    return true;
  }

  @override
  Future<bool> applySilenceForGeo({String? masjidId}) async {
    appliedMasjidIds.add(masjidId);
    return applySilenceForGeoResult;
  }

  @override
  Future<bool> applySilenceForPrayerWindow({
    required String prayerName,
    required int windowEndMs,
  }) async {
    appliedPrayerWindows.add((prayerName, windowEndMs));
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
      currentMinuteProvider.overrideWith((ref) => Stream.value(DateTime.now())),
      ...overrides,
    ],
  );
}

void main() {
  group('repairMasjidPresence', () {
    test('silences immediately when already inside a saved masjid', () async {
      final controller = _FakeVolumeController();
      final locationService = _FakeLocationService([
        _position(latitude: 24.7136, longitude: 46.6753),
      ]);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults(),
        masjids: [_masjid(id: 'riyadh', latitude: 24.7136, longitude: 46.6753)],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      final repaired = await repairMasjidPresence(container);

      expect(repaired, true);
      expect(controller.appliedMasjidIds, ['riyadh']);
      expect(controller.removeGeofencesOnlyCalls, 1);
      expect(controller.registerGeofencesCalls, 1);
      expect(
        eventLog.messages,
        contains(
          'geofenceEnter:Immediate masjid presence check detected an active visit',
        ),
      );
    });

    test(
      'retries a bounded number of times and returns false when still outside',
      () async {
        final controller = _FakeVolumeController();
        final locationService = _FakeLocationService([
          _position(latitude: 24.7136, longitude: 46.6753),
          _position(latitude: 24.7136, longitude: 46.6753),
          _position(latitude: 24.7136, longitude: 46.6753),
        ]);
        final eventLog = _FakeEventLogService();
        final container = _container(
          settings: AppSettings.defaults(),
          masjids: [_masjid(id: 'far', latitude: 24.8000, longitude: 46.8000)],
          controller: controller,
          locationService: locationService,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        final repaired = await repairMasjidPresence(
          container,
          attempts: 2,
          retryDelay: Duration.zero,
        );

        expect(repaired, false);
        expect(controller.appliedMasjidIds, isEmpty);
        expect(locationService.calls, 2);
      },
    );
  });

  group('reEvaluateCurrentSuppression', () {
    test(
      'clears manual overrides and rechecks current masjid immediately',
      () async {
        final controller = _FakeVolumeController();
        final locationService = _FakeLocationService([
          _position(latitude: 24.7136, longitude: 46.6753),
        ]);
        final eventLog = _FakeEventLogService();
        final container = _container(
          settings: AppSettings.defaults(),
          masjids: [
            _masjid(id: 'riyadh', latitude: 24.7136, longitude: 46.6753),
          ],
          controller: controller,
          locationService: locationService,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        await reEvaluateCurrentSuppression(
          container,
          checkPrayer: false,
          checkGeo: true,
          clearPrayerOverride: false,
          clearGeoOverride: true,
        );

        expect(controller.clearManualOverridesCalls, 0);
        expect(controller.clearPrayerOverrideCalls, 0);
        expect(controller.clearGeoOverrideCalls, 1);
        expect(controller.appliedMasjidIds, ['riyadh']);
      },
    );

    test('applies the active prayer window immediately on resume', () async {
      final controller = _FakeVolumeController();
      final locationService = _FakeLocationService(const []);
      final eventLog = _FakeEventLogService();
      final activeWindow = SilenceWindow(
        prayer: PrayerName.asr,
        start: DateTime(2026, 3, 31, 15, 20),
        end: DateTime(2026, 3, 31, 15, 40),
      );
      final container = _container(
        settings: AppSettings.defaults().copyWith(
          timeBasedSilenceEnabled: true,
          geofenceSilenceEnabled: false,
        ),
        masjids: const [],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
        overrides: [
          activeSilenceWindowProvider.overrideWith((ref) => activeWindow),
        ],
      );
      addTearDown(container.dispose);

      await reEvaluateCurrentSuppression(
        container,
        checkPrayer: true,
        checkGeo: false,
        clearPrayerOverride: true,
        clearGeoOverride: false,
      );

      expect(controller.clearManualOverridesCalls, 0);
      expect(controller.clearPrayerOverrideCalls, 1);
      expect(controller.clearGeoOverrideCalls, 0);
      expect(controller.appliedPrayerWindows, [
        (PrayerName.asr.displayName, activeWindow.end.millisecondsSinceEpoch),
      ]);
      expect(
        eventLog.messages,
        contains('silenced:Immediate prayer window check activated Asr'),
      );
    });

    test('clears both override types for full master resume', () async {
      final controller = _FakeVolumeController();
      final locationService = _FakeLocationService(const []);
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults().copyWith(
          timeBasedSilenceEnabled: false,
          geofenceSilenceEnabled: false,
        ),
        masjids: const [],
        controller: controller,
        locationService: locationService,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      await reEvaluateCurrentSuppression(container);

      expect(controller.clearManualOverridesCalls, 1);
      expect(controller.clearPrayerOverrideCalls, 0);
      expect(controller.clearGeoOverrideCalls, 0);
    });
  });
}
