class DiseaseWeatherSummary {
  final int? rainyDaysLast7;
  final int? rainyHoursLast7;
  final double? totalRainfallLast7;
  final double? avgTemperatureLast7;
  final double? avgHumidityLast7;
  final double? maxHumidityLast7;
  final double? avgWindSpeedLast7;
  final double? maxWindSpeedLast7;
  final double? avgSunshineHoursLast7;
  final double? estimatedLeafWetnessHoursLast7;

  const DiseaseWeatherSummary({
    this.rainyDaysLast7,
    this.rainyHoursLast7,
    this.totalRainfallLast7,
    this.avgTemperatureLast7,
    this.avgHumidityLast7,
    this.maxHumidityLast7,
    this.avgWindSpeedLast7,
    this.maxWindSpeedLast7,
    this.avgSunshineHoursLast7,
    this.estimatedLeafWetnessHoursLast7,
  });

  factory DiseaseWeatherSummary.fromJson(Map<String, dynamic> json) {
    return DiseaseWeatherSummary(
      rainyDaysLast7: (json['rainy_days_last_7'] as num?)?.toInt(),
      rainyHoursLast7: (json['rainy_hours_last_7'] as num?)?.toInt(),
      totalRainfallLast7: (json['total_rainfall_last_7'] as num?)?.toDouble(),
      avgTemperatureLast7: (json['avg_temperature_last_7'] as num?)?.toDouble(),
      avgHumidityLast7: (json['avg_humidity_last_7'] as num?)?.toDouble(),
      maxHumidityLast7: (json['max_humidity_last_7'] as num?)?.toDouble(),
      avgWindSpeedLast7: (json['avg_wind_speed_last_7'] as num?)?.toDouble(),
      maxWindSpeedLast7: (json['max_wind_speed_last_7'] as num?)?.toDouble(),
      avgSunshineHoursLast7:
          (json['avg_sunshine_hours_last_7'] as num?)?.toDouble(),
      estimatedLeafWetnessHoursLast7:
          (json['estimated_leaf_wetness_hours_last_7'] as num?)?.toDouble(),
    );
  }
}

class DiseasePrediction {
  final String disease;
  final String classKey;
  final double probability;

  const DiseasePrediction({
    required this.disease,
    required this.classKey,
    required this.probability,
  });

  factory DiseasePrediction.fromJson(Map<String, dynamic> json) {
    return DiseasePrediction(
      disease: json['disease']?.toString() ?? '',
      classKey: json['class_key']?.toString() ?? '',
      probability: (json['probability'] as num?)?.toDouble() ?? 0.0,
    );
  }

  int get percent => (probability * 100).round();
}

class EnvironmentFactor {
  final String feature;
  final double scaledValue;
  final double impact;
  final String effect; // 'increase_risk' | 'decrease_risk'

  const EnvironmentFactor({
    required this.feature,
    required this.scaledValue,
    required this.impact,
    required this.effect,
  });

  factory EnvironmentFactor.fromJson(Map<String, dynamic> json) {
    return EnvironmentFactor(
      feature: json['feature']?.toString() ?? '',
      scaledValue: (json['scaled_value'] as num?)?.toDouble() ?? 0.0,
      impact: (json['impact'] as num?)?.toDouble() ?? 0.0,
      effect: json['effect']?.toString() ?? '',
    );
  }

  bool get isRiskIncreasing => effect == 'increase_risk';
}

class PerImageExplanation {
  final String filename;
  final String gradcamImage;
  final List<EnvironmentFactor> environmentFactors;

  const PerImageExplanation({
    required this.filename,
    required this.gradcamImage,
    this.environmentFactors = const [],
  });

