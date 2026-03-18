/// Represents the 5 daily prayer times for a specific date.
class PrayerDay {
  final DateTime date;
  final DateTime fajr;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  const PrayerDay({
    required this.date,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  DateTime? timeForPrayer(PrayerName prayer) {
    switch (prayer) {
      case PrayerName.fajr:
        return fajr;
      case PrayerName.dhuhr:
      case PrayerName.jumuah:
        return dhuhr;
      case PrayerName.asr:
        return asr;
      case PrayerName.maghrib:
        return maghrib;
      case PrayerName.isha:
        return isha;
    }
  }

  /// Returns the next prayer after [now], or null if all prayers have passed.
  (PrayerName, DateTime)? nextPrayer(DateTime now) {
    final prayers = [
      (PrayerName.fajr, fajr),
      (PrayerName.dhuhr, dhuhr),
      (PrayerName.asr, asr),
      (PrayerName.maghrib, maghrib),
      (PrayerName.isha, isha),
    ];
    for (final (name, time) in prayers) {
      if (time.isAfter(now)) return (name, time);
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'fajr': fajr.toIso8601String(),
        'dhuhr': dhuhr.toIso8601String(),
        'asr': asr.toIso8601String(),
        'maghrib': maghrib.toIso8601String(),
        'isha': isha.toIso8601String(),
      };

  factory PrayerDay.fromJson(Map<String, dynamic> json) => PrayerDay(
        date: DateTime.parse(json['date'] as String),
        fajr: DateTime.parse(json['fajr'] as String),
        dhuhr: DateTime.parse(json['dhuhr'] as String),
        asr: DateTime.parse(json['asr'] as String),
        maghrib: DateTime.parse(json['maghrib'] as String),
        isha: DateTime.parse(json['isha'] as String),
      );
}

enum PrayerName { fajr, dhuhr, asr, maghrib, isha, jumuah }

extension PrayerNameDisplay on PrayerName {
  String get displayName {
    switch (this) {
      case PrayerName.fajr:
        return 'Fajr';
      case PrayerName.dhuhr:
        return 'Dhuhr';
      case PrayerName.asr:
        return 'Asr';
      case PrayerName.maghrib:
        return 'Maghrib';
      case PrayerName.isha:
        return 'Isha';
      case PrayerName.jumuah:
        return "Jumu'ah";
    }
  }
}
