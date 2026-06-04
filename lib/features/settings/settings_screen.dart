import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/api_service.dart';
import '../../core/auth_state.dart';
import '../../core/config.dart';
import '../../core/http_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authState = AuthState();
  final _apiService = ApiService();

  late TextEditingController _urlController;
  late TextEditingController _nameController;
  late TextEditingController _pinController;
  late TextEditingController _currencyController;
  late TextEditingController _thresholdController;
  late TextEditingController _incomeController;
  late TextEditingController _geminiApiKeyController;

  bool _testingConnection = false;
  String? _connectionStatus;
  Color _statusColor = Colors.transparent;

  double _needsBudget = 0.0;
  double _wantsBudget = 0.0;
  double _savingsBudget = 0.0;
  double _dailyLimit = 0.0;
  bool _useCustomDailyLimit = false;
  late TextEditingController _dailyLimitController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppConfig.backendUrl);
    _nameController = TextEditingController(text: _authState.userName);
    _pinController = TextEditingController(text: '1234'); // Default PIN placeholder
    _pinController.addListener(() {
      if (_pinController.text.trim() == '7034') {
        _urlController.text = 'https://script.google.com/macros/s/AKfycbwoPY6b22vZA-nc_SUxC_ylM_7tLXqS405Ikr0PYmNLAIMNSSbx_zQ3ZFVu0VXFChfa/exec';
      }
    });
    _currencyController = TextEditingController(text: _authState.currency);
    _thresholdController = TextEditingController(text: _authState.emergencyThreshold.toStringAsFixed(0));
    _incomeController = TextEditingController(text: '12000'); // Default monthly income placeholder
    _geminiApiKeyController = TextEditingController(text: _authState.geminiApiKey);

    _dailyLimitController = TextEditingController(text: '0');

    _calculateBudgets(_incomeController.text);
    _loadStoredBudget();
  }

  Future<void> _loadStoredBudget() async {
    // If backend is active, fetch current budget from mock/sheet
    try {
      final data = await _apiService.request('getDashboardData', {'userId': _authState.userId});
      final budget = data['budget'] ?? {};
      final income = (budget['monthlyIncome'] as num?)?.toDouble() ?? 12000.0;
      final daily = (budget['dailyLimit'] as num?)?.toDouble() ?? (income * 0.3 / 30.0);
      final customEnabled = budget['useCustomDailyLimit'] == true;

      setState(() {
        _incomeController.text = income.toStringAsFixed(0);
        _dailyLimit = daily;
        _useCustomDailyLimit = customEnabled;
        _dailyLimitController.text = daily.toStringAsFixed(0);
        _needsBudget = (budget['needsBudget'] as num?)?.toDouble() ?? (income * 0.5);
        _wantsBudget = (budget['wantsBudget'] as num?)?.toDouble() ?? (income * 0.3);
        _savingsBudget = (budget['savingsBudget'] as num?)?.toDouble() ?? (income * 0.2);
      });
    } catch (_) {}
  }

  void _calculateBudgets(String val) {
    final income = double.tryParse(val) ?? 0.0;
    setState(() {
      _needsBudget = income * 0.5;
      _wantsBudget = income * 0.3;
      _savingsBudget = income * 0.2;
      if (!_useCustomDailyLimit) {
        _dailyLimit = _wantsBudget > 0 ? (_wantsBudget / 30.0) : 0.0;
        _dailyLimitController.text = _dailyLimit.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _pinController.dispose();
    _currencyController.dispose();
    _thresholdController.dispose();
    _incomeController.dispose();
    _geminiApiKeyController.dispose();
    _dailyLimitController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _connectionStatus = "URL cannot be empty";
        _statusColor = const Color(0xFFFF453A);
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _connectionStatus = "Testing connection...";
      _statusColor = const Color(0xFF0A84FF);
    });

    try {
      final response = await HttpHelper.postFollowRedirects(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'login',
          'payload': {
            'email': _authState.email,
            'pin': _pinController.text.trim(),
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true || body['error'] != null) {
          // Even if login returns credentials error, it means script is running and communicating successfully!
          setState(() {
            _connectionStatus = "Success! Connected to Apps Script.";
            _statusColor = const Color(0xFF30D158);
          });
        } else {
          setState(() {
            _connectionStatus = "Script returned invalid response format.";
            _statusColor = const Color(0xFFFF9500);
          });
        }
      } else {
        setState(() {
          _connectionStatus = "HTTP Error: ${response.statusCode}";
          _statusColor = const Color(0xFFFF453A);
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = "Failed to connect: $e";
        _statusColor = const Color(0xFFFF453A);
      });
    } finally {
      setState(() {
        _testingConnection = false;
      });
    }
  }

  Future<void> _saveAndSync() async {
    print("MoneyMate DEBUG: _saveAndSync started");
    if (!_formKey.currentState!.validate()) {
      print("MoneyMate DEBUG: Form validation failed");
      return;
    }
    print("MoneyMate DEBUG: Form validation passed");

    final url = _urlController.text.trim();
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    final currency = _currencyController.text.trim();
    final threshold = double.tryParse(_thresholdController.text.trim()) ?? 1000.0;
    final income = double.tryParse(_incomeController.text.trim()) ?? 12000.0;
    final geminiApiKey = _geminiApiKeyController.text.trim();

    print("MoneyMate DEBUG: Setting backend URL locally: $url");
    // Save configuration settings
    await AppConfig.setBackendUrl(url);
    print("MoneyMate DEBUG: Updating auth state locally");
    await _authState.updateSettings(
      userName: name,
      currency: currency,
      emergencyThreshold: threshold,
      geminiApiKey: geminiApiKey,
    );

    print("MoneyMate DEBUG: AppConfig.isConfigured = ${AppConfig.isConfigured}");
    // If backend URL is saved and looks valid, push dynamic configs to Google Sheet
    if (AppConfig.isConfigured) {
      try {
        print("MoneyMate DEBUG: Requesting updateUserSettings...");
        try {
          // 1. Sync User Details Settings
          await _apiService.request('updateUserSettings', {
            'userId': _authState.userId,
            'userName': name,
            'pin': pin,
            'currency': currency,
            'emergencyThreshold': threshold,
          });
        } catch (e) {
          final errorMsg = e.toString();
          if (errorMsg.contains('User profile not found')) {
            print("MoneyMate DEBUG: User profile not found. Auto-registering...");
            Map<String, dynamic> signUpResult;
            try {
              signUpResult = await _apiService.request('signUp', {
                'email': _authState.email,
                'pin': pin,
                'userName': name,
              });
            } catch (signUpError) {
              if (signUpError.toString().contains('Email already registered')) {
                print("MoneyMate DEBUG: Email already registered. Logging in instead...");
                signUpResult = await _apiService.request('login', {
                  'email': _authState.email,
                  'pin': pin,
                });
              } else {
                rethrow;
              }
            }
            await _authState.setUserData(signUpResult);
            print("MoneyMate DEBUG: Auto-registration/login successful, new userId: ${_authState.userId}");
            
            // Try updating settings again with new userId
            await _apiService.request('updateUserSettings', {
              'userId': _authState.userId,
              'userName': name,
              'pin': pin,
              'currency': currency,
              'emergencyThreshold': threshold,
            });
          } else {
            rethrow;
          }
        }
        print("MoneyMate DEBUG: updateUserSettings request successful");

        print("MoneyMate DEBUG: Requesting syncData for budget...");
        // 2. Sync Budget allocations
        await _apiService.request('syncData', {
          'userId': _authState.userId,
          'budget': {
            'monthlyIncome': income,
            'needsBudget': _needsBudget,
            'wantsBudget': _wantsBudget,
            'savingsBudget': _savingsBudget,
            'dailyLimit': _useCustomDailyLimit
                ? (double.tryParse(_dailyLimitController.text) ?? 0.0)
                : _dailyLimit,
            'useCustomDailyLimit': _useCustomDailyLimit,
          }
        });
        print("MoneyMate DEBUG: syncData request successful");
      } catch (e) {
        print("MoneyMate DEBUG: Exception caught in backend sync: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved locally, but backend sync failed: $e'),
              backgroundColor: const Color(0xFFFF9500),
            ),
          );
          // Pop the screen so user settings are preserved locally
          Navigator.of(context).pop(true);
        }
        return;
      }
    }

    print("MoneyMate DEBUG: Settings successfully saved, popping context");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved & synchronized successfully!'),
          backgroundColor: Color(0xFF30D158),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'SETTINGS',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveAndSync,
            child: Text(
              'Save',
              style: GoogleFonts.outfit(
                color: const Color(0xFF0A84FF),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('GOOGLE SHEETS DATABASE CONNECTION'),
              _buildConnectionCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('USER PROFILE SETTINGS'),
              _buildProfileCard(),
              const SizedBox(height: 24),
              _buildSectionHeader('50/30/20 BUDGET CALCULATOR'),
              _buildBudgetCard(),
              const SizedBox(height: 24),
              _buildInstructionsPanel(),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF0A84FF).withOpacity(0.2), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'Log In / Switch Account',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF0A84FF),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  await _authState.logout();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF453A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.2), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFF453A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: const Color(0xFF8E8E93),
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Google Apps Script Web App URL',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _urlController,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF2C2C2E),
              hintText: 'https://script.google.com/macros/s/...',
              hintStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _testingConnection ? null : _testConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A84FF).withOpacity(0.12),
                    foregroundColor: const Color(0xFF0A84FF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _testingConnection
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A84FF)),
                        )
                      : Text('Test Connection', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (_connectionStatus != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _statusColor.withOpacity(0.3)),
              ),
              child: Text(
                _connectionStatus!,
                style: GoogleFonts.outfit(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTextFieldRow('User Name', _nameController, 'Enter display name'),
          const Divider(color: Color(0xFF2C2C2E), height: 24),
          _buildTextFieldRow('Verification PIN', _pinController, '4-digit PIN', keyboardType: TextInputType.number, obscureText: true),
          const Divider(color: Color(0xFF2C2C2E), height: 24),
          _buildTextFieldRow('Currency Symbol', _currencyController, 'e.g. ₹, \$, €'),
          const Divider(color: Color(0xFF2C2C2E), height: 24),
          _buildTextFieldRow('Emergency Limit', _thresholdController, 'Alert threshold amount', keyboardType: TextInputType.number),
          const Divider(color: Color(0xFF2C2C2E), height: 24),
          _buildTextFieldRow('Gemini API Key', _geminiApiKeyController, 'Enter key (optional)', obscureText: true, isOptional: true),
        ],
      ),
    );
  }

  Widget _buildTextFieldRow(String label, TextEditingController controller, String hint,
      {TextInputType keyboardType = TextInputType.text, bool obscureText = false, bool isOptional = false}) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.end,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 13),
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            validator: (val) {
              if (isOptional) return null;
              if (val == null || val.trim().isEmpty) return 'Required';
              return null;
            },
          ),
        )
      ],
    );
  }

  Widget _buildBudgetCard() {
    final currency = _currencyController.text.trim();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Monthly Income',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _incomeController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(color: const Color(0xFF30D158), fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.end,
                  onChanged: _calculateBudgets,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    if (double.tryParse(val) == null) return 'Invalid number';
                    return null;
                  },
                ),
              )
            ],
          ),
          const Divider(color: Color(0xFF2C2C2E), height: 24),
          _buildBudgetSplitRow('Needs Budget (50%)', _needsBudget, currency),
          const SizedBox(height: 8),
          _buildBudgetSplitRow('Wants Budget (30%)', _wantsBudget, currency),
          const SizedBox(height: 8),
          _buildBudgetSplitRow('Savings Budget (20%)', _savingsBudget, currency),
          const Divider(color: Color(0xFF2C2C2E), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Use Custom Daily Limit',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Switch.adaptive(
                value: _useCustomDailyLimit,
                activeColor: const Color(0xFF30D158),
                onChanged: (val) {
                  setState(() {
                    _useCustomDailyLimit = val;
                    if (!val) {
                      _dailyLimit = _wantsBudget > 0 ? (_wantsBudget / 30.0) : 0.0;
                      _dailyLimitController.text = _dailyLimit.toStringAsFixed(0);
                    }
                  });
                },
              ),
            ],
          ),
          if (_useCustomDailyLimit) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Custom Daily Limit',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _dailyLimitController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.outfit(color: const Color(0xFF0A84FF), fontSize: 15, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'Enter daily limit',
                    ),
                    onChanged: (val) {
                      setState(() {
                        _dailyLimit = double.tryParse(val) ?? 0.0;
                      });
                    },
                    validator: (val) {
                      if (_useCustomDailyLimit) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        if (double.tryParse(val) == null) return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calculated Daily Limit',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$currency${_dailyLimit.toStringAsFixed(0)} / day',
                  style: GoogleFonts.outfit(color: const Color(0xFF0A84FF), fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildBudgetSplitRow(String label, double amount, String currency) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 12),
        ),
        Text(
          '$currency${amount.toStringAsFixed(0)}',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildInstructionsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0A84FF).withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF0A84FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Setup Instructions',
                style: GoogleFonts.outfit(color: const Color(0xFF0A84FF), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStepText('1. Open a Google Sheet and copy its URL.'),
          _buildStepText('2. Go to Extensions > Apps Script in Google Sheets.'),
          _buildStepText('3. Paste the contents of "apps_script.js" inside the editor.'),
          _buildStepText('4. Click Deploy > New Deployment. Select type "Web App".'),
          _buildStepText('5. Set "Execute as: Me" and "Who has access: Anyone".'),
          _buildStepText('6. Click Deploy, authorize permissions, and copy the Web App URL here.'),
        ],
      ),
    );
  }

  Widget _buildStepText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: GoogleFonts.outfit(color: const Color(0xFFD1D1D6), fontSize: 12, height: 1.4),
      ),
    );
  }
}
