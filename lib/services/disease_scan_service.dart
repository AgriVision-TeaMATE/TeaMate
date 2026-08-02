import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/network_config.dart';
import '../models/disease_scan_record.dart';
import '../models/environmental_data.dart';
import 'auth_service.dart';

/// Exception thrown when disease scan API fails
class DiseaseScanException implements Exception {
  final String message;
  DiseaseScanException(this.message);

  @override
  String toString() => message;
}

/// A single image to be submitted for disease scanning.
class ScanImage {
  final Uint8List bytes;
  final String name;
  const ScanImage({required this.bytes, required this.name});
}

/// Service for disease scanning API calls
class DiseaseScanService {
  static String get _host => 'http://${NetworkConfig.host}:8001';
  static String get _baseUrl => '$_host/api/v1/disease/scan';
  static String get _diseaseBaseUrl => '$_host/api/v1/disease';

  // Fallback token, used only if the user isn't currently logged in
  // (AuthService().token is preferred and used whenever available).
  static const String _authToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhMGFiMDAwYS1kOGJkLTRhODktODA3YS03YmZlMjVkZDRhMTMiLCJlbWFpbCI6ImFAYS5hIiwiZXhwIjoxNzg3MzM5OTIxfQ.p-X_efCJmVZxBpDR4ThQnJwWKWhK1FsQ7h6t690dvWQ';

  static Map<String, String> _authHeaders() {
    final token = AuthService().token;
    final resolved = (token != null && token.isNotEmpty) ? token : _authToken;
    return {'Authorization': 'Bearer $resolved'};
  }

