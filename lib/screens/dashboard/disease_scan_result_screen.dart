import 'package:flutter/material.dart';

import '../../models/field_model.dart';
import '../../theme.dart';

class DiseaseScanResultScreen extends StatefulWidget {
  final String fieldId;
  final String? imagePath;
  final DiseaseScanResult? scanResult;

  const DiseaseScanResultScreen({
    super.key,
    required this.fieldId,
    this.imagePath,
    this.scanResult,
  });

  @override
  State<DiseaseScanResultScreen> createState() =>
      _DiseaseScanResultScreenState();
}

class _DiseaseScanResultScreenState extends State<DiseaseScanResultScreen> {
  late final DiseaseScanResult _scanResult;

  @override
  void initState() {
    super.initState();
    _scanResult = widget.scanResult ?? _generateDummyResult();
  }

  /// Check if the scan classifies as a healthy leaf (no disease detected).
  /// Prefers the backend's `classification.level`, falling back to the old
  /// heuristic (top confidence-analysis entry named "Healthy") for
  /// responses that don't include a classification block.
  bool _isHealthyResult() {
    if (_scanResult.classification != null) {
      return _scanResult.classification!.isHealthy;
    }
    return _scanResult.diseaseResults.isNotEmpty &&
        _scanResult.diseaseResults.first.name.toLowerCase() == 'healthy';
  }

  DiseaseScanResult _generateDummyResult() {
    return DiseaseScanResult(
      fieldId: widget.fieldId,
      imagePath: widget.imagePath,
      detectedAt: DateTime.now(),
      weather: WeatherSnapshot(
        date: DateTime.now(),
        summary: 'Partly cloudy',
        rainChance: 42,
        humidity: 78,
        temperatureC: 24.5,
        stormRisk: false,
      ),
      classification: const DiseaseClassification(
        level: 'disease',
        label: 'Blister Blight',
        confidence: 0.65,
        category: 'Fungal Disease',
        message: 'Detected Blister Blight with moderate confidence.',
      ),
      mostProbableDisease: const MostProbableDisease(
        diseaseName: 'Blister Blight',
        confidence: 0.65,
        severity: 'high',
        description:
            'Fungal disease causing small, water-soaked blisters on leaves that later turn brown and necrotic.',
        causes: [
          'Fungal infection favored by high humidity and prolonged leaf wetness',
          'Cool, wet weather with frequent rainfall',
          'Poor air circulation within the canopy',
        ],
      ),
      diseaseResults: const [
        DiseaseResult(
          name: 'Blister Blight',
          confidence: 65,
          confidenceLabel: 'Moderate',
          category: 'Fungal Disease',
        ),
        DiseaseResult(
          name: 'Tea Mosquito Bug',
          confidence: 18,
          confidenceLabel: 'Low',
          category: 'Pest Damage',
        ),
        DiseaseResult(
          name: 'Red Leaf Spot',
          confidence: 12,
          confidenceLabel: 'Low',
          category: 'Bacterial Disease',
        ),
      ],
      recommendations: const [
        'Remove and destroy infected leaves immediately',
        'Apply copper-based fungicides during outbreak periods',
        'Improve air circulation by proper pruning',
        'Avoid overhead irrigation',
      ],
    );
  }

