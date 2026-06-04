import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/auth_state.dart';
import '../../core/api_service.dart';
import 'add_borrowed_screen.dart';
import 'add_receivable_screen.dart';

class DebtsScreen extends StatefulWidget {
  final int initialTabIndex;
  const DebtsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthState _authState = AuthState();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _borrowed = [];
  List<Map<String, dynamic>> _receivables = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      setState(() {}); // Rebuild FAB based on active tab
    });
    _fetchDues();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDues() async {
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

      final rawBorrowed = data['borrowed'] as List? ?? [];
      final rawReceivables = data['receivables'] as List? ?? [];

      setState(() {
        _borrowed = rawBorrowed
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _receivables = rawReceivables
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

  Future<void> _toggleBorrowedRepaid(Map<String, dynamic> item) async {
    final userId = _authState.userId;
    if (userId == null) return;

    final String oldStatus = item['status'] ?? 'Pending';
    final String newStatus = oldStatus == 'Pending' ? 'Repaid' : 'Pending';

    setState(() {
      item['status'] = newStatus;
    });

    try {
      final syncItem = Map<String, dynamic>.from(item)..['status'] = newStatus;
      await ApiService().request('syncData', {
        'userId': userId,
        'borrowed': [syncItem]
      });
      _fetchDues();
    } catch (e) {
      setState(() {
        item['status'] = oldStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteBorrowed(String id) async {
    final userId = _authState.userId;
    if (userId == null) return;

    final index = _borrowed.indexWhere((x) => x['id'] == id);
    if (index == -1) return;

    final backup = _borrowed[index];
    setState(() {
      _borrowed.removeAt(index);
    });

    try {
      await ApiService().request('syncData', {
        'userId': userId,
        'borrowed': [
          {'id': id, '_action': 'delete'}
        ]
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text(
              'Borrowed record deleted',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF2DD4BF),
              onPressed: () async {
                setState(() {
                  _borrowed.insert(index, backup);
                });
                await ApiService().request('syncData', {
                  'userId': userId,
                  'borrowed': [backup]
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _borrowed.insert(index, backup);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _toggleReceivablePaid(Map<String, dynamic> item) async {
    final userId = _authState.userId;
    if (userId == null) return;

    final String oldStatus = item['status'] ?? 'Pending';
    final String newStatus = oldStatus == 'Pending' ? 'Repaid' : 'Pending';

    setState(() {
      item['status'] = newStatus;
    });

    try {
      final syncItem = Map<String, dynamic>.from(item)..['status'] = newStatus;
      await ApiService().request('syncData', {
        'userId': userId,
        'receivables': [syncItem]
      });
      _fetchDues();
    } catch (e) {
      setState(() {
        item['status'] = oldStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteReceivable(String id) async {
    final userId = _authState.userId;
    if (userId == null) return;

    final index = _receivables.indexWhere((x) => x['id'] == id);
    if (index == -1) return;

    final backup = _receivables[index];
    setState(() {
      _receivables.removeAt(index);
    });

    try {
      await ApiService().request('syncData', {
        'userId': userId,
        'receivables': [
          {'id': id, '_action': 'delete'}
        ]
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text(
              'Receivable record deleted',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF2DD4BF),
              onPressed: () async {
                setState(() {
                  _receivables.insert(index, backup);
                });
                await ApiService().request('syncData', {
                  'userId': userId,
                  'receivables': [backup]
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _receivables.insert(index, backup);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _sendWhatsAppReminder(Map<String, dynamic> item) async {
    final String debtor = item['personName'] ?? 'Friend';
    final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final String dateStr = item['date'] ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();

    final String message =
        "Hey $debtor, just a friendly reminder about the ₹${amount.toStringAsFixed(0)} from ${DateFormat('d MMMM').format(date)}. Could you please clear it when possible? Thanks!";
    final String encodedMessage = Uri.encodeComponent(message);

    final Uri whatsappUri = Uri.parse("whatsapp://send?text=$encodedMessage");
    final Uri webUri = Uri.parse("https://wa.me/?text=$encodedMessage");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }

      // Update reminderStatus to "Sent"
      final userId = _authState.userId;
      if (userId != null) {
        final updatedItem = Map<String, dynamic>.from(item)
          ..['reminderStatus'] = 'Sent';
        await ApiService().request('syncData', {
          'userId': userId,
          'receivables': [updatedItem]
        });
        _fetchDues();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch WhatsApp: $e')),
        );
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
          'Debts & Loans',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(true),
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF2DD4BF),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Borrowed (You Owe)'),
            Tab(text: 'Owed to Me'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2DD4BF)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: You Owe (Borrowed list)
                RefreshIndicator(
                  onRefresh: _fetchDues,
                  color: const Color(0xFF2DD4BF),
                  backgroundColor: const Color(0xFF1E293B),
                  child: _buildBorrowedList(),
                ),
                // Tab 2: Owed to Me (Receivables list)
                RefreshIndicator(
                  onRefresh: _fetchDues,
                  color: const Color(0xFF2DD4BF),
                  backgroundColor: const Color(0xFF1E293B),
                  child: _buildReceivablesList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool isBorrowedTab = _tabController.index == 0;
          final Widget targetScreen = isBorrowedTab
              ? const AddBorrowedScreen()
              : const AddReceivableScreen();

          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => targetScreen),
          );
          if (result == true) {
            _fetchDues();
          }
        },
        backgroundColor: const Color(0xFF2DD4BF),
        foregroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildBorrowedList() {
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (_borrowed.isEmpty) {
      return _buildEmptyState(
        icon: Icons.handshake_outlined,
        title: 'No Borrowed Money Logged',
        message: 'Tap the + button below to log a debt you owe to someone.',
      );
    }

    // Sort Pending first, then Repaid. Inside those, order by due date.
    final List<Map<String, dynamic>> sortedList = List.from(_borrowed);
    sortedList.sort((a, b) {
      final aStatus = a['status'] ?? 'Pending';
      final bStatus = b['status'] ?? 'Pending';
      if (aStatus != bStatus) {
        return aStatus == 'Pending' ? -1 : 1;
      }
      final dateA = DateTime.tryParse(a['dueDate'] ?? '') ?? DateTime(2025);
      final dateB = DateTime.tryParse(b['dueDate'] ?? '') ?? DateTime(2025);
      return dateA.compareTo(dateB);
    });

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      itemCount: sortedList.length,
      itemBuilder: (context, index) {
        final item = sortedList[index];
        final String id = item['id'] ?? '';
        final String lender = item['personName'] ?? 'Lender';
        final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        final String status = item['status'] ?? 'Pending';
        final String borrowDateStr = item['borrowDate'] ?? '';
        final String dueDateStr = item['dueDate'] ?? '';

        final borrowDate = DateTime.tryParse(borrowDateStr) ?? DateTime.now();
        final dueDate = DateTime.tryParse(dueDateStr) ?? DateTime.now();
        final isOverdue = status == 'Pending' && dueDate.isBefore(DateTime.now());

        final isPending = status == 'Pending';

        return Dismissible(
          key: Key(id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24.0),
            margin: const EdgeInsets.only(bottom: 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ),
          onDismissed: (_) => _deleteBorrowed(id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            decoration: BoxDecoration(
              color: isPending
                  ? const Color(0xFF1E293B).withOpacity(0.4)
                  : const Color(0xFF1E293B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPending
                    ? (isOverdue
                        ? const Color(0xFFF87171).withOpacity(0.3)
                        : Colors.white.withOpacity(0.04))
                    : Colors.white.withOpacity(0.02),
                width: 1.2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isPending
                              ? (isOverdue
                                  ? const Color(0xFFEF4444).withOpacity(0.12)
                                  : const Color(0xFFFBBF24).withOpacity(0.12))
                              : const Color(0xFF10B981).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPending
                              ? (isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.hourglass_empty_rounded)
                              : Icons.check_circle_outline_rounded,
                          color: isPending
                              ? (isOverdue
                                  ? const Color(0xFFF87171)
                                  : const Color(0xFFFBBF24))
                              : const Color(0xFF34D399),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lender,
                              style: GoogleFonts.outfit(
                                color: isPending ? Colors.white : const Color(0xFF94A3B8),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: isPending
                                    ? TextDecoration.none
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPending
                                  ? 'Due ${DateFormat('d MMM yyyy').format(dueDate)}'
                                  : 'Borrowed on ${DateFormat('d MMM yyyy').format(borrowDate)}',
                              style: GoogleFonts.outfit(
                                color: isOverdue
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currencyFormat.format(amount),
                            style: GoogleFonts.outfit(
                              color: isPending
                                  ? (isOverdue
                                      ? const Color(0xFFF87171)
                                      : Colors.white)
                                  : const Color(0xFF94A3B8),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _toggleBorrowedRepaid(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? const Color(0xFF2DD4BF).withOpacity(0.1)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isPending
                                      ? const Color(0xFF2DD4BF).withOpacity(0.2)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                isPending ? 'MARK REPAID' : 'REOPEN DEBT',
                                style: GoogleFonts.outfit(
                                  color: isPending
                                      ? const Color(0xFF2DD4BF)
                                      : const Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
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
        );
      },
    );
  }

  Widget _buildReceivablesList() {
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (_receivables.isEmpty) {
      return _buildEmptyState(
        icon: Icons.request_quote_outlined,
        title: 'No Money Owed to You',
        message: 'Tap the + button below to log a loan you extended to a friend.',
      );
    }

    // Sort Pending first, then Repaid. Inside those, order by date.
    final List<Map<String, dynamic>> sortedList = List.from(_receivables);
    sortedList.sort((a, b) {
      final aStatus = a['status'] ?? 'Pending';
      final bStatus = b['status'] ?? 'Pending';
      if (aStatus != bStatus) {
        return aStatus == 'Pending' ? -1 : 1;
      }
      final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2025);
      final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2025);
      return dateB.compareTo(dateA); // Newest first
    });

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      itemCount: sortedList.length,
      itemBuilder: (context, index) {
        final item = sortedList[index];
        final String id = item['id'] ?? '';
        final String debtor = item['personName'] ?? 'Debtor';
        final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        final String status = item['status'] ?? 'Pending';
        final String dateStr = item['date'] ?? '';
        final String reminderStatus = item['reminderStatus'] ?? 'Not Sent';
        final date = DateTime.tryParse(dateStr) ?? DateTime.now();

        final isPending = status == 'Pending';
        final isReminderSent = reminderStatus == 'Sent';

        return Dismissible(
          key: Key(id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24.0),
            margin: const EdgeInsets.only(bottom: 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ),
          onDismissed: (_) => _deleteReceivable(id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            decoration: BoxDecoration(
              color: isPending
                  ? const Color(0xFF1E293B).withOpacity(0.4)
                  : const Color(0xFF1E293B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.04),
                width: 1.2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isPending
                              ? const Color(0xFF10B981).withOpacity(0.12)
                              : const Color(0xFF64748B).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPending
                              ? Icons.call_received_rounded
                              : Icons.check_circle_outline_rounded,
                          color: isPending ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              debtor,
                              style: GoogleFonts.outfit(
                                color: isPending ? Colors.white : const Color(0xFF94A3B8),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: isPending
                                    ? TextDecoration.none
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lent on ${DateFormat('d MMM yyyy').format(date)}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                            if (isPending) ...[
                              const SizedBox(height: 6),
                              // Reminder Status Text Badge
                              Row(
                                children: [
                                  Icon(
                                    isReminderSent
                                        ? Icons.check_circle
                                        : Icons.access_time_filled,
                                    size: 11,
                                    color: isReminderSent
                                        ? const Color(0xFF2DD4BF)
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isReminderSent
                                        ? 'Reminder: Sent'
                                        : 'Reminder: Not Sent',
                                    style: GoogleFonts.outfit(
                                      color: isReminderSent
                                          ? const Color(0xFF2DD4BF)
                                          : const Color(0xFF64748B),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currencyFormat.format(amount),
                            style: GoogleFonts.outfit(
                              color: isPending ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // WhatsApp Reminder Icon (only for active Pending logs)
                              if (isPending) ...[
                                GestureDetector(
                                  onTap: () => _sendWhatsAppReminder(item),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF25D366).withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline,
                                      color: Color(0xFF25D366),
                                      size: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              // Mark Paid Action Toggle
                              GestureDetector(
                                onTap: () => _toggleReceivablePaid(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? const Color(0xFF2DD4BF).withOpacity(0.1)
                                        : Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isPending
                                          ? const Color(0xFF2DD4BF).withOpacity(0.2)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Text(
                                    isPending ? 'MARK PAID' : 'REOPEN',
                                    style: GoogleFonts.outfit(
                                      color: isPending
                                          ? const Color(0xFF2DD4BF)
                                          : const Color(0xFF94A3B8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
      {required IconData icon, required String title, required String message}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.6,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF2DD4BF), size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load debts',
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
                color: const Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
