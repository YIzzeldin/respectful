import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_masjid.dart';

/// Persists saved masjid locations to SharedPreferences.
class MasjidStorageService {
  static const _key = 'saved_masjids';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<SavedMasjid> loadAll() {
    final json = _prefs.getString(_key);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => SavedMasjid.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<SavedMasjid> masjids) async {
    await _prefs.setString(
      _key,
      jsonEncode(masjids.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> add(SavedMasjid masjid) async {
    final list = loadAll();
    list.add(masjid);
    await saveAll(list);
  }

  Future<void> remove(String id) async {
    final list = loadAll();
    list.removeWhere((m) => m.id == id);
    await saveAll(list);
  }

  Future<void> rename(String id, String newName) async {
    final list = loadAll();
    final index = list.indexWhere((m) => m.id == id);
    if (index >= 0) {
      final old = list[index];
      list[index] = SavedMasjid(
        id: old.id,
        name: newName,
        latitude: old.latitude,
        longitude: old.longitude,
        savedAt: old.savedAt,
      );
      await saveAll(list);
    }
  }
}
