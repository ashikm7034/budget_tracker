import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/auth_state.dart';
import '../../core/api_service.dart';
import 'add_expense_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  final String? initialPaymentMethodFilter;
  const ExpenseListScreen({super.key, this.initialPaymentMethodFilter});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final AuthState _authState = AuthState();
  NumberFormat get _currencyFormat =>
      NumberFormat.currency(locale: 'en_IN', symbol: _authState.currency, decimalDigits: 0);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _expenses = [];

  final Map<String, Map<String, dynamic>> _catMeta = {
    'Tea': {'icon': Icons.local_cafe_outlined, 'color': Color(0xFFFF9F0A)},
    'Snacks': {'icon': Icons.fastfood_outlined, 'color': Color(0xFFFF453A)},
    'Food': {'icon': Icons.restaurant_outlined, 'color': Color(0xFF30D158)},
    'Travel': {'icon': Icons.directions_car_outlined, 'color': Color(0xFF64D2FF)},
    'College': {'icon': Icons.school_outlined, 'color': Color(0xFFBF5AF2)},
    'Recharge': {'icon': Icons.bolt_outlined, 'color': Color(0xFFFF375F)},
    'Shopping': {'icon': Icons.local_mall_outlined, 'color': Color(0xFFFF9F0A)},
    'Subscription': {'icon': Icons.card_membership_outlined, 'color': Color(0xFF5E5CE6)},
    'Transfer': {'icon': Icons.swap_horiz_outlined, 'color': Color(0xFF0A84FF)},
    'Other': {'icon': Icons.more_horiz_outlined, 'color': Color(0xFF8E8E93)},
  };

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
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

      final rawList = data['expenses'] as List? ?? [];
      final List<Map<String, dynamic>> typedExpenses = rawList
          .map((item) => Map<String, dynamic>.from(item as Map)..['isIncome'] = false)
          .toList();

      final rawIncome = data['income'] as List? ?? [];
      final List<Map<String, dynamic>> typedIncome = rawIncome
          .map((item) => Map<String, dynamic>.from(item as Map)
            ..['isIncome'] = true
            ..['category'] = item['source'] ?? 'Income')
          .toList();

      List<Map<String, dynamic>> typedList = [...typedExpenses, ...typedIncome];

      if (widget.initialPaymentMethodFilter != null) {
        typedList = typedList.where((x) => x['paymentMethod'] == widget.initialPaymentMethodFilter).toList();
      }

      // Sort chronological descending (newest first)
      typedList.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2025);
        final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2025);
        return dateB.compareTo(dateA);
      });

      setState(() {
        _expenses = typedList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    final userId = _authState.userId;
    if (userId == null) return;

    final itemIndex = _expenses.indexWhere((x) => x['id'] == expenseId);
    if (itemIndex == -1) return;
    final backupItem = _expenses[itemIndex];
    final bool isIncome = backupItem['isIncome'] == true;

    setState(() {
      _expenses.removeAt(itemIndex);
    });

    try {
      await ApiService().request('syncData', {
        'userId': userId,
        isIncome ? 'income' : 'expenses': [
          {'id': expenseId, '_action': 'delete'}
        ]
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1C1C1E),
            content: Text(
              isIncome ? 'Income deleted' : 'Expense deleted',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF0A84FF),
              onPressed: () async {
                setState(() {
                  _expenses.insert(itemIndex, backupItem);
                });
                await ApiService().request('syncData', {
                  'userId': userId,
                  isIncome ? 'income' : 'expenses': [backupItem]
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _expenses.insert(itemIndex, backupItem);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupExpenses() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final exp in _expenses) {
      final dateStr = exp['date'] as String? ?? '';
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterdayStr = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(const Duration(days: 1)));
      final formattedCompare = DateFormat('yyyy-MM-dd').format(parsedDate);

      String headerKey;
      if (formattedCompare == todayStr) {
        headerKey = 'Today';
      } else if (formattedCompare == yesterdayStr) {
        headerKey = 'Yesterday';
      } else {
        headerKey = DateFormat('EEEE, d MMMM yyyy').format(parsedDate);
      }

      grouped.putIfAbsent(headerKey, () => []).add(exp);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupExpenses();
    final headers = grouped.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Apple True Black
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.initialPaymentMethodFilter != null
              ? '${widget.initialPaymentMethodFilter} History'
              : 'Expenses',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0A84FF), size: 20), // Apple Back Chevron
          onPressed: () => Navigator.of(context).pop(true),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF0A84FF), size: 28),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
              );
              if (result == true) {
                _fetchExpenses();
              }
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchExpenses,
        color: const Color(0xFF0A84FF),
        backgroundColor: const Color(0xFF1C1C1E),
        child: _buildListContent(headers, grouped),
      ),
    );
  }

  Widget _buildListContent(
      List<String> headers, Map<String, List<Map<String, dynamic>>> grouped) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
      );
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFFF453A), size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load expenses',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF8E8E93),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_expenses.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF0A84FF),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Expenses Logged Yet',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button in the top right to track your first purchase.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF8E8E93),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      itemCount: headers.length,
      itemBuilder: (context, headerIndex) {
        final header = headers[headerIndex];
        final items = grouped[header] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 18.0, bottom: 8.0, left: 4.0),
              child: Text(
                header.toUpperCase(),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF8E8E93),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E), // iOS Grouped Card
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(
                  color: Color(0xFF2C2C2E),
                  height: 0.5,
                  thickness: 0.5,
                  indent: 52,
                ),
                itemBuilder: (context, itemIndex) {
                  final item = items[itemIndex];
                  return _buildDismissibleItem(item);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDismissibleItem(Map<String, dynamic> item) {
    final String id = item['id'] ?? '';
    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        decoration: const BoxDecoration(
          color: Color(0xFFFF453A), // Apple iOS Red
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 24),
      ),
      onDismissed: (direction) => _deleteExpense(id),
      child: _buildExpenseRow(item),
    );
  }

  Widget _buildExpenseRow(Map<String, dynamic> item) {
    final bool isIncome = item['isIncome'] == true;
    final String catName = item['category'] ?? 'Other';
    final String note = item['note'] ?? '';
    final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final String needOrWant = item['needOrWant'] ?? 'Want';
    final String method = item['paymentMethod'] ?? 'UPI';

    final meta = isIncome
        ? {'icon': Icons.arrow_downward_rounded, 'color': const Color(0xFF30D158)}
        : (_catMeta[catName] ?? _catMeta['Other']!);
    final Color catColor = meta['color'] as Color;
    final IconData catIcon = meta['icon'] as IconData;

    final isNeed = needOrWant.toLowerCase() == 'need';
    final badgeColor = isIncome
        ? const Color(0xFF30D158)
        : (isNeed ? const Color(0xFF30D158) : const Color(0xFFBF5AF2));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          // Category Circle Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(catIcon, color: catColor, size: 18),
          ),
          const SizedBox(width: 14),

          // Title & Meta details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (note.isNotEmpty ? note : catName).replaceAll(RegExp(r'\s+(expense|income)$', caseSensitive: false), ''),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      catName,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF8E8E93),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: Color(0xFF38383A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      method,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF8E8E93),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Amount & Classification Tag
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isIncome ? '+ ${_currencyFormat.format(amount)}' : '- ${_currencyFormat.format(amount)}',
                style: GoogleFonts.outfit(
                  color: isIncome ? const Color(0xFF30D158) : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isIncome ? 'INCOME' : needOrWant.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward_ios,
            color: Color(0xFF2C2C2E),
            size: 11,
          ),
        ],
      ),
    );
  }
}
