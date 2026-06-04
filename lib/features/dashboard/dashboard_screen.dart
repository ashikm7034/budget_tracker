import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/auth_state.dart';
import '../../core/api_service.dart';
import 'package:uuid/uuid.dart';
import '../../core/config.dart';
import '../expenses/expense_list_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../payment/qr_scanner_screen.dart';
import '../settings/settings_screen.dart';
import '../income/income_tracker_screen.dart';
import 'dashboard_skeleton.dart';
import '../../core/widgets/apple_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthState _authState = AuthState();
  NumberFormat get _currencyFormat =>
      NumberFormat.currency(locale: 'en_IN', symbol: _authState.currency, decimalDigits: 0);

  bool _isLoading = true;
  bool _isSyncing = false;
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _authState.userId;
      if (userId == null) throw Exception('No authenticated user session found');

      final data = await ApiService().request('getDashboardData', {
        'userId': userId,
      });

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showLoadUpiLiteDialog() {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Load UPI Lite',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter amount to transfer from your Bank Account to UPI Lite wallet.',
                  style: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: InputDecoration(
                      prefixText: '${_authState.currency} ',
                      prefixStyle: GoogleFonts.outfit(color: const Color(0xFF0A84FF), fontWeight: FontWeight.bold),
                      hintText: '0',
                      hintStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(color: const Color(0xFFFF453A)),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final double? amt = double.tryParse(amountController.text.trim());
                  if (amt == null || amt <= 0) return;
                  Navigator.of(context).pop();
                  await _loadMoneyToUpiLite(amt);
                },
                child: Text(
                  'Load',
                  style: GoogleFonts.outfit(color: const Color(0xFF30D158), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadMoneyToUpiLite(double amount) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final userId = _authState.userId;
      if (userId != null) {
        final expenseId = 'exp_${const Uuid().v4()}';
        final newExpense = {
          'id': expenseId,
          'userId': userId,
          'amount': amount,
          'category': 'Transfer',
          'note': 'Load UPI Lite',
          'date': DateTime.now().toIso8601String(),
          'paymentMethod': 'UPI',
          'needOrWant': 'Need',
        };

        await ApiService().request('syncData', {
          'userId': userId,
          'expenses': [newExpense]
        });
        
        await _fetchDashboardData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load UPI Lite: $e'),
            backgroundColor: const Color(0xFFFF453A),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncToCloud() async {
    final configured = AppConfig.isConfigured;
    if (!configured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF9F0A),
          content: Text(
            'Google Sheets not configured. Set URL in Settings first!',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final userId = _authState.userId;
      if (userId.isEmpty) throw Exception('No authenticated user session found');

      await ApiService().markAllAsUnsynced(userId);

      final result = await ApiService().cloudUpdate(userId);
      final syncedCount = result['syncedCount'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text(
              syncedCount > 0
                  ? 'Cloud Update Successful! Synced $syncedCount changes.'
                  : 'Cloud Update: Everything is already up-to-date!',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
        _fetchDashboardData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF453A),
            content: Text(
              'Sync failed: ${e.toString().replaceAll('Exception: ', '')}',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tea':
        return Icons.local_cafe_rounded;
      case 'snacks':
        return Icons.fastfood_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'travel':
        return Icons.directions_car_rounded;
      case 'college':
        return Icons.school_rounded;
      case 'recharge':
        return Icons.bolt_rounded;
      case 'shopping':
        return Icons.local_mall_rounded;
      case 'subscription':
        return Icons.card_membership_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'tea':
        return const Color(0xFFFF9F0A); // Apple Amber
      case 'snacks':
        return const Color(0xFFFF2D55); // Apple Pink
      case 'food':
        return const Color(0xFF30D158); // Apple Green
      case 'travel':
        return const Color(0xFF64D2FF); // Apple Sky Blue
      case 'college':
        return const Color(0xFFBF5AF2); // Apple Purple
      case 'recharge':
        return const Color(0xFFFF375F); // Apple Rose
      case 'shopping':
        return const Color(0xFFFF9F0A); // Apple Amber
      case 'subscription':
        return const Color(0xFF5E5CE6); // Apple Lavender
      case 'transfer':
        return const Color(0xFF0A84FF); // Apple Blue
      default:
        return const Color(0xFF8E8E93); // Apple Muted Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Apple True Black
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
          style: GoogleFonts.outfit(
            color: const Color(0xFF8E8E93),
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          if (_isSyncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF0A84FF),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
              tooltip: 'Cloud Update',
              onPressed: _syncToCloud,
            ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) {
                _fetchDashboardData();
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: const Color(0xFF0A84FF),
        backgroundColor: const Color(0xFF1C1C1E),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final bool showSkeleton = _isLoading && _dashboardData == null;

    final summary = _dashboardData?['summary'] ?? {};
    final currentBalance = (summary['currentBalance'] as num?)?.toDouble() ?? 0.0;
    final dailyLimit = (summary['dailyLimit'] as num?)?.toDouble() ?? 0.0;
    final dailyBudgetRemaining = (summary['dailyBudgetRemaining'] as num?)?.toDouble() ?? 0.0;

    final List<dynamic> rawExpenses = _dashboardData?['expenses'] as List? ?? [];
    final List<dynamic> rawIncome = _dashboardData?['income'] as List? ?? [];

    final List<Map<String, dynamic>> typedExpenses = rawExpenses
        .map((item) => Map<String, dynamic>.from(item as Map)..['isIncome'] = false)
        .toList();

    final List<Map<String, dynamic>> typedIncome = rawIncome
        .map((item) => Map<String, dynamic>.from(item as Map)
          ..['isIncome'] = true
          ..['category'] = item['source'] ?? 'Income')
        .toList();

    final List<Map<String, dynamic>> combinedActivity = [...typedExpenses, ...typedIncome];
    combinedActivity.sort((a, b) {
      final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 100.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),

          // Apple Wallet style flat card (Slide fade entrance & Bounceable)
          if (showSkeleton)
            _buildWalletCardPlaceholder()
          else
            AppleSlideFadeEntrance(
              delay: Duration.zero,
              child: AppleBounceable(
                onTap: _fetchDashboardData,
                child: _buildAppleWalletCard(
                  currentBalance,
                  (summary['bankBalance'] as num?)?.toDouble() ?? currentBalance,
                  (summary['upiLiteBalance'] as num?)?.toDouble() ?? 0.0,
                  dailyLimit,
                  dailyBudgetRemaining,
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Quick Action Buttons (Thumb Zone with stagger entrance and bounce)
          AppleSlideFadeEntrance(
            delay: const Duration(milliseconds: 120),
            child: Row(
              children: [
                Expanded(
                  child: AppleBounceable(
                    onTap: () async {
                      final refresh = await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                      );
                      if (refresh == true) {
                        _fetchDashboardData();
                      }
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_scanner, color: Color(0xFF0A84FF), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Scan to Pay',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppleBounceable(
                    onTap: () async {
                      final refresh = await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                      );
                      if (refresh == true) {
                        _fetchDashboardData();
                      }
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Add Expense',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          if (_errorMessage != null) ...[
            _buildOfflineErrorSection(),
            const SizedBox(height: 24),
          ],

          // Recent Activity Section (Slide-in and Bounce items)
          AppleSlideFadeEntrance(
            delay: const Duration(milliseconds: 240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final refresh = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ExpenseListScreen()),
                        );
                        if (refresh == true) {
                          _fetchDashboardData();
                        }
                      },
                      child: Text(
                        'See All',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF0A84FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Recent Expenses List Grouped iOS-style
                if (showSkeleton)
                  _buildActivityListPlaceholder()
                else if (combinedActivity.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: Text(
                      'No recent activity yet.',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF1C1C1E),
                          Color(0xFF141416),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 0.5,
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: combinedActivity.length > 5 ? 5 : combinedActivity.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: Color(0xFF2C2C2E), // Thin Divider
                        height: 0.5,
                        thickness: 0.5,
                        indent: 52,
                      ),
                      itemBuilder: (context, index) {
                        final item = combinedActivity[index];
                        final bool isIncome = item['isIncome'] == true;
                        final String category = item['category'] ?? 'Other';
                        final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                        final String note = item['note'] ?? '';
                        final String dateStr = item['date'] ?? '';
                        final date = DateTime.tryParse(dateStr) ?? DateTime.now();

                        final catColor = isIncome ? const Color(0xFF30D158) : _getCategoryColor(category);
                        final catIcon = isIncome ? Icons.arrow_downward_rounded : _getCategoryIcon(category);

                        return AppleBounceable(
                          onTap: () => _showTransactionDetails(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: catColor.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(catIcon, color: catColor, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (note.isNotEmpty ? note : category).replaceAll(RegExp(r'\s+(expense|income)$', caseSensitive: false), ''),
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        DateFormat('d MMM, h:mm a').format(date),
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF8E8E93),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      isIncome ? '+ ${_currencyFormat.format(amount)}' : '- ${_currencyFormat.format(amount)}',
                                      style: GoogleFonts.outfit(
                                        color: isIncome ? const Color(0xFF30D158) : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Color(0xFF38383A),
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleWalletCard(
      double balance, double bankBalance, double upiLiteBalance, double dailyLimit, double dailyRemaining) {
    final hasLimit = dailyLimit > 0;
    final isOverspent = dailyRemaining < 0;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1C1E),
            Color(0xFF0F0F10),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2C2C2E),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL BALANCE',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF8E8E93),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0A84FF), size: 20),
            ],
          ),
          const SizedBox(height: 6),
          AppleAnimatedCount(
            endValue: balance,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
            formatter: (val) => _currencyFormat.format(val),
          ),
          const SizedBox(height: 16),
          // Sub-balances Row
          Row(
            children: [
              // Main Bank Account / UPI
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BANK / UPI',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF8E8E93),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormat.format(bankBalance),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // UPI Lite
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UPI LITE',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF8E8E93),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(upiLiteBalance),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _showLoadUpiLiteDialog,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0A84FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY BUDGET',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF8E8E93),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasLimit
                        ? _currencyFormat.format(dailyRemaining.abs())
                        : 'Not Set',
                    style: GoogleFonts.outfit(
                      color: isOverspent
                          ? const Color(0xFFFF453A) // iOS Red
                          : const Color(0xFF30D158), // iOS Green
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (hasLimit)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOverspent
                        ? const Color(0xFFFF453A).withOpacity(0.12)
                        : const Color(0xFF30D158).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOverspent ? 'OVER LIMIT' : 'ON TRACK',
                    style: GoogleFonts.outfit(
                      color: isOverspent ? const Color(0xFFFF453A) : const Color(0xFF30D158),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> item) {
    final bool isIncome = item['isIncome'] == true;
    final String category = item['category'] ?? 'Other';
    final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final String note = item['note'] ?? '';
    final String dateStr = item['date'] ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final String classification = isIncome ? 'INCOME' : (item['needOrWant'] ?? item['classification'] ?? 'Want');
    final String paymentMethod = item['paymentMethod'] ?? 'UPI';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaction Details',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF8E8E93)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Amount', _currencyFormat.format(amount), valueColor: isIncome ? const Color(0xFF30D158) : const Color(0xFF0A84FF)),
                const Divider(color: Color(0xFF2C2C2E), height: 16),
                _buildDetailRow('Description', (note.isNotEmpty ? note : category).replaceAll(RegExp(r'\s+(expense|income)$', caseSensitive: false), '')),
                const Divider(color: Color(0xFF2C2C2E), height: 16),
                _buildDetailRow('Category', category),
                const Divider(color: Color(0xFF2C2C2E), height: 16),
                _buildDetailRow('Date', DateFormat('d MMMM yyyy, h:mm a').format(date)),
                const Divider(color: Color(0xFF2C2C2E), height: 16),
                _buildDetailRow('Method', paymentMethod),
                const Divider(color: Color(0xFF2C2C2E), height: 16),
                _buildDetailRow(
                  'Type',
                  classification,
                  valueColor: isIncome
                      ? const Color(0xFF30D158)
                      : (classification.toLowerCase() == 'need'
                          ? const Color(0xFF30D158)
                          : const Color(0xFFBF5AF2)),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteTransaction(item['id'], note, amount, isIncome);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Delete Transaction',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFFF453A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 14),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _deleteTransaction(dynamic id, String note, double amount, bool isIncome) {
    final userId = _authState.userId;
    if (userId != null && id != null) {
      ApiService().request('syncData', {
        'userId': userId,
        isIncome ? 'income' : 'expenses': [
          {'id': id, '_action': 'delete'}
        ]
      }).then((_) {
        _fetchDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1C1C1E),
            content: Text(
              'Deleted ${_currencyFormat.format(amount)} for "$note"',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }).catchError((err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF453A),
            content: Text(
              'Failed to delete: $err',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      });
    }
  }

  Widget _buildWalletCardPlaceholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0A84FF)),
        ),
      ),
    );
  }

  Widget _buildActivityListPlaceholder() {
    return Column(
      children: List.generate(
        2,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineErrorSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF453A).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF453A).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off, color: Color(0xFFFF453A), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Offline Mode: Unable to sync with Google Sheet.',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Network request failed. You can still scan or add expenses locally.',
            style: GoogleFonts.outfit(
              color: const Color(0xFFE5E5EA),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _fetchDashboardData,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF0A84FF).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.refresh, color: Color(0xFF0A84FF), size: 14),
              label: Text(
                'Retry Sync',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0A84FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

