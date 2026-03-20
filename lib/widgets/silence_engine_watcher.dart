import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

/// Invisible widget that keeps the auto-schedule provider alive.
/// Place this in the widget tree to ensure alarms are scheduled
/// whenever silence windows change (settings, location, midnight).
class SilenceEngineWatcher extends ConsumerWidget {
  final Widget child;

  const SilenceEngineWatcher({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching this provider keeps the auto-scheduling alive.
    // Whenever silenceWindowsProvider changes (due to settings, location,
    // or date change), autoScheduleProvider re-runs and reschedules alarms.
    ref.watch(autoScheduleProvider);
    ref.watch(autoGeofenceProvider);
    ref.watch(gpsCalibrationProvider); // GPS calibration for geofence self-healing
    return child;
  }
}
