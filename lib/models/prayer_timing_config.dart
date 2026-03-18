import 'prayer_day.dart';

/// Per-prayer timing configuration: how long before, during, and after each prayer
/// the phone should be silenced.
class PrayerTimingConfig {
  final int minutesBefore;
  final int durationMinutes;
  final int minutesAfter;
  final bool enabled;

  const PrayerTimingConfig({
    required this.minutesBefore,
    required this.durationMinutes,
    required this.minutesAfter,
    this.enabled = true,
  });

  /// Total silence window length in minutes.
  int get totalMinutes => minutesBefore + durationMinutes + minutesAfter;

  Map<String, dynamic> toJson() => {
        'minutesBefore': minutesBefore,
        'durationMinutes': durationMinutes,
        'minutesAfter': minutesAfter,
        'enabled': enabled,
      };

  factory PrayerTimingConfig.fromJson(Map<String, dynamic> json) =>
      PrayerTimingConfig(
        minutesBefore: json['minutesBefore'] as int? ?? 5,
        durationMinutes: json['durationMinutes'] as int? ?? 20,
        minutesAfter: json['minutesAfter'] as int? ?? 5,
        enabled: json['enabled'] as bool? ?? true,
      );

  /// Sensible defaults per prayer.
  static PrayerTimingConfig defaultFor(PrayerName prayer) {
    switch (prayer) {
      case PrayerName.fajr:
        return const PrayerTimingConfig(
            minutesBefore: 5, durationMinutes: 25, minutesAfter: 5);
      case PrayerName.dhuhr:
        return const PrayerTimingConfig(
            minutesBefore: 5, durationMinutes: 20, minutesAfter: 5);
      case PrayerName.asr:
        return const PrayerTimingConfig(
            minutesBefore: 5, durationMinutes: 20, minutesAfter: 5);
      case PrayerName.maghrib:
        return const PrayerTimingConfig(
            minutesBefore: 5, durationMinutes: 15, minutesAfter: 5);
      case PrayerName.isha:
        return const PrayerTimingConfig(
            minutesBefore: 5, durationMinutes: 25, minutesAfter: 5);
      case PrayerName.jumuah:
        return const PrayerTimingConfig(
            minutesBefore: 10, durationMinutes: 45, minutesAfter: 10);
    }
  }

  PrayerTimingConfig copyWith({
    int? minutesBefore,
    int? durationMinutes,
    int? minutesAfter,
    bool? enabled,
  }) =>
      PrayerTimingConfig(
        minutesBefore: minutesBefore ?? this.minutesBefore,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        minutesAfter: minutesAfter ?? this.minutesAfter,
        enabled: enabled ?? this.enabled,
      );
}

/// All per-prayer timing configs stored together.
class TimingPreferences {
  final Map<PrayerName, PrayerTimingConfig> configs;

  const TimingPreferences({required this.configs});

  factory TimingPreferences.defaults() => TimingPreferences(
        configs: {
          for (final prayer in PrayerName.values)
            prayer: PrayerTimingConfig.defaultFor(prayer),
        },
      );

  PrayerTimingConfig configFor(PrayerName prayer) =>
      configs[prayer] ?? PrayerTimingConfig.defaultFor(prayer);

  /// On Friday, use Jumuah config for Dhuhr slot.
  PrayerTimingConfig configForPrayerOnDate(PrayerName prayer, DateTime date) {
    if (prayer == PrayerName.dhuhr && date.weekday == DateTime.friday) {
      return configFor(PrayerName.jumuah);
    }
    return configFor(prayer);
  }

  TimingPreferences withConfig(PrayerName prayer, PrayerTimingConfig config) =>
      TimingPreferences(configs: {...configs, prayer: config});

  Map<String, dynamic> toJson() => {
        for (final entry in configs.entries)
          entry.key.name: entry.value.toJson(),
      };

  factory TimingPreferences.fromJson(Map<String, dynamic> json) {
    final configs = <PrayerName, PrayerTimingConfig>{};
    for (final prayer in PrayerName.values) {
      final data = json[prayer.name];
      if (data != null) {
        configs[prayer] =
            PrayerTimingConfig.fromJson(data as Map<String, dynamic>);
      } else {
        configs[prayer] = PrayerTimingConfig.defaultFor(prayer);
      }
    }
    return TimingPreferences(configs: configs);
  }
}
