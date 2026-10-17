import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';

class BattlesTab extends StatefulWidget {
  final List<dynamic> groups;
  final List<dynamic> quizzes;
  final ApiService api;
  final TelegramService tg;
  final bool isDark;
  final Future<void> Function() onRefreshAll;
  final Function(String msg, {bool isError}) onShowToast;
  final Function(String quizId, String groupTitle) onLaunchQuiz;

  const BattlesTab({
    super.key,
    required this.groups,
    required this.quizzes,
    required this.api,
    required this.tg,
    required this.isDark,
    required this.onRefreshAll,
    required this.onShowToast,
    required this.onLaunchQuiz,
  });

  @override
  State<BattlesTab> createState() => _BattlesTabState();
}

class _BattlesTabState extends State<BattlesTab> {
  ApiService get _api => widget.api;
  TelegramService get _tg => widget.tg;
  List<dynamic> get _groups => widget.groups;
  List<dynamic> get _quizzes => widget.quizzes;

  void _showToast(String msg, {bool isError = false}) => widget.onShowToast(msg, isError: isError);
  Future<void> _loadAllData() => widget.onRefreshAll();

  Future<void> _cancelGroupSchedulePrompt(dynamic groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Scheduled Exam?'),
        content: const Text('Are you sure you want to cancel the scheduled battle for this community?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Schedule')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Exam', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final res = await _api.cancelGroupSchedule(groupId.toString());
      if (res['success'] == true) {
        _showToast('Scheduled battle cancelled.');
        _loadAllData();
      } else {
        _showToast(res['error'] ?? 'Cancellation failed', isError: true);
      }
    }
  }

  Future<void> _deleteGroupPrompt(dynamic g) async {
    final groupId = g is Map ? (g['group_id']?.toString() ?? '') : g.toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Community?'),
        content: const Text('Are you sure you want to remove authorization for this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final res = await _api.deleteGroup(groupId);
      if (res['success'] == true) {
        _showToast('Community authorization removed.');
        _loadAllData();
      } else {
        _showToast(res['error'] ?? 'Removal failed', isError: true);
      }
    }
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
          backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
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
                    value: selectedQuizId,
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
                      value: delayMinutes,
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
                  _showToast('Battle scheduled successfully! 🎯 Countdown dispatched.');
                  _loadAllData();
                } else {
                  _showToast(res['error'] ?? 'Scheduling failed', isError: true);
                }
              },
              child: const Text('Confirm Schedule', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      onPressed: _openAuthorizeGroupDialog,
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
                  onPressed: _openAuthorizeGroupDialog,
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
                    onPressed: () => widget.onLaunchQuiz(
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

  void _openAuthorizeGroupDialog() {
    final groupCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
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
  }
}
