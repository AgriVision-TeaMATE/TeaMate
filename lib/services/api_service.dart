import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/field_model.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8001/api/v1';
    if (Platform.isAndroid) return 'http://10.0.2.2:8001/api/v1';
    return 'http://localhost:8001/api/v1';
  }

  static String get modelBaseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  static const Duration _timeout = Duration(seconds: 12);

  Future<List<Field>> fetchFields() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/fields'))
          .timeout(_timeout);
      if (response.statusCode != 200) return [];
      final List data = jsonDecode(response.body);
      return data.map((json) => _parseField(json)).toList();
    } catch (e) {
      debugPrint('ApiService fetchFields error: $e');
      return [];
    }
  }

  Future<List<Worker>> fetchWorkers() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/workers'))
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
          .get(Uri.parse('$baseUrl/schedules'))
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
          .get(Uri.parse('$baseUrl/notifications'))
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
    SkillLevel skillLevel = SkillLevel.experienced,
  }) async {
    try {
      final skillStr = switch (skillLevel) {
        SkillLevel.junior => 'junior',
        SkillLevel.experienced => 'experienced',
        SkillLevel.senior => 'senior',
      };
      final response = await http
          .post(
            Uri.parse('$baseUrl/workers'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'skill_level': skillStr,
            }),
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
            headers: {'Content-Type': 'application/json'},
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
          .delete(Uri.parse('$baseUrl/workers/$workerId'))
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
            headers: {'Content-Type': 'application/json'},
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
          .post(Uri.parse('$baseUrl/workers/$workerId/unassign'))
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
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'round_date': DateTime.now().toIso8601String(),
            }),
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
    required String sourceLabel,
  }) async {
    try {
      String imageUrlPayload = imagePathOrUrl;
      if (!imagePathOrUrl.startsWith('http') && !imagePathOrUrl.startsWith('data:')) {
        try {
          final file = File(imagePathOrUrl);
          final bytes = await file.readAsBytes();
          imageUrlPayload = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          debugPrint('Successfully encoded local image file to base64 (${bytes.length} bytes)');
        } catch (err) {
          debugPrint('Error reading file $imagePathOrUrl for base64 upload: $err');
        }
      }
      final pathPayload = imagePathOrUrl.length > 450 ? 'local_upload.jpg' : imagePathOrUrl;
      final response = await http
          .post(
            Uri.parse('$baseUrl/rounds/$roundId/images'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firebase_url': imageUrlPayload,
              'firebase_path': pathPayload,
              'source_label': sourceLabel,
              'captured_at': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 201 && response.statusCode != 200) return null;
      return _parseImageResult(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService uploadImageToRound error: $e');
      return null;
    }
  }

  Future<FieldMeasurement?> analyzeRound(String roundId) async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/rounds/$roundId/analyze'))
          .timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) return null;
      return _parseRound(jsonDecode(response.body));
    } catch (e) {
      debugPrint('ApiService analyzeRound error: $e');
      return null;
    }
  }

  Future<AnalysisImageResult?> analyzeImageDirectly({
    required String imagePath,
    required String sourceLabel,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$modelBaseUrl/predict'));
      if (imagePath.startsWith('http') || imagePath.startsWith('data:')) {
        return null;
      }
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'image.jpg',
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      if (streamedResponse.statusCode != 200) {
        debugPrint('Direct model response error: ${streamedResponse.statusCode}');
        return null;
      }

      final response = await http.Response.fromStream(streamedResponse);
      final json = jsonDecode(response.body);

      final arimbuCount = (json['arimbu_count'] as num?)?.toInt() ?? 0;
      final pluckableCount = (json['pluckable_count'] as num?)?.toInt() ?? 0;
      final base64Img = json['image'] as String? ?? '';

      return AnalysisImageResult(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imagePath: base64Img.isNotEmpty ? 'data:image/jpeg;base64,$base64Img' : imagePath,
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
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'actual_yield_kg': yieldKg}),
          )
          .timeout(_timeout);
      await http
          .put(Uri.parse('$baseUrl/rounds/$roundId/complete'))
          .timeout(_timeout);
    } catch (e) {
      debugPrint('ApiService saveActualYield error: $e');
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
      name: json['name'] ?? 'Tea Field',
      region: json['region'] ?? 'Estate',
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

    final skillStr = json['skill_level']?.toString() ?? 'experienced';
    final skill = switch (skillStr) {
      'junior' => SkillLevel.junior,
      'senior' => SkillLevel.senior,
      _ => SkillLevel.experienced,
    };

    return Worker(
      id: json['id'].toString(),
      name: json['name'] ?? 'Worker',
      phone: json['phone'] ?? '',
      status: status,
      skillLevel: skill,
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
      date: DateTime.tryParse(json['round_date'] ?? '') ?? DateTime.now(),
      analyzedImages: images,
      fieldArea: (json['field_area_hectares'] as num?)?.toDouble(),
      predictedYieldKg: (json['predicted_yield_kg'] as num?)?.toDouble(),
      actualYieldKg: (json['actual_yield_kg'] as num?)?.toDouble(),
    );
  }

  AnalysisImageResult _parseImageResult(Map<String, dynamic> json) {
    final markersJson = json['bud_markers'] as List? ?? [];
    final markers = markersJson.map((m) {
      final map = m as Map<String, dynamic>;
      return Offset(
        (map['x_position'] as num?)?.toDouble() ?? 0.5,
        (map['y_position'] as num?)?.toDouble() ?? 0.5,
      );
    }).toList();

    return AnalysisImageResult(
      id: json['id'].toString(),
      imagePath: json['firebase_url'] ?? '',
      sourceLabel: json['source_label'] ?? 'Upload',
      capturedAt: DateTime.tryParse(json['captured_at'] ?? '') ?? DateTime.now(),
      arimbuCount: (json['arimbu_count'] as num?)?.toInt() ?? 0,
      pluckableCount: (json['pluckable_count'] as num?)?.toInt() ?? 0,
      capturedArea: (json['captured_area_sqm'] as num?)?.toDouble() ?? 8.0,
      budMarkers: markers,
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
      scheduledDate: DateTime.tryParse(json['scheduled_date'] ?? '') ?? DateTime.now(),
      shiftStart: json['shift_start'] ?? '06:00 AM',
      shiftEnd: json['shift_end'] ?? '02:00 PM',
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
      fieldName: json['field_id']?.toString() ?? 'System',
      title: json['title'] ?? 'Notice',
      message: json['message'] ?? '',
      category: json['category'] ?? 'System',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      severity: sev,
      isUnread: !(json['is_read'] as bool? ?? false),
    );
  }
}
