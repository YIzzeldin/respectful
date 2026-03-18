import 'package:flutter_test/flutter_test.dart';
import 'package:respectful/models/prayer_day.dart';
import 'package:respectful/models/prayer_timing_config.dart';
import 'package:respectful/models/silence_window.dart';
import 'package:respectful/services/silence_window_calculator.dart';

void main() {
  late SilenceWindowCalculator calculator;
  late TimingPreferences defaultPrefs;

  setUp(() {
    calculator = SilenceWindowCalculator();
    defaultPrefs = TimingPreferences.defaults();
  });

  PrayerDay makePrayerDay({
    DateTime? date,
    DateTime? fajr,
    DateTime? dhuhr,
    DateTime? asr,
    DateTime? maghrib,
    DateTime? isha,
  }) {
    final d = date ?? DateTime(2026, 3, 18); // Wednesday
    return PrayerDay(
      date: d,
      fajr: fajr ?? DateTime(d.year, d.month, d.day, 5, 15),
      dhuhr: dhuhr ?? DateTime(d.year, d.month, d.day, 12, 30),
      asr: asr ?? DateTime(d.year, d.month, d.day, 15, 45),
      maghrib: maghrib ?? DateTime(d.year, d.month, d.day, 18, 20),
      isha: isha ?? DateTime(d.year, d.month, d.day, 19, 50),
    );
  }

  group('Basic window computation', () {
    test('produces 5 windows for a normal day', () {
      final day = makePrayerDay();
      final windows = calculator.computeWindows(day, defaultPrefs);
      expect(windows.length, 5);
    });

    test('window start is prayer_time - minutesBefore', () {
      final day = makePrayerDay();
      final windows = calculator.computeWindows(day, defaultPrefs);
      final fajrWindow = windows.first;
      // Default Fajr: 5 min before
      expect(fajrWindow.start, DateTime(2026, 3, 18, 5, 10));
    });

    test('window end is prayer_time + duration + minutesAfter', () {
      final day = makePrayerDay();
      final windows = calculator.computeWindows(day, defaultPrefs);
      final fajrWindow = windows.first;
      // Default Fajr: 25 min duration + 5 min after = 30 min after prayer
      expect(fajrWindow.end, DateTime(2026, 3, 18, 5, 45));
    });

    test('disabled prayer is skipped', () {
      final prefs = defaultPrefs.withConfig(
        PrayerName.asr,
        PrayerTimingConfig.defaultFor(PrayerName.asr).copyWith(enabled: false),
      );
      final day = makePrayerDay();
      final windows = calculator.computeWindows(day, prefs);
      expect(windows.length, 4);
      expect(windows.any((w) => w.prayer == PrayerName.asr), false);
    });
  });

  group('Jumu\'ah handling', () {
    test('uses Jumu\'ah config for Dhuhr on Friday', () {
      final friday = DateTime(2026, 3, 20); // Friday
      final day = makePrayerDay(date: friday);
      final windows = calculator.computeWindows(day, defaultPrefs);

      final dhuhrWindow = windows.firstWhere(
        (w) => w.prayer == PrayerName.jumuah,
      );
      // Jumu'ah default: 10 min before, 45 min duration, 10 min after
      expect(dhuhrWindow.start, DateTime(2026, 3, 20, 12, 20));
      expect(dhuhrWindow.end, DateTime(2026, 3, 20, 13, 25));
    });

    test('uses Dhuhr config on non-Friday', () {
      final thursday = DateTime(2026, 3, 19); // Thursday
      final day = makePrayerDay(date: thursday);
      final windows = calculator.computeWindows(day, defaultPrefs);

      final dhuhrWindow = windows.firstWhere(
        (w) => w.prayer == PrayerName.dhuhr,
      );
      // Dhuhr default: 5 min before, 20 min duration, 5 min after
      expect(dhuhrWindow.start, DateTime(2026, 3, 19, 12, 25));
      expect(dhuhrWindow.end, DateTime(2026, 3, 19, 12, 55));
    });
  });

  group('Overlapping window merging', () {
    test('merges overlapping Maghrib and Isha', () {
      // Set Maghrib with long duration so it overlaps with Isha
      final prefs = defaultPrefs
          .withConfig(
            PrayerName.maghrib,
            const PrayerTimingConfig(
              minutesBefore: 5,
              durationMinutes: 60, // 60 min — will overlap with Isha
              minutesAfter: 15,
            ),
          )
          .withConfig(
            PrayerName.isha,
            const PrayerTimingConfig(
              minutesBefore: 10,
              durationMinutes: 25,
              minutesAfter: 5,
            ),
          );

      // Maghrib at 18:20, Isha at 19:50
      // Maghrib window: 18:15 - 19:35 (5 before, 60 dur, 15 after)
      // Isha window: 19:40 - 20:20 (10 before, 25 dur, 5 after)
      // Gap of 5 min — no overlap with default times.
      // Make Isha closer so windows overlap:
      final closeDay = makePrayerDay(
        isha: DateTime(2026, 3, 18, 19, 20), // Isha at 19:20 instead of 19:50
      );
      final closeWindows = calculator.computeWindows(closeDay, prefs);

      // Maghrib window: 18:15 - 19:35
      // Isha window: 19:10 - 19:50 (10 before 19:20)
      // These overlap at 19:10-19:35
      final mergedWindow = closeWindows.firstWhere(
        (w) => w.mergedPrayers.isNotEmpty,
        orElse: () => closeWindows.last,
      );
      expect(mergedWindow.mergedPrayers.length, 2);
      expect(mergedWindow.mergedPrayers.contains(PrayerName.maghrib), true);
      expect(mergedWindow.mergedPrayers.contains(PrayerName.isha), true);
      expect(mergedWindow.start, DateTime(2026, 3, 18, 18, 15));
      expect(mergedWindow.end, DateTime(2026, 3, 18, 19, 50));
    });

    test('adjacent windows (end == start) are merged', () {
      // Set Dhuhr to end exactly when Asr starts
      final prefs = defaultPrefs.withConfig(
        PrayerName.dhuhr,
        const PrayerTimingConfig(
          minutesBefore: 5,
          durationMinutes: 190, // ends at 15:40
          minutesAfter: 0,
        ),
      );
      // Asr at 15:45, 5 min before = starts at 15:40
      final day = makePrayerDay();
      final windows = calculator.computeWindows(day, prefs);

      final merged = windows.where((w) => w.mergedPrayers.isNotEmpty);
      expect(merged.length, 1);
    });
  });

  group('Active window detection', () {
    test('finds active window at prayer time', () {
      final day = makePrayerDay();
      final windows = calculator.computeWindows(day, defaultPrefs);
      final now = DateTime(2026, 3, 18, 12, 35); // During Dhuhr
      final active = calculator.activeWindow(windows, now);
      expect(active, isNotNull);
      expect(active!.prayer, PrayerName.dhuhr);
    });

    test('returns null between prayers', () {
      final day = makePrayerDay();
      final windows = calculator.computeWindows(day, defaultPrefs);
      final now = DateTime(2026, 3, 18, 10, 0); // Between Fajr and Dhuhr
      final active = calculator.activeWindow(windows, now);
      expect(active, isNull);
    });

    test('finds next window', () {
      final day = makePrayerDay();
      final windows = calculator.computeWindows(day, defaultPrefs);
      final now = DateTime(2026, 3, 18, 10, 0);
      final next = calculator.nextWindow(windows, now);
      expect(next, isNotNull);
      expect(next!.prayer, PrayerName.dhuhr);
    });
  });

  group('Per-prayer customization', () {
    test('each prayer uses its own config', () {
      final prefs = TimingPreferences(configs: {
        PrayerName.fajr: const PrayerTimingConfig(
            minutesBefore: 10, durationMinutes: 30, minutesAfter: 10),
        PrayerName.dhuhr: const PrayerTimingConfig(
            minutesBefore: 3, durationMinutes: 15, minutesAfter: 3),
        PrayerName.asr: const PrayerTimingConfig(
            minutesBefore: 5, durationMinutes: 20, minutesAfter: 5),
        PrayerName.maghrib: const PrayerTimingConfig(
            minutesBefore: 2, durationMinutes: 10, minutesAfter: 2),
        PrayerName.isha: const PrayerTimingConfig(
            minutesBefore: 5, durationMinutes: 25, minutesAfter: 5),
        PrayerName.jumuah: const PrayerTimingConfig(
            minutesBefore: 15, durationMinutes: 60, minutesAfter: 10),
      });

      final day = makePrayerDay();
      final windows = calculator.computeWindows(day, prefs);

      // Fajr: 5:15 - 10 before = 5:05, + 30 + 10 = 5:55
      expect(windows[0].start, DateTime(2026, 3, 18, 5, 5));
      expect(windows[0].end, DateTime(2026, 3, 18, 5, 55));

      // Dhuhr: 12:30 - 3 before = 12:27, + 15 + 3 = 12:48
      expect(windows[1].start, DateTime(2026, 3, 18, 12, 27));
      expect(windows[1].end, DateTime(2026, 3, 18, 12, 48));
    });
  });

  group('SilenceWindow model', () {
    test('isActive at start boundary', () {
      final w = SilenceWindow(
        prayer: PrayerName.dhuhr,
        start: DateTime(2026, 3, 18, 12, 0),
        end: DateTime(2026, 3, 18, 12, 30),
      );
      expect(w.isActive(DateTime(2026, 3, 18, 12, 0)), true);
      expect(w.isActive(DateTime(2026, 3, 18, 12, 30)), false);
      expect(w.isActive(DateTime(2026, 3, 18, 11, 59)), false);
    });

    test('remaining time calculates correctly', () {
      final w = SilenceWindow(
        prayer: PrayerName.dhuhr,
        start: DateTime(2026, 3, 18, 12, 0),
        end: DateTime(2026, 3, 18, 12, 30),
      );
      expect(
        w.remaining(DateTime(2026, 3, 18, 12, 10)).inMinutes,
        20,
      );
    });

    test('displayName shows merged prayers', () {
      final w = SilenceWindow(
        prayer: PrayerName.maghrib,
        start: DateTime(2026, 3, 18, 18, 0),
        end: DateTime(2026, 3, 18, 20, 0),
        mergedPrayers: [PrayerName.maghrib, PrayerName.isha],
      );
      expect(w.displayName, 'Maghrib + Isha');
    });

    test('toJson/fromJson roundtrip', () {
      final w = SilenceWindow(
        prayer: PrayerName.asr,
        start: DateTime(2026, 3, 18, 15, 0),
        end: DateTime(2026, 3, 18, 15, 30),
      );
      final json = w.toJson();
      final restored = SilenceWindow.fromJson(json);
      expect(restored.prayer, w.prayer);
      expect(restored.start, w.start);
      expect(restored.end, w.end);
    });
  });
}
