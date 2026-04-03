import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../models/prayer_day.dart';
import '../models/prayer_timing_config.dart';
import '../providers/app_providers.dart';
import '../services/event_log_service.dart';
import 'troubleshooting_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isUpdatingGeo = false;
  bool _isUpdatingTime = false;
  bool _isUpdatingFastExit = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header
            Text(l.settings, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),

            // Silence Modes — geofence ON by default, time-based OFF by default
            _SectionCard(
              title: l.silenceModes,
              children: [
                _ToggleRow(
                  icon: Icons.mosque_rounded,
                  label: l.masjidDetection,
                  subtitle: l.masjidDetectionDesc,
                  value: settings.geofenceSilenceEnabled,
                  onChanged: _isUpdatingGeo
                      ? null
                      : (v) async {
                          setState(() => _isUpdatingGeo = true);
                          try {
                            final controller = ref.read(
                              volumeControllerProvider,
                            );
                            if (!v) {
                              await controller.disableGeofenceSilence();
                            }
                            await ref
                                .read(settingsProvider.notifier)
                                .setGeofenceSilenceEnabled(v);
                            if (v) {
                              await reEvaluateCurrentSuppression(
                                ref,
                                checkPrayer: false,
                                checkGeo: true,
                                clearPrayerOverride: false,
                                clearGeoOverride: true,
                              );
                            }
                            ref.invalidate(suppressionStateProvider);
                            ref.invalidate(geoSilencedProvider);
                            ref.invalidate(activeMasjidGeofencesProvider);
                          } finally {
                            if (mounted) {
                              setState(() => _isUpdatingGeo = false);
                            }
                          }
                        },
                ),
                const Divider(height: 20),
                _ToggleRow(
                  icon: Icons.schedule_rounded,
                  label: l.timeBasedSilence,
                  subtitle: l.timeBasedSilenceDesc,
                  value: settings.timeBasedSilenceEnabled,
                  onChanged: _isUpdatingTime
                      ? null
                      : (v) async {
                          setState(() => _isUpdatingTime = true);
                          try {
                            final controller = ref.read(
                              volumeControllerProvider,
                            );
                            if (!v) {
                              await controller.disableTimeBasedSilence();
                            }
                            await ref
                                .read(settingsProvider.notifier)
                                .setTimeBasedSilenceEnabled(v);
                            if (v) {
                              await reEvaluateCurrentSuppression(
                                ref,
                                checkPrayer: true,
                                checkGeo: false,
                                clearPrayerOverride: true,
                                clearGeoOverride: false,
                              );
                            }
                            ref.invalidate(suppressionStateProvider);
                          } finally {
                            if (mounted) {
                              setState(() => _isUpdatingTime = false);
                            }
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // GPS Calibration (only when geofencing is enabled)
            if (settings.geofenceSilenceEnabled) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.radar,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.masjidRadius,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                l.masjidRadiusDesc,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.masjidRadiusValue(settings.masjidRadiusMeters),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: Slider(
                            value: settings.masjidRadiusMeters.toDouble(),
                            min: 100,
                            max: 400,
                            divisions: 12,
                            activeColor: AppColors.primary,
                            onChanged: (v) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setMasjidRadiusMeters(v.round());
                            },
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _ToggleRow(
                      icon: Icons.directions_walk_rounded,
                      label: l.passThroughProtection,
                      subtitle: l.passThroughProtectionDesc,
                      value: settings.requireMasjidDwellBeforeSilence,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setRequireMasjidDwellBeforeSilence(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.gpsCalibration,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                l.gpsCalibrationDesc,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.gpsCalibrationInterval(
                            settings.gpsCalibrationMinutes,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: Slider(
                            value: settings.gpsCalibrationMinutes.toDouble(),
                            min: 1,
                            max: 30,
                            divisions: 29,
                            activeColor: AppColors.primary,
                            onChanged: (v) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                    settings.copyWith(
                                      gpsCalibrationMinutes: v.round(),
                                    ),
                                  );
                            },
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _ToggleRow(
                      icon: Icons.flash_on_rounded,
                      label: l.fasterExitDetection,
                      subtitle: l.fasterExitDetectionDesc,
                      value: settings.fastGeoExitTrackingEnabled,
                      onChanged: _isUpdatingFastExit
                          ? null
                          : (v) async {
                              setState(() => _isUpdatingFastExit = true);
                              try {
                                await ref
                                    .read(settingsProvider.notifier)
                                    .setFastGeoExitTrackingEnabled(v);
                                await ref
                                    .read(volumeControllerProvider)
                                    .syncGeoExitTracking();
                              } finally {
                                if (mounted) {
                                  setState(() => _isUpdatingFastExit = false);
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Silence Level
            _SectionCard(
              title: l.silenceLevel,
              children: [
                _SilenceLevelOption(
                  title: l.prioritySilence,
                  subtitle: l.prioritySilenceDesc,
                  isSelected:
                      settings.silenceLevel == SilenceLevel.prioritySilence,
                  onTap: () => ref
                      .read(settingsProvider.notifier)
                      .setSilenceLevel(SilenceLevel.prioritySilence),
                ),
                const SizedBox(height: 12),
                _SilenceLevelOption(
                  title: l.totalSilence,
                  subtitle: l.totalSilenceDesc,
                  isSelected:
                      settings.silenceLevel == SilenceLevel.totalSilence,
                  onTap: () => ref
                      .read(settingsProvider.notifier)
                      .setSilenceLevel(SilenceLevel.totalSilence),
                  warning: l.cautionMessage,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Timing sections — only visible when time-based silence is ON
            if (settings.timeBasedSilenceEnabled) ...[
              // Default Timing — show range across all prayers
              Builder(
                builder: (context) {
                  final configs =
                      [
                            PrayerName.fajr,
                            PrayerName.dhuhr,
                            PrayerName.asr,
                            PrayerName.maghrib,
                            PrayerName.isha,
                          ]
                          .map((p) => settings.timingPreferences.configFor(p))
                          .toList();
                  final beforeMin = configs
                      .map((c) => c.minutesBeforeIqamah)
                      .reduce((a, b) => a < b ? a : b);
                  final beforeMax = configs
                      .map((c) => c.minutesBeforeIqamah)
                      .reduce((a, b) => a > b ? a : b);
                  final afterMin = configs
                      .map((c) => c.minutesAfter)
                      .reduce((a, b) => a < b ? a : b);
                  final afterMax = configs
                      .map((c) => c.minutesAfter)
                      .reduce((a, b) => a > b ? a : b);

                  return _SectionCard(
                    title: l.defaultTiming,
                    children: [
                      _TimingRow(
                        label: l.beforeIqamah,
                        value: beforeMin,
                        unit: beforeMin == beforeMax
                            ? l.min
                            : '-$beforeMax ${l.min}',
                      ),
                      const Divider(height: 24),
                      _TimingRow(
                        label: l.prayerDuration,
                        value: PrayerTimingConfig.prayerDurationMinutes,
                        unit: '${l.min} (${l.fixed})',
                      ),
                      const Divider(height: 24),
                      _TimingRow(
                        label: l.afterPrayer,
                        value: afterMin,
                        unit: afterMin == afterMax
                            ? l.min
                            : '-$afterMax ${l.min}',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Per-prayer timing — tappable to edit
              _SectionCard(
                title: l.perPrayerTiming,
                children: [
                  Text(
                    l.tapToCustomize,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...PrayerName.values.map(
                    (prayer) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PerPrayerTimingCard(
                        prayer: prayer,
                        config: settings.timingPreferences.configFor(prayer),
                        onTap: () =>
                            _showTimingEditor(context, ref, prayer, settings),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ], // end of timeBasedSilenceEnabled block
            // Calculation Method
            _SectionCard(
              title: l.calculationMethod,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CalculationMethodType>(
                      isExpanded: true,
                      value: settings.calculationMethod,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                      ),
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
                          ref
                              .read(settingsProvider.notifier)
                              .setCalculationMethod(method);
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

            // Language
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.language,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l.language,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('EN')),
                      ButtonSegment(value: 'ar', label: Text('عربي')),
                    ],
                    selected: {settings.languageCode},
                    onSelectionChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateSettings(
                            settings.copyWith(languageCode: value.first),
                          );
                    },
                    style: ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.build_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l.troubleshooting,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textTertiary,
                        ),
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
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
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
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
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
  final ValueChanged<bool>? onChanged;

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
        Icon(
          icon,
          size: 20,
          color: value ? AppColors.primary : AppColors.textTertiary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
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
        Text(
          label,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ),
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
    final l = AppLocalizations.of(context);
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
                      l.prayerName(prayer.displayName),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${config.minutesBeforeIqamah}${l.min} ${l.beforeIqamah} · '
                      '${PrayerTimingConfig.prayerDurationMinutes}${l.min} ${l.prayerDuration} · '
                      '${config.minutesAfter}${l.min} ${l.afterPrayer}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
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
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textTertiary,
              ),
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
        final newPrefs = settings.timingPreferences.withConfig(
          prayer,
          newConfig,
        );
        ref
            .read(settingsProvider.notifier)
            .updateSettings(settings.copyWith(timingPreferences: newPrefs));
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

  int get _total =>
      _beforeIqamah + PrayerTimingConfig.prayerDurationMinutes + _minutesAfter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                l.prayerName(widget.prayer.displayName),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l.totalTime(_total),
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
            '${l.prayerDuration}: ${PrayerTimingConfig.prayerDurationMinutes} ${l.min} (${l.fixed})',
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),

          // Enabled toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.autoSilenceForPrayer,
                style: const TextStyle(fontSize: 15),
              ),
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
            label: l.beforeIqamah,
            value: _beforeIqamah,
            min: 0,
            max: 60,
            onChanged: (v) => setState(() => _beforeIqamah = v),
          ),
          _SliderRow(
            label: l.afterPrayer,
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
                widget.onSave(
                  PrayerTimingConfig(
                    minutesBeforeIqamah: _beforeIqamah,
                    iqamahOffsetMinutes:
                        widget.initialConfig.iqamahOffsetMinutes,
                    minutesAfter: _minutesAfter,
                    enabled: _enabled,
                  ),
                );
                Navigator.pop(context);
              },
              child: Text(l.save),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                final defaultConfig = PrayerTimingConfig.defaultFor(
                  widget.prayer,
                );
                setState(() {
                  _beforeIqamah = defaultConfig.minutesBeforeIqamah;
                  _minutesAfter = defaultConfig.minutesAfter;
                  _enabled = defaultConfig.enabled;
                });
              },
              child: Text(
                l.resetToDefaults,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
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
    final l = AppLocalizations.of(context);
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
                '$value ${l.min}',
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
            SnackBar(
              content: Text(AppLocalizations.of(context).pleaseEnableLocation),
            ),
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
            SnackBar(
              content: Text(
                AppLocalizations.of(context).locationPermPermanentlyDenied,
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await ref
          .read(settingsProvider.notifier)
          .setLocation(position.latitude, position.longitude);

      await ref
          .read(eventLogServiceProvider)
          .log(
            EventType.info,
            'Location manually refreshed '
            '(${position.latitude.toStringAsFixed(2)}, '
            '${position.longitude.toStringAsFixed(2)})',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).locationUpdated),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).failedToGetLocation('$e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
          Text(
            l.location,
            style: const TextStyle(
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
                hasLocation ? '$lat, $lng' : l.notSet,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.autoUpdatesOnTravel,
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
              label: Text(_isRefreshing ? l.updating : l.updateLocationNow),
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
