import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/field_model.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../widgets/weather_widgets.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherForecast? _forecast;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final forecast = await WeatherService.fetchForecast();
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
        _isLoading = false;
      });
      FieldManager().updateForecast(forecast);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load weather data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Weather Forecast',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadWeather,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          size: 56, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadWeather,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWeather,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCurrentConditions(),
                        const SizedBox(height: 18),
                        if (_forecast != null)
                          PluckingWindowCard(forecast: _forecast!),
                        const SizedBox(height: 22),
                        _buildRainAlert(),
                        const SizedBox(height: 22),
                        _buildHourlyForecast(),
                        const SizedBox(height: 22),
                        _buildDailyForecast(),
                        const SizedBox(height: 22),
                        _buildFieldImpact(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildCurrentConditions() {
    final f = _forecast!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF173730), Color(0xFF0E221D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173730).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hatton, Sri Lanka',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${f.currentTemp.toStringAsFixed(0)}°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -3,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    f.currentDescription,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                WeatherService.weatherCodeToIcon(f.currentWeatherCode),
                style: const TextStyle(fontSize: 56),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ConditionStat(
                  label: 'Feels Like',
                  value: '${f.feelsLike.toStringAsFixed(0)}°C',
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                _ConditionStat(
                  label: 'Humidity',
                  value: '${f.currentHumidity}%',
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                _ConditionStat(
                  label: 'Wind',
                  value: '${f.currentWindSpeed.toStringAsFixed(0)} km/h',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRainAlert() {
    final f = _forecast!;
    if (!f.hasStormRisk) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFB97922).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFB97922).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFB97922), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Rain Alert',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7A4D0C),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Heavy rain expected in the next 6 hours. Recommended actions:',
            style: TextStyle(
              color: Color(0xFF7A4D0C),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _buildAlertAction(Icons.schedule_outlined, 'Move plucking to early morning window'),
          const SizedBox(height: 6),
          _buildAlertAction(Icons.shield_outlined, 'Protect collected leaves from moisture'),
          const SizedBox(height: 6),
          _buildAlertAction(Icons.water_outlined, 'Check drainage in low-lying fields'),
        ],
      ),
    );
  }

  Widget _buildAlertAction(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFB97922)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7A4D0C),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyForecast() {
    final f = _forecast!;
    final now = DateTime.now();
    final upcoming =
        f.hourly.where((h) => h.time.isAfter(now)).take(24).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '24-Hour Forecast',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: upcoming.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final hour = upcoming[index];
              final isNow = index == 0;
              return Container(
                width: 72,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: isNow
                      ? const Color(0xFF173730)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: isNow
                      ? null
                      : Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isNow ? 'Now' : DateFormat('HH:mm').format(hour.time),
                      style: TextStyle(
                        color: isNow ? Colors.white70 : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      WeatherService.weatherCodeToIcon(hour.weatherCode),
                      style: const TextStyle(fontSize: 22),
                    ),
                    Text(
                      '${hour.temperatureC.toStringAsFixed(0)}°',
                      style: TextStyle(
                        color: isNow ? Colors.white : AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.water_drop,
                          size: 10,
                          color: isNow
                              ? Colors.white54
                              : const Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${hour.rainChance}%',
                          style: TextStyle(
                            color: isNow
                                ? Colors.white54
                                : const Color(0xFF3B82F6),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDailyForecast() {
    final f = _forecast!;
    if (f.daily.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '7-Day Forecast',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < f.daily.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                _DailyRow(day: f.daily[i], isToday: i == 0),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldImpact() {
    final fields = FieldManager().fields;
    if (fields.isEmpty || _forecast == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Field Impact',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'How current weather affects each field\'s plucking schedule.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 14),
        ...fields.map((field) {
          final measurement = field.latestMeasurement;
          final isReady = measurement?.isReadyToPluck == true;
          final hasRisk = _forecast!.hasStormRisk;
          
          String impact;
          Color impactColor;
          IconData impactIcon;
          
          if (isReady && !hasRisk) {
            impact = 'Good conditions — proceed with scheduled plucking.';
            impactColor = const Color(0xFF2E7655);
            impactIcon = Icons.check_circle_outline_rounded;
          } else if (isReady && hasRisk) {
            impact = 'Move plucking earlier — rain risk may affect leaf quality.';
            impactColor = const Color(0xFFB97922);
            impactIcon = Icons.warning_amber_rounded;
          } else if (!isReady && hasRisk) {
            impact = 'Rain may slow maturity. Reassess in 2 days.';
            impactColor = const Color(0xFFD95C5C);
            impactIcon = Icons.cancel_outlined;
          } else {
            impact = 'Not ready — monitor growth. Current conditions are neutral.';
            impactColor = AppTheme.textSecondary;
            impactIcon = Icons.info_outline_rounded;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Icon(impactIcon, color: impactColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        impact,
                        style: TextStyle(
                          color: impactColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ConditionStat extends StatelessWidget {
  final String label;
  final String value;

  const _ConditionStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DailyRow extends StatelessWidget {
  final WeatherDaily day;
  final bool isToday;

  const _DailyRow({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              isToday ? 'Today' : DateFormat('EEE').format(day.date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            WeatherService.weatherCodeToIcon(day.weatherCode),
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RainChanceBar(percentage: day.rainChance),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              Icon(Icons.water_drop, size: 12, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 3),
              Text(
                '${day.rainChance}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 60,
            child: Text(
              '${day.tempMax.toStringAsFixed(0)}° / ${day.tempMin.toStringAsFixed(0)}°',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
