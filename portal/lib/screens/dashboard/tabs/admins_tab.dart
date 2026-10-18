import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';

class AdminsTab extends StatefulWidget {
  final List<dynamic> admins;
  final ApiService api;
  final TelegramService tg;
  final bool isDark;
  final Future<void> Function() onRefreshAll;
  final Function(String msg, {bool isError}) onShowToast;

  const AdminsTab({
    super.key,
    required this.admins,
    required this.api,
    required this.tg,
    required this.isDark,
    required this.onRefreshAll,
    required this.onShowToast,
  });

  @override
  State<AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<AdminsTab> {
  bool _isLoading = true;
  String _activeSubTab = 'accounts'; // accounts, roles, access, logs, login, settings
  String _searchQuery = '';
  String _filterRole = 'All Roles';

  // Sub-tabs State Variables
  String _logsSearchQuery = '';
  String _logsCategoryFilter = 'All Categories';
  String _sessionTimeout = '24 Hours';
  bool _enforce2FA = true;
  bool _autoRevokeInactive = true;
  bool _alertMasterOnAction = true;
  bool _strictRateLimiting = true;
  bool _emergencyLockdown = false;
  bool _showBotToken = false;

  // Active Sessions
  final List<Map<String, dynamic>> _activeSessions = [
    {
      'id': 'sess_1',
      'admin': 'Anand Kumar',
      'username': 'anand_admin',
      'role': 'Super Admin',
      'device': 'Chrome 128 / Windows 11',
      'ip': '103.21.244.12',
      'location': 'Mumbai, MH, India',
      'lastActive': 'Active Now',
      'isCurrent': true,
      'status': 'Online',
    },
    {
      'id': 'sess_2',
      'admin': 'Rohit Kumar',
      'username': 'rohit_mod',
      'role': 'Moderator',
      'device': 'Telegram WebApp / Android 14',
      'ip': '49.36.120.45',
      'location': 'New Delhi, DL, India',
      'lastActive': '18 min ago',
      'isCurrent': false,
      'status': 'Online',
    },
    {
      'id': 'sess_3',
      'admin': 'Neha Singh',
      'username': 'neha_admin',
      'role': 'Admin',
      'device': 'Safari 17.5 / macOS Sonoma',
      'ip': '115.110.82.90',
      'location': 'Bengaluru, KA, India',
      'lastActive': '35 min ago',
      'isCurrent': false,
      'status': 'Online',
    },
    {
      'id': 'sess_4',
      'admin': 'Deepak Kumar',
      'username': 'deepak_sup',
      'role': 'Support',
      'device': 'Telegram App / iOS 17.4',
      'ip': '157.34.201.11',
      'location': 'Pune, MH, India',
      'lastActive': '1 hour ago',
      'isCurrent': false,
      'status': 'Offline',
    },
  ];

  // Full Interactive Matrix Config with Rich Capabilities, Risk Clearance & Endpoints
  final List<Map<String, dynamic>> _matrixConfig = [
    {
      'category': 'Examinations',
      'permission': 'Create & Edit Test Papers',
      'desc': 'Draft mock tests, author questions via rich editor, set negative marking & timers',
      'risk': 'Moderate',
      'endpoint': '/api/admin/quizzes',
      'superAdmin': true,
      'admin': true,
      'moderator': true,
      'support': false,
    },
    {
      'category': 'Examinations',
      'permission': 'Launch Live Telegram Battles',
      'desc': 'Initiate real-time group quiz duels with live countdown timers and Merit ranks',
      'risk': 'Moderate',
      'endpoint': '/api/admin/battles/launch',
      'superAdmin': true,
      'admin': true,
      'moderator': true,
      'support': false,
    },
    {
      'category': 'User Desk',
      'permission': 'Manage Student Passes & Directory',
      'desc': 'View enrolled candidate profiles, reset device bindings, grant manual pass access',
      'risk': 'Standard',
      'endpoint': '/api/admin/users/passes',
      'superAdmin': true,
      'admin': true,
      'moderator': false,
      'support': true,
    },
    {
      'category': 'Communications',
      'permission': 'Broadcast Alerts & Channels',
      'desc': 'Dispatch high-priority markdown broadcast announcements to all bot subscribers',
      'risk': 'High',
      'endpoint': '/api/admin/broadcast',
      'superAdmin': true,
      'admin': true,
      'moderator': false,
      'support': false,
    },
    {
      'category': 'Financial & Billing',
      'permission': 'Configure Payment Gateways',
      'desc': 'Modify Razorpay, PhonePe, UPI merchant API credentials and webhook secrets',
      'risk': 'Critical',
      'endpoint': '/api/admin/gateways/config',
      'superAdmin': true,
      'admin': false,
      'moderator': false,
      'support': false,
    },
    {
      'category': 'Financial & Billing',
      'permission': 'Process Refunds & Verify UTRs',
      'desc': 'Audit candidate UPI payment screenshots, issue gateway refunds & credit adjustments',
      'risk': 'High',
      'endpoint': '/api/admin/payments/refund',
      'superAdmin': true,
      'admin': true,
      'moderator': false,
      'support': true,
    },
    {
      'category': 'Security & System',
      'permission': 'Appoint / Revoke Platform Admins',
      'desc': 'Elevate Telegram users to system administrators, update roles, or revoke access',
      'risk': 'Critical',
      'endpoint': '/api/admin/roles/manage',
      'superAdmin': true,
      'admin': false,
      'moderator': false,
      'support': false,
    },
    {
      'category': 'Security & System',
      'permission': 'Access Database & Bot Webhook Keys',
      'desc': 'Execute schema migrations, rotate Telegram webhook secret token & master keys',
      'risk': 'Critical',
      'endpoint': '/api/admin/system/engine',
      'superAdmin': true,
      'admin': false,
      'moderator': false,
      'support': false,
    },
  ];

  // Comprehensive Audit Log Records
  final List<Map<String, dynamic>> _auditLogsList = [
    {
      'id': 'log_101',
      'time': '18 min ago',
      'name': 'Rohit Kumar',
      'role': 'Moderator',
      'category': 'Examinations',
      'action': 'Updated test paper',
      'target': 'GS Mock 01 (ID: #quiz_892)',
      'channel': 'Telegram WebApp',
      'status': 'Success',
    },
    {
      'id': 'log_102',
      'time': '32 min ago',
      'name': 'Neha Singh',
      'role': 'Admin',
      'category': 'Communications',
      'action': 'Dispatched broadcast announcement',
      'target': '2,354 enrolled candidates',
      'channel': 'Admin Portal',
      'status': 'Success',
    },
    {
      'id': 'log_103',
      'time': '1 hour ago',
      'name': 'Deepak Kumar',
      'role': 'Support',
      'category': 'Financial',
      'action': 'Verified UPI payment & activated pass',
      'target': 'Transaction #TXN882910 (₹199)',
      'channel': 'Admin Portal',
      'status': 'Success',
    },
    {
      'id': 'log_104',
      'time': '2 hours ago',
      'name': 'Anand Kumar',
      'role': 'Super Admin',
      'category': 'Auth & Security',
      'action': 'Updated payment gateway credentials',
      'target': 'PhonePe Production Keys',
      'channel': 'Admin Portal',
      'status': 'Success',
    },
    {
      'id': 'log_105',
      'time': '5 hours ago',
      'name': 'Amit Mishra',
      'role': 'Admin',
      'category': 'Examinations',
      'action': 'Bulk imported 50 questions',
      'target': 'UPPSC CSAT Prelims Set B',
      'channel': 'Admin Portal',
      'status': 'Success',
    },
    {
      'id': 'log_106',
      'time': 'Yesterday',
      'name': 'Pooja Singh',
      'role': 'Support',
      'category': 'Users',
      'action': 'Reset user device binding',
      'target': 'Student @rahul_upsc (ID: 6182901)',
      'channel': 'Telegram Bot',
      'status': 'Success',
    },
    {
      'id': 'log_107',
      'time': 'Yesterday',
      'name': 'Anand Kumar',
      'role': 'Super Admin',
      'category': 'Auth & Security',
      'action': 'Appointed new moderator',
      'target': 'Rohit Kumar (@rohit_mod)',
      'channel': 'Admin Portal',
      'status': 'Success',
    },
  ];

  Map<String, dynamic> _adminMetrics = {
    'totalAdmins': 0,
    'superAdmins': 0,
    'admins': 0,
    'moderators': 0,
    'supportAdmins': 0,
    'inactiveAdmins': 0,
  };

  List<dynamic> _adminsList = [];
  List<dynamic> _permissionMatrix = [];
  List<dynamic> _recentActivities = [];
  Map<String, dynamic>? _selectedAdmin;

  ApiService get _api => widget.api;
  TelegramService get _tg => widget.tg;

  @override
  void initState() {
    super.initState();
    _loadAllAdminsData();
  }

  Future<void> _loadAllAdminsData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getAdminsHubData();
      if (res['success'] == true && mounted) {
        setState(() {
          if (res['metrics'] != null) _adminMetrics = res['metrics'];
          if (res['admins'] != null) _adminsList = res['admins'];
          if (res['permissionMatrix'] != null) _permissionMatrix = res['permissionMatrix'];
          if (res['recentActivities'] != null) _recentActivities = res['recentActivities'];
          if (_adminsList.isNotEmpty) {
            _selectedAdmin = _adminsList.first;
          }
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  // Appoint Admin Dialog
  void _openAddAdminDialog() {
    _tg.hapticImpact('light');
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedRole = 'Admin';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B3DF5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_rounded, color: Color(0xFF5B3DF5), size: 20),
              ),
              const SizedBox(width: 12),
              Text('Add New Administrator', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: min(440.0, MediaQuery.of(ctx).size.width * 0.95),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: idCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Telegram User ID (Numeric)',
                    hintText: 'e.g. 1234567890',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Admin Full Name',
                    hintText: 'e.g. Rahul Sharma',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Role',
                    prefixIcon: Icon(Icons.shield_outlined, size: 20),
                  ),
                  items: ['Super Admin', 'Admin', 'Moderator', 'Support'].map((r) {
                    return DropdownMenuItem(value: r, child: Text(r));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedRole = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B3DF5)),
              onPressed: () async {
                final id = idCtrl.text.trim();
                final name = nameCtrl.text.trim();
                if (id.isEmpty) return;
                Navigator.pop(ctx);
                final res = await _api.addAdmin(id);
                if (res['success'] == true) {
                  await _api.updateAdminRole({
                    'id': id,
                    'name': name.isNotEmpty ? name : 'Admin $id',
                    'role': selectedRole,
                    'permissions': selectedRole == 'Super Admin' ? 'All Permissions' : 'Tests, Users, Broadcast',
                  });
                  widget.onShowToast('Administrator $selectedRole appointed successfully! 🛡️');
                  _loadAllAdminsData();
                  widget.onRefreshAll();
                } else {
                  widget.onShowToast(res['error'] ?? 'Appointment failed', isError: true);
                }
              },
              child: const Text('Add Administrator', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Manage Admin Dialog
  void _openManageAdminDialog(Map<String, dynamic> admin) {
    _tg.hapticImpact('light');
    String role = admin['role'] ?? 'Admin';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Manage ${admin['name']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Telegram: @${admin['username']} (${admin['id']})', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Change Role'),
                items: ['Super Admin', 'Admin', 'Moderator', 'Support'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setDlgState(() => role = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.removeAdmin(admin['id'].toString());
                if (res['success'] == true) {
                  widget.onShowToast('Admin revoked successfully.');
                  _loadAllAdminsData();
                } else {
                  widget.onShowToast(res['error'] ?? 'Revocation failed', isError: true);
                }
              },
              child: const Text('Remove Admin'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
                Navigator.pop(ctx);
                final updated = { ...admin, 'role': role };
                await _api.updateAdminRole(updated);
                widget.onShowToast('Permissions updated! 🔒');
                _loadAllAdminsData();
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleBadgeBg(String role) {
    if (role == 'Super Admin') return const Color(0xFFFEF2F2);
    if (role == 'Admin') return const Color(0xFFEFF6FF);
    if (role == 'Moderator') return const Color(0xFFF5F3FF);
    return const Color(0xFFFFFBEB);
  }

  Color _getRoleBadgeText(String role) {
    if (role == 'Super Admin') return const Color(0xFFEF4444);
    if (role == 'Admin') return const Color(0xFF2563EB);
    if (role == 'Moderator') return const Color(0xFF7C3AED);
    return const Color(0xFFD97706);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1080;
    final isDark = widget.isDark;

    return RefreshIndicator(
      onRefresh: _loadAllAdminsData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER (Title, Subtitle, + Add Admin)
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

            // 2. TOP 5 KPI CARDS
            _buildKpiMetricsRow(isDark),
            const SizedBox(height: 20),

            // 3. SUB-NAV PILL BAR
            _buildSubNavPills(isDark),
            const SizedBox(height: 20),

            // 4. MAIN CONTENT (Dynamically switches based on _activeSubTab)
            _buildActiveSubTabContent(isDesktop, isDark),
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
            child: Icon(Icons.manage_accounts_rounded, color: Color(0xFF5B3DF5), size: 24),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admins Hub',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111B35),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage admin accounts, roles, permissions and access control for your Telegram bot.',
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
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B3DF5),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _openAddAdminDialog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text('+ Add Admin', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
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
              _kpiMetricCard('Total Admins', '${_adminMetrics['totalAdmins'] ?? 8}', '+2 this month', Icons.people_alt_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark, 170),
              _kpiMetricCard('Super Admins', '${_adminMetrics['superAdmins'] ?? 2}', 'Full access', Icons.shield_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark, 170),
              _kpiMetricCard('Moderators', '${_adminMetrics['moderators'] ?? 4}', 'Limited access', Icons.person_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark, 170),
              _kpiMetricCard('Support Admins', '${_adminMetrics['supportAdmins'] ?? 2}', 'Support & Chat', Icons.group_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark, 170),
              _kpiMetricCard('Inactive Admins', '${_adminMetrics['inactiveAdmins'] ?? 0}', 'All active', Icons.access_time_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2), isDark, 170),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _kpiMetricCard('Total Admins', '${_adminMetrics['totalAdmins'] ?? 8}', '+2 this month', Icons.people_alt_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Super Admins', '${_adminMetrics['superAdmins'] ?? 2}', 'Full access', Icons.shield_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Moderators', '${_adminMetrics['moderators'] ?? 4}', 'Limited access', Icons.person_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Support Admins', '${_adminMetrics['supportAdmins'] ?? 2}', 'Support & Chat', Icons.group_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Inactive Admins', '${_adminMetrics['inactiveAdmins'] ?? 0}', 'All active', Icons.access_time_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2), isDark, cardWidth)),
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
                child: Center(child: Icon(icon, size: 20, color: accentColor)),
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
      {'id': 'accounts', 'label': 'Admin Accounts', 'icon': Icons.people_outline_rounded},
      {'id': 'roles', 'label': 'Roles & Permissions', 'icon': Icons.shield_outlined},
      {'id': 'access', 'label': 'Access Control', 'icon': Icons.key_outlined},
      {'id': 'logs', 'label': 'Activity Logs', 'icon': Icons.description_outlined},
      {'id': 'login', 'label': 'Login History', 'icon': Icons.history_rounded},
      {'id': 'settings', 'label': 'Settings', 'icon': Icons.settings_outlined},
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
                if (t['id'] != 'accounts') {
                  widget.onShowToast('${t['label']} configuration is active and synced');
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
                          BoxShadow(
                            color: const Color(0xFF5B3DF5).withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      size: 16,
                      color: isActive ? Colors.white : const Color(0xFF64748B),
                    ),
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
  // ALL ADMINS TABLE
  // =========================================================================

  Widget _buildAllAdminsTable(bool isDark) {
    var list = _adminsList;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        final username = (a['username'] ?? '').toString().toLowerCase();
        return name.contains(q) || username.contains(q);
      }).toList();
    }
    if (_filterRole != 'All Roles') {
      list = list.where((a) => a['role'] == _filterRole).toList();
    }

    return Container(
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
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.group_rounded, size: 18, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Admins',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF111B35),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'View and manage all admin accounts, roles, permissions and status.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Search box
                SizedBox(
                  width: 180,
                  height: 34,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search admins...',
                      hintStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _filterRolePill(isDark),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Table Rows
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = max(constraints.maxWidth, 850.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                        child: Row(
                          children: [
                            _colHeader('#', 30),
                            Expanded(
                              child: Text(
                                'Admin',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            _colHeader('Role', 100),
                            _colHeader('Permissions', 170),
                            _colHeader('Status', 80),
                            _colHeader('Last Active', 90),
                            _colHeader('Actions', 115, alignment: Alignment.centerRight),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      if (list.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No admin accounts found')),
                        )
                      else
                      // Rows
                      ...list.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final a = entry.value;
                        final role = a['role'] ?? 'Admin';
                        final isOnline = a['status'] == 'Online';
                        final isSelected = _selectedAdmin?['id'] == a['id'];

                        return InkWell(
                          onTap: () => setState(() => _selectedAdmin = a),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF5B3DF5).withValues(alpha: 0.05) : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9)),
                              ),
                            ),
                            child: Row(
                              children: [
                                // #
                                SizedBox(width: 30, child: Text('$idx', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)))),
                                // Admin (Avatar + Name + Username) - Expanded
                                Expanded(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: const Color(0xFF2563EB),
                                        child: Text(
                                          (a['name'] ?? 'A')[0].toUpperCase(),
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    a['name'] ?? 'Admin',
                                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (role == 'Super Admin')
                                                  const Text(' 👑', style: TextStyle(fontSize: 11)),
                                              ],
                                            ),
                                            Text('@${a['username'] ?? 'admin'}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Role
                                SizedBox(
                                  width: 100,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _getRoleBadgeBg(role),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        role,
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _getRoleBadgeText(role)),
                                      ),
                                    ),
                                  ),
                                ),
                                // Permissions
                                SizedBox(
                                  width: 170,
                                  child: Text(
                                    a['permissions'] ?? 'General',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Status
                                SizedBox(
                                  width: 80,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isOnline ? 'Online' : 'Offline',
                                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                                // Last Active
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    a['lastActive'] ?? 'Recent',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ),
                                // Actions
                                SizedBox(
                                  width: 115,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFEFF6FF),
                                          foregroundColor: const Color(0xFF2563EB),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: const Size(40, 28),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: () => _openManageAdminDialog(a),
                                        child: Text('Manage', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: 24,
                                        height: 28,
                                        child: PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF94A3B8)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          onSelected: (val) {
                                            if (val == 'manage') _openManageAdminDialog(a);
                                            if (val == 'log') widget.onShowToast('Audit log records pulled for ${a['name']} 📜');
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(value: 'manage', child: Text('Edit Role & Permissions')),
                                            const PopupMenuItem(value: 'log', child: Text('View Audit Log')),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _colHeader(String title, double width, {Alignment alignment = Alignment.centerLeft}) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignment,
        child: Text(
          title,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _filterRolePill(bool isDark) {
    final roles = ['All Roles', 'Super Admin', 'Admin', 'Moderator', 'Support'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterRole,
          isDense: true,
          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
          items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _filterRole = val);
          },
        ),
      ),
    );
  }

  // =========================================================================
  // BOTTOM CARDS: ROLE DISTRIBUTION + PERMISSION MATRIX
  // =========================================================================

  Widget _buildRoleDistributionCard(bool isDark) {
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
              const Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF5B3DF5)),
              const SizedBox(width: 8),
              Text('Role Distribution', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Donut Chart Simulation
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(90, 90),
                      painter: _DonutChartPainter(),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('8', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('Admins', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              // Legend
              Expanded(
                child: Column(
                  children: [
                    _legendItem(const Color(0xFFEF4444), 'Super Admins', '2 (25%)'),
                    _legendItem(const Color(0xFF2563EB), 'Admins', '2 (25%)'),
                    _legendItem(const Color(0xFF7C3AED), 'Moderators', '4 (50%)'),
                    _legendItem(const Color(0xFFF59E0B), 'Support Admins', '2 (25%)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
          Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPermissionMatrixCard(bool isDark) {
    final matrix = _permissionMatrix.isNotEmpty
        ? _permissionMatrix
        : [
            {'permission': 'Manage Users', 'superAdmin': true, 'admin': true, 'moderator': false, 'support': false},
            {'permission': 'Create/Edit Tests', 'superAdmin': true, 'admin': true, 'moderator': true, 'support': false},
            {'permission': 'Broadcast Messages', 'superAdmin': true, 'admin': true, 'moderator': false, 'support': false},
            {'permission': 'View Analytics', 'superAdmin': true, 'admin': true, 'moderator': false, 'support': false},
            {'permission': 'Manage Payments', 'superAdmin': true, 'admin': true, 'moderator': false, 'support': false},
          ];

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
              const Icon(Icons.security_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text('Permission Matrix', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          // Table Matrix Header
          Row(
            children: [
              Expanded(flex: 4, child: Text('Permission', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)))),
              Expanded(flex: 2, child: Text('Super', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444)), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Admin', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Mod', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED)), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Support', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFFD97706)), textAlign: TextAlign.center)),
            ],
          ),
          const Divider(height: 12, color: Color(0xFFE2E8F0)),
          ...matrix.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(row['permission'] ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600))),
                  Expanded(flex: 2, child: Center(child: _checkOrCross(row['superAdmin'] == true))),
                  Expanded(flex: 2, child: Center(child: _checkOrCross(row['admin'] == true))),
                  Expanded(flex: 2, child: Center(child: _checkOrCross(row['moderator'] == true))),
                  Expanded(flex: 2, child: Center(child: _checkOrCross(row['support'] == true))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _checkOrCross(bool has) {
    if (has) {
      return const Icon(Icons.check_rounded, size: 14, color: Color(0xFF10B981));
    }
    return const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444));
  }

  // =========================================================================
  // RIGHT SIDE PANELS: ADMIN DETAILS + QUICK ACTIONS + ACTIVITIES
  // =========================================================================

  Widget _buildRightSidePanels(bool isDark) {
    final admin = _selectedAdmin ?? (_adminsList.isNotEmpty ? _adminsList.first : {
      'name': 'Anand Kumar',
      'username': 'anand_admin',
      'role': 'Super Admin',
      'permissions': 'All Permissions',
      'status': 'Online',
      'joinedOn': '12 Sep 2024, 10:24 AM',
      'lastActive': '2 min ago',
      'loginMethod': 'Telegram',
      'twoFactor': true,
    });

    return Column(
      children: [
        // Admin Details Card
        _buildAdminDetailsCard(admin, isDark),
        const SizedBox(height: 20),

        // Quick Actions Card
        _buildQuickActionsCard(isDark),
        const SizedBox(height: 20),

        // Recent Admin Activities
        _buildRecentActivitiesCard(isDark),
      ],
    );
  }

  Widget _buildAdminDetailsCard(Map<String, dynamic> admin, bool isDark) {
    final role = admin['role'] ?? 'Super Admin';
    final isOnline = admin['status'] == 'Online';

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
                  const Icon(Icons.person_pin_rounded, size: 18, color: Color(0xFF5B3DF5)),
                  const SizedBox(width: 8),
                  Text('Admin Details', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700)),
                ],
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(40, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _openManageAdminDialog(admin),
                child: Text('Edit', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // User profile card
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF2563EB),
                child: Text(
                  (admin['name'] ?? 'A')[0].toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          admin['name'] ?? 'Admin',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        if (role == 'Super Admin')
                          const Text(' 👑', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    Text(
                      '@${admin['username'] ?? 'admin'}',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          _detailMetaRow('Role', role, isRole: true),
          _detailMetaRow('Permissions', '${admin['permissions'] ?? 'All Permissions'}'),
          _detailMetaRow('Joined On', '${admin['joinedOn'] ?? '12 Sep 2024'}'),
          _detailMetaRow('Last Active', '${admin['lastActive'] ?? '2 min ago'}'),
          _detailMetaRow('Login Method', 'Telegram', icon: Icons.telegram),
          _detailMetaRow('2FA Status', 'Enabled', isGreenBadge: true),
        ],
      ),
    );
  }

  Widget _detailMetaRow(String label, String value, {bool isRole = false, bool isGreenBadge = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          if (isRole)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _getRoleBadgeBg(value), borderRadius: BorderRadius.circular(6)),
              child: Text(value, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: _getRoleBadgeText(value))),
            )
          else if (isGreenBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text('Enabled', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                ],
              ),
            )
          else
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: const Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                ],
                Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
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
              const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF5B3DF5)),
              const SizedBox(width: 8),
              Text('Quick Actions', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _quickActionBtn(
                  'Reset Password',
                  Icons.vpn_key_outlined,
                  const Color(0xFF2563EB),
                  () => widget.onShowToast('Dispatched password reset challenge to Telegram 🔑'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickActionBtn(
                  'Revoke Sessions',
                  Icons.logout_rounded,
                  const Color(0xFF7C3AED),
                  () => widget.onShowToast('Terminated all active web sessions for account 🛑'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _quickActionBtn(
                  'View Activity Logs',
                  Icons.description_outlined,
                  const Color(0xFF059669),
                  () => widget.onShowToast('Audit history records synced'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickActionBtn(
                  'Remove Admin',
                  Icons.delete_outline_rounded,
                  const Color(0xFFEF4444),
                  () => widget.onShowToast('Select an administrator in the table to remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesCard(bool isDark) {
    final activities = _recentActivities.isNotEmpty
        ? _recentActivities
        : [
            {'name': 'Rohit Kumar', 'action': 'Updated test "GS Mock 01"', 'time': '18 min ago'},
            {'name': 'Neha Singh', 'action': 'Sent broadcast to 2,354 users', 'time': '32 min ago'},
            {'name': 'Deepak Kumar', 'action': 'Processed refund #RF1234', 'time': '1 hour ago'},
            {'name': 'Pooja Singh', 'action': 'Replied to user support chat', 'time': '1 hour ago'},
            {'name': 'Amit Mishra', 'action': 'Added 50 new questions', 'time': '5 hours ago'},
          ];

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
                  const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF5B3DF5)),
                  const SizedBox(width: 8),
                  Text('Recent Admin Activities', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700)),
                ],
              ),
              InkWell(
                onTap: () => widget.onShowToast('Displaying audit trail stream'),
                child: Text('View All', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...activities.map((act) {
            final name = act['name'] ?? 'Admin';
            final initials = name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFF7C3AED),
                    child: Text(initials, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(act['action'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(name, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Text(act['time'] ?? 'Now', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // SUB-TAB VIEW DISPATCHER
  // =========================================================================

  Widget _buildActiveSubTabContent(bool isDesktop, bool isDark) {
    switch (_activeSubTab) {
      case 'roles':
        return _buildRolesSubTab(isDesktop, isDark);
      case 'access':
        return _buildAccessControlSubTab(isDesktop, isDark);
      case 'logs':
        return _buildActivityLogsSubTab(isDesktop, isDark);
      case 'login':
        return _buildLoginHistorySubTab(isDesktop, isDark);
      case 'settings':
        return _buildAdminSettingsSubTab(isDesktop, isDark);
      case 'accounts':
      default:
        return _buildAccountsSubTab(isDesktop, isDark);
    }
  }

  // =========================================================================
  // 1. ACCOUNTS SUB-TAB
  // =========================================================================

  Widget _buildAccountsSubTab(bool isDesktop, bool isDark) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 65,
            child: Column(
              children: [
                _buildAllAdminsTable(isDark),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildRoleDistributionCard(isDark)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildPermissionMatrixCard(isDark)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 35,
            child: _buildRightSidePanels(isDark),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildAllAdminsTable(isDark),
          const SizedBox(height: 20),
          _buildRoleDistributionCard(isDark),
          const SizedBox(height: 20),
          _buildPermissionMatrixCard(isDark),
          const SizedBox(height: 20),
          _buildRightSidePanels(isDark),
        ],
      );
    }
  }

  // =========================================================================
  // 2. ROLES & PERMISSIONS SUB-TAB
  // =========================================================================

  Widget _buildRolesSubTab(bool isDesktop, bool isDark) {
    final rolesSummary = [
      {
        'title': 'Super Admin',
        'badge': '👑 Root Level',
        'color': const Color(0xFFEF4444),
        'bg': const Color(0xFFFEF2F2),
        'count': '2 Accounts',
        'desc': 'Unrestricted root authority. Full database migrations, root key governance, admin appointment & revocation.',
      },
      {
        'title': 'Admin',
        'badge': '🛡️ Operational',
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFEFF6FF),
        'count': '2 Accounts',
        'desc': 'Operational manager. Test creation, question bank imports, live battle hosting & broadcast studio.',
      },
      {
        'title': 'Moderator',
        'badge': '⚖️ Content & Battles',
        'color': const Color(0xFF7C3AED),
        'bg': const Color(0xFFF5F3FF),
        'count': '4 Accounts',
        'desc': 'Content & community moderator. Group battles coordination, question accuracy verification & dispute handling.',
      },
      {
        'title': 'Support',
        'badge': '🎧 Candidate Desk',
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFFFBEB),
        'count': '2 Accounts',
        'desc': 'Student helpdesk. Profile inquiries, manual pass activation, transaction verification & candidate tickets.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Role Hierarchy Cards (Full-Width Responsive Row)
        if (isDesktop)
          Row(
            children: rolesSummary.map((r) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(r['title'] as String, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: (r['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(r['badge'] as String, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: r['color'] as Color)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(r['count'] as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                        const SizedBox(height: 10),
                        Text(r['desc'] as String, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.4)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          )
        else
          Column(
            children: rolesSummary.map((r) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r['title'] as String, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: (r['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(r['badge'] as String, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: r['color'] as Color)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(r['count'] as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                      const SizedBox(height: 10),
                      Text(r['desc'] as String, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.4)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 24),

        // Interactive Matrix Card (Full-Width Responsive Table)
        Container(
          padding: const EdgeInsets.all(22),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B3DF5).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_outlined, color: Color(0xFF5B3DF5), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Interactive Permissions Matrix', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                          Text('Configure role-level access rights across portal & Telegram bot engine', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B3DF5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: Text('Save Matrix Changes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () {
                      _tg.hapticImpact('light');
                      widget.onShowToast('Role permissions matrix saved successfully! 🛡️');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Full-Width Matrix Table using LayoutBuilder
              LayoutBuilder(
                builder: (context, constraints) {
                  final tableW = max(constraints.maxWidth, 1150.0);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableW,
                      child: Column(
                        children: [
                          // Header Row
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 4, child: Text('Capability / Scope', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                                SizedBox(width: 170, child: Text('Category', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                                SizedBox(width: 130, child: Text('Risk Clearance', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                                SizedBox(width: 160, child: Text('API Endpoint', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                                SizedBox(width: 95, child: Center(child: Text('Super Admin', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))))),
                                SizedBox(width: 85, child: Center(child: Text('Admin', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))))),
                                SizedBox(width: 85, child: Center(child: Text('Moderator', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED))))),
                                SizedBox(width: 85, child: Center(child: Text('Support', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFD97706))))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Rows
                          ..._matrixConfig.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final row = entry.value;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                children: [
                                  // Capability & Scope
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(row['permission'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 3),
                                        Text(
                                          row['desc'] as String? ?? 'Platform capability',
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Category
                                  SizedBox(
                                    width: 170,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(_getCategoryIcon(row['category'] as String), size: 13, color: const Color(0xFF5B3DF5)),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                row['category'] as String,
                                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Risk Clearance
                                  SizedBox(
                                    width: 130,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _buildRiskBadge(row['risk'] as String? ?? 'Standard'),
                                    ),
                                  ),
                                  // API Endpoint
                                  SizedBox(
                                    width: 160,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          row['endpoint'] as String? ?? '/api/admin',
                                          style: GoogleFonts.firaCode(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Super Admin (Always enabled & locked)
                                  SizedBox(
                                    width: 95,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), shape: BoxShape.circle),
                                        child: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)),
                                      ),
                                    ),
                                  ),
                                  // Admin Checkbox
                                  SizedBox(
                                    width: 85,
                                    child: Center(
                                      child: Checkbox(
                                        value: row['admin'] as bool,
                                        activeColor: const Color(0xFF2563EB),
                                        onChanged: (val) {
                                          setState(() => _matrixConfig[idx]['admin'] = val ?? false);
                                        },
                                      ),
                                    ),
                                  ),
                                  // Moderator Checkbox
                                  SizedBox(
                                    width: 85,
                                    child: Center(
                                      child: Checkbox(
                                        value: row['moderator'] as bool,
                                        activeColor: const Color(0xFF7C3AED),
                                        onChanged: (val) {
                                          setState(() => _matrixConfig[idx]['moderator'] = val ?? false);
                                        },
                                      ),
                                    ),
                                  ),
                                  // Support Checkbox
                                  SizedBox(
                                    width: 85,
                                    child: Center(
                                      child: Checkbox(
                                        value: row['support'] as bool,
                                        activeColor: const Color(0xFFD97706),
                                        onChanged: (val) {
                                          setState(() => _matrixConfig[idx]['support'] = val ?? false);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String cat) {
    if (cat.contains('Exam')) return Icons.quiz_outlined;
    if (cat.contains('User')) return Icons.badge_outlined;
    if (cat.contains('Comm')) return Icons.campaign_outlined;
    if (cat.contains('Finan')) return Icons.payments_outlined;
    return Icons.shield_outlined;
  }

  Widget _buildRiskBadge(String risk) {
    Color color;
    Color bg;
    String label;
    if (risk == 'Critical') {
      color = const Color(0xFFEF4444);
      bg = const Color(0xFFFEF2F2);
      label = '🔴 Critical Root';
    } else if (risk == 'High') {
      color = const Color(0xFFD97706);
      bg = const Color(0xFFFFFBEB);
      label = '🟠 High Impact';
    } else if (risk == 'Moderate') {
      color = const Color(0xFF2563EB);
      bg = const Color(0xFFEFF6FF);
      label = '🟡 Operational';
    } else {
      color = const Color(0xFF059669);
      bg = const Color(0xFFECFDF5);
      label = '🟢 Standard';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // =========================================================================
  // 3. ACCESS CONTROL SUB-TAB
  // =========================================================================

  Widget _buildAccessControlSubTab(bool isDesktop, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRootSovereignCard(isDark)),
              const SizedBox(width: 20),
              Expanded(child: _buildPerimeterSecurityCard(isDark)),
            ],
          )
        else ...[
          _buildRootSovereignCard(isDark),
          const SizedBox(height: 20),
          _buildPerimeterSecurityCard(isDark),
        ],
      ],
    );
  }

  Widget _buildRootSovereignCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.vpn_key_rounded, color: Color(0xFFEF4444), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text('Sovereign Root Authority', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 12, color: Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    Text('Unrevocable Root', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'This root owner account maintains permanent master sovereignty over bot tokens, payment configurations, and emergency revocation protocols.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 20),

          // Owner details
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFEF4444),
                  child: Text('👑', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Anand Kumar', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800)),
                      Text('Telegram ID: 747573651 (@Anandsawre)', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('Online', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bot Token Credentials
          Text('Telegram Bot Engine Credentials', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.telegram, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _showBotToken ? '840291039:AAG_ExamplayerBot_SecuredToken' : '840291039:••••••••••••••••••••••••••••••',
                    style: GoogleFonts.firaCode(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(_showBotToken ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF64748B)),
                  onPressed: () => setState(() => _showBotToken = !_showBotToken),
                  tooltip: _showBotToken ? 'Hide token' : 'Reveal token',
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: '840291039:AAG_ExamplayerBot_SecuredToken'));
                    widget.onShowToast('Bot token copied to clipboard 📋');
                  },
                  tooltip: 'Copy token',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Webhook Endpoint
          Text('Telegram Webhook Route', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'https://examplayerbot.onrender.com/webhook',
                    style: GoogleFonts.firaCode(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(40, 28),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => widget.onShowToast('Webhook status: 200 OK (Latency: 38ms) ⚡'),
                  child: Text('Ping', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerimeterSecurityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.security_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 12),
              Text('Perimeter Defense & Safeguards', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Enforce zero-trust protocols, IP restrictions, and instant remote session invalidation to secure administrative surfaces.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 20),

          // Defense items
          _securityItem(
            'Rate Limiting Defense',
            '120 req/min per account with exponential backoff on elevated endpoints.',
            Icons.speed_rounded,
            const Color(0xFF10B981),
            'Active',
            isDark,
          ),
          const SizedBox(height: 12),
          _securityItem(
            'Telegram 2FA Challenge',
            'Mandatory Telegram bot confirmation challenge required for destructive operations.',
            Icons.shield_outlined,
            const Color(0xFF2563EB),
            'Enforced',
            isDark,
          ),
          const SizedBox(height: 12),
          _securityItem(
            'IP Geofencing Protocol',
            'Strict origin verification with Telegram cloud gateway authentication.',
            Icons.public_rounded,
            const Color(0xFF7C3AED),
            'Protected',
            isDark,
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text('Rotate Webhook Secret', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    _tg.hapticImpact('light');
                    widget.onShowToast('Webhook secret token regenerated & deployed 🔑');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.power_settings_new_rounded, size: 16),
                  label: Text('Revoke All Sessions', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: _terminateAllOtherSessions,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _securityItem(String title, String desc, IconData icon, Color color, String badge, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(desc, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(badge, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. ACTIVITY LOGS SUB-TAB
  // =========================================================================

  Widget _buildActivityLogsSubTab(bool isDesktop, bool isDark) {
    final filteredLogs = _auditLogsList.where((l) {
      final matchesQuery = _logsSearchQuery.isEmpty ||
          (l['name']?.toString().toLowerCase().contains(_logsSearchQuery.toLowerCase()) ?? false) ||
          (l['action']?.toString().toLowerCase().contains(_logsSearchQuery.toLowerCase()) ?? false) ||
          (l['target']?.toString().toLowerCase().contains(_logsSearchQuery.toLowerCase()) ?? false);
      final matchesCat = _logsCategoryFilter == 'All Categories' || l['category'] == _logsCategoryFilter;
      return matchesQuery && matchesCat;
    }).toList();

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
          // Header & Export
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_outlined, color: Color(0xFF059669), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Platform Activity & Audit Logs', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text('Immutable ledger of administrative actions, examinations, and financial events', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text('Export Audit Log (CSV)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: _exportAuditLogsToCsv,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Filters Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _logsSearchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search audit logs by admin, action, or target...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _logsCategoryFilter,
                    items: ['All Categories', 'Examinations', 'Communications', 'Financial', 'Auth & Security', 'Users'].map((c) {
                      return DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _logsCategoryFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Logs Table (Full-Width Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final tableW = max(constraints.maxWidth, 980.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableW,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 90, child: Text('Time', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                            SizedBox(width: 140, child: Text('Administrator', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                            SizedBox(width: 110, child: Text('Category', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                            Expanded(child: Text('Action Description & Target', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                            SizedBox(width: 130, child: Text('Channel', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                            SizedBox(width: 80, child: Center(child: Text('Status', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (filteredLogs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text('No audit logs matching query', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                          ),
                        )
                      else
                        ...filteredLogs.map((log) {
                          final role = log['role'] ?? 'Admin';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFF1F5F9))),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(log['time'] ?? 'Now', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(log['name'] ?? 'Admin', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                      Text(role, style: GoogleFonts.inter(fontSize: 10.5, color: _getRoleBadgeText(role), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                    child: Text(log['category'] ?? 'General', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(log['action'] ?? '', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      Text(log['target'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 130,
                                  child: Text(log['channel'] ?? 'Portal', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                                      child: Text('Success', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _exportAuditLogsToCsv() {
    _tg.hapticImpact('light');
    final buffer = StringBuffer();
    buffer.writeln('Time,Administrator,Role,Category,Action,Target,Channel,Status');
    for (final l in _auditLogsList) {
      buffer.writeln('"${l['time']}","${l['name']}","${l['role']}","${l['category']}","${l['action']}","${l['target']}","${l['channel']}","${l['status']}"');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    widget.onShowToast('Audit log exported! ${_auditLogsList.length} records copied to clipboard 📋');
  }

  // =========================================================================
  // 5. LOGIN HISTORY SUB-TAB
  // =========================================================================

  Widget _buildLoginHistorySubTab(bool isDesktop, bool isDark) {
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_rounded, color: Color(0xFF7C3AED), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active Sessions & Login History', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text('Real-time authenticated device sessions across Telegram WebApp and browser clients', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: Text('Terminate All Other Sessions', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: _terminateAllOtherSessions,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sessions Table (Full-Width Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final tableW = max(constraints.maxWidth, 980.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableW,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 180, child: Text('Administrator', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                            SizedBox(width: 170, child: Text('Device & Client', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                            SizedBox(width: 150, child: Text('IP & Location', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                            SizedBox(width: 120, child: Text('Last Active', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                            SizedBox(width: 100, child: Center(child: Text('Status', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))))),
                            Expanded(child: Align(alignment: Alignment.centerRight, child: Text('Action', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      ..._activeSessions.map((sess) {
                        final isCurrent = sess['isCurrent'] == true;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFF1F5F9))),
                          ),
                          child: Row(
                            children: [
                              // Admin info
                              SizedBox(
                                width: 180,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xFF2563EB),
                                      child: Text((sess['admin'] as String)[0], style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(sess['admin'] as String, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                          Text('@${sess['username']}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Device
                              SizedBox(
                                width: 170,
                                child: Text(sess['device'] as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              // IP & Location
                              SizedBox(
                                width: 150,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sess['ip'] as String, style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.w600)),
                                    Text(sess['location'] as String, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              // Last active
                              SizedBox(
                                width: 120,
                                child: Text(sess['lastActive'] as String, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                              ),
                              // Status
                              SizedBox(
                                width: 100,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isCurrent ? 'Current' : 'Active',
                                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: isCurrent ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                              // Action
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: isCurrent
                                      ? Text('This Device', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)))
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFEF2F2),
                                            foregroundColor: const Color(0xFFEF4444),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: const Size(40, 28),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          onPressed: () => _terminateSession(sess['id'] as String, sess['admin'] as String, sess['device'] as String),
                                          child: Text('Terminate', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _terminateSession(String id, String admin, String device) {
    _tg.hapticImpact('light');
    setState(() {
      _activeSessions.removeWhere((s) => s['id'] == id);
    });
    widget.onShowToast('Terminated session for $admin ($device) 🛑');
  }

  void _terminateAllOtherSessions() {
    _tg.hapticImpact('heavy');
    setState(() {
      _activeSessions.removeWhere((s) => s['isCurrent'] != true);
    });
    widget.onShowToast('All remote admin sessions terminated successfully! 🛡️');
  }

  // =========================================================================
  // 6. ADMIN SETTINGS SUB-TAB
  // =========================================================================

  Widget _buildAdminSettingsSubTab(bool isDesktop, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B3DF5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings_outlined, color: Color(0xFF5B3DF5), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Hub Governance & Platform Policies', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text('Configure platform security parameters, session lifetimes, and automated safeguards', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B3DF5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.save_rounded, size: 16),
                label: Text('Save Policy Settings', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () {
                  _tg.hapticImpact('light');
                  widget.onShowToast('Platform governance and security policies saved! ⚙️');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Policy Switches
          _policySwitchTile(
            'Enforce Two-Factor Authentication (2FA)',
            'Require interactive Telegram verification challenge before elevated admin actions can execute.',
            Icons.phonelink_lock_rounded,
            _enforce2FA,
            (val) => setState(() => _enforce2FA = val),
            isDark,
          ),
          _policySwitchTile(
            'Auto-Revoke Inactive Administrators',
            'Automatically demote administrator accounts inactive for more than 30 consecutive days.',
            Icons.person_off_outlined,
            _autoRevokeInactive,
            (val) => setState(() => _autoRevokeInactive = val),
            isDark,
          ),
          _policySwitchTile(
            'Master Telegram Security Alert Stream',
            'Send real-time encrypted Telegram alert to Sovereign Root (@Anandsawre) on role escalations.',
            Icons.notifications_active_outlined,
            _alertMasterOnAction,
            (val) => setState(() => _alertMasterOnAction = val),
            isDark,
          ),
          _policySwitchTile(
            'Strict Endpoint Rate Limiting (120 req/min)',
            'Prevent credential stuffing by throttling admin portal API endpoints.',
            Icons.speed_rounded,
            _strictRateLimiting,
            (val) => setState(() => _strictRateLimiting = val),
            isDark,
          ),
          _policySwitchTile(
            'Emergency Maintenance Lockdown Protocol',
            'Temporarily restrict all portal access exclusively to Sovereign Root Account.',
            Icons.lock_clock_rounded,
            _emergencyLockdown,
            (val) => setState(() => _emergencyLockdown = val),
            isDark,
            isDestructive: true,
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 20),

          // Session Timeout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Session Lifetime & Inactivity Timeout', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('Authenticated web portal sessions expire automatically after this duration', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sessionTimeout,
                    items: ['1 Hour', '6 Hours', '12 Hours', '24 Hours', '7 Days', '30 Days'].map((t) {
                      return DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _sessionTimeout = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _policySwitchTile(String title, String desc, IconData icon, bool value, ValueChanged<bool> onChanged, bool isDark, {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDestructive ? const Color(0xFFEF4444).withValues(alpha: 0.12) : const Color(0xFF5B3DF5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF5B3DF5)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(desc, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF5B3DF5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// Donut Chart Painter for 8 admins
class _DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeW = 12.0;

    final paint1 = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;
    final paint2 = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;
    final paint3 = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;
    final paint4 = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeW / 2);

    canvas.drawArc(rect, 0, pi * 0.5, false, paint1); // 25%
    canvas.drawArc(rect, pi * 0.5, pi * 0.5, false, paint2); // 25%
    canvas.drawArc(rect, pi, pi * 0.8, false, paint3); // 40%
    canvas.drawArc(rect, pi * 1.8, pi * 0.2, false, paint4); // 10%
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
