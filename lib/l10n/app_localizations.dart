import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  // --- General ---
  String get appName => isArabic ? 'محترم' : 'Respectful';
  String get appTagline => isArabic
      ? 'إصمات هاتفك باحترام'
      : 'Silence your phone respectfully';

  // --- Home Screen ---
  String get greeting => isArabic ? 'السلام عليكم' : 'Assalamu Alaikum';
  String get todaysPrayers => isArabic ? 'صلوات اليوم' : "Today's Prayers";
  String get nextPrayer => isArabic ? 'الصلاة التالية' : 'NEXT PRAYER';
  String get startsIn => isArabic ? 'تبدأ في' : 'Starts in';
  String get myMasjids => isArabic ? 'مساجدي' : 'My Masjids';
  String get tapToAddMasjid => isArabic
      ? 'اضغط لإضافة موقع مسجد'
      : 'Tap to add a masjid location';
  String savedMasjidsCount(int count) => isArabic
      ? '$count محفوظ • إصمات تلقائي عند الدخول'
      : '$count saved • auto-silence on entry';
  String get youAreAtMasjid => isArabic
      ? 'أنت في المسجد'
      : 'You are at a masjid';
  String get phoneSilencedAutoDetected => isArabic
      ? 'الهاتف صامت — تم الكشف تلقائياً'
      : 'Phone silenced — auto-detected';
  String get currentlySilenced => isArabic
      ? 'الهاتف صامت حالياً'
      : 'Currently silenced';
  String get silencesAtMasjid => isArabic
      ? 'يُصمت عند دخول مسجد محفوظ'
      : 'Silences when you enter a saved masjid';
  String silencesAtMasjidOrIn(String time) => isArabic
      ? 'يُصمت عند المسجد أو خلال $time'
      : 'Silences at masjid or in $time';
  String silencesIn(String time) => isArabic
      ? 'يُصمت خلال $time'
      : 'Silences in $time';
  String get youAreAtMasjidSilenced => isArabic
      ? 'أنت في المسجد — الهاتف صامت'
      : 'You are at a masjid — phone silenced';

  // --- Silenced Screen ---
  String get phoneSilenced => isArabic ? 'الهاتف صامت' : 'Phone Silenced';
  String get currentlyAt => isArabic ? 'حالياً في' : 'Currently at';
  String get activePrayer => isArabic ? 'الصلاة الحالية' : 'Active Prayer';
  String get enteringFocus => isArabic ? 'وضع التركيز' : 'Entering Focus';
  String get nextTransition => isArabic ? 'التالي' : 'Next Transition';
  String get exitSilenceMode => isArabic ? 'إنهاء وضع الصمت' : 'EXIT SILENCE MODE';
  String minutesLabel(int m) => isArabic ? '$m دقيقة' : '$m Minutes';
  String get unknownMasjid => isArabic ? 'مسجد محفوظ' : 'Saved Masjid';
  String get silencedFor => isArabic ? 'صامت منذ' : 'Silent For';

  // --- Prayer Names ---
  String get fajr => isArabic ? 'الفجر' : 'Fajr';
  String get dhuhr => isArabic ? 'الظهر' : 'Dhuhr';
  String get asr => isArabic ? 'العصر' : 'Asr';
  String get maghrib => isArabic ? 'المغرب' : 'Maghrib';
  String get isha => isArabic ? 'العشاء' : 'Isha';
  String get jumuah => isArabic ? 'الجمعة' : "Jumu'ah";

  // --- Settings ---
  String get settings => isArabic ? 'الإعدادات' : 'Settings';
  String get silenceModes => isArabic ? 'أوضاع الصمت' : 'Silence Modes';
  String get masjidDetection => isArabic
      ? 'كشف المسجد'
      : 'Masjid Detection';
  String get masjidDetectionDesc => isArabic
      ? 'إصمات تلقائي عند الاقتراب من مسجد محفوظ'
      : 'Auto-silence when near a saved masjid';
  String get timeBasedSilence => isArabic
      ? 'صمت حسب الوقت'
      : 'Time-Based Silence';
  String get timeBasedSilenceDesc => isArabic
      ? 'إصمات تلقائي في أوقات الصلاة'
      : 'Auto-silence at prayer times';
  String get silenceLevel => isArabic ? 'مستوى الصمت' : 'Silence Level';
  String get totalSilence => isArabic ? 'صمت كامل' : 'Total Silence';
  String get totalSilenceDesc => isArabic
      ? 'يمنع كل شيء بما في ذلك المنبهات والمكالمات'
      : 'Blocks everything including alarms and calls';
  String get prioritySilence => isArabic
      ? 'صمت الأولوية (موصى به)'
      : 'Priority Silence (Recommended)';
  String get prioritySilenceDesc => isArabic
      ? 'يمنع الإشعارات، يسمح بالمنبهات والمكالمات المميزة'
      : 'Blocks notifications, allows alarms & starred contacts';
  String get cautionMessage => isArabic
      ? 'استخدم بحذر — قد تفوتك مكالمات مهمة'
      : 'Use with caution — may miss important calls';
  String get defaultTiming => isArabic ? 'التوقيت الافتراضي' : 'Default Timing';
  String get beforeIqamah => isArabic ? 'قبل الإقامة' : 'Before iqamah';
  String get prayerDuration => isArabic ? 'مدة الصلاة' : 'Prayer duration';
  String get afterPrayer => isArabic ? 'بعد الصلاة' : 'After prayer';
  String get perPrayerTiming => isArabic
      ? 'توقيت لكل صلاة'
      : 'Per-Prayer Timing';
  String get tapToCustomize => isArabic
      ? 'اضغط على صلاة لتخصيص توقيتها'
      : 'Tap a prayer to customize its timing';
  String get calculationMethod => isArabic
      ? 'طريقة الحساب'
      : 'Calculation Method';
  String get location => isArabic ? 'الموقع' : 'Location';
  String get notSet => isArabic ? 'لم يُحدد' : 'Not set';
  String get autoUpdatesOnTravel => isArabic
      ? 'يتحدث تلقائياً عند السفر أكثر من 10 كم'
      : 'Updates automatically when you travel >10km';
  String get updateLocationNow => isArabic
      ? 'تحديث الموقع الآن'
      : 'Update Location Now';
  String get gpsCalibration => isArabic
      ? 'معايرة نظام تحديد المواقع'
      : 'GPS Calibration';
  String get gpsCalibrationDesc => isArabic
      ? 'فحص دوري بنظام تحديد المواقع للتأكد من حالة الإصمات (يستهلك البطارية)'
      : 'Periodic GPS check to verify silence state (uses battery)';
  String get masjidRadius => isArabic ? 'Masjid radius' : 'Masjid Radius';
  String get masjidRadiusDesc => isArabic
      ? 'Adjust how close you need to be before masjid silence can activate'
      : 'How close you need to be before masjid silence can activate';
  String masjidRadiusValue(int meters) => '$meters m';
  String get passThroughProtection => isArabic
      ? 'Pass-through protection'
      : 'Pass-Through Protection';
  String get passThroughProtectionDesc => isArabic
      ? 'Wait for a dwell event before silencing to avoid accidental silence while passing by'
      : 'Wait for a dwell event before silencing to avoid accidental silence while passing by';
  String get fasterExitDetection => isArabic
      ? 'اكتشاف خروج أسرع'
      : 'Faster Exit Detection';
  String get fasterExitDetectionDesc => isArabic
      ? 'يشغّل تتبع موقع مؤقت مع إشعار دائم فقط أثناء صمت المسجد لتحسين الاستعادة عند المغادرة، ويستهلك بطارية أكثر'
      : 'Uses a temporary foreground location notification only while masjid silence is active to restore faster when you leave, and uses more battery';
  String gpsCalibrationInterval(int mins) => isArabic
      ? 'كل $mins دقيقة'
      : 'Every $mins minutes';
  String get checkingLocation => isArabic
      ? 'جاري التحقق من الموقع...'
      : 'Checking location...';
  String get troubleshooting => isArabic ? 'استكشاف الأخطاء' : 'Troubleshooting';
  String get language => isArabic ? 'اللغة' : 'Language';
  String get arabic => isArabic ? 'العربية' : 'Arabic';
  String get english => isArabic ? 'الإنجليزية' : 'English';

  // --- Masjid Screen ---
  String get noMasjidsSaved => isArabic
      ? 'لا توجد مساجد محفوظة'
      : 'No masjids saved';
  String get noMasjidsDesc => isArabic
      ? 'عندما تكون في مسجد، اضغط الزر أدناه لحفظ موقعه.'
      : "When you're at a masjid, tap the button below to save its location for quick access.";
  String get saveCurrentLocation => isArabic
      ? 'حفظ الموقع الحالي'
      : 'Save Current Location';
  String get pickFromMap => isArabic ? 'اختيار من الخريطة' : 'Pick from Map';
  String get addFromMap => isArabic
      ? 'إضافة مسجد من الخريطة'
      : 'Add Masjid from Map';
  String get nameThisMasjid => isArabic
      ? 'تسمية هذا المسجد'
      : 'Name this masjid';
  String get rename => isArabic ? 'إعادة تسمية' : 'Rename';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get deleteMasjid => isArabic ? 'حذف المسجد؟' : 'Delete masjid?';
  String deleteMasjidConfirm(String name) => isArabic
      ? 'إزالة "$name" من مواقعك المحفوظة؟'
      : 'Remove "$name" from your saved locations?';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get save => isArabic ? 'حفظ' : 'Save';
  String alreadySavedNearby(String name) => isArabic
      ? 'محفوظ بالفعل: "$name" قريب'
      : 'Already saved: "$name" is nearby';
  String get geofenceActive => isArabic
      ? 'سياج جغرافي 200م نشط'
      : '200m geofence active';
  String geofenceActiveWithRadius(int radiusMeters) => '${radiusMeters}m geofence active';

  // --- Onboarding ---
  String get getStarted => isArabic ? 'ابدأ' : 'Get Started';
  String get continueText => isArabic ? 'متابعة' : 'Continue';
  String get completeSetup => isArabic ? 'إكمال الإعداد' : 'Complete Setup';
  String get yourLocation => isArabic ? 'موقعك' : 'Your Location';
  String get locationDesc => isArabic
      ? 'نحتاج موقعك لحساب أوقات الصلاة الدقيقة لمنطقتك.'
      : 'We need your location to calculate accurate prayer times for your area.';
  String get grantLocationAccess => isArabic
      ? 'منح صلاحية الموقع'
      : 'Grant location access';
  String get locationGranted => isArabic
      ? 'تم منح الموقع'
      : 'Location granted';
  String get permissions => isArabic ? 'الصلاحيات' : 'Permissions';
  String get permissionsDesc => isArabic
      ? 'هذه الصلاحيات مطلوبة لكي يعمل التطبيق.'
      : 'These permissions are needed for Respectful to silence your phone.';
  String get dndAccess => isArabic
      ? 'صلاحية عدم الإزعاج'
      : 'Do Not Disturb Access';
  String get dndAccessDesc => isArabic
      ? 'مطلوب لإصمات هاتفك تلقائياً'
      : 'Required to silence your phone automatically';
  String get smartMasjidDetection => isArabic
      ? 'كشف ذكي للمسجد'
      : 'Smart masjid detection';
  String get smartMasjidDesc => isArabic
      ? 'يُصمت الهاتف تلقائياً عند دخولك المسجد'
      : 'Phone silences automatically when you enter a masjid';
  String get optionalTimeBased => isArabic
      ? 'صمت حسب الوقت (اختياري)'
      : 'Optional time-based silence';
  String get optionalTimeBasedDesc => isArabic
      ? 'صمت في أوقات الصلاة حتى بعيداً عن المسجد'
      : 'Silence at prayer times even away from the masjid';
  String get fullyCustomizable => isArabic
      ? 'قابل للتخصيص بالكامل'
      : 'Fully customizable';
  String get fullyCustomizableDesc => isArabic
      ? 'توقيت لكل صلاة، طريقة حساب، مستوى صمت'
      : 'Per-prayer timing, calculation method, silence level';

  // --- Activity ---
  String get activity => isArabic ? 'النشاط' : 'Activity';
  String get last7Days => isArabic ? 'آخر 7 أيام' : 'Last 7 days';
  String get silenced => isArabic ? 'صامت' : 'Silenced';
  String get overrides => isArabic ? 'تجاوزات' : 'Overrides';
  String get restored => isArabic ? 'مُستعاد' : 'Restored';
  String get noActivityYet => isArabic
      ? 'لا يوجد نشاط بعد'
      : 'No activity yet';
  String get noActivityDesc => isArabic
      ? 'ستظهر الأحداث هنا عند إصمات هاتفك في المسجد أو أثناء الصلاة.'
      : 'Events will appear here when your phone is silenced at a masjid or during prayer.';
  String get today => isArabic ? 'اليوم' : 'Today';
  String get yesterday => isArabic ? 'أمس' : 'Yesterday';

  // --- Common ---
  String get on => isArabic ? 'تشغيل' : 'ON';
  String get off => isArabic ? 'إيقاف' : 'OFF';
  String get masjid => isArabic ? 'مسجد' : 'Masjid';
  String get time => isArabic ? 'وقت' : 'Time';
  String get min => isArabic ? 'د' : 'min';
  String get fixed => isArabic ? 'ثابت' : 'fixed';
  String get grant => isArabic ? 'منح' : 'Grant';

  // --- Bottom Nav ---
  String get home => isArabic ? 'الرئيسية' : 'HOME';
  String get activityTab => isArabic ? 'النشاط' : 'ACTIVITY';
  String get settingsTab => isArabic ? 'الإعدادات' : 'SETTINGS';

  // --- Timing Editor ---
  String get autoSilenceForPrayer => isArabic
      ? 'إصمات تلقائي لهذه الصلاة'
      : 'Auto-silence for this prayer';
  String get resetToDefaults => isArabic
      ? 'إعادة للافتراضي'
      : 'Reset to defaults';
  String totalTime(int mins) => isArabic ? 'المجموع: $minsد' : 'Total: ${mins}m';

  // --- Troubleshooting ---
  String get permissionStatus => isArabic ? 'حالة الصلاحيات' : 'Permission Status';
  String get dndAccessShort => isArabic ? 'صلاحية عدم الإزعاج' : 'DND Access';
  String get exactAlarms => isArabic ? 'المنبهات الدقيقة' : 'Exact Alarms';
  String get granted => isArabic ? 'ممنوحة' : 'Granted';
  String get fix => isArabic ? 'إصلاح' : 'Fix';
  String get batteryOptimization => isArabic ? 'تحسين البطارية' : 'Battery Optimization';
  String get batteryDesc => isArabic
      ? 'لإصمات موثوق، عطّل تحسين البطارية لتطبيق محترم.'
      : 'For reliable auto-silence, disable battery optimization for Respectful.';
  String get openBatterySettings => isArabic ? 'فتح إعدادات البطارية' : 'Open Battery Settings';
  String get deviceGuide => isArabic ? 'دليل الجهاز' : 'Device-Specific Guide';
  String get deviceGuideDesc => isArabic
      ? 'بعض الأجهزة تقتل التطبيقات في الخلفية. اتبع الخطوات لجهازك:'
      : 'Some phone manufacturers aggressively kill background apps. Follow the steps for your device brand:';
  String get commonIssues => isArabic ? 'مشاكل شائعة' : 'Common Issues';
  String phoneSilencedSaved(String name) => isArabic
      ? 'تم حفظ "$name" — الهاتف صامت'
      : 'Saved "$name" — phone silenced';
  String saved(String name) => isArabic ? 'تم حفظ "$name"' : 'Saved "$name"';
  String get locationUpdated => isArabic
      ? 'تم تحديث الموقع — أوقات الصلاة أُعيد حسابها'
      : 'Location updated — prayer times recalculated';
  String get updating => isArabic ? 'جاري التحديث...' : 'Updating...';
  String get tapOnMap => isArabic
      ? 'اضغط على الخريطة لوضع مسجد'
      : 'Tap on the map to place a masjid';
  String get locationSelected => isArabic ? 'تم تحديد الموقع' : 'Location selected';
  String get saveThisLocation => isArabic ? 'حفظ هذا الموقع' : 'Save This Location';
  String get saving => isArabic ? 'جاري الحفظ...' : 'Saving...';
  String get autoDetectedFromLocation => isArabic
      ? 'تم الكشف تلقائياً من الموقع'
      : 'Auto-detected from location';
  String get renameMasjid => isArabic ? 'إعادة تسمية المسجد' : 'Rename masjid';
  String get next => isArabic ? 'التالي' : 'NEXT';
  String get alreadyHaveSettings => isArabic
      ? 'لديك إعدادات بالفعل؟ استعادة'
      : 'Already have settings? Restore';
  String get chooseCalcMethod => isArabic
      ? 'اختر طريقة حساب أوقات الصلاة المستخدمة في منطقتك.'
      : 'Choose the prayer time calculation method used in your region.';
  String get totalSilenceWarning => isArabic
      ? 'الصمت الكامل يمنع كل الأصوات بما فيها المكالمات والمنبهات أثناء التواجد في المسجد أو وقت الصلاة.'
      : 'Total silence mode blocks ALL sounds including calls and alarms while at a masjid or during prayer.';
  String get pleaseEnableLocation => isArabic
      ? 'يرجى تفعيل خدمات الموقع'
      : 'Please enable location services';
  String get locationPermDenied => isArabic
      ? 'تم رفض صلاحية الموقع'
      : 'Location permission denied';
  String get locationPermPermanentlyDenied => isArabic
      ? 'صلاحية الموقع مرفوضة نهائياً. يرجى التفعيل من الإعدادات.'
      : 'Location permission permanently denied. Please enable in settings.';
  String failedToGetLocation(String error) => isArabic
      ? 'فشل الحصول على الموقع: $error'
      : 'Failed to get location: $error';
  String get locationNeeded => isArabic ? 'الموقع مطلوب' : 'Location needed';
  String get locationNeededDesc => isArabic
      ? 'يرجى إكمال الإعداد لتحديد موقعك لأوقات صلاة دقيقة.'
      : 'Please complete onboarding to set your location for accurate prayer times.';
  String get grantBgLocation => isArabic
      ? 'امنح صلاحية "السماح دائماً" للموقع للكشف التلقائي عند دخول المسجد.'
      : 'Grant "Allow all the time" location for auto-detection when you enter a masjid.';
  String gpsRetrying(int attempt, int max) => isArabic
      ? 'نظام تحديد المواقع غير متاح — إعادة المحاولة خلال 30 ثانية (محاولة $attempt/$max)'
      : 'GPS unavailable — retrying in 30s (attempt $attempt/$max)';
  String get gpsFailed => isArabic
      ? 'فشل نظام تحديد المواقع — إلغاء الصمت لتجنب التعليق'
      : 'GPS failed — clearing silence to avoid stuck state';
  String get masterOffRestored => isArabic
      ? 'زر الإيقاف الرئيسي — تم استعادة الهاتف للوضع العادي'
      : 'Master toggle OFF — phone restored to normal';

  // --- Prayer name helper ---
  String prayerName(String name) {
    switch (name) {
      case 'Fajr': return fajr;
      case 'Dhuhr': return dhuhr;
      case 'Asr': return asr;
      case 'Maghrib': return maghrib;
      case 'Isha': return isha;
      case "Jumu'ah": return jumuah;
      default: return name;
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
