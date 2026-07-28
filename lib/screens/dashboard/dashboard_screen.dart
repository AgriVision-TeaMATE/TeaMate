import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/field_model.dart';
import '../../services/auth_service.dart';
import '../../services/weather_service.dart';
import '../../theme.dart';
import '../fields/field_analysis_screen.dart';
import '../fields/fields_screen.dart';
import '../settings/profile_screen.dart';
import 'disease_detection_screen.dart';
import 'weather_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  WeatherForecast? _forecast;
  bool _loadingWeather = true;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  Future<void> _refreshDashboard() async {
    try {
      final forecast = await WeatherService.fetchForecast();
      if (!mounted) {
        return;
      }
      setState(() {
        _forecast = forecast;
        _loadingWeather = false;
      });
      FieldManager().updateForecast(forecast);
      await FieldManager().syncFromServer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingWeather = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FieldManager(),
      builder: (context, _) {
        final manager = FieldManager();
        final stats = _DashboardStats.from(manager, _forecast);

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshDashboard,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  _DashboardHeader(
                    unreadCount: manager.unreadNotificationCount,
                  ),
                  const SizedBox(height: 18),
                  _WeatherCard(
                    forecast: _forecast,
                    loading: _loadingWeather,
                    stats: stats,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WeatherScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  _SectionHeader(title: 'Explore Features', compact: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ModuleTile(
                          eyebrow: 'YIELD',
                          title: 'Optimization',
                          colors: const [
                            AppTheme.primaryButton,
                            Color(0xFF1F1F1F),
                          ],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FieldsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModuleTile(
                          eyebrow: 'DISEASE',
                          title: 'Detection',
                          colors: const [
                            AppTheme.primaryButton,
                            Color(0xFF1F1F1F),
                          ],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DiseaseDetectionScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _TrendCard(points: _buildTrendPoints(manager.fields)),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: 'Critical Fields',
                    badgeText: '${stats.criticalFields.length}',
                    actionLabel: 'View All',
                    onAction: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FieldsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (stats.criticalFields.isEmpty)
                    const _EmptyStateCard(
                      text:
                          'No urgent fields right now. Analyze more rounds to build readiness insights.',
                    )
                  else
                    ...stats.criticalFields.map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CriticalFieldCard(field: field),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final int unreadCount;

  const _DashboardHeader({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final displayName = AuthService().currentUser?.fullName.split(' ').first;

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
                children: [
                  const TextSpan(
                    text: 'Good morning, ',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: displayName ?? 'Arjun'),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE8ECE8)),
                ),
                child: IconButton(
                  onPressed: () {},
                  iconSize: 20,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text('$unreadCount'),
                    backgroundColor: AppTheme.brandGreen,
                    textColor: Colors.white,
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF1B242C),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: AssetImage('assets/images/tea_background.png'),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(
                      color: const Color(0xFFE7ECE7),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final WeatherForecast? forecast;
  final bool loading;
  final _DashboardStats stats;
  final VoidCallback onTap;

  const _WeatherCard({
    required this.forecast,
    required this.loading,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rainChance = forecast?.currentRainChance ?? 0;
    final showAlert = (forecast?.hasStormRisk ?? false) || rainChance >= 60;
    final temperatureText = forecast == null
        ? '--'
        : forecast!.currentTemp.toStringAsFixed(0);
    final conditionText = forecast?.currentDescription ?? 'Weather pending';
    final humidityText = '${forecast?.currentHumidity ?? 0}%';
    final windText = forecast == null
        ? '--'
        : '${forecast!.currentWindSpeed.toStringAsFixed(0)} km/h';
    final outlookTitle = forecast?.hasStormRisk == true
        ? 'High harvest risk'
        : rainChance >= 40
        ? 'Rain watch'
        : 'Good plucking window';
    final outlookAction = forecast?.hasStormRisk == true
        ? 'Wait for supervisor confirmation'
        : rainChance >= 40
        ? 'Pluck before noon if safe'
        : 'Prioritize ready fields';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        height: 185,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: const DecorationImage(
            image: AssetImage('assets/images/tea_background.png'),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.2),
                AppTheme.primaryButton.withValues(alpha: 0.7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side: Temp & info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      temperatureText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 46,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -2,
                                        height: 1.0,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4, left: 2),
                                      child: Text(
                                        '°C',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  conditionText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.sync_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      size: 11,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Updated 20 min ago',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 168,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black.withValues(alpha: 0.42),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      showAlert
                                          ? Icons.warning_amber_rounded
                                          : Icons.eco_outlined,
                                      color: showAlert
                                          ? const Color(0xFFFFD7D7)
                                          : AppTheme.brandGreen,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    const Expanded(
                                      child: Text(
                                        'Harvest Outlook',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  outlookTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  outlookAction,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 9.5,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryButton.withValues(alpha: 0.85),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            _WeatherInfoChip(
                              icon: Icons.cloud_outlined,
                              label: 'Rain',
                              value: '$rainChance%',
                              showDivider: true,
                            ),
                            _WeatherInfoChip(
                              icon: Icons.water_drop_outlined,
                              label: 'Humidity',
                              value: humidityText,
                              showDivider: true,
                            ),
                            _WeatherInfoChip(
                              icon: Icons.air_rounded,
                              label: 'Wind',
                              value: windText,
                              showDivider: true,
                            ),
                            const _WeatherInfoChip(
                              icon: Icons.explore_outlined,
                              label: 'Direction',
                              value: 'SW',
                              showDivider: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _WeatherInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  const _WeatherInfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.eyebrow,
    required this.title,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SizedBox(
            height: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.brandGreen,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      'Open',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<_TrendPoint> points;

  const _TrendCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE4E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actual Yield & Readiness',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RangePill(label: '7D', active: true),
                      _RangePill(label: '30D'),
                      _RangePill(label: '90D'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LegendDot(
                color: AppTheme.brandGreen,
                label: 'Actual Yield (kg)',
              ),
              const SizedBox(height: 8),
              const _LegendDot(
                color: AppTheme.primaryButton,
                label: 'Pluckable Ratio (%)',
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (points.isEmpty)
            const _EmptyStateCard(
              text:
                  'Log actual yield after completed rounds to populate the estate readiness trend.',
            )
          else
            SizedBox(
              height: 250,
              child: CustomPaint(
                painter: _TrendPainter(points: points),
                size: Size.infinite,
              ),
            ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  final String label;
  final bool active;

  const _RangePill({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryButton : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? badgeText;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const _SectionHeader({
    required this.title,
    this.badgeText,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 18 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (badgeText != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE84B4B),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeText!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        if (onAction != null && actionLabel != null) ...[
          const Spacer(),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                color: AppTheme.primaryButton,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CriticalFieldCard extends StatelessWidget {
  final _CriticalFieldInfo field;

  const _CriticalFieldCard({required this.field});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FieldAnalysisScreen(
                fieldId: field.fieldId,
                measurementId: field.measurementId,
              ),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEDF0EC)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Image.asset(
                          'assets/images/tea_background.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            field.fieldName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1B242C),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            field.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6E7E8B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF6E7E8B),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildActionBadge(field.chipLabel, field.chipColor),
                    const Spacer(),
                    Text(
                      field.metricLabel,
                      style: const TextStyle(
                        color: Color(0xFF6E7E8B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      field.metricValue,
                      style: TextStyle(
                        color: field.metricColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBadge(String label, Color accentColor) {
    IconData icon;
    if (label == 'Pluck Now') {
      icon = Icons.content_cut_rounded;
    } else if (label == 'Overgrown') {
      icon = Icons.warning_amber_rounded;
    } else {
      icon = Icons.thunderstorm_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String text;

  const _EmptyStateCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
      ),
    );
  }
}

class _DashboardStats {
  final double estimatedYieldKg;
  final double readinessPct;
  final String estimatedYieldCaption;
  final String readinessCaption;
  final String riskLabel;
  final String riskCaption;
  final Color riskColor;
  final List<_CriticalFieldInfo> criticalFields;

  const _DashboardStats({
    required this.estimatedYieldKg,
    required this.readinessPct,
    required this.estimatedYieldCaption,
    required this.readinessCaption,
    required this.riskLabel,
    required this.riskCaption,
    required this.riskColor,
    required this.criticalFields,
  });

  factory _DashboardStats.from(
    FieldManager manager,
    WeatherForecast? forecast,
  ) {
    final measurements = manager.fields
        .map((field) => field.latestMeasurement)
        .whereType<FieldMeasurement>()
        .toList();

    final estimatedYield = measurements.fold<double>(
      0,
      (sum, item) => sum + (item.predictedYieldKg ?? 0),
    );
    final readinessValues = measurements
        .where((item) => item.analyzedImages.isNotEmpty)
        .map((item) => item.averagePluckableRatio * 100)
        .toList();
    final readinessPct = readinessValues.isEmpty
        ? 0.0
        : readinessValues.reduce((a, b) => a + b) / readinessValues.length;

    final weatherRisk =
        forecast?.hasStormRisk == true ||
        (forecast?.currentRainChance ?? 0) >= 60;
    final unreadCritical = manager.notifications
        .where(
          (item) => item.severity == AlertSeverity.critical && item.isUnread,
        )
        .length;

    String riskLabel;
    String riskCaption;
    Color riskColor;
    if (weatherRisk || unreadCritical >= 3) {
      riskLabel = 'High';
      riskCaption = 'Weather and field pressure';
      riskColor = const Color(0xFFD95C5C);
    } else if (unreadCritical > 0 || readinessPct > 70) {
      riskLabel = 'Medium';
      riskCaption = 'Balanced monitoring needed';
      riskColor = const Color(0xFFB97922);
    } else {
      riskLabel = 'Low';
      riskCaption = 'Stable current outlook';
      riskColor = AppTheme.brandGreen;
    }

    final criticalFields = manager.fields
        .map((field) => _CriticalFieldInfo.from(field, forecast))
        .whereType<_CriticalFieldInfo>()
        .take(3)
        .toList();

    return _DashboardStats(
      estimatedYieldKg: estimatedYield,
      readinessPct: readinessPct,
      estimatedYieldCaption: estimatedYield > 0
          ? '${manager.fieldsReadyToPluck} fields close to action'
          : 'Analyze rounds to unlock estimate',
      readinessCaption: readinessPct >= 60
          ? 'Ready to pluck'
          : readinessPct >= 50
          ? 'Approaching window'
          : 'Need more growth',
      riskLabel: riskLabel,
      riskCaption: riskCaption,
      riskColor: riskColor,
      criticalFields: criticalFields,
    );
  }
}

class _CriticalFieldInfo {
  final String fieldId;
  final String measurementId;
  final String fieldName;
  final String caption;
  final String chipLabel;
  final Color chipColor;
  final String metricLabel;
  final String metricValue;
  final Color metricColor;

  const _CriticalFieldInfo({
    required this.fieldId,
    required this.measurementId,
    required this.fieldName,
    required this.caption,
    required this.chipLabel,
    required this.chipColor,
    required this.metricLabel,
    required this.metricValue,
    required this.metricColor,
  });

  static _CriticalFieldInfo? from(Field field, WeatherForecast? forecast) {
    final measurement = field.latestMeasurement;
    if (measurement == null || measurement.isCompleted) {
      return null;
    }

    final readinessPct = measurement.averagePluckableRatio * 100;
    final isReadyToPluck = measurement.pluckingStatus == 'ready_to_pluck';
    final isOvergrown = measurement.pluckingStatus == 'overgrown';
    final hasWeatherRisk = forecast?.hasStormRisk == true;

    if (isReadyToPluck && hasWeatherRisk) {
      return _CriticalFieldInfo(
        fieldId: field.id,
        measurementId: measurement.id,
        fieldName: field.name,
        caption: 'Ready to pluck, weather risk increasing',
        chipLabel: 'Weather Risk',
        chipColor: const Color(0xFFD95C5C),
        metricLabel: 'Risk Level',
        metricValue: 'High',
        metricColor: const Color(0xFFD95C5C),
      );
    }

    if (isReadyToPluck) {
      return _CriticalFieldInfo(
        fieldId: field.id,
        measurementId: measurement.id,
        fieldName: field.name,
        caption: 'High plucking readiness',
        chipLabel: 'Pluck Now',
        chipColor: const Color(0xFFE2574C),
        metricLabel: 'Readiness',
        metricValue: '${readinessPct.toStringAsFixed(0)}%',
        metricColor: AppTheme.brandGreen,
      );
    }

    if (isOvergrown) {
      return _CriticalFieldInfo(
        fieldId: field.id,
        measurementId: measurement.id,
        fieldName: field.name,
        caption: 'Leaf maturity past optimal window',
        chipLabel: 'Overgrown',
        chipColor: AppTheme.statusUrgent,
        metricLabel: 'Readiness',
        metricValue: '${readinessPct.toStringAsFixed(0)}%',
        metricColor: AppTheme.statusUrgent,
      );
    }

    return null;
  }
}

class _TrendPoint {
  final String label;
  final double actualYieldKg;
  final double pluckableRatioPct;

  const _TrendPoint({
    required this.label,
    required this.actualYieldKg,
    required this.pluckableRatioPct,
  });
}

List<_TrendPoint> _buildTrendPoints(List<Field> fields) {
  final grouped = <DateTime, Map<String, FieldMeasurement>>{};

  for (final field in fields) {
    for (final measurement in field.measurements) {
      if (!measurement.hasActualYield || measurement.analyzedImages.isEmpty) {
        continue;
      }
      final key = DateTime(
        measurement.date.year,
        measurement.date.month,
        measurement.date.day,
      );
      final fieldRecords = grouped.putIfAbsent(key, () => {});
      final existing = fieldRecords[field.id];
      if (existing == null || measurement.date.isAfter(existing.date)) {
        fieldRecords[field.id] = measurement;
      }
    }
  }

  final entries = grouped.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final recent = entries.length > 7
      ? entries.sublist(entries.length - 7)
      : entries;

  return recent.map((entry) {
    final records = entry.value.values.toList(growable: false);
    final actualYieldKg = records.fold<double>(
      0,
      (sum, measurement) => sum + (measurement.actualYieldKg ?? 0),
    );
    final totalPluckable = records.fold<int>(
      0,
      (sum, measurement) => sum + measurement.totalPluckableCount,
    );
    final totalBuds = records.fold<int>(
      0,
      (sum, measurement) =>
          sum + measurement.totalPluckableCount + measurement.totalArimbuCount,
    );
    final pluckableRatioPct = totalBuds == 0
        ? 0.0
        : (totalPluckable / totalBuds) * 100;

    return _TrendPoint(
      label: '${_monthName(entry.key.month)} ${entry.key.day}',
      actualYieldKg: actualYieldKg,
      pluckableRatioPct: pluckableRatioPct.clamp(0, 100),
    );
  }).toList();
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

class _TrendPainter extends CustomPainter {
  final List<_TrendPoint> points;

  const _TrendPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final leftPad = 40.0;
    final rightPad = 34.0;
    final topPad = 24.0;
    final bottomPad = 38.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    final highestYield = points.fold<double>(
      0,
      (max, point) => math.max(max, point.actualYieldKg),
    );
    final maxYield = math.max(1.0, highestYield * 1.18);
    const double maxRisk = 100.0;

    final gridPaint = Paint()
      ..color = const Color(0xFFF0F2F5)
      ..strokeWidth = 1;

    final yieldPaint = Paint()
      ..color = AppTheme.brandGreen
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final ratioPaint = Paint()
      ..color = AppTheme.primaryButton
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final yieldFillShader = LinearGradient(
      colors: [
        AppTheme.brandGreen.withValues(alpha: 0.15),
        AppTheme.brandGreen.withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(leftPad, topPad, chartWidth, chartHeight));

    final yieldFillPaint = Paint()..shader = yieldFillShader;

    final ratioFillShader = LinearGradient(
      colors: [
        AppTheme.primaryButton.withValues(alpha: 0.1),
        AppTheme.primaryButton.withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(leftPad, topPad, chartWidth, chartHeight));

    final ratioFillPaint = Paint()..shader = ratioFillShader;

    const axisStyle = TextStyle(
      color: Color(0xFF8A948D),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    // Draw horizontal grid lines and Y-axis labels
    final yLabelsLeft = List.generate(5, (index) {
      final value = maxYield * (1 - index / 4);
      if (value >= 1000) {
        return '${(value / 1000).toStringAsFixed(1)}k';
      }
      return value.toStringAsFixed(0);
    });
    final yLabelsRight = ['100', '75', '50', '25', '0'];

    for (var i = 0; i < 5; i++) {
      final y = topPad + (chartHeight / 4) * i;

      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );

      final leftPainter = TextPainter(
        text: TextSpan(text: yLabelsLeft[i], style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      leftPainter.paint(
        canvas,
        Offset(leftPad - leftPainter.width - 8, y - (leftPainter.height / 2)),
      );

      final rightPainter = TextPainter(
        text: TextSpan(text: yLabelsRight[i], style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      rightPainter.paint(
        canvas,
        Offset(size.width - rightPad + 8, y - (rightPainter.height / 2)),
      );
    }

    final slotWidth = points.length == 1
        ? 0.0
        : chartWidth / (points.length - 1);
    final yieldOffsets = <Offset>[];
    final ratioOffsets = <Offset>[];

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final dx = points.length == 1
          ? leftPad + (chartWidth / 2)
          : leftPad + (slotWidth * i);

      final yValue = (point.actualYieldKg).clamp(0.0, maxYield);
      final rValue = (point.pluckableRatioPct).clamp(0.0, maxRisk);

      final yieldDy = topPad + chartHeight - (yValue / maxYield) * chartHeight;
      final riskDy = topPad + chartHeight - (rValue / maxRisk) * chartHeight;

      yieldOffsets.add(Offset(dx, yieldDy));
      ratioOffsets.add(Offset(dx, riskDy));

      final labelPainter = TextPainter(
        text: TextSpan(text: point.label, style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(dx - (labelPainter.width / 2), size.height - 20),
      );
    }

    Path getBezierPath(List<Offset> offsets) {
      final path = Path();
      if (offsets.isEmpty) return path;
      path.moveTo(offsets[0].dx, offsets[0].dy);
      for (var i = 0; i < offsets.length - 1; i++) {
        final p0 = offsets[i];
        final p1 = offsets[i + 1];
        final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2.2, p0.dy);
        final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2.2, p1.dy);
        path.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          p1.dx,
          p1.dy,
        );
      }
      return path;
    }

    Path getBezierFillPath(List<Offset> offsets, double bottom) {
      final path = Path();
      if (offsets.isEmpty) return path;
      path.moveTo(offsets[0].dx, bottom);
      path.lineTo(offsets[0].dx, offsets[0].dy);
      for (var i = 0; i < offsets.length - 1; i++) {
        final p0 = offsets[i];
        final p1 = offsets[i + 1];
        final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2.2, p0.dy);
        final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2.2, p1.dy);
        path.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          p1.dx,
          p1.dy,
        );
      }
      path.lineTo(offsets.last.dx, bottom);
      path.close();
      return path;
    }

    if (yieldOffsets.length >= 2) {
      final bottomY = topPad + chartHeight;
      canvas.drawPath(getBezierFillPath(yieldOffsets, bottomY), yieldFillPaint);
      canvas.drawPath(getBezierFillPath(ratioOffsets, bottomY), ratioFillPaint);
      canvas.drawPath(getBezierPath(yieldOffsets), yieldPaint);
      canvas.drawPath(getBezierPath(ratioOffsets), ratioPaint);
    }

    final selectedIdx = points.length > 4 ? 4 : points.length - 1;
    if (selectedIdx >= 0 && selectedIdx < points.length) {
      final selectedYieldOffset = yieldOffsets[selectedIdx];
      final selectedRatioOffset = ratioOffsets[selectedIdx];
      final selectedX = selectedYieldOffset.dx;

      final dottedPaint = Paint()
        ..color = const Color(0xFFC2C9C4)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      const double dashHeight = 4.0;
      const double dashSpace = 4.0;
      double startY = topPad;
      final double endY = topPad + chartHeight;
      while (startY < endY) {
        canvas.drawLine(
          Offset(selectedX, startY),
          Offset(selectedX, (startY + dashHeight).clamp(topPad, endY)),
          dottedPaint,
        );
        startY += dashHeight + dashSpace;
      }

      final whitePaint = Paint()..color = Colors.white;

      final yDotOuter = Paint()..color = AppTheme.brandGreen;
      canvas.drawCircle(selectedYieldOffset, 6.0, yDotOuter);
      canvas.drawCircle(selectedYieldOffset, 3.0, whitePaint);

      final ratioDotOuter = Paint()..color = AppTheme.primaryButton;
      canvas.drawCircle(selectedRatioOffset, 6.0, ratioDotOuter);
      canvas.drawCircle(selectedRatioOffset, 3.0, whitePaint);

      final tooltipY =
          math.min(selectedYieldOffset.dy, selectedRatioOffset.dy) - 45;
      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(selectedX, tooltipY),
          width: 110,
          height: 52,
        ),
        const Radius.circular(8),
      );

      canvas.drawRRect(
        tooltipRect,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      canvas.drawRRect(tooltipRect, Paint()..color = Colors.white);

      canvas.drawRRect(
        tooltipRect,
        Paint()
          ..color = const Color(0xFFEAEDEA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      const tooltipTitleStyle = TextStyle(
        color: Color(0xFF1B242C),
        fontSize: 9,
        fontWeight: FontWeight.w700,
      );
      const tooltipBodyGreen = TextStyle(
        color: AppTheme.brandGreen,
        fontSize: 8,
        fontWeight: FontWeight.w700,
      );
      const tooltipBodyOrange = TextStyle(
        color: AppTheme.primaryButton,
        fontSize: 8,
        fontWeight: FontWeight.w700,
      );

      final selectedPoint = points[selectedIdx];

      final titlePainter = TextPainter(
        text: TextSpan(text: selectedPoint.label, style: tooltipTitleStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      titlePainter.paint(canvas, Offset(selectedX - 48, tooltipY - 20));

      final yieldValText =
          'Actual: ${selectedPoint.actualYieldKg.toStringAsFixed(0)} kg';
      final yieldValPainter = TextPainter(
        text: TextSpan(text: yieldValText, style: tooltipBodyGreen),
        textDirection: TextDirection.ltr,
      )..layout();
      yieldValPainter.paint(canvas, Offset(selectedX - 48, tooltipY - 6));

      final ratioValText =
          'Ratio: ${selectedPoint.pluckableRatioPct.toStringAsFixed(0)}%';
      final ratioValPainter = TextPainter(
        text: TextSpan(text: ratioValText, style: tooltipBodyOrange),
        textDirection: TextDirection.ltr,
      )..layout();
      ratioValPainter.paint(canvas, Offset(selectedX - 48, tooltipY + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
