import 'prayer_day.dart';

/// Per-prayer timing configuration.
///
/// Timeline: [minutesBefore azan] → AZAN → [iqamahOffsetMinutes] → PRAYER START → [durationMinutes] → [minutesAfter]
///
/// The adhan library gives us the AZAN time. The actual prayer starts
/// iqamahOffsetMinutes later. Silence window covers the full range.
class PrayerTimingConfig {
  /// Minutes to silence BEFORE the azan.
  final int minutesBefore;

  /// Minutes between azan and iqamah (when prayer actually starts).
  final int iqamahOffsetMinutes;

  /// Duration of the prayer itself in minutes.
  final int durationMinutes;

  /// Minutes to stay silent AFTER the prayer ends.
  final int minutesAfter;

  final bool enabled;

  const PrayerTimingConfig({
    required this.minutesBefore,
    this.iqamahOffsetMinutes = 15,
    required this.durationMinutes,
    required this.minutesAfter,
    this.enabled = true,
  });

  /// Total silence window length in minutes.
  int get totalMinutes =>
      minutesBefore + iqamahOffsetMinutes + durationMinutes + minutesAfter;

  Map<String, dynamic> toJson() => {
        'minutesBefore': minutesBefore,
        'iqamahOffsetMinutes': iqamahOffsetMinutes,
        'durationMinutes': durationMinutes,
        'minutesAfter': minutesAfter,
        'enabled': enabled,
      };

  /// Deserialize. If iqamahOffsetMinutes is missing (pre-migration data),
  /// the caller should provide the prayer name for correct defaults.
  factory PrayerTimingConfig.fromJson(Map<String, dynamic> json, [PrayerName? prayer]) {
    // If iqamahOffsetMinutes is absent in stored data, use prayer-specific default
    final hasIqamah = json.containsKey('iqamahOffsetMinutes');
    final defaultIqamah = prayer != null
        ? PrayerTimingConfig.defaultFor(prayer).iqamahOffsetMinutes
        : 15;

    return PrayerTimingConfig(
      minutesBefore: json['minutesBefore'] as int? ?? 5,
      iqamahOffsetMinutes: hasIqamah
          ? json['iqamahOffsetMinutes'] as int
          : defaultIqamah,
      durationMinutes: json['durationMinutes'] as int? ?? 20,
      minutesAfter: json['minutesAfter'] as int? ?? 5,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  /// Sensible defaults per prayer.
  /// iqamahOffset varies: Maghrib is short (5 min), Jumu'ah is long (30 min for khutbah).
  static PrayerTimingConfig defaultFor(PrayerName prayer) {
    switch (prayer) {
      case PrayerName.fajr:
        return const PrayerTimingConfig(
            minutesBefore: 5, iqamahOffsetMinutes: 20, durationMinutes: 15, minutesAfter: 5);
      case PrayerName.dhuhr:
        return const PrayerTimingConfig(
            minutesBefore: 5, iqamahOffsetMinutes: 15, durationMinutes: 15, minutesAfter: 5);
      case PrayerName.asr:
        return const PrayerTimingConfig(
            minutesBefore: 5, iqamahOffsetMinutes: 15, durationMinutes: 15, minutesAfter: 5);
      case PrayerName.maghrib:
        return const PrayerTimingConfig(
            minutesBefore: 5, iqamahOffsetMinutes: 5, durationMinutes: 10, minutesAfter: 5);
      case PrayerName.isha:
        return const PrayerTimingConfig(
            minutesBefore: 5, iqamahOffsetMinutes: 15, durationMinutes: 15, minutesAfter: 5);
      case PrayerName.jumuah:
        return const PrayerTimingConfig(
            minutesBefore: 10, iqamahOffsetMinutes: 30, durationMinutes: 20, minutesAfter: 10);
    }
  }

  PrayerTimingConfig copyWith({
    int? minutesBefore,
    int? iqamahOffsetMinutes,
    int? durationMinutes,
    int? minutesAfter,
    bool? enabled,
  }) =>
      PrayerTimingConfig(
        minutesBefore: minutesBefore ?? this.minutesBefore,
        iqamahOffsetMinutes: iqamahOffsetMinutes ?? this.iqamahOffsetMinutes,
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
            PrayerTimingConfig.fromJson(data as Map<String, dynamic>, prayer);
      } else {
        configs[prayer] = PrayerTimingConfig.defaultFor(prayer);
      }
    }
    return TimingPreferences(configs: configs);
  }
}
