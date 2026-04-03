import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/prayer_day.dart';
import '../models/silence_window.dart';
import '../services/event_log_service.dart';
import '../services/geofence_recovery_policy.dart';
import '../services/prayer_calculator.dart';
import '../services/silence_scheduler.dart';
import '../services/silence_window_calculator.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../services/masjid_storage_service.dart';
import '../services/volume_controller.dart';
import '../models/saved_masjid.dart';
import '../models/suppression_state.dart';

const _geofenceRecoveryPolicy = GeofenceRecoveryPolicy();
int _gpsExitRecoveryOutsideStreak = 0;

class _NearestMasjidMatch {
  const _NearestMasjidMatch({
    required this.masjid,
    required this.distanceMeters,
  });

  final SavedMasjid masjid;
  final double distanceMeters;
}

Stream<DateTime> _periodicImmediate(Duration interval) async* {
  yield DateTime.now();
  yield* Stream.periodic(interval, (_) => DateTime.now());
}

_NearestMasjidMatch? _nearestMasjidMatch({
  required List<SavedMasjid> masjids,
  required LocationService locationService,
  required double latitude,
  required double longitude,
}) {
  _NearestMasjidMatch? nearest;

  for (final masjid in masjids) {
    final distanceMeters = locationService.distanceMetersBetween(
      masjid.latitude,
      masjid.longitude,
      latitude,
      longitude,
    );

    if (nearest == null || distanceMeters < nearest.distanceMeters) {
      nearest = _NearestMasjidMatch(
        masjid: masjid,
        distanceMeters: distanceMeters,
      );
    }
  }

  return nearest;
}

Future<bool> repairMasjidPresence(
  dynamic ref, {
  int attempts = 3,
  Duration retryDelay = const Duration(seconds: 3),
}) async {
  final settings = ref.read(settingsProvider) as AppSettings;
  if (!settings.masterSilenceEnabled || !settings.geofenceSilenceEnabled) {
    return false;
  }
  // Respect dwell protection: GPS repair should not silence on a brief
  // drive-by fix. Let the native DWELL event handle initial silencing.
  if (settings.requireMasjidDwellBeforeSilence) {
    return false;
  }

  final masjids = ref.read(savedMasjidsProvider);
  if (masjids.isEmpty) return false;

  ref.invalidate(autoGeofenceProvider);
  await ref.read(autoGeofenceProvider.future);

  final controller = ref.read(volumeControllerProvider);
  final locationService = ref.read(locationServiceProvider);

  for (var attempt = 0; attempt < attempts; attempt++) {
    final position = await locationService.getCurrentPosition();
    if (position != null) {
      final nearest = _nearestMasjidMatch(
        masjids: masjids,
        locationService: locationService,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (nearest != null &&
          _geofenceRecoveryPolicy.shouldRepairEnter(
            nearestDistanceMeters: nearest.distanceMeters,
            radiusMeters: settings.masjidRadiusMeters,
          )) {
        final applied = await controller.applySilenceForGeo(
          masjidId: nearest.masjid.id,
        );
        if (applied) {
          ref.invalidate(suppressionStateProvider);
          ref.invalidate(geoSilencedProvider);
          ref.invalidate(activeMasjidGeofencesProvider);
          final eventLog = ref.read(eventLogServiceProvider);
          await eventLog.log(
            EventType.geofenceEnter,
            'Immediate masjid presence check detected an active visit',
          );
          return true;
        }
      }
    }

    if (attempt < attempts - 1) {
      await Future<void>.delayed(retryDelay);
    }
  }

  return false;
}

Future<void> reEvaluateCurrentSuppression(
  dynamic ref, {
  bool checkPrayer = true,
  bool checkGeo = true,
  bool clearPrayerOverride = true,
  bool clearGeoOverride = true,
}) async {
  final settings = ref.read(settingsProvider) as AppSettings;
  if (!settings.masterSilenceEnabled) {
    ref.invalidate(suppressionStateProvider);
    ref.invalidate(geoSilencedProvider);
    ref.invalidate(activeMasjidGeofencesProvider);
    return;
  }

  final controller = ref.read(volumeControllerProvider);
  if (clearPrayerOverride && clearGeoOverride) {
    await controller.clearManualOverrides();
  } else {
    if (clearPrayerOverride) {
      await controller.clearPrayerOverride();
    }
    if (clearGeoOverride) {
      await controller.clearGeoOverride();
    }
  }

  if (checkPrayer && settings.timeBasedSilenceEnabled) {
    final activeWindow =
        ref.read(activeSilenceWindowProvider) as SilenceWindow?;
    if (activeWindow != null) {
      final applied = await controller.applySilenceForPrayerWindow(
        prayerName: activeWindow.prayer.displayName,
        windowEndMs: activeWindow.end.millisecondsSinceEpoch,
      );
      if (applied) {
        final eventLog = ref.read(eventLogServiceProvider);
        await eventLog.log(
          EventType.silenced,
          'Immediate prayer window check activated ${activeWindow.prayer.displayName}',
        );
      }
    }
  }

  if (checkGeo && settings.geofenceSilenceEnabled) {
    await repairMasjidPresence(ref, attempts: 1, retryDelay: Duration.zero);
  }

  ref.invalidate(suppressionStateProvider);
  ref.invalidate(geoSilencedProvider);
  ref.invalidate(activeMasjidGeofencesProvider);
}

// --- Singleton services ---

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Must be overridden with initialized instance');
});

