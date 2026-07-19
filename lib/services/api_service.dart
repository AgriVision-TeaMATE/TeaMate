import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/network_config.dart';
import '../models/field_model.dart';
import 'auth_service.dart';

class ApiService {
  static String get baseUrl => NetworkConfig.apiBaseUrl();

  static String get modelBaseUrl => NetworkConfig.modelBaseUrl();

  static const Duration _timeout = Duration(seconds: 12);

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    final token = AuthService().token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  Future<List<Field>> fetchFields() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/fields'), headers: _headers())
          .timeout(_timeout);
      if (response.statusCode != 200) return [];
      final List data = jsonDecode(response.body);
      return data.map((json) => _parseField(json)).toList();
    } catch (e) {
      debugPrint('ApiService fetchFields error: $e');
      return [];
    }
  }

  Future<Field?> addField({
    required String name,
    required double areaHectares,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/fields'),
            headers: _headers(json: true),
            body: jsonEncode({'name': name, 'area_hectares': areaHectares}),
          )
          .timeout(_timeout);
      if (response.statusCode != 201 && response.statusCode != 200) return null;
      return _parseField(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService addField error: $e');
      return null;
    }
  }

  Future<List<FieldMeasurement>> fetchFieldRounds(String fieldId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/fields/$fieldId/rounds'),
            headers: _headers(),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return [];
      final List data = jsonDecode(response.body);
      return data
          .map((json) => _parseRound(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ApiService fetchFieldRounds error: $e');
      return [];
    }
  }

  Future<void> deleteField(String fieldId) async {
    try {
      await http
          .delete(Uri.parse('$baseUrl/fields/$fieldId'), headers: _headers())
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService deleteField error: $e');
    }
  }

  Future<void> deleteRound(String roundId) async {
    try {
      await http
          .delete(Uri.parse('$baseUrl/rounds/$roundId'), headers: _headers())
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService deleteRound error: $e');
    }
  }

  Future<List<Worker>> fetchWorkers() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/workers'), headers: _headers())
          .timeout(_timeout);
      if (response.statusCode != 200) return [];
      final List data = jsonDecode(response.body);
      return data.map((json) => _parseWorker(json)).toList();
    } catch (e) {
      debugPrint('ApiService fetchWorkers error: $e');
      return [];
    }
  }

  Future<List<PluckingSchedule>> fetchSchedules() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/schedules'), headers: _headers())
          .timeout(_timeout);
      if (response.statusCode != 200) return [];
      final List data = jsonDecode(response.body);
      return data.map((json) => _parseSchedule(json)).toList();
    } catch (e) {
      debugPrint('ApiService fetchSchedules error: $e');
      return [];
    }
  }

  Future<List<AppNotificationItem>> fetchNotifications() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/notifications'), headers: _headers())
          .timeout(_timeout);
      if (response.statusCode != 200) return [];
      final List data = jsonDecode(response.body);
      return data.map((json) => _parseNotification(json)).toList();
    } catch (e) {
      debugPrint('ApiService fetchNotifications error: $e');
      return [];
    }
  }

  Future<Worker?> addWorker({
    required String name,
    required String phone,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/workers'),
            headers: _headers(json: true),
            body: jsonEncode({'name': name, 'phone': phone}),
          )
          .timeout(_timeout);
      if (response.statusCode != 201 && response.statusCode != 200) return null;
      return _parseWorker(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService addWorker error: $e');
      return null;
    }
  }

  Future<void> updateWorkerStatus(String workerId, WorkerStatus status) async {
    try {
      final statusStr = switch (status) {
        WorkerStatus.available => 'available',
        WorkerStatus.assigned => 'assigned',
        WorkerStatus.onLeave => 'on_leave',
      };
      await http
          .put(
            Uri.parse('$baseUrl/workers/$workerId/status'),
            headers: _headers(json: true),
            body: jsonEncode({'status': statusStr}),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService updateWorkerStatus error: $e');
    }
  }

  Future<void> deleteWorker(String workerId) async {
    try {
      await http
          .delete(Uri.parse('$baseUrl/workers/$workerId'), headers: _headers())
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService deleteWorker error: $e');
    }
  }

  Future<void> assignWorkerToField(String workerId, String fieldId) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/workers/$workerId/assign'),
            headers: _headers(json: true),
            body: jsonEncode({'field_id': fieldId}),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService assignWorkerToField error: $e');
    }
  }

  Future<void> unassignWorker(String workerId) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/workers/$workerId/unassign'),
            headers: _headers(),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService unassignWorker error: $e');
    }
  }

  Future<FieldMeasurement?> createDraftRound(String fieldId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/fields/$fieldId/rounds'),
            headers: _headers(json: true),
            body: jsonEncode({}),
          )
          .timeout(_timeout);
      if (response.statusCode != 201 && response.statusCode != 200) return null;
      return _parseRound(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService createDraftRound error: $e');
      return null;
    }
  }

  Future<AnalysisImageResult?> uploadImageToRound({
    required String roundId,
    required String imagePathOrUrl,
    required double capturedArea,
  }) async {
    try {
      if (imagePathOrUrl.startsWith('http') ||
          imagePathOrUrl.startsWith('data:')) {
        return null;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/rounds/$roundId/images'),
      );
      request.headers.addAll(_headers());
      request.fields['captured_area_sqm'] = capturedArea.toString();

      final file = File(imagePathOrUrl);
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: imagePathOrUrl.split(Platform.pathSeparator).last,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      if (streamedResponse.statusCode != 201 &&
          streamedResponse.statusCode != 200) {
        return null;
      }
      final response = await http.Response.fromStream(streamedResponse);
      return _parseImageResult(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService uploadImageToRound error: $e');
      return null;
    }
  }

  Future<FieldMeasurement?> analyzeRound(String roundId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/rounds/$roundId/analyze'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) return null;
      return _parseRound(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService analyzeRound error: $e');
      return null;
    }
  }

  Future<bool> deleteAnalysisImage(String imageId) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/images/$imageId'), headers: _headers())
          .timeout(_timeout);
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('ApiService deleteAnalysisImage error: $e');
      return false;
    }
  }

  Future<FieldMeasurement?> predictRoundYield(String roundId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/rounds/$roundId/predict-yield'),
            headers: _headers(),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      return _parseRound(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService predictRoundYield error: $e');
      return null;
    }
  }

  Future<RoundPlanResult?> planRound({
    required String roundId,
    required double kgPerWorkerPerDay,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/rounds/$roundId/plan'),
            headers: _headers(json: true),
            body: jsonEncode({'kg_per_worker_per_day': kgPerWorkerPerDay}),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      return _parseRoundPlan(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService planRound error: $e');
      return null;
    }
  }

  Future<AnalysisImageResult?> analyzeImageDirectly({
    required String imagePath,
    required String sourceLabel,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$modelBaseUrl/predict'),
      );
      if (imagePath.startsWith('http') || imagePath.startsWith('data:')) {
        return null;
      }
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'image.jpg'),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      if (streamedResponse.statusCode != 200) {
        debugPrint(
          'Direct model response error: ${streamedResponse.statusCode}',
        );
        return null;
      }

      final response = await http.Response.fromStream(streamedResponse);
      final json = jsonDecode(response.body);

      final arimbuCount = (json['arimbu_count'] as num?)?.toInt() ?? 0;
      final pluckableCount = (json['pluckable_count'] as num?)?.toInt() ?? 0;
      final base64Img = json['image'] as String? ?? '';

      return AnalysisImageResult(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imagePath: base64Img.isNotEmpty
            ? 'data:image/jpeg;base64,$base64Img'
            : imagePath,
        sourceLabel: sourceLabel,
        capturedAt: DateTime.now(),
        arimbuCount: arimbuCount,
        pluckableCount: pluckableCount,
        capturedArea: 8.0,
        budMarkers: const [],
      );
    } catch (e) {
      debugPrint('ApiService analyzeImageDirectly error: $e');
      return null;
    }
  }

  Future<void> saveActualYield(String roundId, double yieldKg) async {
    try {
      await http
          .put(
            Uri.parse('$baseUrl/rounds/$roundId'),
            headers: _headers(json: true),
            body: jsonEncode({'actual_yield': yieldKg}),
          )
          .timeout(_timeout);
      await http
          .put(
            Uri.parse('$baseUrl/rounds/$roundId/complete'),
            headers: _headers(),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService saveActualYield error: $e');
    }
  }

  Future<void> updateActualYield(String roundId, double yieldKg) async {
    try {
      await http
          .put(
            Uri.parse('$baseUrl/rounds/$roundId'),
            headers: _headers(json: true),
            body: jsonEncode({'actual_yield': yieldKg}),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService updateActualYield error: $e');
    }
  }

  Future<PluckingSchedule?> createSchedule({
    required String fieldId,
    required String roundId,
    required DateTime scheduledDate,
    required String shiftStart,
    required String shiftEnd,
    required int recommendedWorkers,
    required List<String> assignedWorkerIds,
    String? notes,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/schedules'),
            headers: _headers(json: true),
            body: jsonEncode({
              'field_id': fieldId,
              'harvest_round_id': roundId,
              'scheduled_date': _dateOnly(scheduledDate),
              'shift_start': shiftStart,
              'shift_end': shiftEnd,
              'recommended_workers': recommendedWorkers,
              'notes': notes,
              'assigned_worker_ids': assignedWorkerIds,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode != 201 && response.statusCode != 200) return null;
      return _parseSchedule(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService createSchedule error: $e');
      return null;
    }
  }

  Future<bool> sendScheduleSms(String scheduleId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/schedules/$scheduleId/send-sms'),
            headers: _headers(),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService sendScheduleSms error: $e');
      return false;
    }
  }

  Future<PluckingSchedule?> updateScheduleWorkers({
    required String scheduleId,
    required List<String> assignedWorkerIds,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/schedules/$scheduleId/workers'),
            headers: _headers(json: true),
            body: jsonEncode(assignedWorkerIds),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      return _parseSchedule(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService updateScheduleWorkers error: $e');
      return null;
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await http
          .put(
            Uri.parse('$baseUrl/notifications/read-all'),
            headers: _headers(),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService markAllNotificationsRead error: $e');
    }
  }

  // ── JSON Parsers ──────────────────────────────────────────

  Field _parseField(Map<String, dynamic> json) {
    final roundsJson = json['latest_round'] as Map<String, dynamic>?;
    final measurements = <FieldMeasurement>[];
    if (roundsJson != null) {
      measurements.add(_parseRound(roundsJson));
    }

    return Field(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      name: json['name'] ?? 'Tea Field',
      region: json['region'] ?? '',
      areaHectares: (json['area_hectares'] as num?)?.toDouble() ?? 1.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 6.9271,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 80.6005,
      elevationMeters: (json['elevation_meters'] as num?)?.toDouble() ?? 1200,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      measurements: measurements,
    );
  }

  Worker _parseWorker(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString() ?? 'available';
    final status = switch (statusStr) {
      'assigned' => WorkerStatus.assigned,
      'on_leave' => WorkerStatus.onLeave,
      _ => WorkerStatus.available,
    };

    return Worker(
      id: json['id'].toString(),
      name: json['name'] ?? 'Worker',
      phone: json['phone'] ?? '',
      status: status,
      assignedFieldId: json['assigned_field_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  FieldMeasurement _parseRound(Map<String, dynamic> json) {
    final imagesJson = json['analysis_images'] as List? ?? [];
    final images = imagesJson
        .map((img) => _parseImageResult(img as Map<String, dynamic>))
        .toList();

    return FieldMeasurement(
      id: json['id'].toString(),
      date:
          DateTime.tryParse(json['created_at'] ?? json['round_date'] ?? '') ??
          DateTime.now(),
      analyzedImages: images,
      pluckingStatus:
          json['plucking_status']?.toString() ?? 'awaiting_analysis',
      isCompleted: json['is_completed'] as bool? ?? false,
      fieldArea: (json['field_area_hectares'] as num?)?.toDouble(),
      predictedYieldKg:
          (json['predicted_yield'] as num?)?.toDouble() ??
          (json['predicted_yield_kg'] as num?)?.toDouble(),
      actualYieldKg:
          (json['actual_yield'] as num?)?.toDouble() ??
          (json['actual_yield_kg'] as num?)?.toDouble(),
    );
  }

  AnalysisImageResult _parseImageResult(Map<String, dynamic> json) {
    return AnalysisImageResult(
      id: json['id'].toString(),
      imagePath: json['image_url'] ?? json['firebase_url'] ?? '',
      sourceLabel: 'Upload',
      capturedAt: DateTime.now(),
      arimbuCount: (json['arimbu_count'] as num?)?.toInt() ?? 0,
      pluckableCount: (json['pluckable_count'] as num?)?.toInt() ?? 0,
      capturedArea:
          (json['captured_area_sqm'] as num?)?.toDouble() ??
          (json['captured_area'] as num?)?.toDouble() ??
          0,
      budMarkers: const [],
    );
  }

  PluckingSchedule _parseSchedule(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString() ?? 'scheduled';
    final status = switch (statusStr) {
      'in_progress' => ScheduleStatus.inProgress,
      'completed' => ScheduleStatus.completed,
      'cancelled' => ScheduleStatus.cancelled,
      _ => ScheduleStatus.scheduled,
    };

    final workers = (json['assigned_worker_ids'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    return PluckingSchedule(
      id: json['id'].toString(),
      fieldId: json['field_id'].toString(),
      harvestRoundId: json['harvest_round_id']?.toString(),
      scheduledDate:
          DateTime.tryParse(json['scheduled_date'] ?? '') ?? DateTime.now(),
      shiftStart: json['shift_start'] ?? '06:00 AM',
      shiftEnd: json['shift_end'] ?? '02:00 PM',
      recommendedWorkers: (json['recommended_workers'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString(),
      assignedWorkerIds: workers,
      status: status,
    );
  }

  AppNotificationItem _parseNotification(Map<String, dynamic> json) {
    final sevStr = json['severity']?.toString() ?? 'info';
    final sev = switch (sevStr) {
      'warning' => AlertSeverity.warning,
      'critical' => AlertSeverity.critical,
      _ => AlertSeverity.info,
    };

    return AppNotificationItem(
      id: json['id'].toString(),
      fieldId: json['field_id']?.toString(),
      fieldName: '',
      title: json['title'] ?? 'Notice',
      message: json['message'] ?? '',
      category: json['category'] ?? 'System',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      severity: sev,
      isUnread: !(json['is_read'] as bool? ?? false),
    );
  }

  RoundPlanResult _parseRoundPlan(Map<String, dynamic> json) {
    final scheduledDate =
        DateTime.tryParse(json['scheduled_date'] ?? '') ?? DateTime.now();
    final weather = json['weather_summary'] == null
        ? null
        : WeatherSnapshot(
            date: scheduledDate,
            summary: json['weather_summary']?.toString() ?? '',
            rainChance: (json['rain_chance_pct'] as num?)?.toInt() ?? 0,
            humidity: (json['humidity_pct'] as num?)?.toInt() ?? 0,
            temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 0,
            stormRisk: json['storm_risk'] as bool? ?? false,
          );

    return RoundPlanResult(
      roundId: json['round_id'].toString(),
      fieldId: json['field_id'].toString(),
      pluckingStatus:
          json['plucking_status']?.toString() ?? 'awaiting_analysis',
      predictedYieldKg: (json['predicted_yield'] as num?)?.toDouble(),
      laborPlan: LaborPlan(
        availableWorkers: 0,
        recommendedWorkers: (json['recommended_workers'] as num?)?.toInt() ?? 0,
        shiftStart: json['shift_start']?.toString() ?? '06:00:00',
        smsScheduled: false,
        focusZones: const [],
      ),
      weather: weather,
      weatherAction: json['weather_action']?.toString(),
      canSchedule: json['can_schedule'] as bool? ?? false,
      scheduledDate: scheduledDate,
      shiftEnd: json['shift_end']?.toString() ?? '14:00:00',
    );
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;
}
