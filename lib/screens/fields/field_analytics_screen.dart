import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/field_model.dart';
import '../../theme.dart';

enum _AnalyticsView {
  predictionAccuracy('Predicted vs Actual'),
  readinessOutput('Pluckable Ratio vs Actual');

  final String label;

  const _AnalyticsView(this.label);
}

enum _AnalyticsRange {
  last7('7D', 7),
  last30('30D', 30),
  last90('90D', 90),
  all('All', 0);

  final String label;
  final int days;

  const _AnalyticsRange(this.label, this.days);
}

class FieldAnalyticsScreen extends StatefulWidget {
  final String fieldId;

  const FieldAnalyticsScreen({super.key, required this.fieldId});

  @override
  State<FieldAnalyticsScreen> createState() => _FieldAnalyticsScreenState();
}

class _FieldAnalyticsScreenState extends State<FieldAnalyticsScreen> {
  _AnalyticsView _view = _AnalyticsView.predictionAccuracy;
  _AnalyticsRange _range = _AnalyticsRange.last30;

  @override
  Widget build(BuildContext context) {
    final manager = FieldManager();
    final field = manager.fields.firstWhere(
      (field) => field.id == widget.fieldId,
    );
    final records = _filteredRecords(field);
    final completed = field.measurements
        .where((measurement) => measurement.hasActualYield)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.name,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Field analytics',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryGrid(records: completed),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4D8DD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Round performance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Compare each completed round against actual harvested output.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _AnalyticsDropdown<_AnalyticsView>(
                          value: _view,
                          values: _AnalyticsView.values,
                          labelBuilder: (value) => value.label,
                          onChanged: (value) => setState(() => _view = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 104,
                        child: _AnalyticsDropdown<_AnalyticsRange>(
                          value: _range,
                          values: _AnalyticsRange.values,
                          labelBuilder: (value) => value.label,
                          onChanged: (value) => setState(() => _range = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (records.isEmpty)
                    const _AnalyticsEmptyState()
                  else
                    SizedBox(
                      height: 260,
                      child: CustomPaint(
                        painter: _FieldAnalyticsPainter(
                          records: records,
                          view: _view,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _InsightPanel(records: completed),
          ],
        ),
      ),
    );
  }

  List<FieldMeasurement> _filteredRecords(Field field) {
    final records =
        field.measurements
            .where(
              (measurement) =>
                  measurement.hasActualYield &&
                  measurement.predictedYieldKg != null &&
                  measurement.analyzedImages.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    if (_range.days == 0) {
      return records;
    }
    final cutoff = DateTime.now().subtract(Duration(days: _range.days));
    return records
        .where((measurement) => measurement.date.isAfter(cutoff))
        .toList();
  }
}

class _SummaryGrid extends StatelessWidget {
  final List<FieldMeasurement> records;

  const _SummaryGrid({required this.records});

  @override
  Widget build(BuildContext context) {
    final totalActual = records.fold<double>(
      0,
      (sum, record) => sum + (record.actualYieldKg ?? 0),
    );
    final avgRatio = records.isEmpty
        ? 0.0
        : records.fold<double>(
                0,
                (sum, record) => sum + record.averagePluckableRatio,
              ) /
              records.length;
    final avgVariance = records.isEmpty
        ? 0.0
        : records.fold<double>(
                0,
                (sum, record) => sum + (record.yieldVariancePercent ?? 0),
              ) /
              records.length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.85,
      children: [
        _SummaryTile(
          label: 'Actual yield',
          value: '${totalActual.toStringAsFixed(1)} kg',
        ),
        _SummaryTile(label: 'Completed rounds', value: '${records.length}'),
        _SummaryTile(
          label: 'Avg pluckable',
          value: '${(avgRatio * 100).toStringAsFixed(1)}%',
        ),
        _SummaryTile(
          label: 'Avg variance',
          value: '${avgVariance.toStringAsFixed(1)}%',
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, Color(0xFF1E4A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.brandGreen,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  const _AnalyticsDropdown({
    required this.value,
    required this.values,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9DEE3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: values
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labelBuilder(item),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
      ),
    );
  }
}

class _FieldAnalyticsPainter extends CustomPainter {
  final List<FieldMeasurement> records;
  final _AnalyticsView view;

  const _FieldAnalyticsPainter({required this.records, required this.view});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 42.0;
    const rightPad = 34.0;
    const topPad = 24.0;
    const bottomPad = 38.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    final actualValues = records
        .map((record) => record.actualYieldKg ?? 0)
        .toList();
    final primaryValues = view == _AnalyticsView.predictionAccuracy
        ? records.map((record) => record.predictedYieldKg ?? 0).toList()
        : records.map((record) => record.averagePluckableRatio * 100).toList();
    final actualMax = math.max(
      1.0,
      actualValues.fold<double>(0, math.max) * 1.18,
    );
    final primaryMax = view == _AnalyticsView.predictionAccuracy
        ? actualMax
        : 100.0;

    final gridPaint = Paint()
      ..color = const Color(0xFFE8ECEF)
      ..strokeWidth = 1;
    const axisStyle = TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );

    for (var i = 0; i < 5; i++) {
      final y = topPad + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );

      final leftLabel = actualMax * (1 - i / 4);
      _paintText(
        canvas,
        leftLabel >= 1000
            ? '${(leftLabel / 1000).toStringAsFixed(1)}k'
            : leftLabel.toStringAsFixed(0),
        Offset(leftPad - 8, y),
        axisStyle,
        alignRight: true,
      );

      final rightLabel = primaryMax * (1 - i / 4);
      _paintText(
        canvas,
        view == _AnalyticsView.predictionAccuracy
            ? rightLabel.toStringAsFixed(0)
            : '${rightLabel.toStringAsFixed(0)}%',
        Offset(size.width - rightPad + 8, y),
        axisStyle,
      );
    }

    final slot = records.length == 1 ? 0.0 : chartWidth / (records.length - 1);
    final actualOffsets = <Offset>[];
    final primaryOffsets = <Offset>[];

    for (var i = 0; i < records.length; i++) {
      final dx = records.length == 1
          ? leftPad + chartWidth / 2
          : leftPad + slot * i;
      final actualY =
          topPad + chartHeight - (actualValues[i] / actualMax) * chartHeight;
      final primaryY =
          topPad + chartHeight - (primaryValues[i] / primaryMax) * chartHeight;
      actualOffsets.add(Offset(dx, actualY));
      primaryOffsets.add(Offset(dx, primaryY));

      _paintText(
        canvas,
        '${records[i].date.month}/${records[i].date.day}',
        Offset(dx, size.height - 18),
        axisStyle,
        centered: true,
      );
    }

    _drawLine(canvas, actualOffsets, AppTheme.brandGreen);
    _drawLine(canvas, primaryOffsets, AppTheme.primaryButton);

    for (final point in actualOffsets) {
      canvas.drawCircle(point, 5, Paint()..color = AppTheme.brandGreen);
      canvas.drawCircle(point, 2.5, Paint()..color = Colors.white);
    }
    for (final point in primaryOffsets) {
      canvas.drawCircle(point, 5, Paint()..color = AppTheme.primaryButton);
      canvas.drawCircle(point, 2.5, Paint()..color = Colors.white);
    }

    final primaryLabel = view == _AnalyticsView.predictionAccuracy
        ? 'Predicted'
        : 'Pluckable';
    _paintLegend(canvas, Offset(leftPad, 0), 'Actual', AppTheme.brandGreen);
    _paintLegend(
      canvas,
      Offset(leftPad + 88, 0),
      primaryLabel,
      AppTheme.primaryButton,
    );
  }

  void _drawLine(Canvas canvas, List<Offset> points, Color color) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (points.length == 1) {
      canvas.drawCircle(points.first, 5, paint..style = PaintingStyle.fill);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _paintLegend(Canvas canvas, Offset offset, String label, Color color) {
    canvas.drawCircle(offset + const Offset(5, 8), 4, Paint()..color = color);
    _paintText(
      canvas,
      label,
      offset + const Offset(14, 8),
      const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    bool centered = false,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = centered
        ? offset.dx - painter.width / 2
        : alignRight
        ? offset.dx - painter.width
        : offset.dx;
    painter.paint(canvas, Offset(dx, offset.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _FieldAnalyticsPainter oldDelegate) {
    return oldDelegate.records != records || oldDelegate.view != view;
  }
}

class _InsightPanel extends StatelessWidget {
  final List<FieldMeasurement> records;

  const _InsightPanel({required this.records});

  @override
  Widget build(BuildContext context) {
    final best =
        records.where((record) => record.yieldVariancePercent != null).toList()
          ..sort(
            (a, b) => (a.yieldVariancePercent!.abs()).compareTo(
              b.yieldVariancePercent!.abs(),
            ),
          );
    final message = best.isEmpty
        ? 'Log actual yield after each round to unlock prediction accuracy insights.'
        : 'Best matched round was ${best.first.yieldVariancePercent!.abs().toStringAsFixed(1)}% away from prediction.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9DEE3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.brandGreen.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.insights_outlined,
              color: AppTheme.brandGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Complete rounds and log actual yield to compare prediction accuracy and pluckable ratio trends.',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}
