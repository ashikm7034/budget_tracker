import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/auth_state.dart';
import '../../core/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AuthState _authState = AuthState();
  NumberFormat get _currencyFormat =>
      NumberFormat.currency(locale: 'en_IN', symbol: _authState.currency, decimalDigits: 0);

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
        return const Color(0xFFFF9F0A); // Apple Orange
      case 'travel':
        return const Color(0xFF0A84FF); // Apple Blue
      case 'snacks':
        return const Color(0xFFBF5AF2); // Apple Purple
      case 'entertainment':
        return const Color(0xFF64D2FF); // Apple Sky Blue
      case 'bills':
        return const Color(0xFFFF453A); // Apple Red
      case 'education':
        return const Color(0xFF30D158); // Apple Green
      case 'shopping':
        return const Color(0xFFFFD60A); // Apple Yellow
      default:
        return const Color(0xFF8E8E93); // Apple Muted Gray
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
      backgroundColor: const Color(0xFF000000), // Apple True Black
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Analytics',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
            )
          : _errorMessage != null
              ? _buildErrorState(_errorMessage!)
              : RefreshIndicator(
                  onRefresh: _fetchExpenses,
                  color: const Color(0xFF0A84FF),
                  backgroundColor: const Color(0xFF1C1C1E),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 100.0),
                children: [
                  // Time Filter Chips Row
                  _buildTimeFilters(),
                  const SizedBox(height: 20),

                  // Total Spent Display Card
                  _buildTotalSpentCard(totalSpent),
                  const SizedBox(height: 20),

                  // Need vs Want Bar Chart Card
                  _buildNeedWantCard(totalSpent, totalNeeds, totalWants, needRatio, wantRatio),
                  const SizedBox(height: 24),

                  // Category Breakdown Header
                  Text(
                    'Category Breakdown',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category progress bars list
                  if (sortedCategories.isEmpty)
                    _buildEmptyBreakdown()
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: List.generate(sortedCategories.length, (index) {
                          final entry = sortedCategories[index];
                          final category = entry.key;
                          final double amount = entry.value;
                          final double percent = totalSpent > 0 ? amount / totalSpent : 0.0;
                          return Column(
                            children: [
                              _buildCategoryRow(category, amount, percent),
                              if (index < sortedCategories.length - 1)
                                const Divider(color: Color(0xFF2C2C2E), height: 24),
                            ],
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTimeFilters() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
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
            color: isActive ? const Color(0xFF2C2C2E) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: isActive ? Colors.white : const Color(0xFF8E8E93),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL EXPENSES',
            style: GoogleFonts.outfit(
              color: const Color(0xFF8E8E93),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currencyFormat.format(amount),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 28,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'NEED VS WANT RATIO',
            style: GoogleFonts.outfit(
              color: const Color(0xFF8E8E93),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Double progress line layout
          Row(
            children: [
              Expanded(
                flex: (needRatio * 100).round().clamp(1, 99),
                child: Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF30D158), // Apple Green
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: (wantRatio * 100).round().clamp(1, 99),
                child: Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF453A), // Apple Red
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
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
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF30D158),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Needs: ${(needRatio * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF453A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Wants: ${(wantRatio * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (hasExpenses) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF2C2C2E), height: 1),
            const SizedBox(height: 12),
            // Smart Advice Block
            Row(
              children: [
                Icon(
                  isWantsHeavy ? Icons.warning_amber_rounded : Icons.thumb_up_alt_outlined,
                  color: isWantsHeavy ? const Color(0xFFFF9F0A) : const Color(0xFF30D158),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isWantsHeavy
                        ? "You're spending more on Wants than Needs. Try deferring some purchases."
                        : "Great job! You are prioritizing your essential Needs.",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF8E8E93),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(catIcon, color: catColor, size: 18),
        ),
        const SizedBox(width: 12),
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
                      color: const Color(0xFF8E8E93),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: const Color(0xFF2C2C2E),
                    valueColor: AlwaysStoppedAnimation<Color>(catColor),
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildEmptyBreakdown() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        'No transactions logged in this timeframe.',
        style: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 13),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF453A), size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load analytics',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
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
}
