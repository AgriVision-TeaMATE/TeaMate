import 'dart:ui' show Offset;
import 'dart:math';

import 'package:flutter/foundation.dart';

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

  double get pluckableRatio =>
      totalBuds == 0 ? 0 : pluckableCount / totalBuds;
}

class FieldMeasurement {
  final String id;
  final DateTime date;
  final List<AnalysisImageResult> analyzedImages;
  final double? fieldArea;
  final double? predictedYieldKg;

  const FieldMeasurement({
    required this.id,
    required this.date,
    required this.analyzedImages,
    this.fieldArea,
    this.predictedYieldKg,
  });

  FieldMeasurement copyWith({
    String? id,
    DateTime? date,
    List<AnalysisImageResult>? analyzedImages,
    double? fieldArea,
    double? predictedYieldKg,
    bool clearPrediction = false,
  }) {
    return FieldMeasurement(
      id: id ?? this.id,
      date: date ?? this.date,
      analyzedImages: analyzedImages ?? this.analyzedImages,
      fieldArea: fieldArea ?? this.fieldArea,
      predictedYieldKg:
          clearPrediction ? null : predictedYieldKg ?? this.predictedYieldKg,
    );
  }

  int get totalArimbuCount => analyzedImages.fold(
    0,
    (sum, image) => sum + image.arimbuCount,
  );

  int get totalPluckableCount => analyzedImages.fold(
    0,
    (sum, image) => sum + image.pluckableCount,
  );

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

  double get totalCapturedArea => analyzedImages.fold(
    0.0,
    (sum, image) => sum + image.capturedArea,
  );

  bool get isReadyToPluck =>
      averagePluckableRatio >= 0.60 && averagePluckableRatio <= 0.70;

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
  List<FieldMeasurement> measurements;

  Field({
    required this.id,
    required this.name,
    DateTime? createdAt,
    List<FieldMeasurement>? measurements,
  })  : _createdAt = createdAt,
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
      createdAt: DateTime.now().subtract(const Duration(days: 12, hours: 4)),
      measurements: [
        FieldMeasurement(
          id: 'm-1001',
          date: DateTime.now().subtract(const Duration(days: 9)),
          fieldArea: 2.4,
          predictedYieldKg: 186.5,
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
      createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
    ),
  ];

  List<Field> get fields => _fields;

  void addField(String name) {
    _fields.add(
      Field(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
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
    field.measurements.removeWhere((measurement) => measurement.id == measurementId);
    notifyListeners();
  }

  void deleteMeasurement(String fieldId, String measurementId) {
    removeMeasurement(fieldId, measurementId);
  }

  Field _findField(String fieldId) {
    return _fields.firstWhere((field) => field.id == fieldId);
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
