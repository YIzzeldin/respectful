import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_providers.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/location_refresh_listener.dart';
import 'widgets/silence_engine_watcher.dart';
import 'services/event_log_service.dart';
import 'services/masjid_storage_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final eventLogService = EventLogService();
  await eventLogService.init();

  final masjidStorage = MasjidStorageService();
  await masjidStorage.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        eventLogServiceProvider.overrideWithValue(eventLogService),
        masjidStorageProvider.overrideWithValue(masjidStorage),
      ],
      child: const RespectfulApp(),
    ),
  );
}

class RespectfulApp extends ConsumerWidget {
  const RespectfulApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final locale = Locale(settings.languageCode);

    return MaterialApp(
      title: 'Respectful',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: settings.onboardingComplete
          ? const SilenceEngineWatcher(
              child: LocationRefreshListener(child: AppShell()),
            )
          : OnboardingScreen(
              onComplete: () {
                ref.read(settingsProvider.notifier).completeOnboarding();
              },
            ),
    );
  }
}
