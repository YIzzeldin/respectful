import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Handles GPS location fetching and travel detection.
class LocationService {
  /// Fetch current GPS position. Returns null if permission denied or unavailable.
  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Check if the user has moved significantly from their stored location.
  /// Returns true if distance exceeds [thresholdKm] (default 10km).
  bool hasMovedSignificantly({
    required double storedLat,
    required double storedLng,
    required double currentLat,
    required double currentLng,
    double thresholdKm = 10.0,
  }) {
    final distanceMeters = _haversineDistance(
      storedLat, storedLng, currentLat, currentLng,
    );
    return distanceMeters > thresholdKm * 1000;
  }

  /// Haversine formula to calculate distance between two GPS points in meters.
  double _haversineDistance(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}
