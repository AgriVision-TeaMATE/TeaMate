import 'package:flutter/material.dart';
import '../models/field_model.dart';
import '../services/weather_service.dart';
import '../theme.dart';

/// Compact weather banner for dashboard
class WeatherBannerCard extends StatelessWidget {
  final WeatherForecast? forecast;
  final VoidCallback? onTap;

  const WeatherBannerCard({super.key, this.forecast, this.onTap});

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    if (f == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A3C34), Color(0xFF0E221D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
            SizedBox(width: 14),
            Text(
              'Loading weather...',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final hasRisk = f.hasStormRisk;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: hasRisk
                ? [const Color(0xFF3D2014), const Color(0xFF1E1108)]
                : [const Color(0xFF1A3C34), const Color(0xFF0E221D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (hasRisk ? const Color(0xFF3D2014) : const Color(0xFF1A3C34))
                  .withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  WeatherService.weatherCodeToIcon(f.currentWeatherCode),
                  style: const TextStyle(fontSize: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${f.currentTemp.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          const Spacer(),
                          if (hasRisk)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Color(0xFFFF9F43), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Storm Risk',
                                    style: TextStyle(
                                      color: Color(0xFFFF9F43),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        f.currentDescription,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _WeatherMiniStat(
                  icon: Icons.water_drop_outlined,
                  label: '${f.currentRainChance}%',
                  sublabel: 'Rain',
                ),
                const SizedBox(width: 20),
                _WeatherMiniStat(
                  icon: Icons.air_outlined,
                  label: '${f.currentWindSpeed.toStringAsFixed(0)} km/h',
                  sublabel: 'Wind',
                ),
                const SizedBox(width: 20),
                _WeatherMiniStat(
                  icon: Icons.thermostat_outlined,
                  label: '${f.feelsLike.toStringAsFixed(0)}°',
                  sublabel: 'Feels like',
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherMiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _WeatherMiniStat({
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              sublabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rain probability bar
class RainChanceBar extends StatelessWidget {
  final int percentage;
  final double height;

  const RainChanceBar({super.key, required this.percentage, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final color = percentage > 70
        ? const Color(0xFFD95C5C)
        : percentage > 40
            ? const Color(0xFFB97922)
            : const Color(0xFF2E7655);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percentage / 100,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// Plucking window recommendation card
class PluckingWindowCard extends StatelessWidget {
  final WeatherForecast forecast;

  const PluckingWindowCard({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final recommendation = forecast.pluckingWindowRecommendation;
    final hasRisk = forecast.hasStormRisk;

    final Color bgColor;
    final Color accentColor;
    final IconData icon;
    final String title;
    final String subtitle;

    if (hasRisk) {
      bgColor = const Color(0xFFFFF2E8);
      accentColor = const Color(0xFFB97922);
      icon = Icons.warning_amber_rounded;
      title = recommendation ?? 'No clear window found';
      subtitle = 'Storm risk detected — pluck in the early morning or reschedule.';
    } else if (recommendation != null) {
      bgColor = const Color(0xFFEEF6F0);
      accentColor = const Color(0xFF2E7655);
      icon = Icons.check_circle_outline_rounded;
      title = recommendation;
      subtitle = 'Optimal conditions: low rain chance, mild temperature.';
    } else {
      bgColor = const Color(0xFFF5F7F6);
      accentColor = AppTheme.textSecondary;
      icon = Icons.schedule_outlined;
      title = 'Checking forecast...';
      subtitle = 'Weather data is being analyzed for plucking windows.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BEST PLUCKING WINDOW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
