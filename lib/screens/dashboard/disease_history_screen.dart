import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/disease_scan_record.dart';
import '../../services/disease_scan_service.dart';
import '../../theme.dart';

/// Detection History screen for a single field.
/// Fetches GET /api/v1/disease/by-field/{field_id} and renders each scan as a
/// tappable card. Tapping a card opens [DiseaseScanDetailScreen], which
/// fetches GET /api/v1/disease/{id} for the full record.
class DiseaseHistoryScreen extends StatefulWidget {
  final String fieldId;
  final String? fieldName;

  const DiseaseHistoryScreen({
    super.key,
    required this.fieldId,
    this.fieldName,
  });

  @override
  State<DiseaseHistoryScreen> createState() => _DiseaseHistoryScreenState();
}

class _DiseaseHistoryScreenState extends State<DiseaseHistoryScreen> {
  late Future<List<DiseaseScanRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = DiseaseScanService.fetchScansByField(widget.fieldId);
  }

  Future<void> _refresh() async {
    final future = DiseaseScanService.fetchScansByField(widget.fieldId);
    setState(() => _future = future);
    await future;
  }

  void _openDetail(DiseaseScanRecord record) {
    final targetId = record.scanId.isNotEmpty ? record.scanId : record.id;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiseaseScanDetailScreen(scanRecordId: targetId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          widget.fieldName != null
              ? 'History · ${widget.fieldName}'
              : 'Detection History',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DiseaseScanRecord>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.brandGreen),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: _ErrorState(
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                    ),
                  ),
                ],
              );
            }

            final records = snapshot.data ?? const [];

            if (records.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const Center(
                      child: Text(
                        'No detection records yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = records[index];
                return _DetectionRecordCard(
                  record: record,
                  onTap: () => _openDetail(record),
                );
              },
            );
          },
        ),
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
          mainAxisAlignment: MainAxisAlignment.center,
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

