import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/auth_state.dart';
import '../../core/api_service.dart';
import '../expenses/add_expense_screen.dart';

class IncomeTrackerScreen extends StatefulWidget {
  const IncomeTrackerScreen({super.key});

  @override
  State<IncomeTrackerScreen> createState() => _IncomeTrackerScreenState();
}

class _IncomeTrackerScreenState extends State<IncomeTrackerScreen> {
  final AuthState _authState = AuthState();
  NumberFormat get _currencyFormat =>
      NumberFormat.currency(locale: 'en_IN', symbol: _authState.currency, decimalDigits: 0);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _incomeList = [];
  double _totalIncomeSum = 0.0;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchIncomeData();
  }

  Future<void> _fetchIncomeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _authState.userId;
      if (userId == null) throw Exception('No authenticated user session');

      final data = await ApiService().request('getDashboardData', {
        'userId': userId,
      });

      final rawIncome = data['income'] as List? ?? [];
      final summary = data['summary'] ?? {};
      final double totalIncomeVal = (summary['totalIncome'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _incomeList = rawIncome
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        // Sort by date descending
        _incomeList.sort((a, b) {
          final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
        _totalIncomeSum = totalIncomeVal;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  IconData _getSourceIcon(String source) {
    switch (source.toLowerCase()) {
      case 'salary':
        return Icons.work_outline;
      case 'pocket money':
        return Icons.family_restroom_outlined;
      case 'gift':
        return Icons.card_giftcard_outlined;
      case 'freelance':
        return Icons.computer_outlined;
      case 'investment':
        return Icons.trending_up_outlined;
      default:
        return Icons.more_horiz_outlined;
    }
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'salary':
        return const Color(0xFF30D158); // Green
      case 'pocket money':
        return const Color(0xFF0A84FF); // Blue
      case 'gift':
        return const Color(0xFFFF9F0A); // Orange
      case 'freelance':
        return const Color(0xFFBF5AF2); // Purple
      case 'investment':
        return const Color(0xFF30D158); // Green
      default:
        return const Color(0xFF8E8E93); // Gray
    }
  }

  Future<void> _deleteIncome(String incomeId) async {
    final userId = _authState.userId;
    if (userId == null) return;

    final itemIndex = _incomeList.indexWhere((x) => x['id'] == incomeId);
    if (itemIndex == -1) return;
    final backupItem = _incomeList[itemIndex];
    final double amount = (backupItem['amount'] as num?)?.toDouble() ?? 0.0;
    final String source = backupItem['source'] ?? 'Other';

    setState(() {
      _incomeList.removeAt(itemIndex);
      _totalIncomeSum -= amount;
    });

    try {
      await ApiService().request('syncData', {
        'userId': userId,
        'income': [
          {'id': incomeId, '_action': 'delete'}
        ]
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1C1C1E),
            content: Text(
              'Income deleted',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF0A84FF),
              onPressed: () async {
                setState(() {
                  _incomeList.insert(itemIndex, backupItem);
                  _totalIncomeSum += amount;
                });
                await ApiService().request('syncData', {
                  'userId': userId,
                  'income': [backupItem]
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _incomeList.insert(itemIndex, backupItem);
        _totalIncomeSum += amount;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Widget _buildFilterPills() {
    final filters = ['All', 'UPI', 'UPI Lite', 'Cash', 'Card'];
    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 18, bottom: 22),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF30D158)
                      : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF30D158)
                        : const Color(0xFF2C2C2E),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _incomeList.where((item) {
      if (_selectedFilter == 'All') return true;
      return (item['paymentMethod'] ?? 'UPI') == _selectedFilter;
    }).toList();

    double filteredSum = 0.0;
    for (final item in filteredList) {
      filteredSum += (item['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Income Tracker',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF30D158), size: 20),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF30D158), size: 26),
             onPressed: () async {
              final refresh = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddExpenseScreen(isDebit: false)),
              );
              if (refresh == true) {
                _fetchIncomeData();
              }
            },
          ),
        ],
      ),
      body: _isLoading && _incomeList.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF30D158)))
          : RefreshIndicator(
              onRefresh: _fetchIncomeData,
              color: const Color(0xFF30D158),
              backgroundColor: const Color(0xFF1C1C1E),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                children: [
                  // Total Income Header Card
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1A3D22), // Deep forest green
                          Color(0xFF0F2013),
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
                              _selectedFilter == 'All'
                                  ? 'TOTAL LOGGED INCOME'
                                  : 'TOTAL ${_selectedFilter.toUpperCase()} INCOME',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF30D158),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const Icon(Icons.arrow_upward, color: Color(0xFF30D158), size: 20),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _currencyFormat.format(filteredSum),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Horizontal Filter Pills
                  _buildFilterPills(),

                  Text(
                    'INCOME HISTORY',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF8E8E93),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF453A).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.outfit(color: const Color(0xFFFF453A), fontSize: 13),
                      ),
                    ),

                  if (filteredList.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on_outlined, color: Colors.white24, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _selectedFilter == 'All'
                                ? 'No income recorded yet.'
                                : 'No $_selectedFilter income recorded yet.',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF8E8E93),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2C2C2E),
                          width: 0.5,
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredList.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: Color(0xFF2C2C2E),
                          height: 0.5,
                        ),
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          final id = item['id'] ?? '';
                          final source = item['source'] ?? 'Other';
                          final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                          final String note = item['note'] ?? '';
                          final String dateStr = item['date'] ?? '';
                          final date = DateTime.tryParse(dateStr) ?? DateTime.now();

                          final color = _getSourceColor(source);
                          final icon = _getSourceIcon(source);
                          final String paymentMethod = item['paymentMethod'] ?? 'UPI';

                          return Dismissible(
                            key: Key(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: const Color(0xFFFF453A),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20.0),
                              child: const Icon(Icons.delete, color: Colors.white, size: 24),
                            ),
                            onDismissed: (direction) => _deleteIncome(id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          source,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                note.isNotEmpty ? note.replaceAll(RegExp(r'\s+(expense|income)$', caseSensitive: false), '') : source,
                                                style: GoogleFonts.outfit(
                                                  color: const Color(0xFF8E8E93),
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF30D158).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                paymentMethod,
                                                style: GoogleFonts.outfit(
                                                  color: const Color(0xFF30D158),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '+ ${_currencyFormat.format(amount)}',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF30D158),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('d MMM yyyy').format(date),
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF8E8E93),
                                          fontSize: 11,
                                        ),
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
    );
  }
}
