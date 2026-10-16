import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String userId;
  final String name;
  final double radius;
  final bool isPremium;
  final bool isRootAdmin;
  final String? customUrl;
  final bool showBadge;
  final bool showOnlineDot;

  const UserAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.radius = 16,
    this.isPremium = false,
    this.isRootAdmin = false,
    this.customUrl,
    this.showBadge = true,
    this.showOnlineDot = false,
  });

  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo - Purple
    [Color(0xFF06B6D4), Color(0xFF3B82F6)], // Cyan - Blue
    [Color(0xFF10B981), Color(0xFF059669)], // Emerald - Green
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber - Orange
    [Color(0xFFEC4899), Color(0xFFBE185D)], // Pink - Rose
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)], // Violet - Purple
    [Color(0xFF14B8A6), Color(0xFF0D9488)], // Teal
  ];

  @override
  Widget build(BuildContext context) {
    final cleanName = name.trim().isEmpty ? 'User' : name.trim();
    final initial = cleanName.substring(0, 1).toUpperCase();
    final hash = (userId.hashCode ^ cleanName.hashCode).abs();
    final gradient = _avatarGradients[hash % _avatarGradients.length];

    // Priority 1: customUrl passed directly
    // Priority 2: backend avatar proxy endpoint (now public and fast)
    final avatarUrl = customUrl ??
        (userId.isNotEmpty && userId != '0'
            ? '${ApiService().baseUrl}/users/$userId/avatar'
            : null);

    final isSpecial = isPremium || isRootAdmin;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Avatar Circle Container
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isRootAdmin
                  ? const Color(0xFFFBBF24) // Gold for Root
                  : isPremium
                      ? const Color(0xFF60A5FA) // Blue for Premium
                      : Colors.white.withValues(alpha: 0.15),
              width: isSpecial ? 2.0 : 1.2,
            ),
            boxShadow: isSpecial
                ? [
                    BoxShadow(
                      color: (isRootAdmin ? const Color(0xFFFBBF24) : const Color(0xFF60A5FA))
                          .withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: ClipOval(
            child: avatarUrl != null
                ? Image.network(
                    avatarUrl,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildInitialFallback(gradient, initial);
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitialFallback(gradient, initial);
                    },
                  )
                : _buildInitialFallback(gradient, initial),
          ),
        ),

        // Status Badge (Crown / Star)
        if (showBadge && isSpecial)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF0B101D),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isRootAdmin ? const Color(0xFFFBBF24) : const Color(0xFF60A5FA),
                  width: 1,
                ),
              ),
              child: Text(
                isRootAdmin ? '👑' : '⭐',
                style: TextStyle(fontSize: radius * 0.6),
              ),
            ),
          ),

        // Online Dot Indicator
        if (showOnlineDot && !isSpecial)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: AppTheme.emerald,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0B101D),
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitialFallback(List<Color> gradient, String initial) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: radius * 0.85,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
