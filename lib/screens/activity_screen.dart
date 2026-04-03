import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_providers.dart';
import '../services/event_log_service.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final eventLog = ref.watch(eventLogServiceProvider);
    final entries = eventLog.getRecentEntries(days: 7);

    // Group by day
    final grouped = <String, List<EventEntry>>{};
    for (final entry in entries) {
      final dayKey = DateFormat('yyyy-MM-dd').format(entry.timestamp);
      grouped.putIfAbsent(dayKey, () => []).add(entry);
    }

    // Stats
    final silenced = entries.where((e) =>
        e.type == EventType.silenced || e.type == EventType.geofenceEnter).length;
    final overrides = entries.where((e) => e.type == EventType.overrideDetected).length;
    final restored = entries.where((e) =>
        e.type == EventType.restored || e.type == EventType.geofenceExit).length;
    final restoreRate = silenced > 0 ? ((restored / silenced) * 100).round() : 100;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.activity, style: Theme.of(context).textTheme.headlineMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surfaceVariant),
                  ),
                  child: Text(
                    l.last7Days,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats row with left accent border
            Row(
              children: [
                _StatCard(value: '$silenced', label: l.silenced, color: AppColors.primary),
                const SizedBox(width: 10),
                _StatCard(value: '$overrides', label: l.overrides, color: AppColors.warning),
                const SizedBox(width: 10),
                _StatCard(value: '$restoreRate%', label: l.restored, color: AppColors.info),
              ],
            ),
            const SizedBox(height: 28),

            // Event timeline
            if (entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(l.noActivityYet,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(l.noActivityDesc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                  ],
                ),
              )
            else
              ...grouped.entries.map((dayGroup) {
                final date = DateTime.parse(dayGroup.key);
                final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
                final yesterdayKey = DateFormat('yyyy-MM-dd').format(
                    DateTime.now().subtract(const Duration(days: 1)));
                final isToday = todayKey == dayGroup.key;
                final isYesterday = yesterdayKey == dayGroup.key;

                final dayLabel = isToday
                    ? l.today
                    : isYesterday
                        ? l.yesterday
                        : DateFormat('EEEE').format(date);
                final dateLabel = DateFormat('MMMM d, yyyy').format(date);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day header with date subtitle
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(dayLabel,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(width: 8),
                          Text(dateLabel,
                              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                    // Events in a grouped card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < dayGroup.value.length; i++) ...[
                            _EventRow(entry: dayGroup.value[i]),
                            if (i < dayGroup.value.length - 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Divider(height: 1, color: AppColors.surfaceVariant.withValues(alpha: 0.6)),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final EventEntry entry;

  const _EventRow({required this.entry});

  static const _purple = Color(0xFF7C4DFF);
  static const _purpleBg = Color(0xFFEDE7F6);
  static const _teal = Color(0xFF00897B);
  static const _tealBg = Color(0xFFE0F2F1);
  static const _indigo = Color(0xFF3949AB);
  static const _indigoBg = Color(0xFFE8EAF6);
  static const _cyan = Color(0xFF0097A7);
  static const _cyanBg = Color(0xFFE0F7FA);

  Color get _iconBgColor {
    switch (entry.type) {
      case EventType.silenced:
        return AppColors.silencedBadge;
      case EventType.geofenceEnter:
        return _tealBg;
      case EventType.masjidAdded:
        return AppColors.silencedBadge;
      case EventType.restored:
        return AppColors.restoredBadge;
      case EventType.geofenceExit:
        return _cyanBg;
      case EventType.overrideDetected:
        return AppColors.overrideBadge;
      case EventType.masjidDeleted:
        return AppColors.overrideBadge;
      case EventType.error:
        return const Color(0xFFFFEBEE);
      case EventType.alarmScheduled:
        return _purpleBg;
      case EventType.permissionGranted:
        return AppColors.silencedBadge;
      case EventType.permissionDenied:
        return const Color(0xFFFFEBEE);
      case EventType.bootRecovery:
        return _indigoBg;
      case EventType.timezoneChange:
        return _cyanBg;
      case EventType.masjidModeOn:
        return _tealBg;
      case EventType.masjidModeOff:
        return AppColors.restoredBadge;
      case EventType.info:
        return _indigoBg;
    }
  }

  Color get _iconColor {
    switch (entry.type) {
      case EventType.silenced:
        return AppColors.primary;
      case EventType.geofenceEnter:
        return _teal;
      case EventType.masjidAdded:
        return AppColors.primary;
      case EventType.restored:
        return AppColors.info;
      case EventType.geofenceExit:
        return _cyan;
      case EventType.overrideDetected:
        return AppColors.warning;
      case EventType.masjidDeleted:
        return AppColors.warning;
      case EventType.error:
        return AppColors.error;
      case EventType.alarmScheduled:
        return _purple;
      case EventType.permissionGranted:
        return AppColors.success;
      case EventType.permissionDenied:
        return AppColors.error;
      case EventType.bootRecovery:
        return _indigo;
      case EventType.timezoneChange:
        return _cyan;
      case EventType.masjidModeOn:
        return _teal;
      case EventType.masjidModeOff:
        return AppColors.info;
      case EventType.info:
        return _indigo;
    }
  }

  IconData get _icon {
    switch (entry.type) {
      case EventType.silenced:
        return Icons.volume_off_rounded;
      case EventType.restored:
        return Icons.volume_up_rounded;
      case EventType.overrideDetected:
        return Icons.pan_tool_rounded;
      case EventType.error:
        return Icons.warning_rounded;
      case EventType.masjidModeOn:
        return Icons.mosque_rounded;
      case EventType.masjidModeOff:
        return Icons.home_rounded;
      case EventType.geofenceEnter:
        return Icons.sensors_rounded;
      case EventType.geofenceExit:
        return Icons.sensors_off_rounded;
      case EventType.masjidAdded:
        return Icons.add_location_alt_rounded;
      case EventType.masjidDeleted:
        return Icons.location_off_rounded;
      case EventType.alarmScheduled:
        return Icons.alarm_rounded;
      case EventType.permissionGranted:
        return Icons.check_circle_rounded;
      case EventType.permissionDenied:
        return Icons.block_rounded;
      case EventType.bootRecovery:
        return Icons.restart_alt_rounded;
      case EventType.timezoneChange:
        return Icons.public_rounded;
      case EventType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, size: 18, color: _iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            DateFormat('h:mm a').format(entry.timestamp),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
