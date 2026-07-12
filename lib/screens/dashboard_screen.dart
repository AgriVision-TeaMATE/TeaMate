import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/field_model.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import 'fields_screen.dart';
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
                  _SectionHeader(
                    title: 'AI / ML Modules',
                    actionLabel: 'Explore All',
                    onAction: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FieldsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ModuleTile(
                          title: 'Yield\nOptimization',
                          iconWidget: const CustomPaint(
                            painter: _YieldIconPainter(),
                            size: Size(32, 32),
                          ),
                          colors: const [Color(0xFF0F4E36), Color(0xFF0A3324)],
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
                          title: 'Disease\nDetection',
                          iconWidget: const CustomPaint(
                            painter: _DiseaseIconPainter(),
                            size: Size(32, 32),
                          ),
                          colors: const [Color(0xFF0F4E36), Color(0xFF0A3324)],
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModuleTile(
                          title: 'Tea Quality\nGrading',
                          iconWidget: const CustomPaint(
                            painter: _TeaIconPainter(),
                            size: Size(32, 32),
                          ),
                          colors: const [Color(0xFF0F4E36), Color(0xFF0A3324)],
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _TrendCard(
                    points: _buildTrendPoints(manager.fields, _forecast),
                  ),
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
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Text(
              'Arjun',
              style: TextStyle(
                color: Color(0xFF1B242C),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
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
                    backgroundColor: const Color(0xFF388E3C),
                    textColor: Colors.white,
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF1B242C),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
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
                const Color(0xFF0F3C18).withValues(alpha: 0.7),
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
                          // Right side: Compact Weather Alert if shown
                          if (showAlert)
                            Container(
                              width: 165,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black.withValues(alpha: 0.4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFC04B4B),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(11),
                                      ),
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Weather Alert',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Heavy rain expected',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Tomorrow, 6 AM - 12 PM',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
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
                          color: const Color(
                            0xFF0C2B29,
                          ).withValues(alpha: 0.85),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            _WeatherInfoChip(
                              icon: Icons.cloud_outlined,
                              label: 'Rainfall',
                              value: '18.6 mm',
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
  final String title;
  final Widget iconWidget;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.title,
    required this.iconWidget,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            image: const DecorationImage(
              image: AssetImage('assets/images/leaf_watermark.png'),
              alignment: Alignment.centerLeft,
              opacity: 0.08,
              fit: BoxFit.none,
            ),
          ),
          child: SizedBox(
            height: 64,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: iconWidget,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0x22FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YieldIconPainter extends CustomPainter {
  const _YieldIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw offset shadows first
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final barWidth = w * 0.10;
    
    // Draw 3D shadows for bars (slightly offset to bottom-right)
    final shadowOffset = 2.0;
    for (int i = 0; i < 4; i++) {
      double bh = 0.0;
      double bx = 0.0;
      double by = 0.0;
      if (i == 0) { bx = w * 0.05; by = h * 0.60; bh = h * 0.30; }
      if (i == 1) { bx = w * 0.20; by = h * 0.45; bh = h * 0.45; }
      if (i == 2) { bx = w * 0.35; by = h * 0.50; bh = h * 0.40; }
      if (i == 3) { bx = w * 0.50; by = h * 0.35; bh = h * 0.55; }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx + shadowOffset, by + shadowOffset, barWidth, bh),
          const Radius.circular(3),
        ),
        shadowPaint,
      );
    }

    // Paint bars with a green gradient
    final barGradient = const LinearGradient(
      colors: [Color(0xFFA5D6A7), Color(0xFF2E7D32)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final barPaint = Paint()
      ..shader = barGradient
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.60, barWidth, h * 0.30),
        const Radius.circular(3),
      ),
      barPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.45, barWidth, h * 0.45),
        const Radius.circular(3),
      ),
      barPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.35, h * 0.50, barWidth, h * 0.40),
        const Radius.circular(3),
      ),
      barPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.50, h * 0.35, barWidth, h * 0.55),
        const Radius.circular(3),
      ),
      barPaint,
    );

    // Glowing trend line (with dual stroke for neon look)
    final trendShadow = Paint()
      ..color = const Color(0xFFC8E6C9).withValues(alpha: 0.3)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final trendLine = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(w * 0.05, h * 0.55);
    path.quadraticBezierTo(w * 0.30, h * 0.40, w * 0.50, h * 0.30);
    
    canvas.drawPath(path, trendShadow);
    canvas.drawPath(path, trendLine);

    // 3D Leaves at the end
    final leafShadow = Path();
    leafShadow.moveTo(w * 0.50 + shadowOffset, h * 0.30 + shadowOffset);
    leafShadow.quadraticBezierTo(w * 0.62 + shadowOffset, h * 0.08 + shadowOffset, w * 0.85 + shadowOffset, h * 0.12 + shadowOffset);
    leafShadow.quadraticBezierTo(w * 0.72 + shadowOffset, h * 0.34 + shadowOffset, w * 0.50 + shadowOffset, h * 0.30 + shadowOffset);
    canvas.drawPath(leafShadow, shadowPaint);

    final leafGradient = const LinearGradient(
      colors: [Color(0xFFE8F5E9), Color(0xFF4CAF50)],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ).createShader(Rect.fromLTWH(w * 0.5, h * 0.1, w * 0.35, h * 0.25));

    final leafPaint = Paint()
      ..shader = leafGradient
      ..style = PaintingStyle.fill;
    
    final leaf1 = Path();
    leaf1.moveTo(w * 0.50, h * 0.30);
    leaf1.quadraticBezierTo(w * 0.62, h * 0.08, w * 0.85, h * 0.12);
    leaf1.quadraticBezierTo(w * 0.72, h * 0.34, w * 0.50, h * 0.30);
    canvas.drawPath(leaf1, leafPaint);

    final leaf2 = Path();
    leaf2.moveTo(w * 0.58, h * 0.26);
    leaf2.quadraticBezierTo(w * 0.74, h * 0.18, w * 0.80, h * 0.35);
    leaf2.quadraticBezierTo(w * 0.66, h * 0.38, w * 0.58, h * 0.26);
    
    final leafPaintSmall = Paint()
      ..color = const Color(0xFFC8E6C9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leaf2, leafPaintSmall);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiseaseIconPainter extends CustomPainter {
  const _DiseaseIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shadowOffset = 2.0;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Shield shadow path
    final shieldShadowPath = Path();
    shieldShadowPath.moveTo(w * 0.5 + shadowOffset, h * 0.15 + shadowOffset);
    shieldShadowPath.quadraticBezierTo(w * 0.78 + shadowOffset, h * 0.15 + shadowOffset, w * 0.82 + shadowOffset, h * 0.24 + shadowOffset);
    shieldShadowPath.quadraticBezierTo(w * 0.82 + shadowOffset, h * 0.60 + shadowOffset, w * 0.5 + shadowOffset, h * 0.88 + shadowOffset);
    shieldShadowPath.quadraticBezierTo(w * 0.18 + shadowOffset, h * 0.60 + shadowOffset, w * 0.18 + shadowOffset, h * 0.24 + shadowOffset);
    shieldShadowPath.quadraticBezierTo(w * 0.22 + shadowOffset, h * 0.15 + shadowOffset, w * 0.5 + shadowOffset, h * 0.15 + shadowOffset);
    canvas.drawPath(shieldShadowPath, shadowPaint);

    // Shield paint with 3D gradient stroke
    final shieldGradient = const LinearGradient(
      colors: [Color(0xFFE8F5E9), Color(0xFF2E7D32)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(w * 0.15, h * 0.15, w * 0.7, h * 0.73));

    final shieldPaint = Paint()
      ..shader = shieldGradient
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final shieldPath = Path();
    shieldPath.moveTo(w * 0.5, h * 0.15);
    shieldPath.quadraticBezierTo(w * 0.78, h * 0.15, w * 0.82, h * 0.24);
    shieldPath.quadraticBezierTo(w * 0.82, h * 0.60, w * 0.5, h * 0.88);
    shieldPath.quadraticBezierTo(w * 0.18, h * 0.60, w * 0.18, h * 0.24);
    shieldPath.quadraticBezierTo(w * 0.22, h * 0.15, w * 0.5, h * 0.15);
    canvas.drawPath(shieldPath, shieldPaint);

    // Translucent shield inner body for depth
    final shieldInnerPaint = Paint()
      ..color = const Color(0xFF81C784).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shieldPath, shieldInnerPaint);

    // Leaves inside shield (with shadow and gradient)
    final leafShadow = Path();
    leafShadow.moveTo(w * 0.35 + shadowOffset, h * 0.62 + shadowOffset);
    leafShadow.quadraticBezierTo(w * 0.44 + shadowOffset, h * 0.32 + shadowOffset, w * 0.65 + shadowOffset, h * 0.38 + shadowOffset);
    leafShadow.quadraticBezierTo(w * 0.56 + shadowOffset, h * 0.68 + shadowOffset, w * 0.35 + shadowOffset, h * 0.62 + shadowOffset);
    
    final leafShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leafShadow, leafShadowPaint);

    final leafGradient = const LinearGradient(
      colors: [Color(0xFFA5D6A7), Color(0xFF1B5E20)],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ).createShader(Rect.fromLTWH(w * 0.35, h * 0.32, w * 0.3, h * 0.36));

    final leafPaint = Paint()
      ..shader = leafGradient
      ..style = PaintingStyle.fill;

    final leaf1 = Path();
    leaf1.moveTo(w * 0.35, h * 0.62);
    leaf1.quadraticBezierTo(w * 0.44, h * 0.32, w * 0.65, h * 0.38);
    leaf1.quadraticBezierTo(w * 0.56, h * 0.68, w * 0.35, h * 0.62);
    canvas.drawPath(leaf1, leafPaint);

    final leaf2 = Path();
    leaf2.moveTo(w * 0.44, h * 0.53);
    leaf2.quadraticBezierTo(w * 0.58, h * 0.42, w * 0.68, h * 0.53);
    leaf2.quadraticBezierTo(w * 0.54, h * 0.64, w * 0.44, h * 0.53);
    
    final leafPaint2 = Paint()
      ..color = const Color(0xFFC8E6C9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leaf2, leafPaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TeaIconPainter extends CustomPainter {
  const _TeaIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shadowOffset = 2.0;

    // Cup shadow
    final cupShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final cupShadowPath = Path();
    cupShadowPath.moveTo(w * 0.18 + shadowOffset, h * 0.46 + shadowOffset);
    cupShadowPath.lineTo(w * 0.82 + shadowOffset, h * 0.46 + shadowOffset);
    cupShadowPath.quadraticBezierTo(w * 0.82 + shadowOffset, h * 0.82 + shadowOffset, w * 0.5 + shadowOffset, h * 0.82 + shadowOffset);
    cupShadowPath.quadraticBezierTo(w * 0.18 + shadowOffset, h * 0.82 + shadowOffset, w * 0.18 + shadowOffset, h * 0.46 + shadowOffset);
    canvas.drawPath(cupShadowPath, cupShadowPaint);

    // Cup body with radial shading for 3D sphere/cup feel
    final cupGradient = const RadialGradient(
      colors: [Colors.white, Color(0xFFD7CCC8)],
      center: Alignment(-0.2, -0.2),
      radius: 0.8,
    ).createShader(Rect.fromLTWH(w * 0.18, h * 0.46, w * 0.64, h * 0.36));

    final cupPaint = Paint()
      ..shader = cupGradient
      ..style = PaintingStyle.fill;

    final cupPath = Path();
    cupPath.moveTo(w * 0.18, h * 0.46);
    cupPath.lineTo(w * 0.82, h * 0.46);
    cupPath.quadraticBezierTo(w * 0.82, h * 0.82, w * 0.5, h * 0.82);
    cupPath.quadraticBezierTo(w * 0.18, h * 0.82, w * 0.18, h * 0.46);
    canvas.drawPath(cupPath, cupPaint);

    // Cup handle with highlight/gradient
    final handlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    
    final handlePath = Path();
    handlePath.moveTo(w * 0.82, h * 0.52);
    handlePath.quadraticBezierTo(w * 0.98, h * 0.60, w * 0.82, h * 0.72);
    canvas.drawPath(handlePath, handlePaint);

    // 3D leaves (with linear gradients for shadows/highlights)
    final leafGrad1 = const LinearGradient(
      colors: [Color(0xFF81C784), Color(0xFF1B5E20)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(w * 0.18, h * 0.22, w * 0.64, h * 0.24));

    final leafPaint1 = Paint()
      ..shader = leafGrad1
      ..style = PaintingStyle.fill;

    final leafGrad2 = const LinearGradient(
      colors: [Color(0xFFE8F5E9), Color(0xFF4CAF50)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(w * 0.38, h * 0.16, w * 0.24, h * 0.30));

    final leafPaint2 = Paint()
      ..shader = leafGrad2
      ..style = PaintingStyle.fill;

    // Left leaf
    final leafLeft = Path();
    leafLeft.moveTo(w * 0.36, h * 0.46);
    leafLeft.quadraticBezierTo(w * 0.18, h * 0.26, w * 0.28, h * 0.22);
    leafLeft.quadraticBezierTo(w * 0.44, h * 0.36, w * 0.36, h * 0.46);
    canvas.drawPath(leafLeft, leafPaint1);

    // Right leaf
    final leafRight = Path();
    leafRight.moveTo(w * 0.64, h * 0.46);
    leafRight.quadraticBezierTo(w * 0.82, h * 0.26, w * 0.72, h * 0.22);
    leafRight.quadraticBezierTo(w * 0.56, h * 0.36, w * 0.64, h * 0.46);
    canvas.drawPath(leafRight, leafPaint1);

    // Center leaf
    final leafCenter = Path();
    leafCenter.moveTo(w * 0.5, h * 0.46);
    leafCenter.quadraticBezierTo(w * 0.38, h * 0.22, w * 0.5, h * 0.16);
    leafCenter.quadraticBezierTo(w * 0.62, h * 0.22, w * 0.5, h * 0.46);
    canvas.drawPath(leafCenter, leafPaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          Row(
            children: [
              const Text(
                'Yield vs Risk',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
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
          const Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _LegendDot(
                color: Color(0xFF1D8A3E),
                label: 'Estimated Yield (kg)',
              ),
              _LegendDot(color: Color(0xFFF2B11A), label: 'Risk Index (%)'),
            ],
          ),
          const SizedBox(height: 18),
          if (points.isEmpty)
            const _EmptyStateCard(
              text:
                  'Add analyzed rounds with predicted yield to populate the trend view.',
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
        color: active ? const Color(0xFF0B5B2E) : Colors.transparent,
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
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? badgeText;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    this.badgeText,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
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
        const Spacer(),
        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: const TextStyle(
              color: Color(0xFF0B5B2E),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CriticalFieldCard extends StatelessWidget {
  final _CriticalFieldInfo field;

  const _CriticalFieldCard({required this.field});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAEDEA)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 60,
              height: 60,
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
                const SizedBox(height: 2),
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
          const SizedBox(width: 8),
          _buildActionBadge(field.chipLabel),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                field.metricLabel,
                style: const TextStyle(
                  color: Color(0xFF6E7E8B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
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
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF6E7E8B),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String label) {
    Color bgColor;
    Color textColor;
    IconData icon;

    if (label == 'Pluck Now') {
      bgColor = const Color(0xFFFDE8E8);
      textColor = const Color(0xFFC04B4B);
      icon = Icons.content_cut_rounded;
    } else if (label == 'Pluck Soon') {
      bgColor = const Color(0xFFFFF4E6);
      textColor = const Color(0xFFD97706);
      icon = Icons.access_time_rounded;
    } else {
      bgColor = const Color(0xFFFDE8E8);
      textColor = const Color(0xFFC04B4B);
      icon = Icons.thunderstorm_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
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
      riskColor = const Color(0xFF2E8B57);
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
  final String fieldName;
  final String caption;
  final String chipLabel;
  final Color chipBackground;
  final Color chipColor;
  final String metricLabel;
  final String metricValue;
  final Color metricColor;

  const _CriticalFieldInfo({
    required this.fieldName,
    required this.caption,
    required this.chipLabel,
    required this.chipBackground,
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
    if (forecast?.hasStormRisk == true && readinessPct >= 50) {
      return _CriticalFieldInfo(
        fieldName: field.name,
        caption: 'Weather risk increasing',
        chipLabel: 'Weather Risk',
        chipBackground: const Color(0xFFFFECEA),
        chipColor: const Color(0xFFD95C5C),
        metricLabel: 'Risk Level',
        metricValue: 'High',
        metricColor: const Color(0xFFD95C5C),
      );
    }

    if (measurement.isReadyToPluck) {
      return _CriticalFieldInfo(
        fieldName: field.name,
        caption: 'High plucking readiness',
        chipLabel: 'Pluck Now',
        chipBackground: const Color(0xFFFFE9E8),
        chipColor: const Color(0xFFE2574C),
        metricLabel: 'Readiness',
        metricValue: '${readinessPct.toStringAsFixed(0)}%',
        metricColor: const Color(0xFF2E8B57),
      );
    }

    if (readinessPct >= 50) {
      return _CriticalFieldInfo(
        fieldName: field.name,
        caption: 'Leaf maturity approaching target',
        chipLabel: 'Pluck Soon',
        chipBackground: const Color(0xFFFFF4E6),
        chipColor: const Color(0xFFCC8A17),
        metricLabel: 'Readiness',
        metricValue: '${readinessPct.toStringAsFixed(0)}%',
        metricColor: const Color(0xFF2E8B57),
      );
    }

    return null;
  }
}

class _TrendPoint {
  final String label;
  final double yieldKg;
  final double riskPct;

  const _TrendPoint({
    required this.label,
    required this.yieldKg,
    required this.riskPct,
  });
}

List<_TrendPoint> _buildTrendPoints(
  List<Field> fields,
  WeatherForecast? forecast,
) {
  final grouped = <DateTime, List<FieldMeasurement>>{};

  for (final field in fields) {
    for (final measurement in field.measurements) {
      if (measurement.predictedYieldKg == null) {
        continue;
      }
      final key = DateTime(
        measurement.date.year,
        measurement.date.month,
        measurement.date.day,
      );
      grouped.putIfAbsent(key, () => []).add(measurement);
    }
  }

  final entries = grouped.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final recent = entries.length > 7
      ? entries.sublist(entries.length - 7)
      : entries;

  return recent.map((entry) {
    final yieldKg = entry.value.fold<double>(
      0,
      (sum, measurement) => sum + (measurement.predictedYieldKg ?? 0),
    );
    final riskPct = entry.value.isEmpty
        ? 0.0
        : entry.value
                  .map((measurement) {
                    final readiness = measurement.averagePluckableRatio * 100;
                    final weatherBoost = forecast?.hasStormRisk == true
                        ? 18.0
                        : 0.0;
                    return (100 - readiness).clamp(0, 100) + weatherBoost;
                  })
                  .reduce((a, b) => a + b) /
              entry.value.length;

    return _TrendPoint(
      label: '${_monthName(entry.key.month)} ${entry.key.day}',
      yieldKg: yieldKg,
      riskPct: riskPct.clamp(0, 100),
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

    // We assume max values for rendering axes labels
    const double maxYield = 1600.0;
    const double maxRisk = 100.0;

    final gridPaint = Paint()
      ..color = const Color(0xFFF0F2F5)
      ..strokeWidth = 1;

    final yieldPaint = Paint()
      ..color = const Color(0xFF2E8B57)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final riskPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final yieldFillShader = LinearGradient(
      colors: [
        const Color(0xFF2E8B57).withValues(alpha: 0.15),
        const Color(0xFF2E8B57).withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(leftPad, topPad, chartWidth, chartHeight));

    final yieldFillPaint = Paint()..shader = yieldFillShader;

    final riskFillShader = LinearGradient(
      colors: [
        const Color(0xFFF59E0B).withValues(alpha: 0.1),
        const Color(0xFFF59E0B).withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(leftPad, topPad, chartWidth, chartHeight));

    final riskFillPaint = Paint()..shader = riskFillShader;

    const axisStyle = TextStyle(
      color: Color(0xFF8A948D),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    // Draw horizontal grid lines and Y-axis labels
    final yLabelsLeft = ['1.6k', '1.2k', '800', '400', '0'];
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
    final riskOffsets = <Offset>[];

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final dx = points.length == 1
          ? leftPad + (chartWidth / 2)
          : leftPad + (slotWidth * i);

      final yValue = (point.yieldKg).clamp(0.0, maxYield);
      final rValue = (point.riskPct).clamp(0.0, maxRisk);

      final yieldDy = topPad + chartHeight - (yValue / maxYield) * chartHeight;
      final riskDy = topPad + chartHeight - (rValue / maxRisk) * chartHeight;

      yieldOffsets.add(Offset(dx, yieldDy));
      riskOffsets.add(Offset(dx, riskDy));

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
      canvas.drawPath(getBezierFillPath(riskOffsets, bottomY), riskFillPaint);
      canvas.drawPath(getBezierPath(yieldOffsets), yieldPaint);
      canvas.drawPath(getBezierPath(riskOffsets), riskPaint);
    }

    final selectedIdx = points.length > 4 ? 4 : points.length - 1;
    if (selectedIdx >= 0 && selectedIdx < points.length) {
      final selectedYieldOffset = yieldOffsets[selectedIdx];
      final selectedRiskOffset = riskOffsets[selectedIdx];
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

      final yDotOuter = Paint()..color = const Color(0xFF2E8B57);
      canvas.drawCircle(selectedYieldOffset, 6.0, yDotOuter);
      canvas.drawCircle(selectedYieldOffset, 3.0, whitePaint);

      final rDotOuter = Paint()..color = const Color(0xFFF59E0B);
      canvas.drawCircle(selectedRiskOffset, 6.0, rDotOuter);
      canvas.drawCircle(selectedRiskOffset, 3.0, whitePaint);

      final tooltipY =
          math.min(selectedYieldOffset.dy, selectedRiskOffset.dy) - 45;
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
        color: Color(0xFF2E8B57),
        fontSize: 8,
        fontWeight: FontWeight.w700,
      );
      const tooltipBodyOrange = TextStyle(
        color: Color(0xFFD97706),
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
          '● Yield: ${selectedPoint.yieldKg.toStringAsFixed(0)} kg';
      final yieldValPainter = TextPainter(
        text: TextSpan(text: yieldValText, style: tooltipBodyGreen),
        textDirection: TextDirection.ltr,
      )..layout();
      yieldValPainter.paint(canvas, Offset(selectedX - 48, tooltipY - 6));

      final riskValText =
          '● Risk: ${selectedPoint.riskPct.toStringAsFixed(0)}%';
      final riskValPainter = TextPainter(
        text: TextSpan(text: riskValText, style: tooltipBodyOrange),
        textDirection: TextDirection.ltr,
      )..layout();
      riskValPainter.paint(canvas, Offset(selectedX - 48, tooltipY + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
