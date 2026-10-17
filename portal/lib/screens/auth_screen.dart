import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/telegram_service.dart';

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
  bool _obscurePassword = true;
  String _errorMessage = '';

  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telegramIdController = TextEditingController(text: '747573651'); // Default Admin ID

  @override
  void initState() {
    super.initState();
    _checkTelegramUser();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _telegramIdController.dispose();
    super.dispose();
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
    final telegramId = _telegramIdController.text.trim();
    if (telegramId.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Telegram User ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    _tg.hapticImpact('light');

    try {
      final res = await _api.requestOtp(telegramId);
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
      setState(() => _errorMessage = 'Please enter the 6-digit OTP');
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
      setState(() => _errorMessage = 'Please enter the admin master password');
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

  void _showHowToFindDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'How to find Telegram ID',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogStep('1', 'Open Telegram on your mobile or desktop.'),
            const SizedBox(height: 10),
            _buildDialogStep('2', 'Search for @userinfobot or open your bot @Examplayer_bot.'),
            const SizedBox(height: 10),
            _buildDialogStep('3', 'Send /start to receive your unique numerical ID (e.g. 747573651).'),
            const SizedBox(height: 10),
            _buildDialogStep('4', 'Copy and paste the ID into the Telegram User ID field.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_outlined, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Default Admin ID 747573651 is pre-filled for convenience.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _tg.openTelegramLink('https://t.me/Examplayer_bot');
            },
            icon: const Icon(Icons.send_rounded, size: 14),
            label: const Text('Open Bot'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogStep(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF2563EB),
            shape: BoxShape.circle,
          ),
          child: Text(
            num,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030718),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 980;

          return Stack(
            children: [
              // Cosmic Background Gradient & Ambient Glow Orbs
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF020617),
                        Color(0xFF060F26),
                        Color(0xFF091B3D),
                        Color(0xFF030718),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // Ambient Cyan Glow Orb in Left-Center
              Positioned(
                left: isDesktop ? constraints.maxWidth * 0.25 : constraints.maxWidth * 0.1,
                top: constraints.maxHeight * 0.35,
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.22),
                        blurRadius: 140,
                        spreadRadius: 80,
                      ),
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.18),
                        blurRadius: 180,
                        spreadRadius: 90,
                      ),
                    ],
                  ),
                ),
              ),

              // Main Content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 48 : 20,
                      vertical: isDesktop ? 36 : 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1220),
                      child: isDesktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Left Column: Branding, Features & 3D Centerpiece
                                Expanded(
                                  flex: 12,
                                  child: _buildLeftHeroSection(),
                                ),
                                const SizedBox(width: 48),
                                // Right Column: White Elevated Floating Card
                                Expanded(
                                  flex: 10,
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 470),
                                      child: _buildAuthCard(),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildMobileBrandHeader(),
                                const SizedBox(height: 24),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 470),
                                  child: _buildAuthCard(),
                                ),
                                const SizedBox(height: 32),
                                _buildTrustIndicators(isCenter: true),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // Mobile Top Header
  // -------------------------------------------------------------
  Widget _buildMobileBrandHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_rounded, size: 24, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Examplayer',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('👑', style: TextStyle(fontSize: 16)),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Telegram Bot',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ADMIN PANEL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Manage Your Telegram Bot with Confidence',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Left Hero Section (Brand, Headline, 4 Features & 3D Centerpiece)
  // -------------------------------------------------------------
  Widget _buildLeftHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand Row
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_rounded, size: 26, color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Examplayer',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('👑', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Telegram Bot',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'ADMIN PANEL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 36),

        // Main Headline: "Manage Your Telegram Bot with Confidence"
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
            children: [
              const TextSpan(text: 'Manage Your\n'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF00A3FF)],
                  ).createShader(bounds),
                  child: Text(
                    'Telegram Bot',
                    style: GoogleFonts.inter(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const TextSpan(text: '\nwith Confidence'),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Subtitle Description
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Secure, fast and powerful administrative control panel for tests, users, broadcasts, payments and more — all in one place.',
            style: GoogleFonts.inter(
              fontSize: 14.5,
              height: 1.55,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),

        const SizedBox(height: 36),

        // Center Content Area: 4 Features on Left + 3D Centerpiece Artwork on Right
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Dot Matrix Pattern background
            Positioned(
              right: 0,
              top: -20,
              child: _buildDotGridPattern(),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 4 Feature items
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeatureItem(
                      icon: Icons.groups_rounded,
                      iconBg: const Color(0xFF2563EB),
                      title: 'Manage Users',
                      subtitle: 'View, track and manage all users',
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureItem(
                      icon: Icons.article_rounded,
                      iconBg: const Color(0xFF8B5CF6),
                      title: 'Create & Manage Tests',
                      subtitle: 'Organize questions and study content',
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureItem(
                      icon: Icons.send_rounded,
                      iconBg: const Color(0xFF10B981),
                      title: 'Send Broadcasts',
                      subtitle: 'Target users, groups or specific plans',
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureItem(
                      icon: Icons.bar_chart_rounded,
                      iconBg: const Color(0xFFF59E0B),
                      title: 'View Analytics',
                      subtitle: 'Track growth and engagement',
                    ),
                  ],
                ),

                const SizedBox(width: 24),

                // 3D Telegram Centerpiece Artwork
                const Expanded(
                  child: Center(
                    child: _Telegram3DArtworkWidget(),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 44),

        // Bottom Trust Indicators
        _buildTrustIndicators(isCenter: false),
      ],
    );
  }

  // -------------------------------------------------------------
  // Feature Row Item
  // -------------------------------------------------------------
  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: iconBg.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Dot Grid Pattern
  // -------------------------------------------------------------
  Widget _buildDotGridPattern() {
    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: _DotGridPainter(),
      ),
    );
  }

  // -------------------------------------------------------------
  // Trust Indicators at Bottom
  // -------------------------------------------------------------
  Widget _buildTrustIndicators({required bool isCenter}) {
    return Row(
      mainAxisAlignment: isCenter ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        _buildTrustItem(Icons.shield_outlined, 'Secure\nAccess'),
        const SizedBox(width: 32),
        _buildTrustItem(Icons.bolt_rounded, 'Fast &\nReliable'),
        const SizedBox(width: 32),
        _buildTrustItem(Icons.cloud_outlined, 'Always\nOnline'),
      ],
    );
  }

  Widget _buildTrustItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 26),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: const Color(0xFFCBD5E1),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Elevated White Auth Card (Right Column)
  // -------------------------------------------------------------
  Widget _buildAuthCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 48,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Robot Avatar Icon
          Center(
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
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

          const SizedBox(height: 18),

          // Portal Title
          Text(
            'Examplayer Admin',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Administrative Operations Portal',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 24),

          // Error Alert Message
          if (_errorMessage.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFBE123C),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Mode Switcher Tabs: [ Telegram 2FA OTP ] vs [ Master Password ]
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: !_isPasswordMode ? const Color(0xFF2563EB) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: !_isPasswordMode
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            size: 14,
                            color: !_isPasswordMode ? Colors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Telegram 2FA OTP',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: !_isPasswordMode ? FontWeight.w700 : FontWeight.w500,
                              color: !_isPasswordMode ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ],
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _isPasswordMode ? const Color(0xFF2563EB) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _isPasswordMode
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: _isPasswordMode ? Colors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Master Password',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: _isPasswordMode ? FontWeight.w700 : FontWeight.w500,
                              color: _isPasswordMode ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Content Based on Mode
          if (!_isPasswordMode) ...[
            if (!_otpSent) ...[
              // Info Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Login using your Telegram account',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enter your Telegram User ID to receive a secure OTP on your Telegram bot.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Telegram User ID Label & "How to find?" Link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Telegram User ID',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Your numerical Telegram ID.',
                        child: Icon(
                          Icons.help_outline_rounded,
                          size: 15,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _showHowToFindDialog(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'How to find?',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Telegram User ID Input Field
              TextField(
                controller: _telegramIdController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  hintText: 'Enter Telegram User ID',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: Color(0xFF2563EB),
                  ),
                  suffixIcon: _telegramIdController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                          onPressed: () => setState(() => _telegramIdController.clear()),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _requestOtp(),
              ),

              const SizedBox(height: 20),

              // Primary CTA Button: Send OTP to Telegram Bot >
              SizedBox(
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _requestOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Send OTP to Telegram Bot',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // OR Divider
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'OR',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                ],
              ),

              const SizedBox(height: 20),

              // Login with Telegram (Open Bot card)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.qr_code_2_rounded, color: Color(0xFF2563EB), size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Login with Telegram',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Open Telegram and click the button below to login instantly.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _tg.openTelegramLink('https://t.me/Examplayer_bot'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.send_rounded, size: 13, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              'Open Bot',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // OTP Sent Verification View
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_read_rounded, color: Color(0xFF059669), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OTP Sent Successfully!',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF065F46),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enter the 6-digit code sent to Telegram ID: ${_telegramIdController.text}',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Enter 6-Digit OTP',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  hintText: '••••••',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 22,
                    letterSpacing: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.security_rounded,
                    size: 20,
                    color: Color(0xFF2563EB),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
                  ),
                ),
                onSubmitted: (_) => _verifyOtp(),
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.verified_user_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Verify & Enter Console',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _otpSent = false;
                            _otpController.clear();
                          }),
                  icon: const Icon(Icons.arrow_back_rounded, size: 14),
                  label: const Text('Resend / Change Telegram ID'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ] else ...[
            // Master Password Mode View
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF2563EB), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Master Key Authorization',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Authenticate directly using the system admin master password.',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Master Password',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                hintText: 'Enter Admin Master Password',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: Color(0xFF2563EB),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: const Color(0xFF2563EB),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
                ),
              ),
              onSubmitted: (_) => _loginWithPassword(),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.vpn_key_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Authenticate & Enter Console',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Dot Grid Matrix Custom Painter