final eventLogServiceProvider = Provider<EventLogService>((ref) {
  throw UnimplementedError('Must be overridden with initialized instance');
});

final masjidStorageProvider = Provider<MasjidStorageService>((ref) {
  throw UnimplementedError('Must be overridden with initialized instance');
});

final savedMasjidsProvider =
    StateNotifierProvider<SavedMasjidsNotifier, List<SavedMasjid>>((ref) {
      final storage = ref.watch(masjidStorageProvider);
      return SavedMasjidsNotifier(storage);
    });

class SavedMasjidsNotifier extends StateNotifier<List<SavedMasjid>> {
  final MasjidStorageService _storage;

  SavedMasjidsNotifier(this._storage) : super(_storage.loadAll());

  Future<void> add(SavedMasjid masjid) async {
    await _storage.add(masjid);
    state = _storage.loadAll();
  }

  Future<void> remove(String id) async {
    await _storage.remove(id);
    state = _storage.loadAll();
  }

  Future<void> rename(String id, String newName) async {
    await _storage.rename(id, newName);
    state = _storage.loadAll();
  }
}

final volumeControllerProvider = Provider<VolumeController>((ref) {
  return VolumeController();
});

final prayerCalculatorProvider = Provider<PrayerCalculatorService>((ref) {
  return PrayerCalculatorService();
});

final silenceWindowCalculatorProvider = Provider<SilenceWindowCalculator>((
  ref,
) {
  return SilenceWindowCalculator();
});

final silenceSchedulerProvider = Provider<SilenceScheduler>((ref) {
  return SilenceScheduler(ref.watch(volumeControllerProvider));
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Refreshes location on app resume. If user has traveled >10km,
/// updates stored coordinates so prayer times recalculate automatically.
final locationRefreshProvider = FutureProvider<void>((ref) async {
  final settings = ref.read(settingsProvider);
  if (!settings.hasLocation || !settings.onboardingComplete) return;

  final locationService = ref.read(locationServiceProvider);
  final eventLog = ref.read(eventLogServiceProvider);

  final position = await locationService.getCurrentPosition();
  if (position == null) return;

  final moved = locationService.hasMovedSignificantly(
    storedLat: settings.latitude!,
    storedLng: settings.longitude!,
    currentLat: position.latitude,
    currentLng: position.longitude,
  );

  if (moved) {
    await ref
        .read(settingsProvider.notifier)
        .setLocation(position.latitude, position.longitude);
    await eventLog.log(
      EventType.info,
      'Location updated — travel detected '
      '(${position.latitude.toStringAsFixed(2)}, '
      '${position.longitude.toStringAsFixed(2)})',
    );
  }
});

// --- App Settings ---

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final StorageService _storage;

  SettingsNotifier(this._storage) : super(_storage.loadSettings());

  Future<void> updateSettings(AppSettings settings) async {
    state = settings;
    await _storage.saveSettings(settings);
  }

  Future<void> setCalculationMethod(CalculationMethodType method) async {
    await updateSettings(state.copyWith(calculationMethod: method));
  }

  Future<void> setTimeBasedSilenceEnabled(bool enabled) async {
    await updateSettings(state.copyWith(timeBasedSilenceEnabled: enabled));
  }

  Future<void> setGeofenceSilenceEnabled(bool enabled) async {
    await updateSettings(state.copyWith(geofenceSilenceEnabled: enabled));
  }

  Future<void> setMasterSilenceEnabled(bool enabled) async {
    await updateSettings(state.copyWith(masterSilenceEnabled: enabled));
  }

  Future<void> setSilenceLevel(SilenceLevel level) async {
    await updateSettings(state.copyWith(silenceLevel: level));
  }

  Future<void> setMasjidRadiusMeters(int radiusMeters) async {
    await updateSettings(state.copyWith(masjidRadiusMeters: radiusMeters));
  }

  Future<void> setRequireMasjidDwellBeforeSilence(bool enabled) async {
    await updateSettings(
      state.copyWith(requireMasjidDwellBeforeSilence: enabled),
    );
  }

  Future<void> setFastGeoExitTrackingEnabled(bool enabled) async {
    await updateSettings(state.copyWith(fastGeoExitTrackingEnabled: enabled));
  }

  Future<void> setLocation(double lat, double lng) async {
    await updateSettings(state.copyWith(latitude: lat, longitude: lng));
  }

  Future<void> completeOnboarding() async {
    await updateSettings(state.copyWith(onboardingComplete: true));
  }
}

// --- Time Ticker ---
// Emits a new DateTime every minute to invalidate time-dependent providers.
// This ensures prayer times refresh after midnight, active window updates, etc.

final currentDateProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  ).map((t) => DateTime(t.year, t.month, t.day)); // date-only for prayer calc
});

final currentMinuteProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 10), (_) => DateTime.now());
});

// --- Prayer Times ---

final todayPrayerTimesProvider = Provider<PrayerDay?>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.hasLocation) return null;

  // Re-evaluate when the date changes (after midnight)
  ref.watch(currentDateProvider);

  final calculator = ref.watch(prayerCalculatorProvider);
  return calculator.today(
    latitude: settings.latitude!,
    longitude: settings.longitude!,
    method: settings.calculationMethod,
  );
});

final tomorrowPrayerTimesProvider = Provider<PrayerDay?>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.hasLocation) return null;

  ref.watch(currentDateProvider);

  final calculator = ref.watch(prayerCalculatorProvider);
  return calculator.tomorrow(
    latitude: settings.latitude!,
    longitude: settings.longitude!,
    method: settings.calculationMethod,
  );
});

// --- Silence Windows ---

final silenceWindowsProvider = Provider<List<SilenceWindow>>((ref) {
  final today = ref.watch(todayPrayerTimesProvider);
  final tomorrow = ref.watch(tomorrowPrayerTimesProvider);
  final settings = ref.watch(settingsProvider);

  if (today == null || tomorrow == null) return [];

  final calculator = ref.watch(silenceWindowCalculatorProvider);
  return calculator.computeWindowsWithTomorrowFajr(
    today,
    tomorrow,
    settings.timingPreferences,
  );
});

/// The currently active silence window (if any).
/// Refreshes every 30 seconds via currentMinuteProvider.
final activeSilenceWindowProvider = Provider<SilenceWindow?>((ref) {
  final windows = ref.watch(silenceWindowsProvider);
  final calculator = ref.watch(silenceWindowCalculatorProvider);
  final now = ref.watch(currentMinuteProvider).valueOrNull ?? DateTime.now();
  return calculator.activeWindow(windows, now);
});

/// The next upcoming silence window. Refreshes every 30 seconds.
final nextSilenceWindowProvider = Provider<SilenceWindow?>((ref) {
  final now = ref.watch(currentMinuteProvider).valueOrNull ?? DateTime.now();
  final windows = ref.watch(silenceWindowsProvider);
  final calculator = ref.watch(silenceWindowCalculatorProvider);
  return calculator.nextWindow(windows, now);
});

/// Next prayer time info: (name, time). Refreshes every 30 seconds.
/// Falls back to tomorrow's Fajr after today's Isha has passed.
final nextPrayerProvider = Provider<(PrayerName, DateTime)?>((ref) {
  final today = ref.watch(todayPrayerTimesProvider);
  if (today == null) return null;
  final now = ref.watch(currentMinuteProvider).valueOrNull ?? DateTime.now();

  final todayNext = today.nextPrayer(now);
  if (todayNext != null) return todayNext;

  // All today's prayers passed — show tomorrow's Fajr
  final tomorrow = ref.watch(tomorrowPrayerTimesProvider);
  if (tomorrow == null) return null;
  return (PrayerName.fajr, tomorrow.fajr);
});

// --- Auto-Schedule Alarms ---
// Watches silence windows and auto-schedules alarms whenever they change.
// This is the critical wiring that makes the engine actually work.

