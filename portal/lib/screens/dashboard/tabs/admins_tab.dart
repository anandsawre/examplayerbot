import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/user_avatar.dart';

class AdminsTab extends StatefulWidget {
  final List<dynamic> admins;
  final ApiService api;
  final TelegramService tg;
  final bool isDark;
  final Future<void> Function() onRefreshAll;
  final Function(String msg, {bool isError}) onShowToast;

  const AdminsTab({
    super.key,
    required this.admins,
    required this.api,
    required this.tg,
    required this.isDark,
    required this.onRefreshAll,
    required this.onShowToast,
  });

  @override
  State<AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<AdminsTab> {
  ApiService get _api => widget.api;
  List<dynamic> get _admins => widget.admins;

  void _showToast(String msg, {bool isError = false}) => widget.onShowToast(msg, isError: isError);
  Future<void> _loadAllData() => widget.onRefreshAll();

  Future<void> _appointAdminDialog() async {
    final idCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkSurface : Colors.white,
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
                _showToast(res['error'] ?? 'Appointment failed', isError: true);
              }
            },
            child: const Text('Appoint Admin', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
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
        Card(
          color: isDark ? AppTheme.darkCard : Colors.white,
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
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
                                    border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0))),
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
                                                      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                      title: const Text('Revoke Administrator?'),
                                                      content: Text('Are you sure you want to revoke admin privileges from ${adm['name'] ?? admId}?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: const Text('Revoke Privileges', style: TextStyle(color: Colors.white)),
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
}
