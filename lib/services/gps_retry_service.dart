import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Retries GPS position fetch with user feedback via SnackBar.
/// Returns the position on success, null only after all retries exhausted.
class GpsRetryService {
  /// Try to get GPS position, retrying up to [maxAttempts] times
  /// with [retryDelay] between attempts. Shows SnackBar on each failure.
  static Future<Position?> getPositionWithRetry({
    required BuildContext context,
    int maxAttempts = 5,
    Duration retryDelay = const Duration(seconds: 30),
    Duration timeout = const Duration(seconds: 10),
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeout,
          ),
        );
        return position;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'GPS unavailable — retrying in ${retryDelay.inSeconds}s '
                '(attempt $attempt/$maxAttempts)',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        if (attempt < maxAttempts) {
          await Future.delayed(retryDelay);
        }
      }
    }
    return null; // All retries exhausted
  }
}
