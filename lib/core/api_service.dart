import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'http_helper.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Helper to read local tables
  Future<List<Map<String, dynamic>>> _getLocalTable(String userId, String tableName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _checkAndSeedDefaults(userId, prefs);
      final dataStr = prefs.getString('local_db_${userId}_$tableName');
      if (dataStr == null || dataStr.isEmpty) {
        return [];
      }
      final List<dynamic> list = jsonDecode(dataStr);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // Helper to write local tables
  Future<void> _setLocalTable(String userId, String tableName, List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_db_${userId}_$tableName', jsonEncode(data));
    } catch (_) {}
  }

  // Helper to read deleted IDs
  Future<List<String>> _getLocalDeleted(String userId, String tableName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString('local_db_deleted_${userId}_$tableName');
      if (dataStr == null || dataStr.isEmpty) {
        return [];
      }
      final List<dynamic> list = jsonDecode(dataStr);
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // Helper to write deleted IDs
  Future<void> _setLocalDeleted(String userId, String tableName, List<String> deletedIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_db_deleted_${userId}_$tableName', jsonEncode(deletedIds));
    } catch (_) {}
  }

  // Seed default data if it's the first time the user loads the app
  Future<void> _checkAndSeedDefaults(String userId, SharedPreferences prefs) async {
    final seedKey = 'local_db_seeded_$userId';
    if (prefs.getBool(seedKey) == true) return;

    // Seed budget
    final defaultBudget = {
      'userId': userId,
      'monthlyIncome': 12000.0,
      'needsBudget': 6000.0,
      'wantsBudget': 3600.0,
      'savingsBudget': 2400.0,
      'dailyLimit': 120.0,
    };
    await prefs.setString('local_db_${userId}_budget', jsonEncode(defaultBudget));

    // Seed expenses
    final defaultExpenses = [
      {
        'id': 'exp_1',
        'userId': userId,
        'amount': 15.0,
        'category': 'Tea',
        'note': 'Morning hot tea',
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': 'Cash',
        'needOrWant': 'Want',
        'isSynced': false,
      },
      {
        'id': 'exp_2',
        'userId': userId,
        'amount': 20.0,
        'category': 'Snacks',
        'note': 'Biscuits',
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': 'UPI',
        'needOrWant': 'Want',
        'isSynced': false,
      },
      {
        'id': 'exp_3',
        'userId': userId,
        'amount': 150.0,
        'category': 'Travel',
        'note': 'Train ticket',
        'date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'paymentMethod': 'Card',
        'needOrWant': 'Need',
        'isSynced': false,
      }
    ];
    await prefs.setString('local_db_${userId}_expenses', jsonEncode(defaultExpenses));

    // Seed income
    final defaultIncome = [
      {
        'id': 'inc_1',
        'userId': userId,
        'amount': 12000.0,
        'source': 'Allowance',
        'date': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'note': 'Pocket money',
        'isSynced': false,
      }
    ];
    await prefs.setString('local_db_${userId}_income', jsonEncode(defaultIncome));

    // Seed borrowed
    final defaultBorrowed = [
      {
        'id': 'bor_1',
        'userId': userId,
        'personName': 'Jithin',
        'amount': 800.0,
        'borrowDate': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        'dueDate': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
        'status': 'Pending',
        'isSynced': false,
      }
    ];
    await prefs.setString('local_db_${userId}_borrowed', jsonEncode(defaultBorrowed));

    // Seed receivables
    final defaultReceivables = [
      {
        'id': 'rec_1',
        'userId': userId,
        'personName': 'Ajmal',
        'amount': 500.0,
        'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'reminderStatus': 'Not Sent',
        'status': 'Pending',
        'isSynced': false,
      }
    ];
    await prefs.setString('local_db_${userId}_receivables', jsonEncode(defaultReceivables));

    // Seed goals
    final defaultGoals = [
      {
        'id': 'goal_1',
        'userId': userId,
        'goalName': 'EMO Robot',
        'targetAmount': 25000.0,
        'currentAmount': 2400.0,
        'deadline': DateTime.now().add(const Duration(days: 60)).toIso8601String(),
        'isSynced': false,
      }
    ];
    await prefs.setString('local_db_${userId}_goals', jsonEncode(defaultGoals));

    // Seed notifications
    final defaultNotifications = [
      {
        'id': 'not_1',
        'userId': userId,
        'title': 'Daily Tip',
        'message': 'You saved ₹30 on tea today! Keep it up for your EMO Robot goal.',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
        'isRead': false,
        'isSynced': false,
      }
    ];
    await prefs.setString('local_db_${userId}_notifications', jsonEncode(defaultNotifications));

    // Mark as seeded
    await prefs.setBool(seedKey, true);
  }

  // Unified Request Interceptor
  Future<Map<String, dynamic>> request(String action, Map<String, dynamic> payload) async {
    // If backend is configured and user attempts to login or signUp, hit server first
    if (AppConfig.isConfigured && (action == 'login' || action == 'signUp')) {
      try {
        final serverResponse = await _serverRequest(action, payload);
        final userId = serverResponse['userId']?.toString();
        if (userId != null && userId.isNotEmpty) {
          // Sync down historical data from sheet immediately
          try {
            final serverDashboard = await _serverRequest('getDashboardData', {'userId': userId});
            await _saveServerDashboardToLocal(userId, serverDashboard);
          } catch (_) {
            // Non-blocking catch: if pull dashboard fails, continue offline with local defaults
          }
        }
        return serverResponse;
      } catch (e) {
        // Fallback to local offline login if server is unreachable
        if (action == 'login') {
          return _localRequest(action, payload);
        } else {
          rethrow;
        }
      }
    }

    // Default to local storage for CRUD operations
    return _localRequest(action, payload);
  }

  // Server request executor
  Future<Map<String, dynamic>> _serverRequest(String action, Map<String, dynamic> payload) async {
    final response = await HttpHelper.postFollowRedirects(
      Uri.parse(AppConfig.backendUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': action,
        'payload': payload,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Server returned status code: ${response.statusCode}');
    }

    final Map<String, dynamic> responseData = jsonDecode(response.body);
    if (responseData['success'] == true) {
      return responseData['data'] as Map<String, dynamic>;
    } else {
      throw Exception(responseData['error'] ?? 'Unknown backend error');
    }
  }

  // Download all sheet data locally and mark as synced
  Future<void> _saveServerDashboardToLocal(String userId, Map<String, dynamic> serverDashboard) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save budget
    final budget = serverDashboard['budget'] ?? {};
    if (budget.isNotEmpty) {
      await prefs.setString('local_db_${userId}_budget', jsonEncode(budget));
    }

    // Save other tables and mark all items as isSynced = true
    final tables = ['expenses', 'income', 'borrowed', 'receivables', 'goals', 'notifications'];
    for (final table in tables) {
      final List<dynamic> list = serverDashboard[table] ?? [];
      final localList = list.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        map['isSynced'] = true; // Mark as already synced with sheet
        return map;
      }).toList();
      await prefs.setString('local_db_${userId}_$table', jsonEncode(localList));
      await prefs.setString('local_db_deleted_${userId}_$table', '[]');
    }

    // Mark as seeded to bypass local defaults
    await prefs.setBool('local_db_seeded_$userId', true);
  }

  // Local SQLite/JSON Mock engine
  Future<Map<String, dynamic>> _localRequest(String action, Map<String, dynamic> payload) async {
    // Small artificial delay for natural UX feeling
    await Future.delayed(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();

    switch (action) {
      case 'signUp':
        final email = (payload['email'] as String? ?? '').trim().toLowerCase();
        final pin = (payload['pin'] as String? ?? '').trim();
        final userName = (payload['userName'] as String? ?? '').trim();

        if (email.isEmpty || pin.isEmpty || userName.isEmpty) {
          throw Exception('Missing required fields: email, pin, userName');
        }

        final usersStr = prefs.getString('local_db_users') ?? '[]';
        final List<dynamic> usersList = jsonDecode(usersStr);
        final users = usersList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        final exists = users.any((u) => u['email'] == email);
        if (exists) {
          throw Exception('Email already registered');
        }

        final userId = const Uuid().v4();
        final newUser = {
          'userId': userId,
          'email': email,
          'pin': pin,
          'userName': userName,
          'currency': '₹',
          'emergencyThreshold': 1000.0,
        };
        users.add(newUser);
        await prefs.setString('local_db_users', jsonEncode(users));

        // Initialize default budget
        final defaultBudget = {
          'userId': userId,
          'monthlyIncome': 0.0,
          'needsBudget': 0.0,
          'wantsBudget': 0.0,
          'savingsBudget': 0.0,
          'dailyLimit': 0.0,
        };
        await prefs.setString('local_db_${userId}_budget', jsonEncode(defaultBudget));
        await prefs.setBool('local_db_seeded_$userId', true); // Bypass mock seeding

        return newUser;

      case 'login':
        final email = (payload['email'] as String? ?? '').trim().toLowerCase();
        final pin = (payload['pin'] as String? ?? '').trim();

        if (email.isEmpty || pin.isEmpty) {
          throw Exception('Missing email or PIN');
        }

        final usersStr = prefs.getString('local_db_users') ?? '[]';
        final List<dynamic> usersList = jsonDecode(usersStr);
        final users = usersList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        final userIdx = users.indexWhere((u) => u['email'] == email);
        if (userIdx != -1) {
          if (users[userIdx]['pin'] == pin) {
            final user = Map<String, dynamic>.from(users[userIdx]);
            // Fetch budget
            final budgetStr = prefs.getString('local_db_${user['userId']}_budget');
            if (budgetStr != null && budgetStr.isNotEmpty) {
              user['budget'] = jsonDecode(budgetStr);
            }
            return user;
          } else {
            throw Exception('Incorrect PIN');
          }
        }

        // Auto-create local user session to bypass registration screens if running entirely offline
        final userId = const Uuid().v4();
        final mockUser = {
          'userId': userId,
          'email': email,
          'pin': pin,
          'userName': 'Mock Student',
          'currency': '₹',
          'emergencyThreshold': 1000.0,
        };
        users.add(mockUser);
        await prefs.setString('local_db_users', jsonEncode(users));

        final defaultBudget = {
          'userId': userId,
          'monthlyIncome': 12000.0,
          'needsBudget': 6000.0,
          'wantsBudget': 3600.0,
          'savingsBudget': 2400.0,
          'dailyLimit': 120.0,
        };
        await prefs.setString('local_db_${userId}_budget', jsonEncode(defaultBudget));

        final userCopy = Map<String, dynamic>.from(mockUser);
        userCopy['budget'] = defaultBudget;
        return userCopy;

      case 'updateUserSettings':
        final userId = payload['userId'] as String?;
        if (userId == null || userId.isEmpty) throw Exception('Missing userId');

        final userName = payload['userName'] as String?;
        final pin = payload['pin'] as String?;
        final currency = payload['currency'] as String?;
        final threshold = (payload['emergencyThreshold'] as num?)?.toDouble();

        final usersStr = prefs.getString('local_db_users') ?? '[]';
        final List<dynamic> usersList = jsonDecode(usersStr);
        final users = usersList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        final idx = users.indexWhere((u) => u['userId'] == userId);
        if (idx != -1) {
          if (userName != null) users[idx]['userName'] = userName;
          if (pin != null) users[idx]['pin'] = pin;
          if (currency != null) users[idx]['currency'] = currency;
          if (threshold != null) users[idx]['emergencyThreshold'] = threshold;
          await prefs.setString('local_db_users', jsonEncode(users));
        }

        return {'status': 'success'};

      case 'getDashboardData':
        final userId = payload['userId'] as String?;
        if (userId == null || userId.isEmpty) throw Exception('Missing userId');

        final expenses = await _getLocalTable(userId, 'expenses');
        final income = await _getLocalTable(userId, 'income');
        final borrowed = await _getLocalTable(userId, 'borrowed');
        final receivables = await _getLocalTable(userId, 'receivables');
        final goals = await _getLocalTable(userId, 'goals');
        final notifications = await _getLocalTable(userId, 'notifications');

        final budgetStr = prefs.getString('local_db_${userId}_budget');
        Map<String, dynamic> budget = {
          'monthlyIncome': 0.0,
          'needsBudget': 0.0,
          'wantsBudget': 0.0,
          'savingsBudget': 0.0,
          'dailyLimit': 0.0,
        };
        if (budgetStr != null && budgetStr.isNotEmpty) {
          budget = Map<String, dynamic>.from(jsonDecode(budgetStr) as Map);
        }

        // Calculate summary metrics dynamically
        double totalIncome = 0.0;
        for (final item in income) {
          totalIncome += (item['amount'] as num?)?.toDouble() ?? 0.0;
        }

        double totalExpenses = 0.0;
        for (final item in expenses) {
          totalExpenses += (item['amount'] as num?)?.toDouble() ?? 0.0;
        }

        double currentBalance = totalIncome - totalExpenses;

        double pendingBorrowed = 0.0;
        for (final item in borrowed) {
          if (item['status'] == 'Pending') {
            pendingBorrowed += (item['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }

        double pendingReceivables = 0.0;
        for (final item in receivables) {
          if (item['status'] == 'Pending') {
            pendingReceivables += (item['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }

        double totalSavings = 0.0;
        for (final item in goals) {
          totalSavings += (item['currentAmount'] as num?)?.toDouble() ?? (item['currentSavedAmount'] as num?)?.toDouble() ?? 0.0;
        }

        final dailyLimit = (budget['dailyLimit'] as num?)?.toDouble() ?? 0.0;

        // Calculate today's expenses
        final todayStartStr = DateTime.now().toIso8601String().substring(0, 10);
        double todayExpenses = 0.0;
        for (final item in expenses) {
          final dateStr = (item['date'] as String? ?? '').substring(0, 10);
          if (dateStr == todayStartStr) {
            todayExpenses += (item['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }

        double upiLiteLoaded = 0.0;
        double upiLiteSpent = 0.0;
        for (final item in expenses) {
          final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
          if (item['category'] == 'Transfer' &&
              ((item['note'] as String? ?? '').toLowerCase().contains('load upi lite') ||
                  (item['note'] as String? ?? '').toLowerCase().contains('load lite'))) {
            upiLiteLoaded += amt;
          }
          if (item['paymentMethod'] == 'UPI Lite') {
            upiLiteSpent += amt;
          }
        }

        double upiLiteIncome = 0.0;
        for (final item in income) {
          if (item['paymentMethod'] == 'UPI Lite') {
            upiLiteIncome += (item['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }

        final double upiLiteBalance = (upiLiteLoaded + upiLiteIncome - upiLiteSpent).clamp(0.0, double.infinity);
        final double bankBalance = currentBalance - upiLiteBalance;

        final dailyBudgetRemaining = dailyLimit - todayExpenses;

        return {
          'summary': {
            'currentBalance': currentBalance,
            'bankBalance': bankBalance,
            'upiLiteBalance': upiLiteBalance,
            'totalIncome': totalIncome,
            'totalExpenses': totalExpenses,
            'totalSavings': totalSavings,
            'pendingBorrowed': pendingBorrowed,
            'pendingReceivables': pendingReceivables,
            'dailyLimit': dailyLimit,
            'dailyBudgetRemaining': dailyBudgetRemaining,
          },
          'budget': budget,
          'expenses': expenses,
          'income': income,
          'borrowed': borrowed,
          'receivables': receivables,
          'goals': goals,
          'notifications': notifications,
        };

      case 'syncData':
        final userId = payload['userId'] as String?;
        if (userId == null || userId.isEmpty) throw Exception('Missing userId');

        final tables = ['expenses', 'income', 'borrowed', 'receivables', 'goals', 'notifications'];
        for (final table in tables) {
          if (payload[table] != null) {
            final List items = payload[table] as List;
            final currentList = await _getLocalTable(userId, table);
            final deletedList = await _getLocalDeleted(userId, table);

            for (final item in items) {
              final mapItem = Map<String, dynamic>.from(item as Map);
              final id = mapItem['id']?.toString();
              if (id == null || id.isEmpty) continue;

              final action = mapItem['_action'] ?? 'upsert';

              if (action == 'delete') {
                final existingIdx = currentList.indexWhere((x) => x['id']?.toString() == id);
                if (existingIdx != -1) {
                  final existingItem = currentList[existingIdx];
                  if (existingItem['isSynced'] == true) {
                    deletedList.add(id); // track synced deletion
                  }
                  currentList.removeAt(existingIdx);
                }
              } else {
                final cleanItem = Map<String, dynamic>.from(mapItem)..remove('_action');
                cleanItem['isSynced'] = false; // Mark item as modified/unsynced

                final existingIdx = currentList.indexWhere((x) => x['id']?.toString() == id);
                if (existingIdx != -1) {
                  currentList[existingIdx] = cleanItem;
                } else {
                  currentList.add(cleanItem);
                }
              }
            }

            await _setLocalTable(userId, table, currentList);
            await _setLocalDeleted(userId, table, deletedList);
          }
        }

        if (payload['budget'] != null) {
          final budgetMap = Map<String, dynamic>.from(payload['budget'] as Map);
          await prefs.setString('local_db_${userId}_budget', jsonEncode(budgetMap));
        }

        return {
          'status': 'success',
          'syncedAt': DateTime.now().toIso8601String()
        };

      default:
        throw Exception('Action "$action" not supported locally');
    }
  }

  // Push all unsynced data + deleted transactions to cloud (Google Sheets)
  Future<Map<String, dynamic>> cloudUpdate(String userId) async {
    if (!AppConfig.isConfigured) {
      throw Exception('Google Sheets is not configured. Please set the Web App URL in Settings.');
    }

    final tables = ['expenses', 'income', 'borrowed', 'receivables', 'goals', 'notifications'];
    final Map<String, dynamic> syncPayload = {
      'userId': userId,
    };

    int unsyncedCount = 0;

    for (final table in tables) {
      final localList = await _getLocalTable(userId, table);
      final deletedList = await _getLocalDeleted(userId, table);

      final List<Map<String, dynamic>> itemsToSync = [];

      // 1. Add deleted items
      for (final id in deletedList) {
        itemsToSync.add({
          'id': id,
          '_action': 'delete',
        });
      }

      // 2. Add unsynced items
      for (final item in localList) {
        if (item['isSynced'] != true) {
          final cleanItem = Map<String, dynamic>.from(item)..remove('isSynced');
          itemsToSync.add(cleanItem);
        }
      }

      if (itemsToSync.isNotEmpty) {
        syncPayload[table] = itemsToSync;
        unsyncedCount += itemsToSync.length;
      }
    }

    // Include budget
    final prefs = await SharedPreferences.getInstance();
    final budgetStr = prefs.getString('local_db_${userId}_budget');
    if (budgetStr != null && budgetStr.isNotEmpty) {
      final budget = jsonDecode(budgetStr);
      syncPayload['budget'] = budget;
      unsyncedCount++;
    }

    if (unsyncedCount == 0) {
      return {
        'status': 'success',
        'syncedCount': 0,
      };
    }

    // Trigger POST request to Sheets Web App endpoint
    final response = await _serverRequest('syncData', syncPayload);

    // If server update returns success, flag all items as synced locally & clear deleted lists
    for (final table in tables) {
      final localList = await _getLocalTable(userId, table);
      final updatedLocalList = localList.map((item) {
        final map = Map<String, dynamic>.from(item);
        map['isSynced'] = true;
        return map;
      }).toList();

      await _setLocalTable(userId, table, updatedLocalList);
      await _setLocalDeleted(userId, table, []);
    }

    return {
      'status': 'success',
      'syncedCount': unsyncedCount,
    };
  }

  Future<void> markAllAsUnsynced(String userId) async {
    final tables = ['expenses', 'income', 'borrowed', 'receivables', 'goals', 'notifications'];
    for (final table in tables) {
      final localList = await _getLocalTable(userId, table);
      final updatedList = localList.map((item) {
        final map = Map<String, dynamic>.from(item);
        map['isSynced'] = false;
        return map;
      }).toList();
      await _setLocalTable(userId, table, updatedList);
    }
  }
}

