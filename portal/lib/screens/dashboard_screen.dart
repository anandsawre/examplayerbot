import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/telegram_service.dart';
import '../theme/app_theme.dart';
import 'dashboard/tabs/overview_tab.dart';
import 'dashboard/tabs/leaderboard_tab.dart';
import 'dashboard/tabs/admins_tab.dart';
import 'dashboard/tabs/battles_tab.dart';
import 'dashboard/tabs/broadcast_tab.dart';
import 'dashboard/tabs/settings_tab.dart';
import 'dashboard/tabs/payments_tab.dart';
import 'dashboard/dialogs/dashboard_dialogs.dart';
import 'dashboard/components/dashboard_sidebar.dart';
import 'dashboard/components/dashboard_top_navbar.dart';
import 'dashboard/tabs/folders_tab.dart';
import 'dashboard/tabs/tests_questions_tab.dart';
import 'dashboard/tabs/users_tab.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final bool isDark;

  const DashboardScreen({
    super.key,
    required this.onLogout,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _api = ApiService();
  final _tg = TelegramService();

  // Navigation (9 full tabs matching HTML console):
  // 0: Dashboard (Operational Overview)
  // 1: Folders & Hierarchy (Folder Explorer)
  // 2: Tests & Questions (Examinations Catalog & Papers)
  // 3: Students Directory (Candidate Directory & Pass Management)
  // 4: Leaderboard & Merit (Competitive Merit Standings)
  // 5: Admins Hub (Platform Administrators Hub)
  // 6: Community Groups (Community Groups Authorization Desk)
  // 7: Broadcast Studio (Announcement Broadcast Studio)
  // 8: System Settings (Global Platform Settings)
  int _selectedNav = 0;
  bool _isLoading = true;
  String _statusMsg = '';

  // Data
  Map<String, dynamic> _stats = {};
  List<dynamic> _quizzes = [];
  List<dynamic> _folders = [];
  List<dynamic> _users = [];
  List<dynamic> _groups = [];
  List<dynamic> _globalLeaderboard = [];
  List<dynamic> _admins = [];
  Map<String, dynamic> _settings = {};

  // Search queries passed to modular tabs
  String _quizTableSearch = '';
  String _userSearch = '';

  // Admin Profile Info
  String _adminId = '613840274';
  String _adminName = 'Anand';
  String _adminUsername = 'Anandsawre';
  String? _adminPhotoUrl;

  // Live Telemetry & Dynamic State
  DateTime? _lastSyncTime;

  Map<String, dynamic> get _resolvedStats {
    if (_stats['stats'] is Map<String, dynamic>) {
      return _stats['stats'] as Map<String, dynamic>;
    }
    return _stats;
  }


  void _openPaymentsPlansDialog() {
    DashboardDialogs.openPaymentsPlansDialog(
      context,
      isDark: widget.isDark,
      onNavigateNav: (idx) => setState(() => _selectedNav = idx),
    );
  }

  void _openCommandsOverviewDialog() {
    DashboardDialogs.openCommandsOverviewDialog(
      context,
      isDark: widget.isDark,
      tg: _tg,
      showToast: _showToast,
    );
  }

  void _openRecentActivitiesDialog() {
    DashboardDialogs.openRecentActivitiesDialog(
      context,
      isDark: widget.isDark,
      users: _users,
      quizzes: _quizzes,
      groups: _groups,
    );
  }

  void _openSearchDialog() {
    DashboardDialogs.openSearchDialog(
      context,
      isDark: widget.isDark,
      onNavigateNav: (idx) => setState(() => _selectedNav = idx),
      onOpenCommands: _openCommandsOverviewDialog,
    );
  }

  @override
  void initState() {
    super.initState();
    _initAdminProfile();
    _loadAllData();
  }

  void _initAdminProfile() {
    if (_tg.isTelegramWebApp) {
      final u = _tg.user;
      if (u != null) {
        if (u['id'] != null) _adminId = u['id'].toString();
        if (u['first_name'] != null) _adminName = u['first_name'].toString();
        if (u['username'] != null) _adminUsername = u['username'].toString();
        if (u['photo_url'] != null) _adminPhotoUrl = u['photo_url'].toString();
      }
    }
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _statusMsg = '';
    });
    try {
      final results = await Future.wait([
        _api.getStats().catchError((_) => <String, dynamic>{}),
        _api.getQuizzes().catchError((_) => <dynamic>[]),
        _api.getFolders().catchError((_) => <dynamic>[]),
        _api.getUsers(query: _userSearch, tier: 'all').catchError((_) => <dynamic>[]),
        _api.getAuthorizedGroups().catchError((_) => <dynamic>[]),
        _api.getGlobalLeaderboard().catchError((_) => <dynamic>[]),
        _api.getAdmins().catchError((_) => <dynamic>[]),
        _api.getSettings().catchError((_) => <String, dynamic>{}),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _quizzes = results[1] as List<dynamic>;
          _folders = results[2] as List<dynamic>;
          _users = results[3] as List<dynamic>;
          _groups = results[4] as List<dynamic>;
          _globalLeaderboard = results[5] as List<dynamic>;
          _admins = results[6] as List<dynamic>;
          _settings = results[7] as Map<String, dynamic>;
          _lastSyncTime = DateTime.now();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMsg = 'Sync note: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLeaderboardData() async {
    try {
      final list = await _api.getGlobalLeaderboard();
      if (mounted) {
        setState(() {
          _globalLeaderboard = list;
        });
      }
    } catch (_) {}
  }

  void _showToast(String msg, {bool isError = false}) {
    _tg.hapticImpact(isError ? 'heavy' : 'light');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: isError ? AppTheme.rose : AppTheme.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================
  // ACTION MODALS & DIALOGS
  // ==========================================

  void _openLaunchQuizDialog(String quizId, String quizTitle) {
    if (_groups.isEmpty) {
      _showToast('No community groups authorized yet. Go to Group Battles tab to authorize a Telegram group first.', isError: true);
      return;
    }

    String? selectedGroupId = _groups.first['group_id']?.toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Launch Live Exam Battle', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Simulate instant Telegram Quiz in real-time', style: TextStyle(fontSize: 11, color: widget.isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: min(480.0, MediaQuery.of(ctx).size.width * 0.92),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          quizTitle,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Choose Destination Telegram Community Group:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.groups_rounded, size: 18),
                    labelText: 'Target Group Channel',
                  ),
                  initialValue: selectedGroupId,
                  items: _groups.map((g) {
                    final isLive = g['isBattleActive'] == true;
                    return DropdownMenuItem<String>(
                      value: g['group_id'].toString(),
                      child: Row(
                        children: [
                          Text(g['group_title'] ?? 'Group ${g['group_id']}'),
                          if (isLive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.roseSubtle, borderRadius: BorderRadius.circular(4)),
                              child: const Text('LIVE NOW', style: TextStyle(color: AppTheme.rose, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setDlgState(() => selectedGroupId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                if (selectedGroupId == null) return;
                Navigator.pop(ctx);
                _showToast('Broadcasting live battle to Telegram group...');
                final res = await _api.launchGroupBattle(selectedGroupId!, quizId);
                if (res['success'] == true) {
                  _showToast('🚀 Battle successfully started in Telegram group!');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Launch failed', isError: true);
                }
              },
              label: const Text('Launch Now', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    final statsData = _stats['stats'] ?? {};
    final userCount = statsData['totalUsers'] != null ? (int.tryParse('${statsData['totalUsers']}') ?? _users.length) : _users.length;

    return DashboardSidebar(
      selectedNav: _selectedNav,
      onSelectNav: (idx) => setState(() => _selectedNav = idx),
      stats: _stats,
      usersCount: userCount,
      quizzesCount: _quizzes.length,
      foldersCount: _folders.length,
      groupsCount: _groups.length,
      leaderboardCount: _globalLeaderboard.length,
      adminName: _adminName,
      adminUsername: _adminUsername,
      adminId: _adminId,
      adminPhotoUrl: _adminPhotoUrl,
      onLogout: widget.onLogout,
      onOpenPayments: _openPaymentsPlansDialog,
      onOpenCommands: _openCommandsOverviewDialog,
      onOpenActivities: _openRecentActivitiesDialog,
      onToast: (msg) => _showToast(msg),
      tg: _tg,
    );
  }

  Widget _buildMobileDrawer(bool isDark) {
    final statsData = _stats['stats'] ?? {};
    final userCount = statsData['totalUsers'] != null ? (int.tryParse('${statsData['totalUsers']}') ?? _users.length) : _users.length;

    return DashboardMobileDrawer(
      selectedNav: _selectedNav,
      onSelectNav: (idx) => setState(() => _selectedNav = idx),
      usersCount: userCount,
      quizzesCount: _quizzes.length,
      foldersCount: _folders.length,
      groupsCount: _groups.length,
      leaderboardCount: _globalLeaderboard.length,
      adminName: _adminName,
      adminUsername: _adminUsername,
      adminId: _adminId,
      adminPhotoUrl: _adminPhotoUrl,
      onLogout: widget.onLogout,
      onOpenPayments: _openPaymentsPlansDialog,
      onOpenCommands: _openCommandsOverviewDialog,
      onOpenActivities: _openRecentActivitiesDialog,
      onToast: (msg) => _showToast(msg),
      tg: _tg,
    );
  }

  Widget _buildTopNavbar({required bool isDesktop}) {
    return DashboardTopNavbar(
      isDesktop: isDesktop,
      isDark: widget.isDark,
      adminName: _adminName,
      adminUsername: _adminUsername,
      adminId: _adminId,
      adminPhotoUrl: _adminPhotoUrl,
      onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      onOpenSearch: _openSearchDialog,
      onOpenActivities: _openRecentActivitiesDialog,
      onToggleTheme: widget.onToggleTheme,
      onLogout: widget.onLogout,
      onSelectNav: (idx) => setState(() => _selectedNav = idx),
      onToast: (msg) => _showToast(msg),
      tg: _tg,
    );
  }

  // ==========================================
  // TAB 0: OPERATIONAL OVERVIEW DASHBOARD (MODULAR TAB)
  // ==========================================

  Widget _buildOverviewTab() {
    final isDark = widget.isDark;
    return OverviewTab(
      stats: _stats,
      quizzes: _quizzes,
      users: _users,
      folders: _folders,
      groups: _groups,
      globalLeaderboard: _globalLeaderboard,
      admins: _admins,
      statusMsg: _statusMsg,
      lastSyncTime: _lastSyncTime,
      adminName: _adminName,
      adminUsername: _adminUsername,
      adminId: _adminId,
      adminPhotoUrl: _adminPhotoUrl,
      api: _api,
      tg: _tg,
      isDark: isDark,
      onNavigateNav: (navIndex) {
        setState(() => _selectedNav = navIndex);
      },
      onRefreshAll: _loadAllData,
      onShowToast: (msg, {isError = false}) => _showToast(msg, isError: isError),
      onLaunchQuiz: _openLaunchQuizDialog,
      onPreviewQuiz: _previewQuestionsDialog,
    );
  }

  // ==========================================
  // ==========================================
  // TAB 1: COMPUTER-LIKE FOLDER EXPLORER (MODULAR TAB)
  // ==========================================

  final GlobalKey<FoldersTabState> _foldersTabKey = GlobalKey<FoldersTabState>();

  Widget _buildFolderExplorerTab() {
    return FoldersTab(
      key: _foldersTabKey,
      folders: _folders,
      quizzes: _quizzes,
      api: _api,
      tg: _tg,
      isDark: widget.isDark,
      onRefreshAll: _loadAllData,
      onShowToast: _showToast,
      onPreviewQuiz: _previewQuestionsDialog,
      onDeleteQuiz: _deleteQuizPrompt,
      onLaunchQuiz: _openLaunchQuizDialog,
    );
  }

  // TAB 2: TESTS & QUESTIONS (MODULAR TAB)
  // ==========================================

  final GlobalKey<TestsQuestionsTabState> _testsTabKey = GlobalKey<TestsQuestionsTabState>();

  Widget _buildQuizzesTab() {
    return TestsQuestionsTab(
      key: _testsTabKey,
      quizzes: _quizzes,
      resolvedStats: _resolvedStats,
      api: _api,
      tg: _tg,
      isDark: widget.isDark,
      onRefreshAll: _loadAllData,
      onShowToast: _showToast,
      onLaunchQuiz: _openLaunchQuizDialog,
      initialSearch: _quizTableSearch,
    );
  }

  void _previewQuestionsDialog(Map<String, dynamic> q) {
    setState(() => _selectedNav = 2);
    _testsTabKey.currentState?.selectQuiz(q, preview: true);
    _showToast('Live preview opened for: ${q['title']}');
  }

  Future<void> _deleteQuizPrompt(Map<String, dynamic> q) async {
    final quizId = q['id']?.toString() ?? '';
    final title = q['title']?.toString() ?? 'Test';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppTheme.rose),
            SizedBox(width: 8),
            Text('Delete Test Paper?'),
          ],
        ),
        content: Text('Are you sure you want to delete "$title"? This will remove all associated questions and test submissions permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Test', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && quizId.isNotEmpty) {
      final res = await _api.deleteQuiz(quizId);
      if (res['success'] == true) {
        _showToast('Test "$title" deleted successfully');
        _loadAllData();
      } else {
        _showToast('Failed to delete test: ${res['message'] ?? 'Unknown error'}');
      }
    }
  }

  // ==========================================
  // TAB 3: USERS MANAGEMENT (MODULAR TAB)
  // ==========================================

  final GlobalKey<UsersTabState> _usersTabKey = GlobalKey<UsersTabState>();

  Widget _buildStudentsTab() {
    return UsersTab(
      key: _usersTabKey,
      users: _users,
      resolvedStats: _resolvedStats,
      api: _api,
      tg: _tg,
      isDark: widget.isDark,
      onRefreshAll: _loadAllData,
      onShowToast: _showToast,
      initialSearch: _userSearch,
    );
  }

  // ==========================================
  // TAB 4: LEADERBOARD & MERIT STANDINGS (MODULAR TAB)
  // ==========================================

  Widget _buildLeaderboardTab() {
    return LeaderboardTab(
      globalLeaderboard: _globalLeaderboard,
      quizzes: _quizzes,
      api: _api,
      tg: _tg,
      isDark: widget.isDark,
      onRefreshLeaderboard: _loadLeaderboardData,
      onShowToast: (msg, {isError = false}) => _showToast(msg, isError: isError),
    );
  }

  // ==========================================
  // TAB 5: ADMINS MANAGEMENT HUB (MODULAR TAB)
  // ==========================================

  Widget _buildAdminsTab() {
    return AdminsTab(
      admins: _admins,
      api: _api,
      tg: _tg,
      isDark: widget.isDark,
      onRefreshAll: _loadAllData,
      onShowToast: (msg, {isError = false}) => _showToast(msg, isError: isError),
    );
  }

  // ==========================================
  // TAB 6: GROUP BATTLES (MODULAR TAB)
  // ==========================================

  Widget _buildBattlesTab() {
    return BattlesTab(
      groups: _groups,
      quizzes: _quizzes,
      api: _api,
      tg: _tg,
      isDark: widget.isDark,
      onRefreshAll: _loadAllData,
      onShowToast: (msg, {isError = false}) => _showToast(msg, isError: isError),
      onLaunchQuiz: _openLaunchQuizDialog,
    );
  }

  // ==========================================
  // TAB 7: BROADCAST TOOL (MODULAR TAB)
  // ==========================================

  Widget _buildBroadcastTab() {
    return BroadcastTab(
      api: _api,
      tg: _tg,
      isDark: widget.isDark,
      users: _users,
      quizzes: _quizzes,
      groups: _groups,
      stats: _stats,
      adminId: _adminId,
      adminName: _adminName,
      adminUsername: _adminUsername,
      onRefreshAll: _loadAllData,
      onShowToast: (msg, {isError = false}) => _showToast(msg, isError: isError),
    );
  }

  // ==========================================
  // TAB 8: GLOBAL PLATFORM SETTINGS (MODULAR TAB)
  // ==========================================

  Widget _buildSettingsTab() {
    return SettingsTab(
      settings: _settings,
      api: _api,
      isDark: widget.isDark,
      onRefreshAll: _loadAllData,
      onShowToast: (msg, {isError = false}) => _showToast(msg, isError: isError),
    );
  }

  // ==========================================
  // TAB 9: PAYMENTS & PLANS (MODULAR TAB)
  // ==========================================

  Widget _buildPaymentsTab() {
    return PaymentsTab(
      api: _api,
      tg: _tg,
      isDark: widget.isDark,
      onRefreshAll: _loadAllData,
      onShowToast: (msg, {isError = false}) => _showToast(msg, isError: isError),
    );
  }

  // ==========================================
  // ROOT BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        return Scaffold(
          key: _scaffoldKey,
          drawer: isDesktop ? null : _buildMobileDrawer(widget.isDark),
          body: Row(
            children: [
              if (isDesktop) _buildLeftSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildTopNavbar(isDesktop: isDesktop),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : IndexedStack(
                              index: _selectedNav,
                              children: [
                                _buildOverviewTab(),
                                _buildFolderExplorerTab(),
                                _buildQuizzesTab(),
                                _buildStudentsTab(),
                                _buildLeaderboardTab(),
                                _buildAdminsTab(),
                                _buildBattlesTab(),
                                _buildBroadcastTab(),
                                _buildSettingsTab(),
                                _buildPaymentsTab(),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedNav == 0
                      ? 0
                      : (_selectedNav == 2
                          ? 1
                          : (_selectedNav == 3
                              ? 2
                              : (_selectedNav == 4 ? 3 : 4))),
                  onDestinationSelected: (idx) {
                    _tg.hapticImpact('light');
                    if (idx == 0) {
                      setState(() => _selectedNav = 0);
                    } else if (idx == 1) {
                      setState(() => _selectedNav = 2);
                    } else if (idx == 2) {
                      setState(() => _selectedNav = 3);
                    } else if (idx == 3) {
                      setState(() => _selectedNav = 4);
                      _loadLeaderboardData();
                    } else if (idx == 4) {
                      _scaffoldKey.currentState?.openDrawer();
                    }
                  },
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
                    NavigationDestination(icon: Icon(Icons.quiz_rounded), label: 'Tests'),
                    NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Students'),
                    NavigationDestination(icon: Icon(Icons.emoji_events_rounded), label: 'Merit'),
                    NavigationDestination(icon: Icon(Icons.menu_rounded), label: 'More'),
                  ],
                ),
        );
      },
    );
  }
}
