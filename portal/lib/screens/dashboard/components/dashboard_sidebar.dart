import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/telegram_service.dart';
import '../../../widgets/user_avatar.dart';

class DashboardSidebar extends StatelessWidget {
  final int selectedNav;
  final Function(int index) onSelectNav;
  final Map<String, dynamic> stats;
  final int usersCount;
  final int quizzesCount;
  final int foldersCount;
  final int groupsCount;
  final int leaderboardCount;
  final String adminName;
  final String adminUsername;
  final String adminId;
  final String? adminPhotoUrl;
  final VoidCallback onLogout;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenCommands;
  final VoidCallback onOpenActivities;
  final Function(String msg) onToast;
  final TelegramService tg;
  final bool isCollapsed;

  const DashboardSidebar({
    super.key,
    required this.selectedNav,
    required this.onSelectNav,
    required this.stats,
    required this.usersCount,
    required this.quizzesCount,
    required this.foldersCount,
    required this.groupsCount,
    required this.leaderboardCount,
    required this.adminName,
    required this.adminUsername,
    required this.adminId,
    required this.adminPhotoUrl,
    required this.onLogout,
    required this.onOpenPayments,
    required this.onOpenCommands,
    required this.onOpenActivities,
    required this.onToast,
    required this.tg,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isCollapsed ? 70 : 255,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1424),
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand Header
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: isCollapsed
                ? Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.smart_toy_rounded, size: 22, color: Colors.white),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.smart_toy_rounded, size: 22, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Examplayer',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('👑', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                            Text(
                              'ENTERPRISE 2026',
                              style: GoogleFonts.inter(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF818CF8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _sidebarSectionHeader('CORE OPERATIONS'),
                _sidebarItem(context, icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0),
                _sidebarItem(context, icon: Icons.people_alt_outlined, title: 'Users', index: 3, badge: '$usersCount'),
                _sidebarItem(context, icon: Icons.assignment_outlined, title: 'Tests & Questions', index: 2, badge: '$quizzesCount'),
                _sidebarItem(context, icon: Icons.folder_outlined, title: 'Folders & Hierarchy', index: 1, badge: '$foldersCount'),
                _sidebarItem(context, icon: Icons.campaign_outlined, title: 'Broadcast Studio', index: 7, badge: 'New', isBlueBadge: true),
                _sidebarItem(context, icon: Icons.groups_outlined, title: 'Groups & Communities', index: 6, badge: '$groupsCount'),
                _sidebarItem(context, icon: Icons.emoji_events_outlined, title: 'Leaderboards & Merit', index: 4, badge: '$leaderboardCount'),

                const SizedBox(height: 8),
                _sidebarSectionHeader('MONETIZATION & SYSTEM'),
                _sidebarItem(context, icon: Icons.credit_card_outlined, title: 'Payments & Plans', index: 9),
                _sidebarItem(context, icon: Icons.tune_rounded, title: 'Commands', index: 102, badge: '12'),
                _sidebarItem(context, icon: Icons.bar_chart_rounded, title: 'Analytics', index: 103),
                _sidebarItem(context, icon: Icons.shield_outlined, title: 'Logs & Activities', index: 104),
                _sidebarItem(context, icon: Icons.manage_accounts_outlined, title: 'Admins Hub', index: 5),
                _sidebarItem(context, icon: Icons.settings_outlined, title: 'Bot Settings', index: 8),
              ],
            ),
          ),

          // User Profile Pill & Logout
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: isCollapsed
                ? Center(
                    child: Tooltip(
                      message: '$adminName (@$adminUsername)',
                      child: UserAvatar(
                        userId: adminId,
                        name: 'ST',
                        radius: 17,
                        isRootAdmin: true,
                        customUrl: adminPhotoUrl,
                        showBadge: false,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      UserAvatar(
                        userId: adminId,
                        name: 'ST',
                        radius: 17,
                        isRootAdmin: true,
                        customUrl: adminPhotoUrl,
                        showBadge: false,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adminName,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '@$adminUsername',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, size: 17, color: Color(0xFFEF4444)),
                        tooltip: 'Logout',
                        onPressed: onLogout,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarSectionHeader(String title) {
    if (isCollapsed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Divider(color: Color(0xFF1E293B), height: 12, thickness: 1, indent: 14, endIndent: 14),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF64748B),
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _sidebarItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
    String? badge,
    bool isBlueBadge = false,
    bool closeDrawerOnTap = false,
  }) {
    final isSelected = selectedNav == index;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Tooltip(
          message: title,
          waitDuration: const Duration(milliseconds: 200),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                tg.hapticImpact('light');
                if (index == 101) {
                  onOpenPayments();
                } else if (index == 102) {
                  onOpenCommands();
                } else if (index == 103) {
                  onSelectNav(0);
                  onToast('Viewing Platform Analytics');
                } else if (index == 104) {
                  onOpenActivities();
                } else {
                  onSelectNav(index);
                }
              },
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected ? Border.all(color: const Color(0xFF334155), width: 1) : null,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            tg.hapticImpact('light');
            if (closeDrawerOnTap) {
              Navigator.of(context).pop();
            }
            if (index == 101) {
              onOpenPayments();
            } else if (index == 102) {
              onOpenCommands();
            } else if (index == 103) {
              onSelectNav(0);
              onToast('Viewing Platform Analytics');
            } else if (index == 104) {
              onOpenActivities();
            } else {
              onSelectNav(index);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: const Color(0xFF334155), width: 1) : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isBlueBadge
                          ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isBlueBadge ? const Color(0xFF3B82F6) : const Color(0xFF334155),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isBlueBadge ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
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
}

class DashboardMobileDrawer extends StatelessWidget {
  final int selectedNav;
  final Function(int index) onSelectNav;
  final int usersCount;
  final int quizzesCount;
  final int foldersCount;
  final int groupsCount;
  final int leaderboardCount;
  final String adminName;
  final String adminUsername;
  final String adminId;
  final String? adminPhotoUrl;
  final VoidCallback onLogout;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenCommands;
  final VoidCallback onOpenActivities;
  final Function(String msg) onToast;
  final TelegramService tg;

  const DashboardMobileDrawer({
    super.key,
    required this.selectedNav,
    required this.onSelectNav,
    required this.usersCount,
    required this.quizzesCount,
    required this.foldersCount,
    required this.groupsCount,
    required this.leaderboardCount,
    required this.adminName,
    required this.adminUsername,
    required this.adminId,
    required this.adminPhotoUrl,
    required this.onLogout,
    required this.onOpenPayments,
    required this.onOpenCommands,
    required this.onOpenActivities,
    required this.onToast,
    required this.tg,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1424),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Examplayer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(width: 4),
                          const Text('👑', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                      Text('ENTERPRISE 2026', style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFF818CF8))),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                    tooltip: 'Close Navigation',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(context, icon: Icons.dashboard_rounded, title: 'Dashboard', index: 0),
                  _drawerItem(context, icon: Icons.people_alt_outlined, title: 'Users', index: 3, badge: '$usersCount'),
                  _drawerItem(context, icon: Icons.assignment_outlined, title: 'Tests & Questions', index: 2, badge: '$quizzesCount'),
                  _drawerItem(context, icon: Icons.folder_outlined, title: 'Folders & Hierarchy', index: 1, badge: '$foldersCount'),
                  _drawerItem(context, icon: Icons.campaign_outlined, title: 'Broadcast Studio', index: 7, badge: 'New', isBlueBadge: true),
                  _drawerItem(context, icon: Icons.groups_outlined, title: 'Groups & Communities', index: 6, badge: '$groupsCount'),
                  _drawerItem(context, icon: Icons.emoji_events_outlined, title: 'Leaderboards & Merit', index: 4, badge: '$leaderboardCount'),
                  _drawerItem(context, icon: Icons.credit_card_outlined, title: 'Payments & Plans', index: 9),
                  _drawerItem(context, icon: Icons.tune_rounded, title: 'Commands', index: 102, badge: '12'),
                  _drawerItem(context, icon: Icons.bar_chart_rounded, title: 'Analytics', index: 103),
                  _drawerItem(context, icon: Icons.shield_outlined, title: 'Logs & Activities', index: 104),
                  _drawerItem(context, icon: Icons.manage_accounts_outlined, title: 'Admins Hub', index: 5),
                  _drawerItem(context, icon: Icons.settings_outlined, title: 'Bot Settings', index: 8),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    userId: adminId,
                    name: 'ST',
                    radius: 16,
                    isRootAdmin: true,
                    customUrl: adminPhotoUrl,
                    showBadge: false,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(adminName, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('@$adminUsername', style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 17, color: Color(0xFFEF4444)),
                    tooltip: 'Logout',
                    onPressed: () {
                      Navigator.of(context).pop();
                      onLogout();
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

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
    String? badge,
    bool isBlueBadge = false,
  }) {
    final isSelected = selectedNav == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            tg.hapticImpact('light');
            Navigator.of(context).pop();
            if (index == 101) {
              onOpenPayments();
            } else if (index == 102) {
              onOpenCommands();
            } else if (index == 103) {
              onSelectNav(0);
              onToast('Viewing Platform Analytics');
            } else if (index == 104) {
              onOpenActivities();
            } else {
              onSelectNav(index);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 19, color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isBlueBadge ? const Color(0xFF2563EB).withValues(alpha: 0.3) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isBlueBadge ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
