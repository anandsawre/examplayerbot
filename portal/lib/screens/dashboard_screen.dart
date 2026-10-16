import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/telegram_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

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

  // Folder Explorer State
  String? _currentFolderId; // null = Root Catalog
  bool _isFolderTableView = false; // Grid vs Table view
  String _folderSearch = '';

  // Quizzes Filters
  String _quizSearch = '';
  String? _quizFolderFilter;
  String _quizTierFilter = 'all';

  // Students Filters
  String _userSearch = '';
  String _userTierFilter = 'all';

  // Leaderboard Subview State
  String _leaderboardViewMode = 'global'; // 'global' or 'quiz'
  String? _selectedLeaderboardQuizId;
  Map<String, dynamic> _quizLeaderboardData = {};
  bool _isQuizLeaderboardLoading = false;
  bool _isGlobalLeaderboardLoading = false;

  // Admin Profile Info
  String _adminId = '613840274';
  String _adminName = 'Anand';
  String _adminUsername = 'Anandsawre';
  String? _adminPhotoUrl;

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
        _api.getUsers(query: _userSearch, tier: _userTierFilter).catchError((_) => <dynamic>[]),
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
    setState(() => _isGlobalLeaderboardLoading = true);
    try {
      final list = await _api.getGlobalLeaderboard();
      if (mounted) {
        setState(() {
          _globalLeaderboard = list;
          _isGlobalLeaderboardLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isGlobalLeaderboardLoading = false);
      }
    }
  }

  Future<void> _loadQuizLeaderboard(String quizId) async {
    setState(() {
      _selectedLeaderboardQuizId = quizId;
      _isQuizLeaderboardLoading = true;
    });
    try {
      final res = await _api.getQuizLeaderboard(quizId);
      if (mounted) {
        setState(() {
          _quizLeaderboardData = res;
          _isQuizLeaderboardLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _quizLeaderboardData = {};
          _isQuizLeaderboardLoading = false;
        });
      }
    }
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
  // FOLDER EXPLORER HIERARCHY HELPERS
  // ==========================================

  List<Map<String, String>> _getBreadcrumbTrail() {
    final trail = <Map<String, String>>[];
    String? currentId = _currentFolderId;
    int guard = 0;

    while (currentId != null && guard < 15) {
      guard++;
      final f = _folders.cast<dynamic>().firstWhere(
            (item) => item['id']?.toString() == currentId,
            orElse: () => null,
          );
      if (f == null) break;
      trail.insert(0, {
        'id': f['id'].toString(),
        'name': f['name']?.toString() ?? 'Folder',
      });
      currentId = f['parent_id']?.toString();
    }
    return trail;
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

  Future<void> _createFolderDialog({String? preselectedParentId}) async {
    final nameCtrl = TextEditingController();
    String? selectedParentId = preselectedParentId ?? _currentFolderId;

    await showDialog(
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
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.create_new_folder_rounded, color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                selectedParentId != null ? 'Create New Subfolder' : 'Create New Folder',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: min(460.0, MediaQuery.of(ctx).size.width * 0.92),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Folder Name',
                    hintText: 'e.g. UPSC CSE, Prelims 2026, Indian Polity',
                    prefixIcon: Icon(Icons.folder_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Parent Location (Folder Hierarchy)',
                    prefixIcon: Icon(Icons.account_tree_outlined, size: 20),
                  ),
                  initialValue: selectedParentId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('🖥️ Root Catalog (Top Level)'),
                    ),
                    ..._folders.map((f) => DropdownMenuItem<String?>(
                          value: f['id'].toString(),
                          child: Text('📁 ${f['name'] ?? 'Unnamed Folder'}'),
                        )),
                  ],
                  onChanged: (val) => setDlgState(() => selectedParentId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final res = await _api.createFolder(nameCtrl.text.trim(), parentId: selectedParentId);
                if (res['success'] == true) {
                  _showToast(selectedParentId != null ? 'Subfolder created!' : 'Root folder created!');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Failed to create folder', isError: true);
                }
              },
              child: const Text('Create Folder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameFolderDialog(String folderId, String currentName) async {
    final nameCtrl = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Rename Folder', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New Folder Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final res = await _api.updateFolder(folderId, nameCtrl.text.trim());
              if (res['success'] == true) {
                _showToast('Folder renamed successfully!');
                _loadAllData();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveQuizDialog(Map<String, dynamic> quiz) async {
    String? targetFolderId = quiz['folder_id']?.toString();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Move "${quiz['title']}"', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SizedBox(
            width: min(440.0, MediaQuery.of(ctx).size.width * 0.92),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Select destination folder where this test file should reside:', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(labelText: 'Destination Folder'),
                  initialValue: targetFolderId,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('🖥️ Root Catalog (No Folder)')),
                    ..._folders.map((f) => DropdownMenuItem<String?>(
                          value: f['id'].toString(),
                          child: Text('📁 ${f['name']}'),
                        )),
                  ],
                  onChanged: (val) => setDlgState(() => targetFolderId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.updateQuiz(quiz['id'].toString(), {'folder_id': targetFolderId});
                if (res['success'] == true) {
                  _showToast('Test moved successfully!');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Move failed', isError: true);
                }
              },
              child: const Text('Move File'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importQuizDialog({String? preselectedFolderId}) async {
    final textController = TextEditingController();
    String? selectedFolderId = preselectedFolderId ?? _currentFolderId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.upload_file_rounded, color: AppTheme.emerald, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Import Exam Test (JSON)', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: min(540.0, MediaQuery.of(ctx).size.width * 0.92),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      try {
                        final files = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (files.isNotEmpty) {
                          final content = await files.first.xFile.readAsString();
                          setDlgState(() => textController.text = content);
                        }
                      } catch (e) {
                        _showToast('File picker error: $e', isError: true);
                      }
                    },
                    icon: const Icon(Icons.file_upload_outlined, size: 20),
                    label: const Text('Select JSON File from Computer'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Or paste JSON payload directly:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textController,
                    maxLines: 7,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: '{\n  "title": "SSC CGL 2026 Mock Test 1",\n  "questions": [...]\n}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(labelText: 'Target Folder Location'),
                    initialValue: selectedFolderId,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('🖥️ Root Catalog (General)')),
                      ..._folders.map((f) => DropdownMenuItem<String?>(
                            value: f['id'].toString(),
                            child: Text('📁 ${f['name'] ?? 'Unnamed'}'),
                          )),
                    ],
                    onChanged: (val) => setDlgState(() => selectedFolderId = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                if (textController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                _showToast('Importing quiz questions...');
                final res = await _api.importQuizJson(
                  textController.text.trim(),
                  folderId: selectedFolderId,
                );
                if (res['success'] == true) {
                  _showToast('Quiz imported: ${res['quiz']?['title'] ?? ''}');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Import failed', isError: true);
                }
              },
              child: const Text('Import Test Paper'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editQuizDialog(Map<String, dynamic> quiz) async {
    final titleCtrl = TextEditingController(text: quiz['title'] ?? '');
    final catCtrl = TextEditingController(text: quiz['category'] ?? 'General');
    final marksCtrl = TextEditingController(text: '${quiz['marks_per_question'] ?? quiz['correct_mark'] ?? 2.0}');
    final negCtrl = TextEditingController(text: '${quiz['negative_marks'] ?? quiz['negative_mark'] ?? 0.5}');
    final timeCtrl = TextEditingController(text: '${quiz['time_limit_seconds'] ?? quiz['per_question_time'] ?? 30}');
    bool isPrem = quiz['is_premium'] == true;
    String? selectedFolderId = quiz['folder_id']?.toString();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Edit Test Parameters', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: min(520.0, MediaQuery.of(ctx).size.width * 0.92),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          decoration: const InputDecoration(labelText: 'Folder Location'),
                          initialValue: selectedFolderId,
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Root Catalog')),
                            ..._folders.map((f) => DropdownMenuItem<String?>(value: f['id'].toString(), child: Text(f['name'] ?? ''))),
                          ],
                          onChanged: (val) => setDlgState(() => selectedFolderId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: marksCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Marks/Correct (+M)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: negCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Negative (-M)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: timeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seconds/Q'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Premium VIP Passholders Only', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: isPrem,
                    activeThumbColor: const Color(0xFFFBBF24),
                    onChanged: (val) => setDlgState(() => isPrem = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.updateQuiz(quiz['id'].toString(), {
                  'title': titleCtrl.text.trim(),
                  'category': catCtrl.text.trim(),
                  'marks_per_question': double.tryParse(marksCtrl.text) ?? 2.0,
                  'negative_marks': double.tryParse(negCtrl.text) ?? 0.5,
                  'time_limit_seconds': int.tryParse(timeCtrl.text) ?? 30,
                  'is_premium': isPrem,
                  'folder_id': selectedFolderId,
                });
                if (res['success'] == true) {
                  _showToast('Test updated!');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Update failed', isError: true);
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createQuizDialog({String? preselectedFolderId}) async {
    final titleCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'General Studies');
    final descCtrl = TextEditingController();
    final marksCtrl = TextEditingController(text: '2.0');
    final negCtrl = TextEditingController(text: '0.5');
    final timeCtrl = TextEditingController(text: '30');
    bool isPrem = false;
    String? selectedFolderId = preselectedFolderId ?? _currentFolderId;

    await showDialog(
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
                child: const Icon(Icons.add_task_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Create New Examination Paper', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: min(540.0, MediaQuery.of(ctx).size.width * 0.92),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Paper Title',
                      hintText: 'e.g. UPSC Prelims Mock Paper 2026',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: catCtrl,
                          decoration: const InputDecoration(labelText: 'Subject Category', hintText: 'e.g. General Studies'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          decoration: const InputDecoration(labelText: 'Folder Location'),
                          initialValue: selectedFolderId,
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('🖥️ Directory Root')),
                            ..._folders.map((f) => DropdownMenuItem<String?>(
                                  value: f['id'].toString(),
                                  child: Text('📁 ${f['name']}'),
                                )),
                          ],
                          onChanged: (val) => setDlgState(() => selectedFolderId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description / Syllabus',
                      hintText: 'Comprehensive test covering Indian Economy & Polity...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: marksCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Marks/Q (+M)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: negCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Penalty (-M)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: timeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Time (sec)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Require Premium Scholar Pass (Locked)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: isPrem,
                    activeThumbColor: const Color(0xFFFBBF24),
                    onChanged: (val) => setDlgState(() => isPrem = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final res = await _api.createQuiz(
                  title: titleCtrl.text.trim(),
                  category: catCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  marksPerQuestion: double.tryParse(marksCtrl.text) ?? 2.0,
                  negativeMarks: double.tryParse(negCtrl.text) ?? 0.5,
                  timeLimitSeconds: int.tryParse(timeCtrl.text) ?? 30,
                  isPremium: isPrem,
                  folderId: selectedFolderId,
                );
                if (res['success'] == true) {
                  _showToast('Examination record created! 🚀');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Creation failed', isError: true);
                }
              },
              child: const Text('Create Examination Record 🚀'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _appointAdminDialog() async {
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
                color: AppTheme.primarySubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.security_rounded, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Text('Appoint Platform Administrator', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
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
                  labelText: 'Candidate Telegram User ID (Numeric)',
                  hintText: 'e.g. 1234567890',
                  prefixIcon: Icon(Icons.person_pin_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Candidate can obtain their numeric ID by sending /id to @userinfobot or checking the Students Directory.',
                style: TextStyle(fontSize: 11, color: widget.isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () async {
              final id = idCtrl.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(ctx);
              final res = await _api.addAdmin(id);
              if (res['success'] == true) {
                _showToast('Administrator appointed successfully! 🛡️');
                _loadAllData();
              } else {
                _showToast(res['error'] ?? 'Failed to appoint admin', isError: true);
              }
            },
            child: const Text('Grant Admin Privileges 🛡️'),
          ),
        ],
      ),
    );
  }

  Future<void> _openScheduleBattleDialog(dynamic groupId, String groupTitle) async {
    if (_quizzes.isEmpty) {
      _showToast('No tests available to schedule. Create a test first.', isError: true);
      return;
    }

    String? selectedQuizId = _quizzes.first['id'].toString();
    String timingMode = 'preset';
    int delayMinutes = 15;
    final customTimeCtrl = TextEditingController();

    await showDialog(
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
                  color: AppTheme.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule_rounded, color: AppTheme.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Schedule Group Examination Battle', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(groupTitle, style: TextStyle(fontSize: 12, color: widget.isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: min(500.0, MediaQuery.of(ctx).size.width * 0.92),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Examination Paper'),
                    initialValue: selectedQuizId,
                    items: _quizzes.map((q) {
                      return DropdownMenuItem<String>(
                        value: q['id'].toString(),
                        child: Text('${q['title']} (${q['total_questions'] ?? 0} Qs)'),
                      );
                    }).toList(),
                    onChanged: (val) => setDlgState(() => selectedQuizId = val),
                  ),
                  const SizedBox(height: 16),
                  const Text('Execution Timing Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('⏱️ Quick Delay'),
                          selected: timingMode == 'preset',
                          onSelected: (val) {
                            if (val) setDlgState(() => timingMode = 'preset');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('🕒 Target IST Time'),
                          selected: timingMode == 'custom',
                          onSelected: (val) {
                            if (val) setDlgState(() => timingMode = 'custom');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (timingMode == 'preset') ...[
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Launch Delay from Now'),
                      initialValue: delayMinutes,
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('⏱️ 5 Minutes Delay')),
                        DropdownMenuItem(value: 15, child: Text('⏱️ 15 Minutes Delay')),
                        DropdownMenuItem(value: 30, child: Text('⏱️ 30 Minutes Delay')),
                        DropdownMenuItem(value: 60, child: Text('⏱️ 1 Hour Delay')),
                        DropdownMenuItem(value: 120, child: Text('⏱️ 2 Hours Delay')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => delayMinutes = val);
                      },
                    ),
                  ] else ...[
                    TextField(
                      controller: customTimeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Target IST Time Slot (Today)',
                        hintText: 'e.g. 20:00 or 8:30 PM or 45',
                        helperText: 'Supports 24h format (21:00), 12h format (9:00 PM), or relative minutes.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_outlined, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The bot will post an official schedule announcement with countdown in the group, deliver a 60-second alert before starting, and trigger the polls automatically.',
                            style: TextStyle(fontSize: 11, color: widget.isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                if (selectedQuizId == null) return;
                Navigator.pop(ctx);
                _showToast('Scheduling group examination session...');
                final res = await _api.scheduleGroupBattle(
                  groupId,
                  selectedQuizId!,
                  delayMinutes: timingMode == 'preset' ? delayMinutes : null,
                  timeStr: timingMode == 'custom' ? customTimeCtrl.text.trim() : null,
                );
                if (res['success'] == true) {
                  _showToast('Battle scheduled for ${res['timeFormatted'] ?? 'set time'} IST! ⏰');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Scheduling failed', isError: true);
                }
              },
              child: const Text('⏰ Confirm & Schedule', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
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
                _loadAllData();
              } else {
                _showToast(res['error'] ?? 'Failed to grant pass', isError: true);
              }
            },
            child: const Text('Grant Scholar Pass ⚡'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroupPrompt(dynamic groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Group?'),
        content: Text('Permanently remove group record $groupId from authorized list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove Group'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final res = await _api.deleteGroup(groupId);
      if (res['success'] == true) {
        _showToast('Group record deleted.');
        _loadAllData();
      } else {
        _showToast(res['error'] ?? 'Delete failed', isError: true);
      }
    }
  }

  Future<void> _cancelGroupSchedulePrompt(dynamic groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Scheduled Battle?'),
        content: const Text('Cancel scheduled examination session for this group? An official cancellation notice will be dispatched to the group.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Schedule'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final res = await _api.cancelGroupSchedule(groupId);
      if (res['success'] == true) {
        _showToast('Scheduled session cancelled. Notice sent to group.');
        _loadAllData();
      } else {
        _showToast(res['error'] ?? 'Failed to cancel schedule', isError: true);
      }
    }
  }

  Future<void> _addQuestionDialog(String quizId, VoidCallback onRefresh) async {
    final qTextCtrl = TextEditingController();
    final opt0Ctrl = TextEditingController();
    final opt1Ctrl = TextEditingController();
    final opt2Ctrl = TextEditingController();
    final opt3Ctrl = TextEditingController();
    final expCtrl = TextEditingController();
    int correctIdx = 0;
    bool hasFormula = false;

    await showDialog(
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
                  color: AppTheme.emeraldSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.emerald, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Add Question to Paper', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: min(540.0, MediaQuery.of(ctx).size.width * 0.92),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: qTextCtrl,
                    maxLines: 2,
                    onChanged: (val) {
                      final containsFormula = val.contains('^') || val.contains('_') || val.contains('\\') || val.contains('\$');
                      if (containsFormula != hasFormula) {
                        setDlgState(() => hasFormula = containsFormula);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Question Text',
                      hintText: 'e.g. What is the acceleration due to gravity (g)?',
                    ),
                  ),
                  if (hasFormula) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.cyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Live Math Notation: ${qTextCtrl.text}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.cyan),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: opt0Ctrl,
                          decoration: const InputDecoration(labelText: 'Option A'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: opt1Ctrl,
                          decoration: const InputDecoration(labelText: 'Option B'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: opt2Ctrl,
                          decoration: const InputDecoration(labelText: 'Option C'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: opt3Ctrl,
                          decoration: const InputDecoration(labelText: 'Option D'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: 'Correct Answer'),
                          initialValue: correctIdx,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Option A')),
                            DropdownMenuItem(value: 1, child: Text('Option B')),
                            DropdownMenuItem(value: 2, child: Text('Option C')),
                            DropdownMenuItem(value: 3, child: Text('Option D')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => correctIdx = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: expCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Detailed Explanation',
                            hintText: 'Standard gravity is 9.8 m/s²...',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final qText = qTextCtrl.text.trim();
                final o0 = opt0Ctrl.text.trim();
                final o1 = opt1Ctrl.text.trim();
                final o2 = opt2Ctrl.text.trim();
                final o3 = opt3Ctrl.text.trim();
                if (qText.isEmpty || o0.isEmpty || o1.isEmpty || o2.isEmpty || o3.isEmpty) {
                  _showToast('Please enter question text and all 4 options.', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                final res = await _api.addQuestion(
                  quizId,
                  questionText: qText,
                  options: [o0, o1, o2, o3],
                  correctOptionIndex: correctIdx,
                  explanation: expCtrl.text.trim().isNotEmpty ? expCtrl.text.trim() : null,
                );
                if (res['success'] == true) {
                  _showToast('Question inserted! ➕');
                  onRefresh();
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Failed to add question', isError: true);
                }
              },
              child: const Text('Insert Question ➕'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editQuestionDialog(Map<String, dynamic> question, VoidCallback onRefresh) async {
    final qTextCtrl = TextEditingController(text: question['question_text'] ?? '');
    final opts = question['options'] is List ? (question['options'] as List) : [];
    final opt0Ctrl = TextEditingController(text: opts.isNotEmpty ? opts[0].toString() : '');
    final opt1Ctrl = TextEditingController(text: opts.length > 1 ? opts[1].toString() : '');
    final opt2Ctrl = TextEditingController(text: opts.length > 2 ? opts[2].toString() : '');
    final opt3Ctrl = TextEditingController(text: opts.length > 3 ? opts[3].toString() : '');
    final expCtrl = TextEditingController(text: question['explanation'] ?? '');
    int correctIdx = (question['correct_option_index'] is int)
        ? question['correct_option_index'] as int
        : (int.tryParse('${question['correct_option_index'] ?? question['correct_option']}') ?? 0);
    if (correctIdx < 0 || correctIdx > 3) correctIdx = 0;

    await showDialog(
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
                child: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Edit Question', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: min(540.0, MediaQuery.of(ctx).size.width * 0.92),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: qTextCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Question Text'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: opt0Ctrl, decoration: const InputDecoration(labelText: 'Option A'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: opt1Ctrl, decoration: const InputDecoration(labelText: 'Option B'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: opt2Ctrl, decoration: const InputDecoration(labelText: 'Option C'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: opt3Ctrl, decoration: const InputDecoration(labelText: 'Option D'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: 'Correct Option'),
                          initialValue: correctIdx,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Option A')),
                            DropdownMenuItem(value: 1, child: Text('Option B')),
                            DropdownMenuItem(value: 2, child: Text('Option C')),
                            DropdownMenuItem(value: 3, child: Text('Option D')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => correctIdx = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: expCtrl,
                          decoration: const InputDecoration(labelText: 'Detailed Explanation'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.updateQuestion(
                  question['id'].toString(),
                  questionText: qTextCtrl.text.trim(),
                  options: [opt0Ctrl.text.trim(), opt1Ctrl.text.trim(), opt2Ctrl.text.trim(), opt3Ctrl.text.trim()],
                  correctOptionIndex: correctIdx,
                  explanation: expCtrl.text.trim().isNotEmpty ? expCtrl.text.trim() : null,
                );
                if (res['success'] == true) {
                  _showToast('Question updated! 💾');
                  onRefresh();
                } else {
                  _showToast(res['error'] ?? 'Update failed', isError: true);
                }
              },
              child: const Text('Save Question Changes 💾'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // NAVIGATION & SHELL LAYOUT
  // ==========================================

  Widget _buildLeftSidebar() {
    final isDark = widget.isDark;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar,
        border: Border(right: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand Header (Height exactly aligned with top navbar)
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryHover],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.smart_toy_rounded, size: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Examplayer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('ENTERPRISE 2026', style: GoogleFonts.inter(fontSize: 8.5, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Navigation Links (9 items matching HTML console)
          _sidebarItem(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0),
          _sidebarItem(icon: Icons.folder_copy_rounded, title: 'Folders & Hierarchy', index: 1, badge: '${_folders.length}'),
          _sidebarItem(icon: Icons.quiz_rounded, title: 'Tests & Questions', index: 2, badge: '${_quizzes.length}'),
          _sidebarItem(icon: Icons.people_alt_rounded, title: 'Students Directory', index: 3, badge: '${_users.length}'),
          _sidebarItem(icon: Icons.emoji_events_rounded, title: 'Leaderboard & Merit', index: 4, badge: '${_globalLeaderboard.length}'),
          _sidebarItem(icon: Icons.shield_rounded, title: 'Admins Hub', index: 5, badge: '${_admins.length}'),
          _sidebarItem(icon: Icons.account_balance_rounded, title: 'Community Groups', index: 6, badge: '${_groups.length}'),
          _sidebarItem(icon: Icons.campaign_rounded, title: 'Broadcast Studio', index: 7),
          _sidebarItem(icon: Icons.settings_rounded, title: 'System Settings', index: 8),

          const Spacer(),

          // System Status Pill
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.emerald,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Webhook & DB Online',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User Profile & Logout Bottom Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface.withValues(alpha: 0.5) : Colors.white,
              border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
            ),
            child: Row(
              children: [
                UserAvatar(
                  userId: _adminId,
                  name: _adminName,
                  radius: 17,
                  isRootAdmin: true,
                  customUrl: _adminPhotoUrl,
                  showOnlineDot: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adminName,
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@$_adminUsername',
                        style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 17),
                  tooltip: 'Logout',
                  onPressed: widget.onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String title,
    required int index,
    String? badge,
    bool closeDrawerOnTap = false,
  }) {
    final isSelected = _selectedNav == index;
    final isDark = widget.isDark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            _tg.hapticImpact('light');
            if (closeDrawerOnTap) {
              Navigator.of(context).pop();
            }
            setState(() => _selectedNav = index);
            if (index == 4) {
              _loadLeaderboardData();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppTheme.primarySubtle : AppTheme.primary.withValues(alpha: 0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3))
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : AppTheme.primary)
                          : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkSurface : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Brand Header with Close Button
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.smart_toy_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Examplayer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySubtle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('ENTERPRISE 2026', style: GoogleFonts.inter(fontSize: 8.5, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close Navigation',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Navigation Links (All 9 items)
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _sidebarItem(icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0, closeDrawerOnTap: true),
                  _sidebarItem(icon: Icons.folder_copy_rounded, title: 'Folders & Hierarchy', index: 1, badge: '${_folders.length}', closeDrawerOnTap: true),
                  _sidebarItem(icon: Icons.quiz_rounded, title: 'Tests & Questions', index: 2, badge: '${_quizzes.length}', closeDrawerOnTap: true),
                  _sidebarItem(icon: Icons.people_alt_rounded, title: 'Students Directory', index: 3, badge: '${_users.length}', closeDrawerOnTap: true),
                  _sidebarItem(icon: Icons.emoji_events_rounded, title: 'Leaderboard & Merit', index: 4, badge: '${_globalLeaderboard.length}', closeDrawerOnTap: true),
                  _sidebarItem(icon: Icons.shield_rounded, title: 'Admins Hub', index: 5, badge: '${_admins.length}', closeDrawerOnTap: true),
                  _sidebarItem(icon: Icons.account_balance_rounded, title: 'Community Groups', index: 6, badge: '${_groups.length}', closeDrawerOnTap: true),
                  _sidebarItem(icon: Icons.campaign_rounded, title: 'Broadcast Studio', index: 7, closeDrawerOnTap: true),
                  _sidebarItem(icon: Icons.settings_rounded, title: 'System Settings', index: 8, closeDrawerOnTap: true),
                ],
              ),
            ),

            // System Status Pill
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.emerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Webhook & DB Online',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Profile & Logout
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface.withValues(alpha: 0.5) : Colors.white,
                border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    userId: _adminId,
                    name: _adminName,
                    radius: 17,
                    isRootAdmin: true,
                    customUrl: _adminPhotoUrl,
                    showOnlineDot: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adminName,
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@$_adminUsername',
                          style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 17),
                    tooltip: 'Logout',
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onLogout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavbar({required bool isDesktop}) {
    final isDark = widget.isDark;
    final titles = [
      'Operational Dashboard',
      'Examination Folders & Directories',
      'Examinations Catalog & Papers',
      'Candidate Directory & Pass Management',
      'Competitive Merit Standings',
      'Platform Administrators Hub',
      'Community Groups Authorization Desk',
      'Announcement Broadcast Studio',
      'Global Platform Settings',
    ];

    if (!isDesktop) {
      // Mobile Top Navbar (Clean, 64px, never overflows)
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
          border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 24),
              tooltip: 'Open Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                titles[_selectedNav.clamp(0, titles.length - 1)],
                style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Contextual compact actions on mobile
            if (_selectedNav == 0 || _selectedNav == 1 || _selectedNav == 2) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.upload_file_rounded, size: 20),
                tooltip: 'Import JSON',
                onPressed: () => _importQuizDialog(),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle, color: AppTheme.primary, size: 22),
                tooltip: 'Create Test',
                onPressed: () => _createQuizDialog(),
              ),
            ] else if (_selectedNav == 3) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.bolt_rounded, color: AppTheme.emerald, size: 22),
                tooltip: 'Quick Pass by ID',
                onPressed: _quickPassPrompt,
              ),
            ] else if (_selectedNav == 4) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Standings',
                onPressed: () {
                  _loadLeaderboardData();
                  if (_selectedLeaderboardQuizId != null) {
                    _loadQuizLeaderboard(_selectedLeaderboardQuizId!);
                  }
                },
              ),
            ] else if (_selectedNav == 5) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.shield_rounded, color: AppTheme.primary, size: 20),
                tooltip: 'Appoint Admin',
                onPressed: _appointAdminDialog,
              ),
            ],

            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
              tooltip: 'Toggle Theme',
              onPressed: widget.onToggleTheme,
            ),
            const SizedBox(width: 4),

            InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: UserAvatar(
                  userId: _adminId,
                  name: _adminName,
                  radius: 13,
                  isRootAdmin: true,
                  customUrl: _adminPhotoUrl,
                  showBadge: false,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Desktop Top Navbar
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
      ),
      child: Row(
        children: [
          Text(
            titles[_selectedNav.clamp(0, titles.length - 1)],
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Spacer(),

          // Contextual Topbar Actions based on active tab
          if (_selectedNav == 0 || _selectedNav == 1 || _selectedNav == 2) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.upload_file_rounded, size: 15),
              label: const Text('Import JSON', style: TextStyle(fontSize: 12)),
              onPressed: () => _importQuizDialog(),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Create Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: () => _createQuizDialog(),
            ),
            const SizedBox(width: 12),
          ] else if (_selectedNav == 3) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.bolt_rounded, size: 16),
              label: const Text('Quick Pass by ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: _quickPassPrompt,
            ),
            const SizedBox(width: 12),
          ] else if (_selectedNav == 4) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Refresh Standings', style: TextStyle(fontSize: 12)),
              onPressed: () {
                _loadLeaderboardData();
                if (_selectedLeaderboardQuizId != null) {
                  _loadQuizLeaderboard(_selectedLeaderboardQuizId!);
                }
              },
            ),
            const SizedBox(width: 12),
          ] else if (_selectedNav == 5) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.shield_rounded, size: 15),
              label: const Text('Appoint Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: _appointAdminDialog,
            ),
            const SizedBox(width: 12),
          ],

          // Telegram Bot Handle Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF229ED9).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF229ED9).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.telegram, color: Color(0xFF229ED9), size: 16),
                SizedBox(width: 6),
                Text('@Examplayer_bot', style: TextStyle(fontSize: 12, color: Color(0xFF229ED9), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Sync Button
          IconButton(
            icon: const Icon(Icons.sync_rounded, size: 19),
            tooltip: 'Sync Live Data',
            onPressed: _loadAllData,
          ),

          // Theme Mode Switch
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 19),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),

          // Top Header Avatar Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
            ),
            child: Row(
              children: [
                UserAvatar(
                  userId: _adminId,
                  name: _adminName,
                  radius: 13,
                  isRootAdmin: true,
                  customUrl: _adminPhotoUrl,
                  showBadge: false,
                ),
                const SizedBox(width: 8),
                Text(
                  _adminName,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 0: CLEAN OVERVIEW DASHBOARD
  // ==========================================

  Widget _buildOverviewTab() {
    final statsData = _stats['stats'] ?? {};
    final isDark = widget.isDark;

    return LayoutBuilder(
      builder: (context, rootConstraints) {
        final isMobile = rootConstraints.maxWidth < 650;

        final recentQuizzesCard = Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.quiz_rounded, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text('Active Quizzes Catalog', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedNav = 2),
                      child: const Text('View All Quizzes ➔', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
              if (_quizzes.isEmpty)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No quizzes uploaded yet.')))
              else
                ..._quizzes.take(5).map((q) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(q['title'] ?? 'Quiz', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                                Text('${q['folder_name'] ?? 'Root'} • ${q['category'] ?? 'General'}',
                                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.rocket_launch_rounded, size: 13),
                            label: const Text('Launch', style: TextStyle(fontSize: 11)),
                            onPressed: () => _openLaunchQuizDialog(q['id'].toString(), q['title'] ?? 'Quiz'),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        );

        final leaderboardTopCard = Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 8),
                        Text('Leaderboard Top 5', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Text('${_globalLeaderboard.length} Ranked', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub)),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
              if (_globalLeaderboard.isEmpty)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No rank records yet.')))
              else
                ..._globalLeaderboard.take(5).toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final u = entry.value;
                  final medal = idx == 0 ? '🥇' : (idx == 1 ? '🥈' : (idx == 2 ? '🥉' : '#${idx + 1}'));
                  final name = (u['first_name'] ?? u['username'] ?? 'Student').toString();
                  final score = u['total_score'] ?? 0;
                  final isPrem = u['is_premium'] == true;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(medal, style: TextStyle(fontSize: idx < 3 ? 16 : 12, fontWeight: FontWeight.w700)),
                        ),
                        UserAvatar(
                          userId: (u['id'] ?? u['user_id'] ?? '').toString(),
                          name: name,
                          radius: 14,
                          isPremium: isPrem,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                        ),
                        Text('$score pts', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.emerald)),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );

        return ListView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          children: [
            if (_statusMsg.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.roseSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.rose, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_statusMsg, style: const TextStyle(color: AppTheme.rose, fontSize: 12))),
                  ],
                ),
              ),
            ],

            // Hero Welcome Card with Admin Avatar
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF162038), const Color(0xFF0F172A)]
                      : [const Color(0xFFEEF2FF), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                              userId: _adminId,
                              name: _adminName,
                              radius: 24,
                              isRootAdmin: true,
                              customUrl: _adminPhotoUrl,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, $_adminName! 👋',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Examplayer Command Center',
                                    style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                              onPressed: () => setState(() => _selectedNav = 1),
                              icon: const Icon(Icons.folder_open_rounded, size: 15),
                              label: const Text('Folder Explorer', style: TextStyle(fontSize: 12)),
                            ),
                            OutlinedButton.icon(
                              onPressed: _importQuizDialog,
                              icon: const Icon(Icons.upload_file_rounded, size: 15),
                              label: const Text('Import Test JSON', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        UserAvatar(
                          userId: _adminId,
                          name: _adminName,
                          radius: 28,
                          isRootAdmin: true,
                          customUrl: _adminPhotoUrl,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to Examplayer Command Center, $_adminName! 👋',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage computer-like nested folders, launch group battles, and monitor enrolled students.',
                                style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                              onPressed: () => setState(() => _selectedNav = 1),
                              icon: const Icon(Icons.folder_open_rounded, size: 16),
                              label: const Text('Open Folder Explorer'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _importQuizDialog,
                              icon: const Icon(Icons.upload_file_rounded, size: 16),
                              label: const Text('Import Test JSON'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),

            // 6 Modern Metric Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 1100 ? 6 : (constraints.maxWidth > 700 ? 3 : 2);
                final ratio = constraints.maxWidth < 450 ? 1.35 : 1.6;
                return GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: ratio,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _kpiTile('Tests Published', '${statsData['totalQuizzes'] ?? _quizzes.length}', Icons.quiz_outlined, AppTheme.primary),
                    _kpiTile('Question Bank', '${statsData['totalQuestions'] ?? 0}', Icons.help_outline_rounded, AppTheme.cyan),
                    _kpiTile('Test Attempts', '${statsData['totalAttempts'] ?? 0}', Icons.timer_outlined, AppTheme.amber),
                    _kpiTile('Students', '${statsData['totalUsers'] ?? _users.length}', Icons.people_outline_rounded, AppTheme.emerald),
                    _kpiTile('VIP Passes', '${statsData['premiumUsers'] ?? 0}', Icons.workspace_premium_outlined, const Color(0xFFFBBF24)),
                    _kpiTile('Active Groups', '${statsData['authorizedGroups'] ?? _groups.length}', Icons.groups_rounded, AppTheme.purple),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),

            // Split Section: Recent Quizzes & Global Leaderboard
            LayoutBuilder(
              builder: (context, splitConstraints) {
                final isStacked = splitConstraints.maxWidth < 750;
                if (isStacked) {
                  return Column(
                    children: [
                      recentQuizzesCard,
                      const SizedBox(height: 16),
                      leaderboardTopCard,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: recentQuizzesCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: leaderboardTopCard),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _kpiTile(String label, String value, IconData icon, Color color) {
    final isDark = widget.isDark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: COMPUTER-LIKE FOLDER EXPLORER
  // (As user specifically demanded: "jaise computer pe hota hai ek folder ko click kiye uske ander ka folder khula...")
  // ==========================================

  Widget _buildFolderExplorerTab() {
    final isDark = widget.isDark;
    final isRoot = _currentFolderId == null;

    final currentFolder = isRoot
        ? null
        : _folders.cast<dynamic>().firstWhere(
            (f) => f['id']?.toString() == _currentFolderId,
            orElse: () => null,
          );

    final breadcrumbs = _getBreadcrumbTrail();

    // 1. Subfolders inside current directory
    final currentSubfolders = _folders.where((f) {
      if (isRoot) {
        final pid = f['parent_id'];
        return pid == null || pid == '' || pid == 'null';
      }
      return f['parent_id']?.toString() == _currentFolderId;
    }).where((f) {
      if (_folderSearch.isEmpty) return true;
      return (f['name'] ?? '').toString().toLowerCase().contains(_folderSearch.toLowerCase());
    }).toList();

    // 2. Exam files inside current directory
    final currentTests = _quizzes.where((q) {
      if (isRoot) {
        final fid = q['folder_id'];
        return fid == null || fid == '' || fid == 'null';
      }
      return q['folder_id']?.toString() == _currentFolderId;
    }).where((q) {
      if (_folderSearch.isEmpty) return true;
      return (q['title'] ?? '').toString().toLowerCase().contains(_folderSearch.toLowerCase());
    }).toList();

    return LayoutBuilder(
      builder: (context, explorerConstraints) {
        final isMobile = explorerConstraints.maxWidth < 650;

        return ListView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          children: [
            // 1. WINDOWS-STYLE ADDRESS & NAVIGATION BAR
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                                tooltip: 'Go Up',
                                onPressed: isRoot
                                    ? null
                                    : () {
                                        _tg.hapticImpact('light');
                                        final parentId = currentFolder?['parent_id']?.toString();
                                        setState(() => _currentFolderId = parentId);
                                      },
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.computer_rounded, size: 18),
                                tooltip: 'Root',
                                onPressed: isRoot
                                    ? null
                                    : () {
                                        _tg.hapticImpact('light');
                                        setState(() => _currentFolderId = null);
                                      },
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        InkWell(
                                          borderRadius: BorderRadius.circular(6),
                                          onTap: isRoot ? null : () => setState(() => _currentFolderId = null),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.home_rounded, size: 14, color: AppTheme.primary),
                                                SizedBox(width: 4),
                                                Text('Bot Root', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        ...breadcrumbs.map((crumb) {
                                          final isLast = crumb['id'] == _currentFolderId;
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.chevron_right_rounded, size: 14),
                                              InkWell(
                                                borderRadius: BorderRadius.circular(6),
                                                onTap: isLast
                                                    ? null
                                                    : () {
                                                        _tg.hapticImpact('light');
                                                        setState(() => _currentFolderId = crumb['id']);
                                                      },
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                  child: Text(
                                                    crumb['name']!,
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: isLast ? FontWeight.w800 : FontWeight.w500,
                                                      color: isLast ? AppTheme.primary : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(_isFolderTableView ? Icons.grid_view_rounded : Icons.view_list_rounded, size: 19),
                                tooltip: _isFolderTableView ? 'Grid View' : 'Details View',
                                onPressed: () => setState(() => _isFolderTableView = !_isFolderTableView),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _createFolderDialog(preselectedParentId: _currentFolderId),
                                icon: const Icon(Icons.create_new_folder_outlined, size: 14),
                                label: Text(isRoot ? 'New Folder' : 'New Subfolder', style: const TextStyle(fontSize: 11.5)),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.emerald,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _importQuizDialog(preselectedFolderId: _currentFolderId),
                                icon: const Icon(Icons.upload_file_outlined, size: 14),
                                label: const Text('New Test File', style: TextStyle(fontSize: 11.5)),
                              ),
                              if (!isRoot) ...[
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit_outlined, size: 17),
                                  tooltip: 'Rename Folder',
                                  onPressed: () => _renameFolderDialog(_currentFolderId!, currentFolder?['name'] ?? ''),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline, size: 17, color: AppTheme.rose),
                                  tooltip: 'Delete Folder',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Folder?'),
                                        content: Text('Are you sure you want to delete "${currentFolder?['name']}"? All contents will be moved to root.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final res = await _api.deleteFolder(_currentFolderId!);
                                      if (res['success'] == true) {
                                        _showToast('Folder deleted.');
                                        final parentId = currentFolder?['parent_id']?.toString();
                                        setState(() => _currentFolderId = parentId);
                                        _loadAllData();
                                      }
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Back Button (Up one folder level)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.arrow_upward_rounded, size: 19),
                            tooltip: 'Go Up to Parent Folder',
                            onPressed: isRoot
                                ? null
                                : () {
                                    _tg.hapticImpact('light');
                                    final parentId = currentFolder?['parent_id']?.toString();
                                    setState(() => _currentFolderId = parentId);
                                  },
                          ),
                          // Home Button (Root directory)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.computer_rounded, size: 19),
                            tooltip: 'Go to Root Catalog',
                            onPressed: isRoot ? null : () {
                              _tg.hapticImpact('light');
                              setState(() => _currentFolderId = null);
                            },
                          ),
                          const SizedBox(width: 8),

                          // Interactive Clickable Breadcrumbs Bar
                          Expanded(
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: isRoot ? null : () => setState(() => _currentFolderId = null),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.home_rounded, size: 15, color: AppTheme.primary),
                                            const SizedBox(width: 6),
                                            Text(
                                              'This Bot',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: isRoot ? FontWeight.w800 : FontWeight.w500,
                                                color: isRoot ? AppTheme.primary : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    ...breadcrumbs.map((crumb) {
                                      final isLast = crumb['id'] == _currentFolderId;
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4),
                                            child: Icon(Icons.chevron_right_rounded, size: 16),
                                          ),
                                          InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: isLast ? null : () {
                                              _tg.hapticImpact('light');
                                              setState(() => _currentFolderId = crumb['id']);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.folder_open_rounded, size: 15, color: Color(0xFFF59E0B)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    crumb['name']!,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: isLast ? FontWeight.w800 : FontWeight.w500,
                                                      color: isLast ? AppTheme.primary : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // View Toggle (Grid vs Table)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(_isFolderTableView ? Icons.grid_view_rounded : Icons.view_list_rounded, size: 20),
                            tooltip: _isFolderTableView ? 'Switch to Grid View' : 'Switch to Details List View',
                            onPressed: () => setState(() => _isFolderTableView = !_isFolderTableView),
                          ),
                          const SizedBox(width: 6),

                          // Action: New Folder
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onPressed: () => _createFolderDialog(preselectedParentId: _currentFolderId),
                            icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                            label: Text(isRoot ? 'New Root Folder' : 'New Subfolder', style: const TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),

                          // Action: New Test File
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emerald,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onPressed: () => _importQuizDialog(preselectedFolderId: _currentFolderId),
                            icon: const Icon(Icons.upload_file_outlined, size: 16),
                            label: const Text('New Test File', style: TextStyle(fontSize: 12)),
                          ),

                          // Current Folder Rename / Delete actions
                          if (!isRoot) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Rename Current Folder',
                              onPressed: () => _renameFolderDialog(_currentFolderId!, currentFolder?['name'] ?? ''),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.rose),
                              tooltip: 'Delete Current Folder',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Folder?'),
                                    content: Text('Are you sure you want to delete "${currentFolder?['name']}"? All contents will be moved to root.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final res = await _api.deleteFolder(_currentFolderId!);
                                  if (res['success'] == true) {
                                    _showToast('Folder deleted.');
                                    final parentId = currentFolder?['parent_id']?.toString();
                                    setState(() => _currentFolderId = parentId);
                                    _loadAllData();
                                  }
                                }
                              },
                            ),
                          ],
                        ],
                      ),
              ),
            ),
        const SizedBox(height: 20),

        // Search Filter inside this folder
        TextField(
          onChanged: (val) => setState(() => _folderSearch = val),
          decoration: InputDecoration(
            hintText: 'Search files and folders in current directory...',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _folderSearch.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => setState(() => _folderSearch = ''),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 20),

        // 2. MAIN CONTENTS: SUBFOLDERS & TEST FILES
        if (currentSubfolders.isEmpty && currentTests.isEmpty)
          Container(
            padding: const EdgeInsets.all(60),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_rounded, size: 64, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub),
                const SizedBox(height: 16),
                Text('This folder is currently empty', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'No subfolders or exam test files exist in this folder yet.',
                  style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      onPressed: () => _createFolderDialog(preselectedParentId: _currentFolderId),
                      icon: const Icon(Icons.create_new_folder_rounded, size: 16),
                      label: const Text('Create Subfolder Here'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _importQuizDialog(preselectedFolderId: _currentFolderId),
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('Import Test Paper Here'),
                    ),
                  ],
                ),
              ],
            ),
          )
        else if (_isFolderTableView)
          // DETAILS / TABLE VIEW
          _buildExplorerDetailsTable(currentSubfolders, currentTests)
        else
          // GRID VIEW (Intuitive computer file icons)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION A: SUBFOLDERS
              if (currentSubfolders.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.folder_rounded, size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Text(
                      'Folders (${currentSubfolders.length})',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text('• Click any folder to drill down into it',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub)),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisExtent: 115,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: currentSubfolders.length,
                      itemBuilder: (ctx, idx) {
                        final f = currentSubfolders[idx];
                        final fId = f['id'].toString();
                        final subCount = _folders.where((sf) => sf['parent_id']?.toString() == fId).length;
                        final testCount = _quizzes.where((q) => q['folder_id']?.toString() == fId).length;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              _tg.hapticImpact('light');
                              setState(() => _currentFolderId = fId);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.folder_rounded, size: 36, color: Color(0xFFF59E0B)),
                                      const Spacer(),
                                      PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        iconSize: 18,
                                        tooltip: 'Folder Actions',
                                        onSelected: (val) {
                                          if (val == 'open') setState(() => _currentFolderId = fId);
                                          if (val == 'rename') _renameFolderDialog(fId, f['name'] ?? '');
                                          if (val == 'delete') {
                                            _api.deleteFolder(fId).then((res) {
                                              if (res['success'] == true) {
                                                _showToast('Folder deleted');
                                                _loadAllData();
                                              }
                                            });
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(value: 'open', child: Text('Open Folder ➔', style: TextStyle(fontSize: 12))),
                                          const PopupMenuItem(value: 'rename', child: Text('Rename', style: TextStyle(fontSize: 12))),
                                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(fontSize: 12, color: AppTheme.rose))),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        f['name'] ?? 'Folder',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$subCount folders • $testCount tests',
                                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 26),
              ],

              // SECTION B: EXAM TEST FILES
              if (currentTests.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.description_rounded, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Exam Test Files (${currentTests.length})',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text('• Click "Launch Battle" to broadcast live test to Telegram group',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub)),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        mainAxisExtent: 155,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: currentTests.length,
                      itemBuilder: (ctx, idx) {
                        final q = currentTests[idx];
                        final isPrem = q['is_premium'] == true;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primarySubtle,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.assignment_outlined, size: 18, color: AppTheme.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          q['title'] ?? 'Test Paper',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Marks: +${q['marks_per_question'] ?? 2} / -${q['negative_marks'] ?? 0.5} • ${q['time_limit_seconds'] ?? 30}s',
                                          style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPrem ? const Color(0xFFFBBF24).withValues(alpha: 0.15) : AppTheme.emeraldSubtle,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isPrem ? 'VIP' : 'Free',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isPrem ? const Color(0xFFFBBF24) : AppTheme.emerald),
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
                              Row(
                                children: [
                                  // Prominent Launch Battle Button!
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.rocket_launch_rounded, size: 13),
                                    label: const Text('Launch Battle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    onPressed: () => _openLaunchQuizDialog(q['id'].toString(), q['title'] ?? 'Quiz'),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(Icons.folder_shared_outlined, size: 16),
                                    tooltip: 'Move to Another Folder',
                                    onPressed: () => _moveQuizDialog(q),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(Icons.visibility_outlined, size: 16),
                                    tooltip: 'Preview Questions',
                                    onPressed: () => _previewQuestionsDialog(q),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    tooltip: 'Edit Parameters',
                                    onPressed: () => _editQuizDialog(q),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.rose, size: 16),
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteQuizPrompt(q),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      );
    },
  );
}

  Widget _buildExplorerDetailsTable(List<dynamic> subfolders, List<dynamic> tests) {
    final isDark = widget.isDark;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = max(constraints.maxWidth, 700.0);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 4, child: Text('NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                    Expanded(flex: 2, child: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                    Expanded(flex: 2, child: Text('ITEMS / MARKS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                    Expanded(flex: 1, child: Text('ACCESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                    SizedBox(width: 140, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),

              // Subfolders Rows
              ...subfolders.map((f) {
                final fId = f['id'].toString();
                final count = _quizzes.where((q) => q['folder_id']?.toString() == fId).length;

                return InkWell(
                  onTap: () {
                    _tg.hapticImpact('light');
                    setState(() => _currentFolderId = fId);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              const Icon(Icons.folder_rounded, color: Color(0xFFF59E0B), size: 20),
                              const SizedBox(width: 10),
                              Text(f['name'] ?? 'Folder', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Expanded(flex: 2, child: Text('Folder Directory', style: TextStyle(fontSize: 12))),
                        Expanded(flex: 2, child: Text('$count test files', style: const TextStyle(fontSize: 12))),
                        const Expanded(flex: 1, child: Text('Catalog', style: TextStyle(fontSize: 11))),
                        SizedBox(
                          width: 140,
                          child: Row(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () => setState(() => _currentFolderId = fId),
                                child: const Text('Open ➔', style: TextStyle(fontSize: 11)),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                onPressed: () => _renameFolderDialog(fId, f['name'] ?? ''),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Exam Files Rows
              ...tests.map((q) {
                final isPrem = q['is_premium'] == true;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            const Icon(Icons.assignment_outlined, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(q['title'] ?? 'Test', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      const Expanded(flex: 2, child: Text('Exam Paper', style: TextStyle(fontSize: 12))),
                      Expanded(flex: 2, child: Text('+${q['marks_per_question'] ?? 2}/-${q['negative_marks'] ?? 0.5}', style: const TextStyle(fontSize: 12))),
                      Expanded(
                        flex: 1,
                        child: Text(isPrem ? 'VIP' : 'Free', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isPrem ? const Color(0xFFFBBF24) : AppTheme.emerald)),
                      ),
                      SizedBox(
                        width: 140,
                        child: Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.rocket_launch_rounded, size: 12),
                              label: const Text('Launch', style: TextStyle(fontSize: 11)),
                              onPressed: () => _openLaunchQuizDialog(q['id'].toString(), q['title'] ?? 'Quiz'),
                            ),
                          ],
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
);
  }

  // ==========================================
  // TAB 2: ALL TESTS & QUIZZES
  // ==========================================

  Widget _buildQuizzesTab() {
    final isDark = widget.isDark;

    final filtered = _quizzes.where((q) {
      if (_quizSearch.isNotEmpty) {
        final title = (q['title'] ?? '').toString().toLowerCase();
        if (!title.contains(_quizSearch.toLowerCase())) return false;
      }
      if (_quizFolderFilter != null) {
        if (q['folder_id']?.toString() != _quizFolderFilter) return false;
      }
      if (_quizTierFilter == 'premium' && q['is_premium'] != true) return false;
      if (_quizTierFilter == 'free' && q['is_premium'] == true) return false;
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return ListView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          children: [
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _quizSearch = val),
                    decoration: const InputDecoration(
                      hintText: 'Search tests by name or topic...',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          decoration: const InputDecoration(labelText: 'Folder'),
                          initialValue: _quizFolderFilter,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('All Folders')),
                            ..._folders.map((f) => DropdownMenuItem<String?>(value: f['id'].toString(), child: Text(f['name'] ?? '', overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) => setState(() => _quizFolderFilter = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Access Tier'),
                          initialValue: _quizTierFilter,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Access')),
                            DropdownMenuItem(value: 'premium', child: Text('👑 VIP Only')),
                            DropdownMenuItem(value: 'free', child: Text('Free Tier')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _quizTierFilter = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _importQuizDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Import Test Paper'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      onChanged: (val) => setState(() => _quizSearch = val),
                      decoration: const InputDecoration(
                        hintText: 'Search tests by name or topic...',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(labelText: 'Filter by Folder'),
                      initialValue: _quizFolderFilter,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Folders')),
                        ..._folders.map((f) => DropdownMenuItem<String?>(value: f['id'].toString(), child: Text(f['name'] ?? ''))),
                      ],
                      onChanged: (val) => setState(() => _quizFolderFilter = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Access Tier'),
                      initialValue: _quizTierFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Access')),
                        DropdownMenuItem(value: 'premium', child: Text('👑 VIP Only')),
                        DropdownMenuItem(value: 'free', child: Text('Free Tier Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _quizTierFilter = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                    onPressed: _importQuizDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Import Test'),
                  ),
                ],
              ),
            const SizedBox(height: 18),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = max(constraints.maxWidth, 800.0);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('TEST MODULE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            Expanded(flex: 2, child: Text('FOLDER LOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            Expanded(flex: 2, child: Text('MARKING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            Expanded(flex: 1, child: Text('TIMER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            Expanded(flex: 1, child: Text('ACCESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            SizedBox(width: 220, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),

                      if (filtered.isEmpty)
                        const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No tests found matching search criteria.')))
                      else
                        ...filtered.map((q) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      q['title'] ?? 'Untitled',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      q['folder_name'] ?? 'General',
                                      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('+${q['marks_per_question'] ?? 2} / -${q['negative_marks'] ?? 0.5}', style: const TextStyle(fontSize: 12)),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text('${q['time_limit_seconds'] ?? 30}s', style: GoogleFonts.inter(fontSize: 12)),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: q['is_premium'] == true ? const Color(0xFFFBBF24).withValues(alpha: 0.15) : AppTheme.emeraldSubtle,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          q['is_premium'] == true ? 'VIP' : 'Free',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: q['is_premium'] == true ? const Color(0xFFFBBF24) : AppTheme.emerald),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 220,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.rocket_launch_rounded, size: 12),
                                          label: const Text('Launch', style: TextStyle(fontSize: 11)),
                                          onPressed: () => _openLaunchQuizDialog(q['id'].toString(), q['title'] ?? 'Quiz'),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          icon: const Icon(Icons.visibility_outlined, size: 17),
                                          tooltip: 'Preview Questions',
                                          onPressed: () => _previewQuestionsDialog(q),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          icon: const Icon(Icons.edit_outlined, size: 17),
                                          tooltip: 'Edit Parameters',
                                          onPressed: () => _editQuizDialog(q),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          icon: const Icon(Icons.delete_outline, color: AppTheme.rose, size: 17),
                                          tooltip: 'Delete',
                                          onPressed: () => _deleteQuizPrompt(q),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
          ],
        );
      },
    );
  }

  void _previewQuestionsDialog(Map<String, dynamic> q) async {
    final isDark = widget.isDark;
    final quizId = q['id'].toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return FutureBuilder<List<dynamic>>(
            future: _api.getQuizQuestions(quizId),
            builder: (context, snapshot) {
              final questions = snapshot.data ?? [];
              final isQuestionsLoading = snapshot.connectionState == ConnectionState.waiting;

              final isDialogMobile = MediaQuery.of(ctx).size.width < 500;

              return AlertDialog(
                backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                title: isDialogMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySubtle,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.quiz_outlined, color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(q['title'] ?? 'Questions List', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text(
                                      'Questions Inspector (${questions.length} questions)',
                                      style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emerald,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Add Question', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              onPressed: () {
                                _addQuestionDialog(quizId, () => setDlgState(() {}));
                              },
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySubtle,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.quiz_outlined, color: AppTheme.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(q['title'] ?? 'Questions List', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(
                                  'Questions Inspector (${questions.length} questions)',
                                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emerald,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Add Question', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            onPressed: () {
                              _addQuestionDialog(quizId, () => setDlgState(() {}));
                            },
                          ),
                        ],
                      ),
                content: SizedBox(
                  width: min(650.0, MediaQuery.of(ctx).size.width * 0.92),
                  height: min(520.0, MediaQuery.of(ctx).size.height * 0.75),
                  child: isQuestionsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : questions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.help_outline_rounded, size: 48, color: AppTheme.cyan),
                                  const SizedBox(height: 12),
                                  const Text('No questions found in this examination paper.'),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add First Question'),
                                    onPressed: () {
                                      _addQuestionDialog(quizId, () => setDlgState(() {}));
                                    },
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: questions.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) {
                                final qItem = questions[idx];
                                final opts = qItem['options'] is List ? (qItem['options'] as List) : [];
                                final correct = (qItem['correct_option_index'] is int)
                                    ? qItem['correct_option_index'] as int
                                    : (int.tryParse('${qItem['correct_option_index'] ?? qItem['correct_option']}') ?? 0);
                                final exp = qItem['explanation']?.toString();

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 11,
                                            backgroundColor: AppTheme.primarySubtle,
                                            child: Text('${idx + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              qItem['question_text'] ?? '',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.edit_outlined, size: 16),
                                            tooltip: 'Edit Question',
                                            onPressed: () {
                                              _editQuestionDialog(qItem, () => setDlgState(() {}));
                                            },
                                          ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.rose),
                                            tooltip: 'Delete Question',
                                            onPressed: () async {
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (c) => AlertDialog(
                                                  title: const Text('Delete Question?'),
                                                  content: const Text('Permanently remove this question from paper?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
                                                      onPressed: () => Navigator.pop(c, true),
                                                      child: const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (ok == true) {
                                                await _api.deleteQuestion(qItem['id'].toString());
                                                _showToast('Question removed.');
                                                setDlgState(() {});
                                                _loadAllData();
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: List.generate(opts.length, (optIdx) {
                                          final isCorrect = optIdx == correct;
                                          final optLetter = String.fromCharCode(65 + optIdx);
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isCorrect ? AppTheme.emeraldSubtle : (isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9)),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isCorrect ? AppTheme.emerald.withValues(alpha: 0.4) : (isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
                                              ),
                                            ),
                                            child: Text(
                                              '$optLetter: ${opts[optIdx]}${isCorrect ? ' ✓' : ''}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500,
                                                color: isCorrect ? AppTheme.emerald : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      if (exp != null && exp.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text('💡 $exp', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub)),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _deleteQuizPrompt(Map<String, dynamic> q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Test?'),
        content: Text('Are you sure you want to permanently delete "${q['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final res = await _api.deleteQuiz(q['id'].toString());
      if (res['success'] == true) {
        _showToast('Test deleted.');
        _loadAllData();
      }
    }
  }

  Widget _tierFilterChip(String label, String tier) {
    final isSelected = _userTierFilter == tier;
    final isDark = widget.isDark;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() => _userTierFilter = tier);
        _api.getUsers(query: _userSearch, tier: _userTierFilter).then((users) {
          if (mounted) setState(() => _users = users);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.primarySubtle : AppTheme.primary.withValues(alpha: 0.12))
              : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: STUDENTS DIRECTORY (AVATARS EVERYWHERE)
  // ==========================================

  Widget _buildStudentsTab() {
    final isDark = widget.isDark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return ListView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          children: [
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    onChanged: (val) {
                      _userSearch = val;
                      _api.getUsers(query: _userSearch, tier: _userTierFilter).then((users) {
                        if (mounted) setState(() => _users = users);
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search by ID, Name, or @username...',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Tier Filter'),
                          initialValue: _userTierFilter,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Students')),
                            DropdownMenuItem(value: 'premium', child: Text('👑 Scholar Pass')),
                            DropdownMenuItem(value: 'free', child: Text('🟢 Open Tier')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _userTierFilter = val);
                              _api.getUsers(query: _userSearch, tier: _userTierFilter).then((users) {
                                if (mounted) setState(() => _users = users);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _quickPassPrompt,
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Text('⚡ Pass by ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      onChanged: (val) {
                        _userSearch = val;
                        _api.getUsers(query: _userSearch, tier: _userTierFilter).then((users) {
                          if (mounted) setState(() => _users = users);
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search by Telegram User ID, Name, or @username...',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Tier Filter'),
                      initialValue: _userTierFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Students')),
                        DropdownMenuItem(value: 'premium', child: Text('👑 Scholar Pass Only')),
                        DropdownMenuItem(value: 'free', child: Text('🟢 Open Tier Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _userTierFilter = val);
                          _api.getUsers(query: _userSearch, tier: _userTierFilter).then((users) {
                            if (mounted) setState(() => _users = users);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _quickPassPrompt,
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('⚡ Quick Pass by ID', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tierFilterChip('👥 All Candidates', 'all'),
                  const SizedBox(width: 8),
                  _tierFilterChip('👑 Scholar Pass Only', 'premium'),
                  const SizedBox(width: 8),
                  _tierFilterChip('🟢 Open Tier Only', 'free'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = max(constraints.maxWidth, 750.0);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('STUDENT & AVATAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            Expanded(flex: 2, child: Text('TELEGRAM ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            Expanded(flex: 2, child: Text('TOTAL SCORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            Expanded(flex: 1, child: Text('STREAK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            Expanded(flex: 2, child: Text('PREMIUM ACCESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),

                      if (_users.isEmpty)
                        const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No students found.')))
                      else
                        ..._users.map((u) {
                          final isPrem = u['is_premium'] == true;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      UserAvatar(
                                        userId: u['id'].toString(),
                                        name: u['first_name'] ?? u['username'] ?? 'Student',
                                        radius: 18,
                                        isPremium: isPrem,
                                        showOnlineDot: true,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              u['first_name'] ?? 'Student',
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (u['username'] != null && u['username'].toString().isNotEmpty)
                                              Text(
                                                '@${u['username']}',
                                                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('${u['id']}', style: GoogleFonts.inter(fontSize: 12)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('${u['total_score'] ?? 0} pts',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.emerald)),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text('${u['streak_days'] ?? 0}d',
                                      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Switch(
                                        value: isPrem,
                                        activeThumbColor: const Color(0xFFFBBF24),
                                        onChanged: (newVal) async {
                                          final res = await _api.toggleUserPremium(u['id'], newVal);
                                          if (res['success'] == true) {
                                            _showToast(newVal ? '👑 Premium pass granted to ${u['first_name']}!' : 'Premium revoked.');
                                            _loadAllData();
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      Text(isPrem ? 'VIP Active' : 'Free',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isPrem ? const Color(0xFFFBBF24) : (isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub))),
                                    ],
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
        ),
          ],
        );
      },
    );
  }

  // ==========================================
  // TAB 4: GROUP BATTLES
  // ==========================================

  Widget _buildBattlesTab() {
    final isDark = widget.isDark;
    final isMobile = MediaQuery.of(context).size.width < 750;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Community Groups & Battle Arena', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Trigger and monitor real-time exam simulations in authorized Telegram groups',
                      style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12)),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      onPressed: () async {
                        final groupCtrl = TextEditingController();
                        final titleCtrl = TextEditingController();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Authorize New Telegram Group'),
                            content: SizedBox(
                              width: min(440.0, MediaQuery.of(ctx).size.width * 0.92),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(controller: groupCtrl, decoration: const InputDecoration(labelText: 'Telegram Group ID (e.g. -100123456789)')),
                                  const SizedBox(height: 10),
                                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Group Title Name')),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () async {
                                  if (groupCtrl.text.trim().isEmpty) return;
                                  Navigator.pop(ctx);
                                  final res = await _api.authorizeGroup(groupCtrl.text.trim(), titleCtrl.text.trim());
                                  if (res['success'] == true) {
                                    _showToast('Group authorized!');
                                    _loadAllData();
                                  }
                                },
                                child: const Text('Authorize Group'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Authorize Group'),
                    ),
                  ),
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Community Groups & Battle Arena', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('Trigger and monitor real-time exam simulations in authorized Telegram groups',
                          style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: () async {
                    final groupCtrl = TextEditingController();
                    final titleCtrl = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Authorize New Telegram Group'),
                        content: SizedBox(
                          width: min(440.0, MediaQuery.of(ctx).size.width * 0.92),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: groupCtrl, decoration: const InputDecoration(labelText: 'Telegram Group ID (e.g. -100123456789)')),
                              const SizedBox(height: 10),
                              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Group Title Name')),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () async {
                              if (groupCtrl.text.trim().isEmpty) return;
                              Navigator.pop(ctx);
                              final res = await _api.authorizeGroup(groupCtrl.text.trim(), titleCtrl.text.trim());
                              if (res['success'] == true) {
                                _showToast('Group authorized!');
                                _loadAllData();
                              }
                            },
                            child: const Text('Authorize Group'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Authorize Group'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        if (_groups.isEmpty)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No groups authorized yet.')))
        else
          ..._groups.map((g) {
            final isBattleActive = g['isBattleActive'] == true;
            final sched = g['activeSchedule'];
            final isActive = g['is_active'] != false;

            Widget groupDetailsWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(g['group_title'] ?? 'Community Group', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.emeraldSubtle : AppTheme.roseSubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isActive ? '🟢 ACTIVE' : '🔴 REVOKED',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppTheme.emerald : AppTheme.rose,
                        ),
                      ),
                    ),
                    if (isBattleActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(color: AppTheme.roseSubtle, borderRadius: BorderRadius.circular(4)),
                        child: const Text('LIVE BATTLE ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.rose)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text('Group ID: ${g['group_id']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub)),
                const SizedBox(height: 2),
                if (sched != null) ...[
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '⏰ Scheduled: ${sched['quizTitle']} at ${sched['timeFormatted']} IST',
                          style: const TextStyle(fontSize: 11, color: AppTheme.amber, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _cancelGroupSchedulePrompt(g['group_id']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.roseSubtle,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.rose.withValues(alpha: 0.3)),
                          ),
                          child: const Text('🛑 Cancel', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.rose)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text('⚪ No Schedule', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub)),
                ],
              ],
            );

            Widget actionButtonsWidget = Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isActive) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openLaunchQuizDialog(
                      _quizzes.isNotEmpty ? _quizzes.first['id'].toString() : '',
                      g['group_title'] ?? 'Community Group',
                    ),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 13),
                    label: const Text('Launch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openScheduleBattleDialog(g['group_id'], g['group_title'] ?? 'Community Group'),
                    icon: const Icon(Icons.schedule_rounded, size: 13),
                    label: const Text('Schedule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.rose,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final res = await _api.toggleGroupStatus(g['group_id'], false, groupTitle: g['group_title'] ?? '');
                      if (res['success'] == true) {
                        _showToast('Group authorization revoked.');
                        _loadAllData();
                      }
                    },
                    child: const Text('Revoke', style: TextStyle(fontSize: 11)),
                  ),
                ] else ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final res = await _api.toggleGroupStatus(g['group_id'], true, groupTitle: g['group_title'] ?? '');
                      if (res['success'] == true) {
                        _showToast('Group authorization approved! 🏛️');
                        _loadAllData();
                      }
                    },
                    child: const Text('Activate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.delete_outline, size: 17, color: AppTheme.rose),
                  tooltip: 'Delete Group Record',
                  onPressed: () => _deleteGroupPrompt(g['group_id']),
                ),
              ],
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
              ),
              child: LayoutBuilder(
                builder: (context, cardConstraints) {
                  final isCardNarrow = cardConstraints.maxWidth < 650;
                  if (isCardNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.purple.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.groups_rounded, color: AppTheme.purple, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: groupDetailsWidget),
                          ],
                        ),
                        const SizedBox(height: 12),
                        actionButtonsWidget,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.groups_rounded, color: AppTheme.purple, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: groupDetailsWidget),
                      const SizedBox(width: 12),
                      actionButtonsWidget,
                    ],
                  );
                },
              ),
            );
          }),
      ],
    );
  }

  // ==========================================
  // TAB 5: BROADCAST TOOL
  // ==========================================

  Widget _buildBroadcastTab() {
    final isDark = widget.isDark;
    final isMobile = MediaQuery.of(context).size.width < 750;
    final msgCtrl = TextEditingController();
    String target = 'all';

    return ListView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      children: [
        Text('Global Broadcast Center', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
        Text('Dispatch platform-wide mock test alerts to registered students and community channels',
            style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12)),
        const SizedBox(height: 20),

        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Target Audience'),
                  initialValue: target,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Global Blast: Everyone (Students + Groups)')),
                    DropdownMenuItem(value: 'users', child: Text('Students Only (Direct Messages)')),
                    DropdownMenuItem(value: 'groups', child: Text('Authorized Community Groups Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) target = val;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: msgCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Broadcast Message (Supports Markdown formatting)',
                    hintText: '🌟 *NEW UPSC PRELIMS MOCK TEST RELEASED!*\n\nTest your preparation now in @Examplayer_bot...',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (msgCtrl.text.trim().isEmpty) return;
                    _showToast('Dispatching broadcast...');
                    final res = await _api.broadcastMessage(msgCtrl.text.trim(), target: target);
                    if (res['success'] == true) {
                      _showToast('📢 Broadcast completed!');
                      msgCtrl.clear();
                    } else {
                      _showToast(res['error'] ?? 'Broadcast error', isError: true);
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Broadcast Announcement'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 4: LEADERBOARD & MERIT STANDINGS
  // ==========================================

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color) {
    final isDark = widget.isDark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    final isDark = widget.isDark;

    // Top 3 metrics
    final rankedCount = _globalLeaderboard.length;
    final topper = _globalLeaderboard.isNotEmpty ? _globalLeaderboard[0] : null;
    final topperName = topper != null
        ? (topper['first_name']?.toString().isNotEmpty == true
            ? topper['first_name']
            : (topper['name']?.toString().isNotEmpty == true
                ? topper['name']
                : (topper['username'] != null && topper['username'].toString().isNotEmpty
                    ? '@${topper['username']}'
                    : 'Candidate #${topper['id'] ?? topper['user_id']}')))
        : '—';
    final topScore = topper != null ? (topper['total_score'] ?? topper['score'] ?? 0) : 0;
    final isMobile = MediaQuery.of(context).size.width < 750;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      children: [
        // 3 Metric Cards matching HTML console
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 750 ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _kpiCard('Ranked Candidates', '$rankedCount', '👥 Students on scoreboard', Icons.emoji_events_rounded, AppTheme.amber),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _kpiCard('All-India #1 Topper', '$topperName', '🥇 Highest cumulative score', Icons.military_tech_rounded, AppTheme.amber),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _kpiCard('Peak Merit Score', '$topScore pts', '⚡ Peak merit points record', Icons.bolt_rounded, AppTheme.cyan),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Main Leaderboard Card
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with Subview Toggle & Refresh Button
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 750;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Competitive Merit Standings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            'Inspect cumulative All-India rankings or analyze candidate performance by specific examination module.',
                            style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                          ),
                          const SizedBox(height: 14),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _lbViewToggleBtn(title: '🌐 All-India Standings', mode: 'global'),
                                const SizedBox(width: 8),
                                _lbViewToggleBtn(title: '📝 Per-Examination Standings', mode: 'quiz'),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, size: 20),
                                  tooltip: 'Refresh Standings',
                                  onPressed: () {
                                    _tg.hapticImpact('light');
                                    _loadLeaderboardData();
                                    if (_selectedLeaderboardQuizId != null) {
                                      _loadQuizLeaderboard(_selectedLeaderboardQuizId!);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Competitive Merit Standings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                'Inspect cumulative All-India rankings or analyze candidate performance by specific examination module.',
                                style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            _lbViewToggleBtn(title: '🌐 All-India Standings', mode: 'global'),
                            const SizedBox(width: 8),
                            _lbViewToggleBtn(title: '📝 Per-Examination Standings', mode: 'quiz'),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              tooltip: 'Refresh Standings',
                              onPressed: () {
                                _tg.hapticImpact('light');
                                _loadLeaderboardData();
                                if (_selectedLeaderboardQuizId != null) {
                                  _loadQuizLeaderboard(_selectedLeaderboardQuizId!);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Subview content
                if (_leaderboardViewMode == 'global') ...[
                  // Global Leaderboard Table
                  if (_isGlobalLeaderboardLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 50),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_globalLeaderboard.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.emoji_events_outlined, size: 40, color: Colors.grey),
                          const SizedBox(height: 10),
                          Text('No ranked candidates on the scoreboard yet.', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                            onPressed: _loadLeaderboardData,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Fetch Live Standings'),
                          ),
                        ],
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final tableWidth = max(constraints.maxWidth, 800.0);
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(width: 70, child: Text('RANK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                  Expanded(flex: 3, child: Text('CANDIDATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                  Expanded(flex: 2, child: Text('TELEGRAM ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                  Expanded(flex: 2, child: Text('TESTS TAKEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                  Expanded(flex: 2, child: Text('CUMULATIVE SCORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                  Expanded(flex: 2, child: Text('STREAK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                  SizedBox(width: 120, child: Text('SCHOLAR PASS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Rows
                            ..._globalLeaderboard.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final u = entry.value;
                              final rank = u['rank'] ?? (idx + 1);
                              final uId = (u['id'] ?? u['user_id'] ?? '').toString();
                              final uName = (u['first_name'] ?? u['name'] ?? (u['username'] != null ? '@${u['username']}' : 'Student #$uId')).toString();
                              final uHandle = u['username'] != null && u['username'].toString().isNotEmpty ? '@${u['username']}' : '';
                              final uTests = u['tests_completed'] ?? u['quizzes_completed'] ?? 0;
                              final uScore = u['total_score'] ?? u['score'] ?? 0;
                              final uStreak = u['streak_days'] ?? 0;
                              final isPrem = u['is_premium'] == 1 || u['is_premium'] == true;

                              String rankDisplay = '#$rank';
                              Color rankColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
                              if (rank == 1) {
                                rankDisplay = '🥇 1st';
                                rankColor = const Color(0xFFF59E0B);
                              } else if (rank == 2) {
                                rankDisplay = '🥈 2nd';
                                rankColor = const Color(0xFF94A3B8);
                              } else if (rank == 3) {
                                rankDisplay = '🥉 3rd';
                                rankColor = const Color(0xFFD97706);
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 70,
                                      child: Text(rankDisplay, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: rankColor)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          UserAvatar(
                                            userId: uId,
                                            name: uName,
                                            radius: 15,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(uName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                                if (uHandle.isNotEmpty)
                                                  Text(uHandle, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        uId.isNotEmpty ? uId : '—',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('$uTests tests', style: const TextStyle(fontSize: 12.5)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '$uScore pts',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFF97316)),
                                          const SizedBox(width: 4),
                                          Text('$uStreak days', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isPrem ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : AppTheme.emerald.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isPrem ? '👑 VIP PASS' : '🟢 OPEN TIER',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isPrem ? const Color(0xFFF59E0B) : AppTheme.emerald,
                                          ),
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
                ] else ...[
                  // Per-Examination Standings View
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedLeaderboardQuizId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Select Examination Module',
                                  prefixIcon: const Icon(Icons.quiz_outlined, size: 18),
                                  filled: true,
                                  fillColor: isDark ? AppTheme.darkCard : Colors.white,
                                ),
                                hint: const Text('Choose an examination paper to view module leaderboard...'),
                                items: _quizzes.map<DropdownMenuItem<String>>((q) {
                                  final qId = q['id'].toString();
                                  final title = q['title'] ?? 'Test Paper';
                                  final cat = q['category'] ?? 'General';
                                  return DropdownMenuItem<String>(
                                    value: qId,
                                    child: Text('$title ($cat)', maxLines: 1, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    _loadQuizLeaderboard(val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_quizLeaderboardData['quiz'] != null) ...[
                          const SizedBox(height: 12),
                          Builder(builder: (context) {
                            final attemptsList = ((_quizLeaderboardData['attempts'] ?? _quizLeaderboardData['leaderboard']) as List?) ?? [];
                            final qData = _quizLeaderboardData['quiz'] as Map<String, dynamic>;
                            return Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _metaBadge(Icons.help_outline_rounded, '${qData['total_questions'] ?? 0} Questions'),
                                _metaBadge(Icons.add_circle_outline, '+${qData['marks_per_question'] ?? 2.0} Marks / Correct'),
                                _metaBadge(Icons.remove_circle_outline, '-${qData['negative_marking'] ?? 0.5} Negative Penalty'),
                                _metaBadge(Icons.people_outline, '${attemptsList.length} Attempts Evaluated'),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isQuizLeaderboardLoading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_selectedLeaderboardQuizId == null)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Text('Select an examination paper above to display candidate standings.',
                          style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                    )
                  else ...[
                    Builder(builder: (context) {
                      final list = ((_quizLeaderboardData['attempts'] ?? _quizLeaderboardData['leaderboard']) as List?) ?? [];
                      if (list.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          alignment: Alignment.center,
                          child: Text('No student attempts recorded for this examination yet.',
                              style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                        );
                      }
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final tableWidth = max(constraints.maxWidth, 800.0);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(width: 70, child: Text('RANK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                    Expanded(flex: 3, child: Text('CANDIDATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                    Expanded(flex: 2, child: Text('SCORE (PTS)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                    Expanded(flex: 1, child: Text('✅ CORRECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                    Expanded(flex: 1, child: Text('❌ WRONG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                    Expanded(flex: 2, child: Text('🎯 ACCURACY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                    Expanded(flex: 2, child: Text('⏱️ TIME TAKEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...list.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                final rank = item['rank'] ?? (idx + 1);
                                final itemId = (item['user_id'] ?? item['id'] ?? '').toString();
                                final itemName = (item['first_name'] ?? item['name'] ?? (item['username'] != null ? '@${item['username']}' : 'Candidate #$itemId')).toString();
                                final itemHandle = item['username'] != null && item['username'].toString().isNotEmpty ? '@${item['username']}' : '';
                                final accuracy = (item['accuracy_percent'] ?? item['accuracy'] ?? 0).toDouble();
                                final timeSec = item['time_taken_seconds'] ?? 0;
                                final timeStr = '${timeSec ~/ 60}m ${timeSec % 60}s';

                                String rankDisplay = '#$rank';
                                Color rankColor = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
                                if (rank == 1) {
                                  rankDisplay = '🥇 1st';
                                  rankColor = const Color(0xFFF59E0B);
                                } else if (rank == 2) {
                                  rankDisplay = '🥈 2nd';
                                  rankColor = const Color(0xFF94A3B8);
                                } else if (rank == 3) {
                                  rankDisplay = '🥉 3rd';
                                  rankColor = const Color(0xFFD97706);
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 70,
                                        child: Text(rankDisplay, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: rankColor)),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            UserAvatar(
                                              userId: itemId,
                                              name: itemName,
                                              radius: 15,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                                  if (itemHandle.isNotEmpty)
                                                    Text(itemHandle, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text('${item['score'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary)),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text('${item['correct_count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.emerald)),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text('${item['wrong_count'] ?? item['incorrect_count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.rose)),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: (accuracy / 100).clamp(0.0, 1.0),
                                                  backgroundColor: isDark ? AppTheme.darkSurface : const Color(0xFFE2E8F0),
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    accuracy >= 75 ? AppTheme.emerald : (accuracy >= 40 ? AppTheme.amber : AppTheme.rose),
                                                  ),
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text('${accuracy.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(timeStr, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
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
                  );
                }),
              ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _lbViewToggleBtn({required String title, required String mode}) {
    final isSelected = _leaderboardViewMode == mode;
    final isDark = widget.isDark;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        _tg.hapticImpact('light');
        setState(() => _leaderboardViewMode = mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
          ),
        ),
      ),
    );
  }

  Widget _metaBadge(IconData icon, String text) {
    final isDark = widget.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 5: ADMINS MANAGEMENT HUB
  // ==========================================

  Widget _buildAdminsTab() {
    final isDark = widget.isDark;
    final isMobile = MediaQuery.of(context).size.width < 750;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Platform Administrators Hub', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            'Authorized administrators with root privileges to create tests, manage candidate passes, and control group battles.',
                            style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onPressed: _appointAdminDialog,
                              icon: const Icon(Icons.shield_rounded, size: 16),
                              label: const Text('Appoint New Admin', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Platform Administrators Hub', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                'Authorized administrators with root privileges to create tests, manage candidate passes, and control group battles.',
                                style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: _appointAdminDialog,
                          icon: const Icon(Icons.shield_rounded, size: 16),
                          label: const Text('Appoint New Admin', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                if (_admins.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    alignment: Alignment.center,
                    child: Text('No platform administrators configured.', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = max(constraints.maxWidth, 700.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 3, child: Text('ADMINISTRATOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                Expanded(flex: 2, child: Text('TELEGRAM ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                Expanded(flex: 2, child: Text('ROLE / STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                                SizedBox(width: 140, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),

                          ..._admins.map((adm) {
                            final isRoot = adm['isRoot'] == true;
                            final admId = adm['id'].toString();

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        UserAvatar(
                                          userId: admId,
                                          name: adm['name'] ?? 'Admin',
                                          radius: 18,
                                          isRootAdmin: isRoot,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(adm['name'] ?? 'Administrator', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                              if (adm['username'] != null && adm['username'].toString().isNotEmpty)
                                                Text('@${adm['username']}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      admId,
                                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: isRoot ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : AppTheme.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isRoot ? '👑 PRIMARY OWNER' : '🛡️ APPOINTED ADMIN',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: isRoot ? const Color(0xFFF59E0B) : AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: isRoot
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9)),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Permanent (Root)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                                          )
                                        : OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.rose,
                                              side: const BorderSide(color: AppTheme.rose),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                  title: const Text('Revoke Administrator?'),
                                                  content: Text('Are you sure you want to revoke admin privileges from ${adm['name'] ?? admId}?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
                                                      onPressed: () => Navigator.pop(ctx, true),
                                                      child: const Text('Revoke Privileges'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                final res = await _api.removeAdmin(admId);
                                                if (res['success'] == true) {
                                                  _showToast('Admin privileges revoked.');
                                                  _loadAllData();
                                                } else {
                                                  _showToast(res['error'] ?? 'Action failed', isError: true);
                                                }
                                              }
                                            },
                                            icon: const Icon(Icons.delete_outline, size: 14),
                                            label: const Text('Revoke', style: TextStyle(fontSize: 11)),
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
        ),
      ],
    );
  }

  // ==========================================
  // TAB 8: GLOBAL PLATFORM SETTINGS
  // ==========================================

  Widget _buildSettingsTab() {
    final isDark = widget.isDark;
    final isMobile = MediaQuery.of(context).size.width < 750;
    final upiCtrl = TextEditingController(text: _settings['upi_id'] ?? '');
    final priceCtrl = TextEditingController(text: '${_settings['subscription_price'] ?? 199}');
    final channelCtrl = TextEditingController(text: _settings['mandatory_channel'] ?? '');

    return ListView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : AppTheme.lightBorder),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Global Platform Settings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Manage payment coordinates, tariff charges, and compulsory subscription channels.',
                  style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: upiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Settlement UPI VPA Address',
                    hintText: 'e.g. examplayer@okhdfcbank',
                    helperText: 'Displayed on student invoice prompts when upgrading to Scholar Pass.',
                    prefixIcon: Icon(Icons.qr_code_2_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Scholar Pass Registration Fee (₹ INR)',
                    hintText: '99',
                    helperText: 'One-time or monthly subscription tariff fee charged in Indian Rupees.',
                    prefixIcon: Icon(Icons.currency_rupee_rounded, size: 19),
                  ),
                ),
                const SizedBox(height: 20),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Mandatory Telegram Announcement Channel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => channelCtrl.clear(),
                          child: const Text('Clear Channel', style: TextStyle(fontSize: 11, color: AppTheme.rose)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: channelCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. @ExamplayerAnnouncements (Leave blank to disable)',
                        helperText: 'If configured, students must join this channel before tests unlock.',
                        prefixIcon: Icon(Icons.campaign_outlined, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final res = await _api.updateSettings(
                      upiId: upiCtrl.text.trim(),
                      price: priceCtrl.text.trim(),
                      channel: channelCtrl.text.trim(),
                    );
                    if (res['success'] == true) {
                      _showToast('Platform settings saved successfully! 💾');
                      _loadAllData();
                    } else {
                      _showToast(res['error'] ?? 'Save failed', isError: true);
                    }
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('💾 Save Platform Configuration', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ],
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
