import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/user_avatar.dart';

class DashboardTopNavbar extends StatelessWidget {
  final bool isDesktop;
  final bool isDark;
  final String adminName;
  final String adminUsername;
  final String adminId;
  final String? adminPhotoUrl;
  final VoidCallback onOpenDrawer;
  final VoidCallback? onToggleSidebar;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenActivities;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;
  final Function(int) onSelectNav;
  final Function(String msg) onToast;
  final TelegramService tg;

  const DashboardTopNavbar({
    super.key,
    required this.isDesktop,
    required this.isDark,
    required this.adminName,
    required this.adminUsername,
    required this.adminId,
    required this.adminPhotoUrl,
    required this.onOpenDrawer,
    this.onToggleSidebar,
    required this.onOpenSearch,
    required this.onOpenActivities,
    required this.onToggleTheme,
    required this.onLogout,
    required this.onSelectNav,
    required this.onToast,
    required this.tg,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      // Mobile Top Navbar (Clean, 64px, never overflows)
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBg : Colors.white,
          border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 24),
              tooltip: 'Open Menu',
              onPressed: onOpenDrawer,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: InkWell(
                onTap: onOpenSearch,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, size: 17, color: Color(0xFF94A3B8)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Search...',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
              tooltip: 'Toggle Theme',
              onPressed: onToggleTheme,
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.notifications_outlined, size: 20),
                  tooltip: 'Notifications',
                  onPressed: onOpenActivities,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    child: const Center(
                      child: Text('5', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Desktop Top Navbar exactly matching image
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white70 : const Color(0xFF64748B), size: 22),
            tooltip: 'Toggle Sidebar',
            onPressed: onToggleSidebar ?? onOpenDrawer,
          ),
          const SizedBox(width: 10),

          // Search Pill
          InkWell(
            onTap: onOpenSearch,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 380,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search users, tests, messages, commands... (Ctrl + K)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Telegram Handle Pill
          InkWell(
            onTap: () {
              tg.openTelegramLink('https://t.me/Examplayer_bot');
              onToast('Opening @Examplayer_bot');
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0284C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.send_rounded, size: 11, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '@Examplayer_bot',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Theme Mode Switch
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
            tooltip: 'Toggle Theme',
            onPressed: onToggleTheme,
          ),
          const SizedBox(width: 4),

          // Notifications with Badge "5"
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
                tooltip: 'Notifications',
                onPressed: onOpenActivities,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '5',
                      style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Admin User Profile Dropdown Pill
          PopupMenuButton<String>(
            tooltip: 'Admin Profile',
            offset: const Offset(0, 48),
            onSelected: (val) {
              if (val == 'settings') {
                onSelectNav(8);
              } else if (val == 'logout') {
                onLogout();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 16),
                    const SizedBox(width: 8),
                    Text('Logged in as $adminName', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Platform Settings', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
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
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminName,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
