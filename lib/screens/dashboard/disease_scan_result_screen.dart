import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/field_model.dart';
import '../../services/disease_scan_service.dart';
import '../../theme.dart';

// ════════════════════════════════════════════════════════════════════════════
// Data models (co-located with result UI)
// ════════════════════════════════════════════════════════════════════════════

/// Top-level classification verdict from the scan endpoint.
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

/// The single highest-confidence disease from `most_probable_disease`.
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

/// One entry from `confidence_analysis`.
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

/// Plain-language environmental insight from `environmental_insights`.
class EnvironmentalInsight {
  final String title;
  final String message;
  final String severity; // 'high', 'medium', 'low'

  const EnvironmentalInsight({
    required this.title,
    required this.message,
    required this.severity,
  });

  factory EnvironmentalInsight.fromJson(Map<String, dynamic> json) {
    return EnvironmentalInsight(
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'low',
    );
  }
}

/// One factor from `environmental_technical_summary.top_risk_factors`.
class EnvironmentalTechFactor {
  final String feature;
  final double impact;
  final String effect; // 'increase_risk' | 'decrease_risk'
  final double? scaledValue;

  const EnvironmentalTechFactor({
    required this.feature,
    required this.impact,
    required this.effect,
    this.scaledValue,
  });

  factory EnvironmentalTechFactor.fromJson(Map<String, dynamic> json) {
    return EnvironmentalTechFactor(
      feature: json['feature']?.toString() ?? '',
      impact: (json['impact'] as num?)?.toDouble() ?? 0.0,
      effect: json['effect']?.toString() ?? '',
      scaledValue: (json['scaled_value'] as num?)?.toDouble(),
    );
  }

  bool get isRiskIncreasing => effect == 'increase_risk';
}

/// Technical environmental summary from `environmental_technical_summary`.
class EnvironmentalTechnicalSummary {
  final List<EnvironmentalTechFactor> topRiskFactors;
  final int riskIncreasingFactors;
  final int riskReducingFactors;

  const EnvironmentalTechnicalSummary({
    required this.topRiskFactors,
    required this.riskIncreasingFactors,
    required this.riskReducingFactors,
  });

  factory EnvironmentalTechnicalSummary.fromJson(Map<String, dynamic> json) {
    return EnvironmentalTechnicalSummary(
      topRiskFactors: (json['top_risk_factors'] as List? ?? [])
          .map(
            (e) => EnvironmentalTechFactor.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      riskIncreasingFactors:
          (json['risk_increasing_factors'] as num?)?.toInt() ?? 0,
      riskReducingFactors:
          (json['risk_reducing_factors'] as num?)?.toInt() ?? 0,
    );
  }
}

class ScanImageExplanation {
  final String filename;
  final String? gradcamUrl;
  final List<EnvironmentalTechFactor> environmentFactors;

  const ScanImageExplanation({
    required this.filename,
    this.gradcamUrl,
    this.environmentFactors = const [],
  });