// -------------------------------------------------------------
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    const spacing = 16.0;
    const radius = 1.5;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// 3D Telegram Artwork Widget
// -------------------------------------------------------------
class _Telegram3DArtworkWidget extends StatelessWidget {
  const _Telegram3DArtworkWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Radial Cyan Backdrop Glow
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A3FF).withValues(alpha: 0.35),
                  blurRadius: 70,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),

          // Luminous Orbital Ring
          Transform.rotate(
            angle: -math.pi / 5.5,
            child: Container(
              width: 230,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.elliptical(230, 110)),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.65),
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A3FF).withValues(alpha: 0.5),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Glowing 3D Glass Shield Centerpiece
          Transform.rotate(
            angle: -0.06,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00B0FF),
                    Color(0xFF0077E6),
                    Color(0xFF0052CC),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(
                  color: const Color(0xFF7DD3FC).withValues(alpha: 0.8),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A3FF).withValues(alpha: 0.6),
                    blurRadius: 36,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(64, 64),
                  painter: _TelegramAirplanePainter(),
                ),
              ),
            ),
          ),

          // Floating Glass Badge 1: Top-Right (Users)
          Positioned(
            top: 24,
            right: 18,
            child: _buildFloatingBadge(
              icon: Icons.groups_rounded,
              iconColor: const Color(0xFF60A5FA),
              glowColor: const Color(0xFF3B82F6),
            ),
          ),

          // Floating Glass Badge 2: Right-Middle (Analytics)
          Positioned(
            right: -6,
            bottom: 74,
            child: _buildFloatingBadge(
              icon: Icons.bar_chart_rounded,
              iconColor: const Color(0xFFA78BFA),
              glowColor: const Color(0xFF8B5CF6),
            ),
          ),

          // Floating Glass Badge 3: Bottom-Left (Tests / Content)
          Positioned(
            bottom: 24,
            left: 12,
            child: _buildFloatingBadge(
              icon: Icons.article_rounded,
              iconColor: const Color(0xFF2DD4BF),
              glowColor: const Color(0xFF14B8A6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBadge({
    required IconData icon,
    required Color iconColor,
    required Color glowColor,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: glowColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

// -------------------------------------------------------------
// Iconic Telegram Paper Airplane Custom Painter
// -------------------------------------------------------------
class _TelegramAirplanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Main Wing Body (Pure White)
    final mainPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final mainPath = Path()
      ..moveTo(w * 0.90, h * 0.16) // Nose tip
      ..lineTo(w * 0.12, h * 0.50) // Left rear corner
      ..lineTo(w * 0.38, h * 0.62) // Center fold
      ..lineTo(w * 0.78, h * 0.86) // Right rear corner
      ..close();

    canvas.drawPath(mainPath, mainPaint);

    // Left Underwing Crease (Subtle sky shadow)
    final shadowPaint = Paint()
      ..color = const Color(0xFFD4E7F7)
      ..style = PaintingStyle.fill;

    final shadowPath = Path()
      ..moveTo(w * 0.38, h * 0.62)
      ..lineTo(w * 0.48, h * 0.84)
      ..lineTo(w * 0.56, h * 0.72)
      ..close();

    canvas.drawPath(shadowPath, shadowPaint);

    // Center Crease Line
    final creasePaint = Paint()
      ..color = const Color(0xFFB9D7F2)
      ..style = PaintingStyle.fill;

    final creasePath = Path()
      ..moveTo(w * 0.90, h * 0.16)
      ..lineTo(w * 0.38, h * 0.62)
      ..lineTo(w * 0.56, h * 0.72)
      ..close();

    canvas.drawPath(creasePath, creasePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
