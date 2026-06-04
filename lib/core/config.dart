import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static String _backendUrl = "";

  static String get backendUrl => _backendUrl;

  static bool get isConfigured =>
      _backendUrl.isNotEmpty &&
      (_backendUrl.startsWith("https://script.google.com") ||
          _backendUrl.startsWith("http://") ||
          _backendUrl.startsWith("https://")); // Support local backend/other scripts for robust networking

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _backendUrl = prefs.getString('backendUrl') ?? "";
    } catch (_) {
      _backendUrl = "";
    }
  }

  static Future<void> setBackendUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backendUrl', url);
      _backendUrl = url;
    } catch (_) {}
  }
}
