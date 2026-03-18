import 'package:flutter/material.dart';
import '../services/volume_controller.dart';

/// Phase 0 spike screen — validates that silence/restore/alarms work on Android.
/// This screen will be replaced by the real UI in Phase 2, but kept as a debug tool.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> with WidgetsBindingObserver {
  final _volumeController = VolumeController();

  Map<String, dynamic>? _currentState;
  Map<String, dynamic>? _savedState;
  bool _hasDndPermission = false;
  bool _hasAlarmPermission = false;
  bool _isSilenced = false;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      _refreshState();
    }
  }

  void _addLog(String message) {
    setState(() {
      _log.insert(0, '${TimeOfDay.now().format(context)}: $message');
      if (_log.length > 50) _log.removeLast();
    });
  }

  Future<void> _checkPermissions() async {
    final dnd = await _volumeController.hasDndPermission();
    final alarm = await _volumeController.hasExactAlarmPermission();
    setState(() {
      _hasDndPermission = dnd;
      _hasAlarmPermission = alarm;
    });
  }

  Future<void> _refreshState() async {
    try {
      final state = await _volumeController.captureCurrentState();
      setState(() => _currentState = state);
    } catch (e) {
      _addLog('Error reading state: $e');
    }
  }

  Future<void> _silence() async {
    try {
      final state = await _volumeController.captureCurrentState();
      setState(() => _savedState = state);

      final success = await _volumeController.applySilence();
      setState(() => _isSilenced = success);

      _addLog(success
          ? 'SILENCED (total). Saved state: ringer=${state["ringerMode"]}, filter=${state["interruptionFilter"]}'
          : 'FAILED — missing DND permission');

      await _refreshState();
    } catch (e) {
      _addLog('Error silencing: $e');
    }
  }

  Future<void> _restore() async {
    if (_savedState == null) {
      _addLog('No saved state to restore');
      return;
    }
    try {
      final success = await _volumeController.restoreState(_savedState!);
      setState(() => _isSilenced = false);

      _addLog(success
          ? 'RESTORED to: ringer=${_savedState!["ringerMode"]}, filter=${_savedState!["interruptionFilter"]}'
          : 'FAILED to restore');

      await _refreshState();
    } catch (e) {
      _addLog('Error restoring: $e');
    }
  }

  Future<void> _silenceAndRestoreAfterDelay() async {
    await _silence();
    if (!_isSilenced) return;

    _addLog('Will restore in 30 seconds...');

    // Schedule restore alarm 30 seconds from now
    final restoreAt = DateTime.now().add(const Duration(seconds: 30));
    await _volumeController.scheduleRestoreAlarm(
      triggerAtMs: restoreAt.millisecondsSinceEpoch,
    );

    _addLog('Restore alarm scheduled for ${TimeOfDay.fromDateTime(restoreAt).format(context)}');
  }

  Future<void> _scheduleSilenceIn1Min() async {
    final silenceAt = DateTime.now().add(const Duration(minutes: 1));
    final restoreAt = DateTime.now().add(const Duration(minutes: 2));

    await _volumeController.scheduleSilenceAlarm(
      triggerAtMs: silenceAt.millisecondsSinceEpoch,
      prayerName: 'Test',
      windowEndMs: restoreAt.millisecondsSinceEpoch,
    );

    await _volumeController.scheduleRestoreAlarm(
      triggerAtMs: restoreAt.millisecondsSinceEpoch,
    );

    _addLog('Scheduled: silence in 1 min, restore in 2 min');
    _addLog('You can kill the app now — alarms should still fire');
  }

  String _ringerModeLabel(int? mode) {
    switch (mode) {
      case 0: return 'Silent';
      case 1: return 'Vibrate';
      case 2: return 'Normal';
      default: return 'Unknown ($mode)';
    }
  }

  String _filterLabel(int? filter) {
    switch (filter) {
      case 1: return 'PRIORITY';
      case 2: return 'NONE (total silence)';
      case 3: return 'ALARMS_ONLY';
      case 4: return 'ALL (normal)';
      default: return 'Unknown ($filter)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Respectful — Spike'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Permissions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Permissions', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _PermissionRow(
                    label: 'DND Access',
                    granted: _hasDndPermission,
                    onFix: () => _volumeController.openDndSettings(),
                  ),
                  _PermissionRow(
                    label: 'Exact Alarms',
                    granted: _hasAlarmPermission,
                    onFix: () => _volumeController.openExactAlarmSettings(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Current state
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Phone State', style: theme.textTheme.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _refreshState,
                      ),
                    ],
                  ),
                  if (_currentState != null) ...[
                    Text('Ringer: ${_ringerModeLabel(_currentState!["ringerMode"] as int?)}'),
                    Text('DND Filter: ${_filterLabel(_currentState!["interruptionFilter"] as int?)}'),
                    Text('Ring Vol: ${_currentState!["ringVolume"]}'),
                    Text('Notif Vol: ${_currentState!["notificationVolume"]}'),
                    Text('Alarm Vol: ${_currentState!["alarmVolume"]}'),
                    Text('Media Vol: ${_currentState!["mediaVolume"]}'),
                  ] else
                    const Text('Tap refresh to read state'),
                  if (_isSilenced)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('SILENCED', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spike Tests', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _ActionButton(
                    icon: Icons.volume_off,
                    label: 'Silence Now',
                    subtitle: 'Total silence (INTERRUPTION_FILTER_NONE)',
                    color: Colors.red,
                    onPressed: _hasDndPermission ? _silence : null,
                  ),
                  const SizedBox(height: 8),
                  _ActionButton(
                    icon: Icons.volume_up,
                    label: 'Restore Now',
                    subtitle: 'Restore to saved state',
                    color: Colors.green,
                    onPressed: _savedState != null ? _restore : null,
                  ),
                  const Divider(height: 24),
                  _ActionButton(
                    icon: Icons.timer,
                    label: 'Silence → Restore in 30s',
                    subtitle: 'Tests alarm-based restore',
                    color: Colors.orange,
                    onPressed: _hasDndPermission ? _silenceAndRestoreAfterDelay : null,
                  ),
                  const SizedBox(height: 8),
                  _ActionButton(
                    icon: Icons.alarm,
                    label: 'Schedule: Silence in 1 min',
                    subtitle: 'Kill the app — should still fire',
                    color: Colors.deepPurple,
                    onPressed: (_hasDndPermission && _hasAlarmPermission) ? _scheduleSilenceIn1Min : null,
                  ),
                  const SizedBox(height: 8),
                  _ActionButton(
                    icon: Icons.cancel,
                    label: 'Cancel All Alarms',
                    subtitle: 'Clear all scheduled events',
                    color: Colors.grey,
                    onPressed: () async {
                      await _volumeController.cancelAllAlarms();
                      _addLog('All alarms cancelled');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Log
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Event Log', style: theme.textTheme.titleMedium),
                      TextButton(
                        onPressed: () => setState(() => _log.clear()),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  if (_log.isEmpty)
                    const Text('No events yet', style: TextStyle(color: Colors.grey))
                  else
                    ..._log.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(entry, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final bool granted;
  final VoidCallback onFix;

  const _PermissionRow({
    required this.label,
    required this.granted,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.error,
            color: granted ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          if (!granted)
            TextButton(
              onPressed: onFix,
              child: const Text('Grant'),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? color : Colors.grey.shade300,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
