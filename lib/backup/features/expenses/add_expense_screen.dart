import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../auth/auth_state.dart';
import '../../core/api_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'Tea';
  String _selectedPaymentMethod = 'UPI';
  String _selectedNeedOrWant = 'Want';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Tea', 'icon': Icons.local_cafe_outlined, 'color': Color(0xFFF59E0B)},
    {'name': 'Snacks', 'icon': Icons.fastfood_outlined, 'color': Color(0xFFEF4444)},
    {'name': 'Food', 'icon': Icons.restaurant_outlined, 'color': Color(0xFF10B981)},
    {'name': 'Travel', 'icon': Icons.directions_bus_outlined, 'color': Color(0xFF3B82F6)},
    {'name': 'College', 'icon': Icons.school_outlined, 'color': Color(0xFF8B5CF6)},
    {'name': 'Recharge', 'icon': Icons.bolt_outlined, 'color': Color(0xFFEC4899)},
    {'name': 'Shopping', 'icon': Icons.shopping_bag_outlined, 'color': Color(0xFF06B6D4)},
    {'name': 'Subscription', 'icon': Icons.card_membership_outlined, 'color': Color(0xFF6366F1)},
    {'name': 'Other', 'icon': Icons.more_horiz_outlined, 'color': Color(0xFF64748B)},
  ];

  final List<String> _paymentMethods = ['UPI', 'Cash', 'Card'];

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
      lastDate: DateTime.now().add(const Duration(days: 305)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2DD4BF),
              onPrimary: Color(0xFF0F172A),
              surface: Color(0xFF1E293B),
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
        'needOrWant': 'Want', // Quick logs (tea/snacks/travel) are standard wants/needs
      };

      await ApiService().request('syncData', {
        'userId': userId,
        'expenses': [newExpense]
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              'Quick logged ₹${amount.toStringAsFixed(0)} for $category! ☕',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
        Navigator.of(context).pop(true); // Return true to request parent refresh
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
      final expenseId = 'exp_${const Uuid().v4()}';

      final newExpense = {
        'id': expenseId,
        'userId': userId,
        'amount': amount,
        'category': _selectedCategory,
        'note': note.isNotEmpty ? note : '$_selectedCategory expense',
        'date': _selectedDate.toIso8601String(),
        'paymentMethod': _selectedPaymentMethod,
        'needOrWant': _selectedNeedOrWant,
      };

      await ApiService().request('syncData', {
        'userId': userId,
        'expenses': [newExpense],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              'Expense logged successfully!',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
        Navigator.of(context).pop(true); // Return true to request parent refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Track Expense',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick Add Header
                Text(
                  'QUICK ADD',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Add Buttons Row
                Row(
                  children: [
                    _buildQuickAddButton('☕ Tea', 15, 'Morning tea'),
                    _buildQuickAddButton('🍔 Snacks', 30, 'Samosa & snacks'),
                    _buildQuickAddButton('🚌 Travel', 20, 'Bus fare'),
                  ],
                ),
                const SizedBox(height: 28),

                // Form Details Header
                Text(
                  'EXPENSE DETAILS',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Frosted Card
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Amount Input
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                prefixStyle: GoogleFonts.outfit(
                                  color: const Color(0xFF2DD4BF),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                labelText: 'Amount',
                                labelStyle: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8)),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFF2DD4BF),
                                    width: 2,
                                  ),
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
                            const SizedBox(height: 20),

                            // Note/Description Input
                            TextFormField(
                              controller: _noteController,
                              style: GoogleFonts.outfit(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Note / Description',
                                labelStyle: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8)),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFF2DD4BF),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Date Selection Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Date',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _selectDate(context),
                                  icon: const Icon(Icons.calendar_today,
                                      size: 16, color: Color(0xFF2DD4BF)),
                                  label: Text(
                                    DateFormat('d MMMM yyyy')
                                        .format(_selectedDate),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Need vs Want Selector (Sliding / custom buttons)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Classification',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSegmentButton(
                                          'Need', const Color(0xFF10B981)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSegmentButton(
                                          'Want', const Color(0xFF8B5CF6)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Payment Method Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Payment Method',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: _selectedPaymentMethod,
                                  dropdownColor: const Color(0xFF1E293B),
                                  iconEnabledColor: const Color(0xFF2DD4BF),
                                  underline: Container(),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  items: _paymentMethods
                                      .map<DropdownMenuItem<String>>(
                                          (String val) {
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Category Selection Panel
                Text(
                  'SELECT CATEGORY',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid View of Categories
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat['name'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat['name'];
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (cat['color'] as Color).withOpacity(0.15)
                              : const Color(0xFF1E293B).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? (cat['color'] as Color)
                                : Colors.white.withOpacity(0.04),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              color: isSelected
                                  ? (cat['color'] as Color)
                                  : const Color(0xFF94A3B8),
                              size: 26,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat['name'] as String,
                              style: GoogleFonts.outfit(
                                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),

                // Save Expense Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2DD4BF),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                          ),
                        )
                      : Text(
                          'Save Expense',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButton(String label, double amount, String note) {
    final catName = label.substring(2); // e.g. "Tea" or "Snacks" or "Travel"
    return Expanded(
      child: GestureDetector(
        onTap: _isLoading ? null : () => _quickAdd(catName, amount, note),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2DD4BF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String type, Color selectedColor) {
    final isSelected = _selectedNeedOrWant == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNeedOrWant = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withOpacity(0.15)
              : const Color(0xFF0F172A).withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            type,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
