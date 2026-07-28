import 'package:flutter/material.dart';

import '../../models/field_model.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../dashboard/weather_screen.dart';
import '../fields/field_analysis_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FieldManager(),
      builder: (context, _) {
        final manager = FieldManager();
        final entries = _buildEntries(manager);
        final hasUnreadLabor = manager.notifications.any(
          (item) => item.category.toLowerCase() == 'labor' && item.isUnread,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            actions: [
              if (hasUnreadLabor)
                TextButton(
                  onPressed: () async {
                    await ApiService().markAllNotificationsRead();
                    await FieldManager().syncFromServer();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Labour notifications marked as read'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      color: Color(0xFF0B4F3F),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          body: entries.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _NotificationCard(
                      entry: entry,
                      onTap: () => _handleTap(context, entry),
                    );
                  },
                ),
        );
      },
    );
  }

  List<_AlertEntry> _buildEntries(FieldManager manager) {
    final laborEntries = manager.notifications
        .where((item) => item.category.toLowerCase() == 'labor')
        .map((item) => _AlertEntry(type: _AlertType.labor, item: item))
        .toList();

    final weatherEntries = _buildWeatherWarnings(manager.cachedForecast);
    final entries = [...weatherEntries, ...laborEntries];
    entries.sort((a, b) => b.item.createdAt.compareTo(a.item.createdAt));
    return entries;
  }

  List<_AlertEntry> _buildWeatherWarnings(WeatherForecast? forecast) {
    if (forecast == null) {
      return const [];
    }

    final warnings = <_AlertEntry>[];
    final today = DateTime.now();
    final todayDaily = forecast.daily.where(
      (day) =>
          day.date.year == today.year &&
          day.date.month == today.month &&
          day.date.day == today.day,
    );
    final daily = todayDaily.isEmpty ? null : todayDaily.first;

    if (forecast.hasStormRisk) {
      warnings.add(
        _AlertEntry(
          type: _AlertType.weather,
          item: AppNotificationItem(
            id: 'weather-storm-${forecast.fetchedAt.toIso8601String()}',
            fieldName: 'Today',
            title: 'Storm risk in today\'s forecast',
            message:
                'Rain or strong wind is expected today. Review the weather window before sending pluckers.',
            category: 'Weather',
            createdAt: forecast.fetchedAt,
            severity: AlertSeverity.warning,
            isUnread: false,
          ),
        ),
      );
    } else if (forecast.currentRainChance >= 40 ||
        (daily?.rainChance ?? 0) >= 40) {
      warnings.add(
        _AlertEntry(
          type: _AlertType.weather,
          item: AppNotificationItem(
            id: 'weather-rain-${forecast.fetchedAt.toIso8601String()}',
            fieldName: 'Today',
            title: 'Rain warning for today',
            message:
                'Today has an elevated rain chance. Check the forecast before crew movement and plan early plucking if needed.',
            category: 'Weather',
            createdAt: forecast.fetchedAt,
            severity: AlertSeverity.info,
            isUnread: false,
          ),
        ),
      );
    }

    return warnings;
  }

  void _handleTap(BuildContext context, _AlertEntry entry) {
    switch (entry.type) {
      case _AlertType.labor:
        final fieldId = entry.item.fieldId;
        if (fieldId == null) {
          return;
        }
        final field = FieldManager().fields
            .where((f) => f.id == fieldId)
            .firstOrNull;
        final measurement = field?.latestMeasurement;
        if (field == null || measurement == null) {
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FieldAnalysisScreen(
              fieldId: field.id,
              measurementId: measurement.id,
            ),
          ),
        );
        break;
      case _AlertType.weather:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeatherScreen()),
        );
        break;
    }
  }
}

enum _AlertType { labor, weather }

class _AlertEntry {
  final _AlertType type;
  final AppNotificationItem item;

  const _AlertEntry({required this.type, required this.item});
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.notifications_off_outlined,
              size: 42,
              color: AppTheme.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Labour allocation updates and today\'s weather warnings will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final _AlertEntry entry;
  final VoidCallback onTap;

  const _NotificationCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final color = _severityColor(item.severity);
    final timeAgo = _formatTimeAgo(item.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: item.isUnread
                  ? Border.all(color: color.withValues(alpha: 0.14))
                  : Border.all(color: const Color(0xFFE8ECEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _categoryIcon(entry.type),
                            size: 12,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.type == _AlertType.labor
                                ? 'Labor'
                                : 'Weather',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (item.isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.fieldName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.fieldName,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  item.message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(_AlertType type) {
    switch (type) {
      case _AlertType.labor:
        return Icons.people_outline_rounded;
      case _AlertType.weather:
        return Icons.cloud_outlined;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) {
      return 'Yesterday';
    }
    return '${diff.inDays}d ago';
  }

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return const Color(0xFFD95C5C);
      case AlertSeverity.warning:
        return const Color(0xFFB97922);
      case AlertSeverity.info:
        return const Color(0xFF2E7655);
    }
  }
}
