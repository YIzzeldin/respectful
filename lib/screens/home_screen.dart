import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../models/prayer_day.dart';
import '../models/silence_window.dart';
import '../services/event_log_service.dart';
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
    final suppressionState = ref.watch(suppressionStateProvider).valueOrNull;
    final isGeoSilenced = suppressionState?.hasGeoReason ?? false;
    final isPrayerSilenced = suppressionState?.hasTimeReason ?? false;
    final silencedWindow = isPrayerSilenced ? activeWindow : null;

    final isSilenced = suppressionState?.isSuppressed ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: isSilenced ? const Color(0xFF1B3A2A) : AppColors.background,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: prayerDay == null
              ? _buildNoLocation(context)
              : isSilenced
              ? _SilencedScreen(
                  prayerDay: prayerDay,
                  nextPrayer: nextPrayer,
                  activeWindow: silencedWindow,
                  isGeoSilenced: isGeoSilenced,
                  settings: settings,
                )
              : _buildNormalContent(
                  context,
                  ref,
                  prayerDay,
                  nextPrayer,
                  settings,
                ),
        ),
      ),
    );
  }

  Widget _buildNoLocation(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              l.locationNeeded,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l.locationNeededDesc,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalContent(
    BuildContext context,
    WidgetRef ref,
    PrayerDay day,
    (PrayerName, DateTime)? nextPrayer,
    AppSettings settings,
  ) {
    final l = AppLocalizations.of(context);
    final timeBasedSilenceEnabled = settings.timeBasedSilenceEnabled;
    final geofenceEnabled = settings.geofenceSilenceEnabled;
    final masterEnabled = settings.masterSilenceEnabled;
    final now = DateTime.now();
    final isGeoSilenced = false; // we're in normal mode

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.greeting,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () async {
                    if (!masterEnabled) {
                      await ref
                          .read(settingsProvider.notifier)
                          .setMasterSilenceEnabled(true);
                      await _resumeSilenceNow(ref);
                    } else {
                      await _restorePhoneNow(ref);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: !masterEnabled
                          ? AppColors.error.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          !masterEnabled ? Icons.volume_up : Icons.volume_off,
                          size: 12,
                          color: !masterEnabled
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          !masterEnabled ? l.off : l.on,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: !masterEnabled
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModeChip(
                      icon: Icons.mosque_rounded,
                      label: l.masjid,
                      enabled: geofenceEnabled,
                    ),
                    const SizedBox(width: 4),
                    _ModeChip(
                      icon: Icons.schedule_rounded,
                      label: l.time,
                      enabled: timeBasedSilenceEnabled,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Next prayer banner
        if (nextPrayer != null)
          NextPrayerBanner(
            prayer: nextPrayer.$1,
            prayerTime: nextPrayer.$2,
            isSilenced: false,
            timeBasedEnabled: timeBasedSilenceEnabled,
            geofenceEnabled: geofenceEnabled,
            isAtMasjid: isGeoSilenced,
          ),
        const SizedBox(height: 24),

        // Today's prayers
        Text(
          l.todaysPrayers,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
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
              _buildPrayerRow(
                day,
                PrayerName.dhuhr,
                day.dhuhr,
                nextPrayer,
                now,
              ),
              _divider(),
              _buildPrayerRow(day, PrayerName.asr, day.asr, nextPrayer, now),
              _divider(),
              _buildPrayerRow(
                day,
                PrayerName.maghrib,
                day.maghrib,
                nextPrayer,
                now,
              ),
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

  Future<void> _resumeSilenceNow(WidgetRef ref) async {
    try {
      await reEvaluateCurrentSuppression(ref);
    } catch (_) {}
  }

  Future<void> _restorePhoneNow(WidgetRef ref) async {
    await ref.read(settingsProvider.notifier).setMasterSilenceEnabled(false);
    final controller = ref.read(volumeControllerProvider);
    final eventLog = ref.read(eventLogServiceProvider);
    await controller.clearManualOverrides();
    await controller.disableTimeBasedSilence();
    await controller.disableGeofenceSilence();
    ref.invalidate(suppressionStateProvider);
    ref.invalidate(geoSilencedProvider);
    ref.invalidate(activeMasjidGeofencesProvider);
    await eventLog.log(
      EventType.restored,
      'Master toggle OFF — phone restored to normal',
    );
  }
}

// =============================================================================
// SILENCED SCREEN — completely different immersive layout
// =============================================================================

class _SilencedScreen extends ConsumerStatefulWidget {
  final PrayerDay prayerDay;
  final (PrayerName, DateTime)? nextPrayer;
  final SilenceWindow? activeWindow;
  final bool isGeoSilenced;
  final AppSettings settings;

  const _SilencedScreen({
    required this.prayerDay,
    required this.nextPrayer,
    required this.activeWindow,
    required this.isGeoSilenced,
    required this.settings,
  });

  @override
  ConsumerState<_SilencedScreen> createState() => _SilencedScreenState();
}

class _SilencedScreenState extends ConsumerState<_SilencedScreen>
    with SingleTickerProviderStateMixin {
  String? _activeMasjidName;
  DateTime? _silencedSince;
  bool _isExiting = false;
  late final Timer _ticker;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _loadSilenceInfo();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSilenceInfo() async {
    final controller = ref.read(volumeControllerProvider);

    if (widget.isGeoSilenced) {
      // Load masjid name
      final activeIds = await controller.getActiveMasjidGeofences();
      if (activeIds.isNotEmpty && mounted) {
        final masjids = ref.read(savedMasjidsProvider);
        final match = masjids.cast<dynamic>().firstWhere(
          (m) => activeIds.contains(m.id),
          orElse: () => null,
        );
        if (match != null && mounted) {
          setState(() => _activeMasjidName = match.name);
        }
      }

      // Load geo silenced timestamp
      final ms = await controller.getGeoSilencedAt();
      if (ms > 0 && mounted) {
        setState(
          () => _silencedSince = DateTime.fromMillisecondsSinceEpoch(ms),
        );
      }
    } else if (widget.activeWindow != null) {
      setState(() => _silencedSince = widget.activeWindow!.start);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nextPrayer = widget.nextPrayer;
    final hasPrayerWindow = widget.activeWindow != null;

    return Stack(
      children: [
        // Animated floating orbs
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              final t = _animController.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _FloatingOrb(
                    t: t,
                    baseX: -30,
                    baseY: -40,
                    radiusX: 80,
                    radiusY: 60,
                    size: 300,
                    color: const Color(0xFFFDBA49),
                    opacity: 0.35,
                    phase: 0,
                  ),
                  _FloatingOrb(
                    t: t,
                    baseX: 150,
                    baseY: 450,
                    radiusX: 70,
                    radiusY: 90,
                    size: 280,
                    color: const Color(0xFFFDBA49),
                    opacity: 0.25,
                    phase: 0.33,
                  ),
                  _FloatingOrb(
                    t: t,
                    baseX: 80,
                    baseY: 200,
                    radiusX: 50,
                    radiusY: 40,
                    size: 200,
                    color: const Color(0xFFFDBA49),
                    opacity: 0.2,
                    phase: 0.66,
                  ),
                ],
              );
            },
          ),
        ),

        // Main content
        ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mosque_rounded,
                      color: Color(0xFFFDBA49),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l.greeting,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_off_rounded,
                    color: Colors.white60,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Central icon
            Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.03),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF096444).withValues(alpha: 0.2),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.do_not_disturb_on_rounded,
                  size: 80,
                  color: Color(0xFFFDBA49),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // "Phone Silenced" title
            Center(
              child: Text(
                l.phoneSilenced,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // "Currently at" + masjid name (tappable to open masjid list)
            if (widget.isGeoSilenced) ...[
              Center(
                child: Text(
                  l.currentlyAt.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: const Color(0xFFFDBA49).withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MasjidScreen()),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _activeMasjidName ?? l.unknownMasjid,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),

            // Prayer info card — shows "Active Prayer" or "Next Prayer"
            if (hasPrayerWindow) ...[
              // Prayer window is active — show active prayer
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.activePrayer.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l.prayerName(widget.activeWindow!.prayer.displayName),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          l.enteringFocus,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: const Color(
                              0xFFFDBA49,
                            ).withValues(alpha: 0.9),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (nextPrayer != null) ...[
              // No active prayer window — show next prayer
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.nextPrayer.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l.prayerName(nextPrayer.$1.displayName),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _formatTime(nextPrayer.$2),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.nextTransition.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nextPrayer != null
                              ? '${l.prayerName(nextPrayer.$1.displayName)} • ${_formatTime(nextPrayer.$2)}'
                              : '—',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.silencedFor.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _silencedSince != null
                              ? _formatElapsed(
                                  DateTime.now().difference(_silencedSince!),
                                )
                              : '—',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Exit silence button
            Center(
              child: GestureDetector(
                onTap: _isExiting ? null : () => _exitSilenceMode(ref),
                child: AnimatedOpacity(
                  opacity: _isExiting ? 0.5 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isExiting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFDBA49),
                                ),
                              )
                            : const Icon(
                                Icons.volume_up_rounded,
                                color: Color(0xFFFDBA49),
                                size: 20,
                              ),
                        const SizedBox(width: 12),
                        Text(
                          l.exitSilenceMode,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime t) {
    final hour = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _exitSilenceMode(WidgetRef ref) async {
    if (_isExiting) return;
    setState(() => _isExiting = true);

    try {
      final controller = ref.read(volumeControllerProvider);
      final eventLog = ref.read(eventLogServiceProvider);
      final exited = await controller.manualExitSilenceMode();
      if (!exited) {
        return;
      }
      ref.invalidate(suppressionStateProvider);
      ref.invalidate(geoSilencedProvider);
      ref.invalidate(activeMasjidGeofencesProvider);
      await eventLog.log(
        EventType.restored,
        'Exit silence mode — current silence session manually exited',
      );
    } finally {
      if (mounted) setState(() => _isExiting = false);
    }
  }
}

// =============================================================================
// Floating orb for peaceful background animation
// =============================================================================

class _FloatingOrb extends StatelessWidget {
  final double t;
  final double baseX, baseY;
  final double radiusX, radiusY;
  final double size;
  final Color color;
  final double opacity;
  final double phase;

  const _FloatingOrb({
    required this.t,
    required this.baseX,
    required this.baseY,
    required this.radiusX,
    required this.radiusY,
    required this.size,
    required this.color,
    required this.opacity,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final angle = (t + phase) * 2 * math.pi;
    final x = baseX + radiusX * math.sin(angle);
    final y = baseY + radiusY * math.cos(angle * 0.7);

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Glass card widget for the silenced screen
// =============================================================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

// =============================================================================
// Shared widgets (used in normal mode)
// =============================================================================

class _MasjidModeCard extends ConsumerWidget {
  const _MasjidModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
                      Text(
                        l.myMasjids,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        savedMasjids.isEmpty
                            ? l.tapToAddMasjid
                            : l.savedMasjidsCount(savedMasjids.length),
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
