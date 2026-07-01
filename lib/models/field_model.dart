import 'dart:ui' show Offset;
import 'dart:math' show max;

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

enum AlertSeverity { info, warning, critical }

enum WorkerStatus { available, assigned, onLeave }

enum SkillLevel { junior, experienced, senior }

enum ScheduleStatus { scheduled, inProgress, completed, cancelled }

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

class WeatherHourly {
  final DateTime time;
  final double temperatureC;
  final int rainChance;
  final int humidity;
  final double windSpeedKmh;
  final int weatherCode;
  final String description;

  const WeatherHourly({
    required this.time,
    required this.temperatureC,
    required this.rainChance,
    required this.humidity,
    required this.windSpeedKmh,
    required this.weatherCode,
    required this.description,
  });
}

class WeatherDaily {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final int rainChance;
  final int weatherCode;
  final String description;
  final double precipitationMm;

  const WeatherDaily({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.rainChance,
    required this.weatherCode,
    required this.description,
    required this.precipitationMm,
  });
}

class WeatherForecast {
  final DateTime fetchedAt;
  final double currentTemp;
  final int currentHumidity;
  final double currentWindSpeed;
  final int currentWeatherCode;
  final String currentDescription;
  final double feelsLike;
  final List<WeatherHourly> hourly;
  final List<WeatherDaily> daily;

  const WeatherForecast({
    required this.fetchedAt,
    required this.currentTemp,
    required this.currentHumidity,
    required this.currentWindSpeed,
    required this.currentWeatherCode,
    required this.currentDescription,
    required this.feelsLike,
    required this.hourly,
    required this.daily,
  });

  int get currentRainChance {
    if (hourly.isEmpty) return 0;
    final now = DateTime.now();
    final closest = hourly.reduce((a, b) =>
        (a.time.difference(now).abs() < b.time.difference(now).abs()) ? a : b);
    return closest.rainChance;
  }

  bool get hasStormRisk =>
      hourly.take(6).any((h) => h.rainChance > 70 || h.windSpeedKmh > 40);

  String? get pluckingWindowRecommendation {
    final now = DateTime.now();
    final upcoming = hourly.where((h) => h.time.isAfter(now)).toList();
    if (upcoming.isEmpty) return null;

    // Look for 4-hour dry windows
    for (int i = 0; i < upcoming.length - 3; i++) {
      final window = upcoming.sublist(i, i + 4);
      final allDry = window.every((h) => h.rainChance < 30);
      final goodTemp =
          window.every((h) => h.temperatureC > 18 && h.temperatureC < 30);
      if (allDry && goodTemp) {
        final start = window.first.time;
        final end = window.last.time;
        final startHour =
            '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
        final endHour =
            '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
        final isToday = start.day == now.day;
        final dayLabel = isToday ? 'Today' : 'Tomorrow';
        return '$dayLabel $startHour – $endHour';
      }
    }
    return null;
  }
}

class Worker {
  final String id;
  String name;
  String phone;
  WorkerStatus status;
  SkillLevel skillLevel;
  String? assignedFieldId;
  final DateTime createdAt;

