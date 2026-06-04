import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../auth/auth_state.dart';
import '../../core/api_service.dart';

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _startingController = TextEditingController();

  DateTime _deadline = DateTime.now().add(const Duration(days: 90));
  bool _isLoading = false;

  final List<Map<String, dynamic>> _suggestions = [
    {'name': '🤖 EMO Robot', 'target': 25000},
    {'name': '💻 Laptop', 'target': 60000},
    {'name': '🏍️ Bike', 'target': 80000},
    {'name': '🏥 Emergency Fund', 'target': 10000},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _startingController.dispose();
    super.dispose();
  }

  void _applySuggestion(Map<String, dynamic> suggestion) {
    setState(() {
      _nameController.text = (suggestion['name'] as String).replaceAll(RegExp(r'[^\w\s]'), '').trim();
      _targetController.text = suggestion['target'].toString();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2025).add(const Duration(days: 1095)),
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

    if (picked != null && picked != _deadline) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authState = AuthState();
      final userId = authState.userId;
      if (userId == null) throw Exception('No session found');

      final String name = _nameController.text.trim();
      final double target = double.parse(_targetController.text.trim());
      final double starting = _startingController.text.trim().isEmpty
          ? 0.0
          : double.parse(_startingController.text.trim());
      final String id = 'goal_${const Uuid().v4()}';

      final newGoal = {
        'id': id,
        'userId': userId,
        'goalName': name,
        'targetAmount': target,
        'currentAmount': starting,
        'deadline': _deadline.toIso8601String(),
      };

      await ApiService().request('syncData', {
        'userId': userId,
        'goals': [newGoal],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              'Savings goal created successfully!',
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
          'Create Savings Goal',
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
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'SUGGESTIONS',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions.map((suggestion) {
                    return ActionChip(
                      onPressed: () => _applySuggestion(suggestion),
                      backgroundColor: const Color(0xFF1E293B),
                      side: BorderSide(color: Colors.white.withOpacity(0.04)),
                      label: Text(
                        suggestion['name'] as String,
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                Text(
                  'GOAL DETAILS',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Frosted card form
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
                            // Goal Name
                            TextFormField(
                              controller: _nameController,
                              style: GoogleFonts.outfit(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Goal Name (e.g. Laptop)',
                                labelStyle: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8)),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.1)),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF2DD4BF)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter goal name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Target Amount
                            TextFormField(
                              controller: _targetController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                prefixStyle: GoogleFonts.outfit(
                                  color: const Color(0xFF2DD4BF),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                labelText: 'Target Amount',
                                labelStyle: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8)),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.1)),
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
                                  return 'Please enter target amount';
                                }
                                if (double.tryParse(value) == null ||
                                    double.parse(value) <= 0) {
                                  return 'Enter a valid target amount';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Starting Savings (Optional)
                            TextFormField(
                              controller: _startingController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                prefixStyle: GoogleFonts.outfit(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 16,
                                ),
                                labelText: 'Starting Savings (Optional)',
                                labelStyle: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8)),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.1)),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF2DD4BF)),
                                ),
                              ),
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final double? startVal = double.tryParse(value);
                                  if (startVal == null || startVal < 0) {
                                    return 'Enter a valid starting savings';
                                  }
                                  final double? targetVal =
                                      double.tryParse(_targetController.text);
                                  if (targetVal != null && startVal > targetVal) {
                                    return 'Cannot exceed target amount';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Deadline selector row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Target Date (Deadline)',
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
                                    DateFormat('d MMMM yyyy').format(_deadline),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
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
                ),
                const SizedBox(height: 36),

                // Save Goal Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveGoal,
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
                          'Save Savings Goal',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
