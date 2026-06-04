import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../auth/auth_state.dart';
import '../../core/api_service.dart';
import 'add_expense_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final AuthState _authState = AuthState();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _expenses = [];

  final Map<String, Map<String, dynamic>> _catMeta = {
    'Tea': {'icon': Icons.local_cafe_outlined, 'color': Color(0xFFF59E0B)},
    'Snacks': {'icon': Icons.fastfood_outlined, 'color': Color(0xFFEF4444)},
    'Food': {'icon': Icons.restaurant_outlined, 'color': Color(0xFF10B981)},
    'Travel': {'icon': Icons.directions_bus_outlined, 'color': Color(0xFF3B82F6)},
    'College': {'icon': Icons.school_outlined, 'color': Color(0xFF8B5CF6)},
    'Recharge': {'icon': Icons.bolt_outlined, 'color': Color(0xFFEC4899)},
    'Shopping': {'icon': Icons.shopping_bag_outlined, 'color': Color(0xFF06B6D4)},
    'Subscription': {'icon': Icons.card_membership_outlined, 'color': Color(0xFF6366F1)},
    'Other': {'icon': Icons.more_horiz_outlined, 'color': Color(0xFF64748B)},
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
      final List<Map<String, dynamic>> typedList = rawList
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

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

    // Store a backup for potential undo action
    final itemIndex = _expenses.indexWhere((x) => x['id'] == expenseId);
    if (itemIndex == -1) return;
    final backupItem = _expenses[itemIndex];

    // Optimistically remove from state list
    setState(() {
      _expenses.removeAt(itemIndex);
    });

    try {
      await ApiService().request('syncData', {
        'userId': userId,
        'expenses': [
          {'id': expenseId, '_action': 'delete'}
        ]
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text(
              'Expense deleted',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF2DD4BF),
              onPressed: () async {
                // Reinsert item to backend
                setState(() {
                  _expenses.insert(itemIndex, backupItem);
                });
                await ApiService().request('syncData', {
                  'userId': userId,
                  'expenses': [backupItem]
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Revert optimism if delete failed
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

  // Groups expenses by date header
  Map<String, List<Map<String, dynamic>>> _groupExpenses() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final exp in _expenses) {
      final dateStr = exp['date'] as String? ?? '';
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

      // Calculate Header String
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Expenses',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(true), // Return true to refresh parent
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _fetchExpenses,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchExpenses,
        color: const Color(0xFF2DD4BF),
        backgroundColor: const Color(0xFF1E293B),
        child: _buildListContent(headers, grouped),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
          if (result == true) {
            _fetchExpenses();
          }
        },
        backgroundColor: const Color(0xFF2DD4BF),
        foregroundColor: const Color(0xFF0F172A),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildListContent(
      List<String> headers, Map<String, List<Map<String, dynamic>>> grouped) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2DD4BF)),
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
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
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
                  color: const Color(0xFF94A3B8),
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
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF2DD4BF),
                    size: 64,
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
                  'Tap the + button below to track your first purchase.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
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
              padding: const EdgeInsets.only(top: 18.0, bottom: 10.0, left: 4.0),
              child: Text(
                header.toUpperCase(),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2DD4BF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ...items.map((item) => _buildDismissibleItem(item)),
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
        margin: const EdgeInsets.only(bottom: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) => _deleteExpense(id),
      child: _buildExpenseCard(item),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> item) {
    final String catName = item['category'] ?? 'Other';
    final String note = item['note'] ?? '';
    final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final String needOrWant = item['needOrWant'] ?? 'Want';
    final String method = item['paymentMethod'] ?? 'UPI';

    final meta = _catMeta[catName] ?? _catMeta['Other']!;
    final Color catColor = meta['color'] as Color;
    final IconData catIcon = meta['icon'] as IconData;

    final isNeed = needOrWant.toLowerCase() == 'need';
    final badgeColor = isNeed ? const Color(0xFF10B981) : const Color(0xFF8B5CF6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(catIcon, color: catColor, size: 20),
                ),
                const SizedBox(width: 16),

                // Note & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.isNotEmpty ? note : catName,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            catName,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'via $method',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount & Badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '- ${_currencyFormat.format(amount)}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFF87171),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Classification Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: badgeColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        needOrWant.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
