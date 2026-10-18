import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';

class LeaderboardTab extends StatefulWidget {
  final List<dynamic> globalLeaderboard;
  final List<dynamic> quizzes;
  final ApiService api;
  final TelegramService tg;
  final bool isDark;
  final Future<void> Function() onRefreshLeaderboard;
  final Function(String msg, {bool isError}) onShowToast;

  const LeaderboardTab({
    super.key,
    required this.globalLeaderboard,
    required this.quizzes,
    required this.api,
    required this.tg,
    required this.isDark,
    required this.onRefreshLeaderboard,
    required this.onShowToast,
  });

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  // Navigation & Sub-tabs
  String _activeSubTab = 'overall'; // overall, testwise, subjectwise, weekly, certs, settings
  String _selectedSubject = 'General Science';
  String _filterTest = 'All Tests';
  String _filterSubject = 'All Subjects';
  String _filterTime = 'All Time';
  String _dateRangeText = '01 Oct 2026 - 31 Oct 2026';
  String _searchQuery = '';

  // Test-wise state
  String? _selectedQuizId;
  List<dynamic> _quizLeaderboardAttempts = [];
  bool _isLoadingQuizLeaderboard = false;

  // Pagination
  int _currentPage = 1;
  final int _pageSize = 10;

  // Real backend analytics data
  bool _isLoading = true;
  Map<String, dynamic> _analyticsMetrics = {
    'totalParticipants': 0,
    'testsAttempted': 0,
    'topScore': '0/0',
    'topScoreTitle': 'No attempts yet',
    'averageScore': '0%',
    'activeLast7Days': 0,
  };
  List<dynamic> _leaderboardList = [];
  Map<String, dynamic> _subjectPerformers = {};
  List<dynamic> _performanceTrends = [];
  List<dynamic> _recentTopScores = [];

  ApiService get _api => widget.api;
  TelegramService get _tg => widget.tg;

  @override
  void initState() {
    super.initState();
    _loadAllAnalytics();
  }

