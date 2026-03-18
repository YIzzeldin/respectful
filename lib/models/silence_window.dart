import 'prayer_day.dart';

/// A computed time window during which the phone should be silenced.
/// Produced by SilenceWindowCalculator from prayer times + timing config.
class SilenceWindow {
  final PrayerName prayer;
  final DateTime start;
  final DateTime end;

  /// If windows were merged, this contains all prayer names in the window.
  final List<PrayerName> mergedPrayers;

  const SilenceWindow({
    required this.prayer,
    required this.start,
    required this.end,
    this.mergedPrayers = const [],
  });

  Duration get duration => end.difference(start);

  bool isActive(DateTime now) =>
      now.isAfter(start) && now.isBefore(end) ||
      now.isAtSameMomentAs(start);

  /// Remaining time from [now] until the end of this window.
  Duration remaining(DateTime now) {
    if (now.isBefore(start)) return end.difference(start);
    if (now.isAfter(end)) return Duration.zero;
    return end.difference(now);
  }

  /// Time until this window starts from [now].
  Duration timeUntil(DateTime now) {
    if (now.isAfter(start)) return Duration.zero;
    return start.difference(now);
  }

  /// Display name, including merged prayers.
  String get displayName {
    if (mergedPrayers.isNotEmpty) {
      return mergedPrayers.map((p) => p.displayName).join(' + ');
    }
    return prayer.displayName;
  }

  /// Check if this window overlaps with another.
  bool overlaps(SilenceWindow other) =>
      start.isBefore(other.end) && other.start.isBefore(end);

  /// Merge two overlapping windows into one.
  SilenceWindow mergeWith(SilenceWindow other) {
    final allPrayers = <PrayerName>{
      ...mergedPrayers.isEmpty ? [prayer] : mergedPrayers,
      ...other.mergedPrayers.isEmpty ? [other.prayer] : other.mergedPrayers,
    };
    return SilenceWindow(
      prayer: prayer, // keep the earlier prayer as primary
      start: start.isBefore(other.start) ? start : other.start,
      end: end.isAfter(other.end) ? end : other.end,
      mergedPrayers: allPrayers.toList(),
    );
  }

  /// Unique alarm IDs based on prayer index.
  int get silenceAlarmId => 1000 + prayer.index;
  int get restoreAlarmId => 2000 + prayer.index;

  Map<String, dynamic> toJson() => {
        'prayer': prayer.name,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'mergedPrayers': mergedPrayers.map((p) => p.name).toList(),
      };

  factory SilenceWindow.fromJson(Map<String, dynamic> json) => SilenceWindow(
        prayer: PrayerName.values.byName(json['prayer'] as String),
        start:
            DateTime.fromMillisecondsSinceEpoch(json['start'] as int),
        end: DateTime.fromMillisecondsSinceEpoch(json['end'] as int),
        mergedPrayers: (json['mergedPrayers'] as List?)
                ?.map((p) => PrayerName.values.byName(p as String))
                .toList() ??
            const [],
      );
}
