import 'dart:ui' show Offset;
import 'dart:math';

import 'package:flutter/foundation.dart';

enum AlertSeverity { info, warning, critical }

class WeatherSnapshot {
  final DateTime date;
  final String summary;
  final int rainChance;
  final int humidity;
  final double temperatureC;
  final bool stormRisk;

  const WeatherSnapshot({
    required this.date,
    required this.summary,
    required this.rainChance,
    required this.humidity,
    required this.temperatureC,
    required this.stormRisk,
  });
}

class LaborPlan {
  final int availableWorkers;
  final int recommendedWorkers;
  final String shiftStart;
  final bool smsScheduled;
  final List<String> focusZones;

  const LaborPlan({
    required this.availableWorkers,
    required this.recommendedWorkers,
    required this.shiftStart,
    required this.smsScheduled,
    required this.focusZones,
  });

  bool get hasShortage => availableWorkers < recommendedWorkers;
}

class InsightAlert {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime createdAt;

  const InsightAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
  });
}

class AppNotificationItem {
  final String id;
  final String fieldName;
  final String title;
  final String message;
  final String category;
  final DateTime createdAt;
  final AlertSeverity severity;
  final bool isUnread;

  const AppNotificationItem({
    required this.id,
    required this.fieldName,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    required this.severity,
    this.isUnread = true,
  });
}

class AnalysisImageResult {
  final String id;
  final String? imagePath;
  final String sourceLabel;
  final DateTime capturedAt;
  final int arimbuCount;
  final int pluckableCount;
  final double capturedArea;
  final List<Offset> budMarkers;

  const AnalysisImageResult({
    required this.id,
    required this.imagePath,
    required this.sourceLabel,
    required this.capturedAt,
    required this.arimbuCount,
    required this.pluckableCount,
    required this.capturedArea,
    required this.budMarkers,
  });

  int get totalBuds => arimbuCount + pluckableCount;

  double get pluckableRatio => totalBuds == 0 ? 0 : pluckableCount / totalBuds;
}

class FieldMeasurement {
  final String id;
  final DateTime date;
  final List<AnalysisImageResult> analyzedImages;
  final double? fieldArea;
  final double? predictedYieldKg;
  final double? actualYieldKg;
  final WeatherSnapshot? weather;
  final LaborPlan? laborPlan;

  const FieldMeasurement({
    required this.id,
    required this.date,
    required this.analyzedImages,
    this.fieldArea,
    this.predictedYieldKg,
    this.actualYieldKg,
    this.weather,
    this.laborPlan,
  });

  FieldMeasurement copyWith({
    String? id,
    DateTime? date,
    List<AnalysisImageResult>? analyzedImages,
    double? fieldArea,
    double? predictedYieldKg,
    double? actualYieldKg,
    WeatherSnapshot? weather,
    LaborPlan? laborPlan,
    bool clearPrediction = false,
  }) {
    return FieldMeasurement(
      id: id ?? this.id,
      date: date ?? this.date,
      analyzedImages: analyzedImages ?? this.analyzedImages,
      fieldArea: fieldArea ?? this.fieldArea,
      predictedYieldKg: clearPrediction
          ? null
          : predictedYieldKg ?? this.predictedYieldKg,
      actualYieldKg: actualYieldKg ?? this.actualYieldKg,
      weather: weather ?? this.weather,
      laborPlan: laborPlan ?? this.laborPlan,
    );
  }

  int get totalArimbuCount =>
      analyzedImages.fold(0, (sum, image) => sum + image.arimbuCount);

  int get totalPluckableCount =>
      analyzedImages.fold(0, (sum, image) => sum + image.pluckableCount);

  int get imageCount => analyzedImages.length;

  double get averagePluckableRatio {
    if (analyzedImages.isEmpty) {
      return 0;
    }
    final totalRatio = analyzedImages.fold<double>(
      0,
      (sum, image) => sum + image.pluckableRatio,
    );
    return totalRatio / analyzedImages.length;
  }

  double get totalCapturedArea =>
      analyzedImages.fold(0.0, (sum, image) => sum + image.capturedArea);

  bool get isReadyToPluck =>
      averagePluckableRatio >= 0.60 && averagePluckableRatio <= 0.70;

  bool get hasActualYield => actualYieldKg != null && actualYieldKg! > 0;

  double? get yieldVarianceKg {
    if (predictedYieldKg == null || actualYieldKg == null) {
      return null;
    }
    return actualYieldKg! - predictedYieldKg!;
  }

