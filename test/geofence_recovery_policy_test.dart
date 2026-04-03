import 'package:flutter_test/flutter_test.dart';
import 'package:respectful/services/geofence_recovery_policy.dart';

void main() {
  const policy = GeofenceRecoveryPolicy();

  group('GeofenceRecoveryPolicy', () {
    test('uses a 20m minimum boundary buffer for small geofences', () {
      expect(policy.boundaryBufferMeters(100), 20);
      expect(policy.enterRepairThresholdMeters(100), 80);
      expect(policy.exitBoundaryBufferMeters(100), 5);
      expect(policy.exitRepairThresholdMeters(100), 105);
    });

    test('uses a tighter exit buffer than the enter buffer', () {
      expect(policy.boundaryBufferMeters(300), 30);
      expect(policy.enterRepairThresholdMeters(300), 270);
      expect(policy.exitBoundaryBufferMeters(300), 9);
      expect(policy.exitRepairThresholdMeters(300), 309);
    });

    test('repairs enter only when comfortably inside the radius', () {
      expect(
        policy.shouldRepairEnter(nearestDistanceMeters: 129, radiusMeters: 150),
        true,
      );
      expect(
        policy.shouldRepairEnter(nearestDistanceMeters: 135, radiusMeters: 150),
        false,
      );
    });

    test('repairs exit only when clearly outside the radius', () {
      expect(
        policy.shouldRepairExit(nearestDistanceMeters: 156, radiusMeters: 150),
        true,
      );
      expect(
        policy.shouldRepairExit(nearestDistanceMeters: 154, radiusMeters: 150),
        false,
      );
    });
  });
}
