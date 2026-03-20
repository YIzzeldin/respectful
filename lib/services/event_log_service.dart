import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local event log for debugging and user confidence.
/// Logs every silence/restore/error/permission event with timestamp.
class EventLogService {
  static const _key = 'event_log';
  static const _maxEntries = 200;

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Log an event with optional timestamp (defaults to now).
  Future<void> log(EventType type, String message, {DateTime? at}) async {
    final entries = _loadEntries();
    entries.insert(0, EventEntry(
      type: type,
      message: message,
      timestamp: at ?? DateTime.now(),
    ));

    // Cap at max entries
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }

    await _prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  /// Get all logged events (newest first).
  List<EventEntry> getEntries() => _loadEntries();

  /// Get entries from the last N days.
  List<EventEntry> getRecentEntries({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _loadEntries()
        .where((e) => e.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Clear all entries.
  Future<void> clear() async {
    await _prefs.remove(_key);
  }

  List<EventEntry> _loadEntries() {
    final json = _prefs.getString(_key);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => EventEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

enum EventType {
  silenced,
  restored,
  overrideDetected,
  permissionGranted,
  permissionDenied,
  alarmScheduled,
  bootRecovery,
  timezoneChange,
  error,
  masjidModeOn,
  masjidModeOff,
  geofenceEnter,
  geofenceExit,
  masjidAdded,
  masjidDeleted,
  info,
}

class EventEntry {
  final EventType type;
  final String message;
  final DateTime timestamp;

  const EventEntry({
    required this.type,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory EventEntry.fromJson(Map<String, dynamic> json) => EventEntry(
        type: EventType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => EventType.info,
        ),
        message: json['message'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );

  String get typeIcon {
    switch (type) {
      case EventType.silenced:
        return '🔇';
      case EventType.restored:
        return '🔊';
      case EventType.overrideDetected:
        return '✋';
      case EventType.permissionGranted:
        return '✅';
      case EventType.permissionDenied:
        return '❌';
      case EventType.alarmScheduled:
        return '⏰';
      case EventType.bootRecovery:
        return '🔄';
      case EventType.timezoneChange:
        return '🌍';
      case EventType.error:
        return '⚠️';
      case EventType.masjidModeOn:
        return '🕌';
      case EventType.masjidModeOff:
        return '🏠';
      case EventType.geofenceEnter:
        return '📍';
      case EventType.geofenceExit:
        return '🚶';
      case EventType.masjidAdded:
        return '➕';
      case EventType.masjidDeleted:
        return '🗑️';
      case EventType.info:
        return 'ℹ️';
    }
  }
}
