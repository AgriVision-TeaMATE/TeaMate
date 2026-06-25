import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/field_model.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  // Default coordinates for Hatton, Sri Lanka (tea plantation region)
  static const double _defaultLat = 6.8985;
  static const double _defaultLon = 80.5853;

  static DateTime? _lastFetch;
  static WeatherForecast? _cache;
  static const Duration _cacheDuration = Duration(minutes: 30);

  static Future<WeatherForecast> fetchForecast({
    double? latitude,
    double? longitude,
  }) async {
    final lat = latitude ?? _defaultLat;
    final lon = longitude ?? _defaultLon;

    // Return cache if fresh
    if (_cache != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _cache!;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?latitude=$lat&longitude=$lon'
        '&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,wind_speed_10m,weather_code'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,apparent_temperature'
        '&timezone=Asia/Colombo'
        '&forecast_days=7',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final forecast = _parseResponse(data);
        _cache = forecast;
        _lastFetch = DateTime.now();
        return forecast;
      }
    } catch (_) {
      // Fall through to mock data
    }

    return _buildMockForecast();
  }

  static WeatherForecast _parseResponse(Map<String, dynamic> data) {
    final current = data['current'] as Map<String, dynamic>;
    final hourlyData = data['hourly'] as Map<String, dynamic>;
    final dailyData = data['daily'] as Map<String, dynamic>;

    // Parse hourly
    final hourlyTimes = (hourlyData['time'] as List).cast<String>();
    final hourlyTemps =
        (hourlyData['temperature_2m'] as List).map((e) => (e as num).toDouble()).toList();
    final hourlyHumidity =
        (hourlyData['relative_humidity_2m'] as List).map((e) => (e as num).toInt()).toList();
    final hourlyRain =
        (hourlyData['precipitation_probability'] as List).map((e) => (e as num).toInt()).toList();
    final hourlyWind =
        (hourlyData['wind_speed_10m'] as List).map((e) => (e as num).toDouble()).toList();
    final hourlyCodes =
        (hourlyData['weather_code'] as List).map((e) => (e as num).toInt()).toList();

    final hourly = <WeatherHourly>[];
    for (int i = 0; i < hourlyTimes.length && i < 48; i++) {
      hourly.add(WeatherHourly(
        time: DateTime.parse(hourlyTimes[i]),
        temperatureC: hourlyTemps[i],
        rainChance: hourlyRain[i],
        humidity: hourlyHumidity[i],
        windSpeedKmh: hourlyWind[i],
        weatherCode: hourlyCodes[i],
        description: weatherCodeToDescription(hourlyCodes[i]),
      ));
    }

    // Parse daily
    final dailyTimes = (dailyData['time'] as List).cast<String>();
    final dailyMax =
        (dailyData['temperature_2m_max'] as List).map((e) => (e as num).toDouble()).toList();
    final dailyMin =
        (dailyData['temperature_2m_min'] as List).map((e) => (e as num).toDouble()).toList();
    final dailyRain =
        (dailyData['precipitation_probability_max'] as List).map((e) => (e as num).toInt()).toList();
    final dailyCodes =
        (dailyData['weather_code'] as List).map((e) => (e as num).toInt()).toList();
    final dailyPrecip =
        (dailyData['precipitation_sum'] as List).map((e) => (e as num).toDouble()).toList();

    final daily = <WeatherDaily>[];
    for (int i = 0; i < dailyTimes.length; i++) {
      daily.add(WeatherDaily(
        date: DateTime.parse(dailyTimes[i]),
        tempMax: dailyMax[i],
        tempMin: dailyMin[i],
        rainChance: dailyRain[i],
        weatherCode: dailyCodes[i],
        description: weatherCodeToDescription(dailyCodes[i]),
        precipitationMm: dailyPrecip[i],
      ));
    }

    return WeatherForecast(
      fetchedAt: DateTime.now(),
      currentTemp: (current['temperature_2m'] as num).toDouble(),
      currentHumidity: (current['relative_humidity_2m'] as num).toInt(),
      currentWindSpeed: (current['wind_speed_10m'] as num).toDouble(),
      currentWeatherCode: (current['weather_code'] as num).toInt(),
      currentDescription:
          weatherCodeToDescription((current['weather_code'] as num).toInt()),
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      hourly: hourly,
      daily: daily,
    );
  }

  static WeatherForecast _buildMockForecast() {
    final now = DateTime.now();
    final hourly = List.generate(48, (i) {
      final time = now.add(Duration(hours: i));
      final isRainy = i > 8 && i < 14;
      return WeatherHourly(
        time: time,
        temperatureC: 20.0 + (i % 6) * 0.5,
        rainChance: isRainy ? 65 + (i % 3) * 10 : 15 + (i % 4) * 5,
        humidity: 75 + (i % 4) * 3,
        windSpeedKmh: 8.0 + (i % 5) * 2.0,
        weatherCode: isRainy ? 61 : (i % 3 == 0 ? 2 : 1),
        description: isRainy ? 'Light rain' : 'Partly cloudy',
      );
    });

    final daily = List.generate(7, (i) {
      final date = DateTime(now.year, now.month, now.day + i);
      return WeatherDaily(
        date: date,
        tempMax: 24.0 + (i % 3),
        tempMin: 18.0 + (i % 2),
        rainChance: 20 + (i * 8) % 60,
        weatherCode: i % 3 == 0 ? 61 : (i % 2 == 0 ? 2 : 1),
        description: i % 3 == 0 ? 'Light rain' : 'Partly cloudy',
        precipitationMm: i % 3 == 0 ? 4.2 : 0.5,
      );
    });

    return WeatherForecast(
      fetchedAt: now,
      currentTemp: 22.0,
      currentHumidity: 78,
      currentWindSpeed: 12.5,
      currentWeatherCode: 2,
      currentDescription: 'Partly cloudy',
      feelsLike: 21.3,
      hourly: hourly,
      daily: daily,
    );
  }

  static String weatherCodeToDescription(int code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing drizzle';
      case 61:
        return 'Light rain';
      case 63:
        return 'Moderate rain';
      case 65:
        return 'Heavy rain';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
      case 73:
      case 75:
        return 'Snowfall';
      case 77:
        return 'Snow grains';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with hail';
      default:
        return 'Unknown';
    }
  }

  static String weatherCodeToIcon(int code) {
    if (code == 0) return '☀️';
    if (code <= 2) return '⛅';
    if (code == 3) return '☁️';
    if (code <= 48) return '🌫️';
    if (code <= 57) return '🌦️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌧️';
    if (code <= 86) return '🌨️';
    return '⛈️';
  }
}
