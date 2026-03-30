import 'dart:math' as math;

/// Shared thresholds for GPS-assisted geofence recovery.
///
/// Native geofence transitions remain the primary signal. These thresholds
/// are only for repair paths when Android misses an enter/exit transition.
class GeofenceRecoveryPolicy {
  static const int exitChecksBeforeRestore = 2;
  static const Duration exitCheckInterval = Duration(seconds: 45);

  const GeofenceRecoveryPolicy();

  double boundaryBufferMeters(int radiusMeters) {
    final radius = radiusMeters.clamp(50, 1000).toDouble();
    return math.max(20.0, radius * 0.10);
  }

  double enterRepairThresholdMeters(int radiusMeters) {
    return math.max(0.0, radiusMeters.toDouble() - boundaryBufferMeters(radiusMeters));
  }

  double exitRepairThresholdMeters(int radiusMeters) {
    return radiusMeters.toDouble() + boundaryBufferMeters(radiusMeters);
  }

  bool shouldRepairEnter({
    required double nearestDistanceMeters,
    required int radiusMeters,
  }) {
    return nearestDistanceMeters <= enterRepairThresholdMeters(radiusMeters);
  }

  bool shouldRepairExit({
    required double nearestDistanceMeters,
    required int radiusMeters,
  }) {
    return nearestDistanceMeters >= exitRepairThresholdMeters(radiusMeters);
  }
}
