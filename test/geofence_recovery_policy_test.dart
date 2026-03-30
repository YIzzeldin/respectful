import 'package:flutter_test/flutter_test.dart';
import 'package:respectful/services/geofence_recovery_policy.dart';

void main() {
  const policy = GeofenceRecoveryPolicy();

  group('GeofenceRecoveryPolicy', () {
    test('uses a 20m minimum boundary buffer for small geofences', () {
      expect(policy.boundaryBufferMeters(100), 20);
      expect(policy.enterRepairThresholdMeters(100), 80);
      expect(policy.exitRepairThresholdMeters(100), 120);
    });

    test('scales boundary buffer with radius for larger geofences', () {
      expect(policy.boundaryBufferMeters(300), 30);
      expect(policy.enterRepairThresholdMeters(300), 270);
      expect(policy.exitRepairThresholdMeters(300), 330);
    });

    test('repairs enter only when comfortably inside the radius', () {
      expect(
        policy.shouldRepairEnter(
          nearestDistanceMeters: 129,
          radiusMeters: 150,
        ),
        true,
      );
      expect(
        policy.shouldRepairEnter(
          nearestDistanceMeters: 135,
          radiusMeters: 150,
        ),
        false,
      );
    });

    test('repairs exit only when clearly outside the radius', () {
      expect(
        policy.shouldRepairExit(
          nearestDistanceMeters: 171,
          radiusMeters: 150,
        ),
        true,
      );
      expect(
        policy.shouldRepairExit(
          nearestDistanceMeters: 165,
          radiusMeters: 150,
        ),
        false,
      );
    });
  });
}
