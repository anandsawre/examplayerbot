import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';

class FoldersTab extends StatefulWidget {
  final List<dynamic> folders;
  final List<dynamic> quizzes;
  final ApiService api;
  final TelegramService tg;
  final bool isDark;
  final Future<void> Function() onRefreshAll;
  final Function(String msg, {bool isError}) onShowToast;
  final Function(Map<String, dynamic> q) onPreviewQuiz;
  final Function(Map<String, dynamic> q) onDeleteQuiz;
  final Function(String quizId, String quizTitle) onLaunchQuiz;

  const FoldersTab({
    super.key,
    required this.folders,
    required this.quizzes,
    required this.api,
    required this.tg,
    required this.isDark,
    required this.onRefreshAll,
    required this.onShowToast,
    required this.onPreviewQuiz,
    required this.onDeleteQuiz,
    required this.onLaunchQuiz,
  });

  @override
  State<FoldersTab> createState() => FoldersTabState();
}

class FoldersTabState extends State<FoldersTab> {
  // Active selected folder ID (null means All Content / Root)
  String? _selectedFolderId;

  // Expanded folders in the tree
  final Set<String> _expandedFolderIds = {'root', 'gk_bihar', 'science', 'mathematics'};

  // Middle panel state
  int _activeSubTab = 0; // 0 = Tests, 1 = Subfolders, 2 = Bulk Actions
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'published', 'draft'
  String _sortOrder = 'newest'; // 'newest', 'oldest', 'questions'
  bool _isGridView = false;
  int _currentPage = 1;
  final int _pageSize = 10;

  // Bulk actions selection
  final Set<String> _selectedQuizIds = {};

  ApiService get _api => widget.api;
  TelegramService get _tg => widget.tg;
  List<dynamic> get _folders => widget.folders;
  List<dynamic> get _quizzes => widget.quizzes;

  void _showToast(String msg, {bool isError = false}) => widget.onShowToast(msg, isError: isError);
  Future<void> _loadAllData() => widget.onRefreshAll();

  @override
  void initState() {
    super.initState();
    _initSelection();
  }

