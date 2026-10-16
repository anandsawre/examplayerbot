import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/telegram_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _api = ApiService();
  final _tg = TelegramService();

  bool _isPasswordMode = false;
  bool _isLoading = false;
  bool _otpSent = false;
  String _errorMessage = '';

  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telegramIdController = TextEditingController(text: '747573651'); // Default Admin ID

  @override
  void initState() {
    super.initState();
    _checkTelegramUser();
  }

  void _checkTelegramUser() {
    if (_tg.isTelegramWebApp) {
      _tg.ready();
      _tg.expand();
      final user = _tg.user;
      if (user != null && user['id'] != null) {
        _telegramIdController.text = user['id'].toString();
      }
    }
  }

  Future<void> _requestOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    _tg.hapticImpact('light');

    try {
      final res = await _api.requestOtp(_telegramIdController.text.trim());
      if (res['success'] == true) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
        _tg.hapticNotification('success');
      } else {
        setState(() {
          _errorMessage = res['error'] ?? 'Failed to send OTP to Telegram';
          _isLoading = false;
        });
        _tg.hapticNotification('error');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
        _isLoading = false;
      });
      _tg.hapticNotification('error');
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await _api.verifyOtp(_telegramIdController.text.trim(), code);
      if (res['success'] == true) {
        _tg.hapticNotification('success');
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage = res['error'] ?? 'Invalid or expired OTP';
          _isLoading = false;
        });
        _tg.hapticNotification('error');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification error: $e';
        _isLoading = false;
      });
      _tg.hapticNotification('error');
    }
  }

  Future<void> _loginWithPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter the admin password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await _api.loginWithPassword(password);
      if (res['success'] == true) {
        _tg.hapticNotification('success');
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage = res['error'] ?? 'Invalid master password';
          _isLoading = false;
        });
        _tg.hapticNotification('error');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
        _isLoading = false;
      });
      _tg.hapticNotification('error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon & Title
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryHover],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.smart_toy_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Examplayer Admin',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _tg.isTelegramWebApp
                          ? 'Telegram Mini App Secure Authentication'
                          : 'Administrative Operations Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error Alert
                    if (_errorMessage.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.rose.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.rose, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(color: AppTheme.rose, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Mode Switcher Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isPasswordMode = false;
                                _errorMessage = '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isPasswordMode
                                      ? (isDark ? AppTheme.darkCard : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !_isPasswordMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'Telegram 2FA OTP',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !_isPasswordMode ? FontWeight.w600 : FontWeight.w500,
                                    color: !_isPasswordMode
                                        ? AppTheme.primary
                                        : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isPasswordMode = true;
                                _errorMessage = '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isPasswordMode
                                      ? (isDark ? AppTheme.darkCard : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _isPasswordMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'Master Password',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _isPasswordMode ? FontWeight.w600 : FontWeight.w500,
                                    color: _isPasswordMode
                                        ? AppTheme.primary
                                        : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form Fields based on Mode
                    if (!_isPasswordMode) ...[
                      if (!_otpSent) ...[
                        Text(
                          'Telegram User ID',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _telegramIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Enter Admin Telegram ID (e.g. 747573651)',
                            prefixIcon: Icon(Icons.send_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _requestOtp,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.security, size: 20),
                          label: Text(_isLoading ? 'Sending OTP to Telegram...' : 'Send OTP to Telegram Bot'),
                        ),
                      ] else ...[
                        Text(
                          'Enter 6-Digit OTP',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            letterSpacing: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Verify & Enter Console'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isLoading ? null : () => setState(() => _otpSent = false),
                          child: const Text('Resend / Change Telegram ID'),
                        ),
                      ],
                    ] else ...[
                      Text(
                        'Admin Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        onSubmitted: (_) => _loginWithPassword(),
                        decoration: const InputDecoration(
                          hintText: 'Enter Admin Password',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _loginWithPassword,
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Authenticate & Enter'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
