import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_state.dart';

class AppleBounceable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const AppleBounceable({super.key, required this.child, required this.onTap});

  @override
  State<AppleBounceable> createState() => _AppleBounceableState();
}

class _AppleBounceableState extends State<AppleBounceable> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

class AppleSlideFadeEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const AppleSlideFadeEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<AppleSlideFadeEntrance> createState() => _AppleSlideFadeEntranceState();
}

class _AppleSlideFadeEntranceState extends State<AppleSlideFadeEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _slide = Tween<Offset>(begin: const Offset(0.0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.fastLinearToSlowEaseIn),
      ),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _slide.value * 120.0, // Moves up 14px to 0
            child: widget.child,
          ),
        );
      },
    );
  }
}

class ExpenseCalculatorSheet extends StatefulWidget {
  final String initialValue;
  const ExpenseCalculatorSheet({super.key, this.initialValue = ''});

  @override
  State<ExpenseCalculatorSheet> createState() => _ExpenseCalculatorSheetState();
}

class _ExpenseCalculatorSheetState extends State<ExpenseCalculatorSheet> {
  String _expression = '';
  String _result = '0';

  @override
  void initState() {
    super.initState();
    final initAmount = double.tryParse(widget.initialValue);
    if (initAmount != null && initAmount > 0) {
      if (initAmount % 1 == 0) {
        _expression = initAmount.toInt().toString();
        _result = initAmount.toInt().toString();
      } else {
        _expression = initAmount.toString();
        _result = initAmount.toString();
      }
    }
  }

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'C') {
        _expression = '';
        _result = '0';
      } else if (key == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _evaluateExpression();
        }
      } else if (key == '=') {
        _evaluateExpression(force: true);
      } else {
        if ('+-*/'.contains(key)) {
          if (_expression.isEmpty) {
            if (key == '-') {
              _expression += key;
            }
            return;
          }
          final lastChar = _expression[_expression.length - 1];
          if ('+-*/'.contains(lastChar)) {
            _expression = _expression.substring(0, _expression.length - 1) + key;
            return;
          }
        }
        _expression += key;
        _evaluateExpression();
      }
    });
  }

  void _evaluateExpression({bool force = false}) {
    if (_expression.isEmpty) {
      _result = '0';
      return;
    }
    String evalStr = _expression;
    if ('+-*/'.contains(evalStr[evalStr.length - 1])) {
      if (force) {
        evalStr = evalStr.substring(0, evalStr.length - 1);
      } else {
        return;
      }
    }

    final val = _evaluate(evalStr);
    if (val != null) {
      if (val % 1 == 0) {
        _result = val.toInt().toString();
      } else {
        String resStr = val.toStringAsFixed(2);
        if (resStr.endsWith('.00')) {
          resStr = resStr.substring(0, resStr.length - 3);
        } else if (resStr.endsWith('0') && resStr.contains('.')) {
          resStr = resStr.substring(0, resStr.length - 1);
        }
        _result = resStr;
      }
    }
  }

  double? _evaluate(String expression) {
    try {
      List<String> tokens = [];
      String currentNumber = '';
      for (int i = 0; i < expression.length; i++) {
        String char = expression[i];
        if ('0123456789.'.contains(char)) {
          currentNumber += char;
        } else if ('+-*/'.contains(char)) {
          if (currentNumber.isNotEmpty) {
            tokens.add(currentNumber);
            currentNumber = '';
          }
          tokens.add(char);
        }
      }
      if (currentNumber.isNotEmpty) {
        tokens.add(currentNumber);
      }

      if (tokens.isEmpty) return null;

      // Handle leading negative number
      if (tokens.first == '-') {
        if (tokens.length > 1) {
          final firstNum = tokens[1];
          tokens[1] = '-$firstNum';
          tokens.removeAt(0);
        }
      }

      // Process multiplication and division first
      List<String> nextTokens = [];
      for (int i = 0; i < tokens.length; i++) {
        if (tokens[i] == '*' || tokens[i] == '/') {
          String op = tokens[i];
          if (nextTokens.isEmpty || i + 1 >= tokens.length) return null;
          double prev = double.parse(nextTokens.removeLast());
          double next = double.parse(tokens[++i]);
          double res = op == '*' ? prev * next : prev / next;
          nextTokens.add(res.toString());
        } else {
          nextTokens.add(tokens[i]);
        }
      }

      // Process addition and subtraction
      if (nextTokens.isEmpty) return null;
      double total = double.parse(nextTokens[0]);
      for (int i = 1; i < nextTokens.length; i += 2) {
        if (i + 1 >= nextTokens.length) break;
        String op = nextTokens[i];
        double val = double.parse(nextTokens[i + 1]);
        if (op == '+') {
          total += val;
        } else if (op == '-') {
          total -= val;
        }
      }
      return total;
    } catch (_) {
      return null;
    }
  }

  Widget _buildBtn(String label, {Color? bgColor, Color? textColor, VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Material(
          color: bgColor ?? const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap ?? () => _onKeyPress(label),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 54,
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: textColor ?? Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = AuthState().currency;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3C),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Expression Display
            Container(
              alignment: Alignment.centerRight,
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _expression,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF8E8E93),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // Result Display
            Container(
              alignment: Alignment.centerRight,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$currency $_result',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Rows
            Row(
              children: [
                _buildBtn('C', bgColor: const Color(0xFF48484A), textColor: Colors.white),
                _buildBtn('⌫', bgColor: const Color(0xFF48484A), textColor: Colors.white),
                _buildBtn('/', bgColor: const Color(0xFFFF9F0A), textColor: Colors.white),
              ],
            ),
            Row(
              children: [
                _buildBtn('7'),
                _buildBtn('8'),
                _buildBtn('9'),
                _buildBtn('*', bgColor: const Color(0xFFFF9F0A), textColor: Colors.white),
              ],
            ),
            Row(
              children: [
                _buildBtn('4'),
                _buildBtn('5'),
                _buildBtn('6'),
                _buildBtn('-', bgColor: const Color(0xFFFF9F0A), textColor: Colors.white),
              ],
            ),
            Row(
              children: [
                _buildBtn('1'),
                _buildBtn('2'),
                _buildBtn('3'),
                _buildBtn('+', bgColor: const Color(0xFFFF9F0A), textColor: Colors.white),
              ],
            ),
            Row(
              children: [
                _buildBtn('0'),
                _buildBtn('.'),
                _buildBtn('='),
              ],
            ),
            const SizedBox(height: 16),
            
            // Done Button
            ElevatedButton(
              onPressed: () {
                _evaluateExpression(force: true);
                Navigator.of(context).pop(_result);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A84FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: Text(
                'Use Amount: $currency $_result',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppleAnimatedCount extends StatefulWidget {
  final double endValue;
  final TextStyle style;
  final String Function(double) formatter;
  final Duration duration;

  const AppleAnimatedCount({
    super.key,
    required this.endValue,
    required this.style,
    required this.formatter,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<AppleAnimatedCount> createState() => _AppleAnimatedCountState();
}

class _AppleAnimatedCountState extends State<AppleAnimatedCount>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.endValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AppleAnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endValue != widget.endValue) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.endValue,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          widget.formatter(_animation.value),
          style: widget.style,
        );
      },
    );
  }
}

