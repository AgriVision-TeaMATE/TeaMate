import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/network_config.dart';
import '../models/disease_insights.dart';
import 'auth_service.dart';

/// Exception thrown when the disease-insights API call fails.
class DiseaseInsightsException implements Exception {
  final String message;
  DiseaseInsightsException(this.message);

  @override
  String toString() => message;
}

/// Service for fetching estate-level and field-level disease insights.
///
/// Endpoints (host from [NetworkConfig], port 8001, `/api/v1` prefix):
///   GET /api/v1/disease/estate-insights
///   GET /api/v1/disease/field-insights/{field_id}
///
/// Authentication mirrors [DiseaseScanService]: the logged-in user token from
/// [AuthService] is preferred, with a fallback bearer token used only when the
/// user is not currently authenticated.
class DiseaseInsightsService {
  static String get _host => 'http://${NetworkConfig.host}:8001';
  static String get _baseUrl => '$_host/api/v1/disease';

  // Fallback token, used only if the user isn't currently logged in
  // (AuthService().token is preferred and used whenever available).
  static const String _authToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhMGFiMDAwYS1kOGJkLTRhODktODA3YS03YmZlMjVkZDRhMTMiLCJlbWFpbCI6ImFAYS5hIiwiZXhwIjoxNzg3MzM5OTIxfQ.p-X_efCJmVZxBpDR4ThQnJwWKWhK1FsQ7h6t690dvWQ';

  static Map<String, String> _authHeaders() {
    final token = AuthService().token;
    final resolved = (token != null && token.isNotEmpty) ? token : _authToken;
    return {'Authorization': 'Bearer $resolved'};
  }

  /// Builds a [Uri] with an optional `days` query parameter.
  static Uri _buildUri(String uriString, {int? days}) {
    if (days == null) return Uri.parse(uriString);
    final separator = uriString.contains('?') ? '&' : '?';
    return Uri.parse('${uriString}${separator}days=$days');
  }

