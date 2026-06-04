import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/auth_state.dart';
import '../../core/api_service.dart';
import '../../core/widgets/apple_widgets.dart';
import '../income/income_tracker_screen.dart';
import 'expense_list_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  final bool isDebit;
  const AddExpenseScreen({super.key, this.isDebit = true});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isDebit = true; // True for Debit (Expense), False for Credit (Income)
  String _selectedCategory = 'Tea';
  String _selectedPaymentMethod = 'UPI';
  String _selectedNeedOrWant = 'Want';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _expenseCategories = [
    {'name': 'Tea', 'icon': Icons.local_cafe_outlined, 'color': Color(0xFFFF9F0A)},
    {'name': 'Snacks', 'icon': Icons.fastfood_outlined, 'color': Color(0xFFFF2D55)},
    {'name': 'Food', 'icon': Icons.restaurant_outlined, 'color': Color(0xFF30D158)},
    {'name': 'Travel', 'icon': Icons.directions_car_outlined, 'color': Color(0xFF64D2FF)},
    {'name': 'College', 'icon': Icons.school_outlined, 'color': Color(0xFFBF5AF2)},
    {'name': 'Recharge', 'icon': Icons.bolt_outlined, 'color': Color(0xFFFF375F)},
    {'name': 'Shopping', 'icon': Icons.local_mall_outlined, 'color': Color(0xFFFF9F0A)},
    {'name': 'Subscription', 'icon': Icons.card_membership_outlined, 'color': Color(0xFF5E5CE6)},
    {'name': 'Other', 'icon': Icons.more_horiz_outlined, 'color': Color(0xFF8E8E93)},
  ];

  final List<Map<String, dynamic>> _incomeCategories = [
    {'name': 'Salary', 'icon': Icons.work_outline, 'color': Color(0xFF30D158)},
    {'name': 'Pocket Money', 'icon': Icons.family_restroom_outlined, 'color': Color(0xFF0A84FF)},
    {'name': 'Gift', 'icon': Icons.card_giftcard_outlined, 'color': Color(0xFFFF9F0A)},
    {'name': 'Freelance', 'icon': Icons.computer_outlined, 'color': Color(0xFFBF5AF2)},
    {'name': 'Investment', 'icon': Icons.trending_up_outlined, 'color': Color(0xFF30D158)},
    {'name': 'Other', 'icon': Icons.more_horiz_outlined, 'color': Color(0xFF8E8E93)},
  ];

  List<Map<String, dynamic>> get _categories => _isDebit ? _expenseCategories : _incomeCategories;

  final List<String> _paymentMethods = ['UPI', 'UPI Lite', 'Cash', 'Card'];

  void _toggleType(bool isDebit) {
    setState(() {
      _isDebit = isDebit;
      _selectedCategory = isDebit ? 'Tea' : 'Salary';
    });
  }

  @override
  void initState() {
    super.initState();
    _isDebit = widget.isDebit;
    _selectedCategory = _isDebit ? 'Tea' : 'Salary';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF0A84FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _quickAdd(String category, double amount, String note) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authState = AuthState();
      final userId = authState.userId;
      if (userId == null) throw Exception('No session found');

      final expenseId = 'exp_${const Uuid().v4()}';
      final newExpense = {
        'id': expenseId,
        'userId': userId,
        'amount': amount,
        'category': category,
        'note': note,
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': 'UPI',
        'needOrWant': 'Want',
      };

      await ApiService().request('syncData', {
        'userId': userId,
        'expenses': [newExpense]
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text(
              'Quick logged ${authState.currency}${amount.toStringAsFixed(0)} for $category! ☕',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
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

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authState = AuthState();
      final userId = authState.userId;
      if (userId == null) throw Exception('No session found');

      final double amount = double.parse(_amountController.text.trim());
      final String note = _noteController.text.trim();

      if (_isDebit) {
        final expenseId = 'exp_${const Uuid().v4()}';
        final newExpense = {
          'id': expenseId,
          'userId': userId,
          'amount': amount,
          'category': _selectedCategory,
          'note': note.isNotEmpty ? note : _selectedCategory,
          'date': _selectedDate.toIso8601String(),
          'paymentMethod': _selectedPaymentMethod,
          'needOrWant': _selectedNeedOrWant,
        };

        await ApiService().request('syncData', {
          'userId': userId,
          'expenses': [newExpense],
        });
      } else {
        final incomeId = 'inc_${const Uuid().v4()}';
        final newIncome = {
          'id': incomeId,
          'userId': userId,
          'amount': amount,
          'source': _selectedCategory,
          'note': note.isNotEmpty ? note : _selectedCategory,
          'date': _selectedDate.toIso8601String(),
          'paymentMethod': _selectedPaymentMethod,
        };

        await ApiService().request('syncData', {
          'userId': userId,
          'income': [newIncome],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text(
              _isDebit ? 'Expense logged successfully!' : 'Income logged successfully!',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF453A),
            content: Text('Failed to save: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Apple True Black
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _isDebit ? 'Track Expense' : 'Add Income',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _isDebit ? const Color(0xFF0A84FF) : const Color(0xFF30D158), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveExpense,
              child: Text(
                'Done',
                style: GoogleFonts.outfit(
                  color: _isDebit ? const Color(0xFF0A84FF) : const Color(0xFF30D158),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Credit / Debit Segment Toggle
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleType(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isDebit ? const Color(0xFFFF453A) : Colors.transparent, // Red for Debit (Expense)
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Debit (Expense)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: _isDebit ? Colors.white : const Color(0xFF8E8E93),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleType(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isDebit ? const Color(0xFF30D158) : Colors.transparent, // Green for Credit (Income)
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Credit (Income)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: !_isDebit ? Colors.white : const Color(0xFF8E8E93),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!_isDebit) ...[
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const IncomeTrackerScreen()),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF30D158).withOpacity(0.18), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF30D158).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_rounded, color: Color(0xFF30D158), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Income Tracker & History',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mistakenly added income? View & delete past income here.',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF8E8E93),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF8E8E93), size: 12),
                    ],
                  ),
                ),
              ),
            ],

            // Form Inputs Grouped iOS-style
            Text(
              _isDebit ? 'EXPENSE DETAILS' : 'INCOME DETAILS',
              style: GoogleFonts.outfit(
                color: const Color(0xFF8E8E93),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Amount Input Row
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        prefixText: '${AuthState().currency} ',
                        prefixStyle: GoogleFonts.outfit(
                          color: _isDebit ? const Color(0xFF0A84FF) : const Color(0xFF30D158),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        labelText: 'Amount',
                        labelStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 14),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calculate_outlined, color: Color(0xFF8E8E93)),
                          onPressed: () async {
                            final result = await showModalBottomSheet<String>(
                              context: context,
                              backgroundColor: const Color(0xFF1C1C1E),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              isScrollControlled: true,
                              builder: (context) => ExpenseCalculatorSheet(
                                initialValue: _amountController.text,
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                _amountController.text = result;
                              });
                            }
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter amount';
                        }
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const Divider(color: Color(0xFF2C2C2E), height: 1),

                    // Note Input Row
                    TextFormField(
                      controller: _noteController,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(color: Color(0xFF2C2C2E), height: 1),

                    // Date Select Row
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Date',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  DateFormat('d MMMM yyyy').format(_selectedDate),
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF8E8E93),
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFF2C2C2E),
                                  size: 13,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: Color(0xFF2C2C2E), height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Method',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          DropdownButton<String>(
                            value: _selectedPaymentMethod,
                            dropdownColor: const Color(0xFF1C1C1E),
                            iconEnabledColor: const Color(0xFF8E8E93),
                            underline: Container(),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            items: _paymentMethods.map<DropdownMenuItem<String>>((String val) {
                              return DropdownMenuItem<String>(
                                value: val,
                                child: Text(val),
                              );
                            }).toList(),
                            onChanged: (String? newVal) {
                              if (newVal != null) {
                                  setState(() {
                                    _selectedPaymentMethod = newVal;
                                  });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Selector Grid
            Text(
              'CATEGORY',
              style: GoogleFonts.outfit(
                color: const Color(0xFF8E8E93),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['name'];
                final catColor = cat['color'] as Color;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat['name'];
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catColor.withOpacity(0.12)
                          : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? catColor : const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          color: isSelected ? catColor : const Color(0xFF8E8E93),
                          size: 22,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat['name'] as String,
                          style: GoogleFonts.outfit(
                            color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      if (_isLoading)
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.75),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF0A84FF)),
                  const SizedBox(height: 24),
                  Text(
                    'Saving to Google Sheets...',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Updating your budget tracker',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF8E8E93),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildQuickAddButton(String label, double amount, String note) {
    final catName = label.substring(2);
    return Expanded(
      child: GestureDetector(
        onTap: _isLoading ? null : () => _quickAdd(catName, amount, note),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2C2C2E),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${AuthState().currency}${amount.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0A84FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentItem(String type, Color selectedColor) {
    final isSelected = _selectedNeedOrWant == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNeedOrWant = type;
        });
      },
      child: Container(
        width: 70,
        height: 30,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C1C1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            type,
            style: GoogleFonts.outfit(
              color: isSelected ? selectedColor : const Color(0xFF8E8E93),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
