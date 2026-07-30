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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.fieldName != null
              ? 'History · ${widget.fieldName}'
              : 'Detection History',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DiseaseScanRecord>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
              padding: const EdgeInsets.all(16),
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

    final primaryUrl = DiseaseScanService.resolveImageUrl(record.primaryImageUrl);
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
                            horizontal: 6, vertical: 2),
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
                            horizontal: 8, vertical: 3),
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
        elevation: 0,
        title: const Text(
          'Scan Details',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<DiseaseScanRecord>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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

                // All Predictions / Confidence Breakdown
                if (record.allPredictions.isNotEmpty) ...[
                  _PredictionsCard(predictions: record.allPredictions),
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
              const Icon(Icons.photo_library_outlined,
                  color: AppTheme.brandGreen, size: 18),
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
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
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
        Icon(icon, color: AppTheme.brandGreen, size: 20),
        const SizedBox(width: 8),
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
                  '${record.confidencePercent}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Severity: ${record.severity.toUpperCase()}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
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

  @override
  Widget build(BuildContext context) {
    final sorted = [...predictions]
      ..sort((a, b) => b.probability.compareTo(a.probability));
    final top = sorted.isNotEmpty ? sorted.first.probability : 0.0;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Detection Confidence',
            icon: Icons.analytics_outlined,
          ),
          const SizedBox(height: 16),
          ...sorted.map((p) {
            final isTop = p.probability == top;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p.disease,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isTop
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isTop
                                ? const Color(0xFFB54848)
                                : AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${p.percent}%',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isTop
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: isTop
                              ? const Color(0xFFB54848)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: p.probability.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isTop
                                ? [
                                    const Color(0xFFB54848),
                                    const Color(0xFFE2574C),
                                  ]
                                : [
                                    const Color(
                                      0xFF6E7E8B,
                                    ).withValues(alpha: 0.5),
                                    const Color(
                                      0xFF6E7E8B,
                                    ).withValues(alpha: 0.3),
                                  ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
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
          if (environmentalSummary != null && environmentalSummary!.isNotEmpty) ...[
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
            ...allFactors.take(5).map((factor) => Padding(
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
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: factor.isRiskIncreasing
                              ? const Color(0xFFB54848).withValues(alpha: 0.1)
                              : const Color(0xFF22C55E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          factor.isRiskIncreasing ? '↑ Increase Risk' : '↓ Decrease Risk',
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
                )),
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