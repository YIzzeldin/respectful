import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:respectful/l10n/app_localizations.dart';
import 'package:respectful/models/app_settings.dart';
import 'package:respectful/models/saved_masjid.dart';
import 'package:respectful/providers/app_providers.dart';
import 'package:respectful/screens/masjid_screen.dart';
import 'package:respectful/services/event_log_service.dart';
import 'package:respectful/services/location_service.dart';
import 'package:respectful/services/masjid_storage_service.dart';
import 'package:respectful/services/storage_service.dart';
import 'package:respectful/services/volume_controller.dart';

const _geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
const _geolocatorAndroidChannel = MethodChannel(
  'flutter.baseflow.com/geolocator_android',
);
const _geocodingChannel = MethodChannel('flutter.baseflow.com/geocoding');
final Uint8List _transparentImageBytes = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest();

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  bool bufferOutput = false;

  @override
  int contentLength = 0;

  @override
  late HttpHeaders headers = _FakeHttpHeaders();

  @override
  Encoding encoding = utf8;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> flush() async {}

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) {}

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  X509Certificate? get certificate => null;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  int get contentLength => _transparentImageBytes.length;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  int get statusCode => HttpStatus.ok;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImageBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  List<String>? operator [](String name) => const ['image/png'];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _runWithMockedHttp(Future<void> Function() body) {
  return HttpOverrides.runZoned(
    body,
    createHttpClient: (context) => _FakeHttpClient(),
  );
}

class _FakeStorageService extends StorageService {
  _FakeStorageService(this._settings);

  AppSettings _settings;

  @override
  AppSettings loadSettings() => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }
}

class _FakeMasjidStorageService extends MasjidStorageService {
  _FakeMasjidStorageService(this._masjids);

  List<SavedMasjid> _masjids;

  @override
  List<SavedMasjid> loadAll() => List<SavedMasjid>.from(_masjids);

  @override
  Future<void> add(SavedMasjid masjid) async {
    _masjids = [..._masjids, masjid];
  }

  @override
  Future<void> remove(String id) async {
    _masjids = _masjids.where((m) => m.id != id).toList();
  }

  @override
  Future<void> rename(String id, String newName) async {
    _masjids = _masjids
        .map(
          (m) => m.id == id
              ? SavedMasjid(
                  id: m.id,
                  name: newName,
                  latitude: m.latitude,
                  longitude: m.longitude,
                  savedAt: m.savedAt,
                )
              : m,
        )
        .toList();
  }
}

class _FakeEventLogService extends EventLogService {
  final List<String> messages = [];

  @override
  Future<void> log(EventType type, String message, {DateTime? at}) async {
    messages.add('${type.name}:$message');
  }
}

class _FakeVolumeController extends VolumeController {
  final List<String?> appliedMasjidIds = [];
  final List<String> clearedMasjidIds = [];
  bool hasBackgroundPermission = true;
  bool isGeoSilencedValue = false;
  String clearGeoSilenceForMasjidResult = 'not_silenced';
  Map<String, dynamic> suppressionState = const {};
  int syncGeoExitTrackingCalls = 0;

  @override
  Future<bool> hasBackgroundLocationPermission() async {
    return hasBackgroundPermission;
  }

  @override
  Future<bool> applySilenceForGeo({String? masjidId}) async {
    appliedMasjidIds.add(masjidId);
    isGeoSilencedValue = true;
    suppressionState = {
      ...suppressionState,
      'isGeoSilenced': true,
      'activeMasjidIds': masjidId == null ? const <String>[] : [masjidId],
    };
    return true;
  }

  @override
  Future<bool> isGeoSilenced() async {
    return isGeoSilencedValue;
  }

  @override
  Future<String> clearGeoSilenceForMasjid(String masjidId) async {
    clearedMasjidIds.add(masjidId);
    if (clearGeoSilenceForMasjidResult == 'restored') {
      isGeoSilencedValue = false;
      suppressionState = {
        ...suppressionState,
        'isGeoSilenced': false,
        'activeMasjidIds': const <String>[],
      };
    }
    return clearGeoSilenceForMasjidResult;
  }

  @override
  Future<Map<String, dynamic>> getSuppressionState() async {
    return suppressionState;
  }

  @override
  Future<String> readNativeEvents() async {
    return '[]';
  }

  @override
  Future<void> syncGeoExitTracking() async {
    syncGeoExitTrackingCalls += 1;
  }
}

