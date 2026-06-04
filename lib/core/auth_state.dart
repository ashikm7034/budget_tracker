import 'package:shared_preferences/shared_preferences.dart';

class AuthState {
  static final AuthState _instance = AuthState._internal();
  factory AuthState() => _instance;
  AuthState._internal();

  String? _userId;
  String? _email;
  String _userName = 'User';
  String _currency = '₹';
  double _emergencyThreshold = 1000.0;
  String _geminiApiKey = '';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');
      if (_userId == 'user_1') {
        _userId = null;
        await prefs.remove('userId');
      }
      _email = prefs.getString('email');
      _userName = prefs.getString('userName') ?? 'User';
      _currency = prefs.getString('currency') ?? '₹';
      _emergencyThreshold = prefs.getDouble('emergencyThreshold') ?? 1000.0;
      _geminiApiKey = prefs.getString('geminiApiKey') ?? '';
    } catch (_) {}
  }

  bool get isLoggedIn => _userId != null && _userId!.isNotEmpty && _userId != 'user_1';

  String get userId => _userId ?? '';
  String get email => _email ?? '';
  String get userName => _userName;
  String get currency => _currency;
  double get emergencyThreshold => _emergencyThreshold;
  String get geminiApiKey => _geminiApiKey;

  Future<void> updateSettings({
    String? userName,
    String? currency,
    double? emergencyThreshold,
    String? geminiApiKey,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userName != null) {
        _userName = userName;
        await prefs.setString('userName', userName);
      }
      if (currency != null) {
        _currency = currency;
        await prefs.setString('currency', currency);
      }
      if (emergencyThreshold != null) {
        _emergencyThreshold = emergencyThreshold;
        await prefs.setDouble('emergencyThreshold', emergencyThreshold);
      }
      if (geminiApiKey != null) {
        _geminiApiKey = geminiApiKey;
        await prefs.setString('geminiApiKey', geminiApiKey);
      }
    } catch (_) {}
  }

  Future<void> setUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = userData['userId']?.toString();
      _email = userData['email']?.toString();
      _userName = userData['userName']?.toString() ?? 'User';
      _currency = userData['currency']?.toString() ?? '₹';
      _emergencyThreshold = double.tryParse(userData['emergencyThreshold']?.toString() ?? '') ?? 1000.0;

      if (_userId != null) await prefs.setString('userId', _userId!);
      if (_email != null) await prefs.setString('email', _email!);
      await prefs.setString('userName', _userName);
      await prefs.setString('currency', _currency);
      await prefs.setDouble('emergencyThreshold', _emergencyThreshold);
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = null;
      _email = null;
      await prefs.remove('userId');
      await prefs.remove('email');
      await prefs.remove('userName');
      await prefs.remove('currency');
      await prefs.remove('emergencyThreshold');
      await prefs.remove('geminiApiKey');
    } catch (_) {}
  }
}
