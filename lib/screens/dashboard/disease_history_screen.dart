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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiseaseScanDetailScreen(scanRecordId: record.id),
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

/// Returns (color, icon) for a given severity string.
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(severityIcon, color: severityColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.detectedDisease,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${record.confidencePercent}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: severityColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(record.scanDatetime),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            if (record.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Tap for details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
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
                if (record.imageUrl != null)
                  _ScanImage(url: DiseaseScanService.resolveImageUrl(
                    record.imageUrl,
                  )),
                if (record.imageUrl != null) const SizedBox(height: 20),
                _DetailHeaderCard(record: record),
                const SizedBox(height: 20),
                if (record.riskLevel != null || record.riskReason != null)
                  _RiskCard(record: record),
                if (record.riskLevel != null || record.riskReason != null)
                  const SizedBox(height: 20),
                if (record.weatherSummary != null)
                  _WeatherCard(weather: record.weatherSummary!),
                if (record.weatherSummary != null)
                  const SizedBox(height: 20),
                if (record.allPredictions.isNotEmpty)
                  _PredictionsCard(predictions: record.allPredictions),
                if (record.allPredictions.isNotEmpty)
                  const SizedBox(height: 20),
                if (record.treatmentSuggestions.isNotEmpty)
                  _TreatmentCard(suggestions: record.treatmentSuggestions),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScanImage extends StatelessWidget {
  final String? url;

  const _ScanImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
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
            'Severity: ${record.severity}',
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
        MapEntry('Rainfall (7d)', '${weather.totalRainfallLast7} mm'),
      if (weather.avgTemperatureLast7 != null)
        MapEntry('Avg. Temp (7d)', '${weather.avgTemperatureLast7}°C'),
      if (weather.avgHumidityLast7 != null)
        MapEntry('Avg. Humidity (7d)', '${weather.avgHumidityLast7}%'),
      if (weather.avgWindSpeedLast7 != null)
        MapEntry('Avg. Wind (7d)', '${weather.avgWindSpeedLast7} km/h'),
      if (weather.avgSunshineHoursLast7 != null)
        MapEntry('Sunshine (7d)', '${weather.avgSunshineHoursLast7} hrs'),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Weather Summary',
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
            title: 'All Predictions',
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
                            fontSize: 13,
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
                          fontSize: 13,
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
            title: 'Treatment Suggestions',
            icon: Icons.medical_services_outlined,
          ),
          const SizedBox(height: 14),
          ...suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.brandGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
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