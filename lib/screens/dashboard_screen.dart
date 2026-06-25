import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/field_model.dart';
import '../theme.dart';
import 'fields_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FieldManager(),
      builder: (context, _) {
        final manager = FieldManager();
        final chartPoints = _buildChartPoints(manager.fields);

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFE8ECEF),
                  child: Icon(
                    Icons.spa_outlined,
                    color: AppTheme.textPrimary,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Text('TeaMate'),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActualYieldChartCard(points: chartPoints),
                const SizedBox(height: 24),
                const Text(
                  'Modules',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                _ModuleButton(
                  title: 'Yield Optimization',
                  subtitle:
                      'Manage plucking readiness, analysis, and actual yield.',
                  icon: Icons.auto_graph_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FieldsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _ModuleButton(
                  title: 'Disease Detection',
                  subtitle: 'Review pest and leaf-damage screening workflows.',
                  icon: Icons.health_and_safety_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _ModulePlaceholderScreen(
                          title: 'Disease Detection',
                          description:
                              'Disease detection workflows can be added here.',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _ModuleButton(
                  title: 'Quality Prediction',
                  subtitle: 'Track quality signals and post-plucking outcomes.',
                  icon: Icons.verified_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _ModulePlaceholderScreen(
                          title: 'Quality Prediction',
                          description:
                              'Quality prediction workflows can be added here.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<_YieldChartPoint> _buildChartPoints(List<Field> fields) {
  final grouped = <DateTime, List<FieldMeasurement>>{};

  for (final field in fields) {
    for (final measurement in field.measurements) {
      if (!measurement.hasActualYield) {
        continue;
      }
      final dayKey = DateTime(
        measurement.date.year,
        measurement.date.month,
        measurement.date.day,
      );
      grouped.putIfAbsent(dayKey, () => []).add(measurement);
    }
  }

  final points = grouped.entries.map((entry) {
    final actualYield = entry.value.fold<double>(
      0,
      (sum, measurement) => sum + (measurement.actualYieldKg ?? 0),
    );
    return _YieldChartPoint(date: entry.key, actualYieldKg: actualYield);
  }).toList();

  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

class _YieldChartPoint {
  final DateTime date;
  final double actualYieldKg;

  const _YieldChartPoint({required this.date, required this.actualYieldKg});

  String get dateLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _ActualYieldChartCard extends StatelessWidget {
  final List<_YieldChartPoint> points;

  const _ActualYieldChartCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE4E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actual Yield',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Actual yield trend across completed plucking rounds.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          if (points.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'No completed rounds yet. Actual yield entries will appear here after rounds are completed.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
              ),
            )
          else
            SizedBox(
              height: 240,
              child: CustomPaint(
                painter: _ActualYieldChartPainter(points: points),
                size: Size.infinite,
              ),
            ),
        ],
      ),
    );
  }
}

class _ModuleButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModuleButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE4E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF7B8794),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModulePlaceholderScreen extends StatelessWidget {
  final String title;
  final String description;

  const _ModulePlaceholderScreen({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActualYieldChartPainter extends CustomPainter {
  final List<_YieldChartPoint> points;

  const _ActualYieldChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = 36.0;
    final rightPad = 14.0;
    final topPad = 10.0;
    final bottomPad = 42.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;
    final maxYield = points
        .map((point) => point.actualYieldKg)
        .reduce(math.max);
    final yieldScaleMax = math.max(1.0, maxYield * 1.15);

    final gridPaint = Paint()
      ..color = const Color(0xFFE9EDF1)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = AppTheme.textPrimary
      ..strokeWidth = 2.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointOuterPaint = Paint()..color = AppTheme.textPrimary;
    final pointInnerPaint = Paint()..color = Colors.white;
    const axisTextStyle = TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    for (var i = 0; i < 5; i++) {
      final ratio = i / 4;
      final y = topPad + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );

      final yValuePainter = TextPainter(
        text: TextSpan(
          text: (yieldScaleMax * (1 - ratio)).toStringAsFixed(0),
          style: axisTextStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      yValuePainter.paint(
        canvas,
        Offset(
          leftPad - yValuePainter.width - 8,
          y - (yValuePainter.height / 2),
        ),
      );
    }

    final chartPoints = <Offset>[];
    final slotWidth = points.length == 1
        ? 0.0
        : chartWidth / (points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final dx = points.length == 1
          ? leftPad + (chartWidth / 2)
          : leftPad + (slotWidth * i);
      final dy =
          topPad +
          chartHeight -
          ((point.actualYieldKg / yieldScaleMax) * chartHeight);
      chartPoints.add(Offset(dx, dy));

      final valuePainter = TextPainter(
        text: TextSpan(
          text: '${point.actualYieldKg.toStringAsFixed(0)} kg',
          style: axisTextStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valuePainter.paint(
        canvas,
        Offset(dx - (valuePainter.width / 2), dy - 20),
      );
    }

    final path = Path();
    for (var i = 0; i < chartPoints.length; i++) {
      final point = chartPoints[i];
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < chartPoints.length; i++) {
      final point = chartPoints[i];
      canvas.drawCircle(point, 5, pointOuterPaint);
      canvas.drawCircle(point, 2.4, pointInnerPaint);

      final labelPainter = TextPainter(
        text: TextSpan(text: points[i].dateLabel, style: axisTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(point.dx - (labelPainter.width / 2), size.height - 22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActualYieldChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
