import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/auth_state.dart';
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
            backgroundColor: const Color(0xFF30D158),
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
          'New Goal',
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
              onPressed: _saveGoal,
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
              'SUGGESTIONS',
              style: GoogleFonts.outfit(
                color: const Color(0xFF8E8E93),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((suggestion) {
                return GestureDetector(
                  onTap: () => _applySuggestion(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      suggestion['name'] as String,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            Text(
              'GOAL DETAILS',
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
                    // Goal Name Input
                    TextFormField(
                      controller: _nameController,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Goal Name',
                        labelStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 14),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter goal name';
                        }
                        return null;
                      },
                    ),
                    const Divider(color: Color(0xFF2C2C2E), height: 1),

                    // Target Amount Input
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
                          color: const Color(0xFF0A84FF),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        labelText: 'Target Amount',
                        labelStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 14),
                        border: InputBorder.none,
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
                    const Divider(color: Color(0xFF2C2C2E), height: 1),

                    // Starting Savings Input (Optional)
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
                          color: const Color(0xFF8E8E93),
                          fontSize: 16,
                        ),
                        labelText: 'Starting Savings (Optional)',
                        labelStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 14),
                        border: InputBorder.none,
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
                    const Divider(color: Color(0xFF2C2C2E), height: 1),

                    // Target Date Selector Row
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Target Date',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  DateFormat('d MMMM yyyy').format(_deadline),
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
          ],
        ),
      ),
    );
  }
}