(Color, IconData) _severityStyle(String severity, bool isHealthy) {
  if (isHealthy) {
    return (AppTheme.brandGreen, Icons.check_circle_rounded);
  }
  switch (severity.toLowerCase()) {
    case 'high':
      return (const Color(0xFFD95C5C), Icons.dangerous_rounded);
    case 'medium':
      return (const Color(0xFFE2574C), Icons.warning_rounded);
    case 'low':
      return (const Color(0xFFB97922), Icons.info_rounded);
    default:
      return (AppTheme.textSecondary, Icons.help_outline_rounded);
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _DetectionRecordCard extends StatelessWidget {
  final DiseaseScanRecord record;
  final VoidCallback onTap;

  const _DetectionRecordCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (severityColor, severityIcon) = _severityStyle(
      record.severity,
      record.isHealthy,
    );

    final primaryUrl = DiseaseScanService.resolveImageUrl(
      record.primaryImageUrl,
    );
    final imageCount = record.imageUrls.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E9DE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail image if present
            if (primaryUrl != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      primaryUrl,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 76,
                        height: 76,
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppTheme.textSecondary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  if (imageCount > 1)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$imageCount photos',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
            ],

            // Content details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(severityIcon, color: severityColor, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          record.detectedDisease,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${record.confidencePercent}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: severityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(record.scanDatetime),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (record.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      record.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Text(
                        'Tap for details',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brandGreen,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppTheme.brandGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full detail view for a single disease scan record.
/// Fetches GET /api/v1/disease/{id}.
class DiseaseScanDetailScreen extends StatefulWidget {
  final String scanRecordId;

  const DiseaseScanDetailScreen({super.key, required this.scanRecordId});

  @override
  State<DiseaseScanDetailScreen> createState() =>
      _DiseaseScanDetailScreenState();
}

class _DiseaseScanDetailScreenState extends State<DiseaseScanDetailScreen> {
  late Future<DiseaseScanRecord> _future;

  @override
  void initState() {
    super.initState();
    _future = DiseaseScanService.fetchScanById(widget.scanRecordId);
  }

  Future<void> _refresh() async {
    final future = DiseaseScanService.fetchScanById(widget.scanRecordId);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Scan Details',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: FutureBuilder<DiseaseScanRecord>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.brandGreen),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final record = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scanned images gallery
                if (record.imageUrls.isNotEmpty)
                  _ScanImageGallery(imageUrls: record.imageUrls),
                if (record.imageUrls.isNotEmpty) const SizedBox(height: 20),

                // Main Header card
                _DetailHeaderCard(record: record),
                const SizedBox(height: 20),

                if (record.allPredictions.isNotEmpty) ...[
                  _PredictionsCard(predictions: record.allPredictions),
                  const SizedBox(height: 20),
                ],

                // Risk assessment
                if (record.riskLevel != null || record.riskReason != null) ...[
                  _RiskCard(record: record),
                  const SizedBox(height: 20),
                ],

                // Treatment Suggestions
                if (record.treatmentSuggestions.isNotEmpty) ...[
                  _TreatmentCard(suggestions: record.treatmentSuggestions),
                  const SizedBox(height: 20),
                ],

                // Weather Summary
                if (record.weatherSummary != null) ...[
                  _WeatherCard(weather: record.weatherSummary!),
                  const SizedBox(height: 20),
                ],

                // AI Explanation Data (GradCAM & Environmental Factors)
                if (record.explanationData != null ||
                    record.environmentalSummary != null) ...[
                  _ExplanationCard(
                    explanationData: record.explanationData,
                    environmentalSummary: record.environmentalSummary,
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScanImageGallery extends StatelessWidget {
  final List<String> imageUrls;

  const _ScanImageGallery({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    final resolvedUrls = imageUrls
        .map((u) => DiseaseScanService.resolveImageUrl(u))
        .whereType<String>()
        .toList();

    if (resolvedUrls.isEmpty) return const SizedBox.shrink();

    if (resolvedUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Image.network(
            resolvedUrls.first,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF3F4F6),
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                color: AppTheme.brandGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${resolvedUrls.length} Scanned Images',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: resolvedUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    resolvedUrls[i],
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 160,
                      height: 160,
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DE), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.brandGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.accentGreenText, size: 19),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _DetailHeaderCard extends StatelessWidget {
  final DiseaseScanRecord record;

  const _DetailHeaderCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final (severityColor, _) = _severityStyle(
      record.severity,
      record.isHealthy,
    );

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI DIAGNOSIS',
            style: TextStyle(
              color: AppTheme.accentGreenText,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  record.detectedDisease,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: record.isHealthy
                        ? const Color(0xFF166534)
                        : const Color(0xFF7A2713),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  record.isHealthy ? 'HEALTHY' : record.severity.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (record.description.isNotEmpty)
            Text(
              record.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatDate(record.scanDatetime)} · '
                '${record.scanDatetime.hour.toString().padLeft(2, '0')}:'
                '${record.scanDatetime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (record.scanId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.qr_code_outlined,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.scanId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final DiseaseScanRecord record;

  const _RiskCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Risk Assessment',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 12),
          if (record.riskLevel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFCE3A8)),
              ),
              child: Text(
                record.riskLevel!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB97922),
                ),
              ),
            ),
          if (record.riskReason != null) ...[
            const SizedBox(height: 10),
            Text(
              record.riskReason!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final DiseaseWeatherSummary weather;

  const _WeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      if (weather.totalRainfallLast7 != null)
        MapEntry('Total Rainfall (7d)', '${weather.totalRainfallLast7} mm'),
      if (weather.avgTemperatureLast7 != null)
        MapEntry('Avg Temperature (7d)', '${weather.avgTemperatureLast7}°C'),
      if (weather.avgHumidityLast7 != null)
        MapEntry('Avg Humidity (7d)', '${weather.avgHumidityLast7}%'),
      if (weather.avgWindSpeedLast7 != null)
        MapEntry('Avg Wind Speed (7d)', '${weather.avgWindSpeedLast7} km/h'),
      if (weather.avgSunshineHoursLast7 != null)
        MapEntry('Avg Sunshine (7d)', '${weather.avgSunshineHoursLast7} hrs'),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: '7-Day Weather Conditions',
            icon: Icons.cloud_outlined,
          ),
          const SizedBox(height: 14),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row.key,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    row.value,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionsCard extends StatelessWidget {
  final List<DiseasePrediction> predictions;

  const _PredictionsCard({required this.predictions});

  static const _chartColors = <Color>[
    AppTheme.primaryGreen,
    AppTheme.brandGreen,
    Color(0xFFE69A2E),
    Color(0xFF5F6C7B),
    Color(0xFF8FA79E),
    Color(0xFFB7C5BE),
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = [...predictions]
      ..sort((a, b) => b.probability.compareTo(a.probability));
    final chartPredictions = sorted
        .where((prediction) => prediction.probability > 0)
        .toList();
    final topPrediction = sorted.first;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Detection Confidence',
            icon: Icons.donut_large_rounded,
          ),
          const SizedBox(height: 6),
          const Text(
            'Probability distribution across the detected conditions.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final chart = _ConfidenceDonut(
                predictions: chartPredictions,
                colors: _chartColors,
                topPrediction: topPrediction,
              );
              final legend = _ConfidenceLegend(
                predictions: sorted,
                colors: _chartColors,
              );

              if (constraints.maxWidth < 350) {
                return Column(
                  children: [
                    Center(child: chart),
                    const SizedBox(height: 22),
                    legend,
                  ],
                );
              }
              return Row(
                children: [
                  chart,
                  const SizedBox(width: 22),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConfidenceDonut extends StatelessWidget {
  final List<DiseasePrediction> predictions;
  final List<Color> colors;
  final DiseasePrediction topPrediction;

  const _ConfidenceDonut({
    required this.predictions,
    required this.colors,
    required this.topPrediction,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${topPrediction.disease}, ${topPrediction.percent} percent confidence',
      child: SizedBox(
        width: 138,
        height: 138,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(138),
              painter: _ConfidenceDonutPainter(
                values: predictions
                    .map((prediction) => prediction.probability)
                    .toList(),
                colors: colors,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${topPrediction.percent}%',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const Text(
                  'TOP MATCH',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceLegend extends StatelessWidget {
  final List<DiseasePrediction> predictions;
  final List<Color> colors;

  const _ConfidenceLegend({required this.predictions, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: predictions.asMap().entries.map((entry) {
        final index = entry.key;
        final prediction = entry.value;
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == predictions.length - 1 ? 0 : 11,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[index % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prediction.disease,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: index == 0
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: index == 0 ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${prediction.percent}%',
                style: TextStyle(
                  color: colors[index % colors.length],
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ConfidenceDonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  const _ConfidenceDonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 16) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final trackPaint = Paint()
      ..color = const Color(0xFFE9EEE9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawCircle(center, radius, trackPaint);

    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    const gap = 0.025;
    for (var index = 0; index < values.length; index++) {
      final sweep = (values[index] / total) * math.pi * 2;
      final visibleSweep = math.max(0.0, sweep - gap);
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16;
      canvas.drawArc(rect, startAngle + gap / 2, visibleSweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _ConfidenceDonutPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

class _TreatmentCard extends StatelessWidget {
  final List<String> suggestions;

  const _TreatmentCard({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Treatment & Recommendations',
            icon: Icons.tips_and_updates_outlined,
          ),
          const SizedBox(height: 14),
          ...suggestions.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final s = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.brandGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$idx',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.brandGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppTheme.textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final ExplanationData? explanationData;
  final String? environmentalSummary;

  const _ExplanationCard({
    required this.explanationData,
    this.environmentalSummary,
  });

  @override
  Widget build(BuildContext context) {
    final aggregatedGradcamUrl = DiseaseScanService.resolveImageUrl(
      explanationData?.aggregatedGradcam,
    );

    // Collect all environmental factors across images
    final allFactors = <EnvironmentFactor>[];
    if (explanationData != null) {
      for (final img in explanationData!.perImage) {
        allFactors.addAll(img.environmentFactors);
      }
    }

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'AI Explanation & Insights',
            icon: Icons.science_outlined,
          ),
          if (environmentalSummary != null &&
              environmentalSummary!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              environmentalSummary!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],

          // GradCAM attention map
          if (aggregatedGradcamUrl != null) ...[
            const SizedBox(height: 14),
            const Text(
              'AI Attention Map (GradCAM)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                aggregatedGradcamUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  color: const Color(0xFFF3F4F6),
                  child: const Center(
                    child: Text(
                      'Attention map unavailable',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Environmental factors
          if (allFactors.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Key Environmental Factors',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...allFactors
                .take(5)
                .map(
                  (factor) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatFeatureName(factor.feature),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: factor.isRiskIncreasing
                                ? const Color(0xFFB54848).withValues(alpha: 0.1)
                                : const Color(
                                    0xFF22C55E,
                                  ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            factor.isRiskIncreasing
                                ? '↑ Increase Risk'
                                : '↓ Decrease Risk',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: factor.isRiskIncreasing
                                  ? const Color(0xFFB54848)
                                  : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  String _formatFeatureName(String feature) {
    switch (feature) {
      case 'avg_wind_speed_last_7':
        return 'Wind Speed';
      case 'avg_temperature_last_7':
        return 'Temperature';
      case 'total_rainfall_last_7':
        return 'Rainfall';
      case 'avg_humidity_last_7':
        return 'Humidity';
      case 'avg_sunshine_hours_last_7':
        return 'Sunshine Hours';
      default:
        return feature.replaceAll('_', ' ');
    }
  }
}
