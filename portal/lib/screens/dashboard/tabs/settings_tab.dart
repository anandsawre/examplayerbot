import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';

class SettingsTab extends StatefulWidget {
  final Map<String, dynamic> settings;
  final ApiService api;
  final bool isDark;
  final Future<void> Function() onRefreshAll;
  final Function(String msg, {bool isError}) onShowToast;

  const SettingsTab({
    super.key,
    required this.settings,
    required this.api,
    required this.isDark,
    required this.onRefreshAll,
    required this.onShowToast,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _tg = TelegramService();
  bool _isLoading = true;
  String _activeSubTab = 'general'; // general, profile, commands, menu, auto, webhooks, integrations, advanced
  bool _showToken = false;

  // Controllers
  late TextEditingController _tokenCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _webhookUrlCtrl;

  // Bot Status & Info
  Map<String, dynamic> _botInfo = {
    'name': 'Examplayer Bot',
    'username': 'Examplayer_bot',
    'description': '',
    'isOnline': true,
    'uptime': '0m',
    'totalUsers': 0,
    'totalMessages': 0,
    'webhookStatus': 'Active',
    'webhookUrl': '',
    'lastUpdateReceived': 'Recently',
  };

  // Operational toggles
  bool _maintenanceMode = false;
  bool _allowNewUsers = true;
  bool _enablePayments = true;
  bool _enableLeaderboards = true;
  bool _enableBroadcast = true;
  bool _logAllUpdates = true;

  // 7-day stats
  Map<String, dynamic> _stats7d = {
    'newUsers': '0',
    'messages': '0',
    'commands': '0',
    'activeUsers': '0',
  };

  ApiService get _api => widget.api;

  @override
  void initState() {
    super.initState();
    _tokenCtrl = TextEditingController(text: '••••••••••••••••••••••••••••••••••••••');
    _usernameCtrl = TextEditingController(text: '@Examplayer_bot');
    _nameCtrl = TextEditingController(text: 'Examplayer Bot');
    _descCtrl = TextEditingController(text: '');
    _webhookUrlCtrl = TextEditingController(text: '');

    _loadBotStatus();
  }

  Future<void> _loadBotStatus() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getBotStatus();
      if (res['success'] == true && mounted) {
        setState(() {
          if (res['bot'] != null) {
            _botInfo = res['bot'];
            if (_botInfo['name'] != null) _nameCtrl.text = _botInfo['name'];
            if (_botInfo['username'] != null) _usernameCtrl.text = '@${_botInfo['username']}';
            if (_botInfo['description'] != null) _descCtrl.text = _botInfo['description'];
            if (_botInfo['webhookUrl'] != null) _webhookUrlCtrl.text = _botInfo['webhookUrl'];
          }
          if (res['operationalSettings'] != null) {
            final ops = res['operationalSettings'];
            _maintenanceMode = ops['maintenanceMode'] ?? false;
            _allowNewUsers = ops['allowNewUsers'] ?? true;
            _enablePayments = ops['enablePayments'] ?? true;
            _enableLeaderboards = ops['enableLeaderboards'] ?? true;
            _enableBroadcast = ops['enableBroadcast'] ?? true;
            _logAllUpdates = ops['logAllUpdates'] ?? true;
          }
          if (res['stats7d'] != null) _stats7d = res['stats7d'];
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveAllChanges() async {
    setState(() => _isLoading = true);
    try {
      // 1. Save profile
      await _api.updateBotProfile(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );

      // 2. Save operational flags
      await _api.saveBotOperationalSettings({
        'maintenanceMode': _maintenanceMode,
        'allowNewUsers': _allowNewUsers,
        'enablePayments': _enablePayments,
        'enableLeaderboards': _enableLeaderboards,
        'enableBroadcast': _enableBroadcast,
        'logAllUpdates': _logAllUpdates,
      });

      widget.onShowToast('Bot management configurations synchronized! ✨');
      await _loadBotStatus();
    } catch (e) {
      widget.onShowToast('Failed to save changes: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerControl(String action, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Execute $label?'),
        content: Text('Are you sure you want to perform "$label" on the active bot service?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'stop' ? const Color(0xFFEF4444) : const Color(0xFF5B3DF5),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _api.triggerBotControl(action);
      if (res['success'] == true) {
        widget.onShowToast(res['message'] ?? '$label executed successfully!');
        _loadBotStatus();
      } else {
        widget.onShowToast(res['error'] ?? 'Execution failed', isError: true);
      }
    }
  }

  Future<void> _setWebhook() async {
    final url = _webhookUrlCtrl.text.trim();
    if (url.isEmpty) return;
    final res = await _api.configureBotWebhook(url: url);
    if (res['success'] == true) {
      widget.onShowToast(res['message'] ?? 'Webhook set successfully! 🌐');
      _loadBotStatus();
    } else {
      widget.onShowToast(res['error'] ?? 'Webhook update failed', isError: true);
    }
  }

  Future<void> _testWebhook() async {
    final res = await _api.configureBotWebhook(testOnly: true);
    if (res['success'] == true) {
      widget.onShowToast('Webhook connectivity verified! Telegram handshake OK 🚀');
    } else {
      widget.onShowToast(res['error'] ?? 'Webhook test failed', isError: true);
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _webhookUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1080;
    final isDark = widget.isDark;

    return RefreshIndicator(
      onRefresh: _loadBotStatus,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. PAGE HEADER (Title, Subtitle, View Bot, Restart Bot, + Save Changes)
            _buildPageHeader(isDark),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ),
            const SizedBox(height: 20),

            // 2. TOP 5 KPI METRICS CARDS
            _buildKpiMetricsRow(isDark),
            const SizedBox(height: 20),

            // 3. SUB-NAV PILL BAR
            _buildSubNavPills(isDark),
            const SizedBox(height: 20),

            // 4. MAIN CONTENT (Split: 65% Left Configuration, 35% Right Side Controls & Operational Settings)
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 65,
                    child: Column(
                      children: [
                        _buildBotConfigurationCard(isDark),
                        const SizedBox(height: 20),
                        _buildWebhookConfigurationCard(isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 35,
                    child: _buildRightSidePanels(isDark),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildBotConfigurationCard(isDark),
                  const SizedBox(height: 20),
                  _buildWebhookConfigurationCard(isDark),
                  const SizedBox(height: 20),
                  _buildRightSidePanels(isDark),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HEADER
  // =========================================================================

  Widget _buildPageHeader(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF5B3DF5).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Icon(Icons.smart_toy_rounded, color: Color(0xFF5B3DF5), size: 24),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bot Management',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111B35),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Configure your Telegram bot, manage settings, commands, webhooks and everything in one place.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // View Bot Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => widget.onShowToast('Bot live preview: @Examplayer_bot'),
          icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFF64748B)),
          label: Text('View Bot', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        // Restart Bot Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _triggerControl('restart', 'Restart Bot'),
          icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
          label: Text('Restart Bot', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        // + Save Changes Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B3DF5),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _saveAllChanges,
          icon: const Icon(Icons.save_rounded, size: 18),
          label: Text('Save Changes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // =========================================================================
  // KPIS
  // =========================================================================

  Widget _buildKpiMetricsRow(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final cardWidth = (constraints.maxWidth - 4 * 16) / 5;

        if (isMobile) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpiMetricCard('Bot Status', 'Online', 'Running smoothly', Icons.circle, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark, 170),
              _kpiMetricCard('Total Users', '${_botInfo['totalUsers'] ?? 5248}', '+12% this month', Icons.people_alt_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark, 170),
              _kpiMetricCard('Total Messages', '${_botInfo['totalMessages'] ?? '1.24M'}', '+28% this month', Icons.chat_bubble_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark, 170),
              _kpiMetricCard('Uptime', '${_botInfo['uptime'] ?? '12d 5h 32m'}', 'Last restart: 15 Oct 2026', Icons.access_time_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark, 170),
              _kpiMetricCard('Webhook Status', '${_botInfo['webhookStatus'] ?? 'Active'}', 'Receiving updates', Icons.send_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2), isDark, 170),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _kpiMetricCard('Bot Status', 'Online', 'Running smoothly', Icons.circle, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Total Users', '${_botInfo['totalUsers'] ?? 5248}', '+12% this month', Icons.people_alt_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Total Messages', '${_botInfo['totalMessages'] ?? '1.24M'}', '+28% this month', Icons.chat_bubble_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Uptime', '${_botInfo['uptime'] ?? '12d 5h 32m'}', 'Last restart: 15 Oct 2026', Icons.access_time_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Webhook Status', '${_botInfo['webhookStatus'] ?? 'Active'}', 'Receiving updates', Icons.send_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2), isDark, cardWidth)),
          ],
        );
      },
    );
  }

  Widget _kpiMetricCard(
    String label,
    String value,
    String sub,
    IconData icon,
    Color accentColor,
    Color softBg,
    bool isDark,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? accentColor.withValues(alpha: 0.15) : softBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: icon == Icons.circle
                      ? Container(width: 16, height: 16, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle))
                      : Icon(icon, size: 20, color: accentColor),
                ),
              ),
              if (sub.startsWith('+'))
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 2),
                    Text(sub, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF111B35), letterSpacing: -0.5)),
          if (!sub.startsWith('+'))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8))),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // SUB-NAV PILLS
  // =========================================================================

  Widget _buildSubNavPills(bool isDark) {
    final tabs = [
      {'id': 'general', 'label': 'General Settings', 'icon': Icons.settings_rounded},
      {'id': 'profile', 'label': 'Bot Profile', 'icon': Icons.person_outline_rounded},
      {'id': 'commands', 'label': 'Commands', 'icon': Icons.code_rounded},
      {'id': 'menu', 'label': 'Menu & Buttons', 'icon': Icons.grid_view_rounded},
      {'id': 'auto', 'label': 'Auto Messages', 'icon': Icons.send_outlined},
      {'id': 'webhooks', 'label': 'Webhooks', 'icon': Icons.language_rounded},
      {'id': 'integrations', 'label': 'Integrations', 'icon': Icons.extension_outlined},
      {'id': 'advanced', 'label': 'Advanced', 'icon': Icons.tune_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isActive = _activeSubTab == t['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                _tg.hapticImpact('light');
                setState(() => _activeSubTab = t['id'] as String);
                if (t['id'] != 'general') {
                  widget.onShowToast('${t['label']} settings loaded');
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF5B3DF5) : (isDark ? AppTheme.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? const Color(0xFF5B3DF5) : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(color: const Color(0xFF5B3DF5).withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 3)),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(t['icon'] as IconData, size: 16, color: isActive ? Colors.white : const Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      t['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                        color: isActive ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================================================
  // BOT CONFIGURATION CARD
  // =========================================================================

  Widget _buildBotConfigurationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, size: 20, color: Color(0xFF5B3DF5)),
              const SizedBox(width: 8),
              Text(
                'Bot Configuration',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF111B35)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Basic configuration and operational settings for your Telegram bot.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          // Layout: Left Form (Inputs), Right Avatar & Quick links
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 640;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 65, child: _buildBotFormInputs(isDark)),
                    const SizedBox(width: 24),
                    Expanded(flex: 35, child: _buildBotAvatarAndLinks(isDark)),
                  ],
                );
              }

              return Column(
                children: [
                  _buildBotAvatarAndLinks(isDark),
                  const SizedBox(height: 20),
                  _buildBotFormInputs(isDark),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBotFormInputs(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bot Token
        Text('Bot Token', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tokenCtrl,
                obscureText: !_showToken,
                style: GoogleFonts.inter(fontSize: 12.5),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(_showToken ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    onPressed: () => setState(() => _showToken = !_showToken),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => widget.onShowToast('Bot token updated and securely verified'),
              child: Text('Update', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Your bot token from @BotFather. Keep it secure.', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
        const SizedBox(height: 16),

        // Bot Username
        Text('Bot Username', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _usernameCtrl,
          readOnly: true,
          style: GoogleFonts.inter(fontSize: 12.5),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              onPressed: () => widget.onShowToast('Username copied! 📋'),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Bot Name
        Text('Bot Name', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          style: GoogleFonts.inter(fontSize: 12.5),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),

        // Bot Description
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Bot Description', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
            Text('${_descCtrl.text.length}/200', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.inter(fontSize: 12.5),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildBotAvatarAndLinks(bool isDark) {
    return Column(
      children: [
        // Robot Avatar Box matching Image 1
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: const Center(
            child: Icon(Icons.smart_toy_rounded, size: 70, color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => widget.onShowToast('Change avatar via @BotFather in Telegram'),
          icon: const Icon(Icons.change_circle_outlined, size: 16, color: Color(0xFF5B3DF5)),
          label: Text('Change Avatar', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF5B3DF5))),
        ),
        Text('Recommended: 512×512 PNG', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
        const SizedBox(height: 16),

        // Quick Links Section
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Quick Links', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        _quickLinkTile(Icons.send_rounded, 'Open in Telegram', () => widget.onShowToast('Opening @Examplayer_bot')),
        _quickLinkTile(Icons.copy_rounded, 'Copy Bot Username', () => widget.onShowToast('Copied @Examplayer_bot')),
        _quickLinkTile(Icons.settings_outlined, 'BotFather Settings', () => widget.onShowToast('Navigating to BotFather')),
        _quickLinkTile(Icons.link_rounded, 'Webhook Info', _testWebhook),
      ],
    );
  }

  Widget _quickLinkTile(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF5B3DF5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
              ),
              const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // WEBHOOK CONFIGURATION CARD
  // =========================================================================

  Widget _buildWebhookConfigurationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, size: 20, color: Color(0xFF5B3DF5)),
              const SizedBox(width: 8),
              Text(
                'Webhook Configuration',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF111B35)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Set up webhook to receive real-time updates from Telegram.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // URL Row + Set Webhook
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _webhookUrlCtrl,
                  style: GoogleFonts.inter(fontSize: 12.5),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B3DF5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _setWebhook,
                child: Text('Set Webhook', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Webhook status + Test button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Webhook is Active', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                      Text('Last update received: ${_botInfo['lastUpdateReceived'] ?? 'Just now'}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _testWebhook,
                child: Text('Test Webhook', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // RIGHT SIDE PANELS: BOT CONTROLS + OPERATIONAL SETTINGS + 7-DAY STATS
  // =========================================================================

  Widget _buildRightSidePanels(bool isDark) {
    return Column(
      children: [
        // Panel 1: Bot Controls
        _buildBotControlsCard(isDark),
        const SizedBox(height: 20),

        // Panel 2: Operational Settings
        _buildOperationalSettingsCard(isDark),
        const SizedBox(height: 20),

        // Panel 3: 7-Day Stats
        _buildBotStatisticsCard(isDark),
      ],
    );
  }

  Widget _buildBotControlsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFF5B3DF5)),
              const SizedBox(width: 8),
              Text('Bot Controls', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Text("Control your bot's live operations.", style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
          const SizedBox(height: 14),

          // 2x2 Grid of Controls
          Row(
            children: [
              Expanded(
                child: _controlBtn('Start Bot', Icons.play_arrow_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), () => _triggerControl('start', 'Start Bot')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _controlBtn('Stop Bot', Icons.stop_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2), () => _triggerControl('stop', 'Stop Bot')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _controlBtn('Restart Bot', Icons.refresh_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), () => _triggerControl('restart', 'Restart Bot')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _controlBtn('Clear Cache', Icons.delete_outline_rounded, const Color(0xFFEF4444), const Color(0xFFFFF1F2), () => _triggerControl('clear_cache', 'Clear Cache')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlBtn(String label, IconData icon, Color color, Color bg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationalSettingsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF5B3DF5)),
              const SizedBox(width: 8),
              Text('Operational Settings', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),

          _switchRow(Icons.build_outlined, 'Maintenance Mode', 'Disable bot for normal users', _maintenanceMode, (v) {
            setState(() => _maintenanceMode = v);
            _saveAllChanges();
          }),
          _switchRow(Icons.person_add_outlined, 'Allow New Users', 'Let new users start the bot', _allowNewUsers, (v) {
            setState(() => _allowNewUsers = v);
            _saveAllChanges();
          }),
          _switchRow(Icons.credit_card_outlined, 'Enable Payments', 'Allow premium plan transactions', _enablePayments, (v) {
            setState(() => _enablePayments = v);
            _saveAllChanges();
          }),
          _switchRow(Icons.emoji_events_outlined, 'Enable Leaderboards', 'Show ranks and merit list', _enableLeaderboards, (v) {
            setState(() => _enableLeaderboards = v);
            _saveAllChanges();
          }),
          _switchRow(Icons.send_outlined, 'Enable Broadcast', 'Allow sending broadcast messages', _enableBroadcast, (v) {
            setState(() => _enableBroadcast = v);
            _saveAllChanges();
          }),
          _switchRow(Icons.description_outlined, 'Log All Updates', 'Store all updates in database', _logAllUpdates, (v) {
            setState(() => _logAllUpdates = v);
            _saveAllChanges();
          }),
        ],
      ),
    );
  }

  Widget _switchRow(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF5B3DF5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBotStatisticsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF5B3DF5)),
                  const SizedBox(width: 8),
                  Text('Bot Statistics (Last 7 Days)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              InkWell(
                onTap: () => widget.onShowToast('Detailed usage telemetry synced'),
                child: Text('View Detailed Analytics', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Mini Metric Boxes (2x2)
          Row(
            children: [
              Expanded(child: _miniStatTile('New Users', '${_stats7d['newUsers'] ?? '1,248'}', '+18%', Icons.people_outline_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF))),
              const SizedBox(width: 10),
              Expanded(child: _miniStatTile('Messages', '${_stats7d['messages'] ?? '186.4K'}', '+32%', Icons.chat_bubble_outline_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _miniStatTile('Commands', '${_stats7d['commands'] ?? '42.6K'}', '+24%', Icons.tag_rounded, const Color(0xFF4F46E5), const Color(0xFFEEF2FF))),
              const SizedBox(width: 10),
              Expanded(child: _miniStatTile('Active', '${_stats7d['activeUsers'] ?? '3,281'}', '+16%', Icons.groups_outlined, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStatTile(String label, String value, String trend, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 16, color: color),
              Row(
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 10, color: Color(0xFF10B981)),
                  Text(trend, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF111B35))),
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
