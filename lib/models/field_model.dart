import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

enum AlertSeverity { info, warning, critical }

enum WorkerStatus { available, assigned, onLeave }

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
    final closest = hourly.reduce(
      (a, b) =>
          (a.time.difference(now).abs() < b.time.difference(now).abs()) ? a : b,
    );
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
      final goodTemp = window.every(
        (h) => h.temperatureC > 18 && h.temperatureC < 30,
      );
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
  String? assignedFieldId;
  final DateTime createdAt;

  Worker({
    required this.id,
    required this.name,
    required this.phone,
    this.status = WorkerStatus.available,
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
}

class PluckingSchedule {
  final String id;
  final String fieldId;
  final String? harvestRoundId;
  final DateTime scheduledDate;
  final String shiftStart;
  final String shiftEnd;
  final int recommendedWorkers;
  final String? notes;
  final List<String> assignedWorkerIds;
  ScheduleStatus status;

  PluckingSchedule({
    required this.id,
    required this.fieldId,
    this.harvestRoundId,
    required this.scheduledDate,
    required this.shiftStart,
    required this.shiftEnd,
    this.recommendedWorkers = 0,
    this.notes,
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

class RoundPlanResult {
  final String roundId;
  final String fieldId;
  final String pluckingStatus;
  final double? predictedYieldKg;
  final LaborPlan laborPlan;
  final WeatherSnapshot? weather;
  final String? weatherAction;
  final bool canSchedule;
  final DateTime scheduledDate;
  final String shiftEnd;

  const RoundPlanResult({
    required this.roundId,
    required this.fieldId,
    required this.pluckingStatus,
    required this.predictedYieldKg,
    required this.laborPlan,
    required this.weather,
    this.weatherAction,
    required this.canSchedule,
    required this.scheduledDate,
    required this.shiftEnd,
  });
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
  final String? fieldId;
  final String fieldName;
  final String title;
  final String message;
  final String category;
  final DateTime createdAt;
  final AlertSeverity severity;
  final bool isUnread;

  const AppNotificationItem({
    required this.id,
    this.fieldId,
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
  // 4 corner points (image-space pixels) of the AR-measured sampling quadrilateral, for
  // traceability/audit. Null for images whose area was entered manually (Upload Image flow).
  final List<Offset>? capturedAreaCorners;

  const AnalysisImageResult({
    required this.id,
    required this.imagePath,
    required this.sourceLabel,
    required this.capturedAt,
    required this.arimbuCount,
    required this.pluckableCount,
    required this.capturedArea,
    required this.budMarkers,
    this.capturedAreaCorners,
  });

  int get totalBuds => arimbuCount + pluckableCount;

  double get pluckableRatio => totalBuds == 0 ? 0 : pluckableCount / totalBuds;
}

class FieldMeasurement {
  final String id;
  final DateTime date;
  final List<AnalysisImageResult> analyzedImages;
  final String pluckingStatus;
  final bool isCompleted;
  final double? fieldArea;
  final double? predictedYieldKg;
  final double? actualYieldKg;
  final WeatherSnapshot? weather;
  final LaborPlan? laborPlan;

  const FieldMeasurement({
    required this.id,
    required this.date,
    required this.analyzedImages,
    this.pluckingStatus = 'awaiting_analysis',
    this.isCompleted = false,
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
    String? pluckingStatus,
    bool? isCompleted,
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
      pluckingStatus: pluckingStatus ?? this.pluckingStatus,
      isCompleted: isCompleted ?? this.isCompleted,
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

  bool get isEmptyDraft =>
      analyzedImages.isEmpty &&
      predictedYieldKg == null &&
      actualYieldKg == null &&
      !isCompleted;

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
    if (isCompleted) {
      return 'Round completed';
    }
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
    if (isCompleted) {
      return 'Completed';
    }
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

  String get statusLabel {
    if (isCompleted || pluckingStatus == 'completed') {
      return 'Completed';
    }

    switch (pluckingStatus) {
      case 'ready_to_pluck':
        return 'Ready to pluck';
      case 'overgrown':
        return 'Review maturity';
      case 'maturing':
        return 'Maturing';
      case 'needs_growth':
        return 'Needs more growth';
      case 'analyzing':
        return 'Analyzing';
      case 'awaiting_analysis':
        return analyzedImages.isEmpty
            ? 'Awaiting analysis'
            : 'Awaiting analysis';
      default:
        return readinessLabel;
    }
  }
}

class Field {
  final String id;
  final String userId;
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
    required this.userId,
    required this.name,
    required this.region,
    required this.areaHectares,
    this.latitude = 6.9271,
    this.longitude = 80.6005,
    this.elevationMeters = 1200,
    DateTime? createdAt,
    List<FieldMeasurement>? measurements,
    List<String>? assignedWorkerIds,
  }) : _createdAt = createdAt,
       measurements = measurements ?? [],
       assignedWorkerIds = assignedWorkerIds ?? [];

  DateTime get createdAt => _createdAt ?? DateTime.now();

  double get areaSquareMeters => areaHectares * 10000;

  String get areaDisplay {
    final sqm = areaSquareMeters;
    final hasFraction = (sqm - sqm.roundToDouble()).abs() > 0.01;
    return hasFraction
        ? '${sqm.toStringAsFixed(1)} sq.m'
        : '${sqm.toStringAsFixed(0)} sq.m';
  }

  FieldMeasurement? get latestMeasurement {
    if (measurements.isEmpty) {
      return null;
    }
    return measurements.reduce(
      (latest, current) => current.date.isAfter(latest.date) ? current : latest,
    );
  }

  String get subtitle {
    final trimmedRegion = region.trim();
    if (trimmedRegion.isEmpty) {
      return areaDisplay;
    }
    return '$trimmedRegion • $areaDisplay';
  }
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
      for (final field in fields) {
        final rounds = await _api.fetchFieldRounds(field.id);
        final emptyDrafts = rounds.where((round) => round.isEmptyDraft);
        for (final draft in emptyDrafts) {
          _api.deleteRound(draft.id);
        }
        field.measurements = rounds
            .where((round) => !round.isEmptyDraft)
            .toList();
      }
      final workers = await _api.fetchWorkers();
      final schedules = await _api.fetchSchedules();
      final notifications = await _api.fetchNotifications();
      _fields
        ..clear()
        ..addAll(fields);
      _workers
        ..clear()
        ..addAll(workers);
      _schedules
        ..clear()
        ..addAll(schedules);
      _notifications
        ..clear()
        ..addAll(_hydrateNotifications(notifications));
      notifyListeners();
    } catch (_) {}
  }

  // ── Workers ───────────────────────────────────────────────
  final List<Worker> _workers = [];

  List<Worker> get workers => _workers;

  List<Worker> get availableWorkers =>
      _workers.where((w) => w.status == WorkerStatus.available).toList();

  List<Worker> get assignedWorkers =>
      _workers.where((w) => w.status == WorkerStatus.assigned).toList();

  List<Worker> get onLeaveWorkers =>
      _workers.where((w) => w.status == WorkerStatus.onLeave).toList();

  List<Worker> workersForField(String fieldId) =>
      _workers.where((w) => w.assignedFieldId == fieldId).toList();

  void addWorker({required String name, required String phone}) {
    final tempId = 'w${DateTime.now().millisecondsSinceEpoch}';
    _workers.add(
      Worker(
        id: tempId,
        name: name,
        phone: phone,
        status: WorkerStatus.available,
      ),
    );
    notifyListeners();
    _api.addWorker(name: name, phone: phone).then((w) {
      if (w != null) syncFromServer();
    });
  }

  void updateWorker(String workerId, {String? name, String? phone}) {
    final worker = _workers.firstWhere((w) => w.id == workerId);
    if (name != null) worker.name = name;
    if (phone != null) worker.phone = phone;
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
  final List<Field> _fields = [];
  final List<AppNotificationItem> _notifications = [];

  List<Field> get fields => _fields;

  Future<bool> addField({
    required String name,
    required double areaHectares,
  }) async {
    final created = await _api.addField(name: name, areaHectares: areaHectares);
    if (created == null) {
      return false;
    }
    _fields.add(created);
    notifyListeners();
    return true;
  }

  Future<void> deleteField(String fieldId) async {
    // Unassign workers from deleted field
    for (final worker in _workers) {
      if (worker.assignedFieldId == fieldId) {
        worker.assignedFieldId = null;
        worker.status = WorkerStatus.available;
      }
    }
    _fields.removeWhere((field) => field.id == fieldId);
    notifyListeners();
    await _api.deleteField(fieldId);
  }

  Future<FieldMeasurement> createDraftMeasurement(
    String fieldId, {
    bool notify = true,
  }) async {
    final field = _findField(fieldId);
    final tempId = 'draft-${DateTime.now().microsecondsSinceEpoch}';
    final measurement = FieldMeasurement(
      id: tempId,
      date: DateTime.now(),
      analyzedImages: const [],
      fieldArea: field.areaHectares,
      weather: _buildWeatherForField(field),
    );
    field.measurements.add(measurement);
    if (notify) {
      notifyListeners();
    }
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
    _api.deleteRound(measurementId);
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
    return measurement.copyWith(
      weather: measurement.weather ?? _weatherFromForecast(_cachedForecast),
      laborPlan: measurement.laborPlan,
    );
  }

  // ── Notifications ─────────────────────────────────────────
  List<AppNotificationItem> get notifications => _notifications;

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

  List<AppNotificationItem> _hydrateNotifications(
    List<AppNotificationItem> notifications,
  ) {
    final fieldNames = {for (final field in _fields) field.id: field.name};
    final hydrated = notifications
        .map(
          (item) => AppNotificationItem(
            id: item.id,
            fieldId: item.fieldId,
            fieldName: item.fieldName.isNotEmpty
                ? item.fieldName
                : fieldNames[item.fieldId] ?? 'System',
            title: item.title,
            message: item.message,
            category: item.category,
            createdAt: item.createdAt,
            severity: item.severity,
            isUnread: item.isUnread,
          ),
        )
        .toList();
    hydrated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return hydrated;
  }

  static WeatherSnapshot? _weatherFromForecast(WeatherForecast? forecast) {
    if (forecast == null) {
      return null;
    }
    return WeatherSnapshot(
      date: forecast.fetchedAt,
      summary: forecast.currentDescription,
      rainChance: forecast.currentRainChance,
      humidity: forecast.currentHumidity,
      temperatureC: forecast.currentTemp,
      stormRisk: forecast.hasStormRisk,
    );
  }
}
