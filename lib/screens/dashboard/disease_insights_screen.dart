import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/disease_insights.dart';
import '../../models/field_model.dart';
import '../../services/disease_insights_service.dart';
import '../../theme.dart';

/// Estate Health Overview / Disease Insights screen.
///
/// Two modes:
///   * Estate view  — [fieldId] is null  → fetches `GET .../disease/estate-insights`
///   * Field view   — [fieldId] provided → fetches `GET .../disease/field-insights/{fieldId}`
///
/// Both branches use a [FutureBuilder] with loading, error (retry), and empty
/// states. The visual design of the cards / charts is unchanged; only the data
/// source moves from inline `const` literals to the models in
/// `lib/models/disease_insights.dart`.
class DiseaseInsightsScreen extends StatefulWidget {
  final String? fieldId;
  final String? fieldName;

  const DiseaseInsightsScreen({super.key, this.fieldId, this.fieldName});

  @override
  State<DiseaseInsightsScreen> createState() => _DiseaseInsightsScreenState();
}

class _DiseaseInsightsScreenState extends State<DiseaseInsightsScreen> {
  late Future<dynamic> _future;
  String _selectedRange = '30D';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final fieldId = widget.fieldId;
    final days = _daysFromRange(_selectedRange);
    if (fieldId != null && fieldId.isNotEmpty) {
      _future = DiseaseInsightsService.fetchFieldInsights(fieldId, days: days);
    } else {
      _future = DiseaseInsightsService.fetchEstateInsights(days: days);
    }
  }

  /// Called by child chart widgets when the user changes the 7D/30D/90D
  /// toggle.  Updates local state and re-fetches insights from the API
  /// with the matching `days` query parameter, then awaits the new future
  /// so the UI shows a fresh loading state while the server responds.
  Future<void> _onRangeChanged(String range) async {
    if (!mounted) return;
    setState(() => _selectedRange = range);
    _load();
    setState(() {}); // trigger FutureBuilder with new future
    await _future;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    _load();
    setState(() {});
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final isFieldView = widget.fieldId != null && widget.fieldId!.isNotEmpty;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(isFieldView
            ? '${widget.fieldName ?? "Field"} Insights'
            : 'Disease Insights'),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingState();
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          final data = snapshot.data;
          if (data == null) {
            debugPrint('[DiseaseInsights] FutureBuilder: data is null');
            return _ErrorState(
              message: 'No insights data returned.',
              onRetry: _refresh,
            );
          }
          if (isFieldView) {
            final insights = data as FieldInsights;
            debugPrint('[DiseaseInsights] FutureBuilder: FieldInsights '
                'received, totalScans=${insights.totalScans}, '
                'timeline=${insights.fieldHealthTimeline.length}, '
                'confidence=${insights.confidenceDistribution.length}, '
                'weather=${insights.weatherVsDisease != null}, '
                'treatment=${insights.treatmentResponseTrend.available}');
            if (insights.totalScans == 0) {
              return const _EmptyState();
            }
            return _FieldInsightsContent(
              insights: insights,
              selectedRange: _selectedRange,
              onRangeChanged: _onRangeChanged,
            );
          }
          final estate = data as EstateInsights;
          debugPrint('[DiseaseInsights] FutureBuilder: EstateInsights '
              'received, kpiCards=${estate.kpiCards.length}, '
              'riskMap=${estate.riskMap.length}, '
              'trend=${estate.diseaseTrend.length}, '
              'priority=${estate.fieldPriority.length}, '
              'composition=${estate.diseaseComposition.length}, '
              'actions=${estate.actionQueue.length}');
          if (estate.isEmpty) {
            return const _EmptyState();
          }
          return _EstateInsightsContent(
            insights: estate,
            selectedRange: _selectedRange,
            onRangeChanged: _onRangeChanged,
          );
        },
      ),
    );
  }
}

