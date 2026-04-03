import 'prayer_timing_config.dart';

/// Calculation methods supported by the adhan library.
enum CalculationMethodType {
  muslimWorldLeague,
  egyptian,
  karachi,
  ummAlQura,
  dubai,
  qatar,
  kuwait,
  moonsightingCommittee,
  singapore,
  turkey,
  tehran,
  northAmerica,
}

extension CalculationMethodDisplay on CalculationMethodType {
  String get displayName {
    switch (this) {
      case CalculationMethodType.muslimWorldLeague:
        return 'Muslim World League';
      case CalculationMethodType.egyptian:
        return 'Egyptian General Authority';
      case CalculationMethodType.karachi:
        return 'University of Islamic Sciences, Karachi';
      case CalculationMethodType.ummAlQura:
        return 'Umm Al-Qura University, Makkah';
      case CalculationMethodType.dubai:
        return 'Dubai';
      case CalculationMethodType.qatar:
        return 'Qatar';
      case CalculationMethodType.kuwait:
        return 'Kuwait';
      case CalculationMethodType.moonsightingCommittee:
        return 'Moonsighting Committee';
      case CalculationMethodType.singapore:
        return 'Singapore';
      case CalculationMethodType.turkey:
        return 'Turkey';
      case CalculationMethodType.tehran:
        return 'Institute of Geophysics, Tehran';
      case CalculationMethodType.northAmerica:
        return 'ISNA (North America)';
    }
  }
}

/// Silence level options.
enum SilenceLevel {
  /// INTERRUPTION_FILTER_NONE — blocks everything including alarms and calls.
  totalSilence,

  /// INTERRUPTION_FILTER_PRIORITY — blocks notifications but allows alarms and starred contacts.
  prioritySilence,
}

extension SilenceLevelDisplay on SilenceLevel {
  String get displayName {
    switch (this) {
      case SilenceLevel.totalSilence:
        return 'Total Silence';
      case SilenceLevel.prioritySilence:
        return 'Priority Silence';
    }
  }

  String get description {
    switch (this) {
      case SilenceLevel.totalSilence:
        return 'Blocks everything including alarms and calls';
      case SilenceLevel.prioritySilence:
        return 'Blocks notifications, allows alarms and starred contacts';
    }
  }
}

/// All app settings.
class AppSettings {
  static const int defaultMasjidRadiusMeters = 150;
  static const int defaultGpsCalibrationMinutes = 2;

  final CalculationMethodType calculationMethod;
  final TimingPreferences timingPreferences;

  /// Time-based auto-silence (silence at prayer times). OFF by default.
  final bool timeBasedSilenceEnabled;

  /// Geofence-based auto-silence (silence at saved masjids). ON by default — main use case.
  final bool geofenceSilenceEnabled;
  final bool masterSilenceEnabled;

  /// GPS calibration interval in minutes (5-30). Only active when geofencing is enabled.
  final int gpsCalibrationMinutes;

  /// Geofence radius used for masjid detection and duplicate checks.
  final int masjidRadiusMeters;

  /// When enabled, wait for a geofence dwell event before silencing.
  final bool requireMasjidDwellBeforeSilence;

  /// When enabled, use foreground location updates only while geo-silenced
  /// so exit detection can restore faster.
  final bool fastGeoExitTrackingEnabled;

  final SilenceLevel silenceLevel;
  final bool usePerPrayerConfig;
  final bool onboardingComplete;
  final String languageCode; // 'en' or 'ar'
  final double? latitude;
  final double? longitude;

  const AppSettings({
    this.calculationMethod = CalculationMethodType.muslimWorldLeague,
    required this.timingPreferences,
    this.timeBasedSilenceEnabled = false,
    this.geofenceSilenceEnabled = true,
    this.masterSilenceEnabled = true,
    this.gpsCalibrationMinutes = defaultGpsCalibrationMinutes,
    this.masjidRadiusMeters = defaultMasjidRadiusMeters,
    this.requireMasjidDwellBeforeSilence = false,
    this.fastGeoExitTrackingEnabled = true,
    this.silenceLevel = SilenceLevel.totalSilence,
    this.usePerPrayerConfig = false,
    this.onboardingComplete = false,
    this.languageCode = 'en',
    this.latitude,
    this.longitude,
  });

  factory AppSettings.defaults() =>
      AppSettings(timingPreferences: TimingPreferences.defaults());

  bool get hasLocation => latitude != null && longitude != null;
  double get masjidRadiusKm => masjidRadiusMeters / 1000.0;

  AppSettings copyWith({
    CalculationMethodType? calculationMethod,
    TimingPreferences? timingPreferences,
    bool? timeBasedSilenceEnabled,
    bool? geofenceSilenceEnabled,
    bool? masterSilenceEnabled,
    int? gpsCalibrationMinutes,
    int? masjidRadiusMeters,
    bool? requireMasjidDwellBeforeSilence,
    bool? fastGeoExitTrackingEnabled,
    SilenceLevel? silenceLevel,
    bool? usePerPrayerConfig,
    bool? onboardingComplete,
    String? languageCode,
    double? latitude,
    double? longitude,
  }) => AppSettings(
    calculationMethod: calculationMethod ?? this.calculationMethod,
    timingPreferences: timingPreferences ?? this.timingPreferences,
    timeBasedSilenceEnabled:
        timeBasedSilenceEnabled ?? this.timeBasedSilenceEnabled,
    geofenceSilenceEnabled:
        geofenceSilenceEnabled ?? this.geofenceSilenceEnabled,
    masterSilenceEnabled: masterSilenceEnabled ?? this.masterSilenceEnabled,
    gpsCalibrationMinutes: gpsCalibrationMinutes ?? this.gpsCalibrationMinutes,
    masjidRadiusMeters: masjidRadiusMeters ?? this.masjidRadiusMeters,
    requireMasjidDwellBeforeSilence:
        requireMasjidDwellBeforeSilence ?? this.requireMasjidDwellBeforeSilence,
    fastGeoExitTrackingEnabled:
        fastGeoExitTrackingEnabled ?? this.fastGeoExitTrackingEnabled,
    silenceLevel: silenceLevel ?? this.silenceLevel,
    usePerPrayerConfig: usePerPrayerConfig ?? this.usePerPrayerConfig,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    languageCode: languageCode ?? this.languageCode,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
  );
}
