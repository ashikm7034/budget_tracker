import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/auth_state.dart';
import '../../core/api_service.dart';
import 'add_goal_screen.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final AuthState _authState = AuthState();
  NumberFormat get _currencyFormat =>
      NumberFormat.currency(locale: 'en_IN', symbol: _authState.currency, decimalDigits: 0);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _goals = [];

  @override
  void initState() {
    super.initState();
    _fetchGoals();
  }

  Future<void> _fetchGoals() async {
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

      final rawGoals = data['goals'] as List? ?? [];

      setState(() {
        _goals = rawGoals
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

  Future<void> _deleteGoal(String id) async {
    final userId = _authState.userId;
    if (userId == null) return;

    final index = _goals.indexWhere((x) => x['id'] == id);
    if (index == -1) return;

    final backup = _goals[index];
    setState(() {
      _goals.removeAt(index);
    });

    try {
      await ApiService().request('syncData', {
        'userId': userId,
        'goals': [
          {'id': id, '_action': 'delete'}
        ]
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1C1C1E),
            content: Text(
              'Savings goal deleted',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF0A84FF),
              onPressed: () async {
                setState(() {
                  _goals.insert(index, backup);
                });
                await ApiService().request('syncData', {
                  'userId': userId,
                  'goals': [backup]
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _goals.insert(index, backup);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _depositSavings(Map<String, dynamic> item, double depositAmount) async {
    final userId = _authState.userId;
    if (userId == null) return;

    final double current = (item['currentAmount'] as num?)?.toDouble() ?? 0.0;
    final double newCurrent = current + depositAmount;

    setState(() {
      item['currentAmount'] = newCurrent;
    });

    try {
      final syncItem = Map<String, dynamic>.from(item)..['currentAmount'] = newCurrent;
      await ApiService().request('syncData', {
        'userId': userId,
        'goals': [syncItem]
      });
      _fetchGoals();
    } catch (e) {
      setState(() {
        item['currentAmount'] = current;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save deposit: $e')),
        );
      }
    }
  }

  void _showDepositDialog(Map<String, dynamic> item) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Savings',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Deposit savings to "${item['goalName']}"',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF8E8E93),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '${_authState.currency} ',
                    prefixStyle: GoogleFonts.outfit(
                      color: const Color(0xFF0A84FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    labelText: 'Deposit Amount',
                    labelStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF0A84FF)),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter deposit amount';
                    final numVal = double.tryParse(val);
                    if (numVal == null || numVal <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: const Color(0xFF8E8E93)),
              ),
            ),
            TextButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final double amt = double.parse(controller.text.trim());
                _depositSavings(item, amt);
                Navigator.pop(context);
              },
              child: Text(
                'Deposit',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0A84FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getGoalIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('robot') || lowerName.contains('emo')) {
      return Icons.smart_toy_rounded;
    } else if (lowerName.contains('laptop') || lowerName.contains('computer')) {
      return Icons.laptop_chromebook;
    } else if (lowerName.contains('bike') || lowerName.contains('cycle') || lowerName.contains('scoot')) {
      return Icons.motorcycle_rounded;
    } else if (lowerName.contains('emergency') || lowerName.contains('fund') || lowerName.contains('hospital')) {
      return Icons.health_and_safety_rounded;
    }
    return Icons.stars_rounded;
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
          'Savings Goals',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF0A84FF), size: 28),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddGoalScreen()),
              );
              if (result == true) {
                _fetchGoals();
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
            )
          : RefreshIndicator(
              onRefresh: _fetchGoals,
              color: const Color(0xFF0A84FF),
              backgroundColor: const Color(0xFF1C1C1E),
              child: _buildGoalsList(),
            ),
    );
  }

  Widget _buildGoalsList() {
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (_goals.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 100.0),
      itemCount: _goals.length,
      itemBuilder: (context, index) {
        final item = _goals[index];
        final String id = item['id'] ?? '';
        final String name = item['goalName'] ?? 'Goal';
        final double current = (item['currentAmount'] as num?)?.toDouble() ?? 0.0;
        final double target = (item['targetAmount'] as num?)?.toDouble() ?? 0.0;
        final String deadlineStr = item['deadline'] ?? '';

        final deadline = DateTime.tryParse(deadlineStr) ?? DateTime.now();
        final daysRemaining = deadline.difference(DateTime.now()).inDays;

        double progress = 0.0;
        if (target > 0) {
          progress = (current / target).clamp(0.0, 1.0);
        }
        final isCompleted = progress >= 1.0;

        return Dismissible(
          key: Key(id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24.0),
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: const Color(0xFFFF453A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 24),
          ),
          onDismissed: (_) => _deleteGoal(id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted
                    ? const Color(0xFF30D158).withOpacity(0.3)
                    : const Color(0xFF2C2C2E),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF30D158).withOpacity(0.12)
                            : const Color(0xFF0A84FF).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getGoalIcon(name),
                        color: isCompleted
                            ? const Color(0xFF30D158)
                            : const Color(0xFF0A84FF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF30D158).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.emoji_events, color: Color(0xFF30D158), size: 10),
                                      const SizedBox(width: 3),
                                      Text(
                                        'SAVED',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF30D158),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isCompleted
                                ? 'Goal Achieved! 🎉'
                                : (daysRemaining > 0
                                    ? '$daysRemaining days left (Due ${DateFormat('d MMM yyyy').format(deadline)})'
                                    : 'Target date passed'),
                            style: GoogleFonts.outfit(
                              color: isCompleted
                                  ? const Color(0xFF30D158)
                                  : const Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAVED SO FAR',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF8E8E93),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _currencyFormat.format(current),
                          style: GoogleFonts.outfit(
                            color: isCompleted ? const Color(0xFF30D158) : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TARGET GOAL',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF8E8E93),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _currencyFormat.format(target),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFF2C2C2E),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted
                                  ? const Color(0xFF30D158)
                                  : const Color(0xFF0A84FF),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.outfit(
                        color: isCompleted ? const Color(0xFF30D158) : const Color(0xFF0A84FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF2C2C2E), height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => _showDepositDialog(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A84FF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add, color: Color(0xFF0A84FF), size: 13),
                              const SizedBox(width: 4),
                              Text(
                                'ADD SAVINGS',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF0A84FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings_outlined, color: Color(0xFF0A84FF), size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'No Savings Goals Logged',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button in the top right to create a goal for your next big purchase.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF8E8E93),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
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
              'Failed to load goals',
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
