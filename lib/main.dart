import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/event_log_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final eventLogService = EventLogService();
  await eventLogService.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        eventLogServiceProvider.overrideWithValue(eventLogService),
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

    return MaterialApp(
      title: 'Respectful',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: settings.onboardingComplete
          ? const AppShell()
          : OnboardingScreen(
              onComplete: () {
                ref.read(settingsProvider.notifier).completeOnboarding();
              },
            ),
    );
  }
}
