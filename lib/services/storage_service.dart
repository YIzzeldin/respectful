import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/prayer_timing_config.dart';

/// Wrapper around SharedPreferences for typed access to app settings.
class StorageService {
  static const _keyCalculationMethod = 'calculation_method';
  static const _keyTimingPreferences = 'timing_preferences';
  static const _keyAutoSilentEnabled = 'auto_silent_enabled';
  static const _keyGeofenceSilenceEnabled = 'geofence_silence_enabled';
  static const _keyMasterSilenceEnabled = 'master_silence_enabled';
  static const _keySilenceLevel = 'silence_level';
  static const _keyUsePerPrayerConfig = 'use_per_prayer_config';
  static const _keyOnboardingComplete = 'onboarding_complete';
  static const _keyGpsCalibrationMinutes = 'gps_calibration_minutes';
  static const _keyMasjidRadiusMeters = 'masjid_radius_meters';
  static const _keyRequireMasjidDwellBeforeSilence =
      'require_masjid_dwell_before_silence';
  static const _keyFastGeoExitTrackingEnabled =
      'fast_geo_exit_tracking_enabled';
  static const _keyFastGeoExitTrackingUserChoice =
      'fast_geo_exit_tracking_user_choice';
  static const _keyLanguageCode = 'language_code';
  static const _keyLatitude = 'latitude';
  static const _keyLongitude = 'longitude';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Load all settings from storage.
  /// Enums are stored by name (not index) so reordering is safe.
  AppSettings loadSettings() {
    final methodName = _prefs.getString(_keyCalculationMethod);
    final timingJson = _prefs.getString(_keyTimingPreferences);
    final silenceLevelName = _prefs.getString(_keySilenceLevel);
    final hasFastExitChoice =
        _prefs.getBool(_keyFastGeoExitTrackingUserChoice) ?? false;
    final fastGeoExitTrackingEnabled = hasFastExitChoice
        ? (_prefs.getBool(_keyFastGeoExitTrackingEnabled) ?? true)
        : true;

    return AppSettings(
      calculationMethod: _enumByName(
        CalculationMethodType.values,
        methodName,
        CalculationMethodType.muslimWorldLeague,
      ),
      timingPreferences: timingJson != null
          ? TimingPreferences.fromJson(
              jsonDecode(timingJson) as Map<String, dynamic>,
            )
          : TimingPreferences.defaults(),
      timeBasedSilenceEnabled: _prefs.getBool(_keyAutoSilentEnabled) ?? false,
      geofenceSilenceEnabled:
          _prefs.getBool(_keyGeofenceSilenceEnabled) ?? true,
      masterSilenceEnabled: _prefs.getBool(_keyMasterSilenceEnabled) ?? true,
      gpsCalibrationMinutes:
          _prefs.getInt(_keyGpsCalibrationMinutes) ??
          AppSettings.defaultGpsCalibrationMinutes,
      masjidRadiusMeters:
          _prefs.getInt(_keyMasjidRadiusMeters) ??
          AppSettings.defaultMasjidRadiusMeters,
      requireMasjidDwellBeforeSilence:
          _prefs.getBool(_keyRequireMasjidDwellBeforeSilence) ?? false,
      fastGeoExitTrackingEnabled: fastGeoExitTrackingEnabled,
      silenceLevel: _enumByName(
        SilenceLevel.values,
        silenceLevelName,
        SilenceLevel.totalSilence,
      ),
      usePerPrayerConfig: _prefs.getBool(_keyUsePerPrayerConfig) ?? false,
      onboardingComplete: _prefs.getBool(_keyOnboardingComplete) ?? false,
      languageCode: _prefs.getString(_keyLanguageCode) ?? 'en',
      latitude: _prefs.getDouble(_keyLatitude),
      longitude: _prefs.getDouble(_keyLongitude),
    );
  }

  /// Save all settings to storage.
  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(
      _keyCalculationMethod,
      settings.calculationMethod.name,
    );
    await _prefs.setString(
      _keyTimingPreferences,
      jsonEncode(settings.timingPreferences.toJson()),
    );
    await _prefs.setBool(
      _keyAutoSilentEnabled,
      settings.timeBasedSilenceEnabled,
    );
    await _prefs.setBool(
      _keyGeofenceSilenceEnabled,
      settings.geofenceSilenceEnabled,
    );
    await _prefs.setBool(
      _keyMasterSilenceEnabled,
      settings.masterSilenceEnabled,
    );
    await _prefs.setInt(
      _keyGpsCalibrationMinutes,
      settings.gpsCalibrationMinutes,
    );
    await _prefs.setInt(_keyMasjidRadiusMeters, settings.masjidRadiusMeters);
    await _prefs.setBool(
      _keyRequireMasjidDwellBeforeSilence,
      settings.requireMasjidDwellBeforeSilence,
    );
    await _prefs.setBool(
      _keyFastGeoExitTrackingEnabled,
      settings.fastGeoExitTrackingEnabled,
    );
    await _prefs.setBool(_keyFastGeoExitTrackingUserChoice, true);
    await _prefs.setString(_keySilenceLevel, settings.silenceLevel.name);
    await _prefs.setBool(_keyUsePerPrayerConfig, settings.usePerPrayerConfig);
    await _prefs.setBool(_keyOnboardingComplete, settings.onboardingComplete);
    await _prefs.setString(_keyLanguageCode, settings.languageCode);
    if (settings.latitude != null) {
      await _prefs.setDouble(_keyLatitude, settings.latitude!);
    } else {
      await _prefs.remove(_keyLatitude);
    }
    if (settings.longitude != null) {
      await _prefs.setDouble(_keyLongitude, settings.longitude!);
    } else {
      await _prefs.remove(_keyLongitude);
    }
  }

  /// Save just the location.
  Future<void> saveLocation(double latitude, double longitude) async {
    await _prefs.setDouble(_keyLatitude, latitude);
    await _prefs.setDouble(_keyLongitude, longitude);
  }

  /// Clear stored location.
  Future<void> clearLocation() async {
    await _prefs.remove(_keyLatitude);
    await _prefs.remove(_keyLongitude);
  }

  /// Mark onboarding as complete.
  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(_keyOnboardingComplete, true);
  }

  /// Look up an enum value by name with a fallback default.
  T _enumByName<T extends Enum>(List<T> values, String? name, T defaultValue) {
    if (name == null) return defaultValue;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return defaultValue;
  }
}