  factory PerImageExplanation.fromJson(Map<String, dynamic> json) {
    return PerImageExplanation(
      filename: json['filename']?.toString() ?? '',
      gradcamImage: json['gradcam_image']?.toString() ?? '',
      environmentFactors: (json['environment_factors'] as List? ?? [])
          .map((e) => EnvironmentFactor.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExplanationData {
  final String? aggregatedGradcam;
  final List<PerImageExplanation> perImage;

  const ExplanationData({
    this.aggregatedGradcam,
    this.perImage = const [],
  });

  factory ExplanationData.fromJson(Map<String, dynamic> json) {
    return ExplanationData(
      aggregatedGradcam: json['aggregated_gradcam']?.toString(),
      perImage: (json['per_image'] as List? ?? [])
          .map((e) => PerImageExplanation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DiseaseScanRecord {
  final String id;
  final String scanId;
  final String fieldId;
  final double? latitude;
  final double? longitude;
  final DateTime scanDatetime;
  final String? imageUrl;
  final List<String> imageUrls;
  final String detectedDisease;
  final String severity;
  final double confidence;
  final String description;
  final DiseaseWeatherSummary? weatherSummary;
  final String? riskLevel;
  final String? riskReason;
  final List<String> treatmentSuggestions;
  final List<DiseasePrediction> allPredictions;
  final String? modelVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ExplanationData? explanationData;
  final String? environmentalSummary;

  const DiseaseScanRecord({
    required this.id,
    required this.scanId,
    required this.fieldId,
    this.latitude,
    this.longitude,
    required this.scanDatetime,
    this.imageUrl,
    this.imageUrls = const [],
    required this.detectedDisease,
    required this.severity,
    required this.confidence,
    required this.description,
    this.weatherSummary,
    this.riskLevel,
    this.riskReason,
    this.treatmentSuggestions = const [],
    this.allPredictions = const [],
    this.modelVersion,
    this.createdAt,
    this.updatedAt,
    this.explanationData,
    this.environmentalSummary,
  });

  factory DiseaseScanRecord.fromJson(Map<String, dynamic> json) {
    final rawImageUrls = json['image_urls'] as List?;
    final parsedImageUrls = rawImageUrls != null
        ? rawImageUrls.map((e) => e.toString()).toList()
        : <String>[];

    final singleImageUrl = json['image_url']?.toString();
    if (parsedImageUrls.isEmpty &&
        singleImageUrl != null &&
        singleImageUrl.isNotEmpty) {
      parsedImageUrls.add(singleImageUrl);
    }

    return DiseaseScanRecord(
      id: json['id']?.toString() ?? '',
      scanId: json['scan_id']?.toString() ?? '',
      fieldId: json['field_id']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      scanDatetime:
          DateTime.tryParse(json['scan_datetime']?.toString() ?? '') ??
              DateTime.now(),
      imageUrl: singleImageUrl ??
          (parsedImageUrls.isNotEmpty ? parsedImageUrls.first : null),
      imageUrls: parsedImageUrls,
      detectedDisease: json['detected_disease']?.toString() ?? 'Unknown',
      severity: json['severity']?.toString() ?? 'unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString() ?? '',
      weatherSummary: json['weather_summary'] is Map<String, dynamic>
          ? DiseaseWeatherSummary.fromJson(
              json['weather_summary'] as Map<String, dynamic>,
            )
          : null,
      riskLevel: json['risk_level']?.toString(),
      riskReason: json['risk_reason']?.toString(),
      treatmentSuggestions: (json['treatment_suggestions'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      allPredictions: (json['all_predictions'] as List? ?? [])
          .map((e) => DiseasePrediction.fromJson(e as Map<String, dynamic>))
          .toList(),
      modelVersion: json['model_version']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      explanationData: json['explanation_data'] is Map<String, dynamic>
          ? ExplanationData.fromJson(
              json['explanation_data'] as Map<String, dynamic>,
            )
          : null,
      environmentalSummary: json['environmental_summary']?.toString(),
    );
  }

  int get confidencePercent => (confidence * 100).round();

  bool get isHealthy => detectedDisease.toLowerCase() == 'healthy';

  String? get primaryImageUrl =>
      imageUrls.isNotEmpty ? imageUrls.first : imageUrl;
}
