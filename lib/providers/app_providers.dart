import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/prayer_day.dart';
import '../models/silence_window.dart';
import '../services/event_log_service.dart';
import '../services/prayer_calculator.dart';
import '../services/silence_scheduler.dart';
import '../services/silence_window_calculator.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../services/masjid_storage_service.dart';
import '../services/volume_controller.dart';
import '../models/saved_masjid.dart';

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

final silenceWindowCalculatorProvider =
    Provider<SilenceWindowCalculator>((ref) {
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
    await ref.read(settingsProvider.notifier).setLocation(
          position.latitude,
          position.longitude,
        );
    await eventLog.log(
      EventType.info,
      'Location updated — travel detected '
      '(${position.latitude.toStringAsFixed(2)}, '
      '${position.longitude.toStringAsFixed(2)})',
    );
  }
});

// --- App Settings ---

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
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

  Future<void> setSilenceLevel(SilenceLevel level) async {
    await updateSettings(state.copyWith(silenceLevel: level));
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
  return Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now())
      .map((t) => DateTime(t.year, t.month, t.day)); // date-only for prayer calc
});

final currentMinuteProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
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

  if (!settings.timeBasedSilenceEnabled || windows.isEmpty) {
    // Cancel any existing alarms when disabled
    if (_lastScheduledHash != 0) {
      final scheduler = ref.read(silenceSchedulerProvider);
      await scheduler.cancelAll();
      _lastScheduledHash = 0;
      final eventLog = ref.read(eventLogServiceProvider);
      await eventLog.log(EventType.info, 'Auto-silence disabled — alarms cancelled');
    }
    return;
  }

  // Compute a hash of the current windows to detect actual changes.
  // Avoids rescheduling + logging on every ticker invalidation.
  final windowsHash = Object.hashAll(
    windows.map((w) => Object.hash(w.start.millisecondsSinceEpoch, w.end.millisecondsSinceEpoch)),
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

// --- Geofence State (reads native geo_silenced flag) ---
// Polls every 30 seconds to detect native geofence enter/exit events.

final geoSilencedProvider = FutureProvider<bool>((ref) async {
  ref.watch(currentMinuteProvider); // refresh every 30s
  final controller = ref.read(volumeControllerProvider);
  return controller.isGeoSilenced();
});

final activeMasjidGeofencesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(currentMinuteProvider);
  final controller = ref.read(volumeControllerProvider);
  return controller.getActiveMasjidGeofences();
});

// --- Geofence Auto-Registration ---
// Watches saved masjids and auto-registers geofences when the list changes.

final autoGeofenceProvider = FutureProvider<void>((ref) async {
  final masjids = ref.watch(savedMasjidsProvider);
  final settings = ref.watch(settingsProvider);
  final controller = ref.read(volumeControllerProvider);

  if (masjids.isEmpty || !settings.geofenceSilenceEnabled) {
    await controller.removeAllGeofences();
    return;
  }

  final hasBgLocation = await controller.hasBackgroundLocationPermission();
  if (!hasBgLocation) return; // Can't register without background location

  // Always remove all first, then re-add. This ensures deleted masjids
  // don't keep stale geofences active (addGeofences only replaces by ID,
  // it doesn't remove IDs that are no longer in the list).
  await controller.removeAllGeofences();

  final masjidMaps = masjids
      .map((m) => {
            'id': m.id,
            'name': m.name,
            'latitude': m.latitude,
            'longitude': m.longitude,
          })
      .toList();

  await controller.registerGeofences(masjidMaps);

  final eventLog = ref.read(eventLogServiceProvider);
  await eventLog.log(
    EventType.info,
    'Registered ${masjids.length} masjid geofences',
  );
});

// --- Masjid Mode ---

final masjidModeProvider =
    StateNotifierProvider<MasjidModeNotifier, MasjidModeState>((ref) {
  return MasjidModeNotifier(
    ref.watch(volumeControllerProvider),
    ref.watch(eventLogServiceProvider),
    ref.watch(silenceSchedulerProvider),
    () => ref.read(silenceWindowsProvider), // lazy read to avoid circular dep
    () => ref.read(settingsProvider),
  );
});

class MasjidModeState {
  final bool isActive;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final bool isOverridden;
  final DateTime? overrideExpiresAt;

  const MasjidModeState({
    this.isActive = false,
    this.activatedAt,
    this.expiresAt,
    this.isOverridden = false,
    this.overrideExpiresAt,
  });

