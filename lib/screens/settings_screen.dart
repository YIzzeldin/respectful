import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme.dart';
import '../models/app_settings.dart';
import '../models/prayer_day.dart';
import '../models/prayer_timing_config.dart';
import '../providers/app_providers.dart';
import '../services/event_log_service.dart';
import 'troubleshooting_screen.dart';

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
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),

            // Silence Modes — geofence ON by default, time-based OFF by default
            _SectionCard(
              title: 'Silence Modes',
              children: [
                _ToggleRow(
                  icon: Icons.mosque_rounded,
                  label: 'Masjid Detection',
                  subtitle: 'Auto-silence when near a saved masjid',
                  value: settings.geofenceSilenceEnabled,
                  onChanged: (v) => ref.read(settingsProvider.notifier)
                      .setGeofenceSilenceEnabled(v),
                ),
                const Divider(height: 20),
                _ToggleRow(
                  icon: Icons.schedule_rounded,
                  label: 'Time-Based Silence',
                  subtitle: 'Auto-silence at prayer times',
                  value: settings.timeBasedSilenceEnabled,
                  onChanged: (v) => ref.read(settingsProvider.notifier)
                      .setTimeBasedSilenceEnabled(v),
                ),
              ],
            ),
            const SizedBox(height: 16),

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

            // Timing sections — only visible when time-based silence is ON
            if (settings.timeBasedSilenceEnabled) ...[
            // Default Timing — show range across all prayers
            Builder(builder: (context) {
              final configs = [PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr,
                  PrayerName.maghrib, PrayerName.isha]
                  .map((p) => settings.timingPreferences.configFor(p))
                  .toList();
              final beforeMin = configs.map((c) => c.minutesBeforeIqamah).reduce((a, b) => a < b ? a : b);
              final beforeMax = configs.map((c) => c.minutesBeforeIqamah).reduce((a, b) => a > b ? a : b);
              final afterMin = configs.map((c) => c.minutesAfter).reduce((a, b) => a < b ? a : b);
              final afterMax = configs.map((c) => c.minutesAfter).reduce((a, b) => a > b ? a : b);

              return _SectionCard(
                title: 'Default Timing',
                children: [
                  _TimingRow(label: 'Before iqamah', value: beforeMin, unit: beforeMin == beforeMax ? 'min' : '-$beforeMax min'),
                  const Divider(height: 24),
                  _TimingRow(label: 'Prayer duration', value: PrayerTimingConfig.prayerDurationMinutes, unit: 'min (fixed)'),
                  const Divider(height: 24),
                  _TimingRow(label: 'After prayer', value: afterMin, unit: afterMin == afterMax ? 'min' : '-$afterMax min'),
                ],
              );
            }),
            const SizedBox(height: 16),

            // Per-prayer timing — tappable to edit
            _SectionCard(
              title: 'Per-Prayer Timing',
              children: [
                const Text(
                  'Tap a prayer to customize its timing',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 8),
                ...PrayerName.values.map((prayer) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PerPrayerTimingCard(
                        prayer: prayer,
                        config: settings.timingPreferences.configFor(prayer),
                        onTap: () => _showTimingEditor(context, ref, prayer, settings),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 16),
            ], // end of timeBasedSilenceEnabled block

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
            const SizedBox(height: 16),

            // Troubleshooting
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TroubleshootingScreen(),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.build_rounded, size: 20, color: AppColors.textSecondary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Troubleshooting',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),
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

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: value ? AppColors.primary : AppColors.textTertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
        ),
        Switch(
          value: value,
          activeTrackColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
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
  final VoidCallback? onTap;

  const _PerPrayerTimingCard({
    required this.prayer,
    required this.config,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prayer.displayName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${config.minutesBeforeIqamah}m before iqamah · '
                      '${PrayerTimingConfig.prayerDurationMinutes}m prayer · '
                      '${config.minutesAfter}m after',
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              Text(
                '${config.totalMinutes}m',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

void _showTimingEditor(
  BuildContext context,
  WidgetRef ref,
  PrayerName prayer,
  AppSettings settings,
) {
  final config = settings.timingPreferences.configFor(prayer);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _TimingEditorSheet(
      prayer: prayer,
      initialConfig: config,
      onSave: (newConfig) {
        final newPrefs = settings.timingPreferences.withConfig(prayer, newConfig);
        ref.read(settingsProvider.notifier).updateSettings(
              settings.copyWith(timingPreferences: newPrefs),
            );
      },
    ),
  );
}

class _TimingEditorSheet extends StatefulWidget {
  final PrayerName prayer;
  final PrayerTimingConfig initialConfig;
  final ValueChanged<PrayerTimingConfig> onSave;

  const _TimingEditorSheet({
    required this.prayer,
    required this.initialConfig,
    required this.onSave,
  });

  @override
  State<_TimingEditorSheet> createState() => _TimingEditorSheetState();
}

class _TimingEditorSheetState extends State<_TimingEditorSheet> {
  late int _beforeIqamah;
  late int _minutesAfter;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _beforeIqamah = widget.initialConfig.minutesBeforeIqamah;
    _minutesAfter = widget.initialConfig.minutesAfter;
    _enabled = widget.initialConfig.enabled;
  }

  int get _total => _beforeIqamah + PrayerTimingConfig.prayerDurationMinutes + _minutesAfter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.prayer.displayName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              Text(
                'Total: ${_total}m',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Prayer duration: ${PrayerTimingConfig.prayerDurationMinutes} min (fixed)',
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),

          // Enabled toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Auto-silence for this prayer', style: TextStyle(fontSize: 15)),
              Switch(
                value: _enabled,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sliders — just 2 settings
          _SliderRow(
            label: 'Before iqamah',
            value: _beforeIqamah,
            min: 0,
            max: 60,
            onChanged: (v) => setState(() => _beforeIqamah = v),
          ),
          _SliderRow(
            label: 'After prayer',
            value: _minutesAfter,
            min: 0,
            max: 30,
            onChanged: (v) => setState(() => _minutesAfter = v),
          ),
          const SizedBox(height: 16),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                widget.onSave(PrayerTimingConfig(
                  minutesBeforeIqamah: _beforeIqamah,
                  iqamahOffsetMinutes: widget.initialConfig.iqamahOffsetMinutes,
                  minutesAfter: _minutesAfter,
                  enabled: _enabled,
                ));
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                final defaultConfig = PrayerTimingConfig.defaultFor(widget.prayer);
                setState(() {
                  _beforeIqamah = defaultConfig.minutesBeforeIqamah;
                  _minutesAfter = defaultConfig.minutesAfter;
                  _enabled = defaultConfig.enabled;
                });
              },
              child: const Text(
                'Reset to defaults',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              Text(
                '$value min',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surfaceVariant,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
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
