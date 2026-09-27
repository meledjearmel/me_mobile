import 'package:flutter/material.dart';

import '../../../../app/theme/app_palette.dart';
import '../../data/dashboard.dart';

/// Courbe des visites sur 30 jours (§4.1), en aire dégradée façon sparkline.
class VisitsChart extends StatelessWidget {
  const VisitsChart({super.key, required this.daily});

  final List<DailyVisit> daily;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (daily.isEmpty) {
      return const SizedBox(height: 120);
    }
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(
        painter: _VisitsPainter(
          daily: daily,
          lineColor: colors.accent,
          fillColor: colors.accent.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _VisitsPainter extends CustomPainter {
  _VisitsPainter({required this.daily, required this.lineColor, required this.fillColor});

  final List<DailyVisit> daily;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxCount = daily.map((d) => d.count).fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = maxCount == 0 ? 1 : maxCount;
    final stepX = daily.length > 1 ? size.width / (daily.length - 1) : 0.0;
    const topPadding = 8.0;
    final chartHeight = size.height - topPadding;

    Offset pointAt(int i) {
      final x = daily.length == 1 ? size.width / 2 : i * stepX;
      final y = topPadding + chartHeight - (daily[i].count / safeMax) * chartHeight;
      return Offset(x, y);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < daily.length; i++) {
      line.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    final fill = Path.from(line)
      ..lineTo(pointAt(daily.length - 1).dx, size.height)
      ..lineTo(pointAt(0).dx, size.height)
      ..close();

    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _VisitsPainter oldDelegate) => !identical(oldDelegate.daily, daily);
}
