import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/config.dart';
import 'core/auth_state.dart';
import 'features/dashboard/navigation_shell.dart';
import 'features/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load dynamic configuration
  await AppConfig.load();

  // Initialize dynamic AuthState
  final authState = AuthState();
  await authState.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = AuthState();
    return MaterialApp(
      title: 'MoneyMate AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000), // Apple True Black
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0A84FF), // iOS System Blue
          secondary: Color(0xFF30D158), // iOS System Green
          surface: Color(0xFF1C1C1E), // iOS System Gray 6
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        useMaterial3: true,
      ),
      home: authState.isLoggedIn ? const NavigationShell() : const LoginScreen(),
      routes: {
        '/dashboard': (context) => const NavigationShell(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