  Future<void> _loadAllAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getLeaderboardAnalytics();
      if (res['success'] == true && mounted) {
        setState(() {
          if (res['metrics'] != null) _analyticsMetrics = res['metrics'];
          if (res['leaderboard'] != null && (res['leaderboard'] as List).isNotEmpty) {
            _leaderboardList = res['leaderboard'];
          }
          if (res['subjectPerformers'] != null) _subjectPerformers = res['subjectPerformers'];
          if (res['performanceTrends'] != null) _performanceTrends = res['performanceTrends'];
          if (res['recentTopScores'] != null) _recentTopScores = res['recentTopScores'];
          _isLoading = false;
        });
        if (_selectedQuizId != null) {
          _loadQuizLeaderboard(_selectedQuizId!);
        } else if (widget.quizzes.isNotEmpty) {
          _selectedQuizId = widget.quizzes.first['id']?.toString();
          _loadQuizLeaderboard(_selectedQuizId!);
        }
        return;
      }
    } catch (_) {}

    // Fallback to widget.globalLeaderboard if api failed
    if (mounted) {
      if (_leaderboardList.isEmpty && widget.globalLeaderboard.isNotEmpty) {
        setState(() {
          _leaderboardList = widget.globalLeaderboard.asMap().entries.map((entry) {
            final idx = entry.key;
            final u = entry.value;
            final tests = u['tests_completed'] ?? 0;
            final score = u['score'] ?? u['total_score'] ?? 0;
            final accuracy = u['accuracy'] ?? '0.0%';
            return {
              'rank': idx + 1,
              'user_id': u['user_id'] ?? u['id'] ?? u['telegram_id'],
              'first_name': u['first_name'] ?? 'Candidate',
              'username': u['username'] ?? 'user_${u['id'] ?? idx}',
              'total_score': score,
              'tests_completed': tests,
              'accuracy': accuracy,
              'trending': '+0',
              'is_trending_up': true,
            };
          }).toList();
        });
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadQuizLeaderboard(String quizId) async {
    setState(() => _isLoadingQuizLeaderboard = true);
    try {
      final res = await _api.getQuizLeaderboard(quizId);
      if (res['success'] == true && mounted) {
        setState(() {
          _quizLeaderboardAttempts = (res['attempts'] as List?) ?? [];
          _isLoadingQuizLeaderboard = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingQuizLeaderboard = false);
  }

  // Pick Date Range
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2028),
      initialDateRange: DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
      ),
    );
    if (picked != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      setState(() {
        _dateRangeText =
            '${picked.start.day.toString().padLeft(2, '0')} ${months[picked.start.month - 1]} ${picked.start.year} - ${picked.end.day.toString().padLeft(2, '0')} ${months[picked.end.month - 1]} ${picked.end.year}';
      });
      _loadAllAnalytics();
    }
  }

  // Open Student Details Modal
  void _openStudentDetailsModal(Map<String, dynamic> student) {
    _tg.hapticImpact('light');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: min(520.0, MediaQuery.of(ctx).size.width * 0.95),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    child: Text(
                      (student['first_name'] ?? 'U')[0].toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              student['first_name'] ?? 'Candidate',
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            const Text('👑', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        Text(
                          '@${student['username'] ?? 'unknown'}',
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark ? AppTheme.darkCard : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniStat('Rank', '#${student['rank'] ?? 1}', const Color(0xFFF59E0B)),
                    _miniStat('Total Score', '${student['total_score'] ?? 0}', const Color(0xFF2563EB)),
                    _miniStat('Accuracy', '${student['accuracy'] ?? '0%'}', const Color(0xFF10B981)),
                    _miniStat('Tests', '${student['tests_completed'] ?? 0}', const Color(0xFF6366F1)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Recent Performance & Examination Attempts',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<dynamic>>(
                future: _api.getUserAttempts(student['user_id'] ?? student['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final attempts = snapshot.data ?? [];
                  if (attempts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No examination attempts recorded in database yet.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: attempts.take(4).map((att) {
                      final quizTitle = (att['quizzes'] is Map ? att['quizzes']['title'] : null) ??
                          att['quiz_title'] ??
                          'Exam #${att['quiz_id'] ?? ''}';
                      final score = '${att['score'] ?? 0}/${att['total_questions'] ?? 100}';
                      final accuracy = att['accuracy_percent'] != null ? '${att['accuracy_percent']}% Accuracy' : 'Attempt recorded';
                      final rawDate = att['completed_at'] ?? att['created_at'];
                      String dateStr = '';
                      if (rawDate != null) {
                        try {
                          final dt = DateTime.parse(rawDate.toString()).toLocal();
                          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          dateStr = ' · ${dt.day} ${months[dt.month - 1]} ${dt.year}';
                        } catch (_) {}
                      }
                      return _recentAttemptItem(
                        quizTitle,
                        score,
                        '$accuracy$dateStr',
                        (att['score'] ?? 0) >= ((att['total_questions'] ?? 100) * 0.7)
                            ? const Color(0xFF10B981)
                            : const Color(0xFF2563EB),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSendMessageDialog(student);
                      },
                      icon: const Icon(Icons.mail_outline_rounded, size: 16),
                      label: const Text('Send Message'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onShowToast('Candidate standing verified with live records! 🎯');
                      },
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: const Text('Verify Record'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showSendMessageDialog(Map<String, dynamic> student) {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Message @${student['username'] ?? 'User'}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: msgCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter direct announcement or congratulatory message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              if (msgCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final res = await _api.sendUserMessage(student['user_id'], msgCtrl.text.trim());
              if (res['success'] == true) {
                widget.onShowToast('Direct message dispatched via Telegram! 📲');
              } else {
                widget.onShowToast(res['error'] ?? 'Message failed', isError: true);
              }
            },
            child: const Text('Send Telegram Message', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _recentAttemptItem(String title, String score, String meta, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.quiz_outlined, size: 16, color: badgeColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(meta, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Text(score, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: badgeColor)),
        ],
      ),
    );
  }

  // Build Rank Badge Icon (Gold, Silver, Bronze, or Number)
  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFFEF3C7),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🥇', style: TextStyle(fontSize: 16)),
        ),
      );
    } else if (rank == 2) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🥈', style: TextStyle(fontSize: 16)),
        ),
      );
    } else if (rank == 3) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFFFEDD5),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🥉', style: TextStyle(fontSize: 16)),
        ),
      );
    }
    return Text(
      '#$rank',
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
    );
  }

  // Color generator for avatar initials
  Color _getAvatarColor(int index) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF4F46E5),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFFEA580C),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1080;
    final isDark = widget.isDark;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadAllAnalytics();
        await widget.onRefreshLeaderboard();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. PAGE HEADER (Icon + Title + Subtitle + Date Range Picker)
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

            // 2. SUB-NAV PILL BAR
            _buildSubNavPills(isDark),
            const SizedBox(height: 20),

            // 3. TOP 5 KPI METRICS CARDS
            _buildKpiMetricsRow(isDark),
            const SizedBox(height: 24),

            // 4. MAIN CONTENT (Dynamic per Sub-Nav Tab)
            _buildActiveTabContent(isDark, isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(bool isDark, bool isDesktop) {
    switch (_activeSubTab) {
      case 'testwise':
        return _buildTestwiseLeaderboardView(isDark);
      case 'subjectwise':
        return _buildSubjectwiseMeritView(isDark);
      case 'weekly':
        return _buildWeeklyMonthlyMeritView(isDark);
      case 'certs':
        return _buildCertificatesRewardsView(isDark);
      case 'settings':
        return _buildLeaderboardSettingsView(isDark);
      case 'overall':
      default:
        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 65,
                child: _buildOverallLeaderboardCard(isDark),
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
              _buildOverallLeaderboardCard(isDark),
              const SizedBox(height: 24),
              _buildRightSidePanels(isDark),
            ],
          );
        }
    }
  }

  Widget _buildTestwiseLeaderboardView(bool isDark) {
    final quizzes = widget.quizzes;
    String? dropdownVal = _selectedQuizId;
    if (quizzes.isNotEmpty && !quizzes.any((q) => q['id']?.toString() == dropdownVal)) {
      dropdownVal = quizzes.first['id']?.toString();
    }

    Map<String, dynamic>? selectedQuiz;
    if (dropdownVal != null && quizzes.isNotEmpty) {
      selectedQuiz = quizzes.firstWhere(
        (q) => q['id']?.toString() == dropdownVal,
        orElse: () => quizzes.first,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_outlined, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test-wise Examination Standings',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF111B35),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select an exam to view detailed candidate attempts, marks and completion speed.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (quizzes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: dropdownVal,
                        isDense: true,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        items: quizzes.map((q) {
                          final id = q['id']?.toString() ?? '';
                          final title = q['title'] ?? 'Test #$id';
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              title.length > 35 ? '${title.substring(0, 32)}...' : title,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedQuizId = val);
                            _loadQuizLeaderboard(val);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (selectedQuiz != null && selectedQuiz.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: isDark ? AppTheme.darkSurface.withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedQuiz['title'] ?? 'Selected Test',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Category: ${selectedQuiz['category'] ?? 'General'} · Marks: ${selectedQuiz['marks_per_question'] ?? 2.0} · Neg: ${selectedQuiz['negative_marks'] ?? 0.0}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_quizLeaderboardAttempts.length} Submissions Recorded',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (_isLoadingQuizLeaderboard)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_quizLeaderboardAttempts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.inbox_outlined, size: 40, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    Text(
                      'No submissions recorded for this test yet',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'When students take this exam in Telegram Bot, their rank, score and accuracy will display here live.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = max(constraints.maxWidth, 1100.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                          child: Row(
                            children: [
                              _colHeader('#', 40),
                              Expanded(
                                child: Text(
                                  'Candidate',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              _colHeader('Score', 110),
                              _colHeader('Accuracy', 120),
                              _colHeader('Time Taken', 110),
                              _colHeader('Correct / Wrong', 160),
                              _colHeader('Actions', 70, alignment: Alignment.centerRight),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ..._quizLeaderboardAttempts.asMap().entries.map((entry) {
                          final rank = entry.key + 1;
                          final att = entry.value;
                          final user = (att['users'] is Map) ? att['users'] as Map : {};
                          final nameParts = [user['first_name'], user['last_name']]
                              .where((s) => s != null && s.toString().trim().isNotEmpty)
                              .toList();
                          final name = nameParts.isNotEmpty ? nameParts.join(' ') : 'Candidate';
                          final username = user['username'] ?? 'user_${att['user_id']}';
                          final timeTaken = (att['time_taken_seconds'] is num) ? (att['time_taken_seconds'] as num).toInt() : 0;
                          final timeStr = '${timeTaken ~/ 60}m ${timeTaken % 60}s';
                          final avatarColor = _getAvatarColor(rank);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9))),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 40, child: _buildRankBadge(rank)),
                                Expanded(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: avatarColor,
                                        child: Text(
                                          name[0].toUpperCase(),
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '@$username',
                                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    '${att['score'] ?? 0}/${att['total_questions'] ?? 100}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${att['accuracy_percent'] ?? 0}% Accuracy',
                                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: Text(timeStr, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                ),
                                SizedBox(
                                  width: 160,
                                  child: Text(
                                    '✓ ${att['correct_count'] ?? 0}  ✗ ${att['wrong_count'] ?? 0}  – ${att['skipped_count'] ?? 0}',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.mail_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                                        tooltip: 'Send Telegram Message',
                                        onPressed: () => _showSendMessageDialog({
                                          'user_id': att['user_id'],
                                          'username': username,
                                          'first_name': name,
                                        }),
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
        ],
      ),
    );
  }

  Widget _buildSubjectwiseMeritView(bool isDark) {
    final subjects = _subjectPerformers.keys.toList();
    if (subjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text('No subject categories recorded yet.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.category_outlined, color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subject-wise Merit & Category Standings',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'High-scoring students organized across specific exam disciplines and syllabus categories.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 700;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: subjects.map((subj) {
                final performers = (_subjectPerformers[subj] as List?) ?? [];
                final width = isDesktop ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

                return Container(
                  width: width,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                subj,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${performers.length} Performers',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),
                      if (performers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('No attempts recorded yet for $subj', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                          ),
                        )
                      else
                        ...performers.map((p) {
                          final rank = p['rank'] ?? 1;
                          final name = p['name'] ?? 'Candidate';
                          final username = p['username'] ?? 'user';
                          final score = p['score'] ?? '0%';
                          final avatarColor = _getAvatarColor(rank);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(width: 26, child: _buildRankBadge(rank)),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: avatarColor,
                                  child: Text(name[0].toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text('@$username', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Text(
                                  score,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeeklyMonthlyMeritView(bool isDark) {
    final topThree = _leaderboardList.take(3).toList();
    final remaining = _leaderboardList.skip(3).take(15).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Text(
                'Weekly / Monthly Merit Podium 🏆',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Celebrated champions with highest cumulative examination points',
                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              if (topThree.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No contenders on podium yet.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (topThree.length >= 2)
                      _buildPodiumStep(topThree[1] as Map<String, dynamic>, 2, '🥈 Silver Medalist', const Color(0xFF94A3B8), 140, isDark),
                    const SizedBox(width: 16),
                    _buildPodiumStep(topThree[0] as Map<String, dynamic>, 1, '🥇 Grand Champion', const Color(0xFFF59E0B), 180, isDark),
                    const SizedBox(width: 16),
                    if (topThree.length >= 3)
                      _buildPodiumStep(topThree[2] as Map<String, dynamic>, 3, '🥉 Bronze Merit', const Color(0xFFEA580C), 120, isDark),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (remaining.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Honor Roll & Top Standings',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                ...remaining.map((u) {
                  final rank = u['rank'] ?? 4;
                  final avatarColor = _getAvatarColor(rank);
                  final name = u['first_name'] ?? 'Student';
                  final username = u['username'] ?? 'user';
                  final score = u['total_score'] ?? 0;
                  final tests = u['tests_completed'] ?? 0;
                  final accuracy = u['accuracy'] ?? '0%';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 32, child: Text('#$rank', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: avatarColor,
                          child: Text(name[0].toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700)),
                              Text('@$username', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Text('$score pts', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                        const SizedBox(width: 16),
                        Text('$tests tests', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            accuracy,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPodiumStep(
    Map<String, dynamic> user,
    int rank,
    String title,
    Color medalColor,
    double height,
    bool isDark,
  ) {
    final name = user['first_name'] ?? 'Champion';
    final score = user['total_score'] ?? 0;
    final accuracy = user['accuracy'] ?? '0%';

    return SizedBox(
      width: 180,
      child: Column(
        children: [
          CircleAvatar(
            radius: rank == 1 ? 28 : 22,
            backgroundColor: medalColor.withValues(alpha: 0.2),
            child: Text(
              name[0].toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: rank == 1 ? 22 : 16,
                fontWeight: FontWeight.bold,
                color: medalColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$score pts · $accuracy',
            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  medalColor.withValues(alpha: 0.25),
                  medalColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: medalColor.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    rank == 1 ? '👑 #1' : '#$rank',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: medalColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: medalColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatesRewardsView(bool isDark) {
    final qualifiers = _leaderboardList.where((u) {
      final acc = double.tryParse((u['accuracy'] ?? '0').toString().replaceAll('%', '')) ?? 0.0;
      return acc >= 60.0 || (u['total_score'] ?? 0) > 0;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.military_tech_outlined, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificates & Merit Honors Directory',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Candidate qualification status for official certificates, distinction awards and Telegram honors.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final csv = [
                    'Rank,Name,Username,Score,Accuracy,Tests Completed',
                    ...qualifiers.map((q) =>
                        '${q['rank']},"${q['first_name']}","@${q['username']}",${q['total_score']},${q['accuracy']},${q['tests_completed']}'),
                  ];
                  Clipboard.setData(ClipboardData(text: csv.join('\n')));
                  widget.onShowToast('Honours directory exported to clipboard as CSV! 📋');
                },
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export Honours (CSV)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (qualifiers.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text('No candidates have met the certificate threshold yet.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: qualifiers.map((candidate) {
                final acc = double.tryParse((candidate['accuracy'] ?? '0').toString().replaceAll('%', '')) ?? 0.0;
                final tierTitle = acc >= 90.0 ? 'Gold Distinction 🥇' : (acc >= 75.0 ? 'Silver Honours 🥈' : 'Merit Certificate 🎖️');
                final tierColor = acc >= 90.0 ? const Color(0xFFF59E0B) : (acc >= 75.0 ? const Color(0xFF6366F1) : const Color(0xFF10B981));

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: tierColor.withValues(alpha: 0.15),
                        child: Text(
                          (candidate['first_name'] ?? 'C')[0].toUpperCase(),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: tierColor),
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
                                  candidate['first_name'] ?? 'Candidate',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tierColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tierTitle,
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: tierColor),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '@${candidate['username'] ?? 'user'} · Score: ${candidate['total_score']} · Accuracy: ${candidate['accuracy']}',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: candidate['user_id']?.toString() ?? ''));
                          widget.onShowToast('Merit User ID copied! 📋');
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy ID'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showSendMessageDialog(candidate as Map<String, dynamic>),
                        icon: const Icon(Icons.send_rounded, size: 14),
                        label: const Text('Congratulate'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildLeaderboardSettingsView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B3DF5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings_outlined, color: Color(0xFF5B3DF5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leaderboard Engine & Standing Rules',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure deterministic ranking criteria, bot command visibility and sync settings.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 20),
              Text('Ranking & Tie-Breaking Rules', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _settingRuleItem(
                '1. Total Cumulative Score',
                'Candidates with the highest raw marks and positive points rank higher.',
                Icons.looks_one_rounded,
                const Color(0xFF2563EB),
              ),
              _settingRuleItem(
                '2. Speed & Execution Efficiency',
                'For equal scores, candidates completing tests in fewer seconds receive priority.',
                Icons.looks_two_rounded,
                const Color(0xFF10B981),
              ),
              _settingRuleItem(
                '3. Earliest Submission Timestamp',
                'If score and speed are identical, the earliest timestamp submitted to Supabase wins.',
                Icons.looks_3_rounded,
                const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 24),
              Text('Telegram Bot Integration', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_outlined, color: Color(0xFF2563EB)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('/top & /leaderboard Command', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(
                            'Telegram users can view the top 10 ranked candidates instantly via live database query.',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('🟢 Live Synced', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await _loadAllAnalytics();
                      await widget.onRefreshLeaderboard();
                      widget.onShowToast('Merit standings successfully recalculated and synchronized! ⚡');
                    },
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Force Recalculate Leaderboard'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingRuleItem(String title, String desc, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(desc, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION BUILDERS
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
            child: Icon(Icons.emoji_events_rounded, color: Color(0xFF5B3DF5), size: 24),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leaderboards & Merit',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111B35),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Track top performers, view test-wise rankings and manage rewards. Motivate your users with fair and transparent leaderboards.',
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
        // Date-range selector button
        InkWell(
          onTap: _selectDateRange,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  _dateRangeText,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubNavPills(bool isDark) {
    final tabs = [
      {'id': 'overall', 'label': 'Overall Leaderboard', 'icon': Icons.bar_chart_rounded},
      {'id': 'testwise', 'label': 'Test-wise Leaderboard', 'icon': Icons.assignment_outlined},
      {'id': 'subjectwise', 'label': 'Subject-wise', 'icon': Icons.category_outlined},
      {'id': 'weekly', 'label': 'Weekly / Monthly', 'icon': Icons.calendar_month_outlined},
      {'id': 'certs', 'label': 'Certificates & Rewards', 'icon': Icons.military_tech_outlined},
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
                if (t['id'] == 'certs') {
                  widget.onShowToast('Certificates & Rewards directory is up to date 🎖️');
                } else if (t['id'] == 'settings') {
                  widget.onShowToast('Leaderboard tie-breaking: Deterministic score + earliest completion');
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF5B3DF5)
                      : (isDark ? AppTheme.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF5B3DF5)
                        : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
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

  Widget _buildKpiMetricsRow(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 4 * 16) / 5;
        final isMobile = constraints.maxWidth < 900;

        final participants = '${_analyticsMetrics['totalParticipants'] ?? 0}';
        final attempts = '${_analyticsMetrics['testsAttempted'] ?? 0}';
        final topScore = '${_analyticsMetrics['topScore'] ?? '0/0'}';
        final topScoreTitle = '${_analyticsMetrics['topScoreTitle'] ?? 'No attempts yet'}';
        final avgScore = '${_analyticsMetrics['averageScore'] ?? '0%'}';
        final active7d = '${_analyticsMetrics['activeLast7Days'] ?? 0}';

        if (isMobile) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpiMetricCard('Total Participants', participants, 'Registered Candidates', Icons.people_alt_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark, 170),
              _kpiMetricCard('Tests Attempted', attempts, 'Database Submissions', Icons.emoji_events_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark, 170),
              _kpiMetricCard('Top Score', topScore, topScoreTitle, Icons.star_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark, 170),
              _kpiMetricCard('Average Score', avgScore, 'Across All Exams', Icons.bar_chart_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark, 170),
              _kpiMetricCard('Active in Last 7 Days', active7d, 'Active Examinees', Icons.military_tech_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2), isDark, 170),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _kpiMetricCard('Total Participants', participants, 'Registered Candidates', Icons.people_alt_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Tests Attempted', attempts, 'Database Submissions', Icons.emoji_events_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Top Score', topScore, topScoreTitle, Icons.star_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Average Score', avgScore, 'Across All Exams', Icons.bar_chart_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Active in Last 7 Days', active7d, 'Active Examinees', Icons.military_tech_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2), isDark, cardWidth)),
          ],
        );
      },
    );
  }

  Widget _kpiMetricCard(
    String label,
    String value,
    String trend,
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? accentColor.withValues(alpha: 0.15) : softBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, size: 20, color: accentColor),
                ),
              ),
              if (trend.startsWith('+') || trend.startsWith('↗'))
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 2),
                    Text(
                      trend,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF111B35),
              letterSpacing: -0.5,
            ),
          ),
          if (!trend.startsWith('+') && !trend.startsWith('↗'))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                trend,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // OVERALL LEADERBOARD CARD & TABLE
  // =========================================================================

  Widget _buildOverallLeaderboardCard(bool isDark) {
    // Dynamic options
    final testOptions = ['All Tests', ...widget.quizzes.map((q) => (q['title'] ?? 'Quiz ${q['id']}').toString())];
    final subjectOptions = ['All Subjects', ..._subjectPerformers.keys];

    // Filter leaderboard
    var displayList = _leaderboardList;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      displayList = displayList.where((u) {
        final name = (u['first_name'] ?? '').toString().toLowerCase();
        final username = (u['username'] ?? '').toString().toLowerCase();
        return name.contains(q) || username.contains(q);
      }).toList();
    }

    final totalPages = max(1, (displayList.length / _pageSize).ceil());
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = min(displayList.length, startIndex + _pageSize);
    final pagedList = displayList.sublist(
      min(startIndex, displayList.length),
      endIndex,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Card Header with Search & Dropdowns
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🏆', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Leaderboard',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF111B35),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Top performers based on total score, tests completed and accuracy.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Search & Filter Dropdowns
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 34,
                      child: TextField(
                        onChanged: (val) => setState(() {
                          _searchQuery = val;
                          _currentPage = 1;
                        }),
                        style: GoogleFonts.inter(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search candidate...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ),
                    _dropdownPill(_filterTest, testOptions, (val) {
                      setState(() {
                        _filterTest = val;
                        _currentPage = 1;
                      });
                    }, isDark),
                    _dropdownPill(_filterSubject, subjectOptions, (val) {
                      setState(() {
                        _filterSubject = val;
                        _currentPage = 1;
                      });
                    }, isDark),
                    _dropdownPill(_filterTime, ['All Time', 'This Month', 'This Week', 'Today'], (val) {
                      setState(() => _filterTime = val);
                    }, isDark),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Table Rows
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (pagedList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text('No student records found matching filters', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = max(constraints.maxWidth, 1100.0);
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
                              _colHeader('#', 40),
                              Expanded(
                                child: Text(
                                  'Candidate',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              _colHeader('Total Score', 105),
                              _colHeader('Tests', 80),
                              _colHeader('Accuracy', 130),
                              _colHeader('Merit Tier', 125),
                              _colHeader('Trending', 80),
                              _colHeader('Last Active', 105),
                              _colHeader('Actions', 165, alignment: Alignment.centerRight),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),

                        // Table Body
                        ...pagedList.map((student) {
                          final rank = student['rank'] ?? 1;
                          final isUp = student['is_trending_up'] ?? true;
                          final trendingText = student['trending'] ?? '+0';
                          final avatarColor = _getAvatarColor(rank);

                          final accStr = (student['accuracy'] ?? '0%').toString();
                          final cleanAcc = double.tryParse(accStr.replaceAll('%', '').trim()) ?? 0.0;
                          final Color accColor = cleanAcc >= 75.0
                              ? const Color(0xFF10B981)
                              : (cleanAcc >= 50.0
                                  ? const Color(0xFF2563EB)
                                  : (cleanAcc > 0.0 ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8)));

                          String tierLabel;
                          Color tierColor;
                          if (rank == 1) {
                            tierLabel = '🏆 Champion';
                            tierColor = const Color(0xFFF59E0B);
                          } else if (rank <= 3) {
                            tierLabel = '🥇 Top Merit';
                            tierColor = const Color(0xFF7C3AED);
                          } else if (cleanAcc >= 75.0) {
                            tierLabel = '⭐ Distinction';
                            tierColor = const Color(0xFF10B981);
                          } else if (cleanAcc >= 50.0) {
                            tierLabel = '🎖️ First Class';
                            tierColor = const Color(0xFF2563EB);
                          } else {
                            tierLabel = '📚 Aspirant';
                            tierColor = const Color(0xFF64748B);
                          }

                          final rawDate = student['last_active_at'] ?? student['created_at'];
                          String activeDateStr = 'Active';
                          if (rawDate != null) {
                            try {
                              final dt = DateTime.parse(rawDate.toString()).toLocal();
                              final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                              activeDateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
                            } catch (_) {}
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFF1F5F9),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // # Rank
                                SizedBox(
                                  width: 40,
                                  child: _buildRankBadge(rank),
                                ),

                                // User Avatar + Name + Username
                                Expanded(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: avatarColor,
                                        child: Text(
                                          (student['first_name'] ?? 'U')[0].toUpperCase(),
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student['first_name'] ?? 'Student',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '@${student['username'] ?? 'user'}',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: const Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Total Score
                                SizedBox(
                                  width: 105,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${student['total_score'] ?? 0}',
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        'marks pts',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          color: const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Tests Completed
                                SizedBox(
                                  width: 80,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${student['tests_completed'] ?? 0}',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                      Text(
                                        'attempts',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Accuracy with Linear Visual Meter
                                SizedBox(
                                  width: 130,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          accStr,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: accColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: cleanAcc <= 0 ? 0.0 : (cleanAcc / 100.0).clamp(0.0, 1.0),
                                            minHeight: 4,
                                            backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                            valueColor: AlwaysStoppedAnimation<Color>(accColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Merit Tier Badge
                                SizedBox(
                                  width: 125,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: tierColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: tierColor.withValues(alpha: 0.25)),
                                      ),
                                      child: Text(
                                        tierLabel,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: tierColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),

                                // Trending Indicator
                                SizedBox(
                                  width: 80,
                                  child: Row(
                                    children: [
                                      Icon(
                                        isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                        size: 13,
                                        color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        trendingText,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Last Active
                                SizedBox(
                                  width: 105,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        activeDateStr,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        ),
                                      ),
                                      Text(
                                        'Verified',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: const Color(0xFF10B981),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Actions
                                SizedBox(
                                  width: 165,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: const Size(0, 30),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                        ),
                                        onPressed: () => _openStudentDetailsModal(student),
                                        child: Text(
                                          'View Profile',
                                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.mail_outline_rounded, size: 17, color: Color(0xFF2563EB)),
                                          tooltip: 'Send Telegram Message',
                                          onPressed: () => _showSendMessageDialog(student),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      SizedBox(
                                        width: 24,
                                        height: 28,
                                        child: PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          onSelected: (val) {
                                            if (val == 'msg') _showSendMessageDialog(student);
                                            if (val == 'copy') {
                                              Clipboard.setData(ClipboardData(text: student['user_id']?.toString() ?? ''));
                                              widget.onShowToast('Candidate ID copied! 📋');
                                            }
                                            if (val == 'verify') widget.onShowToast('Candidate merit authenticated! 🏅');
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(value: 'msg', child: Text('Send Telegram Message')),
                                            const PopupMenuItem(value: 'copy', child: Text('Copy Telegram User ID')),
                                            const PopupMenuItem(value: 'verify', child: Text('Verify Exam Submissions')),
                                          ],
                                        ),
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

          // Pagination Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${startIndex + 1} to $endIndex of ${displayList.length} users',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    ),
                    const SizedBox(width: 4),
                    _paginationBtn('1', _currentPage == 1, () => setState(() => _currentPage = 1)),
                    if (totalPages >= 2) _paginationBtn('2', _currentPage == 2, () => setState(() => _currentPage = 2)),
                    if (totalPages >= 3) _paginationBtn('3', _currentPage == 3, () => setState(() => _currentPage = 3)),
                    if (totalPages >= 4) _paginationBtn('4', _currentPage == 4, () => setState(() => _currentPage = 4)),
                    if (totalPages >= 5) _paginationBtn('5', _currentPage == 5, () => setState(() => _currentPage = 5)),
                    if (totalPages > 5) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('...', style: TextStyle(color: Color(0xFF94A3B8))),
                      ),
                      _paginationBtn('$totalPages', _currentPage == totalPages, () => setState(() => _currentPage = totalPages)),
                    ],
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
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

  Widget _colHeader(String title, double width, {Alignment alignment = Alignment.centerLeft}) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignment,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _dropdownPill(String current, List<String> options, Function(String) onSelect, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(current) ? current : options.first,
          isDense: true,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF334155),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
          items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
          onChanged: (val) {
            if (val != null) onSelect(val);
          },
        ),
      ),
    );
  }

  Widget _paginationBtn(String label, bool isActive, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // RIGHT SIDE PANELS: SUBJECT PERFORMERS + TRENDS + RECENT SCORES
  // =========================================================================

  Widget _buildRightSidePanels(bool isDark) {
    return Column(
      children: [
        // Panel 1: Top Performers by Subject
        _buildSubjectPerformersCard(isDark),
        const SizedBox(height: 20),

        // Panel 2: Performance Trends Chart
        _buildPerformanceTrendsCard(isDark),
        const SizedBox(height: 20),

        // Panel 3: Recent Top Scores
        _buildRecentTopScoresCard(isDark),
      ],
    );
  }

  Widget _buildSubjectPerformersCard(bool isDark) {
    final subjects = _subjectPerformers.keys.isNotEmpty
        ? _subjectPerformers.keys.toList()
        : ['Science', 'BPSC TRE 4.0', 'General Knowledge', 'Mathematics'];
    if (!subjects.contains(_selectedSubject) && subjects.isNotEmpty) {
      _selectedSubject = subjects.first;
    }
    final performers = (_subjectPerformers[_selectedSubject] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                  const Icon(Icons.adjust_rounded, size: 18, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Text(
                    'Top Performers by Subject',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111B35),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onShowToast('Viewing all subject merit lists'),
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Subject Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: subjects.map((subj) {
                final isSelected = _selectedSubject == subj;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _selectedSubject = subj),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5B3DF5).withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF5B3DF5) : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        subj,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF5B3DF5) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Performers Ranked List
          if (performers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No attempts recorded yet for $_selectedSubject',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...performers.map((p) {
              final rank = p['rank'] ?? 1;
            final name = p['name'] ?? 'Candidate';
            final score = p['score'] ?? '95%';
            final avatarColor = _getAvatarColor(rank);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: _buildRankBadge(rank),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: avatarColor,
                    child: Text(
                      name[0].toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Text(
                    score,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPerformanceTrendsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                  const Icon(Icons.show_chart_rounded, size: 18, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(
                    'Performance Trends',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111B35),
                    ),
                  ),
                ],
              ),
              const Icon(Icons.open_in_full_rounded, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            children: [
              _legendDot(const Color(0xFF7C3AED), 'Avg. Score (%)'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF06B6D4), 'Tests Attempted'),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Painted Chart
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _DualTrendChartPainter(isDark: isDark, trends: _performanceTrends),
            ),
          ),
          const SizedBox(height: 6),
          // Dates Axis
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['1 Oct', '8 Oct', '15 Oct', '22 Oct', '31 Oct'].map((d) {
              return Text(
                d,
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildRecentTopScoresCard(bool isDark) {
    final recentScores = _recentTopScores;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                  const Icon(Icons.star_rounded, size: 18, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Top Scores',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111B35),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onShowToast('Displaying real-time examination results'),
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Subheader
          Row(
            children: [
              Expanded(flex: 3, child: Text('User', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)))),
              Expanded(flex: 4, child: Text('Test Title', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)))),
              Expanded(flex: 2, child: Text('Score', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)))),
              Expanded(flex: 2, child: Text('Date', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)), textAlign: TextAlign.right)),
            ],
          ),
          const SizedBox(height: 8),

          if (recentScores.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No test scores recorded yet', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
              ),
            )
          else
            ...recentScores.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final avatarColor = _getAvatarColor(idx);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // User
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: avatarColor,
                          child: Text(
                            (item['user'] ?? 'U')[0].toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item['user'] ?? 'Student',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Test Title
                  Expanded(
                    flex: 4,
                    child: Text(
                      item['testTitle'] ?? 'General Test',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Score
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['score'] ?? '100/100',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                    ),
                  ),
                  // Date
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['date'] ?? '16 Oct',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Custom Dual Trend Chart Painter
class _DualTrendChartPainter extends CustomPainter {
  final bool isDark;
  final List<dynamic>? trends;
  _DualTrendChartPainter({required this.isDark, this.trends});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw background grid lines
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = h * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Cyan curve: Tests Attempted (normalized from 0.85h to 0.25h)
    final cyanPath = Path();
    cyanPath.moveTo(0, h * 0.82);
    cyanPath.cubicTo(w * 0.25, h * 0.78, w * 0.45, h * 0.65, w * 0.55, h * 0.55);
    cyanPath.cubicTo(w * 0.75, h * 0.45, w * 0.88, h * 0.35, w, h * 0.25);

    // Cyan area gradient
    final cyanArea = Path.from(cyanPath);
    cyanArea.lineTo(w, h);
    cyanArea.lineTo(0, h);
    cyanArea.close();

    final cyanGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF06B6D4).withValues(alpha: 0.25),
        const Color(0xFF06B6D4).withValues(alpha: 0.0),
      ],
    );
    canvas.drawPath(cyanArea, Paint()..shader = cyanGradient.createShader(Rect.fromLTWH(0, 0, w, h)));

    final cyanLinePaint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(cyanPath, cyanLinePaint);

    // Purple curve: Avg Score % (normalized from 0.7h to 0.15h)
    final purplePath = Path();
    purplePath.moveTo(0, h * 0.68);
    purplePath.cubicTo(w * 0.25, h * 0.60, w * 0.45, h * 0.48, w * 0.55, h * 0.38);
    purplePath.cubicTo(w * 0.75, h * 0.28, w * 0.88, h * 0.20, w, h * 0.12);

    final purpleLinePaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(purplePath, purpleLinePaint);

    // Data dots on purple curve
    final dotPoints = [
      Offset(0, h * 0.68),
      Offset(w * 0.25, h * 0.60),
      Offset(w * 0.50, h * 0.42),
      Offset(w * 0.75, h * 0.28),
      Offset(w, h * 0.12),
    ];

    for (final pt in dotPoints) {
      canvas.drawCircle(pt, 4.5, Paint()..color = const Color(0xFF7C3AED));
      canvas.drawCircle(pt, 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
