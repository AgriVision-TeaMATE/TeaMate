import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/environmental_data.dart';

/// Exception thrown when disease scan API fails
class DiseaseScanException implements Exception {
  final String message;
  DiseaseScanException(this.message);

  @override
  String toString() => message;
}

/// Service for disease scanning API calls
class DiseaseScanService {
  static const String _baseUrl = 'http://localhost:8001/api/v1/disease/scan';
  static const String _authToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhMGFiMDAwYS1kOGJkLTRhODktODA3YS03YmZlMjVkZDRhMTMiLCJlbWFpbCI6ImFAYS5hIiwiZXhwIjoxNzg3MzM5OTIxfQ.p-X_efCJmVZxBpDR4ThQnJwWKWhK1FsQ7h6t690dvWQ';

  /// Performs disease scan with image and environmental data
  /// Throws DiseaseScanException on failure
  static Future<Map<String, dynamic>> scanDisease({
    required Uint8List imageBytes,
    required String fileName,
    required EnvironmentalData environmentalData,
    String? fieldId,
  }) async {
    try {
      final uri = Uri.parse(_baseUrl);

      // Build weather summary JSON from environmental data
      final weatherSummary = {
        'rainy_days_last_7': environmentalData.totalRainfallLast7 > 10 ? 5 : 2,
        'rainy_hours_last_7': 42,
        'total_rainfall_last_7': environmentalData.totalRainfallLast7,
        'avg_temperature_last_7': environmentalData.avgTemperatureLast7,
        'avg_humidity_last_7': environmentalData.avgHumidityLast7,
        'max_humidity_last_7': environmentalData.avgHumidityLast7 + 10,
        'avg_wind_speed_last_7': environmentalData.avgWindSpeedLast7,
        'max_wind_speed_last_7': environmentalData.avgWindSpeedLast7 + 5,
        'avg_sunshine_hours_last_7': environmentalData.avgSunshineHoursLast7,
        'estimated_leaf_wetness_hours_last_7':
            (environmentalData.avgHumidityLast7 > 80) ? 65 : 20,
      };

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $_authToken';

      // Determine content type from file extension
      final mimeType = _getImageMimeType(fileName);
      final contentType = MediaType('image', mimeType);

      // Add image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: fileName,
          contentType: contentType,
        ),
      );

      // Add weather summary as form field
      request.fields['weather_summary'] = json.encode(weatherSummary);

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody) as Map<String, dynamic>;
      } else {
        final errorMessage = _parseErrorMessage(responseBody, response.statusCode);
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
        return data['detail'] as String;
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

    return 'Disease analysis failed: Could not reach ML backend at http://localhost:8000/predict: All connection attempts failed';
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