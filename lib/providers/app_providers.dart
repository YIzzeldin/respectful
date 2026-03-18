import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/prayer_day.dart';
import '../models/silence_window.dart';
import '../services/event_log_service.dart';
import '../services/prayer_calculator.dart';
import '../services/silence_scheduler.dart';
import '../services/silence_window_calculator.dart';
import '../services/storage_service.dart';
import '../services/volume_controller.dart';

// --- Singleton services ---

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Must be overridden with initialized instance');
});

final eventLogServiceProvider = Provider<EventLogService>((ref) {
  throw UnimplementedError('Must be overridden with initialized instance');
});

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

  Future<void> setAutoSilentEnabled(bool enabled) async {
    await updateSettings(state.copyWith(autoSilentEnabled: enabled));
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
final nextPrayerProvider = Provider<(PrayerName, DateTime)?>((ref) {
  final today = ref.watch(todayPrayerTimesProvider);
  if (today == null) return null;
  final now = ref.watch(currentMinuteProvider).valueOrNull ?? DateTime.now();
  return today.nextPrayer(now);
});

// --- Permission Status ---

final dndPermissionProvider = FutureProvider<bool>((ref) async {
  final controller = ref.watch(volumeControllerProvider);
  return controller.hasDndPermission();
});

final exactAlarmPermissionProvider = FutureProvider<bool>((ref) async {
  final controller = ref.watch(volumeControllerProvider);
  return controller.hasExactAlarmPermission();
});
