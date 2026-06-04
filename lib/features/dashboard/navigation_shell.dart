import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import '../../core/widgets/apple_widgets.dart';

import '../debts/debts_screen.dart';
import '../goals/savings_goals_screen.dart';
import '../reports/reports_screen.dart';
import '../coach/ai_coach_screen.dart';
import 'dart:ui';
import 'package:quick_actions/quick_actions.dart';
import '../payment/qr_scanner_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initQuickActions();
  }

  void _initQuickActions() {
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_scan') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QRScannerScreen()),
        );
      }
    });
    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_scan',
        localizedTitle: 'Scan & Pay',
        icon: 'ic_launcher',
      ),
    ]);
  }

  final List<Widget> _pages = [
    const DashboardScreen(),
    const DebtsScreen(),
    const SavingsGoalsScreen(),
    const AICoachScreen(),
    const ReportsScreen(),
  ];

  Widget _buildTabItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: AppleBounceable(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 200),
                  tween: ColorTween(
                    begin: const Color(0xFF8E8E93),
                    end: isSelected ? const Color(0xFF0A84FF) : const Color(0xFF8E8E93),
                  ),
                  builder: (context, color, child) {
                    return Icon(
                      isSelected ? selectedIcon : unselectedIcon,
                      color: color,
                      size: 22,
                    );
                  },
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF0A84FF) : const Color(0xFF8E8E93),
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: RepaintBoundary(
        child: AppleSlideFadeEntrance(
          delay: const Duration(milliseconds: 200),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xCC1A1A1C),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutBack,
                          alignment: Alignment((_currentIndex / 4.0) * 2.0 - 1.0, 0.0),
                          child: FractionallySizedBox(
                            widthFactor: 0.18,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A84FF).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF0A84FF).withOpacity(0.18),
                                  width: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _buildTabItem(0, Icons.home_outlined, Icons.home, 'Home'),
                            _buildTabItem(1, Icons.people_outline, Icons.people, 'Debts'),
                            _buildTabItem(2, Icons.savings_outlined, Icons.savings, 'Goals'),
                            _buildTabItem(3, Icons.psychology_outlined, Icons.psychology, 'AI Coach'),
                            _buildTabItem(4, Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
