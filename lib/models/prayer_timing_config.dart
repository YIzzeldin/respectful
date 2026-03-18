import 'prayer_day.dart';

/// Per-prayer timing configuration.
///
/// Simplified model: user only controls two things:
///   1. Minutes to silence BEFORE the iqamah
///   2. Minutes to stay silent AFTER the prayer
///
/// Prayer duration is fixed at 10 minutes (not user-configurable).
///
/// Timeline: [minutesBeforeIqamah] → IQAMAH → [10 min prayer] → [minutesAfter]
///
/// The adhan library gives us the AZAN time. We add iqamahOffsetMinutes
/// (the gap between azan and iqamah, per prayer) to get the iqamah time.
/// Then the silence window starts minutesBeforeIqamah before that.
class PrayerTimingConfig {
  /// Minutes to silence BEFORE the iqamah (prayer start).
  final int minutesBeforeIqamah;

  /// Minutes between azan and iqamah. This is a fixed per-prayer value,
  /// not directly user-configurable (set via defaults or advanced settings).
  final int iqamahOffsetMinutes;

  /// Minutes to stay silent AFTER the prayer ends.
  final int minutesAfter;

  final bool enabled;

  /// Fixed prayer duration — not user-configurable.
  static const int prayerDurationMinutes = 10;

  const PrayerTimingConfig({
    required this.minutesBeforeIqamah,
    this.iqamahOffsetMinutes = 15,
    required this.minutesAfter,
    this.enabled = true,
  });

  /// Total silence window length in minutes.
  int get totalMinutes =>
      minutesBeforeIqamah + prayerDurationMinutes + minutesAfter;

  /// The full window from azan perspective (used by silence window calculator).
  /// Silence starts at: azan_time + iqamahOffset - minutesBeforeIqamah
  /// Silence ends at: azan_time + iqamahOffset + prayerDuration + minutesAfter
  int get minutesBeforeAzan {
    final beforeIqamahFromAzan = iqamahOffsetMinutes - minutesBeforeIqamah;
    return beforeIqamahFromAzan < 0 ? -beforeIqamahFromAzan : 0;
  }

  Map<String, dynamic> toJson() => {
        'minutesBeforeIqamah': minutesBeforeIqamah,
        'iqamahOffsetMinutes': iqamahOffsetMinutes,
        'minutesAfter': minutesAfter,
        'enabled': enabled,
      };

  factory PrayerTimingConfig.fromJson(Map<String, dynamic> json, [PrayerName? prayer]) {
    final defaultConfig = prayer != null
        ? PrayerTimingConfig.defaultFor(prayer)
        : const PrayerTimingConfig(minutesBeforeIqamah: 10, minutesAfter: 5);

    // Migration: handle old format with minutesBefore/durationMinutes
    if (json.containsKey('minutesBeforeIqamah')) {
      return PrayerTimingConfig(
        minutesBeforeIqamah: json['minutesBeforeIqamah'] as int? ?? defaultConfig.minutesBeforeIqamah,
        iqamahOffsetMinutes: json['iqamahOffsetMinutes'] as int? ?? defaultConfig.iqamahOffsetMinutes,
        minutesAfter: json['minutesAfter'] as int? ?? defaultConfig.minutesAfter,
        enabled: json['enabled'] as bool? ?? true,
      );
    }

    // Old format migration: convert minutesBefore + iqamahOffset to minutesBeforeIqamah
    final oldBefore = json['minutesBefore'] as int? ?? 5;
    final oldIqamah = json['iqamahOffsetMinutes'] as int? ?? defaultConfig.iqamahOffsetMinutes;
    return PrayerTimingConfig(
      minutesBeforeIqamah: oldBefore + oldIqamah, // combine into single "before iqamah"
      iqamahOffsetMinutes: oldIqamah,
      minutesAfter: json['minutesAfter'] as int? ?? 5,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  /// Sensible defaults per prayer.
  static PrayerTimingConfig defaultFor(PrayerName prayer) {
    switch (prayer) {
      case PrayerName.fajr:
        return const PrayerTimingConfig(
            minutesBeforeIqamah: 25, iqamahOffsetMinutes: 20, minutesAfter: 5);
      case PrayerName.dhuhr:
        return const PrayerTimingConfig(
            minutesBeforeIqamah: 20, iqamahOffsetMinutes: 15, minutesAfter: 5);
      case PrayerName.asr:
        return const PrayerTimingConfig(
            minutesBeforeIqamah: 20, iqamahOffsetMinutes: 15, minutesAfter: 5);
      case PrayerName.maghrib:
        return const PrayerTimingConfig(
            minutesBeforeIqamah: 10, iqamahOffsetMinutes: 5, minutesAfter: 5);
      case PrayerName.isha:
        return const PrayerTimingConfig(
            minutesBeforeIqamah: 20, iqamahOffsetMinutes: 15, minutesAfter: 5);
      case PrayerName.jumuah:
        return const PrayerTimingConfig(
            minutesBeforeIqamah: 40, iqamahOffsetMinutes: 30, minutesAfter: 10);
    }
  }

  PrayerTimingConfig copyWith({
    int? minutesBeforeIqamah,
    int? iqamahOffsetMinutes,
    int? minutesAfter,
    bool? enabled,
  }) =>
      PrayerTimingConfig(
        minutesBeforeIqamah: minutesBeforeIqamah ?? this.minutesBeforeIqamah,
        iqamahOffsetMinutes: iqamahOffsetMinutes ?? this.iqamahOffsetMinutes,
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
