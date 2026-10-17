import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserGrowthChart extends StatelessWidget {
  final bool isDark;
  final double? height;
  final List<double>? dataPoints;
  final List<String>? xLabels;
  final double? maxValue;

  const UserGrowthChart({
    super.key,
    this.isDark = false,
    this.height,
    this.dataPoints,
    this.xLabels,
    this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double finalHeight = height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : 124.0);
        return SizedBox(
          width: constraints.maxWidth,
          height: finalHeight,
          child: CustomPaint(
            painter: _UserGrowthChartPainter(
              isDark: isDark,
              customDataPoints: dataPoints,
              customXLabels: xLabels,
              customMax: maxValue,
            ),
          ),
        );
      },
    );
  }
}

class _UserGrowthChartPainter extends CustomPainter {
  final bool isDark;
  final List<double>? customDataPoints;
  final List<String>? customXLabels;
  final double? customMax;

  _UserGrowthChartPainter({
    required this.isDark,
    this.customDataPoints,
    this.customXLabels,
    this.customMax,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 40.0;
    const double bottomPadding = 22.0;
    const double topPadding = 8.0;
    const double rightPadding = 14.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final gridPaint = Paint()
      ..color = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    final axisLabelStyle = GoogleFonts.inter(
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    );

    final dataPoints = customDataPoints ?? [360.0, 480.0, 620.0, 780.0, 950.0, 1120.0, 1340.0, 1720.0];
    final xLabels = customXLabels ?? ['Sep 17', 'Sep 21', 'Sep 25', 'Sep 29', 'Oct 03', 'Oct 07', 'Oct 11', 'Oct 15'];

    double maxVal = customMax ?? 2000.0;
    if (customMax == null) {
      double highest = 0;
      for (final p in dataPoints) {
        if (p > highest) highest = p;
      }
      if (highest > 0) {
        maxVal = (highest * 1.25).ceilToDouble();
      }
    }
    if (maxVal <= 0) maxVal = 100.0;

    // Y Axis levels: 4 intervals
    final step = maxVal / 4.0;
    final yValues = [maxVal, step * 3, step * 2, step, 0.0];

    for (int i = 0; i < yValues.length; i++) {
      final y = topPadding + (i * chartHeight / (yValues.length - 1));

      // Grid line
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Y Label
      final val = yValues[i];
      final labelText = val == 0
          ? '0'
          : (val >= 1000
              ? '${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}k'
              : val.toInt().toString());

      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: axisLabelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 8, y - tp.height / 2));
    }

    final List<Offset> points = [];
    final int count = min(dataPoints.length, xLabels.length);
    if (count < 2) return;

    for (int i = 0; i < count; i++) {
      final x = leftPadding + (i * chartWidth / (count - 1));
      final normalizedY = (dataPoints[i] / maxVal).clamp(0.0, 1.0);
      final y = topPadding + chartHeight * (1.0 - normalizedY);
      points.add(Offset(x, y));

      // X Label
      final tp = TextPainter(
        text: TextSpan(text: xLabels[i], style: axisLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomPadding + 5));
    }

    if (points.length < 2) return;

    // Build smooth cubic bezier curve
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY1 = p0.dy;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY2 = p1.dy;
      path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
    }

    // Fill Path with Gradient under the line
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, topPadding + chartHeight)
      ..lineTo(points.first.dx, topPadding + chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3B82F6).withValues(alpha: 0.28),
          const Color(0xFF3B82F6).withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Line stroke paint
    final strokePaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Draw dots at data points
    final dotOuterPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;

    final dotInnerPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : Colors.white
      ..style = PaintingStyle.fill;

    for (final pt in points) {
      canvas.drawCircle(pt, 4.0, dotOuterPaint);
      canvas.drawCircle(pt, 2.0, dotInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UserGrowthChartPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.customDataPoints != customDataPoints ||
      oldDelegate.customXLabels != customXLabels;
}

class UserTypesDonut extends StatelessWidget {
  final int totalUsers;
  final int freeCount;
  final int premiumCount;
  final int inactiveCount;
  final int blockedCount;
  final bool isDark;

  const UserTypesDonut({
    super.key,
    this.totalUsers = 0,
    this.freeCount = 0,
    this.premiumCount = 0,
    this.inactiveCount = 0,
    this.blockedCount = 0,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _UserTypesDonutPainter(
          totalUsers: totalUsers,
          freeCount: freeCount,
          premiumCount: premiumCount,
          inactiveCount: inactiveCount,
          blockedCount: blockedCount,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _UserTypesDonutPainter extends CustomPainter {
  final int totalUsers;
  final int freeCount;
  final int premiumCount;
  final int inactiveCount;
  final int blockedCount;
  final bool isDark;

  _UserTypesDonutPainter({
    required this.totalUsers,
    required this.freeCount,
    required this.premiumCount,
    required this.inactiveCount,
    required this.blockedCount,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 18.0;

    final int calculatedTotal = totalUsers > 0 ? totalUsers : (freeCount + premiumCount + inactiveCount + blockedCount);

    if (calculatedTotal <= 0) {
      // Empty placeholder ring
      final emptyPaint = Paint()
        ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, emptyPaint);

      final zeroTp = TextPainter(
        text: TextSpan(
          text: '0',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      zeroTp.paint(canvas, Offset(center.dx - zeroTp.width / 2, center.dy - zeroTp.height / 2 - 7));

      final labelTp = TextPainter(
        text: TextSpan(
          text: 'Users',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelTp.paint(canvas, Offset(center.dx - labelTp.width / 2, center.dy + 3));
      return;
    }

    final fCount = freeCount > 0 ? freeCount : (calculatedTotal - premiumCount - inactiveCount - blockedCount).clamp(0, calculatedTotal);
    final pCount = premiumCount;
    final iCount = inactiveCount;
    final bCount = blockedCount;

    final segments = [
      {'val': fCount, 'color': const Color(0xFF0284C7)},
      {'val': pCount, 'color': const Color(0xFF10B981)},
      {'val': iCount, 'color': const Color(0xFFF59E0B)},
      {'val': bCount, 'color': const Color(0xFFEF4444)},
    ];

    double startAngle = -pi / 2;
    const gapAngle = 0.04;

    for (int i = 0; i < segments.length; i++) {
      final val = segments[i]['val'] as int;
      if (val <= 0) continue;
      final pct = val / calculatedTotal;
      final sweepAngle = max(0.01, pct * 2 * pi - gapAngle);
      final paint = Paint()
        ..color = segments[i]['color'] as Color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gapAngle / 2,
        sweepAngle,
        false,
        paint,
      );

      startAngle += pct * 2 * pi;
    }

    // Center text
    final countFormatted = calculatedTotal >= 1000
        ? '${(calculatedTotal / 1000).toStringAsFixed(1)}k'
        : '$calculatedTotal';

    final numberTp = TextPainter(
      text: TextSpan(
        text: countFormatted,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    numberTp.paint(canvas, Offset(center.dx - numberTp.width / 2, center.dy - numberTp.height / 2 - 7));

    final labelTp = TextPainter(
      text: TextSpan(
        text: 'Users',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelTp.paint(canvas, Offset(center.dx - labelTp.width / 2, center.dy + 3));
  }

  @override
  bool shouldRepaint(covariant _UserTypesDonutPainter oldDelegate) =>
      oldDelegate.totalUsers != totalUsers ||
      oldDelegate.freeCount != freeCount ||
      oldDelegate.premiumCount != premiumCount ||
      oldDelegate.inactiveCount != inactiveCount ||
      oldDelegate.blockedCount != blockedCount ||
      oldDelegate.isDark != isDark;
}

