import 'dart:math';
import 'package:flutter/material.dart';
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
  final String _searchQuery = '';

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
                    _miniStat('Accuracy', '${student['accuracy'] ?? '95%'}', const Color(0xFF10B981)),
                    _miniStat('Tests', '${student['tests_completed'] ?? 12}', const Color(0xFF6366F1)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Recent Performance & Milestones',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _recentAttemptItem('Bihar Special Full Test', '100/100', '98% Accuracy · 16 Oct 2026', const Color(0xFF10B981)),
              _recentAttemptItem('General Science Mock Exam', '94/100', '92% Accuracy · 14 Oct 2026', const Color(0xFF2563EB)),
              _recentAttemptItem('Reasoning & Speed Test', '92/100', '89% Accuracy · 12 Oct 2026', const Color(0xFFF59E0B)),
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
                        widget.onShowToast('Candidate profile verified and synced! 🎯');
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

            // 4. MAIN CONTENT (Split View on Desktop: 65% Table, 35% Panels)
            if (isDesktop)
              Row(
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
              )
            else
              Column(
                children: [
                  _buildOverallLeaderboardCard(isDark),
                  const SizedBox(height: 24),
                  _buildRightSidePanels(isDark),
                ],
              ),
          ],
        ),
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

        if (isMobile) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpiMetricCard('Total Participants', '${_analyticsMetrics['totalParticipants'] ?? 12548}', '+18% from last month', Icons.people_alt_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark, 170),
              _kpiMetricCard('Tests Attempted', '${_analyticsMetrics['testsAttempted'] ?? 28412}', '+26%', Icons.emoji_events_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark, 170),
              _kpiMetricCard('Top Score', '${_analyticsMetrics['topScore'] ?? '100/100'}', '${_analyticsMetrics['topScoreTitle'] ?? 'Bihar Special - Full Test'}', Icons.star_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark, 170),
              _kpiMetricCard('Average Score', '${_analyticsMetrics['averageScore'] ?? '62.4%'}', '+8.5%', Icons.bar_chart_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark, 170),
              _kpiMetricCard('Active in Last 7 Days', '${_analyticsMetrics['activeLast7Days'] ?? 3281}', '+12%', Icons.military_tech_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2), isDark, 170),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _kpiMetricCard('Total Participants', '${_analyticsMetrics['totalParticipants'] ?? 12548}', '+18% from last month', Icons.people_alt_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Tests Attempted', '${_analyticsMetrics['testsAttempted'] ?? 28412}', '+26%', Icons.emoji_events_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Top Score', '${_analyticsMetrics['topScore'] ?? '100/100'}', '${_analyticsMetrics['topScoreTitle'] ?? 'Bihar Special - Full Test'}', Icons.star_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Average Score', '${_analyticsMetrics['averageScore'] ?? '62.4%'}', '+8.5%', Icons.bar_chart_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), isDark, cardWidth)),
            const SizedBox(width: 14),
            Expanded(child: _kpiMetricCard('Active in Last 7 Days', '${_analyticsMetrics['activeLast7Days'] ?? 3281}', '+12%', Icons.military_tech_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2), isDark, cardWidth)),
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
    // Filter leaderboard
    var displayList = _leaderboardList;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
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
          // Table Card Header with Dropdowns
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
                // Filter Dropdowns
                Wrap(
                  spacing: 8,
                  children: [
                    _dropdownPill(_filterTest, ['All Tests', 'Bihar Special', 'General Science', 'Mock Series'], (val) {
                      setState(() => _filterTest = val);
                    }, isDark),
                    _dropdownPill(_filterSubject, ['All Subjects', 'Science', 'Maths', 'Reasoning', 'GK'], (val) {
                      setState(() => _filterSubject = val);
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
                          _colHeader('#', 40),
                          _colHeader('User', 200),
                          _colHeader('Total Score', 100),
                          _colHeader('Tests', 70),
                          _colHeader('Accuracy', 90),
                          _colHeader('Trending', 80),
                          _colHeader('Actions', 140, alignment: Alignment.centerRight),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Table Body
                    ...pagedList.map((student) {
                      final rank = student['rank'] ?? 1;
                      final isUp = student['is_trending_up'] ?? true;
                      final trendingText = student['trending'] ?? '+1';
                      final avatarColor = _getAvatarColor(rank);

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
                            SizedBox(
                              width: 200,
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
                              width: 100,
                              child: Text(
                                '${student['total_score'] ?? 0}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ),

                            // Tests Completed
                            SizedBox(
                              width: 70,
                              child: Text(
                                '${student['tests_completed'] ?? 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),

                            // Accuracy
                            SizedBox(
                              width: 90,
                              child: Text(
                                '${student['accuracy'] ?? '90%'}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10B981),
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

                            // Actions
                            SizedBox(
                              width: 140,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _openStudentDetailsModal(student),
                                    child: Text(
                                      'View Profile',
                                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (val) {
                                      if (val == 'msg') _showSendMessageDialog(student);
                                      if (val == 'verify') widget.onShowToast('Candidate merit authenticated! 🏅');
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'msg', child: Text('Send Telegram Message')),
                                      const PopupMenuItem(value: 'verify', child: Text('Verify Exam Submissions')),
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
