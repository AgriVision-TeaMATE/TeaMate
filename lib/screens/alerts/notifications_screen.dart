import 'package:flutter/material.dart';

import '../../models/field_model.dart';
import '../../services/api_service.dart';
import '../../theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _categories = [
    'All',
    'Weather',
    'Labor',
    'Quality',
    'Schedule',
    'Reminder',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<AppNotificationItem> _filterNotifications(
    List<AppNotificationItem> all,
  ) {
    if (_tabController.index == 0) return all;
    final category = _categories[_tabController.index];
    return all.where((n) => n.category == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FieldManager(),
      builder: (context, _) {
        final allNotifications = FieldManager().notifications;
        final filtered = _filterNotifications(allNotifications);

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
              if (allNotifications.any((n) => n.isUnread))
                TextButton(
                  onPressed: () {
                    ApiService().markAllNotificationsRead().then((_) {
                      FieldManager().syncFromServer();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All notifications marked as read'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    });
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isSelected = _tabController.index == index;
                    final category = _categories[index];
                    final count = index == 0
                        ? allNotifications.length
                        : allNotifications
                              .where((n) => n.category == category)
                              .length;

                    return GestureDetector(
                      onTap: () {
                        _tabController.animateTo(index);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0B4F3F)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              category,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : const Color(0xFFE0E5E9),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          body: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_off_outlined,
                            size: 42,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _tabController.index == 0
                              ? 'No notifications yet'
                              : 'No ${_categories[_tabController.index].toLowerCase()} notifications',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Weather warnings, labor reminders, and alerts will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _SummaryStrip(notifications: allNotifications);
                    }
                    final item = filtered[index - 1];
                    return _NotificationCard(item: item);
                  },
                ),
        );
      },
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final List<AppNotificationItem> notifications;

  const _SummaryStrip({required this.notifications});

  @override
  Widget build(BuildContext context) {
    final critical = notifications
        .where((item) => item.severity == AlertSeverity.critical)
        .length;
    final weather = notifications
        .where((item) => item.category == 'Weather')
        .length;
    final labor = notifications
        .where((item) => item.category == 'Labor')
        .length;
    final reminders = notifications
        .where(
          (item) => item.category == 'Reminder' || item.category == 'Schedule',
        )
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF173730), Color(0xFF0E221D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(label: 'Critical', value: '$critical'),
          ),
          Expanded(
            child: _SummaryMetric(label: 'Weather', value: '$weather'),
          ),
          Expanded(
            child: _SummaryMetric(label: 'Labor', value: '$labor'),
          ),
          Expanded(
            child: _SummaryMetric(label: 'Reminders', value: '$reminders'),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotificationItem item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(item.severity);
    final timeAgo = _formatTimeAgo(item.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: item.isUnread
            ? Border.all(color: color.withValues(alpha: 0.15))
            : null,
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
                    Icon(_categoryIcon(item.category), size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(
                      item.category,
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
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            item.fieldName,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.message,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(_actionIcon(item.category), size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _actionText(item.category),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: color.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Weather':
        return Icons.cloud_outlined;
      case 'Labor':
        return Icons.people_outline_rounded;
      case 'Quality':
        return Icons.verified_outlined;
      case 'Schedule':
        return Icons.calendar_today_outlined;
      case 'Reminder':
        return Icons.notifications_outlined;
      default:
        return Icons.info_outline;
    }
  }

  IconData _actionIcon(String category) {
    switch (category) {
      case 'Weather':
        return Icons.cloud_outlined;
      case 'Labor':
        return Icons.person_add_outlined;
      case 'Quality':
        return Icons.analytics_outlined;
      case 'Schedule':
        return Icons.event_outlined;
      default:
        return Icons.sms_outlined;
    }
  }

  String _actionText(String category) {
    switch (category) {
      case 'Weather':
        return 'View full weather forecast and plucking windows.';
      case 'Labor':
        return 'Open labour management to assign workers.';
      case 'Quality':
        return 'Review field analysis and plucking comparison.';
      case 'Schedule':
        return 'View scheduled plucking rounds and worker assignments.';
      default:
        return 'Auto-SMS summary ready for supervisor coordination.';
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
