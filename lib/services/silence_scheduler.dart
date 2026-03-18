import '../models/silence_window.dart';
import 'volume_controller.dart';

/// Orchestrates scheduling silence/restore alarms for computed silence windows.
/// Bridges the SilenceWindowCalculator output to the native AlarmScheduler.
class SilenceScheduler {
  final VolumeController _volumeController;

  SilenceScheduler(this._volumeController);

  /// Schedule all alarms for the given silence windows.
  /// Cancels any existing alarms first, then schedules new ones.
  Future<void> scheduleAll(List<SilenceWindow> windows) async {
    await _volumeController.cancelAllAlarms();

    final now = DateTime.now();

    for (final window in windows) {
      // Skip windows that have already ended
      if (window.end.isBefore(now)) continue;

      if (window.start.isAfter(now)) {
        // Window hasn't started — schedule both silence and restore
        await _volumeController.scheduleSilenceAlarm(
          triggerAtMs: window.start.millisecondsSinceEpoch,
          prayerName: window.displayName,
          windowEndMs: window.end.millisecondsSinceEpoch,
          requestCode: window.silenceAlarmId,
        );
      }
      // Always schedule restore (even if window already started — we may be mid-window after restart)
      await _volumeController.scheduleRestoreAlarm(
        triggerAtMs: window.end.millisecondsSinceEpoch,
        requestCode: window.restoreAlarmId,
      );
    }
  }

  /// Schedule alarms for a single window (used for immediate silencing).
  Future<void> scheduleSingle(SilenceWindow window) async {
    final now = DateTime.now();

    if (window.start.isAfter(now)) {
      await _volumeController.scheduleSilenceAlarm(
        triggerAtMs: window.start.millisecondsSinceEpoch,
        prayerName: window.displayName,
        windowEndMs: window.end.millisecondsSinceEpoch,
        requestCode: window.silenceAlarmId,
      );
    }

    await _volumeController.scheduleRestoreAlarm(
      triggerAtMs: window.end.millisecondsSinceEpoch,
      requestCode: window.restoreAlarmId,
    );
  }

  /// Cancel all scheduled alarms.
  Future<void> cancelAll() async {
    await _volumeController.cancelAllAlarms();
  }
}
