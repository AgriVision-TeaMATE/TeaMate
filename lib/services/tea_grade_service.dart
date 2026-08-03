import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/network_config.dart';
import '../models/tea_grade_model.dart';
import 'auth_service.dart';

/// API client for the tea quality grading module.
/// Falls back to mock data (flagged `isMock`) when the backend is unreachable,
/// so the UI can be exercised offline — same idea as WeatherService's mock.
class TeaGradeService {
  static final TeaGradeService _instance = TeaGradeService._internal();
  factory TeaGradeService() => _instance;
  TeaGradeService._internal();

  static String get origin => 'http://${NetworkConfig.host}:8001';

  static String get baseUrl => '$origin/api/v1/tea-quality';

  Map<String, String> _headers() {
    final token = AuthService().token;
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Content type for the upload; the backend rejects anything that is not
  /// jpeg/png/webp with 415, so never fall back to octet-stream.
  static MediaType _imageMediaType(XFile image) {
    final mime = image.mimeType;
    if (mime != null && mime.startsWith('image/')) {
      return MediaType.parse(mime);
    }
    final name = image.name.toLowerCase();
    if (name.endsWith('.png')) return MediaType('image', 'png');
    if (name.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  Future<TeaQualityScan?> submitScan(XFile image, {String? fieldId}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/scan'));
      request.headers.addAll(_headers());
      if (fieldId != null && fieldId.isNotEmpty) {
        request.fields['field_id'] = fieldId;
      }
      final bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.name.isNotEmpty ? image.name : 'sample.jpg',
          contentType: _imageMediaType(image),
        ),
      );

      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return TeaQualityScan.fromJson(jsonDecode(response.body));
      }
      debugPrint(
        'TeaGradeService submitScan failed: ${response.statusCode} ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('TeaGradeService submitScan error: $e');
      return _buildMockScan();
    }
  }

  Future<List<TeaQualityScan>> fetchScans() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/scans'), headers: _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((json) => TeaQualityScan.fromJson(json))
              .toList();
        }
      }
      debugPrint('TeaGradeService fetchScans failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('TeaGradeService fetchScans error: $e');
      return [
        _buildMockScan(minutesAgo: 40),
        _buildMockScan(minutesAgo: 60 * 26),
      ];
    }
  }

  Future<TeaQualityScan?> fetchScan(String scanId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/scan/$scanId'), headers: _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return TeaQualityScan.fromJson(jsonDecode(response.body));
      }
      debugPrint('TeaGradeService fetchScan failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('TeaGradeService fetchScan error: $e');
      return null;
    }
  }

  // ── Mock fallback ──

  static const List<String> _grades = [
    'OP',
    'OPA',
    'PEKOE',
    'BOP',
    'BOP1',
    'BOPF',
    'Dust No.1',
  ];

  TeaQualityScan _buildMockScan({int minutesAgo = 0}) {
    final random = Random();
    final weights =
        List.generate(_grades.length, (_) => random.nextDouble() + 0.15);
    final totalWeight = weights.reduce((a, b) => a + b);
    final composition = <GradeComposition>[];
    for (var i = 0; i < _grades.length; i++) {
      composition.add(
        GradeComposition(
          grade: _grades[i],
          percentage:
              double.parse((weights[i] / totalWeight * 100).toStringAsFixed(2)),
        ),
      );
    }
    composition.sort((a, b) => b.percentage.compareTo(a.percentage));

    final when = DateTime.now().subtract(Duration(minutes: minutesAgo));
    return TeaQualityScan(
      id: 'mock-${when.millisecondsSinceEpoch}',
      scanId: 'mock_${when.millisecondsSinceEpoch}',
      imageUrl: '',
      scanDatetime: when,
      gradeComposition: composition,
      dominantGrade: composition.first.grade,
      dominantGradePercentage: composition.first.percentage,
      modelVersion: 'offline-mock',
      isMock: true,
    );
  }
}