  /// Builds an absolute URL for an `image_url` returned by the API
  /// (e.g. "/media/disease-scans/xyz.jpg" -> "http://localhost:8001/media/...").
  static String? resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/')) {
      return '$_host$path';
    }
    return '$_host/$path';
  }

  /// Fetches all disease scan records for a given field, most recent first.
  /// Throws DiseaseScanException on failure.
  static Future<List<DiseaseScanRecord>> fetchScansByField(
    String fieldId,
  ) async {
    try {
      final uri = Uri.parse('$_diseaseBaseUrl/by-field/$fieldId');
      final response = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body) as List;
        final records = data
            .map(
              (e) => DiseaseScanRecord.fromJson(e as Map<String, dynamic>),
            )
            .toList();
        records.sort((a, b) => b.scanDatetime.compareTo(a.scanDatetime));
        return records;
      }

      throw DiseaseScanException(
        _parseErrorMessage(response.body, response.statusCode),
      );
    } on DiseaseScanException {
      rethrow;
    } catch (e) {
      throw DiseaseScanException(_parseExceptionMessage(e));
    }
  }

  /// Fetches a single disease scan record's full detail by its scan_id.
  /// Throws DiseaseScanException on failure.
  static Future<DiseaseScanRecord> fetchScanById(String scanId) async {
    try {
      final uri = Uri.parse('$_diseaseBaseUrl/by-scan-id/$scanId');
      final response = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return DiseaseScanRecord.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw DiseaseScanException(
        _parseErrorMessage(response.body, response.statusCode),
      );
    } on DiseaseScanException {
      rethrow;
    } catch (e) {
      throw DiseaseScanException(_parseExceptionMessage(e));
    }
  }

  /// Performs disease scan with one or more images and environmental data.
  ///
  /// The new API accepts multiple images under the `images` key (repeated
  /// multipart fields), along with individual weather form fields and a
  /// `weather_summary` JSON blob.
  ///
  /// Throws [DiseaseScanException] on failure.
  static Future<Map<String, dynamic>> scanDisease({
    required List<ScanImage> images,
    required EnvironmentalData environmentalData,
    String? fieldId,
  }) async {
    if (images.isEmpty) {
      throw DiseaseScanException('At least one image is required for scanning.');
    }

    try {
      final uri = Uri.parse(_baseUrl);

      // Build weather summary JSON — only the 5 fields the new API expects.
      final weatherSummary = {
        'total_rainfall_last_7': environmentalData.totalRainfallLast7,
        'avg_temperature_last_7': environmentalData.avgTemperatureLast7,
        'avg_humidity_last_7': environmentalData.avgHumidityLast7,
        'avg_wind_speed_last_7': environmentalData.avgWindSpeedLast7,
        'avg_sunshine_hours_last_7': environmentalData.avgSunshineHoursLast7,
      };

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_authHeaders());

      // Add each image under the `images` key (repeated multipart field).
      for (final image in images) {
        final mimeType = _getImageMimeType(image.name);
        final contentType = MediaType('image', mimeType);
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            image.bytes,
            filename: image.name,
            contentType: contentType,
          ),
        );
      }

      // Individual weather form fields (new API format).
      request.fields['total_rainfall_last_7'] =
          environmentalData.totalRainfallLast7.toString();
      request.fields['avg_temperature_last_7'] =
          environmentalData.avgTemperatureLast7.toString();
      request.fields['avg_humidity_last_7'] =
          environmentalData.avgHumidityLast7.toString();
      request.fields['avg_wind_speed_last_7'] =
          environmentalData.avgWindSpeedLast7.toString();
      request.fields['avg_sunshine_hours_last_7'] =
          environmentalData.avgSunshineHoursLast7.toString();

      // weather_summary as JSON blob (redundant but some backend versions need it).
      request.fields['weather_summary'] = json.encode(weatherSummary);

      // GPS coordinates.
      if (environmentalData.latitude != 0.0) {
        request.fields['latitude'] = environmentalData.latitude.toString();
      }
      if (environmentalData.longitude != 0.0) {
        request.fields['longitude'] = environmentalData.longitude.toString();
      }

      // Associate this scan with a specific field.
      if (fieldId != null && fieldId.isNotEmpty) {
        request.fields['field_id'] = fieldId;
      }

      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(responseBody) as Map<String, dynamic>;
        // Some validation errors (e.g. "Uploaded image is not a leaf image")
        // arrive with a 200 status and a `detail` object instead of an error
        // status code. Treat them as failures.
        if (decoded['detail'] != null) {
          throw DiseaseScanException(
            _parseErrorMessage(responseBody, response.statusCode),
          );
        }
        return decoded;
      } else {
        final errorMessage =
            _parseErrorMessage(responseBody, response.statusCode);
        throw DiseaseScanException(errorMessage);
      }
    } on DiseaseScanException {
      rethrow;
    } catch (e) {
      throw DiseaseScanException(_parseExceptionMessage(e));
    }
  }

  /// Parse human-readable error message from response body and status code
  static String _parseErrorMessage(String responseBody, int statusCode) {
    // Try to parse error message from API response
    try {
      final data = json.decode(responseBody) as Map<String, dynamic>;
      if (data['detail'] != null) {
        final detail = data['detail'];
        if (detail is String) {
          return detail;
        }
        if (detail is Map) {
          final detailMap = detail as Map<String, dynamic>;
          return detailMap['message']?.toString() ??
              detailMap['error']?.toString() ??
              detailMap['detail']?.toString() ??
              'An error occurred during analysis';
        }
      }
      if (data['message'] != null) {
        return data['message'] as String;
      }
      if (data['error'] != null) {
        return data['error'] as String;
      }
    } catch (_) {
      // Response body not JSON, use status code messages
    }

    // Return human-readable status code messages
    switch (statusCode) {
      case 400:
        return 'Invalid request: Please check the image format';
      case 401:
        return 'Authentication failed: Please log in again';
      case 403:
        return 'Access denied: You don\'t have permission to perform this scan';
      case 404:
        return 'Service unavailable: The disease analysis endpoint was not found';
      case 413:
        return 'Image too large: Please choose a smaller image file';
      case 415:
        return 'Unsupported image type: Please use JPG, PNG, or WebP format';
      case 422:
        return 'Image validation failed: The image could not be processed';
      case 429:
        return 'Too many requests: Please wait before scanning again';
      case 500:
        return 'Server error: The analysis service is experiencing issues';
      case 502:
      case 503:
      case 504:
        return 'Service unavailable: The disease analysis service is temporarily offline';
      default:
        return 'Unable to connect to disease analysis service';
    }
  }

  /// Parse human-readable message from exception
  static String _parseExceptionMessage(Object e) {
    final message = e.toString().toLowerCase();

    if (message.contains('socket')) {
      return 'Cannot connect to server: Please check your internet connection';
    }
    if (message.contains('timeout')) {
      return 'Request timed out: The server took too long to respond';
    }
    if (message.contains('connection refused')) {
      return 'Cannot connect to server: The disease analysis service may not be running';
    }
    if (message.contains('network')) {
      return 'Network error: Please check your internet connection';
    }

    return 'Disease analysis failed: Could not reach ML backend at http://localhost:8001/api/v1/disease/scan';
  }

  /// Extracts MIME type from file extension
  static String _getImageMimeType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      default:
        return 'jpeg'; // Default to jpeg for unknown types
    }
  }
}