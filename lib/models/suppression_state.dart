/// Reasons why the phone is currently silenced.
sealed class SuppressionReason {
  DateTime get activatedAt;
}

class TimeReason extends SuppressionReason {
  final String prayerName;
  final DateTime windowEnd;
  @override
  final DateTime activatedAt;

  TimeReason({
    required this.prayerName,
    required this.windowEnd,
    required this.activatedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeReason && prayerName == other.prayerName;

  @override
  int get hashCode => prayerName.hashCode;
}

class GeoReason extends SuppressionReason {
  final String masjidId;
  final String masjidName;
  @override
  final DateTime activatedAt;

  GeoReason({
    required this.masjidId,
    required this.masjidName,
    required this.activatedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoReason && masjidId == other.masjidId;

  @override
  int get hashCode => masjidId.hashCode;
}

/// Captured phone state before silencing — used to restore after prayer.
class PhoneStateSnapshot {
  final int ringerMode;
  final int interruptionFilter;
  final int ringVolume;
  final int notificationVolume;
  final int alarmVolume;
  final int mediaVolume;
  final DateTime capturedAt;
  final String changeToken;

  const PhoneStateSnapshot({
    required this.ringerMode,
    required this.interruptionFilter,
    required this.ringVolume,
    required this.notificationVolume,
    required this.alarmVolume,
    required this.mediaVolume,
    required this.capturedAt,
    required this.changeToken,
  });

  factory PhoneStateSnapshot.fromMap(Map<String, dynamic> map) =>
      PhoneStateSnapshot(
        ringerMode: map['ringerMode'] as int? ?? 0,
        interruptionFilter: map['interruptionFilter'] as int? ?? 4,
        ringVolume: map['ringVolume'] as int? ?? 5,
        notificationVolume: map['notificationVolume'] as int? ?? 5,
        alarmVolume: map['alarmVolume'] as int? ?? 5,
        mediaVolume: map['mediaVolume'] as int? ?? 5,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(
          map['capturedAt'] as int? ?? 0,
        ),
        changeToken: map['changeToken'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
    'ringerMode': ringerMode,
    'interruptionFilter': interruptionFilter,
    'ringVolume': ringVolume,
    'notificationVolume': notificationVolume,
    'alarmVolume': alarmVolume,
    'mediaVolume': mediaVolume,
    'capturedAt': capturedAt.millisecondsSinceEpoch,
    'changeToken': changeToken,
  };
}

/// The current suppression state of the app.
class SuppressionState {
  final Set<SuppressionReason> activeReasons;
  final PhoneStateSnapshot? ownedSnapshot;
  final bool userOverridden;
  final DateTime? overrideExpiresAt;
  final DateTime? sessionStart;

  const SuppressionState({
    this.activeReasons = const {},
    this.ownedSnapshot,
    this.userOverridden = false,
    this.overrideExpiresAt,
    this.sessionStart,
  });

  factory SuppressionState.fromNativeMap(Map<String, dynamic> map) {
    final activeReasons = <SuppressionReason>{};
    final now = DateTime.now();

    final isPrayerSilenced = map['isPrayerSilenced'] == true;
    final currentPrayer =
        (map['currentPrayer'] as String?)?.trim().isNotEmpty == true
        ? map['currentPrayer'] as String
        : 'Unknown prayer';
    final prayerActivatedAt = _dateTimeOrNow(
      map['prayerSilencedAtMs'],
      fallback: now,
    );
    final prayerWindowEnd = _dateTimeOrNow(
      map['prayerWindowEndMs'],
      fallback: prayerActivatedAt,
    );
    if (isPrayerSilenced) {
      activeReasons.add(
        TimeReason(
          prayerName: currentPrayer,
          windowEnd: prayerWindowEnd,
          activatedAt: prayerActivatedAt,
        ),
      );
    }

    final isGeoSilenced = map['isGeoSilenced'] == true;
    final geoActivatedAt = _dateTimeOrNow(
      map['geoSilencedAtMs'],
      fallback: now,
    );
    final activeMasjidIds =
        (map['activeMasjidIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toSet();
    if (isGeoSilenced) {
      final ids = activeMasjidIds.isEmpty ? const {'unknown'} : activeMasjidIds;
      for (final masjidId in ids) {
        activeReasons.add(
          GeoReason(
            masjidId: masjidId,
            masjidName: masjidId,
            activatedAt: geoActivatedAt,
          ),
        );
      }
    }

    final sessionStart = activeReasons.isEmpty
        ? null
        : activeReasons
              .map((reason) => reason.activatedAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);

    return SuppressionState(
      activeReasons: activeReasons,
      userOverridden: map['userOverridden'] == true,
      overrideExpiresAt: null,
      sessionStart: sessionStart,
    );
  }

  bool get isSuppressed => activeReasons.isNotEmpty && !isInOverridePeriod;

  bool get isInOverridePeriod =>
      userOverridden &&
      overrideExpiresAt != null &&
      DateTime.now().isBefore(overrideExpiresAt!);

  bool get shouldRestore =>
      activeReasons.isEmpty && ownedSnapshot != null && !userOverridden;

  bool get hasTimeReason => activeReasons.any((r) => r is TimeReason);

  bool get hasGeoReason => activeReasons.any((r) => r is GeoReason);

  String? get currentPrayerName {
    for (final reason in activeReasons) {
      if (reason is TimeReason) return reason.prayerName;
    }
    return null;
  }

  DateTime? get prayerActivatedAt {
    for (final reason in activeReasons) {
      if (reason is TimeReason) return reason.activatedAt;
    }
    return null;
  }

  DateTime? get geoActivatedAt {
    for (final reason in activeReasons) {
      if (reason is GeoReason) return reason.activatedAt;
    }
    return null;
  }
}

DateTime _dateTimeOrNow(dynamic value, {required DateTime fallback}) {
  final millis = switch (value) {
    int() => value,
    num() => value.toInt(),
    _ => 0,
  };
  if (millis <= 0) return fallback;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}
