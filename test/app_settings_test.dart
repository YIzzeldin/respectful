import 'package:flutter_test/flutter_test.dart';
import 'package:respectful/models/app_settings.dart';
import 'package:respectful/models/prayer_timing_config.dart';

void main() {
  group('AppSettings', () {
    test('defaults include 200m radius and dwell protection off', () {
      final settings = AppSettings.defaults();

      expect(settings.masjidRadiusMeters, AppSettings.defaultMasjidRadiusMeters);
      expect(settings.masjidRadiusMeters, 200);
      expect(settings.masjidRadiusKm, 0.2);
      expect(settings.requireMasjidDwellBeforeSilence, false);
    });

    test('copyWith updates radius and dwell settings', () {
      final settings = AppSettings.defaults().copyWith(
        masjidRadiusMeters: 275,
        requireMasjidDwellBeforeSilence: true,
      );

      expect(settings.masjidRadiusMeters, 275);
      expect(settings.masjidRadiusKm, 0.275);
      expect(settings.requireMasjidDwellBeforeSilence, true);
    });

    test('copyWith preserves unrelated settings', () {
      final settings = AppSettings.defaults().copyWith(
        timingPreferences: TimingPreferences.defaults(),
        geofenceSilenceEnabled: true,
      );
      final updated = settings.copyWith(masjidRadiusMeters: 300);

      expect(updated.geofenceSilenceEnabled, true);
      expect(updated.requireMasjidDwellBeforeSilence, false);
      expect(updated.masjidRadiusMeters, 300);
    });
  });
}
