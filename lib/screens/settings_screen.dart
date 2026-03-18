import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme.dart';
import '../models/app_settings.dart';
import '../models/prayer_day.dart';
import '../models/prayer_timing_config.dart';
import '../providers/app_providers.dart';
import '../services/event_log_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                const SizedBox(width: 12),
                Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 24),

            // Silence Level
            _SectionCard(
              title: 'Silence Level',
              children: [
                _SilenceLevelOption(
                  title: 'Priority Silence (Recommended)',
                  subtitle: 'Blocks notifications, allows alarms & starred contacts',
                  isSelected: settings.silenceLevel == SilenceLevel.prioritySilence,
                  onTap: () => ref.read(settingsProvider.notifier)
                      .setSilenceLevel(SilenceLevel.prioritySilence),
                ),
                const SizedBox(height: 12),
                _SilenceLevelOption(
                  title: 'Total Silence',
                  subtitle: 'Blocks everything including alarms and calls',
                  isSelected: settings.silenceLevel == SilenceLevel.totalSilence,
                  onTap: () => ref.read(settingsProvider.notifier)
                      .setSilenceLevel(SilenceLevel.totalSilence),
                  warning: 'Use with caution — may miss important calls',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Default Timing — show range across all prayers
            Builder(builder: (context) {
              final configs = [PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr,
                  PrayerName.maghrib, PrayerName.isha]
                  .map((p) => settings.timingPreferences.configFor(p))
                  .toList();
              final beforeMin = configs.map((c) => c.minutesBefore).reduce((a, b) => a < b ? a : b);
              final beforeMax = configs.map((c) => c.minutesBefore).reduce((a, b) => a > b ? a : b);
              final durMin = configs.map((c) => c.durationMinutes).reduce((a, b) => a < b ? a : b);
              final durMax = configs.map((c) => c.durationMinutes).reduce((a, b) => a > b ? a : b);
              final afterMin = configs.map((c) => c.minutesAfter).reduce((a, b) => a < b ? a : b);
              final afterMax = configs.map((c) => c.minutesAfter).reduce((a, b) => a > b ? a : b);

              return _SectionCard(
                title: 'Default Timing',
                children: [
                  _TimingRow(label: 'Before prayer', value: beforeMin, unit: beforeMin == beforeMax ? 'min' : '-$beforeMax min'),
                  const Divider(height: 24),
                  _TimingRow(label: 'Prayer duration', value: durMin, unit: durMin == durMax ? 'min' : '-$durMax min'),
                  const Divider(height: 24),
                  _TimingRow(label: 'After prayer', value: afterMin, unit: afterMin == afterMax ? 'min' : '-$afterMax min'),
                ],
              );
            }),
            const SizedBox(height: 16),

            // Per-prayer timing — always show since each prayer has its own config
            _SectionCard(
              title: 'Per-Prayer Timing',
              children: PrayerName.values.map((prayer) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PerPrayerTimingCard(
                      prayer: prayer,
                      config: settings.timingPreferences.configFor(prayer),
                    ),
                  )).toList(),
            ),
            const SizedBox(height: 16),

            // Calculation Method
            _SectionCard(
              title: 'Calculation Method',
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CalculationMethodType>(
                      isExpanded: true,
                      value: settings.calculationMethod,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                      ),
                      dropdownColor: AppColors.surface,
                      items: CalculationMethodType.values.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method.displayName),
                        );
                      }).toList(),
                      onChanged: (method) {
                        if (method != null) {
                          ref.read(settingsProvider.notifier).setCalculationMethod(method);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location
            _LocationCard(settings: settings),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SilenceLevelOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final String? warning;

  const _SilenceLevelOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (warning != null && isSelected) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                warning!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  final String label;
  final int value;
  final String unit;

  const _TimingRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
        Text(
          '$value $unit',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _PerPrayerTimingCard extends StatelessWidget {
  final PrayerName prayer;
  final PrayerTimingConfig config;

  const _PerPrayerTimingCard({required this.prayer, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              prayer.displayName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${config.minutesBefore} | ${config.durationMinutes} | ${config.minutesAfter}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _LocationCard extends ConsumerStatefulWidget {
  final AppSettings settings;

  const _LocationCard({required this.settings});

  @override
  ConsumerState<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends ConsumerState<_LocationCard> {
  bool _isRefreshing = false;

  Future<void> _refreshLocation() async {
    setState(() => _isRefreshing = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      await ref.read(settingsProvider.notifier).setLocation(
            position.latitude,
            position.longitude,
          );

      await ref.read(eventLogServiceProvider).log(
            EventType.info,
            'Location manually refreshed '
            '(${position.latitude.toStringAsFixed(2)}, '
            '${position.longitude.toStringAsFixed(2)})',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated — prayer times recalculated'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.settings.hasLocation;
    final lat = widget.settings.latitude?.toStringAsFixed(4) ?? '—';
    final lng = widget.settings.longitude?.toStringAsFixed(4) ?? '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 18,
                color: hasLocation ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                hasLocation ? '$lat, $lng' : 'Not set',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Updates automatically when you travel >10km',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isRefreshing ? null : _refreshLocation,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(_isRefreshing ? 'Updating...' : 'Update Location Now'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