  void _navigateToRecommendations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiseaseRecommendationScreen(
          diseaseName:
              _scanResult.mostProbableDisease?.diseaseName ??
              _scanResult.diseaseResults.first.name,
          confidence:
              _scanResult.mostProbableDisease?.confidencePercent ??
              _scanResult.diseaseResults.first.confidence,
          recommendations: _scanResult.recommendations,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Field? field = FieldManager().fields
        .where((f) => f.id == widget.fieldId)
        .toList()
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Scan Results',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Section
            _ScanSummaryCard(field: field, scanResult: _scanResult),
            const SizedBox(height: 20),

            // Classification banner (new) — top-line verdict from the
            // `classification` block returned by the scan endpoint.
            if (_scanResult.classification != null) ...[
              _ClassificationBanner(
                classification: _scanResult.classification!,
              ),
              const SizedBox(height: 20),
            ],

            // Healthy Result Card (positive outcome)
            if (_isHealthyResult()) ...[
              _HealthyLeafCard(
                confidence:
                    _scanResult.mostProbableDisease?.confidencePercent ??
                    _scanResult.classification?.confidencePercent ??
                    (_scanResult.diseaseResults.isNotEmpty
                        ? _scanResult.diseaseResults.first.confidence
                        : 0),
                message: _scanResult.classification?.message,
              ),
            ] else if (_scanResult.diseaseResults.isNotEmpty) ...[
              // Most Probable Disease (disease result)
              if (_scanResult.mostProbableDisease != null)
                _MostProbableDiseaseCard(
                  disease: _scanResult.mostProbableDisease!,
                )
              else
                _MostProbableDiseaseCard(
                  disease: MostProbableDisease(
                    diseaseName: _scanResult.diseaseResults.first.name,
                    confidence:
                        _scanResult.diseaseResults.first.confidence / 100,
                    severity: '',
                    description: '',
                    causes: const [],
                  ),
                ),
              const SizedBox(height: 20),

              // Confidence Analysis
              _ConfidenceAnalysisCard(
                diseaseResults: _scanResult.diseaseResults,
              ),
              const SizedBox(height: 20),

              // Recommendations (global list from the API, no longer
              // per-disease symptoms/treatment)
              if (_scanResult.recommendations.isNotEmpty) ...[
                _RecommendationsCard(
                  recommendations: _scanResult.recommendations,
                ),
                const SizedBox(height: 24),
              ],

              // Recommendation Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _navigateToRecommendations,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.recommend_outlined, size: 18),
                  label: const Text(
                    'View Recommendations',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ] else ...[
              // No results placeholder
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.brandGreen,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Diseases Detected',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The scan completed but no disease patterns were identified in the image.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Top-level classification returned by the scan endpoint, e.g.
/// { "level": "disease", "label": "Blister Blight", "confidence": 0.98,
///   "category": "Fungal Disease", "message": "Detected ... " }
class DiseaseClassification {
  final String level;
  final String label;
  final double confidence;
  final String category;
  final String message;

  const DiseaseClassification({
    required this.level,
    required this.label,
    required this.confidence,
    required this.category,
    required this.message,
  });

  factory DiseaseClassification.fromJson(Map<String, dynamic> json) {
    return DiseaseClassification(
      level: json['level']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }

  int get confidencePercent => (confidence * 100).round();

  bool get isHealthy => level.toLowerCase() == 'healthy';
}

/// The single highest-confidence disease from `most_probable_disease`,
/// including severity/description/causes not present on the plain
/// confidence_analysis entries.
class MostProbableDisease {
  final String diseaseName;
  final double confidence;
  final String severity;
  final String description;
  final List<String> causes;

  const MostProbableDisease({
    required this.diseaseName,
    required this.confidence,
    required this.severity,
    required this.description,
    this.causes = const [],
  });

  factory MostProbableDisease.fromJson(Map<String, dynamic> json) {
    return MostProbableDisease(
      diseaseName: json['disease_name']?.toString() ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      severity: json['severity']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      causes: (json['causes'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }

  int get confidencePercent => (confidence * 100).round();
}

class DiseaseScanResult {
  final String fieldId;
  final String? imagePath;
  final DateTime detectedAt;
  final String? scanId;
  final String? fieldName;
  final String? remoteImageUrl;
  final WeatherSnapshot? weather;
  final DiseaseClassification? classification;
  final MostProbableDisease? mostProbableDisease;
  final List<DiseaseResult> diseaseResults;
  final List<String> recommendations;

  const DiseaseScanResult({
    required this.fieldId,
    this.imagePath,
    required this.detectedAt,
    this.scanId,
    this.fieldName,
    this.remoteImageUrl,
    this.weather,
    this.classification,
    this.mostProbableDisease,
    required this.diseaseResults,
    this.recommendations = const [],
  });
}

/// One entry from `confidence_analysis`. Note this no longer carries
/// symptoms/treatment text — that detail now lives only on
/// `most_probable_disease` (causes/description) and the shared
/// top-level `recommendations` list.
class DiseaseResult {
  final String name;
  final int confidence;
  final String confidenceLabel;
  final String category;

  const DiseaseResult({
    required this.name,
    required this.confidence,
    this.confidenceLabel = '',
    this.category = '',
  });
}

class _ScanSummaryCard extends StatelessWidget {
  final Field? field;
  final DiseaseScanResult scanResult;

  const _ScanSummaryCard({required this.field, required this.scanResult});

  @override
  Widget build(BuildContext context) {
    final displayFieldName = scanResult.fieldName ?? field?.name;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppTheme.brandGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Scan Summary',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (displayFieldName != null)
            _SummaryRow(
              label: 'Field',
              value: displayFieldName,
              icon: Icons.agriculture_outlined,
            ),
          if (displayFieldName != null) const SizedBox(height: 10),
          _SummaryRow(
            label: 'Date',
            value: _formatDate(scanResult.detectedAt),
            icon: Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Time',
            value: _formatTime(scanResult.detectedAt),
            icon: Icons.access_time_outlined,
          ),
          const SizedBox(height: 10),
          if (scanResult.weather != null)
            _SummaryRow(
              label: 'Weather',
              value: _buildWeatherSummary(scanResult.weather!),
              icon: Icons.cloud_outlined,
            ),
          if (scanResult.weather != null) const SizedBox(height: 10),
          if (scanResult.scanId != null) ...[
            _SummaryRow(
              label: 'Scan ID',
              value: scanResult.scanId!,
              icon: Icons.qr_code_outlined,
            ),
            const SizedBox(height: 10),
          ],
          _SummaryRow(
            label: 'Image',
            value:
                scanResult.imagePath != null ||
                    scanResult.remoteImageUrl != null
                ? 'Captured'
                : 'Not available',
            icon: Icons.image_outlined,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _buildWeatherSummary(WeatherSnapshot weather) {
    return '${weather.temperatureC.toStringAsFixed(1)}°C • ${weather.humidity}% humidity';
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        const Text(':', style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Colors/icon for a severity or classification level string. Shared by
/// the classification banner and the most-probable-disease card.
(Color, IconData) _levelStyle(String level) {
  switch (level.toLowerCase()) {
    case 'healthy':
      return (const Color(0xFF22C55E), Icons.check_circle_rounded);
    case 'high':
    case 'disease':
      return (const Color(0xFFB54848), Icons.dangerous_rounded);
    case 'medium':
    case 'pest':
      return (const Color(0xFFE2574C), Icons.warning_rounded);
    case 'low':
      return (const Color(0xFFB97922), Icons.info_rounded);
    default:
      return (AppTheme.textSecondary, Icons.help_outline_rounded);
  }
}

/// Banner surfacing the top-level `classification` verdict returned by the
/// scan endpoint (level / label / confidence / message).
class _ClassificationBanner extends StatelessWidget {
  final DiseaseClassification classification;

  const _ClassificationBanner({required this.classification});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _levelStyle(classification.level);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        classification.label.isNotEmpty
                            ? classification.label
                            : classification.level,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                    if (classification.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          classification.category,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                  ],
                ),
                if (classification.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    classification.message,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: color.withValues(alpha: 0.9),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MostProbableDiseaseCard extends StatelessWidget {
  final MostProbableDisease disease;

  const _MostProbableDiseaseCard({required this.disease});

  @override
  Widget build(BuildContext context) {
    final (severityColor, _) = _levelStyle(disease.severity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: Color(0xFFB54848),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Most Probable Disease',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD5D5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        disease.diseaseName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF7A2713),
                          letterSpacing: -0.5,
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
                        '${disease.confidencePercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (disease.severity.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Severity: ${disease.severity}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A2713),
                    ),
                  ),
                ],
                if (disease.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    disease.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF7A2713).withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ],
                if (disease.causes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Likely Causes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7A2713),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...disease.causes.map(
                    (cause) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFFB54848),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cause,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: const Color(
                                  0xFF7A2713,
                                ).withValues(alpha: 0.85),
                                height: 1.45,
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
          ),
        ],
      ),
    );
  }
}

class _HealthyLeafCard extends StatelessWidget {
  final int confidence;
  final String? message;

  const _HealthyLeafCard({required this.confidence, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandGreen.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: Color(0xFF22C55E), size: 20),
              SizedBox(width: 8),
              Text(
                'Healthy Leaf',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'No Disease Detected',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF166534),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$confidence%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  message?.isNotEmpty == true
                      ? message!
                      : 'The leaf appears healthy with no visible signs of disease or pest infection. Continue regular monitoring and maintain good agricultural practices.',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF166534).withValues(alpha: 0.8),
                    height: 1.5,
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

class _ConfidenceAnalysisCard extends StatelessWidget {
  final List<DiseaseResult> diseaseResults;

  const _ConfidenceAnalysisCard({required this.diseaseResults});

  @override
  Widget build(BuildContext context) {
    final topConfidence = diseaseResults.isNotEmpty
        ? diseaseResults
              .map((d) => d.confidence)
              .reduce((a, b) => a > b ? a : b)
        : 0;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: AppTheme.brandGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Confidence Analysis',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...diseaseResults.map(
            (disease) => _ConfidenceBar(
              disease: disease,
              isTopResult: disease.confidence == topConfidence,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final DiseaseResult disease;
  final bool isTopResult;

  const _ConfidenceBar({required this.disease, required this.isTopResult});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disease.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isTopResult
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isTopResult
                            ? const Color(0xFFB54848)
                            : AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (disease.category.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        disease.category,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${disease.confidence}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isTopResult ? FontWeight.w900 : FontWeight.w700,
                  color: isTopResult
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
              widthFactor: (disease.confidence / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isTopResult
                        ? [const Color(0xFFB54848), const Color(0xFFE2574C)]
                        : [
                            const Color(0xFF6E7E8B).withValues(alpha: 0.5),
                            const Color(0xFF6E7E8B).withValues(alpha: 0.3),
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
  }
}

/// Displays the flat, top-level `recommendations` list returned by the
/// scan endpoint. This replaces the old per-disease "AI Explanation"
/// symptoms/treatment section, since the new API no longer returns
/// per-disease treatment text.
class _RecommendationsCard extends StatelessWidget {
  final List<String> recommendations;

  const _RecommendationsCard({required this.recommendations});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                color: AppTheme.brandGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...recommendations.map(
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

// Recommendation screen — now shows the real recommendations from the
// scan response when provided, falling back to static guidance if not.
class DiseaseRecommendationScreen extends StatelessWidget {
  final String diseaseName;
  final int confidence;
  final List<String> recommendations;

  const DiseaseRecommendationScreen({
    super.key,
    required this.diseaseName,
    required this.confidence,
    this.recommendations = const [],
  });

  List<_RecommendationItem> get _items {
    if (recommendations.isNotEmpty) {
      const icons = [
        Icons.eco_outlined,
        Icons.cut_outlined,
        Icons.visibility_outlined,
        Icons.water_drop_outlined,
        Icons.shield_outlined,
      ];
      return List.generate(
        recommendations.length,
        (i) => _RecommendationItem(
          title: recommendations[i],
          description: '',
          icon: icons[i % icons.length],
        ),
      );
    }

    return const [
      _RecommendationItem(
        title: 'Apply fungicide',
        description:
            'Use copper-based fungicides bi-weekly until symptoms clear.',
        icon: Icons.eco_outlined,
      ),
      _RecommendationItem(
        title: 'Improve air circulation',
        description:
            'Prune surrounding vegetation to reduce humidity around plants.',
        icon: Icons.cut_outlined,
      ),
      _RecommendationItem(
        title: 'Monitor regularly',
        description: 'Check plants every 3-4 days for spread of infection.',
        icon: Icons.visibility_outlined,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Recommendations',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diseaseName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB54848),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Detected with $confidence% confidence',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Recommended Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (int i = 0; i < _items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _items[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _RecommendationItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.brandGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppTheme.brandGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
