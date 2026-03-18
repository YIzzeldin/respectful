import 'package:flutter/services.dart';

/// Platform channel interface for Android volume/DND control.
/// This is the Dart side of the native Kotlin VolumeControlService.
class VolumeController {
  static const _channel = MethodChannel('com.respectful/volume_control');

  /// Capture the current phone state (ringer mode, DND, volumes).
  /// Returns a map that can be stored and later passed to restoreState().
  Future<Map<String, dynamic>> captureCurrentState() async {
    final result = await _channel.invokeMethod('captureCurrentState');
    return Map<String, dynamic>.from(result as Map);
  }

  /// Apply total silence: RINGER_MODE_SILENT + INTERRUPTION_FILTER_NONE.
  /// Returns true if successful, false if DND permission is missing.
  Future<bool> applySilence() async {
    return await _channel.invokeMethod<bool>('applySilence') ?? false;
  }

  /// Apply priority silence: allows alarms and starred contacts through.
  Future<bool> applyPrioritySilence() async {
    return await _channel.invokeMethod<bool>('applyPrioritySilence') ?? false;
  }

  /// Restore phone to a previously captured state.
  Future<bool> restoreState(Map<String, dynamic> state) async {
    return await _channel.invokeMethod<bool>('restoreState', state) ?? false;
  }

  /// Check if the app has DND access permission.
  Future<bool> hasDndPermission() async {
    return await _channel.invokeMethod<bool>('hasDndPermission') ?? false;
  }

  /// Open system settings for DND access grant.
  Future<void> openDndSettings() async {
    await _channel.invokeMethod('openDndSettings');
  }

  /// Check if exact alarm permission is granted (Android 12+).
  Future<bool> hasExactAlarmPermission() async {
    return await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? false;
  }

  /// Open system settings for exact alarm permission.
  Future<void> openExactAlarmSettings() async {
    await _channel.invokeMethod('openExactAlarmSettings');
  }

  /// Get current ringer mode (for override detection).
  Future<int> getCurrentRingerMode() async {
    return await _channel.invokeMethod<int>('getCurrentRingerMode') ?? 0;
  }

  /// Get current interruption filter.
  Future<int> getCurrentInterruptionFilter() async {
    return await _channel.invokeMethod<int>('getCurrentInterruptionFilter') ?? 0;
  }

  /// Schedule a silence alarm at a specific time.
  Future<void> scheduleSilenceAlarm({
    required int triggerAtMs,
    required String prayerName,
    required int windowEndMs,
    int requestCode = 1000,
  }) async {
    await _channel.invokeMethod('scheduleSilenceAlarm', {
      'triggerAtMs': triggerAtMs,
      'prayerName': prayerName,
      'windowEndMs': windowEndMs,
      'requestCode': requestCode,
    });
  }

  /// Schedule a restore alarm at a specific time.
  Future<void> scheduleRestoreAlarm({
    required int triggerAtMs,
    int requestCode = 2000,
  }) async {
    await _channel.invokeMethod('scheduleRestoreAlarm', {
      'triggerAtMs': triggerAtMs,
      'requestCode': requestCode,
    });
  }

  /// Cancel all scheduled alarms.
  Future<void> cancelAllAlarms() async {
    await _channel.invokeMethod('cancelAllAlarms');
  }
}