  double? get yieldVariancePercent {
    if (predictedYieldKg == null ||
        actualYieldKg == null ||
        predictedYieldKg == 0) {
      return null;
    }
    return ((actualYieldKg! - predictedYieldKg!) / predictedYieldKg!) * 100;
  }

  bool get hasOverPluckingRisk => (yieldVariancePercent ?? 0) >= 15;

  String get laborPriorityLabel {
    final ratio = averagePluckableRatio;
    if (ratio >= 0.60 && ratio <= 0.70) {
      return 'Dispatch now';
    }
    if (ratio > 0.70) {
      return 'Urgent review';
    }
    if (ratio >= 0.50) {
      return 'Prepare crew';
    }
    return 'Monitor only';
  }

  int get laborPriorityScore {
    final base = (averagePluckableRatio * 100).round();
    final yieldBoost = ((predictedYieldKg ?? 0) / 4).round();
    final riskBoost = hasOverPluckingRisk ? 8 : 0;
    return (base + yieldBoost + riskBoost).clamp(0, 100);
  }

  String get readinessLabel {
    if (analyzedImages.isEmpty) {
      return 'Awaiting analysis';
    }
    if (isReadyToPluck) {
      return 'Ready to pluck';
    }
    if (averagePluckableRatio > 0.70) {
      return 'Highly mature';
    }
    return 'Needs more growth';
  }
}

class Field {
  final String id;
  String name;
  final DateTime? _createdAt;
  final String region;
  final double areaHectares;
  List<FieldMeasurement> measurements;

  Field({
    required this.id,
    required this.name,
    required this.region,
    required this.areaHectares,
    DateTime? createdAt,
    List<FieldMeasurement>? measurements,
  }) : _createdAt = createdAt,
       measurements = measurements ?? [];

  DateTime get createdAt => _createdAt ?? DateTime.now();

  FieldMeasurement? get latestMeasurement =>
      measurements.isEmpty ? null : measurements.last;
}

class FieldManager extends ChangeNotifier {
  static final FieldManager _instance = FieldManager._internal();
  factory FieldManager() => _instance;
  FieldManager._internal();

  final List<Field> _fields = [
    Field(
      id: '1',
      name: 'Highland North Block',
      region: 'Hatton Division',
      areaHectares: 2.4,
      createdAt: DateTime.now().subtract(const Duration(days: 12, hours: 4)),
      measurements: [
        FieldMeasurement(
          id: 'm-1001',
          date: DateTime.now().subtract(const Duration(days: 9)),
          fieldArea: 2.4,
          predictedYieldKg: 186.5,
          actualYieldKg: 214.0,
          weather: WeatherSnapshot(
            date: DateTime.now().subtract(const Duration(days: 9)),
            summary: 'Cloudy morning',
            rainChance: 34,
            humidity: 78,
            temperatureC: 22.5,
            stormRisk: false,
          ),
          laborPlan: LaborPlan(
            availableWorkers: 8,
            recommendedWorkers: 10,
            shiftStart: '06:00 AM',
            smsScheduled: true,
            focusZones: ['North row', 'Center lane'],
          ),
          analyzedImages: [
            _mockImageResult(
              id: 'img-1',
              sourceLabel: 'North row',
              arimbuCount: 24,
              pluckableCount: 39,
              capturedArea: 8.2,
              seed: 1,
            ),
            _mockImageResult(
              id: 'img-2',
              sourceLabel: 'Center aisle',
              arimbuCount: 22,
              pluckableCount: 37,
              capturedArea: 7.8,
              seed: 2,
            ),
            _mockImageResult(
              id: 'img-3',
              sourceLabel: 'South edge',
              arimbuCount: 20,
              pluckableCount: 34,
              capturedArea: 8.5,
              seed: 3,
            ),
          ],
        ),
      ],
    ),
    Field(
      id: '2',
      name: 'Lower Valley Section B',
      region: 'Dickoya Division',
      areaHectares: 1.8,
      createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
      measurements: [
        FieldMeasurement(
          id: 'm-1002',
          date: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
          fieldArea: 1.8,
          predictedYieldKg: 126.0,
          weather: WeatherSnapshot(
            date: DateTime.now(),
            summary: 'Rain after noon',
            rainChance: 72,
            humidity: 86,
            temperatureC: 21.0,
            stormRisk: true,
          ),
          laborPlan: LaborPlan(
            availableWorkers: 5,
            recommendedWorkers: 7,
            shiftStart: '06:30 AM',
            smsScheduled: false,
            focusZones: ['Lower terrace', 'River edge'],
          ),
          analyzedImages: [
            _mockImageResult(
              id: 'img-4',
              sourceLabel: 'Terrace A',
              arimbuCount: 28,
              pluckableCount: 25,
              capturedArea: 7.3,
              seed: 4,
            ),
            _mockImageResult(
              id: 'img-5',
              sourceLabel: 'Terrace B',
              arimbuCount: 31,
              pluckableCount: 26,
              capturedArea: 7.9,
              seed: 5,
            ),
            _mockImageResult(
              id: 'img-6',
              sourceLabel: 'River edge',
              arimbuCount: 25,
              pluckableCount: 24,
              capturedArea: 8.0,
              seed: 6,
            ),
          ],
        ),
      ],
    ),
  ];

