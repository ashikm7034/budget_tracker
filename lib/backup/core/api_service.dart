import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Dynamic state representation for offline demo mock database
  final List<Map<String, dynamic>> _mockUsers = [];
  List<Map<String, dynamic>>? _mockExpenses;
  List<Map<String, dynamic>>? _mockIncome;
  List<Map<String, dynamic>>? _mockBorrowed;
  List<Map<String, dynamic>>? _mockReceivables;
  List<Map<String, dynamic>>? _mockGoals;
  List<Map<String, dynamic>>? _mockNotifications;
  Map<String, dynamic>? _mockBudget;

  void _initMockData(String userId) {
    if (_mockExpenses != null) return;

    _mockExpenses = [
      {
        'id': 'exp_1',
        'userId': userId,
        'amount': 15.0,
        'category': 'Tea',
        'note': 'Morning hot tea',
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': 'Cash',
        'needOrWant': 'Want'
      },
      {
        'id': 'exp_2',
        'userId': userId,
        'amount': 20.0,
        'category': 'Snacks',
        'note': 'Biscuits',
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': 'UPI',
        'needOrWant': 'Want'
      },
      {
        'id': 'exp_3',
        'userId': userId,
        'amount': 150.0,
        'category': 'Travel',
        'note': 'Train ticket',
        'date': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'paymentMethod': 'Card',
        'needOrWant': 'Need'
      }
    ];

    _mockIncome = [
      {
        'id': 'inc_1',
        'userId': userId,
        'amount': 12000.0,
        'source': 'Allowance',
        'date': DateTime.now()
            .subtract(const Duration(days: 3))
            .toIso8601String(),
        'note': 'Pocket money'
      }
    ];

    _mockBorrowed = [
      {
        'id': 'bor_1',
        'userId': userId,
        'personName': 'Jithin',
        'amount': 800.0,
        'borrowDate': DateTime.now()
            .subtract(const Duration(days: 4))
            .toIso8601String(),
        'dueDate': DateTime.now()
            .add(const Duration(days: 10))
            .toIso8601String(),
        'status': 'Pending'
      }
    ];

    _mockReceivables = [
      {
        'id': 'rec_1',
        'userId': userId,
        'personName': 'Ajmal',
        'amount': 500.0,
        'date': DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
        'reminderStatus': 'Not Sent',
        'status': 'Pending'
      }
    ];

    _mockGoals = [
      {
        'id': 'goal_1',
        'userId': userId,
        'goalName': 'EMO Robot',
        'targetAmount': 25000.0,
        'currentAmount': 2400.0,
        'deadline': DateTime.now()
            .add(const Duration(days: 60))
            .toIso8601String(),
      }
    ];

    _mockNotifications = [
      {
        'id': 'not_1',
        'userId': userId,
        'title': 'Daily Tip',
        'message':
            'You saved ₹30 on tea today! Keep it up for your EMO Robot goal.',
        'timestamp': DateTime.now()
            .subtract(const Duration(minutes: 45))
            .toIso8601String(),
        'isRead': false
      }
    ];

    _mockBudget = {
      'userId': userId,
      'monthlyIncome': 12000.0,
      'needsBudget': 6000.0,
      'wantsBudget': 3600.0,
      'savingsBudget': 2400.0,
      'dailyLimit': 120.0,
    };
  }

  void _syncMockTable(List<Map<String, dynamic>> table, List items) {
    for (final item in items) {
      final mapItem = Map<String, dynamic>.from(item as Map);
      final id = mapItem['id'];
      final action = mapItem['_action'] ?? 'upsert';

      if (action == 'delete') {
        table.removeWhere((x) => x['id'] == id);
      } else {
        // Clean off local action keys before saving
        final cleanItem = Map<String, dynamic>.from(mapItem)..remove('_action');
        final existingIndex = table.indexWhere((x) => x['id'] == id);
        if (existingIndex != -1) {
          table[existingIndex] = cleanItem;
        } else {
          table.add(cleanItem);
        }
      }
    }
  }

  Future<Map<String, dynamic>> request(
      String action, Map<String, dynamic> payload) async {
    if (!AppConfig.isConfigured) {
      return _mockRequest(action, payload);
    }

    try {
      final response = await http.post(
        Uri.parse(AppConfig.backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': action,
          'payload': payload,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned status code: ${response.statusCode}');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['success'] == true) {
        return responseData['data'] as Map<String, dynamic>;
      } else {
        throw Exception(responseData['error'] ?? 'Unknown backend error');
      }
    } catch (e) {
      throw Exception('Connection failed: $e');
    }
  }

  Future<Map<String, dynamic>> _mockRequest(
      String action, Map<String, dynamic> payload) async {
    await Future.delayed(
        const Duration(milliseconds: 600)); // Simulate realistic network latency

    switch (action) {
      case 'signUp':
        final email = (payload['email'] as String? ?? '').trim().toLowerCase();
        final pin = (payload['pin'] as String? ?? '').trim();
        final userName = (payload['userName'] as String? ?? '').trim();

        if (email.isEmpty || pin.isEmpty || userName.isEmpty) {
          throw Exception('Missing required fields: email, pin, userName');
        }

        final exists = _mockUsers.any((u) => u['email'] == email);
        if (exists) {
          throw Exception('Email already registered (Mock Mode)');
        }

        final userId = const Uuid().v4();
        final newUser = {
          'userId': userId,
          'email': email,
          'pin': pin,
          'userName': userName,
          'currency': '₹',
          'emergencyThreshold': 1000,
          'budget': {
            'monthlyIncome': 0.0,
            'needsBudget': 0.0,
            'wantsBudget': 0.0,
            'savingsBudget': 0.0,
            'dailyLimit': 0.0,
          }
        };
        _mockUsers.add(newUser);
        return newUser;

      case 'login':
        final email = (payload['email'] as String? ?? '').trim().toLowerCase();
        final pin = (payload['pin'] as String? ?? '').trim();

        if (email.isEmpty || pin.isEmpty) {
          throw Exception('Missing email or PIN');
        }

        try {
          final user = _mockUsers.firstWhere(
            (u) => u['email'] == email && u['pin'] == pin,
          );
          return user;
        } catch (_) {
          // In mock mode, auto-create a default mock session to bypass registration during testing
          final userId = const Uuid().v4();
          return {
            'userId': userId,
            'email': email,
            'pin': pin,
            'userName': 'Mock Student',
            'currency': '₹',
            'emergencyThreshold': 1000,
            'budget': {
              'monthlyIncome': 12000.0,
              'needsBudget': 6000.0,
              'wantsBudget': 3600.0,
              'savingsBudget': 2400.0,
              'dailyLimit': 120.0,
            }
          };
        }

      case 'syncData':
        final userId = payload['userId'] as String?;
        if (userId == null) throw Exception('Missing userId');
        _initMockData(userId);

        if (payload['expenses'] != null) {
          _syncMockTable(_mockExpenses!, payload['expenses'] as List);
        }
        if (payload['income'] != null) {
          _syncMockTable(_mockIncome!, payload['income'] as List);
        }
        if (payload['borrowed'] != null) {
          _syncMockTable(_mockBorrowed!, payload['borrowed'] as List);
        }
        if (payload['receivables'] != null) {
          _syncMockTable(_mockReceivables!, payload['receivables'] as List);
        }
        if (payload['goals'] != null) {
          _syncMockTable(_mockGoals!, payload['goals'] as List);
        }
        if (payload['notifications'] != null) {
          _syncMockTable(_mockNotifications!, payload['notifications'] as List);
        }
        if (payload['budget'] != null) {
          _mockBudget = Map<String, dynamic>.from(payload['budget'] as Map);
        }

        return {
          'status': 'success',
          'syncedAt': DateTime.now().toIso8601String()
        };

      case 'getDashboardData':
        final userId = payload['userId'] as String?;
        if (userId == null) throw Exception('Missing userId');
        _initMockData(userId);

        // Compute summary metrics dynamically from the mutable tables
        double totalIncome = 0.0;
        for (final item in _mockIncome!) {
          totalIncome += (item['amount'] as num?)?.toDouble() ?? 0.0;
        }

        double totalExpenses = 0.0;
        for (final item in _mockExpenses!) {
          totalExpenses += (item['amount'] as num?)?.toDouble() ?? 0.0;
        }

        double currentBalance = totalIncome - totalExpenses;

        double pendingBorrowed = 0.0;
        for (final item in _mockBorrowed!) {
          if (item['status'] == 'Pending') {
            pendingBorrowed += (item['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }

        double pendingReceivables = 0.0;
        for (final item in _mockReceivables!) {
          if (item['status'] == 'Pending') {
            pendingReceivables += (item['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }

        double totalSavings = 0.0;
        for (final item in _mockGoals!) {
          totalSavings += (item['currentAmount'] as num?)?.toDouble() ?? 0.0;
        }

        final dailyLimit =
            (_mockBudget!['dailyLimit'] as num?)?.toDouble() ?? 0.0;

        // Calculate today's expenses in user's local day
        final todayStartStr =
            DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
        double todayExpenses = 0.0;
        for (final item in _mockExpenses!) {
          final dateStr = (item['date'] as String? ?? '').substring(0, 10);
          if (dateStr == todayStartStr) {
            todayExpenses += (item['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }

        final dailyBudgetRemaining = dailyLimit - todayExpenses;

        return {
          'summary': {
            'currentBalance': currentBalance,
            'totalIncome': totalIncome,
            'totalExpenses': totalExpenses,
            'totalSavings': totalSavings,
            'pendingBorrowed': pendingBorrowed,
            'pendingReceivables': pendingReceivables,
            'dailyLimit': dailyLimit,
            'dailyBudgetRemaining': dailyBudgetRemaining,
          },
          'expenses': List<Map<String, dynamic>>.from(_mockExpenses!),
          'income': List<Map<String, dynamic>>.from(_mockIncome!),
          'borrowed': List<Map<String, dynamic>>.from(_mockBorrowed!),
          'receivables': List<Map<String, dynamic>>.from(_mockReceivables!),
          'goals': List<Map<String, dynamic>>.from(_mockGoals!),
          'notifications': List<Map<String, dynamic>>.from(_mockNotifications!),
        };

      default:
        throw Exception('Action "$action" not supported in Mock Mode');
    }
  }
}
