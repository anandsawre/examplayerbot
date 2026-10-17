import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/telegram_service.dart';

class DashboardDialogs {
  /// VIP Passes & Monetization tier selector dialog
  static void openPaymentsPlansDialog(
    BuildContext context, {
    required bool isDark,
    required Function(int) onNavigateNav,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 20),
            ),
            const SizedBox(width: 12),
            Text('VIP Passes & Monetization', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _planCard('Free Student Tier', '₹0', 'Standard question catalog, basic ranks, public bot commands', Icons.school_outlined, const Color(0xFF64748B), isDark),
              const SizedBox(height: 10),
              _planCard('VIP Pass Tier', '₹199 / mo', 'Full access to premium test series, detailed solutions, private battle rooms', Icons.workspace_premium_rounded, const Color(0xFFD97706), isDark),
              const SizedBox(height: 10),
              _planCard('Enterprise Coaching Pass', '₹999 / yr', 'Unlimited community group battles, branded PDF reports, instant bulk pass issuance', Icons.business_center_rounded, const Color(0xFF2563EB), isDark),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () {
              Navigator.pop(ctx);
              onNavigateNav(3);
            },
            child: const Text('Manage User Passes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static Widget _planCard(String name, String price, String desc, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    Text(price, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive Bot Commands quick reference dialog
  static void openCommandsOverviewDialog(
    BuildContext context, {
    required bool isDark,
    required TelegramService tg,
    required Function(String) showToast,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.code_rounded, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 12),
            Text('Bot Commands Directory', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _commandDialogItem(context, '/start', 'Initial bot launch & language selection', '8,912 runs', const Color(0xFF3B82F6), isDark, tg, showToast),
              _commandDialogItem(context, '/quiz', 'Start an interactive test or mock exam', '6,120 runs', const Color(0xFF10B981), isDark, tg, showToast),
              _commandDialogItem(context, '/help', 'Bot commands guide & troubleshooting', '4,856 runs', const Color(0xFFF59E0B), isDark, tg, showToast),
              _commandDialogItem(context, '/notes', 'Browse syllabus notes and study material', '3,421 runs', const Color(0xFF8B5CF6), isDark, tg, showToast),
              _commandDialogItem(context, '/test', 'Quick test selector & category filter', '2,987 runs', const Color(0xFF06B6D4), isDark, tg, showToast),
              _commandDialogItem(context, '/currentaffairs', 'Daily & monthly current affairs quizzes', '2,301 runs', const Color(0xFFF43F5E), isDark, tg, showToast),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  static Widget _commandDialogItem(
    BuildContext context,
    String cmd,
    String desc,
    String runs,
    Color color,
    bool isDark,
    TelegramService tg,
    Function(String) showToast,
  ) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: cmd));
        tg.hapticImpact('light');
        showToast('Copied $cmd to clipboard');
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(cmd, style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(desc, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)))),
            Text(runs, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  /// Recent Activities dialog with dynamic log entries
  static void openRecentActivitiesDialog(
    BuildContext context, {
    required bool isDark,
    required List<dynamic> users,
    required List<dynamic> quizzes,
    required List<dynamic> groups,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.history_rounded, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 12),
            Text('Recent Activity Logs', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _recentItem(
                icon: Icons.person_outline_rounded,
                iconBg: const Color(0xFFCCFBF1),
                iconColor: const Color(0xFF0D9488),
                text: users.isNotEmpty
                    ? 'New student joined: @${users.first['username'] ?? users.first['first_name'] ?? 'Candidate'}'
                    : 'New student registered: @candidate',
                time: 'Just now',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _recentItem(
                icon: Icons.assignment_outlined,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
                text: quizzes.isNotEmpty ? 'Exam live: ${quizzes.first['title'] ?? 'Mock Test'}' : 'Exam published: General Studies',
                time: '5 min ago',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _recentItem(
                icon: Icons.sports_esports_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                text: groups.isNotEmpty ? 'Battle ready in: ${groups.first['title'] ?? 'Study Group'}' : 'Announcement broadcast studio active',
                time: '12 min ago',
                isDark: isDark,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  static Widget _recentItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String text,
    required String time,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  /// Global Search Modal Dialog
  static void openSearchDialog(
    BuildContext context, {
    required bool isDark,
    required Function(int) onNavigateNav,
    required VoidCallback onOpenCommands,
  }) {
    final searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(20),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    hintText: 'Search users, tests, folders, commands...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setDlgState(() => searchCtrl.clear()),
                    ),
                  ),
                  onChanged: (_) => setDlgState(() {}),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.quiz_outlined, size: 14),
                      label: const Text('Tests', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onNavigateNav(2);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.people_alt_outlined, size: 14),
                      label: const Text('Users', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onNavigateNav(3);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.folder_outlined, size: 14),
                      label: const Text('Folders', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onNavigateNav(1);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.tune_rounded, size: 14),
                      label: const Text('Commands', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onOpenCommands();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
