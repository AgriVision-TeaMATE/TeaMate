import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../config/network_config.dart';
import '../models/environmental_data.dart';

/// Service for fetching environmental data using GPS and weather APIs
class EnvironmentalDataService {
  /// Local API endpoint for weekly weather summary
  static String get _weeklyWeatherUrl => '${NetworkConfig.apiBaseUrl()}/weather/weekly-summary';

  /// Maximum acceptable age of a cached position (10 seconds).
  /// Positions older than this are treated as stale and rejected.
  static const Duration _maxPositionAge = Duration(seconds: 10);

  /// Timeout for the GPS fetch operation.
  static const Duration _gpsTimeout = Duration(seconds: 15);

  /// Fetches the current GPS location from the device's location provider.
  ///
  /// Throws [LocationServiceDisabledException] if GPS/location services are off.
  /// Throws [PermissionDeniedException] if location permission is denied or
  /// permanently denied.
  /// Throws [LocationFetchException] if the position is invalid (0,0), stale,
  /// or the fetch times out.
  ///
  /// Never falls back to dummy or cached coordinates.
  static Future<LocationResult> getCurrentLocation() async {
    // Step 1: Check whether device location service (GPS) is enabled.
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceDisabledException();
    }

    // Step 2: Check and request location permissions.
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw PermissionDeniedException(
          'Location permission was denied. Please grant location permission to use this feature.',
        );
      }
    }

    // Handle permanently denied — both from the initial check and after
    // requesting (the user may have checked "Don't ask again").
    if (permission == LocationPermission.deniedForever) {
      throw PermissionDeniedException(
        'Location permission is disabled. Please enable it from app settings.',
      );
    }

    // Step 3: Fetch fresh location data with high accuracy.
    // AndroidSettings extends LocationSettings and provides Android-specific
    // configuration. The 10m distance filter ensures we only receive fresh,
    // meaningful position updates rather than cached/stale values.
    late final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          timeLimit: _gpsTimeout,
        ),
      );
    } on LocationServiceDisabledException {
      // The service may have been disabled between our check and the call.
      throw LocationServiceDisabledException();
    } on TimeoutException {
      throw LocationFetchException(
        'Location fetch timed out after ${_gpsTimeout.inSeconds}s. '
        'Please ensure GPS has a clear signal and try again.',
      );
    }

    // Step 4: Validate the returned coordinates.
    // Reject (0,0) — the "null island" coordinate that some providers return
    // when they cannot determine a real position.
    if (position.latitude == 0.0 && position.longitude == 0.0) {
      throw LocationFetchException(
        'Received invalid coordinates (0, 0). The location provider could not determine your position.',
      );
    }

    // Reject positions with poor accuracy.
    if (position.accuracy > 100) {
      throw LocationFetchException(
        'Location accuracy is too low (${position.accuracy.toStringAsFixed(1)}m). '
        'Please move to an open area with better GPS reception.',
      );
    }

    // Step 5: Validate the timestamp — ensure the position is recent.
    // Geolocator 13.x Position.timestamp is non-nullable DateTime.
    final positionTime = position.timestamp;
    final age = DateTime.now().difference(positionTime);
    if (age > _maxPositionAge) {
      throw LocationFetchException(
        'Location data is stale (${age.inSeconds}s old). '
        'Please ensure GPS is receiving a fresh signal.',
      );
    }

    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: positionTime,
      accuracy: position.accuracy,
    );
  }

  /// Fetches environmental data using GPS coordinates.
  /// Requires valid latitude and longitude — no dummy fallback.
  static Future<EnvironmentalData> fetchEnvironmentalData({
    required double latitude,
    required double longitude,
  }) async {
    // Validate coordinates are not (0,0) or null
    if (latitude == 0.0 && longitude == 0.0) {
      throw LocationFetchException(
        'Invalid coordinates (0, 0). A real GPS position is required.',
      );
    }

    final lat = latitude;
    final lon = longitude;

    // Fetch weekly weather summary
    final weather = await _fetchWeeklyWeather(lat, lon);

    final now = DateTime.now();

    return EnvironmentalData(
      date: now,
      time: now,
      latitude: lat,
      longitude: lon,
      avgTemperatureLast7: weather.avgTemperatureLast7,
      avgHumidityLast7: weather.avgHumidityLast7,
      avgWindSpeedLast7: weather.avgWindSpeedLast7,
      avgSunshineHoursLast7: weather.avgSunshineHoursLast7,
      totalRainfallLast7: weather.totalRainfallLast7,
    );
  }

  static Future<_WeeklyWeatherData> _fetchWeeklyWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(_weeklyWeatherUrl);

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'latitude': lat,
          'longitude': lon,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseWeeklyWeatherResponse(data);
      }
    } catch (_) {
      // Fall through to mock data
    }

    return _defaultWeeklyWeather();
  }

  static _WeeklyWeatherData _parseWeeklyWeatherResponse(Map<String, dynamic> data) {
    return _WeeklyWeatherData(
      avgTemperatureLast7: (data['avg_temperature_last_7'] as num?)?.toDouble() ?? 28.0,
      avgHumidityLast7: (data['avg_humidity_last_7'] as num?)?.toInt() ?? 76,
      avgWindSpeedLast7: (data['avg_wind_speed_last_7'] as num?)?.toDouble() ?? 11.0,
      avgSunshineHoursLast7: (data['avg_sunshine_hours_last_7'] as num?)?.toDouble() ?? 11.5,
      totalRainfallLast7: (data['total_rainfall_last_7'] as num?)?.toDouble() ?? 22.0,
    );
  }

  static _WeeklyWeatherData _defaultWeeklyWeather() {
    return _WeeklyWeatherData(
      avgTemperatureLast7: 28.3,
      avgHumidityLast7: 76,
      avgWindSpeedLast7: 11.4,
      avgSunshineHoursLast7: 11.5,
      totalRainfallLast7: 22.3,
    );
  }
}

/// Location result from GPS
class LocationResult {
  final double latitude;
  final double longitude;
  final DateTime? timestamp;
  final double? accuracy;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.timestamp,
    this.accuracy,
  });
}

/// Exception thrown when the location fetch fails due to invalid or stale data.
class LocationFetchException implements Exception {
  final String message;
  LocationFetchException(this.message);

  @override
  String toString() => message;
}

class _WeeklyWeatherData {
  final double avgTemperatureLast7;
  final int avgHumidityLast7;
  final double avgWindSpeedLast7;
  final double avgSunshineHoursLast7;
  final double totalRainfallLast7;

  _WeeklyWeatherData({
    required this.avgTemperatureLast7,
    required this.avgHumidityLast7,
    required this.avgWindSpeedLast7,
    required this.avgSunshineHoursLast7,
    required this.totalRainfallLast7,
  });
}