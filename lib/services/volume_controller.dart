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

  /// Register geofences for saved masjid locations.
  Future<bool> registerGeofences(List<Map<String, dynamic>> masjids) async {
    return await _channel.invokeMethod<bool>(
          'registerGeofences',
          {'masjids': masjids},
        ) ??
        false;
  }

  /// Remove all registered geofences AND clear geo silence state.
  /// Use when user explicitly disables geofencing or deletes all masjids.
  Future<void> removeAllGeofences() async {
    await _channel.invokeMethod('removeAllGeofences');
  }

  /// Remove geofences only (for re-registration). Does NOT clear geo_silenced.
  Future<void> removeGeofencesOnly() async {
    await _channel.invokeMethod('removeGeofencesOnly');
  }

  /// Check if background location permission is granted.
  Future<bool> hasBackgroundLocationPermission() async {
    return await _channel.invokeMethod<bool>('hasBackgroundLocationPermission') ?? false;
  }

  /// Silence phone AND mark geo_silenced=true in native SharedPreferences.
  /// Pass [masjidId] to track which masjid triggered the silence.
  Future<bool> applySilenceForGeo({String? masjidId}) async {
    final args = <String, dynamic>{};
    if (masjidId != null) args['masjidId'] = masjidId;
    return await _channel.invokeMethod<bool>('applySilenceForGeo', args) ?? false;
  }

  /// Clear geo silence for a specific deleted masjid.
  /// Returns: "not_silenced", "not_at_deleted", "still_at_other", or "restored".
  Future<String> clearGeoSilenceForMasjid(String masjidId) async {
    return await _channel.invokeMethod<String>('clearGeoSilenceForMasjid', {
      'masjidId': masjidId,
    }) ?? 'not_silenced';
  }

  /// Clear geo silence only — restores phone if prayer is not active.
  /// If prayer IS active, just clears geo flags without touching DND.
  Future<bool> clearGeoSilence() async {
    return await _channel.invokeMethod<bool>('clearGeoSilence') ?? false;
  }

  /// Force phone back to normal — ringer normal + DND all + clear all silence state.
  Future<bool> forceRestoreNormal() async {
    return await _channel.invokeMethod<bool>('forceRestoreNormal') ?? false;
  }

  /// Read and clear native event log (events logged by GeofenceReceiver etc.)
  Future<String> readNativeEvents() async {
    return await _channel.invokeMethod<String>('readNativeEvents') ?? '[]';
  }

  /// Check if phone is currently silenced by a geofence (native side).
  Future<bool> isGeoSilenced() async {
    return await _channel.invokeMethod<bool>('isGeoSilenced') ?? false;
  }

  /// Get the timestamp when geo silence started (milliseconds since epoch).
  Future<int> getGeoSilencedAt() async {
    return await _channel.invokeMethod<int>('getGeoSilencedAt') ?? 0;
  }

  /// Get the IDs of masjids currently inside geofence.
  Future<List<String>> getActiveMasjidGeofences() async {
    final result = await _channel.invokeMethod<List>('getActiveMasjidGeofences');
    return result?.cast<String>() ?? [];
  }
}
