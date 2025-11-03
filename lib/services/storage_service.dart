import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/geofence_model.dart';

class StorageService {
  static SharedPreferences? _prefs;
  static const _key = 'geofences';

  /// ✅ Must be called once in main() before using any geofence storage
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<List<GeofenceModel>> getGeofences() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => GeofenceModel.fromJson(e)).toList();
  }

  static Future<void> addGeofence(GeofenceModel geofence) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final geofences = await getGeofences();
    geofences.add(geofence);
    await prefs.setString(
      _key,
      jsonEncode(geofences.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> removeGeofence(String id) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final geofences = await getGeofences();
    geofences.removeWhere((g) => g.id == id);
    await prefs.setString(
      _key,
      jsonEncode(geofences.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> updateGeofence(GeofenceModel updated) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final geofences = await getGeofences();
    final index = geofences.indexWhere((g) => g.id == updated.id);
    if (index != -1) geofences[index] = updated;
    await prefs.setString(
      _key,
      jsonEncode(geofences.map((e) => e.toJson()).toList()),
    );
  }
}
