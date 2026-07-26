import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../models/environmental_data.dart';

/// Service for fetching environmental data using GPS and weather APIs
class EnvironmentalDataService {
  /// Local API endpoint for weekly weather summary
  static const String _weeklyWeatherUrl = 'http://localhost:8001/api/v1/weather/weekly-summary';

  /// Dummy GPS coordinates for testing (Hatton, Sri Lanka - tea plantation region)
  static const double _defaultLat = 6.8985;
  static const double _defaultLon = 80.5853;

  /// Fetches current GPS location from device
  /// Returns dummy location if location services are unavailable
  static Future<LocationResult> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceDisabledException();
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw PermissionDeniedException('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw PermissionDeniedException('Location permissions are permanently denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Fall back to dummy location if GPS fails
      await Future.delayed(const Duration(milliseconds: 500));
      return LocationResult(
        latitude: _defaultLat,
        longitude: _defaultLon,
      );
    }
  }

  /// Fetches environmental data using GPS coordinates
  static Future<EnvironmentalData> fetchEnvironmentalData({
    double? latitude,
    double? longitude,
  }) async {
    final lat = latitude ?? _defaultLat;
    final lon = longitude ?? _defaultLon;

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

  const LocationResult({
    required this.latitude,
    required this.longitude,
  });
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