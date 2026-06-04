import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/auth_state.dart';
import '../../core/api_service.dart';

class AddBorrowedScreen extends StatefulWidget {
  const AddBorrowedScreen({super.key});

  @override
  State<AddBorrowedScreen> createState() => _AddBorrowedScreenState();
}

class _AddBorrowedScreenState extends State<AddBorrowedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lenderController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _borrowDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isLoading = false;

  @override
  void dispose() {
    _lenderController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isBorrowDate) async {
    final DateTime initial = isBorrowDate ? _borrowDate : _dueDate;
    final DateTime first = isBorrowDate ? DateTime(2025) : _borrowDate;
    final DateTime last = DateTime(2025).add(const Duration(days: 1095));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
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

    if (picked != null) {
      setState(() {
        if (isBorrowDate) {
          _borrowDate = picked;
          if (_dueDate.isBefore(_borrowDate)) {
            _dueDate = _borrowDate.add(const Duration(days: 1));
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _saveBorrowed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authState = AuthState();
      final userId = authState.userId;
      if (userId == null) throw Exception('No session found');

      final String lender = _lenderController.text.trim();
      final double amount = double.parse(_amountController.text.trim());
      final String id = 'bor_${const Uuid().v4()}';

      final newBorrowed = {
        'id': id,
        'userId': userId,
        'personName': lender,
        'amount': amount,
        'borrowDate': _borrowDate.toIso8601String(),
        'dueDate': _dueDate.toIso8601String(),
        'status': 'Pending',
      };

      await ApiService().request('syncData', {
        'userId': userId,
        'borrowed': [newBorrowed],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF30D158),
            content: Text(
              'Borrowed debt logged successfully!',
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
          'Log Borrowed',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0A84FF), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveBorrowed,
              child: Text(
                'Done',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0A84FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DEBT DETAILS',
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
                    // Lender Name Input
                    TextFormField(
                      controller: _lenderController,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Lender Name',
                        labelStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 14),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter lender name';
                        }
                        return null;
                      },
                    ),
                    const Divider(color: Color(0xFF2C2C2E), height: 1),

                    // Amount Input
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: GoogleFonts.outfit(
                          color: const Color(0xFF0A84FF),
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

                    // Borrow Date Selector Row
                    InkWell(
                      onTap: () => _selectDate(context, true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Borrow Date',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  DateFormat('d MMMM yyyy').format(_borrowDate),
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

                    // Due Date Selector Row
                    InkWell(
                      onTap: () => _selectDate(context, false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Due Date',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  DateFormat('d MMMM yyyy').format(_dueDate),
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFFF453A),
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
          ],
        ),
      ),
    );
  }
}
