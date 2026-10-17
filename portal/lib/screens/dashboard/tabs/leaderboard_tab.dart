import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/user_avatar.dart';

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
  String _leaderboardViewMode = 'global';
  String? _selectedLeaderboardQuizId;
  Map<String, dynamic> _quizLeaderboardData = {};
  bool _isGlobalLeaderboardLoading = false;
  bool _isQuizLeaderboardLoading = false;
  List<dynamic> _internalGlobalLeaderboard = [];

  ApiService get _api => widget.api;
  TelegramService get _tg => widget.tg;
  List<dynamic> get _quizzes => widget.quizzes;

  @override
  void initState() {
    super.initState();
    _internalGlobalLeaderboard = widget.globalLeaderboard;
  }

  @override
  void didUpdateWidget(covariant LeaderboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.globalLeaderboard != widget.globalLeaderboard) {
      _internalGlobalLeaderboard = widget.globalLeaderboard;
    }
  }

  Future<void> _fetchLeaderboardData() async {
    setState(() => _isGlobalLeaderboardLoading = true);
    try {
      final list = await _api.getGlobalLeaderboard();
      if (mounted) {
        setState(() {
          _internalGlobalLeaderboard = list;
          _isGlobalLeaderboardLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isGlobalLeaderboardLoading = false);
      }
    }
    await widget.onRefreshLeaderboard();
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

  Widget _kpiCard(String label, String value, String sub, IconData icon, Color color) {
    final isDark = widget.isDark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final rankedCount = _internalGlobalLeaderboard.length;
    final topper = _internalGlobalLeaderboard.isNotEmpty ? _internalGlobalLeaderboard[0] : null;
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

        Card(
          color: isDark ? AppTheme.darkCard : Colors.white,
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                    _fetchLeaderboardData();
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
                                _fetchLeaderboardData();
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

                if (_leaderboardViewMode == 'global') ...[
                  if (_isGlobalLeaderboardLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 50),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_internalGlobalLeaderboard.isEmpty)
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
                            onPressed: _fetchLeaderboardData,
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

                                ..._internalGlobalLeaderboard.asMap().entries.map((entry) {
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
                                      border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0))),
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedLeaderboardQuizId,
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
                                        border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0))),
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
          border: Border.all(color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0))),
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
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
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
}
