import 'package:flutter/material.dart';

/// Reusable status badge with colored indicator dot and pastel background
class StatusBadge extends StatelessWidget {
  final String label;
  final Color dotColor;
  final Color bgColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.dotColor,
    required this.bgColor,
    required this.textColor,
  });

  factory StatusBadge.published() {
    return const StatusBadge(
      label: 'Published',
      dotColor: Color(0xFF10B981),
      bgColor: Color(0xFFDCFCE7),
      textColor: Color(0xFF15803D),
    );
  }

  factory StatusBadge.draft() {
    return const StatusBadge(
      label: 'Draft',
      dotColor: Color(0xFFF59E0B),
      bgColor: Color(0xFFFEF3C7),
      textColor: Color(0xFFB45309),
    );
  }

  factory StatusBadge.active() {
    return const StatusBadge(
      label: 'Active',
      dotColor: Color(0xFF10B981),
      bgColor: Color(0xFFECFDF5),
      textColor: Color(0xFF047857),
    );
  }

  factory StatusBadge.inactive() {
    return const StatusBadge(
      label: 'Inactive',
      dotColor: Color(0xFF94A3B8),
      bgColor: Color(0xFFF1F5F9),
      textColor: Color(0xFF64748B),
    );
  }

  factory StatusBadge.blocked() {
    return const StatusBadge(
      label: 'Blocked',
      dotColor: Color(0xFFEF4444),
      bgColor: Color(0xFFFEF2F2),
      textColor: Color(0xFFB91C1C),
    );
  }

  factory StatusBadge.vip() {
    return const StatusBadge(
      label: 'PRO VIP',
      dotColor: Color(0xFF8B5CF6),
      bgColor: Color(0xFFF5F3FF),
      textColor: Color(0xFF6D28D9),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
