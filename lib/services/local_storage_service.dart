import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seclick/model/log_entry.dart';

class LocalStorageService {
  static const String _historyKey = 'prediction_history';
  static final LocalStorageService _instance = LocalStorageService._internal();
  
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Future<void> savePrediction(LogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    
    // Add new entry at the beginning of the list
    history.insert(0, entry);
    
    // Keep only the last 100 entries
    if (history.length > 100) {
      history.removeLast();
    }
    
    final historyJson = history.map((e) => {
      'timestamp': e.timestamp,
      'url': e.url,
      'details': e.details,
      'phishing_percentage': e.phishingPercentage,
      'safe_percentage': e.safePercentage,
    }).toList();
    
    await prefs.setString(_historyKey, jsonEncode(historyJson));
  }

  Future<List<LogEntry>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) {
      return [];
    }
    
    final List<dynamic> decoded = jsonDecode(historyJson);
    return decoded.map((e) => LogEntry.fromJson(e)).toList();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
} 
