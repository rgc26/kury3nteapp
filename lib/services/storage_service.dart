import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/outage_report.dart';
import '../models/fuel_station.dart';
import '../models/app_models.dart';

/// Handles all local data persistence via SharedPreferences.
/// Designed with a clean interface so it can be swapped to Firebase later.
class StorageService {
  static const String _outagesKey = 'outage_reports';
  static const String _fuelLogsKey = 'fuel_logs';
  static const String _watchlistKey = 'watchlist_areas';
  static const String _readinessKey = 'readiness_checklist';
  static const String _bayanihanKey = 'bayanihan_posts';
  static const String _settingsKey = 'app_settings';
  static const String _geminiKeyKey = 'gemini_api_key';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Outage Reports ---
  Future<List<OutageReport>> getOutageReports() async {
    final data = _prefs.getString(_outagesKey);
    if (data == null) return [];
    final list = json.decode(data) as List;
    return list.map((e) => OutageReport.fromJson(e)).toList();
  }

  Future<void> saveOutageReport(OutageReport report) async {
    final reports = await getOutageReports();
    reports.add(report);
    await _prefs.setString(_outagesKey, json.encode(reports.map((e) => e.toJson()).toList()));
  }

  // --- Fuel Logs ---
  Future<List<FuelLog>> getFuelLogs() async {
    final data = _prefs.getString(_fuelLogsKey);
    if (data == null) return [];
    final list = json.decode(data) as List;
    return list.map((e) => FuelLog.fromJson(e)).toList();
  }

  Future<void> saveFuelLog(FuelLog log) async {
    final logs = await getFuelLogs();
    logs.add(log);
    await _prefs.setString(_fuelLogsKey, json.encode(logs.map((e) => e.toJson()).toList()));
  }

  // --- Watchlist ---
  Future<List<WatchlistArea>> getWatchlist() async {
    final data = _prefs.getString(_watchlistKey);
    if (data == null) return [];
    final list = json.decode(data) as List;
    return list.map((e) => WatchlistArea.fromJson(e)).toList();
  }

  Future<void> saveWatchlist(List<WatchlistArea> areas) async {
    await _prefs.setString(_watchlistKey, json.encode(areas.map((e) => e.toJson()).toList()));
  }

  // --- Readiness Checklist ---
  Future<Map<String, bool>> getReadinessChecklist() async {
    final data = _prefs.getString(_readinessKey);
    if (data == null) return _defaultChecklist;
    return Map<String, bool>.from(json.decode(data));
  }

  Future<void> saveReadinessChecklist(Map<String, bool> checklist) async {
    await _prefs.setString(_readinessKey, json.encode(checklist));
  }

  static const Map<String, bool> _defaultChecklist = {
    'Flashlight / Emergency Light': false,
    'Powerbank (10,000+ mAh)': false,
    'Water Supply (3-day)': false,
    'Portable Generator': false,
    'First Aid Kit': false,
    'Battery-powered Radio': false,
    'Cash on Hand (₱5,000+)': false,
    'Emergency Contact List': false,
    'Canned Food / Non-perishables': false,
    'Candles / Matches': false,
  };

  // --- Bayanihan Posts ---
  Future<List<BayanihanPost>> getBayanihanPosts() async {
    final data = _prefs.getString(_bayanihanKey);
    if (data == null) return [];
    final list = json.decode(data) as List;
    return list.map((e) => BayanihanPost.fromJson(e)).toList();
  }

  Future<void> saveBayanihanPosts(List<BayanihanPost> posts) async {
    await _prefs.setString(_bayanihanKey, json.encode(posts.map((e) => e.toJson()).toList()));
  }

  // --- Gemini API Key ---
  Future<String?> getGeminiApiKey() async {
    return _prefs.getString(_geminiKeyKey);
  }

  Future<void> saveGeminiApiKey(String key) async {
    await _prefs.setString(_geminiKeyKey, key);
  }

  // --- Settings ---
  Future<Map<String, dynamic>> getSettings() async {
    final data = _prefs.getString(_settingsKey);
    if (data == null) {
      return {
        'brownoutAlerts': true,
        'fuelAlerts': true,
        'criticalAlerts': true,
        'searchRadius': 5.0,
      };
    }
    return Map<String, dynamic>.from(json.decode(data));
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _prefs.setString(_settingsKey, json.encode(settings));
  }

  // --- Device Lock ---
  Future<String> getDeviceId() async {
    const key = 'device_unique_id';
    String? id = _prefs.getString(key);
    if (id == null) {
      // Generate a simple unique ID for web/demo
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
      await _prefs.setString(key, id);
    }
    return id;
  }
}