/// Tracks the last scheduled window set to avoid redundant rescheduling.
int _lastScheduledHash = 0;

final autoScheduleProvider = FutureProvider<void>((ref) async {
  final windows = ref.watch(silenceWindowsProvider);
  final settings = ref.watch(settingsProvider);

  if (!settings.masterSilenceEnabled ||
      !settings.timeBasedSilenceEnabled ||
      windows.isEmpty) {
    // Cancel any existing alarms when disabled
    if (_lastScheduledHash != 0) {
      final scheduler = ref.read(silenceSchedulerProvider);
      await scheduler.cancelAll();
      _lastScheduledHash = 0;
      final eventLog = ref.read(eventLogServiceProvider);
      await eventLog.log(
        EventType.info,
        'Auto-silence disabled — alarms cancelled',
      );
    }
    return;
  }

  // Compute a hash of the current windows to detect actual changes.
  // Avoids rescheduling + logging on every ticker invalidation.
  final windowsHash = Object.hashAll(
    windows.map(
      (w) => Object.hash(
        w.start.millisecondsSinceEpoch,
        w.end.millisecondsSinceEpoch,
      ),
    ),
  );
  if (windowsHash == _lastScheduledHash) return;
  _lastScheduledHash = windowsHash;

  final scheduler = ref.read(silenceSchedulerProvider);
  final eventLog = ref.read(eventLogServiceProvider);

  await scheduler.scheduleAll(windows);

  final now = DateTime.now();
  final upcoming = windows.where((w) => w.end.isAfter(now)).length;
  await eventLog.log(
    EventType.alarmScheduled,
    'Scheduled $upcoming silence windows',
  );
});

/// Imports native events into Flutter's event log. Triggered on app resume
/// and on geoSilenced poll. Native side uses synchronized lock to prevent
/// log() and readAndClear() from interleaving.
final importNativeEventsProvider = FutureProvider<void>((ref) async {
  await _importNativeEvents(ref);
});

Future<void> _importNativeEvents(Ref ref) async {
  try {
    final controller = ref.read(volumeControllerProvider);
    final eventLog = ref.read(eventLogServiceProvider);
    final json = await controller.readNativeEvents();

    if (json == '[]') return;

    final List<dynamic> events = jsonDecode(json) as List;
    for (final event in events) {
      final type = event['type'] as String? ?? 'info';
      final message = event['message'] as String? ?? '';
      final timestampMs = event['timestamp'] as int? ?? 0;

      final eventType = type == 'geofenceEnter'
          ? EventType.geofenceEnter
          : type == 'geofenceExit'
          ? EventType.geofenceExit
          : EventType.info;

      // Use the real native timestamp, not DateTime.now()
      final realTimestamp = timestampMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
          : DateTime.now();

      await eventLog.log(eventType, message, at: realTimestamp);
    }
  } catch (_) {}
}

// --- Geofence State ---
// Mode 1: Normal poll (10s) — reads native geo_silenced flag for UI. No GPS.
// Mode 2: GPS calibration (configurable, default 5min) — recovery path:
//         CAN silence if GPS says near masjid but native missed it.
//         CAN also clear a stuck geo silence if GPS repeatedly says outside.
//         Only active when geofencing is enabled.

final suppressionStateProvider = FutureProvider<SuppressionState>((ref) async {
  ref.watch(currentMinuteProvider); // refresh every 10s
  ref.watch(importNativeEventsProvider);
  final controller = ref.read(volumeControllerProvider);
  final state = await controller.getSuppressionState();
  return SuppressionState.fromNativeMap(state);
});

final geoSilencedProvider = FutureProvider<bool>((ref) async {
  final state = await ref.watch(suppressionStateProvider.future);
  return state.hasGeoReason;
});

// GPS calibration — runs at user-configured interval, silence-only
final _gpsCalibrationTickProvider = StreamProvider<DateTime>((ref) {
  final settings = ref.watch(settingsProvider);
  final minutes = settings.gpsCalibrationMinutes.clamp(1, 30);
  return _periodicImmediate(Duration(minutes: minutes));
});