ProviderContainer _container({
  required AppSettings settings,
  required List<SavedMasjid> masjids,
  required _FakeVolumeController controller,
  required _FakeEventLogService eventLog,
}) {
  final storage = _FakeStorageService(settings);
  final masjidStorage = _FakeMasjidStorageService(masjids);
  return ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((ref) => SettingsNotifier(storage)),
      savedMasjidsProvider.overrideWith(
        (ref) => SavedMasjidsNotifier(masjidStorage),
      ),
      volumeControllerProvider.overrideWithValue(controller),
      eventLogServiceProvider.overrideWithValue(eventLog),
      locationServiceProvider.overrideWithValue(LocationService()),
      currentMinuteProvider.overrideWith((ref) => Stream.value(DateTime.now())),
    ],
  );
}

Widget _testApp(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

Position _position({required double latitude, required double longitude}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 0,
  );
}

SavedMasjid _masjid({
  required String id,
  required String name,
  required double latitude,
  required double longitude,
}) {
  return SavedMasjid(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    savedAt: DateTime(2025, 1, 1),
  );
}

void _installPlatformMocks({
  required Position currentPosition,
  List<Map<String, dynamic>> placemarks = const [],
}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<Object?> geolocatorHandler(MethodCall call) async {
    switch (call.method) {
      case 'isLocationServiceEnabled':
        return true;
      case 'checkPermission':
      case 'requestPermission':
        return LocationPermission.whileInUse.index;
      case 'getCurrentPosition':
        return currentPosition.toJson();
      default:
        return null;
    }
  }

  messenger.setMockMethodCallHandler(_geolocatorChannel, geolocatorHandler);
  messenger.setMockMethodCallHandler(
    _geolocatorAndroidChannel,
    geolocatorHandler,
  );
  messenger.setMockMethodCallHandler(_geocodingChannel, (call) async {
    if (call.method == 'placemarkFromCoordinates') {
      return placemarks;
    }
    return null;
  });
}

