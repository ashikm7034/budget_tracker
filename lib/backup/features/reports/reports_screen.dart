import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../auth/auth_state.dart';
import '../../core/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AuthState _authState = AuthState();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _expenses = [];

  // Filter selection: 0 = This Week, 1 = This Month, 2 = All Time
  int _activeFilter = 1;

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

      final rawExpenses = data['expenses'] as List? ?? [];

      setState(() {
        _expenses = rawExpenses
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredExpenses() {
    final now = DateTime.now();
    DateTime cutoff;

    if (_activeFilter == 0) {
      cutoff = now.subtract(const Duration(days: 7));
    } else if (_activeFilter == 1) {
      cutoff = now.subtract(const Duration(days: 30));
    } else {
      return _expenses; // All Time
    }

    return _expenses.where((exp) {
      final date = DateTime.tryParse(exp['date'] ?? '') ?? now;
      return date.isAfter(cutoff);
    }).toList();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.fastfood_rounded;
      case 'travel':
        return Icons.directions_bus_rounded;
      case 'snacks':
        return Icons.cookie_rounded;
      case 'entertainment':
        return Icons.movie_creation_rounded;
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'education':
        return Icons.menu_book_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFFFBBF24); // Amber
      case 'travel':
        return const Color(0xFF38BDF8); // Sky
      case 'snacks':
        return const Color(0xFFF472B6); // Pink
      case 'entertainment':
        return const Color(0xFFC084FC); // Purple
      case 'bills':
        return const Color(0xFFFB7185); // Rose
      case 'education':
        return const Color(0xFF34D399); // Emerald
      case 'shopping':
        return const Color(0xFFFB923C); // Orange
      default:
        return const Color(0xFF94A3B8); // Muted Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredExpenses();

    // Calculations
    double totalSpent = 0.0;
    double totalNeeds = 0.0;
    double totalWants = 0.0;
    final Map<String, double> categorySums = {};

    for (var exp in filtered) {
      final double amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
      final String category = exp['category'] ?? 'Other';
      final String classification = exp['classification'] ?? 'Need';

      totalSpent += amt;
      categorySums[category] = (categorySums[category] ?? 0.0) + amt;

      if (classification.toLowerCase() == 'need') {
        totalNeeds += amt;
      } else {
        totalWants += amt;
      }
    }

    final double needRatio = totalSpent > 0 ? (totalNeeds / totalSpent) : 0.5;
    final double wantRatio = totalSpent > 0 ? (totalWants / totalSpent) : 0.5;

    // Sort categories by expenditure
    final sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Expense Analytics',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2DD4BF)),
            )
          : RefreshIndicator(
              onRefresh: _fetchExpenses,
              color: const Color(0xFF2DD4BF),
              backgroundColor: const Color(0xFF1E293B),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                children: [
                  // Time Filter Chips Row
                  _buildTimeFilters(),
                  const SizedBox(height: 24),

                  // Total Spent Display Card
                  _buildTotalSpentCard(totalSpent),
                  const SizedBox(height: 24),

                  // Need vs Want Bar Chart Card
                  _buildNeedWantCard(totalSpent, totalNeeds, totalWants, needRatio, wantRatio),
                  const SizedBox(height: 24),

                  // Category Breakdown Header
                  Text(
                    'Category-wise Breakdown',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category progress bars list
                  if (sortedCategories.isEmpty)
                    _buildEmptyBreakdown()
                  else
                    ...sortedCategories.map((entry) {
                      final category = entry.key;
                      final double amount = entry.value;
                      final double percent = totalSpent > 0 ? amount / totalSpent : 0.0;
                      return _buildCategoryRow(category, amount, percent);
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildTimeFilters() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildFilterChip(0, 'This Week'),
          _buildFilterChip(1, 'This Month'),
          _buildFilterChip(2, 'All Time'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isActive = _activeFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeFilter = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2DD4BF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalSpentCard(double amount) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL EXPENSES',
            style: GoogleFonts.outfit(
              color: const Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(amount),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedWantCard(double total, double needs, double wants, double needRatio, double wantRatio) {
    final hasExpenses = total > 0;
    final isWantsHeavy = wantRatio > 0.5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'NEED VS WANT RATIO',
            style: GoogleFonts.outfit(
              color: const Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),

          // Double filled progress layout
          Row(
            children: [
              Expanded(
                flex: (needRatio * 100).round().clamp(1, 99),
                child: Container(
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34D399), // Emerald for Needs
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: (wantRatio * 100).round().clamp(1, 99),
                child: Container(
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFB7185), // Rose Red for Wants
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF34D399),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Needs: ${(needRatio * 100).toStringAsFixed(0)}% (${_currencyFormat.format(needs)})',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFB7185),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Wants: ${(wantRatio * 100).toStringAsFixed(0)}% (${_currencyFormat.format(wants)})',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (hasExpenses) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),
            // Smart Advice Block
            Row(
              children: [
                Icon(
                  isWantsHeavy ? Icons.warning_amber_rounded : Icons.thumb_up_alt_outlined,
                  color: isWantsHeavy ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isWantsHeavy
                        ? "You're spending more on Wants than Needs. Try deferring some purchases to save more!"
                        : "Great job! You are prioritizing your essential Needs. Keep it up to build healthy savings.",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            )
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String category, double amount, double percentage) {
    final catColor = _getCategoryColor(category);
    final catIcon = _getCategoryIcon(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(catIcon, color: catColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_currencyFormat.format(amount)} (${(percentage * 100).toStringAsFixed(0)}%)',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Horizontal category bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.white.withOpacity(0.04),
                      valueColor: AlwaysStoppedAnimation<Color>(catColor),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyBreakdown() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        'No transactions logged in this timeframe.',
        style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
      ),
    );
  }
}
