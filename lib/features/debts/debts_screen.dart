import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth_state.dart';
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
  NumberFormat get _currencyFormat =>
      NumberFormat.currency(locale: 'en_IN', symbol: _authState.currency, decimalDigits: 0);

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
      setState(() {});
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
            backgroundColor: const Color(0xFF1C1C1E),
            content: Text(
              'Borrowed record deleted',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF0A84FF),
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
            backgroundColor: const Color(0xFF1C1C1E),
            content: Text(
              'Receivable record deleted',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF0A84FF),
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

  void _showDebtLedgerSheet(Map<String, dynamic> item, bool isBorrowed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _DebtLedgerSheet(
          item: item,
          isBorrowed: isBorrowed,
          currencyFormat: _currencyFormat,
          onUpdated: () {
            _fetchDues();
          },
        );
      },
    );
  }

  Future<void> _sendWhatsAppReminder(Map<String, dynamic> item) async {
    final String debtor = item['personName'] ?? 'Friend';
    final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final String dateStr = item['date'] ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();

    final String message =
        "Hey $debtor, just a friendly reminder about the ${_authState.currency}${amount.toStringAsFixed(0)} from ${DateFormat('d MMMM').format(date)}. Could you please clear it when possible? Thanks!";
    final String encodedMessage = Uri.encodeComponent(message);

    final Uri whatsappUri = Uri.parse("whatsapp://send?text=$encodedMessage");
    final Uri webUri = Uri.parse("https://wa.me/?text=$encodedMessage");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }

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
      backgroundColor: const Color(0xFF000000), // Apple True Black
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Debts & Loans',
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
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0A84FF),
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF8E8E93),
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: 'Borrowed (You Owe)'),
            Tab(text: 'Owed to Me'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _fetchDues,
                  color: const Color(0xFF0A84FF),
                  backgroundColor: const Color(0xFF1C1C1E),
                  child: _buildBorrowedList(),
                ),
                RefreshIndicator(
                  onRefresh: _fetchDues,
                  color: const Color(0xFF0A84FF),
                  backgroundColor: const Color(0xFF1C1C1E),
                  child: _buildReceivablesList(),
                ),
              ],
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
        message: 'Tap the + button in the top right to log a debt you owe.',
      );
    }

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
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 100.0),
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
              color: const Color(0xFFFF453A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 24),
          ),
          onDismissed: (_) => _deleteBorrowed(id),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showDebtLedgerSheet(item, true),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPending && isOverdue
                      ? const Color(0xFFFF453A).withOpacity(0.3)
                      : const Color(0xFF2C2C2E),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isPending
                          ? (isOverdue
                              ? const Color(0xFFFF453A).withOpacity(0.12)
                              : const Color(0xFFFF9F0A).withOpacity(0.12))
                          : const Color(0xFF30D158).withOpacity(0.12),
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
                              ? const Color(0xFFFF453A)
                              : const Color(0xFFFF9F0A))
                          : const Color(0xFF30D158),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lender,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: isPending ? Colors.white : const Color(0xFF8E8E93),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: isPending
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isPending
                              ? 'Due ${DateFormat('d MMM yyyy').format(dueDate)}'
                              : 'Borrowed on ${DateFormat('d MMM yyyy').format(borrowDate)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: isOverdue ? const Color(0xFFFF453A) : const Color(0xFF8E8E93),
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
                                  ? const Color(0xFFFF453A)
                                  : Colors.white)
                              : const Color(0xFF8E8E93),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _toggleBorrowedRepaid(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPending
                                ? const Color(0xFF0A84FF).withOpacity(0.12)
                                : const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPending ? 'MARK REPAID' : 'REOPEN',
                            style: GoogleFonts.outfit(
                              color: isPending
                                  ? const Color(0xFF0A84FF)
                                  : const Color(0xFF8E8E93),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
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
        message: 'Tap the + button in the top right to log a loan extended to a friend.',
      );
    }

    final List<Map<String, dynamic>> sortedList = List.from(_receivables);
    sortedList.sort((a, b) {
      final aStatus = a['status'] ?? 'Pending';
      final bStatus = b['status'] ?? 'Pending';
      if (aStatus != bStatus) {
        return aStatus == 'Pending' ? -1 : 1;
      }
      final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2025);
      final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2025);
      return dateB.compareTo(dateA);
    });

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 100.0),
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
              color: const Color(0xFFFF453A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 24),
          ),
          onDismissed: (_) => _deleteReceivable(id),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showDebtLedgerSheet(item, false),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2C2C2E),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isPending
                          ? const Color(0xFF30D158).withOpacity(0.12)
                          : const Color(0xFF8E8E93).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPending
                          ? Icons.call_received_rounded
                          : Icons.check_circle_outline_rounded,
                      color: isPending ? const Color(0xFF30D158) : const Color(0xFF8E8E93),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debtor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: isPending ? Colors.white : const Color(0xFF8E8E93),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: isPending
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Lent on ${DateFormat('d MMM yyyy').format(date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF8E8E93),
                            fontSize: 12,
                          ),
                        ),
                        if (isPending) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                isReminderSent
                                    ? Icons.check_circle
                                    : Icons.access_time_filled,
                                size: 11,
                                color: isReminderSent
                                    ? const Color(0xFF30D158)
                                    : const Color(0xFF8E8E93),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  isReminderSent
                                      ? 'Reminder: Sent'
                                      : 'Reminder: Not Sent',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: isReminderSent
                                        ? const Color(0xFF30D158)
                                        : const Color(0xFF8E8E93),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                          color: isPending ? Colors.white : const Color(0xFF8E8E93),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (isPending) ...[
                            GestureDetector(
                              onTap: () => _sendWhatsAppReminder(item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF30D158).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'REMIND',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF30D158),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          GestureDetector(
                            onTap: () => _toggleReceivablePaid(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? const Color(0xFF0A84FF).withOpacity(0.12)
                                    : const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isPending ? 'MARK PAID' : 'REOPEN',
                                style: GoogleFonts.outfit(
                                  color: isPending
                                      ? const Color(0xFF0A84FF)
                                      : const Color(0xFF8E8E93),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
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
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1E),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF0A84FF), size: 40),
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
                  color: const Color(0xFF8E8E93),
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
            const Icon(Icons.error_outline, color: Color(0xFFFF453A), size: 48),
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

class _DebtLedgerSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isBorrowed;
  final NumberFormat currencyFormat;
  final VoidCallback onUpdated;

  const _DebtLedgerSheet({
    required this.item,
    required this.isBorrowed,
    required this.currencyFormat,
    required this.onUpdated,
  });

  @override
  State<_DebtLedgerSheet> createState() => _DebtLedgerSheetState();
}

