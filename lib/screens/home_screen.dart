import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/prayer_day.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: prayerDay == null
            ? _buildNoLocation(context)
            : _buildContent(context, ref, prayerDay, nextPrayer, activeWindow != null),
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
  ) {
    final now = DateTime.now();
    final greeting = _getGreeting(now);

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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, d MMM yyyy').format(now),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Next prayer banner
        if (nextPrayer != null)
          NextPrayerBanner(
            prayer: nextPrayer.$1,
            prayerTime: nextPrayer.$2,
            isSilenced: isSilenced,
          ),
        const SizedBox(height: 24),

        // Today's prayers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Prayers",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '5 min before',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
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
                // TODO: activate masjid mode
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
                      child: const Icon(
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
                          const Text(
                            "I'm at a Masjid",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'Tap to activate masjid mode',
                            style: TextStyle(
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
        ),
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