  factory ScanImageExplanation.fromJson(Map<String, dynamic> json) {
    return ScanImageExplanation(
      filename: json['filename']?.toString() ?? '',
      gradcamUrl: json['gradcam_image']?.toString(),
      environmentFactors: (json['environment_factors'] as List? ?? [])
          .map(
            (item) =>
                EnvironmentalTechFactor.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Weather data for the scan context.
class DiseaseWeatherSnapshot {
  final DateTime date;
  final String summary;
  final int humidity;
  final double temperatureC;
  final double rainfallMm;
  final double windSpeedKmh;
  final double sunshineHours;

  const DiseaseWeatherSnapshot({
    required this.date,
    required this.summary,
    required this.humidity,
    required this.temperatureC,
    this.rainfallMm = 0.0,
    this.windSpeedKmh = 0.0,
    this.sunshineHours = 0.0,
  });
}

/// Complete scan result passed to [DiseaseScanResultScreen].
class DiseaseScanResult {
  final String status;
  final String fieldId;
  final List<String> imagePaths; // local paths (from picker)
  final DateTime detectedAt;
  final String? scanId;
  final String? fieldName;
  final List<String> remoteImageUrls; // URLs returned by API
  final DiseaseWeatherSnapshot? weather;
  final DiseaseClassification? classification;
  final MostProbableDisease? mostProbableDisease;
  final List<DiseaseResult> diseaseResults;
  final List<String> recommendations;
  final String? aggregatedGradcamUrl;
  final List<EnvironmentalInsight> environmentalInsights;
  final EnvironmentalTechnicalSummary? environmentalTechnicalSummary;
  final String? environmentalSummary;
  final int processedImages;
  final double? latitude;
  final double? longitude;
  final List<String> failedImages;
  final List<ScanImageExplanation> perImageExplanations;
  final String? modelVersion;
  final double? inferenceTimeMs;
  final DateTime? responseTimestamp;

  const DiseaseScanResult({
    this.status = 'success',
    required this.fieldId,
    this.imagePaths = const [],
    required this.detectedAt,
    this.scanId,
    this.fieldName,
    this.remoteImageUrls = const [],
    this.weather,
    this.classification,
    this.mostProbableDisease,
    required this.diseaseResults,
    this.recommendations = const [],
    this.aggregatedGradcamUrl,
    this.environmentalInsights = const [],
    this.environmentalTechnicalSummary,
    this.environmentalSummary,
    this.processedImages = 1,
    this.latitude,
    this.longitude,
    this.failedImages = const [],
    this.perImageExplanations = const [],
    this.modelVersion,
    this.inferenceTimeMs,
    this.responseTimestamp,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// Result screen
// ════════════════════════════════════════════════════════════════════════════

class DiseaseScanResultScreen extends StatefulWidget {
  final String fieldId;
  final List<String>? imagePaths;
  final DiseaseScanResult? scanResult;

  const DiseaseScanResultScreen({
    super.key,
    required this.fieldId,
    this.imagePaths,
    this.scanResult,
  });

  @override
  State<DiseaseScanResultScreen> createState() =>
      _DiseaseScanResultScreenState();
}

class _DiseaseScanResultScreenState extends State<DiseaseScanResultScreen> {
  late final DiseaseScanResult _scanResult;
  bool _showTechnicalDetails = false;

  @override
  void initState() {
    super.initState();
    _scanResult = widget.scanResult ?? _generateDummyResult();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  String get _topResultName {
    if (_scanResult.mostProbableDisease != null) {
      return _scanResult.mostProbableDisease!.diseaseName;
    }
    if (_scanResult.diseaseResults.isNotEmpty) {
      return _scanResult.diseaseResults.first.name;
    }
    return '';
  }

  bool _isHealthyResult() {
    final level = _scanResult.classification?.level.toLowerCase();
    if (level == 'healthy') return true;
    return _topResultName.toLowerCase() == 'healthy';
  }

  bool _isUncertainResult() {
    final level = _scanResult.classification?.level.toLowerCase();
    return level == 'uncertain' || level == 'unknown' || level == 'unclear';
  }

  // ─── Dummy data (fallback when no real result passed) ───────────────────

  DiseaseScanResult _generateDummyResult() {
    return DiseaseScanResult(
      fieldId: widget.fieldId,
      imagePaths: widget.imagePaths ?? [],
      detectedAt: DateTime.now(),
      weather: DiseaseWeatherSnapshot(
        date: DateTime.now(),
        summary: 'Partly cloudy',
        humidity: 78,
        temperatureC: 24.5,
        rainfallMm: 15.2,
        windSpeedKmh: 6.1,
        sunshineHours: 5.0,
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
      environmentalInsights: const [
        EnvironmentalInsight(
          title: 'Wind Conditions',
          message:
              'Lower wind movement may reduce air circulation and create favourable conditions for disease development.',
          severity: 'high',
        ),
        EnvironmentalInsight(
          title: 'Temperature',
          message:
              'Temperature conditions may support pathogen activity and disease development.',
          severity: 'medium',
        ),
        EnvironmentalInsight(
          title: 'Rainfall',
          message:
              'Recent rainfall may have increased moisture availability for disease development.',
          severity: 'low',
        ),
      ],
      environmentalSummary:
          'Recent environmental conditions may have increased disease risk based on weather patterns.',
      processedImages: 1,
    );
  }

  // ─── Navigation ─────────────────────────────────────────────────────────

  void _navigateToRecommendations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiseaseRecommendationScreen(
          diseaseName:
              _scanResult.mostProbableDisease?.diseaseName ??
              (_scanResult.diseaseResults.isNotEmpty
                  ? _scanResult.diseaseResults.first.name
                  : 'Unknown'),
          confidence:
              _scanResult.mostProbableDisease?.confidencePercent ??
              (_scanResult.diseaseResults.isNotEmpty
                  ? _scanResult.diseaseResults.first.confidence
                  : 0),
          recommendations: _scanResult.recommendations,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Build
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final Field? field = FieldManager().fields
        .where((f) => f.id == widget.fieldId)
        .toList()
        .firstOrNull;
    final isHealthy = _isHealthyResult();
    final isUncertain = _isUncertainResult();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // ── Hero / verdict header ──────────────────────────────────────
          SliverToBoxAdapter(
            child: _ImmediateDetailsHeader(
              scanResult: _scanResult,
              field: field,
              isHealthy: isHealthy,
              isUncertain: isUncertain,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                // ── Scanned images carousel ─────────────────────────────
                _ScannedImagesCarousel(
                  localPaths: _scanResult.imagePaths,
                  remoteUrls: _scanResult.remoteImageUrls,
                  processedImages: _scanResult.processedImages,
                ),
                const SizedBox(height: 20),

                // ── Healthy leaf celebration ────────────────────────────
                if (isHealthy) ...[
                  if (_scanResult.diseaseResults.isNotEmpty) ...[
                    _ConfidenceBreakdownCard(
                      diseaseResults: _scanResult.diseaseResults,
                      topResultIsHealthy: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _HealthyCelebrationCard(
                    confidence:
                        _scanResult.mostProbableDisease?.confidencePercent ??
                        _scanResult.classification?.confidencePercent ??
                        (_scanResult.diseaseResults.isNotEmpty
                            ? _scanResult.diseaseResults.first.confidence
                            : 0),
                    message: _scanResult.classification?.message,
                    isUncertain: isUncertain,
                  ),
                ],

                // ── Disease result cards ────────────────────────────────
                if (!isHealthy && _scanResult.diseaseResults.isNotEmpty) ...[
                  _ConfidenceBreakdownCard(
                    diseaseResults: _scanResult.diseaseResults,
                    topResultIsHealthy: false,
                  ),
                  const SizedBox(height: 16),

                  // What is it?
                  if (_scanResult.mostProbableDisease != null) ...[
                    _WhatIsItCard(
                      disease: _scanResult.mostProbableDisease!,
                      isUncertain: isUncertain,
                      candidateOnly:
                          _scanResult.mostProbableDisease!.confidence < 0.60 &&
                          _scanResult.classification != null &&
                          _scanResult.classification!.confidence >
                              _scanResult.mostProbableDisease!.confidence,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // What should I do?
                  if (_scanResult.recommendations.isNotEmpty) ...[
                    _WhatToDoCard(recommendations: _scanResult.recommendations),
                    const SizedBox(height: 16),
                  ],

                  // Recommendation button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToRecommendations,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.recommend_outlined, size: 18),
                      label: const Text(
                        'View Full Recommendations',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── No results ──────────────────────────────────────────
                if (_scanResult.diseaseResults.isEmpty) ...[_NoResultsCard()],

                // ── Environmental conditions (aggregated) ───────────────
                if (_scanResult.environmentalInsights.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _EnvironmentalConditionsCard(
                    insights: _scanResult.environmentalInsights,
                    summary: _scanResult.environmentalSummary,
                  ),
                ],

                // ── Technical details (expandable) ──────────────────────
                const SizedBox(height: 20),
                _TechnicalDetailsSection(
                  scanResult: _scanResult,
                  isExpanded: _showTechnicalDetails,
                  onToggle: () => setState(
                    () => _showTechnicalDetails = !_showTechnicalDetails,
                  ),
                ),

                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Hero Verdict Card
// ════════════════════════════════════════════════════════════════════════════

class _ImmediateDetailsHeader extends StatelessWidget {
  final DiseaseScanResult scanResult;
  final Field? field;
  final bool isHealthy;
  final bool isUncertain;
  final VoidCallback onBack;

  const _ImmediateDetailsHeader({
    required this.scanResult,
    required this.field,
    required this.isHealthy,
    required this.isUncertain,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final disease = scanResult.mostProbableDisease;
    final classification = scanResult.classification;
    final preferClassification =
        !isHealthy &&
        disease != null &&
        disease.confidence < 0.60 &&
        classification != null &&
        classification.confidence > disease.confidence;
    final title = isHealthy
        ? 'Healthy leaf profile'
        : preferClassification
        ? classification.label
        : disease?.diseaseName ??
              (scanResult.diseaseResults.isNotEmpty
                  ? scanResult.diseaseResults.first.name
                  : 'Scan complete');
    final confidence =
        (preferClassification ? classification.confidencePercent : null) ??
        disease?.confidencePercent ??
        scanResult.classification?.confidencePercent ??
        (scanResult.diseaseResults.isNotEmpty
            ? scanResult.diseaseResults.first.confidence
            : 0);
    final severity = isHealthy
        ? 'Healthy'
        : isUncertain
        ? 'Review'
        : disease?.severity ?? 'Detected';
    final accent = isHealthy
        ? AppTheme.accentGreenText
        : isUncertain
        ? const Color(0xFFB97922)
        : const Color(0xFFB54848);

    return ColoredBox(
      color: AppTheme.backgroundLight,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Scan Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4E9DE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isHealthy
                              ? Icons.check_circle_outline_rounded
                              : Icons.health_and_safety_outlined,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scanResult.classification?.category.isNotEmpty ==
                                      true
                                  ? scanResult.classification!.category
                                  : 'Disease analysis',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$confidence%',
                          style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ResultInfoChip(
                        icon: Icons.shield_outlined,
                        label: severity.toUpperCase(),
                      ),
                      _ResultInfoChip(
                        icon: Icons.landscape_outlined,
                        label: scanResult.fieldName ?? field?.name ?? 'Field',
                      ),
                      _ResultInfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: _resultDate(scanResult.detectedAt),
                      ),
                    ],
                  ),
                  if (scanResult.classification?.message.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 12),
                    Text(
                      scanResult.classification!.message,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (preferClassification) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'An exact disease could not be identified with sufficient confidence. '
                        'The most likely classification is ${classification.label}.',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resultDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _ResultInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ResultInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _HeroVerdictCard extends StatelessWidget {
  final DiseaseScanResult scanResult;
  final Field? field;
  final bool isHealthy;
  final bool isUncertain;
  final VoidCallback onBack;

  const _HeroVerdictCard({
    required this.scanResult,
    required this.field,
    required this.isHealthy,
    required this.isUncertain,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // Colors based on result
    final List<Color> gradientColors;
    final String headline;
    final String subline;
    final IconData icon;
    final Color iconColor;

    if (isHealthy && !isUncertain) {
      gradientColors = [AppTheme.primaryDark, const Color(0xFF263338)];
      headline = 'Healthy leaf profile';
      subline = 'No visible disease patterns detected';
      icon = Icons.eco_rounded;
      iconColor = AppTheme.brandGreen;
    } else if (isHealthy && isUncertain) {
      gradientColors = [const Color(0xFF7A4D0C), const Color(0xFFB97922)];
      headline = 'Likely Healthy';
      subline = 'Low confidence — consider rescanning';
      icon = Icons.help_outline_rounded;
      iconColor = Colors.white;
    } else {
      final severity =
          scanResult.mostProbableDisease?.severity.toLowerCase() ?? 'medium';
      if (severity == 'high') {
        gradientColors = [const Color(0xFF7A1515), const Color(0xFFB54848)];
      } else if (severity == 'medium') {
        gradientColors = [const Color(0xFF7A3D15), const Color(0xFFCC6633)];
      } else {
        gradientColors = [const Color(0xFF5C4A10), const Color(0xFFB99020)];
      }
      final diseaseName =
          scanResult.mostProbableDisease?.diseaseName ??
          (scanResult.diseaseResults.isNotEmpty
              ? scanResult.diseaseResults.first.name
              : 'Disease Detected');
      headline = diseaseName;
      final sev = scanResult.mostProbableDisease?.severity ?? '';
      subline = sev.isNotEmpty
          ? '${_capitalize(sev)} severity'
          : 'Disease detected';
      icon = Icons.health_and_safety_outlined;
      iconColor = Colors.white;
    }

    final confidence =
        scanResult.mostProbableDisease?.confidencePercent ??
        scanResult.classification?.confidencePercent ??
        (scanResult.diseaseResults.isNotEmpty
            ? scanResult.diseaseResults.first.confidence
            : 0);

    final fieldDisplayName =
        scanResult.fieldName ?? field?.name ?? 'Unknown Field';
    final date = _formatDate(scanResult.detectedAt);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Scan Results',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Confidence badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '$confidence% confidence',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(height: 16),

              // Headline
              Text(
                headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subline,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Field / date info
              Row(
                children: [
                  _HeroPill(
                    icon: Icons.agriculture_outlined,
                    label: fieldDisplayName,
                  ),
                  const SizedBox(width: 8),
                  _HeroPill(icon: Icons.calendar_today_outlined, label: date),
                  if (scanResult.processedImages > 1) ...[
                    const SizedBox(width: 8),
                    _HeroPill(
                      icon: Icons.photo_library_outlined,
                      label: '${scanResult.processedImages} images',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Scanned Images Carousel
// ════════════════════════════════════════════════════════════════════════════

class _ScannedImagesCarousel extends StatelessWidget {
  final List<String> localPaths;
  final List<String> remoteUrls;
  final int processedImages;

  const _ScannedImagesCarousel({
    required this.localPaths,
    required this.remoteUrls,
    required this.processedImages,
  });

  @override
  Widget build(BuildContext context) {
    // Prefer local paths; fall back to remote URLs resolved via service
    final displayPaths = localPaths.isNotEmpty
        ? localPaths
        : remoteUrls
              .map((u) => DiseaseScanService.resolveImageUrl(u) ?? u)
              .toList();

    if (displayPaths.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: AppTheme.brandGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  displayPaths.length == 1
                      ? 'Scanned Image'
                      : '${displayPaths.length} Scanned Images',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: displayPaths.length == 1 ? 220 : 160,
            child: displayPaths.length == 1
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildImage(
                        displayPaths.first,
                        double.infinity,
                        220,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    itemCount: displayPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildImage(displayPaths[i], 160, 160),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildImage(String path, double width, double height) {
    final isRemoteOrWeb =
        kIsWeb ||
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:');

    if (isRemoteOrWeb) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(width, height),
      );
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _imagePlaceholder(width, height),
    );
  }

  Widget _imagePlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF3F4F6),
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppTheme.textSecondary,
        size: 36,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Healthy Celebration Card
// ════════════════════════════════════════════════════════════════════════════

class _HealthyCelebrationCard extends StatelessWidget {
  final int confidence;
  final String? message;
  final bool isUncertain;

  const _HealthyCelebrationCard({
    required this.confidence,
    this.message,
    this.isUncertain = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isUncertain
        ? const Color(0xFFB97922)
        : AppTheme.brandGreen;
    final textColor = isUncertain
        ? const Color(0xFF7A4D0C)
        : AppTheme.textPrimary;
    final bgColor = isUncertain ? const Color(0xFFFFF8EC) : Colors.white;
    const borderColor = Color(0xFFE4E9DE);
    final headline = isUncertain ? 'Likely Healthy' : 'No disease detected';
    final defaultMessage = isUncertain
        ? 'Symptoms are ambiguous, but the leaf most closely matches a healthy profile. '
              'Consider rescanning with better lighting for a more reliable result.'
        : 'The submitted leaf images show no visible signs of disease. '
              'Continue routine monitoring and good field practices.';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Colored top bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFE4E9DE),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isUncertain
                          ? Icons.help_outline_rounded
                          : Icons.eco_rounded,
                      color: accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        headline,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isUncertain
                            ? accentColor
                            : AppTheme.primaryButton,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$confidence%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message?.isNotEmpty == true ? message! : defaultMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withValues(alpha: 0.85),
                    height: 1.6,
                  ),
                ),
                if (!isUncertain) ...[
                  const SizedBox(height: 16),
                  _GreenTip(
                    icon: Icons.visibility_outlined,
                    text:
                        'Keep monitoring your field regularly to catch any early signs of disease.',
                  ),
                  const SizedBox(height: 8),
                  _GreenTip(
                    icon: Icons.water_drop_outlined,
                    text:
                        'Maintain proper drainage and airflow to prevent future infections.',
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

class _GreenTip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GreenTip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// "What Is It?" Card
// ════════════════════════════════════════════════════════════════════════════

class _WhatIsItCard extends StatelessWidget {
  final MostProbableDisease disease;
  final bool isUncertain;
  final bool candidateOnly;

  const _WhatIsItCard({
    required this.disease,
    this.isUncertain = false,
    this.candidateOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final severity = disease.severity.toLowerCase();
    Color severityColor;
    String severityLabel;
    IconData severityIcon;

    switch (severity) {
      case 'high':
        severityColor = const Color(0xFFB54848);
        severityLabel = 'High Severity';
        severityIcon = Icons.warning_rounded;
        break;
      case 'medium':
        severityColor = const Color(0xFFCC6633);
        severityLabel = 'Medium Severity';
        severityIcon = Icons.info_rounded;
        break;
      case 'low':
        severityColor = const Color(0xFFB99020);
        severityLabel = 'Low Severity';
        severityIcon = Icons.info_outline_rounded;
        break;
      default:
        severityColor = AppTheme.textSecondary;
        severityLabel = 'Unknown Severity';
        severityIcon = Icons.help_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored top stripe
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFE4E9DE),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.health_and_safety_outlined,
                      color: Color(0xFFB54848),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      candidateOnly
                          ? 'Most likely specific disease'
                          : 'What was detected?',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (isUncertain) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFB97922,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Low confidence',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB97922),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Disease name + severity chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        disease.diseaseName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B242C),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: severityColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(severityIcon, size: 12, color: severityColor),
                          const SizedBox(width: 4),
                          Text(
                            severityLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: severityColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (disease.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'About this disease',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    disease.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ],

                if (disease.causes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Why did this happen?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...disease.causes.map((cause) => _CauseRow(cause: cause)),
                ],

                if (isUncertain) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8EC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Color(0xFFB97922),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The model wasn\'t fully confident. Consider rescanning '
                            'in better lighting or from a closer angle.',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(
                                0xFFB97922,
                              ).withValues(alpha: 0.9),
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

class _CauseRow extends StatelessWidget {
  final String cause;
  const _CauseRow({required this.cause});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFB54848),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cause,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// "What To Do?" Card
// ════════════════════════════════════════════════════════════════════════════

class _WhatToDoCard extends StatelessWidget {
  final List<String> recommendations;
  const _WhatToDoCard({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            decoration: const BoxDecoration(
              color: AppTheme.brandGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      color: AppTheme.brandGreen,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'What should you do?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...List.generate(recommendations.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppTheme.brandGreen.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.brandGreen,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              recommendations[i],
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                                height: 1.5,
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
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Confidence Breakdown Card
// ════════════════════════════════════════════════════════════════════════════

class _ConfidenceBreakdownCard extends StatelessWidget {
  final List<DiseaseResult> diseaseResults;
  final bool topResultIsHealthy;

  const _ConfidenceBreakdownCard({
    required this.diseaseResults,
    this.topResultIsHealthy = false,
  });

  @override
  Widget build(BuildContext context) {
    final topConfidence = diseaseResults.isNotEmpty
        ? diseaseResults
              .map((d) => d.confidence)
              .reduce((a, b) => a > b ? a : b)
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: AppTheme.brandGreen,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Detection Confidence',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'How confident the AI is about each possibility',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final chart = _DetectionConfidencePie(results: diseaseResults);
              final legend = _DetectionConfidenceLegend(
                results: diseaseResults,
                topConfidence: topConfidence,
              );
              if (constraints.maxWidth < 350) {
                return Column(
                  children: [
                    Center(child: chart),
                    const SizedBox(height: 20),
                    legend,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  chart,
                  const SizedBox(width: 20),
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

const _confidenceColors = <Color>[
  AppTheme.primaryGreen,
  Color(0xFF718096),
  Color(0xFFD69E2E),
  Color(0xFF9AA3AF),
  Color(0xFF4A6C6F),
];

class _DetectionConfidencePie extends StatelessWidget {
  final List<DiseaseResult> results;

  const _DetectionConfidencePie({required this.results});

  @override
  Widget build(BuildContext context) {
    final top = results.reduce(
      (first, second) => first.confidence >= second.confidence ? first : second,
    );
    return Semantics(
      label: '${top.name}, ${top.confidence} percent confidence',
      child: SizedBox(
        width: 132,
        height: 132,
        child: CustomPaint(
          painter: _DetectionConfidencePiePainter(
            values: results
                .map((result) => result.confidence.toDouble())
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _DetectionConfidencePiePainter extends CustomPainter {
  final List<double> values;

  const _DetectionConfidencePiePainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.shortestSide / 2,
        Paint()..color = const Color(0xFFE8ECEF),
      );
      return;
    }

    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = _confidenceColors[index % _confidenceColors.length],
      );
      start += sweep;
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _DetectionConfidencePiePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _DetectionConfidenceLegend extends StatelessWidget {
  final List<DiseaseResult> results;
  final int topConfidence;

  const _DetectionConfidenceLegend({
    required this.results,
    required this.topConfidence,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: results.asMap().entries.map((entry) {
        final index = entry.key;
        final result = entry.value;
        final isTop = result.confidence == topConfidence;
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == results.length - 1 ? 0 : 10,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _confidenceColors[index % _confidenceColors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12.5,
                        fontWeight: isTop ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    if (result.category.isNotEmpty)
                      Text(
                        result.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${result.confidence}%',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
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

// Kept for compatibility with older result compositions.
// ignore: unused_element
class _ConfidenceBar extends StatelessWidget {
  final DiseaseResult disease;
  final bool isTopResult;

  const _ConfidenceBar({required this.disease, required this.isTopResult});

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFB54848);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disease.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isTopResult
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isTopResult ? accentColor : AppTheme.textPrimary,
                      ),
                    ),
                    if (disease.category.isNotEmpty)
                      Text(
                        disease.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${disease.confidence}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isTopResult ? FontWeight.w900 : FontWeight.w700,
                  color: isTopResult ? accentColor : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              if (disease.confidenceLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isTopResult
                        ? accentColor.withValues(alpha: 0.1)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    disease.confidenceLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isTopResult ? accentColor : AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 7,
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
                        ? [accentColor, accentColor.withValues(alpha: 0.7)]
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

// ════════════════════════════════════════════════════════════════════════════
// Environmental Conditions Card (aggregated — shown once per scan)
// ════════════════════════════════════════════════════════════════════════════

class _EnvironmentalConditionsCard extends StatelessWidget {
  final List<EnvironmentalInsight> insights;
  final String? summary;

  const _EnvironmentalConditionsCard({required this.insights, this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_outlined, color: AppTheme.brandGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Weather Impact',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (summary != null && summary!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...insights.map((insight) => _InsightTile(insight: insight)),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final EnvironmentalInsight insight;
  const _InsightTile({required this.insight});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (insight.severity.toLowerCase()) {
      case 'high':
        color = const Color(0xFFB54848);
        icon = Icons.warning_rounded;
        break;
      case 'medium':
        color = const Color(0xFFCC6633);
        icon = Icons.info_rounded;
        break;
      default:
        color = const Color(0xFFB99020);
        icon = Icons.wb_sunny_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E9DE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: color.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
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

// ════════════════════════════════════════════════════════════════════════════
// Technical Details (expandable)
// ════════════════════════════════════════════════════════════════════════════

class _TechnicalDetailsSection extends StatelessWidget {
  final DiseaseScanResult scanResult;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _TechnicalDetailsSection({
    required this.scanResult,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: Column(
        children: [
          // Toggle header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.science_outlined,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Technical Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'For advanced users — model data & risk factors',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE8ECEF)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scan metadata
                  _TechSection(
                    title: 'Scan Information',
                    children: [
                      _TechRow(
                        label: 'Status',
                        value: scanResult.status.isEmpty
                            ? 'Unknown'
                            : scanResult.status,
                      ),
                      if (scanResult.scanId != null)
                        _TechRow(label: 'Scan ID', value: scanResult.scanId!),
                      if (scanResult.fieldName != null)
                        _TechRow(label: 'Field', value: scanResult.fieldName!),
                      _TechRow(label: 'Field ID', value: scanResult.fieldId),
                      _TechRow(
                        label: 'Processed Images',
                        value: '${scanResult.processedImages}',
                      ),
                      _TechRow(
                        label: 'Failed Images',
                        value: '${scanResult.failedImages.length}',
                      ),
                      _TechRow(
                        label: 'Date & Time',
                        value: _formatDateTime(scanResult.detectedAt),
                      ),
                      if (scanResult.latitude != null)
                        _TechRow(
                          label: 'Latitude',
                          value: scanResult.latitude!.toStringAsFixed(6),
                        ),
                      if (scanResult.longitude != null)
                        _TechRow(
                          label: 'Longitude',
                          value: scanResult.longitude!.toStringAsFixed(6),
                        ),
                    ],
                  ),

                  if (scanResult.classification != null) ...[
                    const SizedBox(height: 16),
                    _TechSection(
                      title: 'Classification',
                      children: [
                        _TechRow(
                          label: 'Level',
                          value: scanResult.classification!.level,
                        ),
                        _TechRow(
                          label: 'Label',
                          value: scanResult.classification!.label,
                        ),
                        _TechRow(
                          label: 'Category',
                          value: scanResult.classification!.category,
                        ),
                        _TechRow(
                          label: 'Confidence',
                          value:
                              '${scanResult.classification!.confidencePercent}%',
                        ),
                        if (scanResult.classification!.message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              scanResult.classification!.message,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12.5,
                                height: 1.45,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  if (scanResult.modelVersion != null ||
                      scanResult.inferenceTimeMs != null ||
                      scanResult.responseTimestamp != null) ...[
                    const SizedBox(height: 16),
                    _TechSection(
                      title: 'Model Metadata',
                      children: [
                        if (scanResult.modelVersion != null)
                          _TechRow(
                            label: 'Model Version',
                            value: scanResult.modelVersion!,
                          ),
                        if (scanResult.inferenceTimeMs != null)
                          _TechRow(
                            label: 'Inference Time',
                            value:
                                '${scanResult.inferenceTimeMs!.toStringAsFixed(0)} ms',
                          ),
                        if (scanResult.responseTimestamp != null)
                          _TechRow(
                            label: 'Response Time',
                            value: _formatDateTime(
                              scanResult.responseTimestamp!,
                            ),
                          ),
                      ],
                    ),
                  ],

                  if (scanResult.failedImages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _TechSection(
                      title: 'Failed Images',
                      children: scanResult.failedImages
                          .map(
                            (image) => _TechRow(label: 'Image', value: image),
                          )
                          .toList(),
                    ),
                  ],

                  // Weather data
                  if (scanResult.weather != null) ...[
                    const SizedBox(height: 16),
                    _TechSection(
                      title: '7-Day Weather Data',
                      children: [
                        _TechRow(
                          label: 'Temperature (avg)',
                          value:
                              '${scanResult.weather!.temperatureC.toStringAsFixed(1)}°C',
                        ),
                        _TechRow(
                          label: 'Humidity (avg)',
                          value: '${scanResult.weather!.humidity}%',
                        ),
                        _TechRow(
                          label: 'Rainfall (total)',
                          value:
                              '${scanResult.weather!.rainfallMm.toStringAsFixed(1)} mm',
                        ),
                        _TechRow(
                          label: 'Wind Speed (avg)',
                          value:
                              '${scanResult.weather!.windSpeedKmh.toStringAsFixed(1)} km/h',
                        ),
                        _TechRow(
                          label: 'Sunshine Hours (avg)',
                          value:
                              '${scanResult.weather!.sunshineHours.toStringAsFixed(1)} h',
                        ),
                      ],
                    ),
                  ],

                  // Environmental risk factors
                  if (scanResult.environmentalTechnicalSummary != null) ...[
                    const SizedBox(height: 16),
                    _TechSection(
                      title: 'Environmental Risk Factors',
                      children: [
                        _TechRow(
                          label: 'Risk-increasing factors',
                          value:
                              '${scanResult.environmentalTechnicalSummary!.riskIncreasingFactors}',
                        ),
                        _TechRow(
                          label: 'Risk-reducing factors',
                          value:
                              '${scanResult.environmentalTechnicalSummary!.riskReducingFactors}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Factor table
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE8ECEF)),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Factor',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Impact',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Effect',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE8ECEF)),
                          ...scanResult
                              .environmentalTechnicalSummary!
                              .topRiskFactors
                              .asMap()
                              .entries
                              .map((entry) {
                                final i = entry.key;
                                final factor = entry.value;
                                final isLast =
                                    i ==
                                    scanResult
                                            .environmentalTechnicalSummary!
                                            .topRiskFactors
                                            .length -
                                        1;
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              _featureLabel(factor.feature),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              factor.impact.toStringAsFixed(4),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppTheme.textSecondary,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: factor.isRiskIncreasing
                                                      ? const Color(
                                                          0xFFB54848,
                                                        ).withValues(alpha: 0.1)
                                                      : const Color(
                                                          0xFF22C55E,
                                                        ).withValues(
                                                          alpha: 0.1,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  factor.isRiskIncreasing
                                                      ? '↑ Risk'
                                                      : '↓ Risk',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        factor.isRiskIncreasing
                                                        ? const Color(
                                                            0xFFB54848,
                                                          )
                                                        : const Color(
                                                            0xFF16A34A,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isLast)
                                      const Divider(
                                        height: 1,
                                        color: Color(0xFFE8ECEF),
                                      ),
                                  ],
                                );
                              }),
                        ],
                      ),
                    ),
                  ],

                  if (scanResult.perImageExplanations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _TechSection(
                      title: 'Per-Image Explanations',
                      children: const [],
                    ),
                    const SizedBox(height: 8),
                    ...scanResult.perImageExplanations.map(
                      (explanation) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE8ECEF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              explanation.filename.isEmpty
                                  ? 'Scanned image'
                                  : explanation.filename,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (explanation.gradcamUrl != null) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  DiseaseScanService.resolveImageUrl(
                                        explanation.gradcamUrl,
                                      ) ??
                                      explanation.gradcamUrl!,
                                  width: double.infinity,
                                  height: 130,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    color: const Color(0xFFF0F2F1),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Attention map unavailable',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (explanation.environmentFactors.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...explanation.environmentFactors.map(
                                (factor) => _TechRow(
                                  label: _featureLabel(factor.feature),
                                  value: factor.scaledValue == null
                                      ? '${factor.isRiskIncreasing ? 'Risk +' : 'Risk -'} ${factor.impact.toStringAsFixed(4)}'
                                      : 'Scaled ${factor.scaledValue!.toStringAsFixed(3)} · ${factor.isRiskIncreasing ? 'Risk +' : 'Risk -'} ${factor.impact.toStringAsFixed(4)}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],

                  // GradCAM image
                  if (scanResult.aggregatedGradcamUrl != null) ...[
                    const SizedBox(height: 16),
                    _TechSection(
                      title: 'AI Attention Map (GradCAM)',
                      children: const [],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The highlighted areas show where the AI focused most when making its decision.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        DiseaseScanService.resolveImageUrl(
                              scanResult.aggregatedGradcamUrl,
                            ) ??
                            scanResult.aggregatedGradcamUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                            child: Text(
                              'Attention map unavailable',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} ${pad(dt.hour)}:${pad(dt.minute)}';
  }

  String _featureLabel(String feature) {
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

class _TechSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _TechSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _TechRow extends StatelessWidget {
  final String label;
  final String value;
  const _TechRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// No Results Card
// ════════════════════════════════════════════════════════════════════════════

class _NoResultsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppTheme.brandGreen,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'No Diseases Detected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The scan completed but no disease patterns were identified in the images.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Recommendation Detail Screen
// ════════════════════════════════════════════════════════════════════════════

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
    const icons = [
      Icons.eco_outlined,
      Icons.cut_outlined,
      Icons.visibility_outlined,
      Icons.water_drop_outlined,
      Icons.shield_outlined,
      Icons.warning_amber_outlined,
      Icons.grass_outlined,
    ];

    if (recommendations.isNotEmpty) {
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8ECEF)),
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
                  const SizedBox(height: 6),
                  Text(
                    'Detected with $confidence% confidence',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
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
                    if (i > 0) const SizedBox(height: 14),
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
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.brandGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppTheme.brandGreen),
        ),
        const SizedBox(width: 14),
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
                  height: 1.4,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
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
