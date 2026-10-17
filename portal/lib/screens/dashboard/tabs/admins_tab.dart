import 'dart:math';
import 'package:flutter/material.dart';
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
                if (id.isEmpty) return;
                Navigator.pop(ctx);
                final res = await _api.addAdmin(id);
                if (res['success'] == true) {
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

            // 4. MAIN CONTENT (Split: 65% Table & Bottom Panels, 35% Right Side Details)
            if (isDesktop)
              Row(
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
              )
            else
              Column(
                children: [
                  _buildAllAdminsTable(isDark),
                  const SizedBox(height: 20),
                  _buildRoleDistributionCard(isDark),
                  const SizedBox(height: 20),
                  _buildPermissionMatrixCard(isDark),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 780,
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                    child: Row(
                      children: [
                        _colHeader('#', 30),
                        _colHeader('Admin', 180),
                        _colHeader('Role', 100),
                        _colHeader('Permissions', 170),
                        _colHeader('Status', 80),
                        _colHeader('Last Active', 90),
                        _colHeader('Actions', 90, alignment: Alignment.centerRight),
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
                            // Admin (Avatar + Name + Username)
                            SizedBox(
                              width: 180,
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
                              width: 90,
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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () => _openManageAdminDialog(a),
                                    child: Text('Manage', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 2),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF94A3B8)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (val) {
                                      if (val == 'manage') _openManageAdminDialog(a);
                                      if (val == 'log') widget.onShowToast('Session history pulled for ${a['name']}');
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'manage', child: Text('Edit Role & Permissions')),
                                      const PopupMenuItem(value: 'log', child: Text('View Audit Log')),
                                    ],
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
