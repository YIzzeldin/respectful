import '../models/prayer_day.dart';
import '../models/prayer_timing_config.dart';
import '../models/silence_window.dart';

/// Pure function: computes silence windows from prayer times + per-prayer configs.
/// Handles overlapping windows (merges them), midnight crossing, and Jumu'ah.
class SilenceWindowCalculator {
  /// Compute silence windows for a day.
  /// On Fridays, Dhuhr uses Jumu'ah config automatically.
  List<SilenceWindow> computeWindows(
    PrayerDay day,
    TimingPreferences prefs,
  ) {
    final prayers = [
      PrayerName.fajr,
      PrayerName.dhuhr,
      PrayerName.asr,
      PrayerName.maghrib,
      PrayerName.isha,
    ];

    final windows = <SilenceWindow>[];

    for (final prayer in prayers) {
      final config = prefs.configForPrayerOnDate(prayer, day.date);
      if (!config.enabled) continue;

      final prayerTime = day.timeForPrayer(prayer);
      if (prayerTime == null) continue;

      // Determine the display name (Jumu'ah on Friday Dhuhr)
      final displayPrayer =
          (prayer == PrayerName.dhuhr && day.date.weekday == DateTime.friday)
              ? PrayerName.jumuah
              : prayer;

      // prayerTime from adhan = azan time
      // iqamah time = azan + iqamahOffsetMinutes
      // Silence starts: iqamah - minutesBeforeIqamah = azan + iqamahOffset - beforeIqamah
      // Silence ends: iqamah + prayerDuration + minutesAfter
      final iqamahTime = prayerTime.add(Duration(minutes: config.iqamahOffsetMinutes));
      final start = iqamahTime.subtract(Duration(minutes: config.minutesBeforeIqamah));
      final end = iqamahTime.add(Duration(
          minutes: PrayerTimingConfig.prayerDurationMinutes +
              config.minutesAfter));

      windows.add(SilenceWindow(
        prayer: displayPrayer,
        start: start,
        end: end,
      ));
    }

    return _mergeOverlapping(windows);
  }

  /// Compute windows for today + tomorrow's Fajr.
  /// This ensures overnight scheduling works correctly.
  List<SilenceWindow> computeWindowsWithTomorrowFajr(
    PrayerDay today,
    PrayerDay tomorrow,
    TimingPreferences prefs,
  ) {
    final todayWindows = computeWindows(today, prefs);

    // Add tomorrow's Fajr if configured
    final fajrConfig = prefs.configForPrayerOnDate(PrayerName.fajr, tomorrow.date);
    if (fajrConfig.enabled) {
      final fajrTime = tomorrow.timeForPrayer(PrayerName.fajr);
      if (fajrTime != null) {
        final fajrIqamah = fajrTime.add(Duration(minutes: fajrConfig.iqamahOffsetMinutes));
        final fajrWindow = SilenceWindow(
          prayer: PrayerName.fajr,
          start: fajrIqamah.subtract(Duration(minutes: fajrConfig.minutesBeforeIqamah)),
          end: fajrIqamah.add(Duration(
              minutes: PrayerTimingConfig.prayerDurationMinutes +
                  fajrConfig.minutesAfter)),
        );
        // Only add if it doesn't overlap with today's windows
        // (edge case: Isha extends past midnight into Fajr territory)
        final allWindows = [...todayWindows, fajrWindow];
        return _mergeOverlapping(allWindows);
      }
    }

    return todayWindows;
  }

  /// Find the currently active silence window, if any.
  SilenceWindow? activeWindow(List<SilenceWindow> windows, DateTime now) {
    for (final window in windows) {
      if (window.isActive(now)) return window;
    }
    return null;
  }

  /// Find the next upcoming silence window after [now].
  SilenceWindow? nextWindow(List<SilenceWindow> windows, DateTime now) {
    for (final window in windows) {
      if (window.start.isAfter(now)) return window;
    }
    return null;
  }

  /// Merge overlapping silence windows.
  /// Input must be sorted by start time (computeWindows produces sorted output).
  List<SilenceWindow> _mergeOverlapping(List<SilenceWindow> windows) {
    if (windows.length <= 1) return windows;

    // Sort by start time
    final sorted = List<SilenceWindow>.from(windows)
      ..sort((a, b) => a.start.compareTo(b.start));

    final merged = <SilenceWindow>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      final last = merged.last;

      if (last.overlaps(current) || last.end.isAtSameMomentAs(current.start)) {
        // Merge: extend the last window to cover both
        merged[merged.length - 1] = last.mergeWith(current);
      } else {
        merged.add(current);
      }
    }

    return merged;
  }
}