  Worker({
    required this.id,
    required this.name,
    required this.phone,
    this.status = WorkerStatus.available,
    this.skillLevel = SkillLevel.experienced,
    this.assignedFieldId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get statusLabel {
    switch (status) {
      case WorkerStatus.available:
        return 'Available';
      case WorkerStatus.assigned:
        return 'Assigned';
      case WorkerStatus.onLeave:
        return 'On Leave';
    }
  }

  String get skillLabel {
    switch (skillLevel) {
      case SkillLevel.junior:
        return 'Junior';
      case SkillLevel.experienced:
        return 'Experienced';
      case SkillLevel.senior:
        return 'Senior';
    }
  }
}

class PluckingSchedule {
  final String id;
  final String fieldId;
  final DateTime scheduledDate;
  final String shiftStart;
  final String shiftEnd;
  final List<String> assignedWorkerIds;
  ScheduleStatus status;

  PluckingSchedule({
    required this.id,
    required this.fieldId,
    required this.scheduledDate,
    required this.shiftStart,
    required this.shiftEnd,
    required this.assignedWorkerIds,
    this.status = ScheduleStatus.scheduled,
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
  final double latitude;
  final double longitude;
  final double elevationMeters;
  List<FieldMeasurement> measurements;
  List<String> assignedWorkerIds;

  Field({
    required this.id,
    required this.name,
    required this.region,
    required this.areaHectares,
    this.latitude = 6.9271,
    this.longitude = 80.6005,
    this.elevationMeters = 1200,
    DateTime? createdAt,
    List<FieldMeasurement>? measurements,
    List<String>? assignedWorkerIds,
  })  : _createdAt = createdAt,
        measurements = measurements ?? [],
        assignedWorkerIds = assignedWorkerIds ?? [];

  DateTime get createdAt => _createdAt ?? DateTime.now();

  FieldMeasurement? get latestMeasurement =>
      measurements.isEmpty ? null : measurements.last;
}

class FieldManager extends ChangeNotifier {
  static final FieldManager _instance = FieldManager._internal();
  factory FieldManager() => _instance;

  final ApiService _api = ApiService();

  FieldManager._internal() {
    syncFromServer();
  }

  Future<void> syncFromServer() async {
    try {
      final fields = await _api.fetchFields();
      final workers = await _api.fetchWorkers();
      if (fields.isNotEmpty) {
        _fields.clear();
        _fields.addAll(fields);
      }
      if (workers.isNotEmpty) {
        _workers.clear();
        _workers.addAll(workers);
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── Workers ───────────────────────────────────────────────
  final List<Worker> _workers = [
    Worker(
      id: 'w1',
      name: 'Kamal Perera',
      phone: '+94 77 123 4567',
      status: WorkerStatus.assigned,
      skillLevel: SkillLevel.senior,
      assignedFieldId: '1',
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    ),
    Worker(
      id: 'w2',
      name: 'Nimal Silva',
      phone: '+94 76 234 5678',
      status: WorkerStatus.assigned,
      skillLevel: SkillLevel.experienced,
      assignedFieldId: '1',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    Worker(
      id: 'w3',
      name: 'Saman Jayawardena',
      phone: '+94 71 345 6789',
      status: WorkerStatus.assigned,
      skillLevel: SkillLevel.experienced,
      assignedFieldId: '2',
      createdAt: DateTime.now().subtract(const Duration(days: 200)),
    ),
    Worker(
      id: 'w4',
      name: 'Ruwan Fernando',
      phone: '+94 78 456 7890',
      status: WorkerStatus.available,
      skillLevel: SkillLevel.junior,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    Worker(
      id: 'w5',
      name: 'Dilshan Kumara',
      phone: '+94 75 567 8901',
      status: WorkerStatus.assigned,
      skillLevel: SkillLevel.senior,
      assignedFieldId: '3',
      createdAt: DateTime.now().subtract(const Duration(days: 300)),
    ),
    Worker(
      id: 'w6',
      name: 'Priyantha Bandara',
      phone: '+94 77 678 9012',
      status: WorkerStatus.onLeave,
      skillLevel: SkillLevel.experienced,
      createdAt: DateTime.now().subtract(const Duration(days: 150)),
    ),
    Worker(
      id: 'w7',
      name: 'Chaminda Wijesinghe',
      phone: '+94 76 789 0123',
      status: WorkerStatus.assigned,
      skillLevel: SkillLevel.experienced,
      assignedFieldId: '4',
      createdAt: DateTime.now().subtract(const Duration(days: 80)),
    ),
    Worker(
      id: 'w8',
      name: 'Lakmal Rathnayake',
      phone: '+94 71 890 1234',
      status: WorkerStatus.available,
      skillLevel: SkillLevel.junior,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    Worker(
      id: 'w9',
      name: 'Ashan de Mel',
      phone: '+94 78 901 2345',
      status: WorkerStatus.assigned,
      skillLevel: SkillLevel.senior,
      assignedFieldId: '5',
      createdAt: DateTime.now().subtract(const Duration(days: 250)),
    ),
    Worker(
      id: 'w10',
      name: 'Tharuka Gamage',
      phone: '+94 75 012 3456',
      status: WorkerStatus.available,
      skillLevel: SkillLevel.experienced,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
  ];

  List<Worker> get workers => _workers;

  List<Worker> get availableWorkers =>
      _workers.where((w) => w.status == WorkerStatus.available).toList();

  List<Worker> get assignedWorkers =>
      _workers.where((w) => w.status == WorkerStatus.assigned).toList();

  List<Worker> get onLeaveWorkers =>
      _workers.where((w) => w.status == WorkerStatus.onLeave).toList();

  List<Worker> workersForField(String fieldId) =>
      _workers.where((w) => w.assignedFieldId == fieldId).toList();

  void addWorker({
    required String name,
    required String phone,
    SkillLevel skillLevel = SkillLevel.experienced,
  }) {
    final tempId = 'w${DateTime.now().millisecondsSinceEpoch}';
    _workers.add(Worker(
      id: tempId,
      name: name,
      phone: phone,
      skillLevel: skillLevel,
      status: WorkerStatus.available,
    ));
    notifyListeners();
    _api.addWorker(name: name, phone: phone, skillLevel: skillLevel).then((w) {
      if (w != null) syncFromServer();
    });
  }

  void updateWorker(String workerId, {String? name, String? phone, SkillLevel? skillLevel}) {
    final worker = _workers.firstWhere((w) => w.id == workerId);
    if (name != null) worker.name = name;
    if (phone != null) worker.phone = phone;
    if (skillLevel != null) worker.skillLevel = skillLevel;
    notifyListeners();
  }

  void deleteWorker(String workerId) {
    _workers.removeWhere((w) => w.id == workerId);
    notifyListeners();
    _api.deleteWorker(workerId);
  }

  void assignWorkerToField(String workerId, String fieldId) {
    final worker = _workers.firstWhere((w) => w.id == workerId);
    worker.assignedFieldId = fieldId;
    worker.status = WorkerStatus.assigned;
    final field = _findField(fieldId);
    if (!field.assignedWorkerIds.contains(workerId)) {
      field.assignedWorkerIds.add(workerId);
    }
    notifyListeners();
    _api.assignWorkerToField(workerId, fieldId);
  }

  void unassignWorker(String workerId) {
    final worker = _workers.firstWhere((w) => w.id == workerId);
    if (worker.assignedFieldId != null) {
      try {
        final field = _findField(worker.assignedFieldId!);
        field.assignedWorkerIds.remove(workerId);
      } catch (_) {}
    }
    worker.assignedFieldId = null;
    worker.status = WorkerStatus.available;
    notifyListeners();
    _api.unassignWorker(workerId);
  }

  void setWorkerStatus(String workerId, WorkerStatus status) {
    final worker = _workers.firstWhere((w) => w.id == workerId);
    if (status == WorkerStatus.onLeave && worker.assignedFieldId != null) {
      unassignWorker(workerId);
    }
    worker.status = status;
    notifyListeners();
    _api.updateWorkerStatus(workerId, status);
  }

  // ── Schedules ─────────────────────────────────────────────
  final List<PluckingSchedule> _schedules = [];

  List<PluckingSchedule> get schedules => _schedules;

  List<PluckingSchedule> schedulesForField(String fieldId) =>
      _schedules.where((s) => s.fieldId == fieldId).toList();

  // ── Weather cache ─────────────────────────────────────────
  WeatherForecast? _cachedForecast;

  WeatherForecast? get cachedForecast => _cachedForecast;

  void updateForecast(WeatherForecast forecast) {
    _cachedForecast = forecast;
    notifyListeners();
  }

  // ── Fields ────────────────────────────────────────────────
  final List<Field> _fields = [
    Field(
      id: '1',
      name: 'Highland North Block',
      region: 'Hatton Division',
      areaHectares: 2.4,
      latitude: 6.8985,
      longitude: 80.5853,
      elevationMeters: 1250,
      assignedWorkerIds: ['w1', 'w2'],
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
          analyzedImages: const [],
        ),
      ],
    ),
    Field(
      id: '2',
      name: 'Lower Valley Section B',
      region: 'Dickoya Division',
      areaHectares: 1.8,
      latitude: 6.8823,
      longitude: 80.6112,
      elevationMeters: 1100,
      assignedWorkerIds: ['w3'],
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
          analyzedImages: const [],
        ),
      ],
    ),
    Field(
      id: '3',
      name: 'Summit East Terrace',
      region: 'Bogawantalawa Division',
      areaHectares: 3.1,
      latitude: 6.8142,
      longitude: 80.6655,
      elevationMeters: 1450,
      assignedWorkerIds: ['w5'],
      createdAt: DateTime.now().subtract(const Duration(days: 18, hours: 5)),
      measurements: [
        FieldMeasurement(
          id: 'm-1003',
          date: DateTime.now().subtract(const Duration(days: 4, hours: 2)),
          fieldArea: 3.1,
          predictedYieldKg: 205.4,
          actualYieldKg: 198.2,
          weather: WeatherSnapshot(
            date: DateTime.now().subtract(const Duration(days: 4, hours: 2)),
            summary: 'Bright intervals',
            rainChance: 28,
            humidity: 73,
            temperatureC: 23.1,
            stormRisk: false,
          ),
          laborPlan: LaborPlan(
            availableWorkers: 9,
            recommendedWorkers: 9,
            shiftStart: '06:15 AM',
            smsScheduled: true,
            focusZones: ['Upper terrace', 'East bend'],
          ),
          analyzedImages: const [],
        ),
      ],
    ),
    Field(
      id: '4',
      name: 'Riverbank South Plot',
      region: 'Maskeliya Division',
      areaHectares: 2.0,
      latitude: 6.8401,
      longitude: 80.5432,
      elevationMeters: 1180,
      assignedWorkerIds: ['w7'],
      createdAt: DateTime.now().subtract(const Duration(days: 7, hours: 1)),
      measurements: [
        FieldMeasurement(
          id: 'm-1004',
          date: DateTime.now().subtract(const Duration(days: 2, hours: 7)),
          fieldArea: 2.0,
          predictedYieldKg: 142.6,
          weather: WeatherSnapshot(
            date: DateTime.now().subtract(const Duration(days: 2, hours: 7)),
            summary: 'Humid morning',
            rainChance: 41,
            humidity: 82,
            temperatureC: 21.8,
            stormRisk: false,
          ),
          laborPlan: LaborPlan(
            availableWorkers: 6,
            recommendedWorkers: 8,
            shiftStart: '06:40 AM',
            smsScheduled: false,
            focusZones: ['South edge', 'Drain line'],
          ),
          analyzedImages: const [],
        ),
      ],
    ),
    Field(
      id: '5',
      name: 'Cedar Upper Lane',
      region: 'Nanu Oya Division',
      areaHectares: 1.6,
      latitude: 6.9501,
      longitude: 80.5788,
      elevationMeters: 1320,
      assignedWorkerIds: ['w9'],
      createdAt: DateTime.now().subtract(const Duration(days: 21, hours: 3)),
      measurements: [
        FieldMeasurement(
          id: 'm-1005',
          date: DateTime.now().subtract(const Duration(days: 6, hours: 9)),
          fieldArea: 1.6,
          predictedYieldKg: 118.3,
          actualYieldKg: 121.9,
          weather: WeatherSnapshot(
            date: DateTime.now().subtract(const Duration(days: 6, hours: 9)),
            summary: 'Cool breeze',
            rainChance: 22,
            humidity: 69,
            temperatureC: 20.9,
            stormRisk: false,
          ),
          laborPlan: LaborPlan(
            availableWorkers: 4,
            recommendedWorkers: 5,
            shiftStart: '07:00 AM',
            smsScheduled: true,
            focusZones: ['Upper lane', 'Rock border'],
          ),
          analyzedImages: const [],
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
    // Unassign workers from deleted field
    for (final worker in _workers) {
      if (worker.assignedFieldId == fieldId) {
        worker.assignedFieldId = null;
        worker.status = WorkerStatus.available;
      }
    }
    _fields.removeWhere((field) => field.id == fieldId);
    notifyListeners();
  }

  Future<FieldMeasurement> createDraftMeasurement(String fieldId) async {
    final field = _findField(fieldId);
    final serverRound = await _api.createDraftRound(fieldId);
    if (serverRound != null) {
      field.measurements.add(serverRound);
      notifyListeners();
      return serverRound;
    }
    final tempId = DateTime.now().microsecondsSinceEpoch.toString();
    final measurement = FieldMeasurement(
      id: tempId,
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
    _api.saveActualYield(measurementId, actualYieldKg);
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

  // ── Notifications ─────────────────────────────────────────
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

      // Labour assignment notifications
      final assignedCount = workersForField(field.id).length;
      final recommended = measurement.laborPlan?.recommendedWorkers ?? 0;
      if (recommended > 0 && assignedCount < recommended) {
        items.add(
          AppNotificationItem(
            id: '${field.id}-assign',
            fieldName: field.name,
            title: 'Workers needed',
            message:
                '$assignedCount of $recommended workers assigned. Assign ${recommended - assignedCount} more workers for optimal coverage.',
            category: 'Labor',
            createdAt: DateTime.now().subtract(const Duration(hours: 4)),
            severity: AlertSeverity.warning,
          ),
        );
      }

      // Schedule reminders
      if (measurement.isReadyToPluck && assignedCount > 0) {
        items.add(
          AppNotificationItem(
            id: '${field.id}-schedule',
            fieldName: field.name,
            title: 'Plucking round scheduled',
            message:
                '$assignedCount workers assigned for tomorrow\'s round starting at ${measurement.laborPlan?.shiftStart ?? '06:00 AM'}.',
            category: 'Schedule',
            createdAt: DateTime.now().subtract(const Duration(hours: 6)),
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

  int get fieldsReadyToPluck =>
      _fields.where((f) => f.latestMeasurement?.isReadyToPluck == true).length;

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
}
