import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/auth_state.dart';
import '../../core/api_service.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedSource = 'Salary';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _sources = [
    {'name': 'Salary', 'icon': Icons.work_outline, 'color': Color(0xFF30D158)},
    {'name': 'Pocket Money', 'icon': Icons.family_restroom_outlined, 'color': Color(0xFF0A84FF)},
    {'name': 'Gift', 'icon': Icons.card_giftcard_outlined, 'color': Color(0xFFFF9F0A)},
    {'name': 'Freelance', 'icon': Icons.computer_outlined, 'color': Color(0xFFBF5AF2)},
    {'name': 'Investment', 'icon': Icons.trending_up_outlined, 'color': Color(0xFF30D158)},
    {'name': 'Other', 'icon': Icons.more_horiz_outlined, 'color': Color(0xFF8E8E93)},
  ];

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
              primary: Color(0xFF30D158), // Green accent for income
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

  Future<void> _saveIncome() async {
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
      final incomeId = 'inc_${const Uuid().v4()}';

      final newIncome = {
        'id': incomeId,
        'userId': userId,
        'amount': amount,
        'source': _selectedSource,
        'note': note.isNotEmpty ? note : '$_selectedSource income',
        'date': _selectedDate.toIso8601String(),
      };

      await ApiService().request('syncData', {
        'userId': userId,
        'income': [newIncome],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text(
              'Income logged successfully!',
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
          'Add Income',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF30D158), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveIncome,
              child: Text(
                'Done',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF30D158),
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
                Text(
                  'INCOME DETAILS',
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
                              color: const Color(0xFF30D158),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            labelText: 'Amount',
                            labelStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 14),
                            border: InputBorder.none,
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Source Selector Grid
                Text(
                  'SOURCE',
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
                  itemCount: _sources.length,
                  itemBuilder: (context, index) {
                    final src = _sources[index];
                    final isSelected = _selectedSource == src['name'];
                    final srcColor = src['color'] as Color;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSource = src['name'];
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? srcColor.withOpacity(0.12)
                              : const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? srcColor : const Color(0xFF2C2C2E),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              src['icon'] as IconData,
                              color: isSelected ? srcColor : const Color(0xFF8E8E93),
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              src['name'] as String,
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
                      const CircularProgressIndicator(color: Color(0xFF30D158)),
                      const SizedBox(height: 24),
                      Text(
                        'Logging Income...',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Syncing with Google Sheets',
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
}
