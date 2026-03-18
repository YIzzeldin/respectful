import 'package:flutter_test/flutter_test.dart';
import 'package:respectful/services/location_service.dart';

void main() {
  late LocationService service;

  setUp(() {
    service = LocationService();
  });

  group('Travel detection', () {
    test('detects significant movement (>10km)', () {
      // Makkah to Jeddah (~75km)
      expect(
        service.hasMovedSignificantly(
          storedLat: 21.4225,
          storedLng: 39.8262,
          currentLat: 21.5433,
          currentLng: 39.1728,
        ),
        true,
      );
    });

    test('ignores small movement (<10km)', () {
      // Same neighborhood (~1km)
      expect(
        service.hasMovedSignificantly(
          storedLat: 21.4225,
          storedLng: 39.8262,
          currentLat: 21.4280,
          currentLng: 39.8300,
        ),
        false,
      );
    });

    test('detects cross-country travel', () {
      // Riyadh to Dubai (~900km)
      expect(
        service.hasMovedSignificantly(
          storedLat: 24.7136,
          storedLng: 46.6753,
          currentLat: 25.2048,
          currentLng: 55.2708,
        ),
        true,
      );
    });

    test('same location returns false', () {
      expect(
        service.hasMovedSignificantly(
          storedLat: 21.4225,
          storedLng: 39.8262,
          currentLat: 21.4225,
          currentLng: 39.8262,
        ),
        false,
      );
    });

    test('custom threshold works', () {
      // ~5km apart, should be significant with 3km threshold
      expect(
        service.hasMovedSignificantly(
          storedLat: 21.4225,
          storedLng: 39.8262,
          currentLat: 21.4600,
          currentLng: 39.8500,
          thresholdKm: 3.0,
        ),
        true,
      );
    });
  });
}