// ── Async shell states ─────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.brandGreen),
          SizedBox(height: 16),
          Text(
            'Loading disease insights...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(
          child: Text(
            'No disease insights available yet',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Estate view
// ════════════════════════════════════════════════════════════════════════════

class _EstateInsightsContent extends StatefulWidget {
  final EstateInsights insights;
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const _EstateInsightsContent({
    required this.insights,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  State<_EstateInsightsContent> createState() => _EstateInsightsContentState();
}

class _EstateInsightsContentState extends State<_EstateInsightsContent> {
  /// When non-null, a field has been chosen from the dropdown and its
  /// insights are being loaded for the disease-growth trend chart.
  String? _selectedFieldId;

  EstateInsights get insights => widget.insights;

  @override
  Widget build(BuildContext context) {
    final kpis = insights.kpiCards;
    debugPrint('[DiseaseInsights] Estate content building: '
        'kpis=${kpis.length}, riskMap=${insights.riskMap.length}, '
        'trend=${insights.diseaseTrend.length}, '
        'priority=${insights.fieldPriority.length}, '
        'composition=${insights.diseaseComposition.length}, '
        'actions=${insights.actionQueue.length}');
    // Per-section trace
    for (var i = 0; i < kpis.length; i++) {
      debugPrint('[DiseaseInsights]   KPI[$i]: label=${kpis[i].label} '
          'value=${kpis[i].value} caption=${kpis[i].caption}');
    }
    for (var i = 0; i < insights.riskMap.length; i++) {
      final f = insights.riskMap[i];
      debugPrint('[DiseaseInsights]   RiskMap[$i]: ${f.fieldName} '
          '${f.healthPercentage.round()}% ${f.riskLevel} '
          '(${f.resultText})');
    }
    for (var i = 0; i < insights.diseaseTrend.length; i++) {
      final p = insights.diseaseTrend[i];
      debugPrint('[DiseaseInsights]   Trend[$i]: ${p.label} '
          'totalScans=${p.totalScans} healthy=${p.healthy.round()}% '
          'anth=${p.anthracnose.round()}% blister=${p.blisterBlight.round()}% '
          'grey=${p.greyBlight.round()}% dist=${p.diseaseDistribution}');
    }
    for (var i = 0; i < insights.fieldPriority.length; i++) {
      final p = insights.fieldPriority[i];
      debugPrint('[DiseaseInsights]   Priority[$i]: ${p.field} '
          'score=${p.score} rank=${p.rank} issue=${p.issue} area=${p.areaDisplay}');
    }
    for (var i = 0; i < insights.diseaseComposition.length; i++) {
      final c = insights.diseaseComposition[i];
      debugPrint('[DiseaseInsights]   Comp[$i]: ${c.disease} ${c.percentage}%');
    }
    for (var i = 0; i < insights.actionQueue.length; i++) {
      final a = insights.actionQueue[i];
      debugPrint('[DiseaseInsights]   Action[$i]: ${a.title} '
          'detail=${a.detail} timing=${a.timing}');
    }
    // Enrich risk-map fields with area data cross-referenced from the
    // fields API (FieldManager).  The estate-insights `risk_map` entries do
    // not include `area_hectares`, so we look it up by `field_id`.
    final areaLookup = {
      for (final fld in FieldManager().fields) fld.id: fld.areaHectares,
    };
    final enrichedRiskMap = [
      for (final f in insights.riskMap)
        EstateRiskMapField(
          fieldId: f.fieldId,
          fieldName: f.fieldName,
          healthPercentage: f.healthPercentage,
          riskLevel: f.riskLevel,
          areaHectares: areaLookup[f.fieldId] ?? 0.0,
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const _PageIntro(
          title: 'Estate health overview',
          subtitle:
              'Prioritize inspections and treatment using risk, coverage, and recent movement.',
        ),
        const SizedBox(height: 18),
        // KPI cards — rendered 2 per row to mirror the original layout.
        for (var r = 0; r < kpis.length; r += 2)
          Padding(
            padding: EdgeInsets.only(bottom: r + 2 < kpis.length ? 10 : 18),
            child: Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    label: kpis[r].label,
                    value: kpis[r].value,
                    caption: kpis[r].caption,
                    icon: kpis[r].icon,
                  ),
                ),
                const SizedBox(width: 10),
                if (r + 1 < kpis.length)
                  Expanded(
                    child: _KpiCard(
                      label: kpis[r + 1].label,
                      value: kpis[r + 1].value,
                      caption: kpis[r + 1].caption,
                      icon: kpis[r + 1].icon,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
        // Field selector dropdown for the disease growth trend graph
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _FieldDropdown(
            fields: FieldManager().fields,
            selectedFieldId: _selectedFieldId,
            onChanged: (id) => setState(() => _selectedFieldId = id),
          ),
        ),
        // Disease growth trend for the selected field (if any)
        if (_selectedFieldId != null && _selectedFieldId!.isNotEmpty) ...[
          _FieldDiseaseGrowthChart(
            fieldId: _selectedFieldId!,
            selectedRange: widget.selectedRange,
            onRangeChanged: widget.onRangeChanged,
          ),
          const SizedBox(height: 16),
        ],
        // Field risk map
        if (enrichedRiskMap.isNotEmpty) ...[
          _InsightCard(
            title: 'Field risk map',
            subtitle: 'Disease pressure and health status by field',
            icon: Icons.map_outlined,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: _RiskMap(fields: enrichedRiskMap),
                ),
                const SizedBox(height: 14),
                const _RiskMapLegend(),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Disease spread & healthiness
        if (insights.diseaseTrend.isNotEmpty) ...[
          _DiseaseSpreadCard(
            points: insights.diseaseTrend,
            selectedRange: widget.selectedRange,
            onRangeChanged: widget.onRangeChanged,
          ),
          const SizedBox(height: 16),
        ],
        // Field priority
        if (insights.fieldPriority.isNotEmpty) ...[
          _PriorityCard(priorityRows: insights.fieldPriority),
          const SizedBox(height: 16),
        ],
        // Disease composition
        if (insights.diseaseComposition.isNotEmpty) ...[
          _DiseaseCompositionCard(composition: insights.diseaseComposition),
          const SizedBox(height: 16),
        ],
        // Action queue
        if (insights.actionQueue.isNotEmpty) ...[
          _ActionQueueCard(actions: insights.actionQueue),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Field view
// ════════════════════════════════════════════════════════════════════════════

class _FieldInsightsContent extends StatelessWidget {
  final FieldInsights insights;
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const _FieldInsightsContent({
    required this.insights,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Debug: trace model data into widgets
    debugPrint('[DiseaseInsights] FieldInsights model: '
        'fieldId=${insights.fieldId}, '
        'totalScans=${insights.totalScans}, '
        'pressureScore=${insights.diseasePressureScore}, '
        'pressureStatus=${insights.diseasePressureStatus}, '
        'timelineEntries=${insights.fieldHealthTimeline.length}, '
        'confidenceSlices=${insights.confidenceDistribution.length}, '
        'weatherAvailable=${insights.weatherVsDisease != null}, '
        'treatmentAvailable=${insights.treatmentResponseTrend.available}');

    final hasTrend = insights.fieldHealthTimeline.length > 1;
    final healthSeries = hasTrend
        ? _healthTimelineToSeries(insights.fieldHealthTimeline)
        : null;
    final hasWeather = insights.weatherVsDisease != null;
    final weatherSeries = hasWeather
        ? _weatherToSeries(insights.weatherVsDisease!)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _PageIntro(
          title: '${insights.fieldName} health overview',
          subtitle:
              'Review disease movement, environmental pressure, and treatment response.',
        ),
        const SizedBox(height: 18),
        _FieldStatusCard(
          diseasePressureScore: insights.diseasePressureScore,
          status: insights.diseasePressureStatus,
        ),
        const SizedBox(height: 16),
        if (hasTrend) _buildTrendCard(healthSeries!),
        const SizedBox(height: 16),
        _InsightCard(
          title: 'Latest confidence',
          subtitle: 'Model probability distribution',
          icon: Icons.pie_chart_outline_rounded,
          child: _ConfidenceSummary(slices: insights.confidenceDistribution),
        ),
        const SizedBox(height: 16),
        if (hasWeather) _buildTrendCard(weatherSeries!),
        const SizedBox(height: 16),
        // Treatment response: the API returns {available, message} rather
        // than before/after rows.  Show the card with the API message so the
        // section always reflects real API data.
        _TreatmentResponseCard(
          rows: <FieldTreatmentResponse>[],
          insight: insights.treatmentResponseTrend.message,
        ),
      ],
    );
  }

  /// Converts the raw health-timeline scan records into a dual-axis
  /// [FieldTrendSeries] for the chart widget.
  ///
  /// Primary series  = health percentage (green).
  /// Secondary series = detection confidence as a percentage (red).
  FieldTrendSeries _healthTimelineToSeries(
    List<HealthTimelineEntry> entries,
  ) {
    debugPrint('[DiseaseInsights] Converting ${entries.length} timeline '
        'entries to chart series');
    return FieldTrendSeries(
      title: 'Field health timeline',
      subtitle: 'Scan-by-scan health percentage and model confidence',
      icon: Icons.timeline_rounded,
      primaryLabel: 'Health',
      secondaryLabel: 'Confidence',
      primaryColor: const Color(0xFF2F6B4F),
      secondaryColor: const Color(0xFFB54848),
      labels: entries.map((e) => e.date).toList(),
      primaryValues:
          entries.map((e) => e.healthPercentage).toList(),
      secondaryValues: entries
          .map((e) => (e.confidence ?? 0.0) * 100)
          .toList(),
      insight: _computeHealthInsight(entries),
    );
  }

  /// Converts the flat weather-vs-disease metrics into a dual-axis
  /// [FieldTrendSeries] for the chart widget.
  ///
  /// Each point compares healthy-scan conditions vs disease-scan conditions
  /// across humidity, rainfall, and temperature.
  FieldTrendSeries _weatherToSeries(WeatherDiseaseRelationship w) {
    debugPrint('[DiseaseInsights] Converting weather relationship to '
        'chart series: insight="${w.insight}"');
    return FieldTrendSeries(
      title: 'Weather vs disease',
      subtitle: 'Healthy vs disease scan conditions',
      icon: Icons.cloud_outlined,
      primaryLabel: 'Healthy scans',
      secondaryLabel: 'Disease scans',
      primaryColor: const Color(0xFF2F6B4F),
      secondaryColor: const Color(0xFFB54848),
      labels: const ['Humidity', 'Rainfall', 'Temperature'],
      primaryValues: [
        w.healthyAvgHumidity ?? 0.0,
        w.healthyAvgRainfall ?? 0.0,
        w.healthyAvgTemperature ?? 0.0,
      ],
      secondaryValues: [
        w.diseaseAvgHumidity ?? 0.0,
        w.diseaseAvgRainfall ?? 0.0,
        w.diseaseAvgTemperature ?? 0.0,
      ],
      insight: w.insight ?? '',
    );
  }

  /// Produces a plain-language interpretation of the latest health entry.
  String _computeHealthInsight(List<HealthTimelineEntry> entries) {
    if (entries.isEmpty) return '';
    final latest = entries.first;
    final disease = latest.detectedDisease;
    final conf = latest.confidence;
    if (disease != null && conf != null) {
      return 'Latest scan: ${latest.healthPercentage.toInt()}% healthy '
          'with $disease detected '
          '(${(conf * 100).toInt()}% confidence).';
    }
    return 'Latest scan shows ${latest.healthPercentage.toInt()}% plant health.';
  }

  Widget _buildTrendCard(FieldTrendSeries series) {
    return _FieldMetricTrendCard(
      title: series.title,
      subtitle: series.subtitle,
      icon: series.icon,
      primaryLabel: series.primaryLabel,
      secondaryLabel: series.secondaryLabel,
      primaryColor: series.primaryColor,
      secondaryColor: series.secondaryColor,
      labels: series.labels,
      primaryValues: series.primaryValues,
      secondaryValues: series.secondaryValues,
      insight: series.insight,
      selectedRange: selectedRange,
      onRangeChanged: onRangeChanged,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared presentation widgets
// ════════════════════════════════════════════════════════════════════════════

class _PageIntro extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PageIntro({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppTheme.textSecondary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  const _InsightCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _RiskMap extends StatelessWidget {
  final List<EstateRiskMapField> fields;
  const _RiskMap({required this.fields});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _RiskMapPainter(fields: fields));
}

class _RiskMapPainter extends CustomPainter {
  final List<EstateRiskMapField> fields;

  const _RiskMapPainter({required this.fields});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = const Color(0xFFF5F7F5),
    );

    if (fields.isEmpty) return;

    // Area-proportional block layout.
    // Each field's block size scales with sqrt(area_hectares) so that larger
    // fields render as larger rectangles while smaller fields stay compact.
    const margin = 8.0;
    const minSize = 56.0;
    const maxSize = 96.0;

    final maxArea = fields.fold<double>(
      0,
      (max, f) => math.max(max, f.areaHectares),
    );
    final safeMax = maxArea > 0 ? maxArea : 1.0;

    double sizeFor(EstateRiskMapField f) {
      if (f.areaHectares <= 0) return minSize;
      final ratio = (f.areaHectares / safeMax).clamp(0.0, 1.0);
      return minSize + (maxSize - minSize) * math.sqrt(ratio);
    }

    var x = margin;
    var y = margin;
    var rowHeight = 0.0;

    for (final field in fields) {
      final blockSize = sizeFor(field);

      // Wrap to next row when the block doesn't fit horizontally.
      if (x + blockSize + margin > size.width) {
        x = margin;
        y += rowHeight + margin;
        rowHeight = 0;
      }

      // Stop drawing if we've run out of vertical space.
      if (y + blockSize + margin > size.height) break;

      final rect = Rect.fromLTWH(x, y, blockSize, blockSize);
      rowHeight = math.max(rowHeight, blockSize);

      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(9));
      canvas.drawRRect(
        shape,
        Paint()..color = field.color.withValues(alpha: .18),
      );
      final borderPaint = Paint()
        ..color = field.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawRRect(shape, borderPaint);

      final label = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${field.fieldName}\n',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: field.resultText,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      // Only paint the label if it fits inside the block.
      if (label.width <= blockSize - 4 && label.height <= blockSize - 4) {
        label.paint(
          canvas,
          Offset(
            rect.center.dx - label.width / 2,
            rect.center.dy - label.height / 2,
          ),
        );
      }

      x += blockSize + margin;
    }
  }

  @override
  bool shouldRepaint(covariant _RiskMapPainter oldDelegate) =>
      oldDelegate.fields != fields;
}

class _RiskMapLegend extends StatelessWidget {
  const _RiskMapLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _ChartLegend(color: Color(0xFFB54848), label: 'High risk'),
        _ChartLegend(color: Color(0xFFE69A2E), label: 'Medium risk'),
        _ChartLegend(color: Color(0xFF8A9B91), label: 'Low risk'),
        _ChartLegend(color: Color(0xFF4F8065), label: 'Healthy'),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final List<EstateFieldPriority> priorityRows;

  const _PriorityCard({required this.priorityRows});

  @override
  Widget build(BuildContext context) => _InsightCard(
        title: 'Field priority',
        subtitle: 'Ranked by risk, area, and recent movement',
        icon: Icons.priority_high_rounded,
        child: Column(
          children: [
            for (var i = 0; i < priorityRows.length; i++) ...[
              _PriorityRow(
                rank: priorityRows[i].rank,
                field: priorityRows[i].field,
                issue: priorityRows[i].issue,
                score: priorityRows[i].score,
                area: priorityRows[i].areaDisplay,
              ),
              if (i != priorityRows.length - 1)
                const Divider(height: 22, color: Color(0xFFE8ECE8)),
            ],
          ],
        ),
      );
}

class _PriorityRow extends StatelessWidget {
  final String rank, field, issue, area;
  final int score;
  const _PriorityRow({
    required this.rank,
    required this.field,
    required this.issue,
    required this.score,
    required this.area,
  });
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              rank,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  issue,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              Text(
                area,
                style:
                    const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      );
}

class _DiseaseCompositionCard extends StatelessWidget {
  final List<EstateDiseaseComposition> composition;

  const _DiseaseCompositionCard({required this.composition});

  @override
  Widget build(BuildContext context) => _InsightCard(
        title: 'Disease composition',
        subtitle: 'Share of detections in the selected period',
        icon: Icons.bar_chart_rounded,
        child: Column(
          children: [
            for (var i = 0; i < composition.length; i++) ...[
              _DistributionRow(
                label: composition[i].disease,
                value: composition[i].percentage,
              ),
              if (i != composition.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      );
}

class _DistributionRow extends StatelessWidget {
  final String label;
  final int value;
  const _DistributionRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$value%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: (value / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE8ECE9),
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      );
}

class _ActionQueueCard extends StatelessWidget {
  final List<EstateActionItem> actions;

  const _ActionQueueCard({required this.actions});

  @override
  Widget build(BuildContext context) => _InsightCard(
        title: 'Management action queue',
        subtitle: 'Decisions requiring follow-up',
        icon: Icons.checklist_rounded,
        child: Column(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              _ActionRow(
                title: actions[i].title,
                detail: actions[i].detail,
                timing: actions[i].timing,
              ),
              if (i != actions.length - 1)
                const Divider(height: 24, color: Color(0xFFE8ECE8)),
            ],
          ],
        ),
      );
}

class _ActionRow extends StatelessWidget {
  final String title, detail, timing;
  const _ActionRow({
    required this.title,
    required this.detail,
    required this.timing,
  });
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.radio_button_unchecked_rounded, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              timing,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
}

class _FieldMetricTrendCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryLabel;
  final String secondaryLabel;
  final Color primaryColor;
  final Color secondaryColor;
  final List<String> labels;
  final List<double> primaryValues;
  final List<double> secondaryValues;
  final String insight;
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const _FieldMetricTrendCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.primaryColor,
    required this.secondaryColor,
    required this.labels,
    required this.primaryValues,
    required this.secondaryValues,
    required this.insight,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  State<_FieldMetricTrendCard> createState() => _FieldMetricTrendCardState();
}

class _FieldMetricTrendCardState extends State<_FieldMetricTrendCard> {
  int? _selectedIndex;

  /// Returns labels whose dates fall within the selected range.
  /// When label values are not parseable as dates (e.g. the weather
  /// comparison chart) all labels are returned unchanged.
  List<String> get _effectiveLabels {
    final filtered = _filterByDate(widget.labels);
    return filtered ?? widget.labels;
  }

  List<double> get _effectivePrimaryValues {
    final indices = _filterIndices(widget.labels);
    if (indices == null) return widget.primaryValues;
    return indices.map((i) => widget.primaryValues[i]).toList();
  }

  List<double> get _effectiveSecondaryValues {
    final indices = _filterIndices(widget.labels);
    if (indices == null) return widget.secondaryValues;
    return indices.map((i) => widget.secondaryValues[i]).toList();
  }

  /// Returns null when labels are not date-parseable (no filtering applies).
  List<String>? _filterByDate(List<String> labels) {
    if (labels.isEmpty) return labels;
    final dated = <int, DateTime>{};
    for (var i = 0; i < labels.length; i++) {
      final date = DateTime.tryParse(labels[i]);
      if (date != null) dated[i] = date;
    }
    if (dated.isEmpty) return null;
    final sortedKeys = dated.keys.toList()..sort((a, b) => dated[a]!.compareTo(dated[b]!));
    final latest = dated[sortedKeys.last]!;
    final days = switch (widget.selectedRange) {
      '7D' => 7, '30D' => 30, '90D' => 90, _ => 30,
    };
    final cutoff = latest.subtract(Duration(days: days));
    final kept = dated.entries.where((e) => !e.value.isBefore(cutoff)).map((e) => e.key).toList()..sort();
    return kept.map((i) => labels[i]).toList();
  }

  /// Returns the indices to keep, or null if labels are not dates.
  List<int>? _filterIndices(List<String> labels) {
    if (labels.isEmpty) return null;
    final dated = <int, DateTime>{};
    for (var i = 0; i < labels.length; i++) {
      final date = DateTime.tryParse(labels[i]);
      if (date != null) dated[i] = date;
    }
    if (dated.isEmpty) return null;
    final sortedKeys = dated.keys.toList()..sort((a, b) => dated[a]!.compareTo(dated[b]!));
    final latest = dated[sortedKeys.last]!;
    final days = switch (widget.selectedRange) {
      '7D' => 7, '30D' => 30, '90D' => 90, _ => 30,
    };
    final cutoff = latest.subtract(Duration(days: days));
    return dated.entries
        .where((e) => !e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList()
      ..sort();
  }

  void _onRangeChanged(String range) {
    setState(() => _selectedIndex = null);
    widget.onRangeChanged(range);
  }

  void _select(Offset position, double width) {
    final labels = _effectiveLabels;
    if (labels.isEmpty) return;
    const left = 34.0;
    const right = 20.0;
    final chartWidth = width - left - right;
    final slotWidth = labels.length == 1 ? 0.0 : chartWidth / (labels.length - 1);
    final index = slotWidth == 0
        ? 0
        : ((position.dx - left).clamp(0.0, chartWidth) / slotWidth)
            .round()
            .clamp(0, labels.length - 1);
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLabels = _effectiveLabels;
    final effectivePrimary = _effectivePrimaryValues;
    final effectiveSecondary = _effectiveSecondaryValues;
    final latestPrimary = effectivePrimary.isNotEmpty
        ? effectivePrimary.last.toStringAsFixed(0)
        : widget.primaryValues.isNotEmpty
            ? widget.primaryValues.last.toStringAsFixed(0)
            : '-';
    final latestSecondary = effectiveSecondary.isNotEmpty
        ? effectiveSecondary.last.toStringAsFixed(0)
        : widget.secondaryValues.isNotEmpty
            ? widget.secondaryValues.last.toStringAsFixed(0)
            : '-';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InsightHeadingIcon(icon: widget.icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricSnapshot(
                  color: widget.primaryColor,
                  label: widget.primaryLabel,
                  value: '$latestPrimary%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricSnapshot(
                  color: widget.secondaryColor,
                  label: widget.secondaryLabel,
                  value: '$latestSecondary%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _ChartLegend(color: widget.primaryColor, label: widget.primaryLabel),
                    _ChartLegend(color: widget.secondaryColor, label: widget.secondaryLabel),
                  ],
                ),
              ),
              _ChartRangeSelector(
                initial: widget.selectedRange,
                onChange: _onRangeChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 265,
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (event) =>
                    _select(event.localPosition, constraints.maxWidth),
                onPanStart: (event) =>
                    _select(event.localPosition, constraints.maxWidth),
                onPanUpdate: (event) =>
                    _select(event.localPosition, constraints.maxWidth),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _DualMetricPainter(
                    labels: effectiveLabels,
                    primaryValues: effectivePrimary,
                    secondaryValues: effectiveSecondary,
                    primaryLabel: widget.primaryLabel,
                    secondaryLabel: widget.secondaryLabel,
                    primaryColor: widget.primaryColor,
                    secondaryColor: widget.secondaryColor,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 17,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.insight,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricSnapshot extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _MetricSnapshot({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9F8),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DualMetricPainter extends CustomPainter {
  final List<String> labels;
  final List<double> primaryValues;
  final List<double> secondaryValues;
  final String primaryLabel;
  final String secondaryLabel;
  final Color primaryColor;
  final Color secondaryColor;
  final int? selectedIndex;

  const _DualMetricPainter({
    required this.labels,
    required this.primaryValues,
    required this.secondaryValues,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.primaryColor,
    required this.secondaryColor,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const right = 20.0;
    const top = 42.0;
    const bottom = 34.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;
    const textStyle = TextStyle(
      color: Color(0xFF8A948D),
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFFF0F2F5)
      ..strokeWidth = 1;

    for (var i = 0; i < 5; i++) {
      final y = top + height * i / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      final axis = TextPainter(
        text: TextSpan(text: '${100 - i * 25}%', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      axis.paint(canvas, Offset(left - axis.width - 6, y - axis.height / 2));
    }

    final span = primaryValues.length - 1;
    List<Offset> offsets(List<double> values) =>
        List.generate(values.length, (i) {
          final x = span == 0 ? left + width / 2 : left + width * i / span;
          return Offset(
            x,
            top + height - values[i] / 100 * height,
          );
        });

    final primary = offsets(primaryValues);
    final secondary = offsets(secondaryValues);

    Path curve(List<Offset> values) {
      final path = Path()..moveTo(values.first.dx, values.first.dy);
      for (var i = 0; i < values.length - 1; i++) {
        final a = values[i];
        final b = values[i + 1];
        final midpoint = a.dx + (b.dx - a.dx) / 2.2;
        path.cubicTo(midpoint, a.dy, midpoint, b.dy, b.dx, b.dy);
      }
      return path;
    }

    final fill = Path.from(curve(primary))
      ..lineTo(primary.last.dx, top + height)
      ..lineTo(primary.first.dx, top + height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [
            primaryColor.withValues(alpha: .14),
            primaryColor.withValues(alpha: 0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(left, top, width, height)),
    );

    void drawSeries(List<Offset> values, Color color) {
      canvas.drawPath(
        curve(values),
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    drawSeries(primary, primaryColor);
    drawSeries(secondary, secondaryColor);

    for (var i = 0; i < labels.length; i++) {
      final label = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(primary[i].dx - label.width / 2, size.height - 18),
      );
    }

    final selected = (selectedIndex ?? labels.length - 1).clamp(
      0,
      labels.length - 1,
    );
    final selectedX = primary[selected].dx;
    final markerPaint = Paint()
      ..color = const Color(0xFFBFC7C1)
      ..strokeWidth = 1;
    for (double y = top; y < top + height; y += 7) {
      canvas.drawLine(
        Offset(selectedX, y),
        Offset(selectedX, math.min(y + 3, top + height)),
        markerPaint,
      );
    }
    for (final item in [
      (primary[selected], primaryColor),
      (secondary[selected], secondaryColor),
    ]) {
      canvas.drawCircle(item.$1, 5.5, Paint()..color = item.$2);
      canvas.drawCircle(item.$1, 2.5, Paint()..color = Colors.white);
    }

    final tooltipX = selectedX.clamp(70.0, size.width - 70.0);
    final tooltip = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(tooltipX, 22), width: 132, height: 40),
      const Radius.circular(8),
    );
    canvas.drawRRect(tooltip, Paint()..color = Colors.white);
    canvas.drawRRect(
      tooltip,
      Paint()..color = const Color(0xFFE4E9DE)..style = PaintingStyle.stroke,
    );
    final details = TextPainter(
      text: TextSpan(
        text:
            '${labels[selected]}\n$primaryLabel ${primaryValues[selected].toInt()}%  •  $secondaryLabel ${secondaryValues[selected].toInt()}%',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 126);
    details.paint(
      canvas,
      Offset(tooltipX - details.width / 2, 22 - details.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DualMetricPainter oldDelegate) =>
      oldDelegate.labels != labels ||
      oldDelegate.primaryValues != primaryValues ||
      oldDelegate.secondaryValues != secondaryValues ||
      oldDelegate.selectedIndex != selectedIndex;
}

class _DiseaseSpreadCard extends StatelessWidget {
  final List<EstateDiseaseTrendPoint> points;
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const _DiseaseSpreadCard({
    required this.points,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trendPoints = points
        .map((p) => _DiseaseTrendPoint(
              p.label,
              p.healthy,
              p.anthracnose,
              p.blisterBlight,
              p.greyBlight,
            ))
        .toList();

    return _DiseaseSpreadCardContent(
      points: trendPoints,
      selectedRange: selectedRange,
      onRangeChanged: onRangeChanged,
    );
  }
}

class _DiseaseTrendPoint {
  final String label;
  final double healthy;
  final double anthracnose;
  final double blisterBlight;
  final double greyBlight;
  const _DiseaseTrendPoint(
    this.label,
    this.healthy,
    this.anthracnose,
    this.blisterBlight,
    this.greyBlight,
  );
}

class _DiseaseSpreadCardContent extends StatefulWidget {
  final List<_DiseaseTrendPoint> points;
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const _DiseaseSpreadCardContent({
    required this.points,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  State<_DiseaseSpreadCardContent> createState() =>
      _DiseaseSpreadCardContentState();
}

class _DiseaseSpreadCardContentState extends State<_DiseaseSpreadCardContent> {
  int? _selectedIndex;

  List<_DiseaseTrendPoint> get _filteredPoints {
    if (widget.points.isEmpty) return widget.points;
    final dated = <DateTime, _DiseaseTrendPoint>{};
    for (final p in widget.points) {
      final date = DateTime.tryParse(p.label);
      if (date != null) dated[date] = p;
    }
    if (dated.isEmpty) return widget.points;
    final sortedKeys = dated.keys.toList()..sort();
    final latest = sortedKeys.last;
    final days = switch (widget.selectedRange) {
      '7D' => 7, '30D' => 30, '90D' => 90, _ => 30,
    };
    final cutoff = latest.subtract(Duration(days: days));
    return dated.entries
        .where((e) => !e.key.isBefore(cutoff))
        .map((e) => e.value)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
  }

  void _onRangeChanged(String range) {
    setState(() {
      _selectedIndex = null;
    });
    widget.onRangeChanged(range);
  }

  void _select(Offset position, double width) {
    final points = _filteredPoints;
    if (points.isEmpty) return;
    const left = 34.0;
    const right = 20.0;
    final chartWidth = width - left - right;
    final slotWidth = points.length == 1 ? 0.0 : chartWidth / (points.length - 1);
    final index = slotWidth == 0
        ? 0
        : ((position.dx - left).clamp(0.0, chartWidth) / slotWidth)
            .round()
            .clamp(0, points.length - 1);
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _InsightHeadingIcon(icon: Icons.show_chart_rounded),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disease spread & healthiness',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Share of scanned plants over time',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _ChartLegend(color: Color(0xFF2F6B4F), label: 'Healthy'),
              _ChartLegend(color: Color(0xFFB54848), label: 'Anthracnose'),
              _ChartLegend(color: Color(0xFFE69A2E), label: 'Blister blight'),
              _ChartLegend(color: Color(0xFF718096), label: 'Grey blight'),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: _ChartRangeSelector(
              initial: widget.selectedRange,
              onChange: _onRangeChanged,
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final points = _filteredPoints;
              return points.isEmpty
                  ? const SizedBox(height: 270)
                  : SizedBox(
                      height: 270,
                      child: LayoutBuilder(
                        builder: (context, constraints) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (event) =>
                              _select(event.localPosition, constraints.maxWidth),
                          onPanStart: (event) =>
                              _select(event.localPosition, constraints.maxWidth),
                          onPanUpdate: (event) =>
                              _select(event.localPosition, constraints.maxWidth),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _DiseaseSpreadPainter(
                              points: points,
                              selectedIndex: _selectedIndex,
                            ),
                          ),
                        ),
                      ),
                    );
            },
          ),
          const SizedBox(height: 6),
          Text(
            _interpretation(_filteredPoints),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Produces a plain-language interpretation of the latest trend point.
String _interpretation(List<_DiseaseTrendPoint> points) {
  if (points.isEmpty) return 'No trend data available.';
  final last = points.last;
  final first = points.first;
  final healthyDelta = (last.healthy - first.healthy).round();
  final trend = last.healthy > first.healthy ? 'recovering' : 'under pressure';
  return 'Disease spread is $trend. Healthiness is at ${last.healthy.toInt().round()}% '
      '(changed $healthyDelta pts since ${first.label}).';
}

class _DiseaseSpreadPainter extends CustomPainter {
  final List<_DiseaseTrendPoint> points;
  final int? selectedIndex;
  const _DiseaseSpreadPainter({required this.points, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const left = 34.0;
    const right = 20.0;
    const top = 42.0;
    const bottom = 34.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;
    const axisStyle = TextStyle(
      color: Color(0xFF8A948D),
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFFF0F2F5)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = top + height * i / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      final text = TextPainter(
        text: TextSpan(text: '${100 - i * 25}%', style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(left - text.width - 6, y - text.height / 2));
    }

    final span = points.length - 1;
    List<Offset> offsets(double Function(_DiseaseTrendPoint) value) =>
        List.generate(points.length, (i) {
          final x = span == 0 ? left + width / 2 : left + width * i / span;
          final y = top + height - value(points[i]) / 100 * height;
          return Offset(x, y);
        });

    final healthy = offsets((p) => p.healthy);
    final anthracnose = offsets((p) => p.anthracnose);
    final blister = offsets((p) => p.blisterBlight);
    final grey = offsets((p) => p.greyBlight);

    Path curve(List<Offset> values) {
      final path = Path()..moveTo(values.first.dx, values.first.dy);
      for (var i = 0; i < values.length - 1; i++) {
        final a = values[i];
        final b = values[i + 1];
        final midpoint = a.dx + (b.dx - a.dx) / 2.2;
        path.cubicTo(midpoint, a.dy, midpoint, b.dy, b.dx, b.dy);
      }
      return path;
    }

    final healthFill = Path.from(curve(healthy))
      ..lineTo(healthy.last.dx, top + height)
      ..lineTo(healthy.first.dx, top + height)
      ..close();
    canvas.drawPath(
      healthFill,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF2F6B4F).withValues(alpha: .14),
            const Color(0xFF2F6B4F).withValues(alpha: 0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(left, top, width, height)),
    );

    void drawLine(List<Offset> values, Color color) {
      canvas.drawPath(
        curve(values),
        Paint()
          ..color = color
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    drawLine(healthy, const Color(0xFF2F6B4F));
    drawLine(anthracnose, const Color(0xFFB54848));
    drawLine(blister, const Color(0xFFE69A2E));
    drawLine(grey, const Color(0xFF718096));

    for (var i = 0; i < points.length; i++) {
      final label = TextPainter(
        text: TextSpan(text: points[i].label, style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(healthy[i].dx - label.width / 2, size.height - 18),
      );
    }

    final selected = (selectedIndex ?? points.length - 1).clamp(
      0,
      points.length - 1,
    );
    final x = healthy[selected].dx;
    final marker = Paint()
      ..color = const Color(0xFFBFC7C1)
      ..strokeWidth = 1;
    for (double y = top; y < top + height; y += 7) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + 3, top + height)),
        marker,
      );
    }
    for (final item in [
      (healthy[selected], const Color(0xFF2F6B4F)),
      (anthracnose[selected], const Color(0xFFB54848)),
      (blister[selected], const Color(0xFFE69A2E)),
      (grey[selected], const Color(0xFF718096)),
    ]) {
      canvas.drawCircle(item.$1, 5, Paint()..color = item.$2);
      canvas.drawCircle(item.$1, 2.3, Paint()..color = Colors.white);
    }

    final point = points[selected];
    final tooltipX = x.clamp(72.0, size.width - 72.0);
    final tooltip = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(tooltipX, 22), width: 138, height: 40),
      const Radius.circular(8),
    );
    canvas.drawRRect(tooltip, Paint()..color = Colors.white);
    canvas.drawRRect(
      tooltip,
      Paint()..color = const Color(0xFFE4E9DE)..style = PaintingStyle.stroke,
    );
    final summary = TextPainter(
      text: TextSpan(
        text:
            '${point.label}  •  Healthy ${point.healthy.toInt()}%\n'
            'Anth. ${point.anthracnose.toInt()}%  Blister ${point.blisterBlight.toInt()}%  Grey ${point.greyBlight.toInt()}%',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 130);
    summary.paint(
      canvas,
      Offset(tooltipX - summary.width / 2, 22 - summary.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DiseaseSpreadPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.selectedIndex != selectedIndex;
}

class _InsightHeadingIcon extends StatelessWidget {
  final IconData icon;
  const _InsightHeadingIcon({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19),
      );
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _ChartRangeSelector extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChange;
  const _ChartRangeSelector({this.initial = '30D', required this.onChange});

  @override
  State<_ChartRangeSelector> createState() => _ChartRangeSelectorState();
}

class _ChartRangeSelectorState extends State<_ChartRangeSelector> {
  late String _selected;
  static const _options = ['7D', '30D', '90D'];

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  void didUpdateWidget(_ChartRangeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      _selected = widget.initial;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in _options)
              _ChartRangePill(
                label: label,
                active: _selected == label,
                onTap: () {
                  setState(() => _selected = label);
                  widget.onChange(label);
                },
              ),
          ],
        ),
      );
}

class _ChartRangePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _ChartRangePill({required this.label, this.active = false, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryButton : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
}

class _FieldStatusCard extends StatelessWidget {
  final double? diseasePressureScore;
  final String? status;
  const _FieldStatusCard({this.diseasePressureScore, this.status});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Disease pressure',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    diseasePressureScore != null
                        ? '${diseasePressureScore!.round()} / 100'
                        : '— / 100',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status ?? 'No trend data',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.trending_down_rounded,
              color: AppTheme.brandGreen,
              size: 38,
            ),
          ],
        ),
      );
}

class _ConfidenceSummary extends StatelessWidget {
  final List<FieldConfidenceSlice> slices;
  const _ConfidenceSummary({this.slices = const []});

  static const _colors = [
    AppTheme.primaryGreen,
    Color(0xFF718096),
    Color(0xFFD2D8D4),
    Color(0xFFB54848),
    Color(0xFFCC6633),
  ];

  @override
  Widget build(BuildContext context) {
    final values = slices.map((s) => s.percentage.toDouble()).toList();
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _ConfidencePainter(values: values, colors: _colors),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < slices.length; i++) ...[
                _ConfidenceLegendRow(
                  label: slices[i].label,
                  value: '${slices[i].percentage}%',
                  color: _colors[i % _colors.length],
                ),
                if (i != slices.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfidencePainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _ConfidencePainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final effective = values.where((v) => v > 0).toList();
    if (effective.isEmpty) {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.shortestSide / 2,
        Paint()..color = const Color(0xFFE9EEE9),
      );
      return;
    }
    var start = -math.pi / 2;
    final rect = Offset.zero & size;
    var idx = 0;
    for (final v in effective) {
      final sweep = v / 100 * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = colors[idx % colors.length],
      );
      start += sweep;
      idx++;
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      30,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _ConfidencePainter oldDelegate) =>
      oldDelegate.values != values;
}

class _ConfidenceLegendRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ConfidenceLegendRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _TreatmentResponseCard extends StatelessWidget {
  final List<FieldTreatmentResponse> rows;
  final String? insight;

  const _TreatmentResponseCard({required this.rows, this.insight});

  @override
  Widget build(BuildContext context) => _InsightCard(
        title: 'Treatment response',
        subtitle: 'Before and after the latest intervention',
        icon: Icons.medical_services_outlined,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              _ResponseRow(
                label: rows[i].label,
                before: rows[i].before,
                after: rows[i].after,
              ),
              if (i != rows.length - 1) const SizedBox(height: 14),
            ],
            if (insight != null && insight!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
}

class _ResponseRow extends StatelessWidget {
  final String label;
  final int before, after;
  const _ResponseRow({
    required this.label,
    required this.before,
    required this.after,
  });
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          _ResponseBar(
              label: 'Before', value: before, color: const Color(0xFF718096)),
          const SizedBox(height: 7),
          _ResponseBar(
              label: 'After', value: after, color: AppTheme.primaryGreen),
        ],
      );
}

class _ResponseBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ResponseBar({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 10.5),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              minHeight: 7,
              value: (value / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE8ECE9),
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text('$value', style: const TextStyle(fontSize: 11)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-level helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Maps the UI range label to a `days` value passed to the backend.
int _daysFromRange(String range) => switch (range) {
      '7D' => 7,
      '30D' => 30,
      '90D' => 90,
      _ => 30,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Field dropdown + field disease growth trend chart (estate view additions)
// ─────────────────────────────────────────────────────────────────────────────

class _FieldDropdown extends StatelessWidget {
  final List<Field> fields;
  final String? selectedFieldId;
  final ValueChanged<String?> onChanged;

  const _FieldDropdown({
    required this.fields,
    required this.selectedFieldId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentId = selectedFieldId;
    final isSet = currentId != null && currentId.isNotEmpty;

    // Look up the currently selected field name for the hint text.
    String? selectedName;
    if (isSet) {
      for (final f in fields) {
        if (f.id == currentId) {
          selectedName = f.name;
          break;
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DE)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: isSet ? currentId : null,
          hint: Text(
            selectedName ?? 'Select a field to view disease growth trend',
            style: TextStyle(
              color: selectedName != null
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          onChanged: onChanged,
          items: fields.isEmpty
              ? const <DropdownMenuItem<String>>[]
              : [
                  for (final field in fields)
                    DropdownMenuItem(
                      value: field.id,
                      child: Text(
                        field.name,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
          isExpanded: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          icon:
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary),
          iconDisabledColor: AppTheme.textSecondary,
          iconEnabledColor: AppTheme.primaryGreen,
        ),
      ),
    );
  }
}

/// One disease series plotted on the field disease-growth chart.
class _DiseaseSeries {
  final String name;
  final Color color;
  final List<double> values;

  const _DiseaseSeries({
    required this.name,
    required this.color,
    required this.values,
  });
}

/// Field-level disease growth trend chart shown in the estate view.
///
/// Fetches [FieldInsights] for [fieldId] and plots one line per disease
/// returned by the API.  No disease list is hardcoded — every disease that
/// appears in the response is rendered dynamically.
class _FieldDiseaseGrowthChart extends StatefulWidget {
  final String fieldId;
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const _FieldDiseaseGrowthChart({
    required this.fieldId,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  State<_FieldDiseaseGrowthChart> createState() => _FieldDiseaseGrowthChartState();
}

class _FieldDiseaseGrowthChartState extends State<_FieldDiseaseGrowthChart> {
  late Future<FieldInsights> _future;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(_FieldDiseaseGrowthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fieldId != widget.fieldId ||
        oldWidget.selectedRange != widget.selectedRange) {
      _fetch();
    }
  }

  void _fetch() {
    final days = _daysFromRange(widget.selectedRange);
    _future = DiseaseInsightsService.fetchFieldInsights(
      widget.fieldId,
      days: days,
    );
  }

  void _onRangeChanged(String range) {
    widget.onRangeChanged(range);
  }

  /// Builds the list of [_DiseaseSeries] from the API trend points.
  ///
  /// Every disease key found in any point's `diseaseDistribution` becomes a
  /// separate series.  "Healthy" is excluded — it is the background, not a
  /// disease.  The percentage for each disease is computed by
  /// [EstateDiseaseTrendPoint.getAllDiseasePercentages].
  List<_DiseaseSeries> _buildDiseaseSeries(List<EstateDiseaseTrendPoint> points) {
    if (points.isEmpty) return [];

    final diseaseNames = <String>{};
    for (final point in points) {
      for (final key in point.diseaseDistribution.keys) {
        final lower = key.toLowerCase();
        if (lower != 'healthy') {
          diseaseNames.add(key);
        }
      }
    }

    final List<_DiseaseSeries> series = [];
    for (final disease in diseaseNames) {
      final values = <double>[];
      for (final point in points) {
        final pct = point.getAllDiseasePercentages();
        values.add(pct[disease] ?? 0.0);
      }
      series.add(_DiseaseSeries(
        name: disease,
        color: DiseasePalette.colorFor(disease),
        values: values,
      ));
    }

    // Sort by name for deterministic legend order.
    series.sort((a, b) => a.name.compareTo(b.name));
    return series;
  }

  String _fieldName() {
    for (final f in FieldManager().fields) {
      if (f.id == widget.fieldId) return f.name;
    }
    return 'Selected field';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FieldInsights>(
      future: _future,
      builder: (context, snapshot) {
        final label = _fieldName();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _InsightCard(
            title: 'Field disease growth',
            subtitle: 'Disease trend for $label',
            icon: Icons.show_chart_rounded,
            child: const SizedBox(
              height: 270,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.brandGreen),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _InsightCard(
            title: 'Field disease growth',
            subtitle: 'Disease trend for $label',
            icon: Icons.show_chart_rounded,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load disease data for this field.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          );
        }

        final insights = snapshot.data!;
        final trendPoints = insights.getEffectiveDiseaseTrend();

        if (trendPoints.isEmpty) {
          return _InsightCard(
            title: 'Field disease growth',
            subtitle: 'Disease trend for ${insights.fieldName}',
            icon: Icons.show_chart_rounded,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No disease trend data available for this field yet.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          );
        }

        final series = _buildDiseaseSeries(trendPoints);

        return _InsightCard(
          title: 'Field disease growth',
          subtitle: 'Disease trend for ${insights.fieldName}',
          icon: Icons.show_chart_rounded,
          child: Column(
            children: [
              SizedBox(
                height: 265,
                child: LayoutBuilder(
                  builder: (context, constraints) => CustomPaint(
                    size: Size.infinite,
                    painter: _FieldDiseaseTrendPainter(
                      points: trendPoints,
                      series: series,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (series.isNotEmpty)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final s in series)
                      _ChartLegend(color: s.color, label: s.name),
                  ],
                ),
              if (series.isNotEmpty) const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _ChartRangeSelector(
                  initial: widget.selectedRange,
                  onChange: _onRangeChanged,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter that draws multiple disease trend lines on a shared
/// time axis.  Lines are generated dynamically from the [series] list — no
/// disease is hardcoded.
class _FieldDiseaseTrendPainter extends CustomPainter {
  final List<EstateDiseaseTrendPoint> points;
  final List<_DiseaseSeries> series;

  const _FieldDiseaseTrendPainter({
    required this.points,
    required this.series,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 34.0;
    const right = 20.0;
    const top = 42.0;
    const bottom = 34.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;

    const axisStyle = TextStyle(
      color: Color(0xFF8A948D),
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFFF0F2F5)
      ..strokeWidth = 1;

    // Grid + Y-axis labels
    for (var i = 0; i < 5; i++) {
      final y = top + height * i / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      final axis = TextPainter(
        text: TextSpan(text: '${100 - i * 25}%', style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      axis.paint(
        canvas,
        Offset(left - axis.width - 6, y - axis.height / 2),
      );
    }

    // X positions for each time point
    final span = points.length - 1;
    List<Offset> offsets(List<double> values) {
      return List.generate(values.length, (i) {
        final x = span == 0 ? left + width / 2 : left + width * i / span;
        final clamped = values[i].clamp(0.0, 100.0);
        final y = top + height - clamped / 100 * height;
        return Offset(x, y);
      });
    }

    Path curve(List<Offset> values) {
      if (values.isEmpty) return Path();
      final path = Path()..moveTo(values.first.dx, values.first.dy);
      for (var i = 0; i < values.length - 1; i++) {
        final a = values[i];
        final b = values[i + 1];
        final midpoint = a.dx + (b.dx - a.dx) / 2.2;
        path.cubicTo(midpoint, a.dy, midpoint, b.dy, b.dx, b.dy);
      }
      return path;
    }

    // Draw each disease line
    for (final s in series) {
      final pts = offsets(s.values);
      canvas.drawPath(
        curve(pts),
        Paint()
          ..color = s.color
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    // X-axis date labels
    for (var i = 0; i < points.length; i++) {
      final label = TextPainter(
        text: TextSpan(text: points[i].label, style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = span == 0 ? left + width / 2 : left + width * i / span;
      label.paint(
        canvas,
        Offset(x - label.width / 2, size.height - 18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FieldDiseaseTrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.series != series;
}
