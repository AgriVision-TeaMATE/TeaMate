import 'package:flutter/material.dart';

import '../models/field_model.dart';
import '../theme.dart';
import 'fields_screen.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FieldManager(),
      builder: (context, _) {
        final manager = FieldManager();
        final topFields = manager.prioritizedFields
            .take(3)
            .toList(growable: false);
        final notifications = manager.notifications
            .take(3)
            .toList(growable: false);
        final readyFields = manager.fields
            .where((field) => field.latestMeasurement?.isReadyToPluck == true)
            .length;
        final shortageFields = manager.fields
            .where(
              (field) =>
                  field.latestMeasurement?.laborPlan?.hasShortage == true,
            )
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFDBE8DD),
                  child: Icon(
                    Icons.spa_outlined,
                    color: AppTheme.primaryDark,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Text('TeaMate'),
              ],
            ),
            actions: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                  if (manager.unreadNotificationCount > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD95C5C),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryDark,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroSummaryCard(
                  predictedYieldTotalKg: manager.predictedYieldTotalKg,
                  actualYieldTotalKg: manager.actualYieldTotalKg,
                  readyFields: readyFields,
                  shortageFields: shortageFields,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Priority Today',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        title: 'Yield Module',
                        subtitle: 'Analyze buds and update yield',
                        icon: Icons.auto_graph_rounded,
                        accent: const Color(0xFFE5F1E4),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        title: 'Notifications',
                        subtitle: 'Weather, labor, and alerts',
                        icon: Icons.campaign_outlined,
                        accent: const Color(0xFFF7E6D9),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const Text(
                  'Operational Snapshot',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SnapshotTile(
                        label: 'Predicted Yield',
                        value:
                            '${manager.predictedYieldTotalKg.toStringAsFixed(0)} kg',
                        note: 'Across latest field records',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SnapshotTile(
                        label: 'Actual Yield',
                        value: manager.actualYieldTotalKg == 0
                            ? '--'
                            : '${manager.actualYieldTotalKg.toStringAsFixed(0)} kg',
                        note: 'Logged after plucking',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SnapshotTile(
                        label: 'Ready Fields',
                        value: readyFields.toString().padLeft(2, '0'),
                        note: 'Optimal plucking window',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SnapshotTile(
                        label: 'Shortage Alerts',
                        value: shortageFields.toString().padLeft(2, '0'),
                        note: 'Need labor balancing',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const Text(
                  'Field Routing Priority',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use maturity, yield potential, labor shortage, and weather risk to dispatch crews first.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 14),
                ...topFields.map((field) => _PriorityFieldTile(field: field)),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Alerts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                      child: const Text('View all'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (notifications.isEmpty)
                  const _EmptyAlertsCard()
                else
                  ...notifications.map(
                    (item) => _NotificationPreviewTile(item: item),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final double predictedYieldTotalKg;
  final double actualYieldTotalKg;
  final int readyFields;
  final int shortageFields;

  const _HeroSummaryCard({
    required this.predictedYieldTotalKg,
    required this.actualYieldTotalKg,
    required this.readyFields,
    required this.shortageFields,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF173730), Color(0xFF0C1D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Yield Optimization Command Center',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Show supervisors what to pluck, when to pluck, and where labor must move next.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Predicted yield ${predictedYieldTotalKg.toStringAsFixed(0)} kg with $readyFields ready field${readyFields == 1 ? '' : 's'} today.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Actual vs Predicted',
                  value: actualYieldTotalKg == 0
                      ? 'Pending'
                      : '${(actualYieldTotalKg - predictedYieldTotalKg).toStringAsFixed(0)} kg',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'Labor shortages',
                  value: shortageFields.toString().padLeft(2, '0'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppTheme.primaryDark),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final String label;
  final String value;
  final String note;

  const _SnapshotTile({
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(note, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _PriorityFieldTile extends StatelessWidget {
  final Field field;

  const _PriorityFieldTile({required this.field});

  @override
  Widget build(BuildContext context) {
    final measurement = field.latestMeasurement;
    if (measurement == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EFEB),
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: const Icon(
              Icons.landscape_rounded,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${field.region}  •  ${measurement.laborPriorityLabel}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${measurement.laborPriorityScore}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                'priority',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationPreviewTile extends StatelessWidget {
  final AppNotificationItem item;

  const _NotificationPreviewTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _severityColor(item.severity).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: _severityColor(item.severity),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.fieldName}  •  ${item.message}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class _EmptyAlertsCard extends StatelessWidget {
  const _EmptyAlertsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'No critical alerts right now. Notifications will appear here for labor shortage, weather pressure, reminders, and over-plucking risk.',
        style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
      ),
    );
  }
}
