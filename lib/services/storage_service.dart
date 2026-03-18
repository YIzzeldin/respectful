import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/prayer_timing_config.dart';

/// Wrapper around SharedPreferences for typed access to app settings.
class StorageService {
  static const _keyCalculationMethod = 'calculation_method';
  static const _keyTimingPreferences = 'timing_preferences';
  static const _keyAutoSilentEnabled = 'auto_silent_enabled';
  static const _keySilenceLevel = 'silence_level';
  static const _keyUsePerPrayerConfig = 'use_per_prayer_config';
  static const _keyOnboardingComplete = 'onboarding_complete';
  static const _keyLatitude = 'latitude';
  static const _keyLongitude = 'longitude';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Load all settings from storage.
  AppSettings loadSettings() {
    final methodIndex = _prefs.getInt(_keyCalculationMethod) ?? 0;
    final timingJson = _prefs.getString(_keyTimingPreferences);
    final silenceLevelIndex = _prefs.getInt(_keySilenceLevel) ?? 0;

    return AppSettings(
      calculationMethod: CalculationMethodType.values[
          methodIndex.clamp(0, CalculationMethodType.values.length - 1)],
      timingPreferences: timingJson != null
          ? TimingPreferences.fromJson(
              jsonDecode(timingJson) as Map<String, dynamic>)
          : TimingPreferences.defaults(),
      autoSilentEnabled: _prefs.getBool(_keyAutoSilentEnabled) ?? true,
      silenceLevel: SilenceLevel.values[
          silenceLevelIndex.clamp(0, SilenceLevel.values.length - 1)],
      usePerPrayerConfig: _prefs.getBool(_keyUsePerPrayerConfig) ?? false,
      onboardingComplete: _prefs.getBool(_keyOnboardingComplete) ?? false,
      latitude: _prefs.getDouble(_keyLatitude),
      longitude: _prefs.getDouble(_keyLongitude),
    );
  }

  /// Save all settings to storage.
  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setInt(
        _keyCalculationMethod, settings.calculationMethod.index);
    await _prefs.setString(
        _keyTimingPreferences, jsonEncode(settings.timingPreferences.toJson()));
    await _prefs.setBool(_keyAutoSilentEnabled, settings.autoSilentEnabled);
    await _prefs.setInt(_keySilenceLevel, settings.silenceLevel.index);
    await _prefs.setBool(_keyUsePerPrayerConfig, settings.usePerPrayerConfig);
    await _prefs.setBool(_keyOnboardingComplete, settings.onboardingComplete);
    if (settings.latitude != null) {
      await _prefs.setDouble(_keyLatitude, settings.latitude!);
    }
    if (settings.longitude != null) {
      await _prefs.setDouble(_keyLongitude, settings.longitude!);
    }
  }

  /// Save just the location.
  Future<void> saveLocation(double latitude, double longitude) async {
    await _prefs.setDouble(_keyLatitude, latitude);
    await _prefs.setDouble(_keyLongitude, longitude);
  }

  /// Mark onboarding as complete.
  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(_keyOnboardingComplete, true);
  }
}