  List<Field> get fields => _fields;

  void addField(String name) {
    _fields.add(
      Field(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        region: 'New Division',
        areaHectares: 2.0,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void deleteField(String fieldId) {
    _fields.removeWhere((field) => field.id == fieldId);
    notifyListeners();
  }

  FieldMeasurement createDraftMeasurement(String fieldId) {
    final field = _findField(fieldId);
    final measurement = FieldMeasurement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      analyzedImages: const [],
      fieldArea: field.areaHectares,
      weather: _buildWeatherForField(field),
      laborPlan: _buildLaborPlanForField(field, const []),
    );
    field.measurements.add(measurement);
    notifyListeners();
    return measurement;
  }

  void saveMeasurement(String fieldId, FieldMeasurement measurement) {
    final field = _findField(fieldId);
    final index = field.measurements.indexWhere((m) => m.id == measurement.id);
    if (index == -1) {
      field.measurements.add(measurement);
    } else {
      field.measurements[index] = measurement;
    }
    notifyListeners();
  }

  void removeMeasurement(String fieldId, String measurementId) {
    final field = _findField(fieldId);
    field.measurements.removeWhere(
      (measurement) => measurement.id == measurementId,
    );
    notifyListeners();
  }

  void deleteMeasurement(String fieldId, String measurementId) {
    removeMeasurement(fieldId, measurementId);
  }

  void updateActualYield(
    String fieldId,
    String measurementId,
    double actualYieldKg,
  ) {
    final field = _findField(fieldId);
    final index = field.measurements.indexWhere((m) => m.id == measurementId);
    if (index == -1) {
      return;
    }
    field.measurements[index] = field.measurements[index].copyWith(
      actualYieldKg: actualYieldKg,
    );
    notifyListeners();
  }

  FieldMeasurement hydrateMeasurementSupportData(
    String fieldId,
    FieldMeasurement measurement,
  ) {
    final field = _findField(fieldId);
    return measurement.copyWith(
      weather: _buildWeatherForField(field),
      laborPlan: _buildLaborPlanForField(field, measurement.analyzedImages),
    );
  }

  List<AppNotificationItem> get notifications {
    final items = <AppNotificationItem>[];
    for (final field in _fields) {
      final measurement = field.latestMeasurement;
      if (measurement == null) {
        continue;
      }

      if (measurement.weather?.stormRisk == true) {
        items.add(
          AppNotificationItem(
            id: '${field.id}-weather',
            fieldName: field.name,
            title: 'Weather warning',
            message:
                'Rain risk is high. Move plucking round earlier and protect collected leaf quality.',
            category: 'Weather',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            severity: AlertSeverity.warning,
          ),
        );
      }

      if (measurement.laborPlan?.hasShortage == true) {
        items.add(
          AppNotificationItem(
            id: '${field.id}-labor',
            fieldName: field.name,
            title: 'Labor shortage',
            message:
                'Only ${measurement.laborPlan!.availableWorkers} workers available for ${measurement.laborPlan!.recommendedWorkers} required slots.',
            category: 'Labor',
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            severity: AlertSeverity.critical,
          ),
        );
      }

      if (measurement.hasOverPluckingRisk) {
        final variance = measurement.yieldVariancePercent!.toStringAsFixed(1);
        items.add(
          AppNotificationItem(
            id: '${field.id}-overpluck',
            fieldName: field.name,
            title: 'Over-plucking alert',
            message:
                'Actual yield is $variance% above prediction. Review coarse leaves and restricted Arimbu mixing.',
            category: 'Quality',
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
            severity: AlertSeverity.critical,
          ),
        );
      }

      if (measurement.isReadyToPluck) {
        items.add(
          AppNotificationItem(
            id: '${field.id}-ready',
            fieldName: field.name,
            title: 'Ready to pluck',
            message:
                'The maturity ratio is in the optimal window. Crew reminder can be sent for ${measurement.laborPlan?.shiftStart ?? 'next round'}.',
            category: 'Reminder',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            severity: AlertSeverity.info,
            isUnread: false,
          ),
        );
      }
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  int get unreadNotificationCount =>
      notifications.where((item) => item.isUnread).length;

  double get predictedYieldTotalKg => _fields.fold(
    0,
    (sum, field) => sum + (field.latestMeasurement?.predictedYieldKg ?? 0),
  );

  double get actualYieldTotalKg => _fields.fold(
    0,
    (sum, field) => sum + (field.latestMeasurement?.actualYieldKg ?? 0),
  );

  List<Field> get prioritizedFields {
    final sorted = List<Field>.from(_fields);
    sorted.sort((a, b) {
      final aScore = a.latestMeasurement?.laborPriorityScore ?? 0;
      final bScore = b.latestMeasurement?.laborPriorityScore ?? 0;
      return bScore.compareTo(aScore);
    });
    return sorted;
  }

  List<InsightAlert> buildInsightsForMeasurement(
    Field field,
    FieldMeasurement measurement,
  ) {
    final alerts = <InsightAlert>[];

    if (measurement.weather?.stormRisk == true) {
      alerts.add(
        InsightAlert(
          id: '${measurement.id}-storm',
          title: 'Weather pressure detected',
          message:
              'Forecast suggests rain after the morning window. Finish priority rows before noon.',
          severity: AlertSeverity.warning,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (measurement.laborPlan?.hasShortage == true) {
      alerts.add(
        InsightAlert(
          id: '${measurement.id}-labor',
          title: 'Labor reallocation needed',
          message:
              'Assign workers from low-priority fields to ${field.name} to avoid maturity loss.',
          severity: AlertSeverity.warning,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (measurement.hasOverPluckingRisk) {
      alerts.add(
        InsightAlert(
          id: '${measurement.id}-yield-gap',
          title: 'Quota dilution risk',
          message:
              'Actual leaf intake is unusually above the predicted yield. Inspect coarse leaves and picking discipline.',
          severity: AlertSeverity.critical,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (measurement.isReadyToPluck) {
      alerts.add(
        InsightAlert(
          id: '${measurement.id}-ready',
          title: 'Optimal plucking window',
          message:
              'Bud maturity is within the target range for quality-preserving harvest.',
          severity: AlertSeverity.info,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (alerts.isEmpty) {
      alerts.add(
        InsightAlert(
          id: '${measurement.id}-observe',
          title: 'Continue monitoring',
          message:
              'This field is still building maturity. Re-sample before committing crew allocation.',
          severity: AlertSeverity.info,
          createdAt: DateTime.now(),
        ),
      );
    }

    return alerts;
  }

  Field _findField(String fieldId) {
    return _fields.firstWhere((field) => field.id == fieldId);
  }

  static WeatherSnapshot _buildWeatherForField(Field field) {
    final seed = field.name.length;
    return WeatherSnapshot(
      date: DateTime.now(),
      summary: seed.isEven ? 'Light clouds' : 'Rain after noon',
      rainChance: seed.isEven ? 38 : 68,
      humidity: seed.isEven ? 76 : 88,
      temperatureC: seed.isEven ? 22.0 : 20.5,
      stormRisk: !seed.isEven,
    );
  }

  static LaborPlan _buildLaborPlanForField(
    Field field,
    List<AnalysisImageResult> images,
  ) {
    final availableWorkers = 6 + (field.name.length % 3);
    final recommendedWorkers =
        max(availableWorkers, 7) + (images.length >= 3 ? 1 : 0);
    return LaborPlan(
      availableWorkers: availableWorkers,
      recommendedWorkers: recommendedWorkers,
      shiftStart: '06:00 AM',
      smsScheduled: images.length >= 3,
      focusZones: images
          .take(2)
          .map((item) => item.sourceLabel)
          .toList(growable: false),
    );
  }

  static AnalysisImageResult _mockImageResult({
    required String id,
    required String sourceLabel,
    required int arimbuCount,
    required int pluckableCount,
    required double capturedArea,
    required int seed,
  }) {
    return AnalysisImageResult(
      id: id,
      imagePath: null,
      sourceLabel: sourceLabel,
      capturedAt: DateTime.now().subtract(Duration(days: seed * 2)),
      arimbuCount: arimbuCount,
      pluckableCount: pluckableCount,
      capturedArea: capturedArea,
      budMarkers: _generateMarkers(seed, arimbuCount + pluckableCount),
    );
  }

  static List<Offset> _generateMarkers(int seed, int count) {
    final random = Random(seed);
    final markerCount = min(count, 14);
    return List.generate(
      markerCount,
      (_) => Offset(
        0.15 + (random.nextDouble() * 0.70),
        0.18 + (random.nextDouble() * 0.62),
      ),
    );
  }
}