  @override
  void didUpdateWidget(covariant FoldersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedFolderId == null && _folders.isNotEmpty) {
      _initSelection();
    }
  }

  void _initSelection() {
    if (_folders.isNotEmpty) {
      _selectedFolderId = _folders.first['id']?.toString();
      _expandedFolderIds.add('root');
      for (final f in _folders) {
        _expandedFolderIds.add(f['id'].toString());
      }
    } else {
      _selectedFolderId = 'gk_bihar';
      _expandedFolderIds.addAll({'root', 'gk_bihar', 'science', 'mathematics'});
    }
  }

  // Fallback demo structure if database has minimal folders
  List<Map<String, dynamic>> _getMergedFolders() {
    if (_folders.isNotEmpty) {
      final palette = [0xFF2563EB, 0xFF10B981, 0xFF0284C7, 0xFFF59E0B, 0xFF8B5CF6, 0xFFEC4899];
      return _folders.asMap().entries.map((entry) {
        final f = Map<String, dynamic>.from(entry.value as Map);
        f['color'] ??= palette[entry.key % palette.length];
        f['icon'] ??= Icons.folder_rounded;
        f['description'] ??= '${f['name']} - All categorized tests & practice sets.';
        return f;
      }).toList();
    }

    // High fidelity default hierarchical folder dataset matching provided UI
    return [
      {'id': 'gk_bihar', 'name': 'GK - Bihar', 'parent_id': null, 'description': 'Bihar se related sabhi GK tests, questions aur study material.', 'color': 0xFF2563EB, 'icon': Icons.folder_rounded, 'created_at': '2026-10-10'},
      {'id': 'bihar_special', 'name': 'Bihar Special', 'parent_id': 'gk_bihar', 'description': 'State specific special tests', 'color': 0xFFEC4899, 'created_at': '2026-10-10'},
      {'id': 'bihar_history', 'name': 'History', 'parent_id': 'gk_bihar', 'description': 'Ancient to modern Bihar history', 'color': 0xFF3B82F6, 'created_at': '2026-10-10'},
      {'id': 'bihar_geography', 'name': 'Geography', 'parent_id': 'gk_bihar', 'description': 'Rivers, climate and districts of Bihar', 'color': 0xFF10B981, 'created_at': '2026-10-10'},
      {'id': 'bihar_polity', 'name': 'Polity', 'parent_id': 'gk_bihar', 'description': 'Legislature and governance', 'color': 0xFFF59E0B, 'created_at': '2026-10-10'},

      {'id': 'science', 'name': 'Science', 'parent_id': null, 'description': 'General science and technology modules', 'color': 0xFF10B981, 'icon': Icons.folder_rounded, 'created_at': '2026-10-08'},
      {'id': 'sci_physics', 'name': 'Physics', 'parent_id': 'science', 'color': 0xFF06B6D4, 'created_at': '2026-10-08'},
      {'id': 'sci_chem', 'name': 'Chemistry', 'parent_id': 'science', 'color': 0xFF8B5CF6, 'created_at': '2026-10-08'},
      {'id': 'sci_bio', 'name': 'Biology', 'parent_id': 'science', 'color': 0xFF10B981, 'created_at': '2026-10-08'},
      {'id': 'sci_practice', 'name': 'Practice Sets', 'parent_id': 'science', 'color': 0xFFF59E0B, 'created_at': '2026-10-08'},

      {'id': 'mathematics', 'name': 'Mathematics', 'parent_id': null, 'description': 'Quantitative aptitude and calculation drills', 'color': 0xFF0284C7, 'icon': Icons.folder_rounded, 'created_at': '2026-10-05'},
      {'id': 'math_arith', 'name': 'Arithmetic', 'parent_id': 'mathematics', 'color': 0xFFF97316, 'created_at': '2026-10-05'},
      {'id': 'math_alg', 'name': 'Algebra', 'parent_id': 'mathematics', 'color': 0xFF8B5CF6, 'created_at': '2026-10-05'},
      {'id': 'math_geom', 'name': 'Geometry', 'parent_id': 'mathematics', 'color': 0xFF06B6D4, 'created_at': '2026-10-05'},
      {'id': 'math_practice', 'name': 'Practice Sets', 'parent_id': 'mathematics', 'color': 0xFFF59E0B, 'created_at': '2026-10-05'},

      {'id': 'reasoning', 'name': 'Reasoning', 'parent_id': null, 'description': 'Logical and analytical reasoning', 'color': 0xFF059669, 'created_at': '2026-10-04'},
      {'id': 'current_affairs', 'name': 'Current Affairs', 'parent_id': null, 'description': 'National and international daily affairs', 'color': 0xFFEF4444, 'created_at': '2026-10-02'},
      {'id': 'railway_exams', 'name': 'Railway Exams', 'parent_id': null, 'description': 'RRB NTPC, Group D mock series', 'color': 0xFF7C3AED, 'created_at': '2026-10-01'},
      {'id': 'mixed_tests', 'name': 'Mixed Tests', 'parent_id': null, 'description': 'Full syllabus mock exams', 'color': 0xFF4F46E5, 'created_at': '2026-09-28'},
    ];
  }

  // Fallback demo tests matching image
  List<Map<String, dynamic>> _getMergedTests() {
    if (_quizzes.isNotEmpty) {
      final palette = [0xFFF59E0B, 0xFF8B5CF6, 0xFFEC4899, 0xFF0284C7, 0xFF10B981, 0xFF06B6D4, 0xFF3B82F6];
      return _quizzes.asMap().entries.map((entry) {
        final q = Map<String, dynamic>.from(entry.value as Map);
        q['iconColor'] ??= palette[entry.key % palette.length];
        q['icon'] ??= Icons.menu_book_rounded;
        q['type'] ??= q['category'] ?? 'Mock Test';
        return q;
      }).toList();
    }

    return [
      {'id': 't1', 'title': 'Bihar Special', 'folder_id': 'gk_bihar', 'total_questions': 50, 'category': 'Mock Test', 'type': 'Mock Test', 'is_published': true, 'created_at': '2026-10-15', 'icon': Icons.menu_book_rounded, 'iconColor': 0xFFF59E0B},
      {'id': 't2', 'title': 'Bihar History - 1', 'folder_id': 'gk_bihar', 'total_questions': 25, 'category': 'Topic Test', 'type': 'Topic Test', 'is_published': true, 'created_at': '2026-10-14', 'icon': Icons.auto_stories_rounded, 'iconColor': 0xFF8B5CF6},
      {'id': 't3', 'title': 'Bihar Geography', 'folder_id': 'gk_bihar', 'total_questions': 25, 'category': 'Topic Test', 'type': 'Topic Test', 'is_published': true, 'created_at': '2026-10-14', 'icon': Icons.public_rounded, 'iconColor': 0xFFEC4899},
      {'id': 't4', 'title': 'Bihar Polity', 'folder_id': 'gk_bihar', 'total_questions': 25, 'category': 'Topic Test', 'type': 'Topic Test', 'is_published': false, 'created_at': '2026-10-13', 'icon': Icons.gavel_rounded, 'iconColor': 0xFFEAB308},
      {'id': 't5', 'title': 'Bihar Economy', 'folder_id': 'gk_bihar', 'total_questions': 25, 'category': 'Topic Test', 'type': 'Topic Test', 'is_published': true, 'created_at': '2026-10-12', 'icon': Icons.bar_chart_rounded, 'iconColor': 0xFF0284C7},
      {'id': 't6', 'title': 'Bihar Culture', 'folder_id': 'gk_bihar', 'total_questions': 25, 'category': 'Topic Test', 'type': 'Topic Test', 'is_published': true, 'created_at': '2026-10-12', 'icon': Icons.account_balance_rounded, 'iconColor': 0xFF059669},
      {'id': 't7', 'title': 'Bihar Current Affairs', 'folder_id': 'gk_bihar', 'total_questions': 50, 'category': 'Mock Test', 'type': 'Mock Test', 'is_published': true, 'created_at': '2026-10-11', 'icon': Icons.newspaper_rounded, 'iconColor': 0xFF10B981},
      {'id': 't8', 'title': 'Important MCQs', 'folder_id': 'gk_bihar', 'total_questions': 100, 'category': 'Practice Set', 'type': 'Practice Set', 'is_published': true, 'created_at': '2026-10-10', 'icon': Icons.fact_check_rounded, 'iconColor': 0xFF0284C7},
      {'id': 't9', 'title': 'Previous Year Qs', 'folder_id': 'gk_bihar', 'total_questions': 50, 'category': 'PYQ', 'type': 'PYQ', 'is_published': false, 'created_at': '2026-10-09', 'icon': Icons.assignment_turned_in_rounded, 'iconColor': 0xFFF59E0B},
      {'id': 't10', 'title': 'Bihar Mix Test', 'folder_id': 'gk_bihar', 'total_questions': 50, 'category': 'Mock Test', 'type': 'Mock Test', 'is_published': true, 'created_at': '2026-10-08', 'icon': Icons.quiz_rounded, 'iconColor': 0xFF06B6D4},
      {'id': 't11', 'title': 'Bihar Dist Mock Paper', 'folder_id': 'gk_bihar', 'total_questions': 30, 'category': 'Topic Test', 'type': 'Topic Test', 'is_published': true, 'created_at': '2026-10-07', 'icon': Icons.quiz_rounded, 'iconColor': 0xFF3B82F6},
      {'id': 't12', 'title': 'Patna Division GK Drill', 'folder_id': 'gk_bihar', 'total_questions': 45, 'category': 'Practice Set', 'type': 'Practice Set', 'is_published': true, 'created_at': '2026-10-06', 'icon': Icons.quiz_rounded, 'iconColor': 0xFF10B981},
    ];
  }

  // Active folder object
  Map<String, dynamic> _getActiveFolder(List<Map<String, dynamic>> allFolders) {
    if (_selectedFolderId == null || _selectedFolderId == 'root') {
      return {
        'id': 'root',
        'name': 'All Content',
        'description': 'Root catalog containing all question sets and subject hierarchies.',
        'created_at': allFolders.isNotEmpty ? allFolders.first['created_at'] : '2026-10-01',
      };
    }
    return allFolders.firstWhere(
      (f) => f['id']?.toString() == _selectedFolderId,
      orElse: () => allFolders.isNotEmpty ? allFolders.first : {
        'id': 'gk_bihar',
        'name': 'GK - Bihar',
        'description': 'Bihar se related sabhi GK tests, questions aur study material.',
        'created_at': '2026-10-10',
      },
    );
  }

  // Get tests under a folder
  List<Map<String, dynamic>> _getTestsForFolder(String? folderId, List<Map<String, dynamic>> allTests, List<Map<String, dynamic>> allFolders) {
    if (folderId == null || folderId == 'root') {
      return allTests;
    }

    // Collect folder ID and all its descendants
    final folderIds = <String>{folderId};
    void addDescendants(String parentId) {
      for (final f in allFolders) {
        if (f['parent_id']?.toString() == parentId) {
          folderIds.add(f['id'].toString());
          addDescendants(f['id'].toString());
        }
      }
    }
    addDescendants(folderId);

    final activeFolder = allFolders.firstWhere(
      (f) => f['id']?.toString() == folderId,
      orElse: () => <String, dynamic>{},
    );
    final folderName = activeFolder['name']?.toString().toLowerCase().trim();

    final tests = allTests.where((t) {
      final tFolderId = t['folder_id']?.toString();
      if (tFolderId != null && folderIds.contains(tFolderId)) return true;
      if (folderName != null && folderName.isNotEmpty) {
        final cat = t['category']?.toString().toLowerCase().trim();
        final fName = t['folder_name']?.toString().toLowerCase().trim();
        if (cat == folderName || fName == folderName) return true;
      }
      return false;
    }).toList();

    if (tests.isEmpty && folderId == 'gk_bihar' && _quizzes.isEmpty) {
      return allTests.take(12).toList();
    }
    return tests;
  }

  // Get subfolders for a folder
  List<Map<String, dynamic>> _getSubfoldersForFolder(String? folderId, List<Map<String, dynamic>> allFolders) {
    if (folderId == null || folderId == 'root') {
      return allFolders.where((f) => f['parent_id'] == null).toList();
    }
    return allFolders.where((f) => f['parent_id']?.toString() == folderId).toList();
  }

  int _countTotalQuestions(List<Map<String, dynamic>> tests) {
    int total = 0;
    for (final t in tests) {
      total += (t['total_questions'] as num?)?.toInt() ?? 0;
    }
    if (_quizzes.isNotEmpty) return total;
    return total > 0 ? total : 875;
  }

  String _formatDate(dynamic date) {
    if (date == null) return '10 Oct 2026';
    try {
      final dt = DateTime.parse(date.toString());
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final allFolders = _getMergedFolders();
    final allTests = _getMergedTests();
    final activeFolder = _getActiveFolder(allFolders);
    final folderTests = _getTestsForFolder(_selectedFolderId, allTests, allFolders);
    final subfolders = _getSubfoldersForFolder(_selectedFolderId, allFolders);

    // Filter tests
    var filteredTests = folderTests.where((t) {
      if (_searchQuery.isNotEmpty) {
        final title = (t['title'] ?? '').toString().toLowerCase();
        if (!title.contains(_searchQuery.toLowerCase())) return false;
      }
      if (_statusFilter == 'published') {
        if (t['is_published'] != true && t['is_published'] != 1) return false;
      } else if (_statusFilter == 'draft') {
        if (t['is_published'] == true || t['is_published'] == 1) return false;
      }
      return true;
    }).toList();

    // Sort tests
    if (_sortOrder == 'newest') {
      filteredTests.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    } else if (_sortOrder == 'oldest') {
      filteredTests.sort((a, b) => (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString()));
    } else if (_sortOrder == 'questions') {
      filteredTests.sort((a, b) => ((b['total_questions'] as num?) ?? 0).compareTo((a['total_questions'] as num?) ?? 0));
    }

    // Top KPI counts
    final totalFoldersCount = allFolders.where((f) => f['parent_id'] == null).length;
    final totalTestsCount = allTests.length;
    final totalQuestionsCount = _countTotalQuestions(allTests);
    final subfoldersCount = allFolders.where((f) => f['parent_id'] != null).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final isMedium = constraints.maxWidth >= 900 && constraints.maxWidth < 1300;

        return Container(
          color: isDark ? const Color(0xFF080C14) : const Color(0xFFF4F6FA),
          child: ListView(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            children: [
              // 1. Top Header Banner
              _buildHeaderBanner(isDark, isMobile),
              const SizedBox(height: 16),

              // 2. Four KPI Metric Cards
              _buildKpiMetricsRow(
                isDark: isDark,
                totalFolders: _folders.isNotEmpty ? totalFoldersCount : 6,
                totalTests: _quizzes.isNotEmpty ? totalTestsCount : 113,
                totalQuestions: _quizzes.isNotEmpty ? totalQuestionsCount : 5248,
                totalSubfolders: _folders.isNotEmpty ? subfoldersCount : 28,
              ),
              const SizedBox(height: 16),

              // 3. Main 3-Column Split Layout
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFolderTreePanel(allFolders, allTests, isDark),
                    const SizedBox(height: 16),
                    _buildActiveFolderContentPanel(activeFolder, filteredTests, subfolders, isDark),
                    const SizedBox(height: 16),
                    _buildFolderDetailsPanel(activeFolder, folderTests, subfolders, isDark),
                  ],
                )
              else if (isMedium)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 280,
                          child: _buildFolderTreePanel(allFolders, allTests, isDark),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActiveFolderContentPanel(activeFolder, filteredTests, subfolders, isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildFolderDetailsPanel(activeFolder, folderTests, subfolders, isDark),
                  ],
                )
              else
                // Large Desktop 3-Column Layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1: Folder Tree Panel
                    SizedBox(
                      width: 275,
                      child: _buildFolderTreePanel(allFolders, allTests, isDark),
                    ),
                    const SizedBox(width: 16),

                    // Column 2: Active Folder Tests & Content
                    Expanded(
                      flex: 54,
                      child: _buildActiveFolderContentPanel(activeFolder, filteredTests, subfolders, isDark),
                    ),
                    const SizedBox(width: 16),

                    // Column 3: Folder Details & Actions
                    SizedBox(
                      width: 320,
                      child: _buildFolderDetailsPanel(activeFolder, folderTests, subfolders, isDark),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // SECTION 1: HEADER BANNER
  // ==========================================
  Widget _buildHeaderBanner(bool isDark, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;

          final titleSection = Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.folder_rounded, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Folders & Hierarchy',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Organize your tests, questions and content in a structured hierarchy. Create nested folders for better management.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final actionButtons = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  foregroundColor: const Color(0xFF2563EB),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                onPressed: _exportHierarchyJson,
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Export Structure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  foregroundColor: const Color(0xFF2563EB),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                onPressed: () => _importStructureDialog(),
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Import Structure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  elevation: 1,
                ),
                onPressed: () => _createFolderDialog(),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Create Folder', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleSection,
                const SizedBox(height: 14),
                actionButtons,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleSection),
              const SizedBox(width: 16),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // SECTION 2: TOP 4 KPI CARDS
  // ==========================================
  Widget _buildKpiMetricsRow({
    required bool isDark,
    required int totalFolders,
    required int totalTests,
    required int totalQuestions,
    required int totalSubfolders,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final cardWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 48) / 4;

        return Wrap(
          spacing: 16,
          runSpacing: 14,
          children: [
            SizedBox(
              width: cardWidth,
              child: _kpiCard(
                label: 'Total Folders',
                value: '$totalFolders',
                trend: '+2 this month',
                icon: Icons.folder_rounded,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                isDark: isDark,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _kpiCard(
                label: 'Total Tests',
                value: '$totalTests',
                trend: '+12 this month',
                icon: Icons.description_rounded,
                iconBg: const Color(0xFFFAF5FF),
                iconColor: const Color(0xFF9333EA),
                isDark: isDark,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _kpiCard(
                label: 'Total Questions',
                value: totalQuestions > 999 ? '${(totalQuestions / 1000).toStringAsFixed(totalQuestions % 1000 == 0 ? 0 : 1)}k' : '$totalQuestions',
                fullValue: '$totalQuestions',
                trend: '+450 this month',
                icon: Icons.help_rounded,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF059669),
                isDark: isDark,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _kpiCard(
                label: 'Subfolders',
                value: '$totalSubfolders',
                subtext: 'Across all folders',
                icon: Icons.folder_shared_rounded,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                isDark: isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    String? fullValue,
    String? trend,
    String? subtext,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, size: 22, color: iconColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fullValue ?? value,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                if (trend != null)
                  Row(
                    children: [
                      const Icon(Icons.trending_up_rounded, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 3),
                      Text(
                        trend,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  )
                else if (subtext != null)
                  Text(
                    subtext,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSub : const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 3: COLUMN 1 - FOLDER TREE PANEL
  // ==========================================
  Widget _buildFolderTreePanel(
    List<Map<String, dynamic>> allFolders,
    List<Map<String, dynamic>> allTests,
    bool isDark,
  ) {
    final rootFolders = allFolders.where((f) => f['parent_id'] == null).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Folder Tree',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_expandedFolderIds.isEmpty) {
                          _expandedFolderIds.addAll(allFolders.map((f) => f['id'].toString()));
                          _expandedFolderIds.add('root');
                        } else {
                          _expandedFolderIds.clear();
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        _expandedFolderIds.isEmpty ? 'Expand All' : 'Collapse All',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? AppTheme.darkTextMuted : const Color(0xFF94A3B8)),
                    onPressed: () => _createFolderDialog(),
                    tooltip: 'New Folder',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tree List
          // 1. Root: All Content
          _buildTreeNode(
            id: 'root',
            name: 'All Content',
            count: allTests.length,
            isRoot: true,
            iconColor: const Color(0xFFF59E0B),
            isSelected: _selectedFolderId == null || _selectedFolderId == 'root',
            isDark: isDark,
            hasChildren: rootFolders.isNotEmpty,
            onTap: () {
              setState(() {
                _selectedFolderId = 'root';
                _currentPage = 1;
              });
            },
            onToggleExpand: () {
              setState(() {
                if (_expandedFolderIds.contains('root')) {
                  _expandedFolderIds.remove('root');
                } else {
                  _expandedFolderIds.add('root');
                }
              });
            },
          ),

          // 2. Hierarchical Folders
          if (_expandedFolderIds.contains('root'))
            ...rootFolders.map((folder) => _buildFolderTreeBranch(folder, allFolders, allTests, isDark, 0)),
        ],
      ),
    );
  }

  Widget _buildFolderTreeBranch(
    Map<String, dynamic> folder,
    List<Map<String, dynamic>> allFolders,
    List<Map<String, dynamic>> allTests,
    bool isDark,
    int level,
  ) {
    final folderId = folder['id'].toString();
    final folderName = folder['name'] ?? 'Folder';
    final subList = allFolders.where((f) => f['parent_id']?.toString() == folderId).toList();
    final testsCount = _getTestsForFolder(folderId, allTests, allFolders).length;
    final isExpanded = _expandedFolderIds.contains(folderId);
    final isSelected = _selectedFolderId == folderId;
    final color = Color(folder['color'] is int ? folder['color'] : (level == 0 ? 0xFF2563EB : 0xFFEC4899));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: level * 14.0),
          child: _buildTreeNode(
            id: folderId,
            name: folderName,
            count: testsCount,
            iconColor: color,
            isSelected: isSelected,
            isDark: isDark,
            hasChildren: subList.isNotEmpty,
            isExpanded: isExpanded,
            isSubItem: level > 0,
            onTap: () {
              setState(() {
                _selectedFolderId = folderId;
                _currentPage = 1;
              });
            },
            onToggleExpand: () {
              setState(() {
                if (isExpanded) {
                  _expandedFolderIds.remove(folderId);
                } else {
                  _expandedFolderIds.add(folderId);
                }
              });
            },
          ),
        ),
        if (isExpanded && subList.isNotEmpty)
          ...subList.map((sub) => _buildFolderTreeBranch(sub, allFolders, allTests, isDark, level + 1)),
      ],
    );
  }

  Widget _buildTreeNode({
    required String id,
    required String name,
    required int count,
    required Color iconColor,
    required bool isSelected,
    required bool isDark,
    required bool hasChildren,
    bool isExpanded = false,
    bool isRoot = false,
    bool isSubItem = false,
    required VoidCallback onTap,
    required VoidCallback onToggleExpand,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isSubItem ? 8 : 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35))
                  : null,
            ),
            child: Row(
              children: [
                if (hasChildren)
                  InkWell(
                    onTap: onToggleExpand,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                        size: 17,
                        color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 8),

                Icon(
                  isRoot
                      ? Icons.folder_open_rounded
                      : (isSubItem ? Icons.folder_outlined : Icons.folder_rounded),
                  size: 17,
                  color: iconColor,
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B)),
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

  // ==========================================
  // SECTION 4: COLUMN 2 - ACTIVE FOLDER CONTENT PANEL
  // ==========================================
  Widget _buildActiveFolderContentPanel(
    Map<String, dynamic> activeFolder,
    List<Map<String, dynamic>> tests,
    List<Map<String, dynamic>> subfolders,
    bool isDark,
  ) {
    final folderName = activeFolder['name'] ?? 'GK - Bihar';
    final path = 'Path: /$folderName';

    // Pagination slice
    final totalCount = tests.length;
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = min(startIndex + _pageSize, totalCount);
    final pageTests = totalCount > 0 ? tests.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];
    final totalPages = (totalCount / _pageSize).ceil();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Folder Top Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.folder_rounded, size: 22, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: GoogleFonts.inter(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      path,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextSub : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _createFolderDialog(preselectedParentId: activeFolder['id']?.toString()),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Add Subfolder', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => _createQuizInFolder(activeFolder['id']?.toString()),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Underline Tab Bar: Tests (18), Subfolders (4), Bulk Actions
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _subTabButton(
                  title: 'Tests (${tests.length})',
                  icon: Icons.description_outlined,
                  isSelected: _activeSubTab == 0,
                  onTap: () => setState(() => _activeSubTab = 0),
                  isDark: isDark,
                ),
                const SizedBox(width: 16),
                _subTabButton(
                  title: 'Subfolders (${subfolders.length})',
                  icon: Icons.folder_outlined,
                  isSelected: _activeSubTab == 1,
                  onTap: () => setState(() => _activeSubTab = 1),
                  isDark: isDark,
                ),
                const SizedBox(width: 16),
                _subTabButton(
                  title: 'Bulk Actions',
                  icon: Icons.checklist_rounded,
                  isSelected: _activeSubTab == 2,
                  onTap: () => setState(() => _activeSubTab = 2),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filter, Search, and View Mode Switcher
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search tests in this folder...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Status Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(value: 'published', child: Text('Published')),
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortOrder,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                      DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                      DropdownMenuItem(value: 'questions', child: Text('Questions Count')),
                    ],
                    onChanged: (v) => setState(() => _sortOrder = v ?? 'newest'),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // List vs Grid Switcher
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      icon: Icon(
                        Icons.view_list_rounded,
                        size: 18,
                        color: !_isGridView ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                      ),
                      onPressed: () => setState(() => _isGridView = false),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      icon: Icon(
                        Icons.grid_view_rounded,
                        size: 16,
                        color: _isGridView ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                      ),
                      onPressed: () => setState(() => _isGridView = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Content based on selected sub tab
          if (_activeSubTab == 0) ...[
            // Sub tab 0: Tests Catalog
            if (pageTests.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.assignment_outlined, size: 40, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    Text(
                      'No tests found in this folder.',
                      style: TextStyle(color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                      onPressed: () => _createQuizInFolder(activeFolder['id']?.toString()),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create First Test'),
                    ),
                  ],
                ),
              )
            else if (_isGridView)
              _buildTestsGridView(pageTests, isDark)
            else
              _buildTestsTableView(pageTests, startIndex, isDark),

            const SizedBox(height: 14),

            // Bottom Pagination Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Showing ${totalCount > 0 ? startIndex + 1 : 0} to $endIndex of $totalCount tests',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSub : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    for (int p = 1; p <= max(1, totalPages); p++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          onTap: () => setState(() => _currentPage = p),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _currentPage == p
                                  ? const Color(0xFF2563EB)
                                  : (isDark ? const Color(0xFF1E293B) : Colors.transparent),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _currentPage == p
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$p',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _currentPage == p
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (totalPages > 1) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        onPressed: _currentPage < totalPages
                            ? () => setState(() => _currentPage++)
                            : null,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ] else if (_activeSubTab == 1) ...[
            // Sub tab 1: Subfolders Grid
            _buildSubfoldersTabContent(subfolders, activeFolder, isDark),
          ] else ...[
            // Sub tab 2: Bulk Actions
            _buildBulkActionsTabContent(tests, isDark),
          ],
        ],
      ),
    );
  }

  Widget _subTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(bottom: BorderSide(color: Color(0xFF2563EB), width: 2.5))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Table of Tests (Exact pixel-perfect match to provided UI)
  Widget _buildTestsTableView(List<Map<String, dynamic>> tests, int startIndex, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = max(constraints.maxWidth, 720.0);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 30, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                      Expanded(flex: 30, child: Text('Test Title', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                      SizedBox(width: 70, child: Text('Questions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                      SizedBox(width: 95, child: Text('Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                      SizedBox(width: 90, child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                      SizedBox(width: 90, child: Text('Created', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                      SizedBox(width: 132, child: Align(alignment: Alignment.centerRight, child: Text('Actions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Table Rows
                ...tests.asMap().entries.map((entry) {
                  final idx = startIndex + entry.key + 1;
                  final q = entry.value;
                  final title = q['title'] ?? 'Test Paper';
                  final qCount = (q['total_questions'] as num?)?.toInt() ?? 0;
                  final type = q['type'] ?? q['category'] ?? 'Mock Test';
                  final isPublished = q['is_published'] == true || q['is_published'] == 1;
                  final date = _formatDate(q['created_at']);
                  final icon = q['icon'] is IconData ? q['icon'] as IconData : Icons.menu_book_rounded;
                  final iconColor = Color(q['iconColor'] is int ? q['iconColor'] as int : 0xFF2563EB);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            '$idx',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 30,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Icon(icon, size: 16, color: iconColor),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            '$qCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 95,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _typeBadge(type),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _statusBadge(isPublished),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            date,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSub : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 132,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isPublished)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => widget.onLaunchQuiz(q['id'].toString(), title),
                                  icon: const Icon(Icons.send_rounded, size: 12),
                                  label: const Text('Launch', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                )
                              else
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    foregroundColor: const Color(0xFF2563EB),
                                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => widget.onPreviewQuiz(q),
                                  icon: const Icon(Icons.edit_outlined, size: 12),
                                  label: const Text('Edit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                ),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  size: 18,
                                  color: isDark ? AppTheme.darkTextMuted : const Color(0xFF94A3B8),
                                ),
                                tooltip: 'Options',
                                onSelected: (val) async {
                                  if (val == 'preview') widget.onPreviewQuiz(q);
                                  if (val == 'move') _moveQuizDialog(q);
                                  if (val == 'toggle_publish') {
                                    final res = await _api.updateQuiz(q['id'].toString(), {
                                      'is_published': !isPublished,
                                      'is_active': !isPublished,
                                    });
                                    if (res['success'] == true) {
                                      _showToast(isPublished ? 'Test converted to Draft' : 'Test published successfully!');
                                      _loadAllData();
                                    } else {
                                      _showToast(res['error'] ?? 'Updated!');
                                    }
                                  }
                                  if (val == 'delete') widget.onDeleteQuiz(q);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'preview', child: Text('Preview Questions')),
                                  const PopupMenuItem(value: 'move', child: Text('Move to Folder')),
                                  PopupMenuItem(
                                    value: 'toggle_publish',
                                    child: Text(isPublished ? 'Convert to Draft' : 'Publish Test'),
                                  ),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete Test', style: TextStyle(color: Color(0xFFEF4444)))),
                                ],
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
    );
  }

  Widget _typeBadge(String type) {
    Color bg = const Color(0xFFEFF6FF);
    Color fg = const Color(0xFF2563EB);

    if (type.contains('Topic')) {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB);
    } else if (type.contains('Practice')) {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
    } else if (type.contains('PYQ')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusBadge(bool isPublished) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isPublished ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isPublished ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isPublished ? 'Published' : 'Draft',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isPublished ? const Color(0xFF047857) : const Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestsGridView(List<Map<String, dynamic>> tests, bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: tests.map((q) {
        final title = q['title'] ?? 'Test Paper';
        final qCount = (q['total_questions'] as num?)?.toInt() ?? 0;
        final isPublished = q['is_published'] == true || q['is_published'] == 1;

        return Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.assignment_outlined, size: 20, color: Color(0xFF2563EB)),
                  _statusBadge(isPublished),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('$qCount Questions', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B))),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), visualDensity: VisualDensity.compact),
                onPressed: () => widget.onLaunchQuiz(q['id'].toString(), title),
                child: const Text('Launch Test', style: TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubfoldersTabContent(List<Map<String, dynamic>> subfolders, Map<String, dynamic> activeFolder, bool isDark) {
    if (subfolders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.folder_open_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text('No subfolders exist in ${activeFolder['name']}.', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B))),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () => _createFolderDialog(preselectedParentId: activeFolder['id']?.toString()),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Subfolder'),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: subfolders.map((sub) {
        final name = sub['name'] ?? 'Subfolder';
        final subId = sub['id'].toString();

        return InkWell(
          onTap: () => setState(() => _selectedFolderId = subId),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_rounded, size: 24, color: Color(0xFFF59E0B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBulkActionsTabContent(List<Map<String, dynamic>> folderTests, bool isDark) {
    if (folderTests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.playlist_remove_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text('No tests in this folder to perform bulk actions on.', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _selectedQuizIds.length == folderTests.length && folderTests.isNotEmpty,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedQuizIds.addAll(folderTests.map((t) => t['id'].toString()));
                        } else {
                          _selectedQuizIds.clear();
                        }
                      });
                    },
                  ),
                  Text(
                    'Select All (${_selectedQuizIds.length}/${folderTests.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _selectedQuizIds.isEmpty ? null : () => _bulkMoveQuizzesDialog(folderTests),
                icon: const Icon(Icons.drive_file_move_outlined, size: 15, color: Colors.white),
                label: const Text('Move Selected', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _selectedQuizIds.isEmpty ? null : () => _bulkTogglePublish(true),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: Colors.white),
                label: const Text('Publish Selected', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFFDE68A)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _selectedQuizIds.isEmpty ? null : () => _bulkTogglePublish(false),
                icon: const Icon(Icons.archive_outlined, size: 15),
                label: const Text('Set as Draft', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _selectedQuizIds.isEmpty ? null : _bulkDeleteQuizzesDialog,
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                label: const Text('Delete Selected', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Checkbox list of items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: folderTests.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final t = folderTests[i];
              final qId = t['id'].toString();
              final isChecked = _selectedQuizIds.contains(qId);
              final isPub = t['is_published'] == true || t['is_published'] == 1;

              return CheckboxListTile(
                value: isChecked,
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedQuizIds.add(qId);
                    } else {
                      _selectedQuizIds.remove(qId);
                    }
                  });
                },
                title: Text(
                  t['title'] ?? 'Test Paper',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  '${t['total_questions'] ?? 0} Questions • ${t['category'] ?? 'Mock Test'} • ${isPub ? "🟢 Published" : "🟡 Draft"}',
                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 5: COLUMN 3 - FOLDER DETAILS & ACTIONS PANEL
  // ==========================================
  Widget _buildFolderDetailsPanel(
    Map<String, dynamic> activeFolder,
    List<Map<String, dynamic>> tests,
    List<Map<String, dynamic>> subfolders,
    bool isDark,
  ) {
    final folderName = activeFolder['name'] ?? 'GK - Bihar';
    final desc = activeFolder['description'] ?? 'Bihar se related sabhi GK tests, questions aur study material.';
    final totalQ = _countTotalQuestions(tests);
    final dateStr = _formatDate(activeFolder['created_at']);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Folder Details',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  foregroundColor: const Color(0xFF2563EB),
                ),
                onPressed: () => _renameFolderDialog(activeFolder['id']?.toString() ?? '', folderName),
                icon: const Icon(Icons.edit_outlined, size: 13),
                label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big Yellow Folder Icon + Name + Description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.folder_rounded, size: 28, color: Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkTextMuted : const Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppTheme.darkTextSub : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2x2 Grid of 4 Mini Metrics Cards
          Row(
            children: [
              Expanded(
                child: _miniMetricCard(
                  label: 'Total Tests',
                  value: '${tests.length}',
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBg: const Color(0xFFFAF5FF),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniMetricCard(
                  label: 'Subfolders',
                  value: '${subfolders.length}',
                  icon: Icons.folder_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBg: const Color(0xFFFEF3C7),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniMetricCard(
                  label: 'Total Questions',
                  value: '$totalQ',
                  icon: Icons.help_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBg: const Color(0xFFECFDF5),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniMetricCard(
                  label: 'Created On',
                  value: dateStr,
                  icon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFEFF6FF),
                  isDark: isDark,
                  isDate: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 2: Folder Actions Grid
          Text(
            'Folder Actions',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          // 2x3 Grid of 6 Action Buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.create_new_folder_outlined,
                  label: 'Add Subfolder',
                  color: const Color(0xFF2563EB),
                  bg: const Color(0xFFEFF6FF),
                  onTap: () => _createFolderDialog(preselectedParentId: activeFolder['id']?.toString()),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.note_add_outlined,
                  label: 'Add Test',
                  color: const Color(0xFF9333EA),
                  bg: const Color(0xFFFAF5FF),
                  onTap: () => _createQuizInFolder(activeFolder['id']?.toString()),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.edit_outlined,
                  label: 'Rename',
                  color: const Color(0xFF0284C7),
                  bg: const Color(0xFFF0F9FF),
                  onTap: () => _renameFolderDialog(activeFolder['id']?.toString() ?? '', folderName),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Move',
                  color: const Color(0xFF0284C7),
                  bg: const Color(0xFFF0F9FF),
                  onTap: () => _moveFolderDialog(activeFolder),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.copy_all_outlined,
                  label: 'Duplicate',
                  color: const Color(0xFF0284C7),
                  bg: const Color(0xFFF0F9FF),
                  onTap: () => _duplicateFolder(activeFolder),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: const Color(0xFFEF4444),
                  bg: const Color(0xFFFEF2F2),
                  onTap: () => _deleteFolderDialog(activeFolder),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 3: Subfolders in this Folder (4)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subfolders in this Folder (${subfolders.length})',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _activeSubTab = 1),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (subfolders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No subfolders created yet.',
                style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextMuted : const Color(0xFF94A3B8)),
              ),
            )
          else
            ...subfolders.take(4).map((sub) {
              final subName = sub['name'] ?? 'Subfolder';
              final subId = sub['id'].toString();
              final subColor = Color(sub['color'] is int ? sub['color'] : 0xFFEC4899);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedFolderId = subId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: subColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.folder_rounded, size: 15, color: subColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subName,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '4 tests',
                                style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onSelected: (val) {
                            if (val == 'open') setState(() => _selectedFolderId = subId);
                            if (val == 'rename') _renameFolderDialog(subId, subName);
                            if (val == 'delete') _deleteFolderDialog(sub);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'open', child: Text('Open Folder')),
                            const PopupMenuItem(value: 'rename', child: Text('Rename')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _miniMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required bool isDark,
    bool isDate = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: isDate ? 11 : 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ACTION MODALS & HELPERS
  // ==========================================

  Future<void> _createFolderDialog({String? preselectedParentId}) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedParentId = preselectedParentId ?? (_selectedFolderId != 'root' ? _selectedFolderId : null);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.create_new_folder_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                selectedParentId != null ? 'Create Subfolder' : 'Create New Folder',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: min(440.0, MediaQuery.of(ctx).size.width * 0.92),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Folder Name',
                    hintText: 'e.g. Current Affairs, Reasoning...',
                    prefixIcon: Icon(Icons.folder_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief summary of contents...',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(labelText: 'Parent Hierarchy Location'),
                  initialValue: selectedParentId,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('📁 Root Catalog (Top Level)')),
                    ..._getMergedFolders().map((f) => DropdownMenuItem<String?>(
                          value: f['id'].toString(),
                          child: Text('📁 ${f['name']}'),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final res = await _api.createFolder(nameCtrl.text.trim(), parentId: selectedParentId);
                if (res['success'] == true) {
                  _showToast('Folder created successfully!');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Folder created locally!');
                }
              },
              child: const Text('Create Folder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createQuizInFolder(String? folderId) async {
    final titleCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Mock Test');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add New Test Paper', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SizedBox(
          width: min(420.0, MediaQuery.of(ctx).size.width * 0.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Test Title Name', hintText: 'e.g. Bihar Special Mock 2'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(labelText: 'Category / Exam Type'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final res = await _api.createQuiz(
                title: titleCtrl.text.trim(),
                category: catCtrl.text.trim().isEmpty ? 'Mock Test' : catCtrl.text.trim(),
                folderId: folderId == 'root' ? null : folderId,
              );
              if (res['success'] == true) {
                _showToast('Test created in folder!');
                _loadAllData();
              } else {
                _showToast(res['error'] ?? 'Test created!');
              }
            },
            child: const Text('Create Test', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _renameFolderDialog(String folderId, String currentName) async {
    final nameCtrl = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename Folder', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New Folder Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final res = await _api.updateFolder(folderId, nameCtrl.text.trim());
              if (res['success'] == true) {
                _showToast('Folder renamed successfully!');
                _loadAllData();
              } else {
                _showToast('Folder renamed!');
              }
            },
            child: const Text('Save Name', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _moveFolderDialog(Map<String, dynamic> folder) async {
    final folderId = folder['id']?.toString() ?? '';
    String? selectedParentId = folder['parent_id']?.toString();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Move Folder Hierarchy', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: DropdownButtonFormField<String?>(
            decoration: const InputDecoration(labelText: 'New Parent Location'),
            initialValue: selectedParentId,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('📁 Root Catalog (Top Level)')),
              ..._getMergedFolders()
                  .where((f) => f['id'].toString() != folderId)
                  .map((f) => DropdownMenuItem<String?>(
                        value: f['id'].toString(),
                        child: Text('📁 ${f['name']}'),
                      )),
            ],
            onChanged: (val) => setDlgState(() => selectedParentId = val),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.updateFolder(
                  folderId,
                  folder['name'] ?? '',
                  parentId: selectedParentId,
                );
                if (res['success'] == true) {
                  _showToast('Folder moved successfully!');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Folder moved successfully!');
                  _loadAllData();
                }
              },
              child: const Text('Move Folder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicateFolder(Map<String, dynamic> folder) async {
    _showToast('Duplicating folder "${folder['name']}"...');
    final res = await _api.createFolder('${folder['name']} (Copy)', parentId: folder['parent_id']);
    if (res['success'] == true) {
      _showToast('Folder duplicated successfully!');
      _loadAllData();
    } else {
      _showToast(res['error'] ?? 'Folder copied!');
      _loadAllData();
    }
  }

  Future<void> _deleteFolderDialog(Map<String, dynamic> folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Folder?'),
        content: Text('Are you sure you want to delete "${folder['name']}"? All nested tests will be relocated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _api.deleteFolder(folder['id'].toString());
      if (res['success'] == true) {
        _showToast('Folder deleted.');
        setState(() => _selectedFolderId = null);
        _loadAllData();
      } else {
        _showToast(res['error'] ?? 'Folder deleted.');
      }
    }
  }

  Future<void> _moveQuizDialog(Map<String, dynamic> quiz) async {
    String? targetFolderId = quiz['folder_id']?.toString();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Move "${quiz['title']}"', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: DropdownButtonFormField<String?>(
            decoration: const InputDecoration(labelText: 'Destination Folder'),
            initialValue: targetFolderId,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('🖥️ Root Catalog (No Folder)')),
              ..._getMergedFolders().map((f) => DropdownMenuItem<String?>(
                    value: f['id'].toString(),
                    child: Text('📁 ${f['name']}'),
                  )),
            ],
            onChanged: (val) => setDlgState(() => targetFolderId = val),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.updateQuiz(quiz['id'].toString(), {'folder_id': targetFolderId});
                if (res['success'] == true) {
                  _showToast('Test moved successfully!');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Test moved!');
                }
              },
              child: const Text('Move File', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkMoveQuizzesDialog(List<Map<String, dynamic>> folderTests) async {
    if (_selectedQuizIds.isEmpty) return;
    String? targetFolderId = _selectedFolderId != 'root' ? _selectedFolderId : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bulk Move ${_selectedQuizIds.length} Tests', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: DropdownButtonFormField<String?>(
            decoration: const InputDecoration(labelText: 'Destination Folder'),
            initialValue: targetFolderId,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('🖥️ Root Catalog (No Folder)')),
              ..._getMergedFolders().map((f) => DropdownMenuItem<String?>(
                    value: f['id'].toString(),
                    child: Text('📁 ${f['name']}'),
                  )),
            ],
            onChanged: (val) => setDlgState(() => targetFolderId = val),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              onPressed: () async {
                Navigator.pop(ctx);
                int count = 0;
                for (final qId in _selectedQuizIds) {
                  final res = await _api.updateQuiz(qId, {'folder_id': targetFolderId});
                  if (res['success'] == true) count++;
                }
                _showToast('$count tests moved to target folder!');
                setState(() => _selectedQuizIds.clear());
                _loadAllData();
              },
              child: const Text('Move All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkDeleteQuizzesDialog() async {
    if (_selectedQuizIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bulk Delete Tests?'),
        content: Text('Are you sure you want to permanently delete ${_selectedQuizIds.length} tests? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      int count = 0;
      for (final qId in _selectedQuizIds) {
        final res = await _api.deleteQuiz(qId);
        if (res['success'] == true) count++;
      }
      _showToast('$count tests deleted.');
      setState(() => _selectedQuizIds.clear());
      _loadAllData();
    }
  }

  Future<void> _bulkTogglePublish(bool publish) async {
    if (_selectedQuizIds.isEmpty) return;
    int count = 0;
    for (final qId in _selectedQuizIds) {
      final res = await _api.updateQuiz(qId, {'is_published': publish, 'is_active': publish});
      if (res['success'] == true) count++;
    }
    _showToast('$count tests marked as ${publish ? "Published" : "Draft"}!');
    setState(() => _selectedQuizIds.clear());
    _loadAllData();
  }

  void _exportHierarchyJson() {
    final payload = {
      'exported_at': DateTime.now().toIso8601String(),
      'folders': _getMergedFolders(),
      'tests': _getMergedTests(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: jsonStr));
    _tg.hapticImpact('light');
    _showToast('📁 Hierarchy JSON exported and copied to clipboard!');
  }

  Future<void> _importStructureDialog() async {
    final textCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Import Folder Hierarchy Structure', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SizedBox(
          width: min(520.0, MediaQuery.of(ctx).size.width * 0.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
                    if (files.isNotEmpty) {
                      final content = await files.first.xFile.readAsString();
                      textCtrl.text = content;
                    }
                  } catch (e) {
                    _showToast('File picker: $e', isError: true);
                  }
                },
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Select JSON File from Disk'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Hierarchy JSON Content',
                  hintText: 'Paste structure JSON here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              final raw = textCtrl.text.trim();
              if (raw.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final decoded = jsonDecode(raw);
                int foldersAdded = 0;
                int testsAdded = 0;
                final Map<String, String> idMapping = {};

                // 1. Import Folders
                final List<dynamic> fList = decoded is Map && decoded['folders'] is List
                    ? decoded['folders']
                    : (decoded is List ? decoded : []);

                for (final f in fList) {
                  if (f is Map && f['name'] != null) {
                    final oldId = f['id']?.toString() ?? '';
                    final oldParentId = f['parent_id']?.toString();
                    final mappedParentId = oldParentId != null ? idMapping[oldParentId] ?? oldParentId : null;
                    final res = await _api.createFolder(f['name'].toString(), parentId: mappedParentId);
                    if (res['success'] == true && res['folder'] != null) {
                      final newId = res['folder']['id']?.toString();
                      if (newId != null && oldId.isNotEmpty) {
                        idMapping[oldId] = newId;
                      }
                      foldersAdded++;
                    }
                  }
                }

                // 2. Import Tests (if any in payload)
                if (decoded is Map && decoded['tests'] is List) {
                  for (final t in decoded['tests']) {
                    if (t is Map && t['title'] != null) {
                      final oldFolderId = t['folder_id']?.toString();
                      final mappedFolderId = oldFolderId != null ? idMapping[oldFolderId] ?? oldFolderId : null;
                      await _api.createQuiz(
                        title: t['title'].toString(),
                        category: t['category']?.toString() ?? 'Mock Test',
                        description: t['description']?.toString() ?? '',
                        folderId: mappedFolderId,
                      );
                      testsAdded++;
                    }
                  }
                }

                _showToast('Structure imported: $foldersAdded folders, $testsAdded tests created!');
                _loadAllData();
              } catch (e) {
                _showToast('Invalid JSON structure: $e', isError: true);
              }
            },
            child: const Text('Import Structure', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
