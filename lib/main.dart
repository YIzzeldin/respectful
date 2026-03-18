import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_providers.dart';
import 'screens/spike_screen.dart';
import 'services/event_log_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services before app starts
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

class RespectfulApp extends StatelessWidget {
  const RespectfulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Respectful',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SpikeScreen(),
    );
  }
}
