import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/prayer_day.dart';

class NextPrayerBanner extends StatefulWidget {
  final PrayerName prayer;
  final DateTime prayerTime;
  final bool isSilenced;
  final bool timeBasedEnabled;
  final bool geofenceEnabled;

  const NextPrayerBanner({
    super.key,
    required this.prayer,
    required this.prayerTime,
    this.isSilenced = false,
    this.timeBasedEnabled = false,
    this.geofenceEnabled = true,
  });

  @override
  State<NextPrayerBanner> createState() => _NextPrayerBannerState();
}

class _NextPrayerBannerState extends State<NextPrayerBanner> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    setState(() {
      _remaining = widget.prayerTime.difference(DateTime.now());
      if (_remaining.isNegative) _remaining = Duration.zero;
    });
  }

  String _getStatusText() {
    if (widget.isSilenced) return 'Currently silenced';
    if (widget.timeBasedEnabled && widget.geofenceEnabled) {
      return 'Silences at masjid or in ${_formatDuration(_remaining)}';
    }
    if (widget.geofenceEnabled) {
      return 'Silences when you enter a saved masjid';
    }
    if (widget.timeBasedEnabled) {
      return 'Silences in ${_formatDuration(_remaining)}';
    }
    return '';
  }

  String _formatTime(DateTime t) {
    final hour = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NEXT PRAYER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.prayer.displayName,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _formatTime(widget.prayerTime),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Starts in',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(_remaining),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.isSilenced || widget.timeBasedEnabled || widget.geofenceEnabled) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isSilenced ? Icons.volume_off : Icons.mosque_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusText(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
            ),
          ),
          ],
        ],
      ),
    );
  }
}