void _clearPlatformMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_geolocatorChannel, null);
  messenger.setMockMethodCallHandler(_geolocatorAndroidChannel, null);
  messenger.setMockMethodCallHandler(_geocodingChannel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clearPlatformMocks);

  group('masjid interactions', () {
    testWidgets('deleting an active masjid clears the correct session', (
      tester,
    ) async {
      final controller = _FakeVolumeController()
        ..isGeoSilencedValue = true
        ..clearGeoSilenceForMasjidResult = 'restored'
        ..suppressionState = {
          'isGeoSilenced': true,
          'activeMasjidIds': ['riyadh'],
        };
      final eventLog = _FakeEventLogService();
      final container = _container(
        settings: AppSettings.defaults(),
        masjids: [
          _masjid(
            id: 'riyadh',
            name: 'Riyadh Masjid',
            latitude: 24.7136,
            longitude: 46.6753,
          ),
        ],
        controller: controller,
        eventLog: eventLog,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_testApp(container, const MasjidScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Riyadh Masjid'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(container.read(savedMasjidsProvider), isEmpty);
      expect(controller.clearedMasjidIds, ['riyadh']);
      expect(
        eventLog.messages,
        contains('restored:Deleted masjid: Riyadh Masjid (restored)'),
      );
    });

    testWidgets(
      'deleting one active masjid keeps silence if another is active',
      (tester) async {
        final controller = _FakeVolumeController()
          ..isGeoSilencedValue = true
          ..clearGeoSilenceForMasjidResult = 'still_at_other'
          ..suppressionState = {
            'isGeoSilenced': true,
            'activeMasjidIds': ['riyadh', 'olaya'],
          };
        final eventLog = _FakeEventLogService();
        final container = _container(
          settings: AppSettings.defaults(),
          masjids: [
            _masjid(
              id: 'riyadh',
              name: 'Riyadh Masjid',
              latitude: 24.7136,
              longitude: 46.6753,
            ),
            _masjid(
              id: 'olaya',
              name: 'Olaya Masjid',
              latitude: 24.7140,
              longitude: 46.6760,
            ),
          ],
          controller: controller,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_testApp(container, const MasjidScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Riyadh Masjid'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
        await tester.pumpAndSettle();

        final savedMasjids = container.read(savedMasjidsProvider);
        expect(savedMasjids.map((m) => m.id), ['olaya']);
        expect(controller.clearedMasjidIds, ['riyadh']);
        expect(
          eventLog.messages,
          contains(
            'masjidDeleted:Deleted masjid: Riyadh Masjid (still_at_other)',
          ),
        );
      },
    );

    testWidgets(
      'saving current location adds a masjid and silences immediately',
      (tester) async {
        _installPlatformMocks(
          currentPosition: _position(latitude: 24.7136, longitude: 46.6753),
        );
        final controller = _FakeVolumeController();
        final eventLog = _FakeEventLogService();
        final container = _container(
          settings: AppSettings.defaults().copyWith(
            geofenceSilenceEnabled: true,
          ),
          masjids: const [],
          controller: controller,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_testApp(container, const MasjidScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save Current Location'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await tester.pumpAndSettle();

        final savedMasjids = container.read(savedMasjidsProvider);
        expect(savedMasjids, hasLength(1));
        expect(savedMasjids.single.name, 'Masjid 1');
        expect(controller.appliedMasjidIds, [savedMasjids.single.id]);
        expect(
          eventLog.messages.any(
            (m) => m.startsWith('masjidAdded:Saved masjid:'),
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'saving current location near an existing masjid does not add a duplicate',
      (tester) async {
        _installPlatformMocks(
          currentPosition: _position(latitude: 24.7136, longitude: 46.6753),
        );
        final controller = _FakeVolumeController();
        final eventLog = _FakeEventLogService();
        final container = _container(
          settings: AppSettings.defaults().copyWith(
            geofenceSilenceEnabled: true,
            masjidRadiusMeters: 200,
          ),
          masjids: [
            _masjid(
              id: 'riyadh',
              name: 'Riyadh Masjid',
              latitude: 24.7136,
              longitude: 46.6753,
            ),
          ],
          controller: controller,
          eventLog: eventLog,
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_testApp(container, const MasjidScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save Current Location'));
        await tester.pumpAndSettle();

        final savedMasjids = container.read(savedMasjidsProvider);
        expect(savedMasjids, hasLength(1));
        expect(controller.appliedMasjidIds, isEmpty);
        expect(eventLog.messages, isEmpty);
        expect(find.textContaining('Already saved:'), findsOneWidget);
      },
    );

    testWidgets(
      'adding from map saves the picked location and silences if nearby',
      (tester) async {
        await _runWithMockedHttp(() async {
          _installPlatformMocks(
            currentPosition: _position(latitude: 24.7136, longitude: 46.6753),
          );
          final controller = _FakeVolumeController();
          final eventLog = _FakeEventLogService();
          final container = _container(
            settings: AppSettings.defaults().copyWith(
              geofenceSilenceEnabled: true,
              masjidRadiusMeters: 400,
            ),
            masjids: const [],
            controller: controller,
            eventLog: eventLog,
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(_testApp(container, const MasjidScreen()));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Pick from Map'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
          map.options.onTap?.call(
            const TapPosition(Offset.zero, Offset.zero),
            const LatLng(24.7137, 46.6754),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));

          expect(find.text('Save This Location'), findsOneWidget);
          await tester.tap(find.text('Save This Location'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final savedMasjids = container.read(savedMasjidsProvider);
          expect(savedMasjids, hasLength(1));
          expect(controller.appliedMasjidIds, [savedMasjids.single.id]);
          expect(
            eventLog.messages,
            contains('masjidAdded:Added masjid from map: Masjid 1'),
          );
        });
      },
    );

    testWidgets(
      'adding from map outside the current zone saves without silencing',
      (tester) async {
        await _runWithMockedHttp(() async {
          _installPlatformMocks(
            currentPosition: _position(latitude: 24.7136, longitude: 46.6753),
          );
          final controller = _FakeVolumeController();
          final eventLog = _FakeEventLogService();
          final container = _container(
            settings: AppSettings.defaults().copyWith(
              geofenceSilenceEnabled: true,
              masjidRadiusMeters: 5,
            ),
            masjids: const [],
            controller: controller,
            eventLog: eventLog,
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(_testApp(container, const MasjidScreen()));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Pick from Map'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
          map.options.onTap?.call(
            const TapPosition(Offset.zero, Offset.zero),
            const LatLng(24.7200, 46.6820),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));

          expect(find.text('Save This Location'), findsOneWidget);
          await tester.tap(find.text('Save This Location'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final savedMasjids = container.read(savedMasjidsProvider);
          expect(savedMasjids, hasLength(1));
          expect(controller.appliedMasjidIds, isEmpty);
          expect(
            eventLog.messages,
            contains('masjidAdded:Added masjid from map: Masjid 1'),
          );
          expect(find.text('Saved "Masjid 1"'), findsOneWidget);
        });
      },
    );
  });
}
