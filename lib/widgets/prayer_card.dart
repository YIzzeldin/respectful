import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/prayer_day.dart';

class PrayerCard extends StatelessWidget {
  final PrayerName prayer;
  final DateTime time;
  final bool isNext;
  final bool isPast;

  const PrayerCard({
    super.key,
    required this.prayer,
    required this.time,
    this.isNext = false,
    this.isPast = false,
  });

  String _formatTime(DateTime t) {
    final hour = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isNext ? AppColors.primary.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isNext
                  ? AppColors.primary
                  : isPast
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            prayer.displayName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isNext ? FontWeight.w600 : FontWeight.w400,
              color: isPast ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            _formatTime(time),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isPast ? AppColors.textTertiary : AppColors.textSecondary,
            ),
          ),
          if (isNext) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'NEXT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          if (isPast) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle, size: 18, color: AppColors.primary.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}
