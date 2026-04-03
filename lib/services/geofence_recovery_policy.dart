import 'dart:math' as math;

/// Shared thresholds for GPS-assisted geofence recovery.
///
/// Native geofence transitions remain the primary signal. These thresholds
/// are only for repair paths when Android misses an enter/exit transition.
class GeofenceRecoveryPolicy {
  static const int exitChecksBeforeRestore = 3;
  static const Duration exitCheckInterval = Duration(seconds: 20);

  const GeofenceRecoveryPolicy();

  double enterBoundaryBufferMeters(int radiusMeters) {
    final radius = radiusMeters.clamp(50, 1000).toDouble();
    return math.max(20.0, radius * 0.10);
  }

  double exitBoundaryBufferMeters(int radiusMeters) {
    final radius = radiusMeters.clamp(50, 1000).toDouble();
    return math.max(5.0, radius * 0.03);
  }

  double boundaryBufferMeters(int radiusMeters) {
    return enterBoundaryBufferMeters(radiusMeters);
  }

  double enterRepairThresholdMeters(int radiusMeters) {
    return math.max(
      0.0,
      radiusMeters.toDouble() - enterBoundaryBufferMeters(radiusMeters),
    );
  }

  double exitRepairThresholdMeters(int radiusMeters) {
    return radiusMeters.toDouble() + exitBoundaryBufferMeters(radiusMeters);
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
