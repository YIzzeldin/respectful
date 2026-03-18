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
    // Refresh on first load
    _refreshLocation();
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
    // Also re-check permissions on resume
    ref.invalidate(dndPermissionProvider);
    ref.invalidate(exactAlarmPermissionProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider to keep it alive
    ref.watch(locationRefreshProvider);
    return widget.child;
  }
}
