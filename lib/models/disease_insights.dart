import 'package:flutter/material.dart';

/// Shared helpers for parsing the Disease Insights API responses.
///
/// These utilities live here so both the estate and field insights models, as
/// well the screen widgets, can stay in sync with the backend contract.

/// Maps a backend-provided icon name string to a Flutter [IconData].
/// Returns [fallback] (or [Icons.insights_outlined]) when the name is
/// unknown so the UI never breaks on an unfamiliar value.
IconData parseIcon(String? name, [IconData fallback = Icons.insights_outlined]) {
  if (name == null || name.isEmpty) return fallback;
  final key = name.trim().toLowerCase();
  return _iconMap[key] ?? fallback;
}

const _iconMap = <String, IconData>{
  // Estate KPI icons (kept consistent with the original UI design)
  'warning_amber': Icons.warning_amber_rounded,
  'warning': Icons.warning_amber_rounded,
  'radar': Icons.radar_rounded,
  'task_alt': Icons.task_alt_rounded,
  'task': Icons.task_alt_rounded,
  'landscape': Icons.landscape_outlined,
  'priority_high': Icons.priority_high_rounded,
  'checklist': Icons.checklist_rounded,
  'bar_chart': Icons.bar_chart_rounded,
  'map': Icons.map_outlined,
  'show_chart': Icons.show_chart_rounded,
  'timeline': Icons.timeline_rounded,
  'cloud': Icons.cloud_outlined,
  'medical_services': Icons.medical_services_outlined,
  'pie_chart': Icons.pie_chart_outline_rounded,
};

/// Parses a color from a hex string sent by the API.
///
/// Accepts `0xFF2F6B4F`, `#2F6B4F`, `FF2F6B4F`, and `2F6B4F` forms.
Color parseColor(String? hex, [Color fallback = const Color(0xFF6E7E8B)]) {
  if (hex == null || hex.isEmpty) return fallback;
  var value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 8) {
    // strip leading alpha if present and not ARGB
    final a = value.substring(0, 2);
    if (a == 'FF' || a == 'ff') value = value.substring(2);
  }
  if (value.length == 8) {
    final parsed = int.tryParse(value, radix: 16);
    if (parsed != null) return Color(parsed);
  }
  if (value.length == 6) {
    final parsed = int.tryParse('FF$value', radix: 16);
    if (parsed != null) return Color(parsed);
  }
  return fallback;
}

/// Converts a backend risk level string into the palette color used by the
/// risk-map legend. Matches the original hardcoded demo colors.
Color riskLevelColor(String level) {
  switch (level.toLowerCase()) {
    case 'high':
      return const Color(0xFFB54848);
    case 'medium':
      return const Color(0xFFE69A2E);
    case 'low':
      return const Color(0xFF8A9B91);
    case 'healthy':
    case 'ok':
      return const Color(0xFF4F8065);
    default:
      return const Color(0xFF8A9B91);
  }
}

/// Human-readable descriptor appended after the percentage on the risk map,
/// matching the original demo wording ("72% high risk", "91% healthy", ...).
String riskLevelDescriptor(String level) {
  switch (level.toLowerCase()) {
    case 'high':
      return 'high risk';
    case 'medium':
      return 'medium';
    case 'low':
      return 'low risk';
    case 'healthy':
      return 'healthy';
    default:
      return level.toLowerCase();
  }
}

// =============================================================================
// Estate-level insights  (GET /api/v1/disease/estate-insights)
// =============================================================================

/// One of the four estate KPI summary cards.
class EstateKpiCard {
  final String label;
  final String value;
  final String caption;
  final IconData icon;

  EstateKpiCard({
    required this.label,
    required this.value,
    required this.caption,
    IconData? icon,
  }) : icon = icon ?? Icons.insights_outlined;

  factory EstateKpiCard.fromJson(Map<String, dynamic> json) {
    return EstateKpiCard(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '-',
      caption: json['caption']?.toString() ?? '',
      icon: parseIcon(json['icon']?.toString()),
    );
  }
}

/// One field rendered on the estate risk map.
class EstateRiskMapField {
  final String fieldId;
  final String fieldName;
  final double healthPercentage;
  final String riskLevel; // "high" | "medium" | "low" | "healthy"
  final double areaHectares;

  EstateRiskMapField({
    required this.fieldId,
    required this.fieldName,
    required this.healthPercentage,
    required this.riskLevel,
    this.areaHectares = 0.0,
  });

