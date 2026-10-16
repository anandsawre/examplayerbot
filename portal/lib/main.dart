import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/telegram_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExamplayerApp());
}

class ExamplayerApp extends StatefulWidget {
  const ExamplayerApp({super.key});

  @override
  State<ExamplayerApp> createState() => _ExamplayerAppState();
}

class _ExamplayerAppState extends State<ExamplayerApp> {
  final _api = ApiService();
  final _tg = TelegramService();

  bool _isDark = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initTelegram();
  }

  void _initTelegram() {
    if (_tg.isTelegramWebApp) {
      _tg.ready();
      _tg.expand();
    }
  }

  void _toggleTheme() {
    _tg.hapticImpact('light');
    setState(() {
      _isDark = !_isDark;
    });
  }

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _onLogout() {
    _tg.hapticImpact('medium');
    _api.logout();
    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Examplayer Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: _isAuthenticated
          ? DashboardScreen(
              onLogout: _onLogout,
              onToggleTheme: _toggleTheme,
              isDark: _isDark,
            )
          : AuthScreen(
              onAuthenticated: _onAuthenticated,
            ),
    );
  }
}