  /// Fetches estate-wide disease insights.
  ///
  /// [days] optionally limits the returned trend/risk data to the last *days*
  /// days.  The server applies this as a `?days=N` query parameter; if the
  /// server does not support it the full dataset is returned and client-side
  /// filtering applies as a fallback.
  ///
  /// Throws [DiseaseInsightsException] on failure.
  static Future<EstateInsights> fetchEstateInsights({int? days}) async {
    try {
      final uri = _buildUri('$_baseUrl/estate-insights', days: days);
      final response = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        debugPrint('[DiseaseInsights Service] Estate raw API response: '
            '${response.body.length} bytes, keys='
            '${data is Map ? data.keys.toList() : "n/a"}');
        if (data is Map<String, dynamic>) {
          final model = EstateInsights.fromJson(data);
          debugPrint('[DiseaseInsights Service] Estate parsed model: '
              'kpiCards=${model.kpiCards.length}, '
              'riskMap=${model.riskMap.length}, '
              'diseaseTrend=${model.diseaseTrend.length}, '
              'fieldPriority=${model.fieldPriority.length}, '
              'diseaseComposition=${model.diseaseComposition.length}, '
              'actionQueue=${model.actionQueue.length}');
          return model;
        }
        // Some backends may wrap the payload.
        if (data is Map) {
          final model = EstateInsights.fromJson(Map<String, dynamic>.from(data));
          debugPrint('[DiseaseInsights Service] Estate parsed model (wrapped): '
              'kpiCards=${model.kpiCards.length}, '
              'riskMap=${model.riskMap.length}, '
              'diseaseTrend=${model.diseaseTrend.length}, '
              'fieldPriority=${model.fieldPriority.length}, '
              'diseaseComposition=${model.diseaseComposition.length}, '
              'actionQueue=${model.actionQueue.length}');
          return model;
        }
        throw DiseaseInsightsException(
          'Unexpected response shape from estate-insights endpoint.',
        );
      }

      throw DiseaseInsightsException(
        _parseErrorMessage(response.body, response.statusCode),
      );
    } on DiseaseInsightsException {
      rethrow;
    } catch (e) {
      throw DiseaseInsightsException(_parseExceptionMessage(e));
    }
  }

  /// Fetches field-specific disease insights for [fieldId].
  ///
  /// [days] optionally limits the returned trend data to the last *days*
  /// days via a `?days=N` query parameter.
  ///
  /// Throws [DiseaseInsightsException] on failure.
  static Future<FieldInsights> fetchFieldInsights(
    String fieldId, {
    int? days,
  }) async {
    if (fieldId.isEmpty) {
      throw DiseaseInsightsException('A field id is required.');
    }
    try {
      final uri = _buildUri('$_baseUrl/field-insights/$fieldId', days: days);
      final response = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        debugPrint('[DiseaseInsights Service] Field raw API response: '
            'fieldId=$fieldId, body=${response.body.substring(0, math.min(response.body.length, 500))}...');
        debugPrint('[DiseaseInsights Service] Field raw API response keys: '
            '${data is Map ? (data as Map).keys.toList() : "n/a"}');
        if (data is Map<String, dynamic>) {
          final model = FieldInsights.fromJson(data);
          debugPrint('[DiseaseInsights Service] Field parsed model: '
              'fieldName=${model.fieldName}, '
              'totalScans=${model.totalScans}, '
              'pressureScore=${model.diseasePressureScore}, '
              'pressureStatus=${model.diseasePressureStatus}, '
              'timelineEntries=${model.fieldHealthTimeline.length}, '
              'confidenceSlices=${model.confidenceDistribution.length}, '
              'diseaseTrend=${model.diseaseTrend.length}, '
              'weatherAvailable=${model.weatherVsDisease != null}, '
              'treatmentAvailable=${model.treatmentResponseTrend.available}');
          return model;
        }
        if (data is Map) {
          final model = FieldInsights.fromJson(Map<String, dynamic>.from(data));
          debugPrint('[DiseaseInsights Service] Field parsed model (wrapped): '
              'fieldName=${model.fieldName}, '
              'totalScans=${model.totalScans}, '
              'timelineEntries=${model.fieldHealthTimeline.length}, '
              'diseaseTrend=${model.diseaseTrend.length}, '
              'weatherAvailable=${model.weatherVsDisease != null}, '
              'treatmentAvailable=${model.treatmentResponseTrend.available}');
          return model;
        }
        throw DiseaseInsightsException(
          'Unexpected response shape from field-insights endpoint.',
        );
      }

      throw DiseaseInsightsException(
        _parseErrorMessage(response.body, response.statusCode),
      );
    } on DiseaseInsightsException {
      rethrow;
    } catch (e) {
      throw DiseaseInsightsException(_parseExceptionMessage(e));
    }
  }

  // ── Error helpers (modeled on DiseaseScanService) ───────────────────────

  static String _parseErrorMessage(String responseBody, int statusCode) {
    try {
      final data = json.decode(responseBody) as Map<String, dynamic>;
      if (data['detail'] != null) return data['detail'] as String;
      if (data['message'] != null) return data['message'] as String;
      if (data['error'] != null) return data['error'] as String;
    } catch (_) {}

    switch (statusCode) {
      case 400:
        return 'Invalid request: the insights payload could not be generated.';
      case 401:
        return 'Authentication failed: Please log in again.';
      case 403:
        return "Access denied: you don't have permission to view these insights.";
      case 404:
        return 'No insights available for this field or endpoint was not found.';
      case 429:
        return 'Too many requests: Please wait before retrying.';
      case 500:
        return 'Server error: the insights service is experiencing issues.';
      case 502:
      case 503:
      case 504:
        return 'Service unavailable: the disease analysis service is temporarily offline.';
      default:
        return 'Unable to load disease insights at this time.';
    }
  }

  static String _parseExceptionMessage(Object e) {
    final message = e.toString().toLowerCase();
    if (message.contains('socket')) {
      return 'Cannot connect to server: Please check your internet connection.';
    }
    if (message.contains('timeout')) {
      return 'Request timed out: the server took too long to respond.';
    }
    if (message.contains('connection refused')) {
      return 'Cannot connect to server: the insights service may not be running.';
    }
    if (message.contains('network')) {
      return 'Network error: Please check your internet connection.';
    }
    return 'Could not load disease insights. Please try again later.';
  }
}