  Duration? get remainingTime {
    if (!isActive || expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  MasjidModeState copyWith({
    bool? isActive,
    DateTime? activatedAt,
    DateTime? expiresAt,
    bool? isOverridden,
    DateTime? overrideExpiresAt,
  }) =>
      MasjidModeState(
        isActive: isActive ?? this.isActive,
        activatedAt: activatedAt ?? this.activatedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        isOverridden: isOverridden ?? this.isOverridden,
        overrideExpiresAt: overrideExpiresAt ?? this.overrideExpiresAt,
      );
}

class MasjidModeNotifier extends StateNotifier<MasjidModeState> {
  final VolumeController _volumeController;
  final EventLogService _eventLog;
  final SilenceScheduler _scheduler;
  final List<SilenceWindow> Function() _getWindows;
  final AppSettings Function() _getSettings;

  /// Captured phone state before masjid mode silenced — used to restore.
  Map<String, dynamic>? _savedPhoneState;

  MasjidModeNotifier(
    this._volumeController,
    this._eventLog,
    this._scheduler,
    this._getWindows,
    this._getSettings,
  ) : super(const MasjidModeState());

  /// Activate masjid mode — capture state, silence phone, schedule auto-expire.
  Future<void> activate({int durationMinutes = 120}) async {
    // Guard against reentrant calls — don't overwrite snapshot if already active
    if (state.isActive) return;

    final now = DateTime.now();

    // Capture phone state BEFORE silencing so we can restore later
    _savedPhoneState = await _volumeController.captureCurrentState();

    // Silence the phone — use applySilenceForGeo which writes native state
    // so the restore alarm can work even if the app process dies
    final success = await _volumeController.applySilenceForGeo();
    if (!success) {
      _savedPhoneState = null;
      await _eventLog.log(EventType.error, 'Masjid mode failed — DND permission missing');
      return;
    }

    state = MasjidModeState(
      isActive: true,
      activatedAt: now,
      expiresAt: now.add(Duration(minutes: durationMinutes)),
    );

    // Schedule masjid-specific restore alarm (requestCode 3000 — won't collide with prayer alarms)
    await _volumeController.scheduleRestoreAlarm(
      triggerAtMs: state.expiresAt!.millisecondsSinceEpoch,
      requestCode: 3000,
    );

    await _eventLog.log(
      EventType.masjidModeOn,
      'Masjid mode activated (${durationMinutes}m)',
    );
  }

  /// Deactivate masjid mode — restore phone state, then reschedule prayer alarms.
  Future<void> deactivate() async {
    if (!state.isActive) return;

    // Restore phone to pre-masjid state
    if (_savedPhoneState != null) {
      await _volumeController.restoreState(_savedPhoneState!);
      _savedPhoneState = null;
    }

    state = const MasjidModeState();

    // Reschedule prayer alarms (masjid deactivation doesn't change silence windows,
    // so autoScheduleProvider won't re-run. We must manually reschedule.)
    final settings = _getSettings();
    if (settings.timeBasedSilenceEnabled) {
      final windows = _getWindows();
      if (windows.isNotEmpty) {
        await _scheduler.scheduleAll(windows);
      }
    }

    await _eventLog.log(EventType.masjidModeOff, 'Masjid mode deactivated');
  }

  /// Extend masjid mode by [additionalMinutes].
  Future<void> extend({int additionalMinutes = 60}) async {
    if (!state.isActive) return;

    final newExpiry = (state.expiresAt ?? DateTime.now())
        .add(Duration(minutes: additionalMinutes));

    state = state.copyWith(expiresAt: newExpiry);

    await _volumeController.scheduleRestoreAlarm(
      triggerAtMs: newExpiry.millisecondsSinceEpoch,
      requestCode: 3000,
    );

    await _eventLog.log(
      EventType.masjidModeOn,
      'Masjid mode extended by ${additionalMinutes}m',
    );
  }
}

// --- Permission Status ---

final dndPermissionProvider = FutureProvider<bool>((ref) async {
  final controller = ref.watch(volumeControllerProvider);
  return controller.hasDndPermission();
});

final exactAlarmPermissionProvider = FutureProvider<bool>((ref) async {
  final controller = ref.watch(volumeControllerProvider);
  return controller.hasExactAlarmPermission();
});
