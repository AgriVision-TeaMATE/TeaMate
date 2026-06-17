import 'package:flutter/material.dart';
import '../theme.dart';

class AlertBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color backgroundColor;

  const AlertBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.warning_amber_rounded,
    this.backgroundColor = AppTheme.errorColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.1),
        border: Border.all(color: backgroundColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: backgroundColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: backgroundColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
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
