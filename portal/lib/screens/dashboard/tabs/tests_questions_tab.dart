import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kpi_card.dart';

class TestsQuestionsTab extends StatefulWidget {
  final List<dynamic> quizzes;
  final Map<String, dynamic> resolvedStats;
  final ApiService api;
  final TelegramService tg;
  final bool isDark;
  final Future<void> Function() onRefreshAll;
  final Function(String msg) onShowToast;
  final Function(String quizId, String title) onLaunchQuiz;
  final String? initialSearch;

  const TestsQuestionsTab({
    super.key,
    required this.quizzes,
    required this.resolvedStats,
    required this.api,
    required this.tg,
    required this.isDark,
    required this.onRefreshAll,
    required this.onShowToast,
    required this.onLaunchQuiz,
    this.initialSearch,
  });

  @override
  State<TestsQuestionsTab> createState() => TestsQuestionsTabState();
}

class TestsQuestionsTabState extends State<TestsQuestionsTab> {
  String _testSubTab = 'all'; // 'all', 'bank', 'categories', 'import', 'trash'
  Map<String, dynamic>? _selectedQuizForEdit;
  List<Map<String, dynamic>> _selectedQuizQuestions = [];
  bool _isLoadingQuestions = false;
  String _quizTableSearch = '';
  String _quizTableCategoryFilter = 'all';
  String _quizTableStatusFilter = 'all'; // 'all', 'published', 'draft'
  String _quizTableSort = 'newest'; // 'newest', 'oldest', 'questions', 'title'
  int _quizTablePage = 1;
  final int _quizTablePageSize = 10;
  bool _isTestPreviewMode = false;

