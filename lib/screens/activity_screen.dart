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

    // Stats — count both prayer silence and geofence events
    final silenced = entries.where((e) =>
        e.type == EventType.silenced || e.type == EventType.geofenceEnter).length;
    final overrides = entries.where((e) => e.type == EventType.overrideDetected).length;
    final restored = entries.where((e) =>
        e.type == EventType.restored || e.type == EventType.geofenceExit).length;
    final restoreRate = silenced > 0 ? ((restored / silenced) * 100).round() : 100;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

            // Stats row
            Row(
              children: [
                _StatCard(value: '$silenced', label: l.silenced, color: AppColors.primary),
                const SizedBox(width: 12),
                _StatCard(value: '$overrides', label: l.overrides, color: AppColors.warning),
                const SizedBox(width: 12),
                _StatCard(value: '$restoreRate%', label: l.restored, color: AppColors.info),
              ],
            ),
            const SizedBox(height: 24),

            // Event timeline
            if (entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      l.noActivityYet,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.noActivityDesc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              )
            else
              ...grouped.entries.map((dayGroup) {
                final date = DateTime.parse(dayGroup.key);
                final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dayGroup.key;
                final label = isToday ? l.today : DateFormat('EEEE').format(date);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    ...dayGroup.value.map((entry) => _EventRow(entry: entry)),
                    const SizedBox(height: 16),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final EventEntry entry;

  const _EventRow({required this.entry});

  Color get _iconBgColor {
    switch (entry.type) {
      case EventType.silenced:
        return AppColors.silencedBadge;
      case EventType.restored:
        return AppColors.restoredBadge;
      case EventType.overrideDetected:
        return AppColors.overrideBadge;
      case EventType.error:
        return const Color(0xFFFFEBEE);
      case EventType.geofenceEnter:
        return AppColors.silencedBadge;
      case EventType.geofenceExit:
        return AppColors.restoredBadge;
      case EventType.masjidAdded:
        return AppColors.silencedBadge;
      case EventType.masjidDeleted:
        return AppColors.overrideBadge;
      default:
        return AppColors.surfaceVariant;
    }
  }

  Color get _iconColor {
    switch (entry.type) {
      case EventType.silenced:
        return AppColors.primary;
      case EventType.geofenceEnter:
        return AppColors.primary;
      case EventType.masjidAdded:
        return AppColors.primary;
      case EventType.masjidDeleted:
        return AppColors.warning;
      case EventType.geofenceExit:
        return AppColors.info;
      case EventType.restored:
        return AppColors.info;
      case EventType.overrideDetected:
        return AppColors.warning;
      case EventType.error:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
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
        return Icons.login_rounded;
      case EventType.geofenceExit:
        return Icons.logout_rounded;
      case EventType.masjidAdded:
        return Icons.add_location_alt_rounded;
      case EventType.masjidDeleted:
        return Icons.location_off_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, size: 18, color: _iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('h:mm a').format(entry.timestamp),
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