class _DebtLedgerSheetState extends State<_DebtLedgerSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _ledgerList = [];
  double _currentAmount = 0.0;
  String _status = 'Pending';

  @override
  void initState() {
    super.initState();
    _currentAmount = (widget.item['amount'] as num?)?.toDouble() ?? 0.0;
    _status = widget.item['status'] ?? 'Pending';
    _parseLedger();
  }

  void _parseLedger() {
    final String ledgerStr = widget.item['ledger'] ?? '';
    if (ledgerStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(ledgerStr);
        if (decoded is List) {
          _ledgerList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (e) {
        debugPrint('Error parsing ledger: $e');
      }
    }

    if (_ledgerList.isEmpty && _currentAmount > 0) {
      final origDateStr = widget.item[widget.isBorrowed ? 'borrowDate' : 'date'] ?? DateTime.now().toIso8601String();
      _ledgerList.add({
        'date': origDateStr,
        'type': widget.isBorrowed ? 'borrowed' : 'lent',
        'amount': _currentAmount,
        'note': 'Initial balance'
      });
    }
  }

  Future<void> _addTransaction(bool isAdd) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;
    final double? val = double.tryParse(amountText);
    if (val == null || val <= 0) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authState = AuthState();
      final userId = authState.userId;
      if (userId == null) throw Exception('No session found');

      double newAmount = _currentAmount;
      if (isAdd) {
        newAmount += val;
      } else {
        newAmount -= val;
      }

      if (newAmount < 0) newAmount = 0;

      final newTx = {
        'date': DateTime.now().toIso8601String(),
        'type': isAdd 
            ? (widget.isBorrowed ? 'borrowed' : 'lent')
            : (widget.isBorrowed ? 'repaid' : 'received'),
        'amount': val,
        'note': _noteController.text.trim().isNotEmpty 
            ? _noteController.text.trim()
            : (isAdd 
                ? (widget.isBorrowed ? 'Borrowed more' : 'Lent more') 
                : (widget.isBorrowed ? 'Repaid partially' : 'Received partial repayment'))
      };

      _ledgerList.add(newTx);
      final newLedgerStr = jsonEncode(_ledgerList);

      final String newStatus = newAmount <= 0 ? 'Repaid' : 'Pending';

      final updatedItem = Map<String, dynamic>.from(widget.item)
        ..['amount'] = newAmount
        ..['ledger'] = newLedgerStr
        ..['status'] = newStatus;

      final key = widget.isBorrowed ? 'borrowed' : 'receivables';

      await ApiService().request('syncData', {
        'userId': userId,
        key: [updatedItem]
      });

      setState(() {
        _currentAmount = newAmount;
        _status = newStatus;
        _amountController.clear();
        _noteController.clear();
        _isLoading = false;
      });

      widget.onUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF30D158),
            content: Text('Ledger updated successfully!'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF453A),
            content: Text('Failed to update: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final personName = widget.item['personName'] ?? 'Friend';
    final initialLetter = personName.isNotEmpty ? personName[0].toUpperCase() : '?';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: widget.isBorrowed 
                            ? const Color(0xFFFF9F0A).withValues(alpha: 0.15) 
                            : const Color(0xFF30D158).withValues(alpha: 0.15),
                        child: Text(
                          initialLetter,
                          style: GoogleFonts.outfit(
                            color: widget.isBorrowed ? const Color(0xFFFF9F0A) : const Color(0xFF30D158),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              personName,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.isBorrowed ? 'Money you borrowed' : 'Money you lent',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF8E8E93),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _status == 'Pending' 
                              ? const Color(0xFFFF9F0A).withValues(alpha: 0.15) 
                              : const Color(0xFF30D158).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _status.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: _status == 'Pending' ? const Color(0xFFFF9F0A) : const Color(0xFF30D158),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Total outstanding box
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Outstanding Balance',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF8E8E93),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.currencyFormat.format(_currentAmount),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // History Section Title
                  Text(
                    'TRANSACTION LEDGER HISTORY',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF8E8E93),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Ledger History list
                  _ledgerList.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No ledger entries logged yet.',
                              style: GoogleFonts.outfit(color: const Color(0xFF8E8E93)),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _ledgerList.length,
                          itemBuilder: (context, index) {
                            final tx = _ledgerList[index];
                            final dateStr = tx['date'] ?? '';
                            final date = DateTime.tryParse(dateStr) ?? DateTime.now();
                            final type = tx['type'] ?? 'borrowed';
                            final double txAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                            final note = tx['note'] ?? '';

                            final bool isPlus = (type == 'borrowed' || type == 'lent');
                            final color = isPlus 
                                ? (widget.isBorrowed ? const Color(0xFFFF9F0A) : const Color(0xFF30D158))
                                : const Color(0xFF8E8E93);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isPlus ? Icons.add_circle_outline : Icons.remove_circle_outline,
                                    color: color,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          note.isNotEmpty ? note : (isPlus ? 'Added' : 'Repaid'),
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('d MMM yyyy, h:mm a').format(date),
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF8E8E93),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isPlus ? "+" : "-"} ${widget.currencyFormat.format(txAmount)}',
                                    style: GoogleFonts.outfit(
                                      color: color,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 16),

                  // Action entry box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'LOG NEW TRANSACTION',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF8E8E93),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                                decoration: InputDecoration(
                                  prefixText: '${AuthState().currency} ',
                                  prefixStyle: GoogleFonts.outfit(color: const Color(0xFF0A84FF)),
                                  hintText: 'Amount',
                                  hintStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93)),
                                  filled: true,
                                  fillColor: const Color(0xFF1C1C1E),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _noteController,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Note (Optional)',
                                  hintStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93)),
                                  filled: true,
                                  fillColor: const Color(0xFF1C1C1E),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
                            ),
                          )
                        else
                          Row(
                            children: [
                              // Subtraction button
                              Expanded(
                                child: TextButton(
                                  onPressed: () => _addTransaction(false),
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFF8E8E93).withValues(alpha: 0.15),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    widget.isBorrowed ? 'GIVE BACK' : 'RECEIVED',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF8E8E93),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Addition button
                              Expanded(
                                child: TextButton(
                                  onPressed: () => _addTransaction(true),
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    widget.isBorrowed ? 'TAKE MORE' : 'LEND MORE',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF0A84FF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
