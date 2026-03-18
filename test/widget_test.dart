import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:respectful/main.dart';
import 'package:respectful/providers/app_providers.dart';
import 'package:respectful/services/event_log_service.dart';
import 'package:respectful/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders onboarding for new user', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final eventLog = EventLogService();
    await eventLog.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          eventLogServiceProvider.overrideWithValue(eventLog),
        ],
        child: const RespectfulApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Respectful'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
