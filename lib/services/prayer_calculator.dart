import 'package:adhan/adhan.dart' as adhan;
import '../models/prayer_day.dart';
import '../models/app_settings.dart';

/// Calculates prayer times locally using the adhan library.
/// No API dependency — works fully offline.
class PrayerCalculatorService {
  /// Calculate prayer times for a given date, location, and method.
  PrayerDay calculate({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethodType method,
  }) {
    final coordinates = adhan.Coordinates(latitude, longitude);
    final params = _getCalculationParameters(method);
    final dateComponents = adhan.DateComponents(date.year, date.month, date.day);
    final prayerTimes = adhan.PrayerTimes(coordinates, dateComponents, params);

    return PrayerDay(
      date: DateTime(date.year, date.month, date.day),
      fajr: prayerTimes.fajr,
      dhuhr: prayerTimes.dhuhr,
      asr: prayerTimes.asr,
      maghrib: prayerTimes.maghrib,
      isha: prayerTimes.isha,
    );
  }

  /// Calculate today's prayer times.
  PrayerDay today({
    required double latitude,
    required double longitude,
    required CalculationMethodType method,
  }) =>
      calculate(
        latitude: latitude,
        longitude: longitude,
        date: DateTime.now(),
        method: method,
      );

  /// Calculate tomorrow's prayer times (needed for overnight Fajr scheduling).
  PrayerDay tomorrow({
    required double latitude,
    required double longitude,
    required CalculationMethodType method,
  }) =>
      calculate(
        latitude: latitude,
        longitude: longitude,
        date: DateTime.now().add(const Duration(days: 1)),
        method: method,
      );

  adhan.CalculationParameters _getCalculationParameters(
      CalculationMethodType method) {
    switch (method) {
      case CalculationMethodType.muslimWorldLeague:
        return adhan.CalculationMethod.muslim_world_league.getParameters();
      case CalculationMethodType.egyptian:
        return adhan.CalculationMethod.egyptian.getParameters();
      case CalculationMethodType.karachi:
        return adhan.CalculationMethod.karachi.getParameters();
      case CalculationMethodType.ummAlQura:
        return adhan.CalculationMethod.umm_al_qura.getParameters();
      case CalculationMethodType.dubai:
        return adhan.CalculationMethod.dubai.getParameters();
      case CalculationMethodType.qatar:
        return adhan.CalculationMethod.qatar.getParameters();
      case CalculationMethodType.kuwait:
        return adhan.CalculationMethod.kuwait.getParameters();
      case CalculationMethodType.moonsightingCommittee:
        return adhan.CalculationMethod.moon_sighting_committee.getParameters();
      case CalculationMethodType.singapore:
        return adhan.CalculationMethod.singapore.getParameters();
      case CalculationMethodType.turkey:
        return adhan.CalculationMethod.turkey.getParameters();
      case CalculationMethodType.tehran:
        return adhan.CalculationMethod.tehran.getParameters();
      case CalculationMethodType.northAmerica:
        return adhan.CalculationMethod.north_america.getParameters();
    }
  }
}