final gpsCalibrationProvider = FutureProvider<void>((ref) async {
  ref.watch(_gpsCalibrationTickProvider);
  final settings = ref.read(settingsProvider);
  if (!settings.masterSilenceEnabled || !settings.geofenceSilenceEnabled) {
    return;
  }

  final masjids = ref.read(savedMasjidsProvider);
  if (masjids.isEmpty) return;

  final controller = ref.read(volumeControllerProvider);
  final nativeGeoSilenced = await controller.isGeoSilenced();
  if (nativeGeoSilenced) return;

  try {
    final locationService = ref.read(locationServiceProvider);
    final position = await locationService.getCurrentPosition();
    if (position == null) return;

    final nearest = _nearestMasjidMatch(
      masjids: masjids,
      locationService: locationService,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (nearest == null) return;
    final nearMasjid = nearest.masjid;

    if (_geofenceRecoveryPolicy.shouldRepairEnter(
      nearestDistanceMeters: nearest.distanceMeters,
      radiusMeters: settings.masjidRadiusMeters,
    )) {
      // GPS says we're at a masjid but native missed it; silence now.
      final applied = await controller.applySilenceForGeo(
        masjidId: nearMasjid.id,
      );
      if (!applied) return;
      ref.invalidate(suppressionStateProvider);
      ref.invalidate(geoSilencedProvider);
      ref.invalidate(activeMasjidGeofencesProvider);
      final eventLog = ref.read(eventLogServiceProvider);
      await eventLog.log(
        EventType.geofenceEnter,
        'GPS repair detected masjid presence - phone silenced',
      );
    }
  } catch (_) {
    // GPS failed; do nothing and try again on the next calibration tick.
  }
});

final _geoExitRecoveryTickProvider = StreamProvider<DateTime>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.masterSilenceEnabled || !settings.geofenceSilenceEnabled) {
    return const Stream<DateTime>.empty();
  }
  return _periodicImmediate(GeofenceRecoveryPolicy.exitCheckInterval);
});

/// Check if the user has left all masjids and clear geo silence after
/// [GeofenceRecoveryPolicy.exitChecksBeforeRestore] consecutive outside
/// readings. Extracted so tests can call it directly without depending
/// on the stream-based tick provider.
Future<bool> checkGeoExitRecovery(dynamic ref) async {
  final settings = ref.read(settingsProvider) as AppSettings;
  if (!settings.masterSilenceEnabled || !settings.geofenceSilenceEnabled) {
    _gpsExitRecoveryOutsideStreak = 0;
    return false;
  }
  // NOTE: Do NOT bail out when fastGeoExitTrackingEnabled is true.
  // The native GeoExitTrackingService provides fast exit detection (10s)
  // but Android can kill it. This Dart-side recovery (45s checks) runs
  // as a redundant safety net whenever the app is alive.
  // Both layers are needed for reliable exit detection.

  final masjids = ref.read(savedMasjidsProvider) as List<SavedMasjid>;
  if (masjids.isEmpty) {
    _gpsExitRecoveryOutsideStreak = 0;
    return false;
  }

  final controller = ref.read(volumeControllerProvider) as VolumeController;
  final nativeGeoSilenced = await controller.isGeoSilenced();
  if (!nativeGeoSilenced) {
    _gpsExitRecoveryOutsideStreak = 0;
    return false;
  }

  try {
    final locationService =
        ref.read(locationServiceProvider) as LocationService;
    final position = await locationService.getCurrentPosition();
    if (position == null) return false;

    // Skip low-quality GPS fixes — indoor GPS can report wildly wrong
    // positions. If accuracy circle is larger than the exit threshold,
    // we can't distinguish inside from outside. Don't count it.
    final exitThreshold = _geofenceRecoveryPolicy
        .exitRepairThresholdMeters(settings.masjidRadiusMeters);
    if (position.accuracy > exitThreshold) {
      return false;
    }

    final nearest = _nearestMasjidMatch(
      masjids: masjids,
      locationService: locationService,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (nearest == null) return false;

    final clearlyOutside = _geofenceRecoveryPolicy.shouldRepairExit(
      nearestDistanceMeters: nearest.distanceMeters,
      radiusMeters: settings.masjidRadiusMeters,
    );
    if (!clearlyOutside) {
      _gpsExitRecoveryOutsideStreak = 0;
      return false;
    }

    _gpsExitRecoveryOutsideStreak += 1;
    if (_gpsExitRecoveryOutsideStreak <
        GeofenceRecoveryPolicy.exitChecksBeforeRestore) {
      final eventLog = ref.read(eventLogServiceProvider) as EventLogService;
      await eventLog.log(
        EventType.info,
        'Dart exit recovery: outside check #$_gpsExitRecoveryOutsideStreak/${GeofenceRecoveryPolicy.exitChecksBeforeRestore} '
        '(dist=${nearest.distanceMeters.toStringAsFixed(0)}m)',
      );
      return false;
    }

    final cleared = await controller.clearGeoSilence();
    if (cleared) {
      _gpsExitRecoveryOutsideStreak = 0;
      ref.invalidate(suppressionStateProvider);
      ref.invalidate(geoSilencedProvider);
      ref.invalidate(activeMasjidGeofencesProvider);
      final eventLog = ref.read(eventLogServiceProvider) as EventLogService;
      await eventLog.log(
        EventType.restored,
        'Dart exit recovery cleared stuck masjid silence '
        '(dist=${nearest.distanceMeters.toStringAsFixed(0)}m)',
      );
      return true;
    }
  } catch (_) {
    // GPS failed; do nothing and try again on the next fast exit check.
  }
  return false;
}

/// Reset the exit recovery streak counter (for testing).
void resetGeoExitRecoveryStreak() {
  _gpsExitRecoveryOutsideStreak = 0;
}

final geoExitRecoveryProvider = FutureProvider<void>((ref) async {
  ref.watch(_geoExitRecoveryTickProvider);
  await checkGeoExitRecovery(ref);
});

final geoReentryProbationProvider = FutureProvider<void>((ref) async {
  ref.watch(currentMinuteProvider);
  final settings = ref.read(settingsProvider);
  if (!settings.masterSilenceEnabled || !settings.geofenceSilenceEnabled) {
    return;
  }

  final controller = ref.read(volumeControllerProvider);
  final state = await controller.getSuppressionState();
  final probationUntilMs =
      (state['geoReentryProbationUntilMs'] as num?)?.toInt() ?? 0;
  if (probationUntilMs <= DateTime.now().millisecondsSinceEpoch) return;
  if ((state['isGeoSilenced'] as bool?) ?? false) return;

  await repairMasjidPresence(ref);
});

final activeMasjidGeofencesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(currentMinuteProvider);
  final controller = ref.read(volumeControllerProvider);
  return controller.getActiveMasjidGeofences();
});

