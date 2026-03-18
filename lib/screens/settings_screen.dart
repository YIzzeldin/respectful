import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/app_settings.dart';
import '../models/prayer_day.dart';
import '../models/prayer_timing_config.dart';
import '../providers/app_providers.dart';

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

            // Default Timing
            _SectionCard(
              title: 'Default Timing',
              children: [
                _TimingRow(
                  label: 'Before prayer',
                  value: settings.timingPreferences
                      .configFor(PrayerName.fajr)
                      .minutesBefore,
                  unit: 'min',
                ),
                const Divider(height: 24),
                _TimingRow(
                  label: 'Prayer duration',
                  value: settings.timingPreferences
                      .configFor(PrayerName.fajr)
                      .durationMinutes,
                  unit: 'min',
                ),
                const Divider(height: 24),
                _TimingRow(
                  label: 'After prayer',
                  value: settings.timingPreferences
                      .configFor(PrayerName.fajr)
                      .minutesAfter,
                  unit: 'min',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Customize per prayer toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customize Per Prayer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Switch(
                    value: settings.usePerPrayerConfig,
                    activeTrackColor: AppColors.primary,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).updateSettings(
                            settings.copyWith(usePerPrayerConfig: value),
                          );
                    },
                  ),
                ],
              ),
            ),

            if (settings.usePerPrayerConfig) ...[
              const SizedBox(height: 16),
              ...PrayerName.values.map((prayer) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PerPrayerTimingCard(
                      prayer: prayer,
                      config: settings.timingPreferences.configFor(prayer),
                    ),
                  )),
            ],
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
