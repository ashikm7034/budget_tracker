import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/auth_state.dart';
import '../../core/api_service.dart';
import '../../core/gemini_service.dart';
import 'dart:ui';

class AICoachScreen extends StatefulWidget {
  const AICoachScreen({super.key});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> with WidgetsBindingObserver {
  final AuthState _authState = AuthState();
  final ApiService _apiService = ApiService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  bool _isTyping = false;
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _lastListedExpenses = [];

  final List<String> _quickPrompts = [
    "Give me last 10 expenses",
    "spent 50 on food for lunch",
    "How is my spending ratio?",
    "Can I afford EMO Robot?",
    "Show my debt summary",
    "Give me a saving tip",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeech();
    _loadDashboardData();
    _messages.add({
      'isUser': false,
      'text': "Hello! I am your Apple-style MoneyMate AI Coach. Tap any suggestion below or ask me about your savings goals, debts, or spending patterns.",
      'time': DateTime.now(),
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speechToText.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    setState(() {});
  }

  Future<void> _initSpeech() async {
    try {
      final enabled = await _speechToText.initialize(
        onError: (val) => debugPrint('Speech error: $val'),
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      setState(() {
        _speechEnabled = enabled;
      });
    } catch (_) {}
  }

  void _startListening() async {
    if (!_speechEnabled) {
      await _initSpeech();
    }
    if (_speechEnabled) {
      setState(() {
        _isListening = true;
      });
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        },
      );
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _loadDashboardData() async {
    try {
      final userId = _authState.userId;
      if (userId != null) {
        final data = await _apiService.request('getDashboardData', {'userId': userId});
        setState(() {
          _dashboardData = data;
        });
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, dynamic>? _parseExpenseCommand(String text) {
    // Look for numbers in the string
    final numRegex = RegExp(r'\b\d+\b');
    final match = numRegex.firstMatch(text);
    if (match == null) return null;

    final double amount = double.parse(match.group(0)!);
    if (amount <= 0) return null;

    final lowerText = text.toLowerCase();
    
    // Categorize
    String category = 'Other';
    if (lowerText.contains('tea') || lowerText.contains('coffee') || lowerText.contains('chai')) {
      category = 'Tea';
    } else if (lowerText.contains('snack') || lowerText.contains('samosa') || lowerText.contains('biscuit') || lowerText.contains('lays') || lowerText.contains('kurkure')) {
      category = 'Snacks';
    } else if (lowerText.contains('food') || lowerText.contains('lunch') || lowerText.contains('dinner') || lowerText.contains('breakfast') || lowerText.contains('hotel') || lowerText.contains('mess') || lowerText.contains('meals')) {
      category = 'Food';
    } else if (lowerText.contains('travel') || lowerText.contains('bus') || lowerText.contains('taxi') || lowerText.contains('auto') || lowerText.contains('train') || lowerText.contains('metro') || lowerText.contains('fuel') || lowerText.contains('petrol')) {
      category = 'Travel';
    } else if (lowerText.contains('college') || lowerText.contains('fees') || lowerText.contains('book') || lowerText.contains('exam') || lowerText.contains('pen') || lowerText.contains('pencil')) {
      category = 'College';
    } else if (lowerText.contains('recharge') || lowerText.contains('phone') || lowerText.contains('internet') || lowerText.contains('wifi') || lowerText.contains('mobile')) {
      category = 'Recharge';
    } else if (lowerText.contains('shop') || lowerText.contains('dress') || lowerText.contains('cloth') || lowerText.contains('shoe') || lowerText.contains('pant') || lowerText.contains('shirt')) {
      category = 'Shopping';
    } else if (lowerText.contains('sub') || lowerText.contains('netflix') || lowerText.contains('spotify') || lowerText.contains('prime') || lowerText.contains('youtube')) {
      category = 'Subscription';
    }

    // Need or Want
    String needOrWant = 'Want';
    if (lowerText.contains('need') || category == 'College' || category == 'Bills' || category == 'Travel') {
      needOrWant = 'Need';
    } else if (lowerText.contains('want')) {
      needOrWant = 'Want';
    }

    // Detect Payment Method
    String paymentMethod = 'UPI';
    if (lowerText.contains('lite') || lowerText.contains('upi lite')) {
      paymentMethod = 'UPI Lite';
    } else if (lowerText.contains('cash')) {
      paymentMethod = 'Cash';
    } else if (lowerText.contains('card') || lowerText.contains('credit') || lowerText.contains('debit')) {
      paymentMethod = 'Card';
    }

    // Construct a clean description / note
    String note = text
        .replaceAll(match.group(0)!, '')
        .replaceAll(RegExp(r'\b(need|want|spent|add|logged|expense|expence|es|for|on|rs|inr|₹|spent|rupees|rupee|lite|upi|cash|card|credit|debit)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (note.isEmpty) {
      note = '$category expense';
    }

    return {
      'amount': amount,
      'category': category,
      'needOrWant': needOrWant,
      'note': note,
      'paymentMethod': paymentMethod,
    };
  }

  void _replyWithDelay(String reply) {
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'isUser': false,
            'text': reply,
            'time': DateTime.now(),
          });
        });
        _scrollToBottom();
      }
    });
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
        'time': DateTime.now(),
      });
      _isTyping = true;
    });
    _scrollToBottom();

    final lowerText = text.toLowerCase();

    // 1. Check for "last 10 expenses" request
    if (lowerText.contains('last 10') || 
        lowerText.contains('show 10') || 
        lowerText.contains('10 expense') || 
        lowerText.contains('list 10') ||
        lowerText.contains('last ten') ||
        lowerText.contains('show ten')) {
      final expensesList = _dashboardData['expenses'] as List? ?? [];
      
      final List<Map<String, dynamic>> sorted = List<Map<String, dynamic>>.from(expensesList)
        ..sort((a, b) {
          final ad = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
          final bd = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
          return bd.compareTo(ad);
        });

      final List<Map<String, dynamic>> last10 = sorted.take(10).toList();
      _lastListedExpenses = last10;

      if (last10.isEmpty) {
        _replyWithDelay("You haven't logged any expenses yet! Ask me like *'spent 50 on food'* to log your first transaction.");
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln("Here are your last ${last10.length} expenses:");
      for (int i = 0; i < last10.length; i++) {
        final exp = last10[i];
        final amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
        final note = exp['note'] ?? exp['category'] ?? 'Expense';
        final needOrWant = exp['needOrWant'] ?? exp['classification'] ?? 'Want';
        
        String dateStr = '';
        try {
          if (exp['date'] != null) {
            dateStr = DateFormat('dd MMM').format(DateTime.parse(exp['date']));
          }
        } catch (_) {}

        buffer.writeln("${i + 1}. **₹${amt.toStringAsFixed(0)}** on *$note* ($dateStr) - $needOrWant");
      }
      buffer.writeln("\n💡 To delete one, reply with **'delete [number]'** (e.g. **'delete 2'**).");
      
      _replyWithDelay(buffer.toString());
      return;
    }

    // 2. Check for "delete [number]" request
    if (lowerText.contains('delete') || lowerText.contains('remove')) {
      final numRegex = RegExp(r'\b\d+\b');
      final match = numRegex.firstMatch(lowerText);
      if (match != null) {
        final int listNum = int.parse(match.group(0)!);
        if (_lastListedExpenses.isNotEmpty) {
          if (listNum >= 1 && listNum <= _lastListedExpenses.length) {
            final targetExpense = _lastListedExpenses[listNum - 1];
            final id = targetExpense['id'];
            final note = targetExpense['note'] ?? targetExpense['category'] ?? 'Expense';
            final amt = (targetExpense['amount'] as num?)?.toDouble() ?? 0.0;
            final userId = _authState.userId;

            if (userId != null && id != null) {
              _apiService.request('syncData', {
                'userId': userId,
                'expenses': [
                  {'id': id, '_action': 'delete'}
                ]
              }).then((_) {
                _loadDashboardData();
              });

              setState(() {
                _lastListedExpenses.removeAt(listNum - 1);
              });

              final reply = "❌ Deleted expense: **₹${amt.toStringAsFixed(0)}** for \"$note\".\n\nYour dashboard and report metrics have been updated.";
              _replyWithDelay(reply);
              return;
            }
          } else {
            _replyWithDelay("Invalid number. Please choose a number between 1 and ${_lastListedExpenses.length} from your last listed expenses.");
            return;
          }
        } else {
          _replyWithDelay("I don't know which expense to delete. Ask me to **'give me last 10 expenses'** first, then reply with **'delete [number]'**.");
          return;
        }
      }
    }

    // 3. Check if user is asking to add an expense
    final parsedExpense = _parseExpenseCommand(text);
    if (parsedExpense != null) {
      final isExpenseAction = lowerText.contains('spent') ||
          lowerText.contains('add') ||
          lowerText.contains('log') ||
          lowerText.contains('bought') ||
          lowerText.contains('paid') ||
          lowerText.contains('expense') ||
          lowerText.contains('expence') ||
          lowerText.contains('rupees') ||
          lowerText.contains('rupee') ||
          lowerText.contains('rs') ||
          lowerText.contains('₹');
      final hasExplicitCategory = parsedExpense['category'] != 'Other';

      if (isExpenseAction || hasExplicitCategory) {
      final userId = _authState.userId;
      if (userId != null) {
        final expenseId = 'exp_${const Uuid().v4()}';
        final newExpense = {
          'id': expenseId,
          'userId': userId,
          'amount': parsedExpense['amount'],
          'category': parsedExpense['category'],
          'note': parsedExpense['note'],
          'date': DateTime.now().toIso8601String(),
          'paymentMethod': parsedExpense['paymentMethod'] ?? 'UPI',
          'needOrWant': parsedExpense['needOrWant'],
        };

        _apiService.request('syncData', {
          'userId': userId,
          'expenses': [newExpense]
        }).then((_) {
          _loadDashboardData();
        });

        final amtStr = parsedExpense['amount'].toStringAsFixed(0);
        final reply = "I've logged that expense for you! 📝\n\n• **Amount:** ₹$amtStr\n• **Category:** ${parsedExpense['category']}\n• **Description:** \"${parsedExpense['note']}\"\n• **Type:** ${parsedExpense['needOrWant']}\n\nIt is now saved in your transaction history.";
        _replyWithDelay(reply);
        return;
      }
    }
  }

    // 4. Default dynamic advice response
    if (GeminiService().isConfigured) {
      GeminiService().generateFinancialAdvice(text, _dashboardData).then((reply) {
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add({
              'isUser': false,
              'text': reply,
              'time': DateTime.now(),
            });
          });
          _scrollToBottom();
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add({
              'isUser': false,
              'text': "Error generating AI advice: $e",
              'time': DateTime.now(),
            });
          });
          _scrollToBottom();
        }
      });
    } else {
      Timer(const Duration(milliseconds: 800), () {
        final reply = _generateCoachReply(text);
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add({
              'isUser': false,
              'text': reply,
              'time': DateTime.now(),
            });
          });
          _scrollToBottom();
        }
      });
    }
  }

  String _generateCoachReply(String query) {
    final lowerQuery = query.toLowerCase();

    // Fetch dynamic figures
    final summary = _dashboardData['summary'] ?? {};
    final double balance = (summary['currentBalance'] as num?)?.toDouble() ?? 0.0;
    final double totalExpenses = (summary['totalExpenses'] as num?)?.toDouble() ?? 0.0;
    final double totalSavings = (summary['totalSavings'] as num?)?.toDouble() ?? 0.0;
    final double borrowed = (summary['pendingBorrowed'] as num?)?.toDouble() ?? 0.0;
    final double receivable = (summary['pendingReceivables'] as num?)?.toDouble() ?? 0.0;
    
    final goals = _dashboardData['goals'] as List? ?? [];
    final expenses = _dashboardData['expenses'] as List? ?? [];

    if (lowerQuery.contains('ratio') || lowerQuery.contains('need') || lowerQuery.contains('want')) {
      double needsSum = 0.0;
      double wantsSum = 0.0;
      for (var exp in expenses) {
        final amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
        final classification = exp['classification'] ?? 'Need';
        if (classification.toLowerCase() == 'need') {
          needsSum += amt;
        } else {
          wantsSum += amt;
        }
      }
      final double total = needsSum + wantsSum;
      if (total == 0) {
        return "You haven't logged any expenses yet! Once you log expenses as Needs or Wants, I'll calculate your budget split here.";
      }
      final double needsPct = (needsSum / total) * 100;
      final double wantsPct = (wantsSum / total) * 100;
      return "Based on your logged expenses, your ratio is:\n• Needs: ${needsPct.toStringAsFixed(0)}% (₹${needsSum.toStringAsFixed(0)})\n• Wants: ${wantsPct.toStringAsFixed(0)}% (₹${wantsSum.toStringAsFixed(0)})\n\n${wantsPct > 50 ? "⚠️ Warning: Your Wants spending is high. Try saving an extra ₹150 this week to balance the scale." : "✅ Excellent: You are keeping your Wants spending under control."}";
    }

    if (lowerQuery.contains('afford') || lowerQuery.contains('goal') || lowerQuery.contains('emo')) {
      if (goals.isEmpty) {
        return "You don't have any savings goals configured right now. Head over to the Goals tab to create one!";
      }

      // Find matched goal
      Map<String, dynamic>? targetGoal;
      for (var goal in goals) {
        final name = (goal['goalName'] as String? ?? '').toLowerCase();
        if (lowerQuery.contains(name) || name.contains('emo') || name.contains('robot') || targetGoal == null) {
          targetGoal = Map<String, dynamic>.from(goal);
        }
      }

      if (targetGoal != null) {
        final name = targetGoal['goalName'] ?? 'Goal';
        final double current = (targetGoal['currentAmount'] as num?)?.toDouble() ?? 0.0;
        final double target = (targetGoal['targetAmount'] as num?)?.toDouble() ?? 0.0;
        final double diff = target - current;

        if (diff <= 0) {
          return "Congratulations! You have already fully funded your goal: '$name' (₹$target saved)! You can afford to buy it now.";
        }

        final deadlineStr = targetGoal['deadline'] ?? '';
        final deadline = DateTime.tryParse(deadlineStr) ?? DateTime.now().add(const Duration(days: 30));
        final days = deadline.difference(DateTime.now()).inDays;

        if (days <= 0) {
          return "For your '$name' goal, you need ₹${diff.toStringAsFixed(0)} more, but the deadline has passed. Go to the Goals tab to update the deadline.";
        }

        final dailySavings = diff / days;
        return "To afford '$name' (Target: ₹${target.toStringAsFixed(0)}):\n• You have saved ₹${current.toStringAsFixed(0)} (Remaining: ₹${diff.toStringAsFixed(0)}).\n• You have $days days left.\n• You need to save about ₹${dailySavings.toStringAsFixed(0)} per day to reach this goal.";
      }
    }

    if (lowerQuery.contains('debt') || lowerQuery.contains('borrow') || lowerQuery.contains('owe') || lowerQuery.contains('loan')) {
      if (borrowed == 0 && receivable == 0) {
        return "You are currently debt-free! No borrowed amounts or receivables recorded.";
      }
      return "Here is your Debt Status summary:\n• You owe others (Borrowed): ₹${borrowed.toStringAsFixed(0)}\n• Others owe you (Receivables): ₹${receivable.toStringAsFixed(0)}\n\n${receivable > borrowed ? "🟢 You are net positive by ₹${(receivable - borrowed).toStringAsFixed(0)}." : "🔴 You are net negative by ₹${(borrowed - receivable).toStringAsFixed(0)}."}";
    }

    if (lowerQuery.contains('tip') || lowerQuery.contains('save') || lowerQuery.contains('budget')) {
      final List<String> tips = [
        "Track small daily leaks. Saving ₹30 on coffee or tea daily adds up to over ₹10,000 in a single year!",
        "Rule of 24 Hours: Before buying any Want, wait 24 hours. The urge to buy usually passes.",
        "Categorize correctly: Always separate 'Need' (rent, transit) from 'Want' (snacks, dining out) to get clear analytics.",
        "Establish an Emergency Fund: Aim to set aside ₹1,000 as a cushion to avoid borrowing in emergencies.",
      ];
      tips.shuffle();
      return "💡 Smart Financial Tip:\n${tips.first}";
    }

    // Default response
    return "I'm not fully sure about that request, but I can assist you with:\n• 'How is my spending ratio?'\n• 'Can I afford my EMO Robot?'\n• 'Show my debt summary'\n• 'Give me a saving tip'";
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQueryData.fromView(View.of(context)).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Apple True Black
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology, color: Color(0xFF0A84FF), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'AI Coach',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 12.0,
                bottom: isKeyboardOpen
                    ? keyboardHeight + 120.0
                    : MediaQuery.of(context).padding.bottom + 120.0,
              ),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                return _buildMessageBubble(msg['text'] as String, isUser);
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isTyping) _buildTypingIndicator(),
                _buildQuickSuggestions(),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    final bubbleColor = isUser ? const Color(0xFF0A84FF) : const Color(0xFF1C1C1E);
    final textColor = Colors.white;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final textStyle = GoogleFonts.outfit(
      color: textColor,
      fontSize: 15,
      height: 1.4,
    );

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: RichText(
          text: TextSpan(
            children: _parseMarkdown(text, textStyle),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _parseMarkdown(String text, TextStyle baseStyle) {
    final List<InlineSpan> spans = [];
    final RegExp regExp = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*');
    int start = 0;

    for (final Match match in regExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: baseStyle,
        ));
      }

      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      }
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle,
      ));
    }

    return spans;
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16.0, bottom: 8.0, top: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF8E8E93),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: _quickPrompts.length,
        itemBuilder: (context, index) {
          final prompt = _quickPrompts[index];
          return GestureDetector(
            onTap: () => _handleSubmitted(prompt),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                prompt,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0A84FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    final keyboardHeight = MediaQueryData.fromView(View.of(context)).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;
    final double bottomPadding = isKeyboardOpen
        ? keyboardHeight + 8.0
        : MediaQuery.of(context).padding.bottom + 8.0;

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                onSubmitted: _handleSubmitted,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: _isListening ? 'Listening...' : 'Ask AI Coach...',
                                  hintStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93), fontSize: 15),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _isListening ? _stopListening : _startListening,
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening ? const Color(0xFFFF453A) : const Color(0xFF8E8E93),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _handleSubmitted(_textController.text),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0A84FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }
}
