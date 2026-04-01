import 'package:flutter_test/flutter_test.dart';
import 'package:respectful/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorageService fast exit tracking migration', () {
    test('defaults legacy installs to fast exit tracking on', () async {
      SharedPreferences.setMockInitialValues({
        'fast_geo_exit_tracking_enabled': false,
      });

      final storage = StorageService();
      await storage.init();
      final settings = storage.loadSettings();

      expect(settings.fastGeoExitTrackingEnabled, true);
    });

    test('respects an explicit user opt-out', () async {
      SharedPreferences.setMockInitialValues({
        'fast_geo_exit_tracking_enabled': false,
        'fast_geo_exit_tracking_user_choice': true,
      });

      final storage = StorageService();
      await storage.init();
      final settings = storage.loadSettings();

      expect(settings.fastGeoExitTrackingEnabled, false);
    });
  });
}
