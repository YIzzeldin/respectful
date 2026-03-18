import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/app_settings.dart';
import '../models/prayer_day.dart';
import 'masjid_screen.dart';
import '../providers/app_providers.dart';
import '../widgets/next_prayer_banner.dart';
import '../widgets/prayer_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerDay = ref.watch(todayPrayerTimesProvider);
    final nextPrayer = ref.watch(nextPrayerProvider);
    final activeWindow = ref.watch(activeSilenceWindowProvider);
    final settings = ref.watch(settingsProvider);
    final masjidMode = ref.watch(masjidModeProvider);
    final isGeoSilenced = ref.watch(geoSilencedProvider).valueOrNull ?? false;

    // Phone is silenced if prayer window active OR manual masjid mode OR geofence triggered
    final isSilenced = activeWindow != null || masjidMode.isActive || isGeoSilenced;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: isSilenced ? const Color(0xFF1B3A2A) : AppColors.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: prayerDay == null
              ? _buildNoLocation(context)
              : _buildContent(context, ref, prayerDay, nextPrayer, isSilenced, settings),
        ),
      ),
    );
  }

  Widget _buildNoLocation(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Location needed',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Please complete onboarding to set your location for accurate prayer times.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    PrayerDay day,
    (PrayerName, DateTime)? nextPrayer,
    bool isSilenced,
    AppSettings settings,
  ) {
    final timeBasedSilenceEnabled = settings.timeBasedSilenceEnabled;
    final geofenceEnabled = settings.geofenceSilenceEnabled;
    final allDisabled = !timeBasedSilenceEnabled && !geofenceEnabled;
    final now = DateTime.now();
    final greeting = _getGreeting(now);

    final isGeoSilenced = ref.watch(geoSilencedProvider).valueOrNull ?? false;

    // Adaptive colors for silenced (dark) vs normal (light) mode
    final primaryTextColor = isSilenced ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isSilenced ? Colors.white70 : AppColors.textSecondary;
    final tertiaryTextColor = isSilenced ? Colors.white54 : AppColors.textTertiary;
    final cardColor = isSilenced ? const Color(0xFF244A35) : AppColors.surface;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, d MMM yyyy').format(now),
                  style: TextStyle(
                    fontSize: 13,
                    color: tertiaryTextColor,
                  ),
                ),
              ],
            ),
            // Status indicators + master toggle
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Master ON/OFF toggle — disables/enables both
                GestureDetector(
                  onTap: () {
                    if (allDisabled) {
                      // Turn on geofence (primary) when enabling
                      ref.read(settingsProvider.notifier).setGeofenceSilenceEnabled(true);
                    } else {
                      // Turn off both when disabling
                      ref.read(settingsProvider.notifier).setGeofenceSilenceEnabled(false);
                      ref.read(settingsProvider.notifier).setTimeBasedSilenceEnabled(false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: allDisabled
                          ? AppColors.error.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          allDisabled ? Icons.volume_up : Icons.volume_off,
                          size: 12,
                          color: allDisabled ? AppColors.error : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          allDisabled ? 'OFF' : 'ON',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: allDisabled ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Mode indicators
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModeChip(
                      icon: Icons.mosque_rounded,
                      label: 'Masjid',
                      enabled: geofenceEnabled,
                    ),
                    const SizedBox(width: 4),
                    _ModeChip(
                      icon: Icons.schedule_rounded,
                      label: 'Time',
                      enabled: timeBasedSilenceEnabled,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Masjid detection banner — shows when at a masjid (geofence or manual)
        Builder(builder: (context) {
          final masjidMode = ref.watch(masjidModeProvider);
          if (!masjidMode.isActive && !isGeoSilenced) return const SizedBox.shrink();

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mosque_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGeoSilenced ? 'You are at a masjid' : 'Masjid Mode Active',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isGeoSilenced
                            ? 'Phone silenced — auto-detected by geofence'
                            : 'Phone silenced${masjidMode.remainingTime != null ? ' — ${masjidMode.remainingTime!.inMinutes}m remaining' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ref.read(masjidModeProvider.notifier).deactivate(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          );
        }),

        // Next prayer banner
        if (nextPrayer != null)
          NextPrayerBanner(
            prayer: nextPrayer.$1,
            prayerTime: nextPrayer.$2,
            isSilenced: isSilenced,
            timeBasedEnabled: timeBasedSilenceEnabled,
            geofenceEnabled: geofenceEnabled,
            isAtMasjid: isGeoSilenced,
          ),
        const SizedBox(height: 24),

        // Today's prayers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Prayers",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primaryTextColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildPrayerRow(day, PrayerName.fajr, day.fajr, nextPrayer, now),
              _divider(),
              _buildPrayerRow(day, PrayerName.dhuhr, day.dhuhr, nextPrayer, now),
              _divider(),
              _buildPrayerRow(day, PrayerName.asr, day.asr, nextPrayer, now),
              _divider(),
              _buildPrayerRow(day, PrayerName.maghrib, day.maghrib, nextPrayer, now),
              _divider(),
              _buildPrayerRow(day, PrayerName.isha, day.isha, nextPrayer, now),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Masjid mode button
        const _MasjidModeCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPrayerRow(
    PrayerDay day,
    PrayerName prayer,
    DateTime time,
    (PrayerName, DateTime)? nextPrayer,
    DateTime now,
  ) {
    final isNext = nextPrayer != null && nextPrayer.$1 == prayer;
    final isPast = time.isBefore(now);

    return PrayerCard(
      prayer: prayer,
      time: time,
      isNext: isNext,
      isPast: isPast && !isNext,
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: AppColors.surfaceVariant),
    );
  }

  String _getGreeting(DateTime now) {
    if (now.hour < 5) return 'Assalamu Alaikum';
    if (now.hour < 12) return 'Assalamu Alaikum';
    if (now.hour < 17) return 'Assalamu Alaikum';
    return 'Assalamu Alaikum';
  }
}

class _MasjidModeCard extends ConsumerWidget {
  const _MasjidModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedMasjids = ref.watch(savedMasjidsProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Always open masjid management — geofence handles silencing automatically
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MasjidScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.mosque_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Masjids',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        savedMasjids.isEmpty
                            ? 'Tap to add a masjid location'
                            : '${savedMasjids.length} saved • auto-silence on entry',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: enabled ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