  factory EstateRiskMapField.fromJson(Map<String, dynamic> json) {
    return EstateRiskMapField(
      fieldId: json['field_id']?.toString() ?? '',
      fieldName: json['field_name']?.toString() ?? json['label']?.toString() ?? 'Field',
      healthPercentage: (json['health_percentage'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['risk_level']?.toString() ?? 'low',
      areaHectares: (json['area_hectares'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Renders the demo-style string, e.g. "72% high risk" or "91% healthy".
  String get resultText =>
      '${healthPercentage.round()}% ${riskLevelDescriptor(riskLevel)}';

  Color get color => riskLevelColor(riskLevel);
}

/// Canonical colour palette for known disease categories.  Any disease not
/// listed here falls back to [otherDiseaseColor] so the chart always renders
/// every detected disease.
class DiseasePalette {
  static const Color healthy = Color(0xFF2F6B4F);
  static const Color anthracnose = Color(0xFFB54848);
  static const Color blisterBlight = Color(0xFFE69A2E);
  static const Color spiderMite = Color(0xFF6A5ACD);
  static const Color algaeOrMoss = Color(0xFF208982);
  static const Color otherDisease = Color(0xFF718096);

  /// Returns the colour for a disease name, falling back to [otherDisease]
  /// for any disease that is not in the predefined list.
  static Color colorFor(String disease) {
    return switch (disease.toLowerCase()) {
      'healthy' => healthy,
      'anthracnose' => anthracnose,
      'blister blight' => blisterBlight,
      'spider mite disease' => spiderMite,
      'spider mite' => spiderMite,
      'algae or moss' => algaeOrMoss,
      'algae' => algaeOrMoss,
      'moss' => algaeOrMoss,
      _ => otherDisease,
    };
  }
}

/// One time point on the estate disease-spread / healthiness trend chart.
///
/// The backend returns raw scan counts grouped by disease in
/// [diseaseDistribution] rather than pre-computed percentages. The
/// [healthy], [anthracnose], [blisterBlight] and [greyBlight] getters on
/// this class compute the percentage share of each category relative to
/// [totalScans] so the chart painter receives values in the 0-100 range.
class EstateDiseaseTrendPoint {
  final String label; // e.g. "2026-07-28"
  final int totalScans;
  final Map<String, int> diseaseDistribution;

  EstateDiseaseTrendPoint({
    required this.label,
    this.totalScans = 0,
    this.diseaseDistribution = const {},
  });

  factory EstateDiseaseTrendPoint.fromJson(Map<String, dynamic> json) {
    final dist = json['disease_distribution'] as Map?;
    return EstateDiseaseTrendPoint(
      label: json['date']?.toString() ?? json['label']?.toString() ?? '',
      totalScans: (json['total_scans'] as num?)?.toInt() ?? 0,
      diseaseDistribution: dist != null
          ? Map<String, int>.from(dist.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt())))
          : {},
    );
  }

  /// Percentage of plants that were healthy.
  double get healthy => _pct('Healthy');

  /// Percentage affected by anthracnose.
  double get anthracnose => _pct('Anthracnose');

  /// Percentage affected by blister blight.
  double get blisterBlight => _pct('Blister Blight');

  /// Percentage of any other disease.  The chart only has four series
  /// (Healthy, Anthracnose, Blister Blight, Grey Blight), so every disease
  /// that is not one of the first three is rolled into the Grey Blight slot.
  double get greyBlight {
    if (totalScans == 0) return 0.0;
    final total = diseaseDistribution.values.fold<int>(0, (s, v) => s + v);
    final known = (diseaseDistribution['Healthy'] ?? 0) +
        (diseaseDistribution['Anthracnose'] ?? 0) +
        (diseaseDistribution['Blister Blight'] ?? 0);
    final other = (total - known).clamp(0, total);
    return (other / totalScans) * 100;
  }

  double _pct(String disease) {
    if (totalScans == 0) return 0.0;
    final count = diseaseDistribution[disease] ?? 0;
    return (count / totalScans) * 100;
  }

  /// Returns every disease found in [diseaseDistribution] mapped to its
  /// percentage share of [totalScans].  Used by the multi-line field disease
  /// trend chart so no detected disease is left out.
  Map<String, double> getAllDiseasePercentages() {
    if (totalScans == 0) return {};
    return {
      for (final entry in diseaseDistribution.entries)
        entry.key: (entry.value / totalScans) * 100,
    };
  }
}

/// One ranked entry on the field-priority list.
class EstateFieldPriority {
  final String fieldId;
  final String fieldName;
  final double priorityScore;
  final String priorityLevel;
  final String? detectedDisease;
  final double? confidence;
  final String? severity;

  EstateFieldPriority({
    required this.fieldId,
    required this.fieldName,
    required this.priorityScore,
    required this.priorityLevel,
    this.detectedDisease,
    this.confidence,
    this.severity,
  });

  factory EstateFieldPriority.fromJson(Map<String, dynamic> json) {
    return EstateFieldPriority(
      fieldId: json['field_id']?.toString() ?? '',
      fieldName: json['field_name']?.toString() ?? '',
      priorityScore: (json['priority_score'] as num?)?.toDouble() ?? 0.0,
      priorityLevel: json['priority_level']?.toString() ?? 'low',
      detectedDisease: json['detected_disease']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      severity: json['severity']?.toString(),
    );
  }

  // ── UI helpers (kept on the model so the widget interface is unchanged) ──

  /// Badge text — the priority level, e.g. "HIGH", "LOW".
  String get rank => priorityLevel.toUpperCase();

  /// Field name shown in the row title.
  String get field => fieldName;

  /// Detected disease or a "no disease" message.
  String get issue => detectedDisease ?? 'No disease detected';

  /// Priority score as an integer (0-100).
  int get score => priorityScore.round();

  /// Confidence shown where the old UI expected an area figure.
  String get areaDisplay => confidence != null
      ? '${(confidence! * 100).round()}% conf'
      : 'No confidence';
}

/// One slice of the disease-composition bar breakdown.
class EstateDiseaseComposition {
  final String disease;
  final int percentage;

  EstateDiseaseComposition({required this.disease, required this.percentage});

  factory EstateDiseaseComposition.fromJson(Map<String, dynamic> json) {
    return EstateDiseaseComposition(
      disease: json['disease']?.toString() ?? json['label']?.toString() ?? '',
      percentage: (json['percentage'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One item in the management action queue.
class EstateActionItem {
  final String fieldId;
  final String fieldName;
  final String actionType;
  final String reason;
  final String severity;
  final String? lastScanDate;
  final double? confidence;

  EstateActionItem({
    required this.fieldId,
    required this.fieldName,
    required this.actionType,
    required this.reason,
    required this.severity,
    this.lastScanDate,
    this.confidence,
  });

  factory EstateActionItem.fromJson(Map<String, dynamic> json) {
    return EstateActionItem(
      fieldId: json['field_id']?.toString() ?? '',
      fieldName: json['field_name']?.toString() ?? '',
      actionType: json['action_type']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      lastScanDate: json['last_scan_date']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  // ── UI helpers (kept on the model so the widget interface is unchanged) ──

  /// Field name — shown as the action row title.
  String get title => fieldName;

  /// Human-readable reason — shown as the action row subtitle.
  String get detail => reason;

  /// Severity used as the timing badge — shown as uppercase in the badge.
  String get timing => severity.toUpperCase();
}

/// Top-level estate insights payload — the response of
/// `GET /api/v1/disease/estate-insights`.
class EstateInsights {
  final List<EstateKpiCard> kpiCards;
  final List<EstateRiskMapField> riskMap;
  final List<EstateDiseaseTrendPoint> diseaseTrend;
  final List<EstateFieldPriority> fieldPriority;
  final List<EstateDiseaseComposition> diseaseComposition;
  final List<EstateActionItem> actionQueue;

  EstateInsights({
    this.kpiCards = const [],
    this.riskMap = const [],
    this.diseaseTrend = const [],
    this.fieldPriority = const [],
    this.diseaseComposition = const [],
    this.actionQueue = const [],
  });

  factory EstateInsights.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    }

    // kpi_cards arrives as a Map (KPISummary), not a List.
    // Convert it into the 4 EstateKpiCard objects the UI expects.
    final kpiCards = _parseKpiCards(json['kpi_cards']);

    // disease_composition arrives as a Map {diseaseName: percentage}, not a List.
    final diseaseComposition = _parseDiseaseComposition(json['disease_composition']);

    return EstateInsights(
      kpiCards: kpiCards,
      riskMap: parseList(json['risk_map'], EstateRiskMapField.fromJson),
      diseaseTrend:
          parseList(json['disease_trend'], EstateDiseaseTrendPoint.fromJson),
      fieldPriority:
          parseList(json['field_priority'], EstateFieldPriority.fromJson),
      diseaseComposition: diseaseComposition,
      actionQueue: parseList(json['action_queue'], EstateActionItem.fromJson),
    );
  }

  /// Converts the API KPI summary object into the 4 EstateKpiCard UI objects.
  static List<EstateKpiCard> _parseKpiCards(dynamic raw) {
    if (raw is! Map) return [];
    final map = Map<String, dynamic>.from(raw);
    final highRisk = (map['high_risk_field_count'] as num?)?.toInt() ?? 0;
    final coverage = (map['scan_coverage_pct'] as num?)?.toDouble() ?? 0.0;
    final actionDue = (map['action_due_count'] as num?)?.toInt() ?? 0;
    final affectedArea =
        (map['affected_area_hectares'] as num?)?.toDouble() ?? 0.0;
    return [
      EstateKpiCard(
        label: 'High-risk fields',
        value: '$highRisk',
        caption: 'fields under high pressure',
        icon: Icons.warning_amber_rounded,
      ),
      EstateKpiCard(
        label: 'Scan coverage',
        value: '${coverage.round()}%',
        caption: 'fields scanned',
        icon: Icons.radar_rounded,
      ),
      EstateKpiCard(
        label: 'Actions due',
        value: '$actionDue',
        caption: 'items requiring follow-up',
        icon: Icons.task_alt_rounded,
      ),
      EstateKpiCard(
        label: 'Affected area',
        value: '${affectedArea.toStringAsFixed(1)} ha',
        caption: 'hectares under observation',
        icon: Icons.landscape_outlined,
      ),
    ];
  }

  /// Converts the API disease-composition Map into a sorted list.
  /// The API returns `{ "Disease Name": percentage, ... }`; the UI expects a
  /// `List<EstateDiseaseComposition>` sorted by descending percentage.
  static List<EstateDiseaseComposition> _parseDiseaseComposition(dynamic raw) {
    if (raw is! Map) return [];
    final entries = raw.entries
        .where((e) => e.value is num)
        .map((e) => EstateDiseaseComposition(
              disease: e.key,
              percentage: (e.value as num).round(),
            ))
        .toList();
    entries.sort((a, b) => b.percentage.compareTo(a.percentage));
    return entries;
  }

  bool get isEmpty =>
      kpiCards.isEmpty &&
      riskMap.isEmpty &&
      diseaseTrend.isEmpty &&
      fieldPriority.isEmpty &&
      diseaseComposition.isEmpty &&
      actionQueue.isEmpty;
}

// =============================================================================
// Field-level insights  (GET /api/v1/disease/field-insights/{field_id})
// =============================================================================

/// A dual-axis trend series used by the field health timeline and the
/// weather-vs-disease relationship cards.
class FieldTrendSeries {
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

  FieldTrendSeries({
    required this.title,
    required this.subtitle,
    IconData? icon,
    required this.primaryLabel,
    required this.secondaryLabel,
    Color? primaryColor,
    Color? secondaryColor,
    this.labels = const [],
    this.primaryValues = const [],
    this.secondaryValues = const [],
    required this.insight,
  })  : icon = icon ?? Icons.timeline_rounded,
        primaryColor = primaryColor ?? const Color(0xFF2F6B4F),
        secondaryColor = secondaryColor ?? const Color(0xFFB54848);

  factory FieldTrendSeries.fromJson(Map<String, dynamic> json) {
    toDoubleList(dynamic raw) =>
        (raw as List? ?? []).map((e) => (e as num).toDouble()).toList();
    toStringList(dynamic raw) =>
        (raw as List? ?? []).map((e) => e.toString()).toList();

    return FieldTrendSeries(
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      icon: parseIcon(json['icon']?.toString(), Icons.timeline_rounded),
      primaryLabel: json['primary_label']?.toString() ?? '',
      secondaryLabel: json['secondary_label']?.toString() ?? '',
      primaryColor: parseColor(json['primary_color']?.toString()),
      secondaryColor: parseColor(json['secondary_color']?.toString()),
      labels: toStringList(json['labels']),
      primaryValues: toDoubleList(json['primary_values']),
      secondaryValues: toDoubleList(json['secondary_values']),
      insight: json['insight']?.toString() ?? '',
    );
  }
}

/// One slice of the field-level confidence (disease probability) donut.
class FieldConfidenceSlice {
  final String label;
  final int percentage;

  FieldConfidenceSlice({required this.label, required this.percentage});
}

/// A single before/after treatment metric.
class FieldTreatmentResponse {
  final String label;
  final int before;
  final int after;

  FieldTreatmentResponse({
    required this.label,
    required this.before,
    required this.after,
  });
}

/// One scan record on the field health timeline.
///
/// The backend returns a list of these rather than a pre-built trend series,
/// so the screen converts them into a [FieldTrendSeries] for the chart.
class HealthTimelineEntry {
  final String date;
  final double healthPercentage;
  final String? detectedDisease;
  final double? confidence;

  HealthTimelineEntry({
    required this.date,
    required this.healthPercentage,
    this.detectedDisease,
    this.confidence,
  });

  factory HealthTimelineEntry.fromJson(Map<String, dynamic> json) {
    return HealthTimelineEntry(
      date: json['date']?.toString() ?? '',
      healthPercentage: (json['health_percentage'] as num?)?.toDouble() ?? 0.0,
      detectedDisease: json['detected_disease']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

/// Comparison of weather conditions during healthy vs disease scans.
///
/// The backend returns a flat object (not a chart-ready series), so the
/// screen builds a [FieldTrendSeries] from the metric pairs.
class WeatherDiseaseRelationship {
  final double? healthyAvgHumidity;
  final double? diseaseAvgHumidity;
  final double? healthyAvgRainfall;
  final double? diseaseAvgRainfall;
  final double? healthyAvgTemperature;
  final double? diseaseAvgTemperature;
  final String? insight;

  WeatherDiseaseRelationship({
    this.healthyAvgHumidity,
    this.diseaseAvgHumidity,
    this.healthyAvgRainfall,
    this.diseaseAvgRainfall,
    this.healthyAvgTemperature,
    this.diseaseAvgTemperature,
    this.insight,
  });

  factory WeatherDiseaseRelationship.fromJson(Map<String, dynamic> json) {
    return WeatherDiseaseRelationship(
      healthyAvgHumidity: (json['healthy_avg_humidity'] as num?)?.toDouble(),
      diseaseAvgHumidity: (json['disease_avg_humidity'] as num?)?.toDouble(),
      healthyAvgRainfall: (json['healthy_avg_rainfall'] as num?)?.toDouble(),
      diseaseAvgRainfall: (json['disease_avg_rainfall'] as num?)?.toDouble(),
      healthyAvgTemperature: (json['healthy_avg_temperature'] as num?)?.toDouble(),
      diseaseAvgTemperature: (json['disease_avg_temperature'] as num?)?.toDouble(),
      insight: json['insight']?.toString(),
    );
  }
}

/// Whether treatment response tracking data is available.
///
/// The backend currently always returns `available: false` with a message
/// explaining that treatment tracking requires a `treatment_history` table.
class TreatmentResponseTrend {
  final bool available;
  final String message;

  const TreatmentResponseTrend({this.available = false, this.message = ''});

  factory TreatmentResponseTrend.fromJson(Map<String, dynamic> json) {
    return TreatmentResponseTrend(
      available: json['available'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
    );
  }
}

/// Top-level field insights payload — the response of
/// `GET /api/v1/disease/field-insights/{field_id}`.
class FieldInsights {
  final String fieldId;
  final String fieldName;
  final double areaHectares;
  final int totalScans;
  final double? diseasePressureScore; // 0-100, nullable
  final String? diseasePressureStatus;
  final List<HealthTimelineEntry> fieldHealthTimeline;
  final List<FieldConfidenceSlice> confidenceDistribution;
  final WeatherDiseaseRelationship? weatherVsDisease;
  final TreatmentResponseTrend treatmentResponseTrend;
  final String? treatmentInsight;
  final List<EstateDiseaseTrendPoint> diseaseTrend;

  FieldInsights({
    required this.fieldId,
    required this.fieldName,
    required this.areaHectares,
    required this.totalScans,
    this.diseasePressureScore,
    this.diseasePressureStatus,
    this.fieldHealthTimeline = const [],
    this.confidenceDistribution = const [],
    this.weatherVsDisease,
    this.treatmentResponseTrend = const TreatmentResponseTrend(),
    this.treatmentInsight,
    this.diseaseTrend = const [],
  });

  factory FieldInsights.fromJson(Map<String, dynamic> json) {
    final score = (json['disease_pressure_score'] as num?)?.toDouble();

    // disease_pressure_status is not always returned by the API; derive a
    // human-readable descriptor from the numeric score when absent.
    String? status = json['disease_pressure_status']?.toString();
    if (status == null || status.isEmpty) {
      if (score == null) {
        status = 'No data';
      } else if (score >= 80) {
        status = 'High risk';
      } else if (score >= 50) {
        status = 'Elevated risk';
      } else if (score > 0) {
        status = 'Low risk';
      } else {
        status = 'No data';
      }
    }

    return FieldInsights(
      fieldId: json['field_id']?.toString() ?? '',
      fieldName:
          json['field_name']?.toString() ?? json['name']?.toString() ?? 'Field',
      areaHectares: (json['area_hectares'] as num?)?.toDouble() ?? 0.0,
      totalScans: (json['total_scans'] as num?)?.toInt() ?? 0,
      diseasePressureScore: score,
      diseasePressureStatus: status,
      fieldHealthTimeline: (json['field_health_timeline'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(HealthTimelineEntry.fromJson)
          .toList(),
      confidenceDistribution:
          _parseConfidenceDistribution(json['confidence_distribution']),
      weatherVsDisease: json['weather_vs_disease_relationship'] is Map
          ? WeatherDiseaseRelationship.fromJson(
              Map<String, dynamic>.from(
                json['weather_vs_disease_relationship'] as Map,
              ),
            )
          : null,
      treatmentResponseTrend: json['treatment_response_trend'] is Map
          ? TreatmentResponseTrend.fromJson(
              Map<String, dynamic>.from(
                json['treatment_response_trend'] as Map,
              ),
            )
          : const TreatmentResponseTrend(),
      treatmentInsight: json['treatment_insight']?.toString(),
      diseaseTrend: (json['disease_trend'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(EstateDiseaseTrendPoint.fromJson)
          .toList(),
    );
  }

  /// Converts the API confidence-distribution list of `{bucket, count}`
  /// items into percentage-based `FieldConfidenceSlice` objects for the
  /// donut chart.  Each slice's percentage is relative to the total scan
  /// count across all buckets.
  static List<FieldConfidenceSlice> _parseConfidenceDistribution(
    dynamic raw,
  ) {
    if (raw is! List) return [];
    final items = raw.whereType<Map<String, dynamic>>().toList();
    final total = items.fold<int>(
      0,
      (sum, e) => sum + ((e['count'] as num?)?.toInt() ?? 0),
    );
    if (total == 0) {
      return items
          .map((e) => FieldConfidenceSlice(
                label: e['bucket']?.toString() ?? '',
                percentage: 0,
              ))
          .toList();
    }
    return items
        .map((e) => FieldConfidenceSlice(
              label: e['bucket']?.toString() ?? '',
              percentage:
                  (((e['count'] as num?)?.toInt() ?? 0) / total * 100).round(),
            ))
        .toList();
  }

  /// Returns the disease trend, preferring the API-provided `disease_trend`
  /// field.  When the API does not return that field, this falls back to
  /// aggregating entries from [fieldHealthTimeline] by date so the
  /// trend graph always has real data to render.
  List<EstateDiseaseTrendPoint> getEffectiveDiseaseTrend() {
    if (diseaseTrend.isNotEmpty) return diseaseTrend;
    return _aggregateTimelineToTrend(fieldHealthTimeline);
  }

  /// Aggregates per-scan [HealthTimelineEntry] records into
  /// [EstateDiseaseTrendPoint] objects grouped by date, with each date's
  /// disease distribution expressed as counts (not percentages).
  static List<EstateDiseaseTrendPoint> _aggregateTimelineToTrend(
    List<HealthTimelineEntry> entries,
  ) {
    if (entries.isEmpty) return [];
    final byDate = <String, Map<String, int>>{};
    for (final entry in entries) {
      final date = entry.date;
      final dist = byDate.putIfAbsent(date, () => {});
      final disease = entry.detectedDisease ?? 'Healthy';
      dist[disease] = (dist[disease] ?? 0) + 1;
    }
    final result = byDate.entries.map((e) {
      final total = e.value.values.fold<int>(0, (s, v) => s + v);
      return EstateDiseaseTrendPoint(
        label: e.key,
        totalScans: total,
        diseaseDistribution: e.value,
      );
    }).toList();
    result.sort((a, b) => a.label.compareTo(b.label));
    return result;
  }
}