// --- Geofence Auto-Registration ---
// Watches saved masjids and auto-registers geofences when the list changes.
// Uses atomic swap: register new geofences first (Play Services replaces
// matching request IDs), then remove only stale IDs that are no longer needed.

/// Tracks the set of masjid IDs from the last successful registration.
/// Used to compute which IDs are stale and need removal after re-registration.
Set<String> _lastRegisteredMasjidIds = {};

final autoGeofenceProvider = FutureProvider<void>((ref) async {
  final masjids = ref.watch(savedMasjidsProvider);
  final settings = ref.watch(settingsProvider);
  final controller = ref.read(volumeControllerProvider);

  if (!settings.masterSilenceEnabled ||
      masjids.isEmpty ||
      !settings.geofenceSilenceEnabled) {
    await controller.removeGeofencesOnly();
    _lastRegisteredMasjidIds = {};
    return;
  }

  final hasBgLocation = await controller.hasBackgroundLocationPermission();
  if (!hasBgLocation) return; // Can't register without background location

  final masjidMaps = masjids
      .map(
        (m) => {
          'id': m.id,
          'name': m.name,
          'latitude': m.latitude,
          'longitude': m.longitude,
        },
      )
      .toList();

  final currentIds = masjids.map((m) => m.id).toSet();
  final success = await controller.registerGeofences(masjidMaps);

  final eventLog = ref.read(eventLogServiceProvider);
  if (!success) {
    await eventLog.log(
      EventType.error,
      'Failed to register ${masjids.length} masjid geofences',
    );
    return;
  }

  // Remove only stale geofence IDs that are no longer in the saved list.
  final staleIds = _lastRegisteredMasjidIds.difference(currentIds);
  if (staleIds.isNotEmpty) {
    await controller.removeGeofencesByIds(staleIds.toList());
  }
  _lastRegisteredMasjidIds = currentIds;

  await eventLog.log(
    EventType.info,
    'Registered ${masjids.length} masjid geofences',
  );
});

// (Manual masjid mode removed - geofencing handles everything natively)

// --- Permission Status ---

final dndPermissionProvider = FutureProvider<bool>((ref) async {
  final controller = ref.watch(volumeControllerProvider);
  return controller.hasDndPermission();
});

final exactAlarmPermissionProvider = FutureProvider<bool>((ref) async {
  final controller = ref.watch(volumeControllerProvider);
  return controller.hasExactAlarmPermission();
});
