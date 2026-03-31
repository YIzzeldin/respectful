import 'package:flutter_test/flutter_test.dart';
import 'package:respectful/models/suppression_state.dart';

void main() {
  group('SuppressionState.fromNativeMap', () {
    test('builds a prayer suppression reason from native state', () {
      final state = SuppressionState.fromNativeMap({
        'isPrayerSilenced': true,
        'currentPrayer': 'Dhuhr',
        'prayerSilencedAtMs': 1_000,
        'prayerWindowEndMs': 2_000,
        'isGeoSilenced': false,
      });

      expect(state.isSuppressed, true);
      expect(state.hasTimeReason, true);
      expect(state.hasGeoReason, false);
      expect(state.currentPrayerName, 'Dhuhr');
      expect(
        state.prayerActivatedAt,
        DateTime.fromMillisecondsSinceEpoch(1_000),
      );
    });

    test('builds geo suppression reasons from active masjid ids', () {
      final state = SuppressionState.fromNativeMap({
        'isPrayerSilenced': false,
        'isGeoSilenced': true,
        'geoSilencedAtMs': 5_000,
        'activeMasjidIds': ['a', 'b'],
      });

      expect(state.isSuppressed, true);
      expect(state.hasTimeReason, false);
      expect(state.hasGeoReason, true);
      expect(state.activeReasons.length, 2);
      expect(state.geoActivatedAt, DateTime.fromMillisecondsSinceEpoch(5_000));
    });

    test('does not infer suppression without active native flags', () {
      final state = SuppressionState.fromNativeMap({
        'isPrayerSilenced': false,
        'isGeoSilenced': false,
        'currentPrayer': 'Asr',
        'prayerWindowEndMs': 10_000,
      });

      expect(state.isSuppressed, false);
      expect(state.hasTimeReason, false);
      expect(state.hasGeoReason, false);
      expect(state.currentPrayerName, isNull);
    });
  });
}
