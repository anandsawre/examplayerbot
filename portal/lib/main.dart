import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
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
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _initTheme();
    _initTelegram();
    _restoreSavedSession();
  }

  void _initTheme() {
    try {
      final savedDark = web.window.localStorage.getItem('examplayer_dark_mode');
      if (savedDark != null) {
        _isDark = savedDark == '1';
      }
    } catch (_) {}
  }

  void _initTelegram() {
    if (_tg.isTelegramWebApp) {
      _tg.ready();
      _tg.expand();
    }
  }

  Future<void> _restoreSavedSession() async {
    try {
      final isValid = await _api.restoreSession();
      if (mounted) {
        setState(() {
          _isAuthenticated = isValid;
          _isCheckingAuth = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isCheckingAuth = false;
        });
      }
    }
  }

  void _toggleTheme() {
    _tg.hapticImpact('light');
    setState(() {
      _isDark = !_isDark;
    });
    try {
      web.window.localStorage.setItem('examplayer_dark_mode', _isDark ? '1' : '0');
    } catch (_) {}
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
      home: _isCheckingAuth
          ? Scaffold(
              backgroundColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Restoring Admin Session...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: _isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _isAuthenticated
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
