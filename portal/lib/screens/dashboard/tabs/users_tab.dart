import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kpi_card.dart';

class UsersTab extends StatefulWidget {
  final List<dynamic> users;
  final Map<String, dynamic> resolvedStats;
  final ApiService api;
  final TelegramService tg;
  final bool isDark;
  final Future<void> Function() onRefreshAll;
  final Function(String msg, {bool isError}) onShowToast;
  final String? initialSearch;

  const UsersTab({
    super.key,
    required this.users,
    required this.resolvedStats,
    required this.api,
    required this.tg,
    required this.isDark,
    required this.onRefreshAll,
    required this.onShowToast,
    this.initialSearch,
  });

  @override
  State<UsersTab> createState() => UsersTabState();
}

class UsersTabState extends State<UsersTab> {
  String _userSearch = '';
  String _userSubTab = 'all'; // 'all', 'active', 'inactive', 'blocked', 'vip', 'recent'
  String _userPlanFilter = 'all'; // 'all', 'free', 'vip', 'premium'
  String _userDateFilter = 'all'; // 'all', 'today', 'week', 'month'
  String _userStatusFilter = 'all'; // 'all', 'active', 'inactive', 'blocked', 'pro'
  int _userCurrentPage = 1;
  String _userDetailsSubTab = 'overview'; // 'overview', 'activity', 'tests', 'payments'
  bool _isUserDetailsPanelOpen = true;
  Map<String, dynamic>? _selectedUser;
  final List<Map<String, dynamic>> _customAddedUsers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _userSearch = widget.initialSearch!;
    }
  }

  void setSearch(String search) {
    setState(() => _userSearch = search);
  }

  void _showToast(String msg, {bool isError = false}) => widget.onShowToast(msg, isError: isError);
  Future<void> _loadAllData() => widget.onRefreshAll();

  ApiService get _api => widget.api;
  TelegramService get _tg => widget.tg;
  List<dynamic> get _users => widget.users;
  Map<String, dynamic> get _resolvedStats => widget.resolvedStats;

  String _formatNumber(dynamic n) {
    if (n == null) return '0';
    final val = int.tryParse(n.toString());
    if (val == null) return n.toString();
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString()).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return date.toString();
    }
  }

  Future<void> _quickPassPrompt() async {
    final idCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 22),
            ),
            const SizedBox(width: 12),
            Text('Quick Scholar Pass by ID', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: min(440.0, MediaQuery.of(ctx).size.width * 0.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: idCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Candidate Telegram User ID',
                  hintText: 'e.g. 5988607147',
                  prefixIcon: Icon(Icons.fingerprint_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Immediately grants VIP Scholar Pass and dispatches an official celebratory message to the student on Telegram.',
                style: TextStyle(fontSize: 11, color: widget.isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () async {
              final text = idCtrl.text.trim();
              if (text.isEmpty) return;
              final numId = int.tryParse(text);
              if (numId == null) {
                _showToast('Please enter a valid numeric Telegram ID.', isError: true);
                return;
              }
              Navigator.pop(ctx);
              final res = await _api.toggleUserPremium(numId, true);
              if (res['success'] == true) {
                _showToast('Scholar Pass granted & Telegram celebratory message dispatched! 📲');
                await _loadAllData();
              } else {
                _showToast(res['error'] ?? 'Failed to grant pass', isError: true);
              }
            },
            child: const Text('Grant Pass & Dispatch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildStudentsTab();
  }

  // ==========================================
  // TAB 3: USERS MANAGEMENT (MATCHING MOCKUP DESIGN)
  // ==========================================

  List<Map<String, dynamic>> get _allDisplayUsers {
    final combined = <Map<String, dynamic>>[];
    final now = DateTime.now();

    // 1. Locally added users in current session
    combined.addAll(_customAddedUsers);

    // 2. Real users loaded directly from Supabase via backend API
    if (_users.isNotEmpty) {
      for (final raw in _users) {
        if (raw is! Map<String, dynamic> && raw is! Map) continue;
        final u = Map<String, dynamic>.from(raw as Map);
        final id = u['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        // Skip if already in custom added list
        if (combined.any((e) => e['id'] == id)) continue;

        final isPrem = u['is_premium'] == true;
        final isBlocked = u['is_blocked'] == true;
        final rawName = u['first_name']?.toString() ?? '';
        final rawUser = u['username']?.toString() ?? '';
        final name = rawName.isNotEmpty
            ? rawName
            : (rawUser.isNotEmpty ? rawUser : 'Candidate $id');
        final username = rawUser.isNotEmpty ? rawUser.replaceAll('@', '') : 'user_$id';

        DateTime? lastActiveDt;
        if (u['last_active_at'] != null) {
          try {
            lastActiveDt = DateTime.parse(u['last_active_at'].toString()).toLocal();
          } catch (_) {}
        }

        DateTime? createdDt;
        if (u['created_at'] != null) {
          try {
            createdDt = DateTime.parse(u['created_at'].toString()).toLocal();
          } catch (_) {}
        }

        final diff = lastActiveDt != null ? now.difference(lastActiveDt) : const Duration(days: 999);
        final isRecent = diff.inHours < 24;
        final isActive = diff.inDays <= 7;
        final status = isBlocked ? 'Blocked' : (isActive ? 'Active' : 'Inactive');

        String lastActiveStr;
        if (lastActiveDt == null) {
          lastActiveStr = 'Never';
        } else if (diff.inMinutes < 2) {
          lastActiveStr = 'Just now';
        } else if (diff.inMinutes < 60) {
          lastActiveStr = '${diff.inMinutes} min ago';
        } else if (diff.inHours < 24) {
          lastActiveStr = '${diff.inHours} hr ago';
        } else if (diff.inDays < 30) {
          lastActiveStr = '${diff.inDays} days ago';
        } else {
          lastActiveStr = '${(diff.inDays / 30).floor()} mo ago';
        }

        final joinedOnStr = createdDt != null ? _formatDate(createdDt) : 'Recent';
        final joinTimeStr = createdDt != null
            ? '${createdDt.hour % 12 == 0 ? 12 : createdDt.hour % 12}:${createdDt.minute.toString().padLeft(2, '0')} ${createdDt.hour >= 12 ? 'PM' : 'AM'}'
            : '10:00 AM';

        final testsCount = int.tryParse(u['tests_completed']?.toString() ?? '0') ?? 0;
        final totalScore = int.tryParse(u['total_score']?.toString() ?? '0') ?? 0;
        final streakDays = int.tryParse(u['streak_days']?.toString() ?? '1') ?? 1;
        final duelRating = int.tryParse(u['duel_rating']?.toString() ?? '1000') ?? 1000;
        final referrals = int.tryParse(u['referrals_count']?.toString() ?? '0') ?? 0;

        final colors = [
          const Color(0xFF2563EB),
          const Color(0xFF8B5CF6),
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
          const Color(0xFFEC4899),
          const Color(0xFF06B6D4),
          const Color(0xFFF97316),
          const Color(0xFF6366F1),
        ];
        final color = colors[(int.tryParse(id) ?? 0).abs() % colors.length];

        combined.add({
          'id': id,
          'first_name': name,
          'last_name': u['last_name']?.toString() ?? '',
          'username': username,
          'status': status,
          'plan': isPrem ? 'VIP' : 'Free',
          'joined_on': joinedOnStr,
          'join_time': joinTimeStr,
          'last_active': lastActiveStr,
          'is_recent': isRecent,
          'tests': testsCount,
          'total_score': totalScore,
          'max_score': testsCount > 0 ? testsCount * 25 : 100,
          'rank': u['merit_rank'] ?? 1,
          'streak_days': streakDays,
          'duel_rating': duelRating,
          'referrals': referrals,
          'language': u['language_code'] ?? 'Hindi',
          'color': color,
          'real_user': u,
        });
      }
    }

    return combined;
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var list = _allDisplayUsers;

    // Sub-tab filter
    if (_userSubTab == 'active') {
      list = list.where((u) => u['status'] == 'Active').toList();
    } else if (_userSubTab == 'inactive') {
      list = list.where((u) => u['status'] == 'Inactive').toList();
    } else if (_userSubTab == 'blocked') {
      list = list.where((u) => u['status'] == 'Blocked').toList();
    } else if (_userSubTab == 'vip') {
      list = list.where((u) => u['plan'] == 'VIP' || u['plan'] == 'Premium').toList();
    } else if (_userSubTab == 'recent') {
      list = list.where((u) => u['is_recent'] == true).toList();
    }

    // Status dropdown filter
    if (_userStatusFilter != 'all') {
      list = list.where((u) => u['status'] == _userStatusFilter).toList();
    }

    // Plan dropdown filter
    if (_userPlanFilter != 'all') {
      list = list.where((u) => u['plan'] == _userPlanFilter).toList();
    }

    // Query search
    if (_userSearch.trim().isNotEmpty) {
      final q = _userSearch.trim().toLowerCase();
      list = list.where((u) {
        final id = u['id']?.toString().toLowerCase() ?? '';
        final name = u['first_name']?.toString().toLowerCase() ?? '';
        final username = u['username']?.toString().toLowerCase() ?? '';
        final lang = u['language']?.toString().toLowerCase() ?? '';
        return id.contains(q) || name.contains(q) || username.contains(q) || lang.contains(q);
      }).toList();
    }

    return list;
  }

  Widget _buildStudentsTab() {
    final isDark = widget.isDark;
    final users = _filteredUsers;

    // Ensure selected user is initialized
    _selectedUser ??= users.isNotEmpty ? users.first : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1050;

        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28 : 16,
            vertical: 20,
          ),
          children: [
            // 1. Page Header (Title + Import, Export, Add User Manually buttons)
            _buildUsersHeader(isDesktop: isDesktop),

            const SizedBox(height: 20),

            // 2. Overview KPI Cards (Total Users, Active, New Users, Inactive)
            _buildUsersKpiCards(isDesktop: isDesktop),

            const SizedBox(height: 24),

            // 3. Main Split Area: Data Table Card (Left) + User Details Panel (Right)
            if (isDesktop && _isUserDetailsPanelOpen && _selectedUser != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 68,
                    child: _buildUsersTableCard(users, isDark),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 32,
                    child: _buildUserDetailsPanel(_selectedUser!, isDark),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUsersTableCard(users, isDark),
                  if (_isUserDetailsPanelOpen && _selectedUser != null) ...[
                    const SizedBox(height: 20),
                    _buildUserDetailsPanel(_selectedUser!, isDark),
                  ],
                ],
              ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Header: Users Management + Actions
  // -------------------------------------------------------------
  Widget _buildUsersHeader({required bool isDesktop}) {
    final isDark = widget.isDark;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Users Management',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'View, manage and analyze all your bot users. Search, filter, track activity and manage access.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),

        // 3 Action Buttons on Right
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Import Users Button
            OutlinedButton.icon(
              onPressed: _openImportUsersDialog,
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                foregroundColor: isDark ? AppTheme.darkTextMain : const Color(0xFF334155),
                side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.file_upload_outlined, size: 16, color: Color(0xFF2563EB)),
              label: Text(
                'Import Users',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),

            // Export Button
            OutlinedButton.icon(
              onPressed: _exportUsersData,
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                foregroundColor: isDark ? AppTheme.darkTextMain : const Color(0xFF334155),
                side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.file_download_outlined, size: 16, color: Color(0xFF2563EB)),
              label: Text(
                'Export',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),

            // Add User Manually Button
            ElevatedButton.icon(
              onPressed: _openAddUserManuallyDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: Text(
                'Add User Manually',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Overview KPI Cards (Row of 4)
  // -------------------------------------------------------------
  Widget _buildUsersKpiCards({required bool isDesktop}) {
    final all = _allDisplayUsers;
    final totalCount = (_resolvedStats['totalUsers'] as num?)?.toInt() ?? all.length;
    final activeCount = all.where((u) => u['status'] == 'Active').length;
    final newCount = all.where((u) => u['is_recent'] == true).length;
    final inactiveCount = all.where((u) => u['status'] == 'Inactive' || u['status'] == 'Blocked').length;
    final activePct = totalCount > 0 ? ((activeCount / totalCount) * 100).toStringAsFixed(1) : '100.0';

    final cards = <Widget>[
      _buildKpiCard(
        title: 'Total Users',
        count: _formatNumber(totalCount),
        trend: '+${all.isNotEmpty ? ((newCount / all.length) * 100).toStringAsFixed(1) : '0.0'}%',
        subtext: '$totalCount registered in bot',
        icon: Icons.people_alt_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
      ),
      _buildKpiCard(
        title: 'Active Users (7 Days)',
        count: _formatNumber(activeCount),
        trend: '$activePct%',
        subtext: '$activePct% active engagement',
        icon: Icons.send_rounded,
        iconBg: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF10B981),
      ),
      _buildKpiCard(
        title: 'New Users (24h)',
        count: _formatNumber(newCount),
        trend: newCount > 0 ? '+$newCount' : null,
        subtext: '$newCount joined recently',
        icon: Icons.person_add_rounded,
        iconBg: const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFF59E0B),
      ),
      _buildKpiCard(
        title: 'Inactive Users',
        count: _formatNumber(inactiveCount),
        trend: null,
        subtext: 'Not active in 7+ days',
        icon: Icons.access_time_rounded,
        iconBg: const Color(0xFFFAF5FF),
        iconColor: const Color(0xFF8B5CF6),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(width: (MediaQuery.of(context).size.width - 44) / 2, child: c)).toList(),
      );
    }
  }

  Widget _buildKpiCard({
    required String title,
    required String count,
    String? trend,
    required String subtext,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return KpiCard(
      title: title,
      count: count,
      trend: trend,
      subtext: subtext,
      icon: icon,
      iconBg: iconBg,
      iconColor: iconColor,
      isDark: widget.isDark,
    );
  }

  // -------------------------------------------------------------
  // Data Table Card (Left Column)
  // -------------------------------------------------------------
  Widget _buildUsersTableCard(List<Map<String, dynamic>> users, bool isDark) {
    final all = _allDisplayUsers;
    final totalCount = (_resolvedStats['totalUsers'] as num?)?.toInt() ?? all.length;
    final activeCount = all.where((u) => u['status'] == 'Active').length;
    final inactiveCount = all.where((u) => u['status'] == 'Inactive').length;
    final blockedCount = all.where((u) => u['status'] == 'Blocked').length;
    final vipCount = all.where((u) => u['plan'] == 'VIP' || u['plan'] == 'Premium').length;
    final recentCount = all.where((u) => u['is_recent'] == true).length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-Tabs Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubTabItem('All Users ($totalCount)', 'all', Icons.people_alt_rounded),
                  const SizedBox(width: 6),
                  _buildSubTabItem('Active ($activeCount)', 'active', Icons.circle, iconColor: const Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  _buildSubTabItem('Inactive ($inactiveCount)', 'inactive', Icons.circle, iconColor: const Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  _buildSubTabItem('Blocked ($blockedCount)', 'blocked', Icons.circle, iconColor: const Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  _buildSubTabItem('VIP Users ($vipCount)', 'vip', Icons.workspace_premium_rounded, iconColor: const Color(0xFF8B5CF6)),
                  const SizedBox(width: 6),
                  _buildSubTabItem('Recent ($recentCount)', 'recent', Icons.history_rounded, iconColor: const Color(0xFF06B6D4)),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9)),

          // Search & Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search Input
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      onChanged: (val) => setState(() => _userSearch = val),
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                        hintText: 'Search by name, username, user id, phone...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        suffixIcon: _userSearch.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                onPressed: () => setState(() => _userSearch = ''),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
                        ),
                      ),
                    ),
                  ),
                ),

                // Status Dropdown
                _buildFilterDropdown(
                  value: _userStatusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                    DropdownMenuItem(value: 'Blocked', child: Text('Blocked')),
                  ],
                  onChanged: (val) => setState(() => _userStatusFilter = val ?? 'all'),
                ),

                // Plans Dropdown
                _buildFilterDropdown(
                  value: _userPlanFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Plans')),
                    DropdownMenuItem(value: 'Free', child: Text('Free Tier')),
                    DropdownMenuItem(value: 'VIP', child: Text('VIP Pass')),
                    DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                  ],
                  onChanged: (val) => setState(() => _userPlanFilter = val ?? 'all'),
                ),

                // Join Date Dropdown
                _buildFilterDropdown(
                  value: _userDateFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Join Date')),
                    DropdownMenuItem(value: 'today', child: Text('Today')),
                    DropdownMenuItem(value: 'week', child: Text('This Week')),
                    DropdownMenuItem(value: 'month', child: Text('This Month')),
                  ],
                  onChanged: (val) => setState(() => _userDateFilter = val ?? 'all'),
                ),

                // Reset Button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _userSearch = '';
                      _userSubTab = 'all';
                      _userStatusFilter = 'all';
                      _userPlanFilter = 'all';
                      _userDateFilter = 'all';
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF64748B)),
                  label: Text('Reset', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9)),

          // Full-Width Responsive Table Content
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth < 920 ? 920.0 : constraints.maxWidth;
              final headerStyle = GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.2,
                color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
              );

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Table Header Row
                      Container(
                        height: 42,
                        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text('#', style: headerStyle),
                            ),
                            Expanded(
                              flex: 22,
                              child: Text('User', style: headerStyle),
                            ),
                            Expanded(
                              flex: 18,
                              child: Text('Username', style: headerStyle),
                            ),
                            Expanded(
                              flex: 12,
                              child: Text('Status', style: headerStyle),
                            ),
                            Expanded(
                              flex: 10,
                              child: Text('Plan', style: headerStyle),
                            ),
                            Expanded(
                              flex: 14,
                              child: Text('Joined On', style: headerStyle),
                            ),
                            Expanded(
                              flex: 14,
                              child: Text('Last Active', style: headerStyle),
                            ),
                            Expanded(
                              flex: 8,
                              child: Text('Tests', style: headerStyle),
                            ),
                            SizedBox(
                              width: 96,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text('Actions', style: headerStyle),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9)),

                      // Table Data Rows
                      if (users.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_off_rounded, size: 44, color: isDark ? AppTheme.darkTextMuted : const Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  'No users found matching your filters',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...users.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final u = entry.value;
                          final id = u['id'].toString();
                          final isSelected = _selectedUser != null && _selectedUser!['id'] == id;

                          final serialColors = [
                            const Color(0xFF2563EB), // Royal Blue
                            const Color(0xFF8B5CF6), // Purple
                            const Color(0xFF10B981), // Emerald
                            const Color(0xFFF59E0B), // Amber
                            const Color(0xFFEC4899), // Pink
                            const Color(0xFF06B6D4), // Cyan
                            const Color(0xFFF97316), // Orange
                            const Color(0xFF6366F1), // Indigo
                            const Color(0xFF14B8A6), // Teal
                            const Color(0xFFE11D48), // Rose
                          ];
                          final sColor = serialColors[(idx - 1) % serialColors.length];

                          return Material(
                            color: isSelected
                                ? (isDark ? const Color(0xFF2563EB).withValues(alpha: 0.18) : const Color(0xFFEFF6FF))
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedUser = u;
                                  _isUserDetailsPanelOpen = true;
                                });
                              },
                              hoverColor: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 52),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9),
                                    ),
                                    left: isSelected
                                        ? const BorderSide(color: Color(0xFF2563EB), width: 3)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Serial Number inside Distinct Colored Circle
                                    SizedBox(
                                      width: 48,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: sColor.withValues(alpha: 0.14),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: sColor.withValues(alpha: 0.4), width: 1.2),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$idx',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: sColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // User with Circle Initial Avatar
                                    Expanded(
                                      flex: 22,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 15,
                                            backgroundColor: u['color'] as Color? ?? const Color(0xFF2563EB),
                                            child: Text(
                                              (u['first_name'] as String).isNotEmpty
                                                  ? (u['first_name'] as String)[0].toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              u['first_name'] ?? 'User',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Username
                                    Expanded(
                                      flex: 18,
                                      child: Text(
                                        '@${u['username']}',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),

                                    // Status Pill
                                    Expanded(
                                      flex: 12,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildStatusBadge(u['status'] ?? 'Active'),
                                      ),
                                    ),

                                    // Plan Pill
                                    Expanded(
                                      flex: 10,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildPlanBadge(u['plan'] ?? 'Free'),
                                      ),
                                    ),

                                    // Joined On
                                    Expanded(
                                      flex: 14,
                                      child: Text(
                                        u['joined_on'] ?? '16 Oct 2026',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: isDark ? AppTheme.darkTextMuted : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),

                                    // Last Active
                                    Expanded(
                                      flex: 14,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: (u['status'] == 'Active' || u['is_recent'] == true)
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFEF4444),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              u['last_active'] ?? 'Recent',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Tests Count
                                    Expanded(
                                      flex: 8,
                                      child: Text(
                                        '${u['tests'] ?? 0}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),

                                    // Actions: View button + 3-dots
                                    SizedBox(
                                      width: 96,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                _selectedUser = u;
                                                _isUserDetailsPanelOpen = true;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFBFDBFE)),
                                              ),
                                              child: Text(
                                                'View',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF2563EB),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            onSelected: (val) {
                                              if (val == 'msg') _openSendMessageToUserDialog(u);
                                              if (val == 'plan') _openChangeUserPlanDialog(u);
                                              if (val == 'pass') _quickPassPrompt();
                                              if (val == 'reset') _confirmResetUserProgress(u);
                                              if (val == 'block') _toggleBlockUser(u);
                                              if (val == 'delete') _confirmDeleteUser(u);
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(value: 'msg', child: Row(children: [Icon(Icons.send_rounded, size: 16, color: Color(0xFF2563EB)), SizedBox(width: 8), Text('Send Telegram Message')])),
                                              const PopupMenuItem(value: 'plan', child: Row(children: [Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFF8B5CF6)), SizedBox(width: 8), Text('Change Plan')])),
                                              const PopupMenuItem(value: 'pass', child: Row(children: [Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFFBBF24)), SizedBox(width: 8), Text('Quick Pass by ID')])),
                                              const PopupMenuItem(value: 'reset', child: Row(children: [Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFF59E0B)), SizedBox(width: 8), Text('Reset Progress')])),
                                              PopupMenuItem(value: 'block', child: Row(children: [const Icon(Icons.block_rounded, size: 16, color: Color(0xFFEF4444)), const SizedBox(width: 8), Text(u['status'] == 'Blocked' ? 'Unblock User' : 'Block User')])),
                                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)), SizedBox(width: 8), Text('Delete User', style: TextStyle(color: Color(0xFFDC2626)))])),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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

          Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9)),

          // Table Pagination Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing 1 to ${users.length} of ${_allDisplayUsers.length} users',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
                Row(
                  children: [
                    _buildPageBtn('1', isSelected: _userCurrentPage == 1),
                    if (users.length > 20) ...[
                      _buildPageBtn('2', isSelected: _userCurrentPage == 2),
                      if (users.length > 40)
                        _buildPageBtn('3', isSelected: _userCurrentPage == 3),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageBtn(String num, {required bool isSelected}) {
    return InkWell(
      onTap: () {
        final p = int.tryParse(num);
        if (p != null) setState(() => _userCurrentPage = p);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          num,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabItem(String label, String key, IconData icon, {Color? iconColor}) {
    final isSelected = _userSubTab == key;
    final isDark = widget.isDark;

    return InkWell(
      onTap: () => setState(() => _userSubTab = key),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? AppTheme.darkSurface : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: icon == Icons.circle ? 8 : 14,
              color: isSelected ? Colors.white : (iconColor ?? const Color(0xFF64748B)),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppTheme.darkTextMuted : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = widget.isDark;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w500),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    Color dot;

    if (status == 'Active') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
      dot = const Color(0xFF10B981);
    } else if (status == 'Inactive') {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
      dot = const Color(0xFFF59E0B);
    } else {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
      dot = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  Widget _buildPlanBadge(String plan) {
    if (plan == 'VIP') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👑', style: TextStyle(fontSize: 10)),
            SizedBox(width: 4),
            Text('VIP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
          ],
        ),
      );
    } else if (plan == 'Premium') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Premium', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Free', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      );
    }
  }

  // -------------------------------------------------------------
  // User Details Panel (Right Column)
  // -------------------------------------------------------------
  Widget _buildUserDetailsPanel(Map<String, dynamic> u, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Title + Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'User Details',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _isUserDetailsPanelOpen = false),
                child: Row(
                  children: [
                    Text('Close', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // User Hero: Big Avatar Circle + Name + Status + Username
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: u['color'] as Color? ?? const Color(0xFF1E3A8A),
                child: Text(
                  (u['first_name'] as String).isNotEmpty ? (u['first_name'] as String)[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            u['first_name'] ?? 'User',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(u['status'] ?? 'Active'),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${u['username']}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Joined ${u['joined_on']} • ${u['last_active']}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sub-tabs: Overview, Activity, Tests, Payments
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                _buildDrawerTab('Overview', 'overview'),
                _buildDrawerTab('Activity', 'activity'),
                _buildDrawerTab('Tests', 'tests'),
                _buildDrawerTab('Payments', 'payments'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Key-Value Attribute Rows
          if (_userDetailsSubTab == 'overview') ...[
            _buildDetailRow('User ID', u['id'].toString(), isCopyable: true),
            _buildDetailRow('Username', '@${u['username']}', isCopyable: true, isLink: true),
            _buildDetailRow('Name', u['first_name'] ?? ''),
            _buildDetailRow('Language', u['language'] ?? 'Hindi'),
            _buildDetailRow(
              'Plan',
              u['plan'] ?? 'Free',
              trailingWidget: InkWell(
                onTap: () => _openChangeUserPlanDialog(u),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            _buildDetailRow('Total Tests', '${u['tests'] ?? 0}'),
            _buildDetailRow('Total Score', '${u['total_score'] ?? 0} pts'),
            _buildDetailRow('Quiz Streak', '🔥 ${u['streak_days'] ?? 1} Days'),
            _buildDetailRow('Duel Rating', '⚔️ ${u['duel_rating'] ?? 1000} ELO'),
            _buildDetailRow('Referrals', '👥 ${u['referrals'] ?? 0} students'),
            _buildDetailRow('Join Date', '${u['joined_on']}, ${u['join_time'] ?? '10:00 AM'}'),
            _buildDetailRow(
              'Last Active',
              u['last_active'] ?? 'Just now',
              leadingDotColor: (u['status'] == 'Active' || u['is_recent'] == true) ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ] else if (_userDetailsSubTab == 'activity') ...[
            _buildTimelineItem('Joined Bot Platform', 'Registered as candidate via Telegram', '${u['joined_on']}, ${u['join_time'] ?? '10:00 AM'}'),
            if ((u['tests'] ?? 0) > 0)
              _buildTimelineItem('Completed Practice Tests', '${u['tests']} mock tests finished with ${u['total_score']} pts', 'Total ${u['tests']} tests')
            else
              _buildTimelineItem('Awaiting First Test', 'Candidate has not attempted any tests yet', 'No tests yet'),
            _buildTimelineItem('Daily Quiz Streak', '${u['streak_days'] ?? 1} Days Active Practice Streak', 'Current streak'),
            _buildTimelineItem('Last Active Timestamp', 'Last recorded activity on bot', u['last_active'] ?? 'Just now'),
          ] else if (_userDetailsSubTab == 'tests') ...[
            if ((u['tests'] ?? 0) > 0) ...[
              _buildTestAttemptItem('Total Completed Tests', '${u['tests']} Finished', 'Passed', const Color(0xFF10B981)),
              _buildTestAttemptItem('Cumulative Merit Score', '${u['total_score']} / ${u['max_score']}', 'Active', const Color(0xFF2563EB)),
              _buildTestAttemptItem('Battle Duel Rating', '${u['duel_rating'] ?? 1000} ELO', 'Ranked', const Color(0xFF8B5CF6)),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.assignment_late_outlined, size: 36, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text('No mock test attempts recorded yet.', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
          ] else ...[
            if (u['plan'] == 'VIP' || u['plan'] == 'Premium')
              _buildPaymentItem('Scholar VIP Unlimited Pass', 'Active', 'VIP Tier', u['joined_on'] ?? 'Recent')
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.credit_card_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text('Free Tier Account', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text('No paid subscription active', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
                        onPressed: () => _openChangeUserPlanDialog(u),
                        child: const Text('Upgrade User to VIP'),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          const SizedBox(height: 20),

          // Primary Button: Send Message
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => _openSendMessageToUserDialog(u),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(
                'Send Message',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 2x2 Grid Actions: Change Plan, Reset Progress, Block User, Delete User
          Row(
            children: [
              Expanded(
                child: _buildPanelSecondaryBtn(
                  label: 'Change Plan',
                  icon: Icons.workspace_premium_rounded,
                  bg: const Color(0xFFF3E8FF),
                  fg: const Color(0xFF7C3AED),
                  onTap: () => _openChangeUserPlanDialog(u),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPanelSecondaryBtn(
                  label: 'Reset Progress',
                  icon: Icons.refresh_rounded,
                  bg: const Color(0xFFFFFBEB),
                  fg: const Color(0xFFD97706),
                  onTap: () => _confirmResetUserProgress(u),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPanelSecondaryBtn(
                  label: u['status'] == 'Blocked' ? 'Unblock User' : 'Block User',
                  icon: Icons.block_rounded,
                  bg: const Color(0xFFFEF2F2),
                  fg: const Color(0xFFDC2626),
                  onTap: () => _toggleBlockUser(u),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPanelSecondaryBtn(
                  label: 'Delete User',
                  icon: Icons.delete_outline_rounded,
                  bg: const Color(0xFFFEF2F2),
                  fg: const Color(0xFFDC2626),
                  onTap: () => _confirmDeleteUser(u),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTab(String label, String key) {
    final isSelected = _userDetailsSubTab == key;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _userDetailsSubTab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                width: 2.2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isCopyable = false,
    bool isLink = false,
    Widget? trailingWidget,
    Color? leadingDotColor,
  }) {
    final isDark = widget.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingDotColor != null) ...[
                Container(width: 6, height: 6, decoration: BoxDecoration(color: leadingDotColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isLink
                      ? const Color(0xFF2563EB)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              if (isCopyable) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    _showToast('Copied $value to clipboard!');
                  },
                  child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                ),
              ],
              if (trailingWidget != null) ...[
                const SizedBox(width: 8),
                trailingWidget,
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanelSecondaryBtn({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String title, String desc, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(desc, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Text(time, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildTestAttemptItem(String title, String score, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
          Text(score, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(String title, String amount, String status, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(date, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          Text(amount, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Action Handlers: Add, Import, Export, Message, Plan, Reset, Block, Delete
  // -------------------------------------------------------------
  void _openAddUserManuallyDialog() {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    String selectedPlan = 'Free';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.person_add_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Text('Add User Manually', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: idCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Telegram User ID', hintText: 'e.g. 747573651')),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g. Rahul Sharma')),
                const SizedBox(height: 12),
                TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Telegram Username', hintText: 'e.g. rahul_s')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Initial Plan'),
                  initialValue: selectedPlan,
                  items: const [
                    DropdownMenuItem(value: 'Free', child: Text('Free Tier')),
                    DropdownMenuItem(value: 'VIP', child: Text('VIP Pass')),
                    DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                  ],
                  onChanged: (val) => setDState(() => selectedPlan = val ?? 'Free'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                if (idCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                  _showToast('Please enter both User ID and Name');
                  return;
                }
                final id = idCtrl.text.trim();
                final name = nameCtrl.text.trim();
                final uname = userCtrl.text.trim().replaceAll('@', '');
                Navigator.pop(ctx);
                _showToast('Saving candidate to database...');
                final res = await _api.createUser(
                  id: id,
                  firstName: name,
                  username: uname.isNotEmpty ? uname : null,
                  plan: selectedPlan,
                );
                if (res['success'] == true) {
                  _showToast('User $name registered successfully!');
                  await _loadAllData();
                  if (_allDisplayUsers.isNotEmpty) {
                    setState(() {
                      _selectedUser = _allDisplayUsers.firstWhere(
                        (u) => u['id'] == id,
                        orElse: () => _allDisplayUsers.first,
                      );
                    });
                  }
                } else {
                  _showToast('Failed to add user: ${res['error'] ?? 'Check database connection'}');
                }
              },
              child: const Text('Add User'),
            ),
          ],
        ),
      ),
    );
  }

  void _openImportUsersDialog() {
    final jsonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.file_upload_outlined, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Import Users', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste candidate JSON array to bulk insert into database:',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jsonCtrl,
                maxLines: 6,
                style: GoogleFonts.inter(fontSize: 11),
                decoration: InputDecoration(
                  hintText: '[\n  {\n    "id": 123456789,\n    "first_name": "Rohan",\n    "username": "rohan_tg",\n    "plan": "VIP"\n  }\n]',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () async {
              final raw = jsonCtrl.text.trim();
              if (raw.isEmpty) {
                _showToast('Please paste a valid JSON array of candidates.');
                return;
              }
              Navigator.pop(ctx);
              try {
                final decoded = jsonDecode(raw);
                if (decoded is! List) {
                  _showToast('Expected a JSON array of candidates.');
                  return;
                }
                final list = decoded
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
                if (list.isEmpty) {
                  _showToast('No users found in JSON array.');
                  return;
                }
                _showToast('Importing ${list.length} candidates...');
                final res = await _api.importUsers(list);
                if (res['success'] == true) {
                  _showToast('Successfully imported ${res['count'] ?? list.length} users into database!');
                  await _loadAllData();
                } else {
                  _showToast('Import failed: ${res['error'] ?? 'Error'}');
                }
              } catch (e) {
                _showToast('Invalid JSON: $e');
              }
            },
            child: const Text('Import Users'),
          ),
        ],
      ),
    );
  }

  void _exportUsersData() {
    final list = _filteredUsers;
    if (list.isEmpty) {
      _showToast('No candidate records available to export.');
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('ID,First Name,Username,Status,Plan,Joined On,Last Active,Tests Completed,Total Score');
    for (final u in list) {
      buffer.writeln('"${u['id']}","${u['first_name']}","${u['username']}","${u['status']}","${u['plan']}","${u['joined_on']}","${u['last_active']}","${u['tests']}","${u['total_score']}"');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _showToast('Exported ${list.length} candidate records as CSV to clipboard!');
  }

  void _openSendMessageToUserDialog(Map<String, dynamic> u) {
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.send_rounded, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Message to ${u['first_name']}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Telegram User ID: ${u['id']} • @${u['username']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Direct Telegram Message',
                  hintText: 'Type message to send directly via @Examplayer_bot...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () async {
              final text = msgCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              _showToast('Dispatching Telegram message to ${u['first_name']}...');
              final res = await _api.sendUserMessage(u['id'], text);
              if (res['success'] == true) {
                _showToast('Message sent to @${u['username']} on Telegram!');
              } else {
                _showToast('Delivery issue: ${res['error'] ?? 'User has not started the bot'}');
              }
            },
            icon: const Icon(Icons.send_rounded, size: 14),
            label: const Text('Send Message'),
          ),
        ],
      ),
    );
  }

  void _openChangeUserPlanDialog(Map<String, dynamic> u) {
    String currentPlan = u['plan'] ?? 'Free';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Change Plan for ${u['first_name']}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlanOptionTile('Free', 'Free Tier', 'Standard open quizzes & general practice', currentPlan, (val) => setDState(() => currentPlan = val)),
              const SizedBox(height: 8),
              _buildPlanOptionTile('VIP', 'VIP Pass 👑', 'Full access to premium test series & rankings', currentPlan, (val) => setDState(() => currentPlan = val)),
              const SizedBox(height: 8),
              _buildPlanOptionTile('Premium', 'Premium Scholar Pass', 'All tests, video explanations & 1-on-1 mentor bot', currentPlan, (val) => setDState(() => currentPlan = val)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                _showToast('Updating plan for ${u['first_name']}...');
                final res = await _api.toggleUserPremium(u['id'], currentPlan != 'Free');
                if (res['success'] == true) {
                  _showToast('${u['first_name']} plan updated to $currentPlan!');
                  await _loadAllData();
                } else {
                  _showToast('Failed to update plan: ${res['error'] ?? 'Error'}');
                }
              },
              child: const Text('Save Plan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanOptionTile(String key, String title, String subtitle, String current, ValueChanged<String> onSelect) {
    final isSelected = key == current;
    return InkWell(
      onTap: () => onSelect(key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResetUserProgress(Map<String, dynamic> u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Candidate Progress?'),
        content: Text('Are you sure you want to reset all quiz scores, tests completed, and merit rank for ${u['first_name']}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              _showToast('Resetting candidate progress in database...');
              final res = await _api.resetUserProgress(u['id']);
              if (res['success'] == true) {
                _showToast('Progress reset for ${u['first_name']}!');
                await _loadAllData();
              } else {
                _showToast('Reset failed: ${res['error'] ?? 'Error'}');
              }
            },
            child: const Text('Reset Now'),
          ),
        ],
      ),
    );
  }

  void _toggleBlockUser(Map<String, dynamic> u) async {
    final willBlock = u['status'] != 'Blocked';
    _showToast(willBlock ? 'Blocking ${u['first_name']}...' : 'Unblocking ${u['first_name']}...');
    final res = await _api.toggleUserBlock(u['id'], isBlocked: willBlock);
    if (res['success'] == true) {
      _showToast(willBlock ? '${u['first_name']} has been blocked.' : '${u['first_name']} has been unblocked.');
      await _loadAllData();
    } else {
      _showToast('Action failed: ${res['error'] ?? 'Error'}');
    }
  }

  void _confirmDeleteUser(Map<String, dynamic> u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User Account?'),
        content: Text('Are you sure you want to permanently delete candidate ${u['first_name']} (${u['id']})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              _showToast('Deleting candidate from database...');
              final res = await _api.deleteUser(u['id']);
              if (res['success'] == true) {
                _showToast('User ${u['first_name']} deleted.');
                if (_selectedUser != null && _selectedUser!['id'] == u['id']) {
                  _selectedUser = null;
                }
                await _loadAllData();
              } else {
                _showToast('Delete failed: ${res['error'] ?? 'Error'}');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


}
