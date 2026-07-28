/// Environmental data model for disease prediction
class EnvironmentalData {
  final DateTime date;
  final DateTime time;
  final double latitude;
  final double longitude;
  final double avgTemperatureLast7;
  final int avgHumidityLast7;
  final double avgWindSpeedLast7;
  final double avgSunshineHoursLast7;
  final double totalRainfallLast7;

  const EnvironmentalData({
    required this.date,
    required this.time,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.avgTemperatureLast7 = 24.0,
    this.avgHumidityLast7 = 75,
    this.avgWindSpeedLast7 = 10.0,
    this.avgSunshineHoursLast7 = 8.0,
    this.totalRainfallLast7 = 0.0,
  });

  EnvironmentalData copyWith({
    DateTime? date,
    DateTime? time,
    double? latitude,
    double? longitude,
    double? avgTemperatureLast7,
    int? avgHumidityLast7,
    double? avgWindSpeedLast7,
    double? avgSunshineHoursLast7,
    double? totalRainfallLast7,
  }) {
    return EnvironmentalData(
      date: date ?? this.date,
      time: time ?? this.time,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      avgTemperatureLast7: avgTemperatureLast7 ?? this.avgTemperatureLast7,
      avgHumidityLast7: avgHumidityLast7 ?? this.avgHumidityLast7,
      avgWindSpeedLast7: avgWindSpeedLast7 ?? this.avgWindSpeedLast7,
      avgSunshineHoursLast7: avgSunshineHoursLast7 ?? this.avgSunshineHoursLast7,
      totalRainfallLast7: totalRainfallLast7 ?? this.totalRainfallLast7,
    );
  }
}