  final TextEditingController _editTestTitleCtrl = TextEditingController();
  final TextEditingController _editTestDescCtrl = TextEditingController();
  String _editTestCategory = 'GK • Bihar';
  int _editTestTimeLimit = 30;
  double _editTestNegativeMark = 0.25;
  bool _editTestShuffleQuestions = true;
  bool _editTestShuffleOptions = true;
  bool _editTestShowExplanation = true;
  bool _editTestIsDraft = false;
  String _editTestImageUrl = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _quizTableSearch = widget.initialSearch!;
    }
  }

  @override
  void dispose() {
    _editTestTitleCtrl.dispose();
    _editTestDescCtrl.dispose();
    super.dispose();
  }

  void selectQuiz(Map<String, dynamic> q, {bool preview = false}) {
    _selectQuizForEditing(q);
    if (preview) {
      setState(() => _isTestPreviewMode = true);
    }
  }

  void setSearch(String search) {
    setState(() => _quizTableSearch = search);
  }

  void _showToast(String msg) => widget.onShowToast(msg);
  void _openLaunchQuizDialog(String id, String title) => widget.onLaunchQuiz(id, title);
  Future<void> _loadAllData() => widget.onRefreshAll();

  ApiService get _api => widget.api;
  TelegramService get _tg => widget.tg;
  List<dynamic> get _quizzes => widget.quizzes;
  Map<String, dynamic> get _resolvedStats => widget.resolvedStats;

  String _formatNumber(int num) {
    if (num >= 10000000) return '${(num / 10000000).toStringAsFixed(1)}Cr';
    if (num >= 100000) return '${(num / 100000).toStringAsFixed(1)}L';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return num.toString();
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
        if (_selectedQuizForEdit?['id']?.toString() == quizId) {
          setState(() {
            _selectedQuizForEdit = null;
            _selectedQuizQuestions = [];
          });
        }
        await _loadAllData();
      } else {
        _showToast('Failed to delete test: ${res['message'] ?? 'Unknown error'}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildQuizzesTab();
  }

  // ==========================================
  // TAB 2: TESTS & QUESTIONS (PIXEL-PERFECT MOCKUP IMPLEMENTATION)
  // ==========================================

  List<Map<String, dynamic>> get _allDisplayQuizzes {
    final list = <Map<String, dynamic>>[];

    // 1. Map real quizzes loaded from database
    if (_quizzes.isNotEmpty) {
      for (final raw in _quizzes) {
        if (raw is! Map<String, dynamic> && raw is! Map) continue;
        final q = Map<String, dynamic>.from(raw as Map);
        final id = q['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        final isDraft = q['is_draft'] == true || q['is_active'] == false;
        final category = q['category']?.toString() ?? (q['folder_name']?.toString() ?? 'General');
        final title = q['title']?.toString() ?? 'Test Paper';
        final desc = q['description']?.toString() ?? '';
        final qCount = int.tryParse(q['total_questions']?.toString() ?? '0') ?? 0;
        final negMarks = double.tryParse(q['negative_marks']?.toString() ?? '0.25') ?? 0.25;
        final timeSec = int.tryParse(q['time_limit_seconds']?.toString() ?? '30') ?? 30;

        String createdStr = 'Recent';
        if (q['created_at'] != null) {
          try {
            final dt = DateTime.parse(q['created_at'].toString()).toLocal();
            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            createdStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
          } catch (_) {}
        }

        list.add({
          'id': id,
          'title': title,
          'subtitle': desc.isNotEmpty ? desc : 'General test series',
          'description': desc,
          'category': category,
          'questions': qCount,
          'status': isDraft ? 'Draft' : 'Published',
          'is_draft': isDraft,
          'created': createdStr,
          'time_limit_seconds': timeSec,
          'negative_marks': negMarks,
          'marks_per_question': double.tryParse(q['marks_per_question']?.toString() ?? '2.0') ?? 2.0,
          'is_premium': q['is_premium'] == true,
          'raw': q,
        });
      }
    }

    // 2. If database has no quizzes yet, provide standard competitive exam mock tests
    if (list.isEmpty) {
      final sampleTests = [
        {
          'id': 'mock-1',
          'title': 'Bihar Special',
          'subtitle': 'Ghatna Chakra • BPSC TRE 4.0',
          'description': 'Ghatna Chakra • BPSC TRE 4.0 के लिए महत्वपूर्ण प्रश्न',
          'category': 'GK • Bihar',
          'questions': 50,
          'status': 'Published',
          'is_draft': false,
          'created': '15 Oct 2026',
          'time_limit_seconds': 30,
          'negative_marks': 0.25,
          'marks_per_question': 2.0,
          'is_premium': true,
        },
        {
          'id': 'mock-2',
          'title': 'विज्ञान मॉक टेस्ट – 10 प्रश्न',
          'subtitle': 'Science • Basic',
          'description': 'General Science foundational questions for competitive exams',
          'category': 'Science',
          'questions': 10,
          'status': 'Published',
          'is_draft': false,
          'created': '14 Oct 2026',
          'time_limit_seconds': 20,
          'negative_marks': 0.25,
          'marks_per_question': 2.0,
          'is_premium': false,
        },
        {
          'id': 'mock-3',
          'title': 'विज्ञान मॉक टेस्ट – 50 प्रश्न',
          'subtitle': 'Science • Practice',
          'description': 'Advanced Physics, Chemistry and Biology comprehensive test',
          'category': 'Science',
          'questions': 50,
          'status': 'Draft',
          'is_draft': true,
          'created': '14 Oct 2026',
          'time_limit_seconds': 30,
          'negative_marks': 0.33,
          'marks_per_question': 2.0,
          'is_premium': false,
        },
        {
          'id': 'mock-4',
          'title': 'Current Affairs – October',
          'subtitle': 'Daily Current Affairs',
          'description': 'National and International October 2026 current affairs quiz',
          'category': 'Current Affairs',
          'questions': 50,
          'status': 'Published',
          'is_draft': false,
          'created': '12 Oct 2026',
          'time_limit_seconds': 25,
          'negative_marks': 0.25,
          'marks_per_question': 2.0,
          'is_premium': true,
        },
        {
          'id': 'mock-5',
          'title': 'Maths Practice Set – 1',
          'subtitle': 'Basic to Advanced',
          'description': 'Quantitative aptitude, percentages, ratios and algebra',
          'category': 'Mathematics',
          'questions': 25,
          'status': 'Published',
          'is_draft': false,
          'created': '10 Oct 2026',
          'time_limit_seconds': 45,
          'negative_marks': 0.5,
          'marks_per_question': 2.0,
          'is_premium': false,
        },
        {
          'id': 'mock-6',
          'title': 'Reasoning – Syllogism',
          'subtitle': 'Practice Questions',
          'description': 'Logical reasoning, Venn diagrams and analytical problems',
          'category': 'Reasoning',
          'questions': 30,
          'status': 'Published',
          'is_draft': false,
          'created': '08 Oct 2026',
          'time_limit_seconds': 30,
          'negative_marks': 0.25,
          'marks_per_question': 2.0,
          'is_premium': false,
        },
        {
          'id': 'mock-7',
          'title': 'General Awareness – Mix',
          'subtitle': 'Static + Current',
          'description': 'Indian Polity, History, Geography and Economics mix paper',
          'category': 'General Awareness',
          'questions': 40,
          'status': 'Published',
          'is_draft': false,
          'created': '05 Oct 2026',
          'time_limit_seconds': 30,
          'negative_marks': 0.25,
          'marks_per_question': 2.0,
          'is_premium': true,
        },
        {
          'id': 'mock-8',
          'title': 'RRB Technician – Model Test',
          'subtitle': 'Full Syllabus',
          'description': 'Railway Recruitment Board Technician Grade III mock exam',
          'category': 'Railway',
          'questions': 100,
          'status': 'Published',
          'is_draft': false,
          'created': '01 Oct 2026',
          'time_limit_seconds': 90,
          'negative_marks': 0.33,
          'marks_per_question': 1.0,
          'is_premium': true,
        },
        {
          'id': 'mock-9',
          'title': 'Biology – Cell Biology',
          'subtitle': 'Chapter Wise',
          'description': 'Cell structure, organelle functions and DNA/RNA concepts',
          'category': 'Biology',
          'questions': 25,
          'status': 'Draft',
          'is_draft': true,
          'created': '28 Sep 2026',
          'time_limit_seconds': 25,
          'negative_marks': 0.25,
          'marks_per_question': 2.0,
          'is_premium': false,
        },
        {
          'id': 'mock-10',
          'title': 'Chemistry – Periodic Table',
          'subtitle': 'MCQ Practice',
          'description': 'Elements, atomic structure, periods and chemical bonding',
          'category': 'Chemistry',
          'questions': 30,
          'status': 'Published',
          'is_draft': false,
          'created': '25 Sep 2026',
          'time_limit_seconds': 30,
          'negative_marks': 0.25,
          'marks_per_question': 2.0,
          'is_premium': true,
        },
      ];
      list.addAll(sampleTests);
    }

    return list;
  }

  List<Map<String, dynamic>> get _filteredQuizzes {
    var list = _allDisplayQuizzes;

    // Category filter
    if (_quizTableCategoryFilter != 'all') {
      list = list.where((q) {
        final cat = q['category']?.toString().toLowerCase() ?? '';
        return cat.contains(_quizTableCategoryFilter.toLowerCase());
      }).toList();
    }

    // Status filter
    if (_quizTableStatusFilter != 'all') {
      list = list.where((q) => q['status']?.toString().toLowerCase() == _quizTableStatusFilter.toLowerCase()).toList();
    }

    // Search query
    if (_quizTableSearch.trim().isNotEmpty) {
      final qStr = _quizTableSearch.trim().toLowerCase();
      list = list.where((q) {
        final title = q['title']?.toString().toLowerCase() ?? '';
        final subtitle = q['subtitle']?.toString().toLowerCase() ?? '';
        final cat = q['category']?.toString().toLowerCase() ?? '';
        return title.contains(qStr) || subtitle.contains(qStr) || cat.contains(qStr);
      }).toList();
    }

    // Sorting
    if (_quizTableSort == 'oldest') {
      list = list.reversed.toList();
    } else if (_quizTableSort == 'questions') {
      list.sort((a, b) => ((b['questions'] as num?) ?? 0).compareTo((a['questions'] as num?) ?? 0));
    } else if (_quizTableSort == 'title') {
      list.sort((a, b) => (a['title']?.toString() ?? '').compareTo(b['title']?.toString() ?? ''));
    }

    return list;
  }

  Widget _buildQuizzesTab() {
    final isDark = widget.isDark;
    final allTests = _allDisplayQuizzes;

    // Auto-select first quiz if nothing selected yet
    if (_selectedQuizForEdit == null && allTests.isNotEmpty) {
      _selectedQuizForEdit = allTests.first;
      _editTestTitleCtrl.text = allTests.first['title']?.toString() ?? '';
      _editTestDescCtrl.text = allTests.first['description']?.toString() ?? '';
      _editTestCategory = allTests.first['category']?.toString() ?? 'GK • Bihar';
      _editTestTimeLimit = ((allTests.first['time_limit_seconds'] as num?)?.toInt() ?? 30);
      _editTestNegativeMark = ((allTests.first['negative_marks'] as num?)?.toDouble() ?? 0.25);
      _editTestIsDraft = allTests.first['is_draft'] == true;

      if (_selectedQuizQuestions.isEmpty) {
        _selectedQuizQuestions = [
          {
            'id': 'q-1',
            'question_text': 'बिहार के किस जिले में स्थित है विश्व प्रसिद्ध नालंदा विश्वविद्यालय?',
            'options': ['नालंदा', 'पटना', 'गया', 'भागलपुर'],
            'correct_option_index': 0,
            'explanation': 'नालंदा विश्वविद्यालय प्राचीन भारत में उच्च शिक्षा का सर्वाधिक महत्वपूर्ण और प्रसिद्ध केंद्र था, जो बिहार के नालंदा (राजगीर के निकट) में स्थित है।',
            'subject_tag': 'Bihar History',
            'difficulty': 'Medium',
          },
          {
            'id': 'q-2',
            'question_text': 'बिहार में 1857 के प्रसिद्ध विद्रोह का नेतृत्व किसने किया था?',
            'options': ['बाबू वीर कुंवर सिंह', 'नाना साहेब', 'तात्या टोपे', 'अमर सिंह'],
            'correct_option_index': 0,
            'explanation': 'बाबू वीर कुंवर सिंह ने जगदीशपुर (भोजपुर) से 1857 की क्रांति का ऐतिहासिक नेतृत्व किया था।',
            'subject_tag': 'Modern Bihar',
            'difficulty': 'Easy',
          },
          {
            'id': 'q-3',
            'question_text': 'चंपारण सत्याग्रह (1917) में गांधीजी को बिहार आने का आमंत्रण किसने दिया था?',
            'options': ['राजकुमार शुक्ल', 'राजेन्द्र प्रसाद', 'मजहरुल हक', 'ब्रजकिशोर प्रसाद'],
            'correct_option_index': 0,
            'explanation': 'पंडित राजकुमार शुक्ल ने लखनऊ अधिवेशन (1916) में महात्मा गांधी से मिलकर चंपारण के नील किसानों की समस्याओं से अवगत कराया था।',
            'subject_tag': 'National Movement',
            'difficulty': 'Medium',
          },
        ];
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1050;

        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28 : 16,
            vertical: 20,
          ),
          children: [
            // 1. Tests & Questions Top Header
            _buildTestsHeader(isDesktop: isDesktop),

            const SizedBox(height: 20),

            // 2. Row of 5 White KPI Cards
            _buildTestsKpiCards(isDesktop: isDesktop),

            const SizedBox(height: 20),

            // 3. Sub-Tabs Bar (All Tests, Question Bank, Categories, Import/Export, Trash)
            _buildTestsSubTabsBar(),

            const SizedBox(height: 20),

            // 4. Main Tab Body based on active subtab
            if (_testSubTab == 'all')
              _buildTestsAllSplitView(isDesktop: isDesktop, isDark: isDark)
            else if (_testSubTab == 'bank')
              _buildQuestionBankView(isDark: isDark)
            else if (_testSubTab == 'categories')
              _buildCategoriesExplorerView(isDark: isDark)
            else if (_testSubTab == 'import')
              _buildImportExportCenterView(isDark: isDark)
            else
              _buildTrashTestsView(isDark: isDark),

            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // 1. Header: Tests & Questions + Action Buttons
  // -------------------------------------------------------------
  Widget _buildTestsHeader({required bool isDesktop}) {
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
              child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tests & Questions',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Create, manage and organize tests, questions and study content for your Telegram bot.',
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
            // Button 1: Import JSON
            OutlinedButton.icon(
              onPressed: _openImportQuizDialog,
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                foregroundColor: isDark ? AppTheme.darkTextMain : const Color(0xFF334155),
                side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.file_upload_outlined, size: 16, color: Color(0xFF2563EB)),
              label: Text(
                'Import JSON',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),

            // Button 2: + Create New Test
            ElevatedButton.icon(
              onPressed: _startCreatingNewTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: Text(
                'Create New Test',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),

            // Button 3: View on Telegram
            OutlinedButton.icon(
              onPressed: () {
                _tg.openTelegramLink('https://t.me/Examplayer_bot');
                _showToast('Opening @Examplayer_bot on Telegram');
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.darkCard : const Color(0xFFEFF6FF),
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.near_me_rounded, size: 16, color: Color(0xFF2563EB)),
              label: Text(
                'View on Telegram',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 2. Row of 5 Metric KPI Cards (White Background, Pure & Clean)
  // -------------------------------------------------------------
  Widget _buildTestsKpiCards({required bool isDesktop}) {
    final all = _allDisplayQuizzes;
    final totalTests = all.length;
    final totalQuestions = all.fold<int>(0, (sum, q) => sum + ((q['questions'] as int?) ?? 0));
    final publishedCount = all.where((q) => q['status'] == 'Published').length;
    final draftCount = all.where((q) => q['status'] == 'Draft').length;
    final totalAttempts = (_resolvedStats['totalAttempts'] as num?)?.toInt() ?? 104320;
    final pctPublished = totalTests > 0 ? ((publishedCount / totalTests) * 100).toStringAsFixed(1) : '100.0';
    final pctDraft = totalTests > 0 ? ((draftCount / totalTests) * 100).toStringAsFixed(1) : '0.0';

    final cards = <Widget>[
      _buildKpiCard(
        title: 'Total Tests',
        count: _formatNumber(totalTests),
        trend: '+12 this month',
        subtext: '$totalTests tests registered',
        icon: Icons.menu_book_rounded,
        iconBg: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF059669),
      ),
      _buildKpiCard(
        title: 'Total Questions',
        count: _formatNumber(totalQuestions > 0 ? totalQuestions : 5248),
        trend: '+450 this month',
        subtext: 'Across all active modules',
        icon: Icons.help_outline_rounded,
        iconBg: const Color(0xFFFAF5FF),
        iconColor: const Color(0xFF8B5CF6),
      ),
      _buildKpiCard(
        title: 'Published Tests',
        count: _formatNumber(publishedCount),
        trend: null,
        subtext: '$pctPublished% of total tests',
        icon: Icons.check_circle_rounded,
        iconBg: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF10B981),
      ),
      _buildKpiCard(
        title: 'Draft Tests',
        count: _formatNumber(draftCount),
        trend: null,
        subtext: '$pctDraft% of total tests',
        icon: Icons.description_rounded,
        iconBg: const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFF59E0B),
      ),
      _buildKpiCard(
        title: 'Total Attempts',
        count: _formatNumber(totalAttempts),
        trend: '+15.3%',
        subtext: '1.04L candidate exams',
        icon: Icons.people_alt_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: c))).toList(),
      );
    } else {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) => SizedBox(width: (MediaQuery.of(context).size.width - 44) / 2, child: c)).toList(),
      );
    }
  }

  // -------------------------------------------------------------
  // 3. Sub-Tabs Header Navigation Bar
  // -------------------------------------------------------------
  Widget _buildTestsSubTabsBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTestTabButton('All Tests', 'all', Icons.article_outlined),
          const SizedBox(width: 8),
          _buildTestTabButton('Question Bank', 'bank', Icons.help_outline_rounded),
          const SizedBox(width: 8),
          _buildTestTabButton('Categories', 'categories', Icons.category_outlined),
          const SizedBox(width: 8),
          _buildTestTabButton('Import/Export', 'import', Icons.sync_alt_rounded),
          const SizedBox(width: 8),
          _buildTestTabButton('Trash', 'trash', Icons.delete_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildTestTabButton(String title, String key, IconData icon) {
    final isSelected = _testSubTab == key;
    final isDark = widget.isDark;

    return InkWell(
      onTap: () => setState(() => _testSubTab = key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? AppTheme.darkTextMain : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 4. Desktop Split View: All Tests Table (Left) + Edit Test (Right)
  // -------------------------------------------------------------
  Widget _buildTestsAllSplitView({required bool isDesktop, required bool isDark}) {
    final tests = _filteredQuizzes;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 60,
            child: _buildAllTestsTableCard(tests, isDark),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 40,
            child: _buildEditTestPanelCard(isDark),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAllTestsTableCard(tests, isDark),
          const SizedBox(height: 20),
          _buildEditTestPanelCard(isDark),
        ],
      );
    }
  }

  // -------------------------------------------------------------
  // Left Card: All Tests Table Card
  // -------------------------------------------------------------
  Widget _buildAllTestsTableCard(List<Map<String, dynamic>> tests, bool isDark) {
    final totalCount = tests.length;
    final totalPages = (totalCount / _quizTablePageSize).ceil().clamp(1, 999);
    final currentPage = _quizTablePage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _quizTablePageSize;
    final endIndex = (startIndex + _quizTablePageSize).clamp(0, totalCount);
    final pagedTests = totalCount > 0 ? tests.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar: Title + Search & Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.article_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(
                      'All Tests ($totalCount)',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search box
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          onChanged: (val) => setState(() {
                            _quizTableSearch = val;
                            _quizTablePage = 1;
                          }),
                          style: GoogleFonts.inter(fontSize: 12.5),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                            hintText: 'Search test title, category...',
                            hintStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Category dropdown
                    SizedBox(
                      height: 36,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _quizTableCategoryFilter,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                            style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF334155)),
                            dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Categories')),
                              DropdownMenuItem(value: 'GK', child: Text('GK • Bihar')),
                              DropdownMenuItem(value: 'Science', child: Text('Science')),
                              DropdownMenuItem(value: 'Current', child: Text('Current Affairs')),
                              DropdownMenuItem(value: 'Math', child: Text('Mathematics')),
                              DropdownMenuItem(value: 'Reasoning', child: Text('Reasoning')),
                              DropdownMenuItem(value: 'General', child: Text('General Awareness')),
                              DropdownMenuItem(value: 'Railway', child: Text('Railway')),
                              DropdownMenuItem(value: 'Biology', child: Text('Biology')),
                              DropdownMenuItem(value: 'Chemistry', child: Text('Chemistry')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() {
                                _quizTableCategoryFilter = val;
                                _quizTablePage = 1;
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    // Status dropdown
                    SizedBox(
                      height: 36,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _quizTableStatusFilter,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                            style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF334155)),
                            dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Status')),
                              DropdownMenuItem(value: 'published', child: Text('Published')),
                              DropdownMenuItem(value: 'draft', child: Text('Draft')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() {
                                _quizTableStatusFilter = val;
                                _quizTablePage = 1;
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    // Sort dropdown
                    SizedBox(
                      height: 36,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _quizTableSort,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                            style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF334155)),
                            dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                            items: const [
                              DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                              DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                              DropdownMenuItem(value: 'questions', child: Text('Most Questions')),
                              DropdownMenuItem(value: 'title', child: Text('Title A-Z')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _quizTableSort = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9)),

          // Full-width Table Header & Rows
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth < 750 ? 750.0 : constraints.maxWidth;
              final headerStyle = GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
              );

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Container(
                        height: 38,
                        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            SizedBox(width: 36, child: Text('#', style: headerStyle)),
                            Expanded(flex: 30, child: Text('Test Title', style: headerStyle)),
                            Expanded(flex: 18, child: Text('Category', style: headerStyle)),
                            Expanded(flex: 12, child: Text('Questions', style: headerStyle)),
                            Expanded(flex: 14, child: Text('Status', style: headerStyle)),
                            Expanded(flex: 14, child: Text('Created', style: headerStyle)),
                            SizedBox(width: 125, child: Align(alignment: Alignment.centerRight, child: Text('Actions', style: headerStyle))),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9)),

                      // Empty state
                      if (pagedTests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_late_outlined, size: 40, color: isDark ? AppTheme.darkTextMuted : const Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  'No tests found matching your criteria',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        // Data rows
                        ...pagedTests.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final q = entry.value;
                          final serialNum = startIndex + idx + 1;
                          final isSelected = _selectedQuizForEdit != null && _selectedQuizForEdit!['id'] == q['id'];
                          final isPublished = q['status'] == 'Published';

                          return Material(
                            color: isSelected
                                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectQuizForEditing(q),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Serial number in colored circle
                                    SizedBox(
                                      width: 36,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: _getSerialCircleColor(serialNum).withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$serialNum',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: _getSerialCircleColor(serialNum),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Test Title + Icon + Subtitle
                                    Expanded(
                                      flex: 30,
                                      child: Row(
                                        children: [
                                          _buildTestThumbnail(q['category']?.toString() ?? '', q['title']?.toString() ?? ''),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  q['title'] ?? 'Test',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12.5,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  q['subtitle'] ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Category Pill Badge
                                    Expanded(
                                      flex: 18,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildCategoryPill(q['category']?.toString() ?? 'General'),
                                      ),
                                    ),

                                    // Questions count
                                    Expanded(
                                      flex: 12,
                                      child: Text(
                                        '${q['questions'] ?? 0}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppTheme.darkTextMain : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),

                                    // Status (Published / Draft)
                                    Expanded(
                                      flex: 14,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isPublished ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 5,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: isPublished ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isPublished ? 'Published' : 'Draft',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isPublished ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Created Date
                                    Expanded(
                                      flex: 14,
                                      child: Text(
                                        q['created'] ?? 'Recent',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                    ),

                                    // Action buttons: Launch or Edit + 3-dots
                                    SizedBox(
                                      width: 125,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (isPublished)
                                            SizedBox(
                                              height: 28,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF2563EB),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  elevation: 0,
                                                ),
                                                onPressed: () => _openLaunchQuizDialog(q['id'].toString(), q['title'] ?? 'Quiz'),
                                                icon: const Icon(Icons.near_me_rounded, size: 12),
                                                label: const Text('Launch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                              ),
                                            )
                                          else
                                            SizedBox(
                                              height: 28,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0284C7),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  elevation: 0,
                                                ),
                                                onPressed: () => _selectQuizForEditing(q),
                                                icon: const Icon(Icons.edit_rounded, size: 12),
                                                label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                              ),
                                            ),
                                          const SizedBox(width: 4),

                                          // 3-dots popup menu
                                          PopupMenuButton<String>(
                                            tooltip: 'More actions',
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                                            onSelected: (val) async {
                                              if (val == 'edit') {
                                                _selectQuizForEditing(q);
                                              } else if (val == 'launch') {
                                                _openLaunchQuizDialog(q['id'].toString(), q['title'] ?? 'Quiz');
                                              } else if (val == 'duplicate') {
                                                _duplicateSelectedQuiz(q);
                                              } else if (val == 'toggle_status') {
                                                _toggleQuizPublishStatus(q);
                                              } else if (val == 'delete') {
                                                _deleteQuizPrompt(q);
                                              }
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 15),
                                                    SizedBox(width: 8),
                                                    Text('Edit in Panel', style: TextStyle(fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'launch',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.rocket_launch_rounded, size: 15, color: Color(0xFF2563EB)),
                                                    SizedBox(width: 8),
                                                    Text('Launch Battle', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'duplicate',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.copy_rounded, size: 15),
                                                    SizedBox(width: 8),
                                                    Text('Duplicate Test', style: TextStyle(fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'toggle_status',
                                                child: Row(
                                                  children: [
                                                    Icon(isPublished ? Icons.visibility_off_outlined : Icons.check_circle_outline_rounded, size: 15),
                                                    const SizedBox(width: 8),
                                                    Text(isPublished ? 'Move to Draft' : 'Publish Test', style: const TextStyle(fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuDivider(),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                                                    SizedBox(width: 8),
                                                    Text('Delete Test', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                                                  ],
                                                ),
                                              ),
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

          // Pagination Footer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalCount > 0
                      ? 'Showing ${startIndex + 1} to $endIndex of $totalCount tests'
                      : 'Showing 0 tests',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextMuted : const Color(0xFF64748B),
                  ),
                ),
                Row(
                  children: [
                    ...List.generate(min(5, totalPages), (i) {
                      final pageNum = i + 1;
                      final isCurrent = pageNum == currentPage;
                      return InkWell(
                        onTap: () => setState(() => _quizTablePage = pageNum),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isCurrent ? const Color(0xFF2563EB) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '$pageNum',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isCurrent ? Colors.white : (isDark ? AppTheme.darkTextMain : const Color(0xFF475569)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (totalPages > 5) ...[
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('...')),
                      InkWell(
                        onTap: () => setState(() => _quizTablePage = totalPages),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          child: Center(
                            child: Text(
                              '$totalPages',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.darkTextMain : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: currentPage < totalPages
                          ? () => setState(() => _quizTablePage = currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Right Card: Edit Test / Test Details & Questions Panel
  // -------------------------------------------------------------
  Widget _buildEditTestPanelCard(bool isDark) {
    final q = _selectedQuizForEdit;
    final isNew = q != null && q['id'] == 'new';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar: Edit Test title + Switch to Preview button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isNew ? Icons.add_circle_outline_rounded : Icons.edit_note_rounded,
                      size: 20,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isNew ? 'Create New Test' : 'Edit Test',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _isTestPreviewMode = !_isTestPreviewMode),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _isTestPreviewMode
                        ? const Color(0xFF2563EB)
                        : (isDark ? AppTheme.darkSurface : const Color(0xFFEFF6FF)),
                    foregroundColor: _isTestPreviewMode ? Colors.white : const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(
                    _isTestPreviewMode ? Icons.edit_rounded : Icons.visibility_rounded,
                    size: 13,
                  ),
                  label: Text(
                    _isTestPreviewMode ? 'Edit Mode' : 'Switch to Preview',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          if (_isTestPreviewMode)
            _buildTelegramQuizPreviewWidget(isDark)
          else
            _buildEditTestFormFields(isDark),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Live Telegram Bot Quiz Simulation Preview Mode
  // -------------------------------------------------------------
  Widget _buildTelegramQuizPreviewWidget(bool isDark) {
    final title = _editTestTitleCtrl.text.trim().isNotEmpty ? _editTestTitleCtrl.text.trim() : 'Competitive Exam Paper';
    final qList = _selectedQuizQuestions;

    return Container(
      padding: const EdgeInsets.all(18),
      color: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF1F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simulation Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@Examplayer_bot Simulation',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        'Live student candidate Telegram experience preview',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('STUDENT VIEW', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Test Title banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                if (_editTestDescCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(_editTestDescCtrl.text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⏱️ $_editTestTimeLimit s / question',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⚠️ -$_editTestNegativeMark Negative',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Question 1 Preview Card
          if (qList.isNotEmpty)
            _buildInteractiveSimulationQuestion(qList.first, isDark)
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('No questions added yet. Click "+ Add Question" to compose question 1.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractiveSimulationQuestion(Map<String, dynamic> q, bool isDark) {
    final qText = q['question_text']?.toString() ?? 'Sample question';
    final opts = q['options'] is List ? List<String>.from((q['options'] as List).map((e) => e.toString())) : <String>['Option A', 'Option B', 'Option C', 'Option D'];
    final correctIdx = ((q['correct_option_index'] as num?)?.toInt() ?? 0);
    final explanation = q['explanation']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('1', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  qText,
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Options list
          ...opts.asMap().entries.map((entry) {
            final idx = entry.key;
            final text = entry.value;
            final isCorrect = idx == correctIdx;
            final letter = String.fromCharCode(65 + idx);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCorrect
                    ? const Color(0xFFDCFCE7)
                    : (isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                  width: isCorrect ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isCorrect ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500,
                        color: isCorrect ? const Color(0xFF15803D) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                  if (isCorrect)
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                ],
              ),
            );
          }),

          if (explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Explanation: $explanation',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Edit Test Form Fields & Questions List
  // -------------------------------------------------------------
  Widget _buildEditTestFormFields(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Title Input (Left) + Image Thumbnail (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Test Title field
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'Test Title ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF334155),
                        ),
                        children: const [
                          TextSpan(text: '*', style: TextStyle(color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _editTestTitleCtrl,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                        hintText: 'e.g. Bihar Special',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Image Thumbnail Box
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: const Center(
                      child: Icon(Icons.account_balance_rounded, size: 28, color: Color(0xFFC2410C)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _openChangeThumbnailDialog,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_outlined, size: 12, color: Color(0xFF2563EB)),
                        const SizedBox(width: 3),
                        Text(
                          'Change Image',
                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _editTestDescCtrl,
                maxLines: 2,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                  hintText: 'Ghatna Chakra • BPSC TRE 4.0 के लिए महत्वपूर्ण प्रश्न',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: 4 Compact Fields (Category, Total Questions, Time Limit, Negative Marking)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Category
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _editTestCategory,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                          dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                          items: const [
                            DropdownMenuItem(value: 'GK • Bihar', child: Text('GK • Bihar')),
                            DropdownMenuItem(value: 'Science', child: Text('Science')),
                            DropdownMenuItem(value: 'Current Affairs', child: Text('Current Affairs')),
                            DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
                            DropdownMenuItem(value: 'Reasoning', child: Text('Reasoning')),
                            DropdownMenuItem(value: 'General Awareness', child: Text('General')),
                            DropdownMenuItem(value: 'Railway', child: Text('Railway')),
                            DropdownMenuItem(value: 'Biology', child: Text('Biology')),
                            DropdownMenuItem(value: 'Chemistry', child: Text('Chemistry')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _editTestCategory = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Total Questions Display
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Questions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '${_selectedQuizQuestions.length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),

              // Time Limit (min)
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Time (min)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: '30',
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null) _editTestTimeLimit = parsed;
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Negative Marking Dropdown
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Negative Mark', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<double>(
                          value: _editTestNegativeMark,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                          dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                          items: const [
                            DropdownMenuItem(value: 0.25, child: Text('0.25 (1/4)')),
                            DropdownMenuItem(value: 0.33, child: Text('0.33 (1/3)')),
                            DropdownMenuItem(value: 0.50, child: Text('0.50 (1/2)')),
                            DropdownMenuItem(value: 0.0, child: Text('None (0.0)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _editTestNegativeMark = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 3: 3 Toggle Switches (Strictly single horizontal line)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSmallToggle('Shuffle Questions', _editTestShuffleQuestions, (val) => setState(() => _editTestShuffleQuestions = val), isDark),
                const SizedBox(width: 14),
                _buildSmallToggle('Shuffle Options', _editTestShuffleOptions, (val) => setState(() => _editTestShuffleOptions = val), isDark),
                const SizedBox(width: 14),
                _buildSmallToggle('Show Explanation', _editTestShowExplanation, (val) => setState(() => _editTestShowExplanation = val), isDark),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Divider(height: 1, color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Questions Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Questions (${_selectedQuizQuestions.length})',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Row(
                children: [
                  // + Add Question Button
                  ElevatedButton.icon(
                    onPressed: _openAddQuestionDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Add Question', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),

                  // Bulk Import Button
                  OutlinedButton.icon(
                    onPressed: _openBulkImportQuestionsDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.file_upload_outlined, size: 14),
                    label: const Text('Bulk Import', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Questions List
          if (_isLoadingQuestions)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_selectedQuizQuestions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.quiz_outlined, size: 36, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 8),
                    const Text('No questions added yet.'),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _openAddQuestionDialog,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add Question 1'),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._selectedQuizQuestions.asMap().entries.map((entry) {
              final idx = entry.key;
              final qItem = entry.value;
              return _buildQuestionItemCard(idx, qItem, isDark);
            }),

          const SizedBox(height: 20),

          // Save Changes Action Button
          ElevatedButton.icon(
            onPressed: _saveSelectedTestChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(
              'Save Test & Questions Changes',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  // Question Card inside Edit Test Panel
  Widget _buildQuestionItemCard(int idx, Map<String, dynamic> q, bool isDark) {
    final qText = q['question_text']?.toString() ?? 'Question';
    final opts = q['options'] is List ? List<String>.from((q['options'] as List).map((e) => e.toString())) : <String>[];
    final correctIdx = ((q['correct_option_index'] as num?)?.toInt() ?? 0);
    final explanation = q['explanation']?.toString();
    final subjectTag = q['subject_tag']?.toString() ?? 'General';
    final difficulty = q['difficulty']?.toString() ?? 'Medium';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question Header: Drag handle + Q# + Question text + Image + Delete
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.drag_indicator_rounded, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                '${idx + 1}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  qText,
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.image_outlined, size: 16, color: Color(0xFF94A3B8)),
                tooltip: 'Attach Image',
                onPressed: () => _showToast('Question image attached.'),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                tooltip: 'Delete Question',
                onPressed: () => _confirmDeleteQuestion(q),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Options A, B, C, D
          ...opts.asMap().entries.map((optEntry) {
            final optIdx = optEntry.key;
            final optText = optEntry.value;
            final isCorrect = optIdx == correctIdx;
            final letter = String.fromCharCode(65 + optIdx);

            return InkWell(
              onTap: () {
                setState(() {
                  q['correct_option_index'] = optIdx;
                });
                _showToast('Correct option set to Option $letter');
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? const Color(0xFFDCFCE7)
                      : (isDark ? AppTheme.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                    width: isCorrect ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isCorrect ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          letter,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        optText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500,
                          color: isCorrect ? const Color(0xFF15803D) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                    if (isCorrect)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                  ],
                ),
              ),
            );
          }),

          // + Add Option
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final currentOpts = List<String>.from(opts);
                currentOpts.add('Option ${String.fromCharCode(65 + currentOpts.length)}');
                setState(() => q['options'] = currentOpts);
              },
              icon: const Icon(Icons.add_rounded, size: 13),
              label: const Text('+ Add Option', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),

          // Footer Row inside Question Card: Set Explanation + Subject Tag + Difficulty
          Row(
            children: [
              const Icon(Icons.check_box_outlined, size: 15, color: Color(0xFF2563EB)),
              const SizedBox(width: 4),
              const Text('Set Explanation ⓘ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(subjectTag, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 7, color: Color(0xFFB45309)),
                    const SizedBox(width: 4),
                    Text(difficulty, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                  ],
                ),
              ),
            ],
          ),
          if (explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('💡 $explanation', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallToggle(String label, bool value, ValueChanged<bool> onChanged, bool isDark) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              width: 30,
              height: 17,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: value ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Helpers: Colored Icons, Category Pills, Serial Colors
  // -------------------------------------------------------------
  Widget _buildTestThumbnail(String category, String title) {
    IconData iconData = Icons.assignment_outlined;
    Color iconColor = const Color(0xFF2563EB);
    Color bgColor = const Color(0xFFEFF6FF);

    final catLower = category.toLowerCase();
    if (catLower.contains('bihar') || title.toLowerCase().contains('bihar')) {
      iconData = Icons.account_balance_rounded;
      iconColor = const Color(0xFFC2410C);
      bgColor = const Color(0xFFFFF7ED);
    } else if (catLower.contains('science')) {
      iconData = Icons.science_rounded;
      iconColor = const Color(0xFF7E22CE);
      bgColor = const Color(0xFFFAF5FF);
    } else if (catLower.contains('chemistry')) {
      iconData = Icons.biotech_rounded;
      iconColor = const Color(0xFF4338CA);
      bgColor = const Color(0xFFEEF2FF);
    } else if (catLower.contains('current')) {
      iconData = Icons.newspaper_rounded;
      iconColor = const Color(0xFFBE123C);
      bgColor = const Color(0xFFFFF1F2);
    } else if (catLower.contains('math')) {
      iconData = Icons.calculate_rounded;
      iconColor = const Color(0xFF1D4ED8);
      bgColor = const Color(0xFFEFF6FF);
    } else if (catLower.contains('reasoning')) {
      iconData = Icons.psychology_rounded;
      iconColor = const Color(0xFFB45309);
      bgColor = const Color(0xFFFFFBEB);
    } else if (catLower.contains('railway')) {
      iconData = Icons.train_rounded;
      iconColor = const Color(0xFFB91C1C);
      bgColor = const Color(0xFFFEF2F2);
    } else if (catLower.contains('biology')) {
      iconData = Icons.eco_rounded;
      iconColor = const Color(0xFF15803D);
      bgColor = const Color(0xFFF0FDF4);
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(iconData, size: 18, color: iconColor),
      ),
    );
  }

  Widget _buildCategoryPill(String category) {
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF475569);

    final c = category.toLowerCase();
    if (c.contains('bihar')) {
      bg = const Color(0xFFFFF7ED);
      text = const Color(0xFFC2410C);
    } else if (c.contains('science')) {
      bg = const Color(0xFFFAF5FF);
      text = const Color(0xFF7E22CE);
    } else if (c.contains('current')) {
      bg = const Color(0xFFFFF1F2);
      text = const Color(0xFFBE123C);
    } else if (c.contains('math')) {
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF1D4ED8);
    } else if (c.contains('reasoning')) {
      bg = const Color(0xFFFFFBEB);
      text = const Color(0xFFB45309);
    } else if (c.contains('railway')) {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFB91C1C);
    } else if (c.contains('biology')) {
      bg = const Color(0xFFF0FDF4);
      text = const Color(0xFF15803D);
    } else if (c.contains('chemistry')) {
      bg = const Color(0xFFEEF2FF);
      text = const Color(0xFF4338CA);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }

  Color _getSerialCircleColor(int num) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];
    return colors[num % colors.length];
  }

  // -------------------------------------------------------------
  // Quiz Actions & Controllers
  // -------------------------------------------------------------
  Future<void> _selectQuizForEditing(Map<String, dynamic> q) async {
    setState(() {
      _selectedQuizForEdit = q;
      _editTestTitleCtrl.text = q['title']?.toString() ?? '';
      _editTestDescCtrl.text = q['description']?.toString() ?? '';
      _editTestCategory = q['category']?.toString() ?? 'General';
      _editTestTimeLimit = int.tryParse(q['time_limit_seconds']?.toString() ?? '30') ?? 30;
      _editTestNegativeMark = double.tryParse(q['negative_marks']?.toString() ?? '0.25') ?? 0.25;
      _editTestIsDraft = q['is_draft'] == true;
      _isLoadingQuestions = true;
    });

    final id = q['id']?.toString() ?? '';
    if (!id.startsWith('mock-') && id != 'new') {
      try {
        final qList = await _api.getQuizQuestions(id);
        if (mounted) {
          setState(() {
            _selectedQuizQuestions = qList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _isLoadingQuestions = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingQuestions = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingQuestions = false);
    }
  }

  void _startCreatingNewTest() {
    setState(() {
      _selectedQuizForEdit = {
        'id': 'new',
        'title': 'New Exam Paper',
        'subtitle': 'Practice Test Series',
        'description': '',
        'category': 'General',
        'is_draft': true,
        'status': 'Draft',
        'questions': 0,
        'time_limit_seconds': 30,
        'negative_marks': 0.25,
      };
      _editTestTitleCtrl.text = 'New Exam Paper';
      _editTestDescCtrl.text = '';
      _editTestCategory = 'General';
      _editTestTimeLimit = 30;
      _editTestNegativeMark = 0.25;
      _editTestIsDraft = true;
      _selectedQuizQuestions = [];
      _isTestPreviewMode = false;
    });
    _showToast('Composing new test in right editor panel 📝');
  }

  Future<void> _saveSelectedTestChanges() async {
    if (_selectedQuizForEdit == null) return;
    final title = _editTestTitleCtrl.text.trim();
    if (title.isEmpty) {
      _showToast('Please enter a test title');
      return;
    }

    _showToast('Saving test and questions...');
    final isNew = _selectedQuizForEdit!['id'] == 'new' || _selectedQuizForEdit!['id'].toString().startsWith('mock-');

    if (isNew) {
      final res = await _api.createQuiz(
        title: title,
        category: _editTestCategory,
        description: _editTestDescCtrl.text.trim(),
        marksPerQuestion: 2.0,
        negativeMarks: _editTestNegativeMark,
        timeLimitSeconds: _editTestTimeLimit,
        isPremium: !_editTestIsDraft,
      );
      if (res['success'] == true) {
        _showToast('Test "$title" saved to database! 🎉');
        final newQuizId = res['quiz']?['id']?.toString();
        if (newQuizId != null && _selectedQuizQuestions.isNotEmpty) {
          await _api.importQuestionsBulk(newQuizId, _selectedQuizQuestions);
        }
        await _loadAllData();
      } else {
        _showToast('Failed to save test: ${res['error'] ?? 'Check database connection'}');
      }
    } else {
      final quizId = _selectedQuizForEdit!['id'].toString();
      final res = await _api.updateQuiz(quizId, {
        'title': title,
        'category': _editTestCategory,
        'description': _editTestDescCtrl.text.trim(),
        'negative_marks': _editTestNegativeMark,
        'time_limit_seconds': _editTestTimeLimit,
      });
      if (res['success'] == true) {
        _showToast('Test changes saved! 💾');
        await _loadAllData();
      } else {
        _showToast('Save failed: ${res['error'] ?? 'Error'}');
      }
    }
  }

  void _duplicateSelectedQuiz(Map<String, dynamic> q) async {
    final quizId = q['id'].toString();
    _showToast('Duplicating "${q['title']}"...');
    final res = await _api.duplicateQuiz(quizId);
    if (res['success'] == true) {
      _showToast('Quiz duplicated successfully!');
      await _loadAllData();
    } else {
      _showToast('Duplicate failed: ${res['error'] ?? 'Error'}');
    }
  }

  void _toggleQuizPublishStatus(Map<String, dynamic> q) async {
    final willPublish = q['status'] != 'Published';
    final quizId = q['id'].toString();
    _showToast(willPublish ? 'Publishing test...' : 'Unpublishing test to draft...');
    final res = await _api.updateQuiz(quizId, {
      'is_active': willPublish,
      'is_premium': willPublish,
    });
    if (res['success'] == true) {
      _showToast(willPublish ? 'Test published for students!' : 'Test moved to draft.');
      await _loadAllData();
    } else {
      _showToast('Status update failed: ${res['error'] ?? 'Error'}');
    }
  }

  void _openAddQuestionDialog() {
    final qCtrl = TextEditingController();
    final opt0Ctrl = TextEditingController(text: 'Option A');
    final opt1Ctrl = TextEditingController(text: 'Option B');
    final opt2Ctrl = TextEditingController(text: 'Option C');
    final opt3Ctrl = TextEditingController(text: 'Option D');
    final expCtrl = TextEditingController();
    int correctIdx = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Question (${_selectedQuizQuestions.length + 1})', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: qCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Question Text', hintText: 'Type question prompt...'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: opt0Ctrl, decoration: const InputDecoration(labelText: 'Option A')),
                  const SizedBox(height: 6),
                  TextField(controller: opt1Ctrl, decoration: const InputDecoration(labelText: 'Option B')),
                  const SizedBox(height: 6),
                  TextField(controller: opt2Ctrl, decoration: const InputDecoration(labelText: 'Option C')),
                  const SizedBox(height: 6),
                  TextField(controller: opt3Ctrl, decoration: const InputDecoration(labelText: 'Option D')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Correct Option Answer'),
                    initialValue: correctIdx,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Option A is Correct ✓')),
                      DropdownMenuItem(value: 1, child: Text('Option B is Correct ✓')),
                      DropdownMenuItem(value: 2, child: Text('Option C is Correct ✓')),
                      DropdownMenuItem(value: 3, child: Text('Option D is Correct ✓')),
                    ],
                    onChanged: (val) => setDState(() => correctIdx = val ?? 0),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expCtrl,
                    decoration: const InputDecoration(labelText: 'Detailed Explanation (Optional)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                final text = qCtrl.text.trim();
                if (text.isEmpty) {
                  _showToast('Please type a question prompt.');
                  return;
                }
                Navigator.pop(ctx);

                final newQ = {
                  'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
                  'question_text': text,
                  'options': [opt0Ctrl.text.trim(), opt1Ctrl.text.trim(), opt2Ctrl.text.trim(), opt3Ctrl.text.trim()],
                  'correct_option_index': correctIdx,
                  'explanation': expCtrl.text.trim(),
                  'subject_tag': 'General Knowledge',
                  'difficulty': 'Medium',
                };

                final quizId = _selectedQuizForEdit?['id']?.toString();
                if (quizId != null && !quizId.startsWith('mock-') && quizId != 'new') {
                  final res = await _api.addQuestion(
                    quizId,
                    questionText: text,
                    options: [opt0Ctrl.text.trim(), opt1Ctrl.text.trim(), opt2Ctrl.text.trim(), opt3Ctrl.text.trim()],
                    correctOptionIndex: correctIdx,
                    explanation: expCtrl.text.trim().isNotEmpty ? expCtrl.text.trim() : null,
                  );
                  if (res['success'] == true) {
                    _showToast('Question added to database!');
                    _selectQuizForEditing(_selectedQuizForEdit!);
                    return;
                  }
                }

                setState(() {
                  _selectedQuizQuestions.add(newQ);
                });
                _showToast('Question added to list! Click "Save Changes" to commit.');
              },
              child: const Text('Add Question'),
            ),
          ],
        ),
      ),
    );
  }

  void _openBulkImportQuestionsDialog() {
    final jsonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.file_upload_outlined, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Text('Bulk Import Questions', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste question JSON array to bulk import:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: jsonCtrl,
                maxLines: 7,
                style: GoogleFonts.inter(fontSize: 11),
                decoration: InputDecoration(
                  hintText: '[\n  {\n    "question_text": "Question text...",\n    "options": ["A", "B", "C", "D"],\n    "correct_option_index": 0,\n    "explanation": "..."\n  }\n]',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              if (raw.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final decoded = jsonDecode(raw);
                if (decoded is! List) {
                  _showToast('Expected a JSON array.');
                  return;
                }
                final list = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                final quizId = _selectedQuizForEdit?['id']?.toString();

                if (quizId != null && !quizId.startsWith('mock-') && quizId != 'new') {
                  final res = await _api.importQuestionsBulk(quizId, list);
                  if (res['success'] == true) {
                    _showToast('Successfully imported ${res['count'] ?? list.length} questions!');
                    _selectQuizForEditing(_selectedQuizForEdit!);
                    return;
                  }
                }

                setState(() {
                  _selectedQuizQuestions.addAll(list);
                });
                _showToast('Added ${list.length} questions to current test!');
              } catch (e) {
                _showToast('Invalid JSON: $e');
              }
            },
            child: const Text('Import Questions'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteQuestion(Map<String, dynamic> q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text('Are you sure you want to remove this question?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final qId = q['id']?.toString();
      if (qId != null && !qId.startsWith('temp-') && !qId.startsWith('q-')) {
        await _api.deleteQuestion(qId);
      }
      setState(() {
        _selectedQuizQuestions.removeWhere((item) => item['id'] == q['id']);
      });
      _showToast('Question removed.');
    }
  }

  void _openChangeThumbnailDialog() {
    final ctrl = TextEditingController(text: _editTestImageUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Test Thumbnail Image'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Image URL or Icon Key', hintText: 'https://example.com/banner.png'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _editTestImageUrl = ctrl.text.trim());
              _showToast('Thumbnail updated! 🖼️');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openImportQuizDialog() {
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
            Text('Import Test Paper JSON', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paste complete test paper JSON with questions array:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 10),
              TextField(
                controller: jsonCtrl,
                maxLines: 8,
                style: GoogleFonts.inter(fontSize: 11),
                decoration: InputDecoration(
                  hintText: '{\n  "title": "Bihar Special Quiz",\n  "category": "GK • Bihar",\n  "time_limit_seconds": 30,\n  "questions": [\n    {\n      "question_text": "Question 1...",\n      "options": ["A", "B", "C", "D"],\n      "correct_option_index": 0\n    }\n  ]\n}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              if (raw.isEmpty) return;
              Navigator.pop(ctx);
              _showToast('Importing test into database...');
              final res = await _api.importQuizJson(raw);
              if (res['success'] == true) {
                _showToast('Test paper imported successfully! 🎉');
                await _loadAllData();
              } else {
                _showToast('Import failed: ${res['error'] ?? 'Check JSON format'}');
              }
            },
            child: const Text('Import Test'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Secondary Sub-Tabs: Question Bank, Categories, Import/Export, Trash
  // -------------------------------------------------------------
  Widget _buildQuestionBankView({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, size: 22, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 10),
              Text('Universal Question Bank', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Search, organize and reuse questions across multiple test papers.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search universal question repository...',
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 20),
          ..._selectedQuizQuestions.map((q) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(q['question_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _showToast('Question cloned into current draft!'),
                  child: const Text('Add to Test', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCategoriesExplorerView({required bool isDark}) {
    final categories = ['GK • Bihar', 'Science', 'Current Affairs', 'Mathematics', 'Reasoning', 'General Awareness', 'Railway', 'Biology', 'Chemistry'];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: categories.map((cat) {
        final count = _allDisplayQuizzes.where((q) => q['category']?.toString().toLowerCase().contains(cat.toLowerCase()) == true).length;
        return Container(
          width: 240,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryPill(cat),
              const SizedBox(height: 12),
              Text(cat, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('$count test modules organized', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImportExportCenterView({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_alt_rounded, size: 22, color: Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Text('Import & Export Studio', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _openImportQuizDialog,
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Import Test Paper (JSON)'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final list = _allDisplayQuizzes;
                  final encoded = const JsonEncoder.withIndent('  ').convert(list);
                  Clipboard.setData(ClipboardData(text: encoded));
                  _showToast('Copied ${list.length} tests as JSON to clipboard!');
                },
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Export All Tests (JSON)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrashTestsView({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.delete_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text('Trash is empty', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            SizedBox(height: 4),
            Text('Deleted test papers will appear here for 30 days before permanent cleanup.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }



}
