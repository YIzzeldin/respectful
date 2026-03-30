import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

/// Listens for app lifecycle changes:
/// - Refreshes location on resume (travel detection)
/// - Checks for stale DND state (crash recovery)
class LocationRefreshListener extends ConsumerStatefulWidget {
  final Widget child;

  const LocationRefreshListener({super.key, required this.child});

  @override
  ConsumerState<LocationRefreshListener> createState() =>
      _LocationRefreshListenerState();
}

class _LocationRefreshListenerState
    extends ConsumerState<LocationRefreshListener> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer refresh to after initState completes — can't access
    // inherited widgets (ProviderScope) during initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLocation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocation();
    }
  }

  void _refreshLocation() {
    ref.invalidate(locationRefreshProvider);
    ref.invalidate(dndPermissionProvider);
    ref.invalidate(exactAlarmPermissionProvider);
    // Import any native events that happened while app was backgrounded/dead
    ref.invalidate(importNativeEventsProvider);
    // Refresh geo state — native side may have changed while app was backgrounded
    ref.invalidate(geoSilencedProvider);
    ref.invalidate(gpsCalibrationProvider);
    ref.invalidate(geoExitRecoveryProvider);
    ref.read(volumeControllerProvider).syncGeoExitTracking();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(locationRefreshProvider);
    ref.watch(importNativeEventsProvider); // keep alive so events import on resume
    return widget.child;
  }
}
