import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthState {
  static final AuthState _instance = AuthState._internal();
  factory AuthState() => _instance;
  AuthState._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isLoggedIn => userId != null;

  String? get userId => _prefs?.getString('userId');
  String? get email => _prefs?.getString('email');
  String? get userName => _prefs?.getString('userName');
  String? get currency => _prefs?.getString('currency') ?? '₹';
  double get emergencyThreshold =>
      _prefs?.getDouble('emergencyThreshold') ?? 1000.0;

  Map<String, dynamic>? get budget {
    final raw = _prefs?.getString('budget');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> login(Map<String, dynamic> userData) async {
    if (_prefs == null) await init();
    await _prefs!.setString('userId', userData['userId']?.toString() ?? '');
    await _prefs!.setString('email', userData['email']?.toString() ?? '');
    await _prefs!.setString('userName', userData['userName']?.toString() ?? '');
    await _prefs!
        .setString('currency', userData['currency']?.toString() ?? '₹');
    await _prefs!.setDouble(
        'emergencyThreshold',
        double.tryParse(userData['emergencyThreshold']?.toString() ?? '') ??
            1000.0);

    if (userData['budget'] != null) {
      await _prefs!.setString('budget', jsonEncode(userData['budget']));
    }
  }

  Future<void> logout() async {
    if (_prefs == null) await init();
    await _prefs!.remove('userId');
    await _prefs!.remove('email');
    await _prefs!.remove('userName');
    await _prefs!.remove('currency');
    await _prefs!.remove('emergencyThreshold');
    await _prefs!.remove('budget');
  }
}
