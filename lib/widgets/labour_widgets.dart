import 'package:flutter/material.dart';
import '../models/field_model.dart';
import '../theme.dart';

/// Circular avatar with worker initials and status dot
class WorkerAvatar extends StatelessWidget {
  final Worker worker;
  final double size;
  final bool showStatusDot;

  const WorkerAvatar({
    super.key,
    required this.worker,
    this.size = 42,
    this.showStatusDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (worker.status) {
      WorkerStatus.available => const Color(0xFF2E7655),
      WorkerStatus.assigned => const Color(0xFF3B82F6),
      WorkerStatus.onLeave => const Color(0xFFB97922),
    };

    final bgColor = switch (worker.status) {
      WorkerStatus.available => const Color(0xFFE8F5EC),
      WorkerStatus.assigned => const Color(0xFFE8F0FE),
      WorkerStatus.onLeave => const Color(0xFFFFF2E8),
    };

    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(size * 0.35),
            ),
            child: Center(
              child: Text(
                worker.initials,
                style: TextStyle(
                  color: statusColor,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (showStatusDot)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Worker row tile for lists
class WorkerAssignmentTile extends StatelessWidget {
  final Worker worker;
  final String? fieldName;
  final VoidCallback? onTap;
  final Widget? trailing;

  const WorkerAssignmentTile({
    super.key,
    required this.worker,
    this.fieldName,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            WorkerAvatar(worker: worker),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      SkillBadge(skillLevel: worker.skillLevel, mini: true),
                      const SizedBox(width: 8),
                      Text(
                        fieldName ?? worker.statusLabel,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Skill level badge
class SkillBadge extends StatelessWidget {
  final SkillLevel skillLevel;
  final bool mini;

  const SkillBadge({super.key, required this.skillLevel, this.mini = false});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (skillLevel) {
      SkillLevel.senior => ('Senior', const Color(0xFF2E7655)),
      SkillLevel.experienced => ('Exp', const Color(0xFF3B82F6)),
      SkillLevel.junior => ('Junior', const Color(0xFFB97922)),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mini ? 6 : 10,
        vertical: mini ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: mini ? 10 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Field assignment card showing worker allocation status
class FieldAssignmentCard extends StatelessWidget {
  final Field field;
  final List<Worker> assignedWorkers;
  final int recommendedWorkers;
  final VoidCallback? onAssignTap;

  const FieldAssignmentCard({
    super.key,
    required this.field,
    required this.assignedWorkers,
    required this.recommendedWorkers,
    this.onAssignTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasShortage = assignedWorkers.length < recommendedWorkers;
    final status = field.latestMeasurement?.readinessLabel ?? 'No analysis';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasShortage
              ? const Color(0xFFD95C5C).withValues(alpha: 0.3)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${field.region} • ${field.areaHectares.toStringAsFixed(1)} ha',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: status == 'Ready to pluck'
                      ? const Color(0xFFE6F2EB)
                      : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: status == 'Ready to pluck'
                        ? const Color(0xFF2E7655)
                        : const Color(0xFF74817B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ShortageIndicator(
                assigned: assignedWorkers.length,
                recommended: recommendedWorkers,
              ),
              const Spacer(),
              if (assignedWorkers.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      for (int i = 0;
                          i < assignedWorkers.length && i < 4;
                          i++)
                        Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                          child: WorkerAvatar(
                            worker: assignedWorkers[i],
                            size: 32,
                            showStatusDot: false,
                          ),
                        ),
                      if (assignedWorkers.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F3F5),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: Text(
                                '+${assignedWorkers.length - 4}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          if (onAssignTap != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAssignTap,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text(
                  hasShortage ? 'Assign Workers' : 'Manage Workers',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: hasShortage
                      ? const Color(0xFFD95C5C)
                      : AppTheme.textPrimary,
                  side: BorderSide(
                    color: hasShortage
                        ? const Color(0xFFD95C5C).withValues(alpha: 0.4)
                        : const Color(0xFFE0E5E9),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Visual shortage indicator
class ShortageIndicator extends StatelessWidget {
  final int assigned;
  final int recommended;

  const ShortageIndicator({
    super.key,
    required this.assigned,
    required this.recommended,
  });

  @override
  Widget build(BuildContext context) {
    final hasShortage = assigned < recommended;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.people_outline_rounded,
          size: 18,
          color: hasShortage
              ? const Color(0xFFD95C5C)
              : const Color(0xFF2E7655),
        ),
        const SizedBox(width: 6),
        Text(
          '$assigned / $recommended workers',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: hasShortage
                ? const Color(0xFFD95C5C)
                : const Color(0xFF2E7655),
          ),
        ),
        if (hasShortage) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD95C5C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '-${recommended - assigned}',
              style: const TextStyle(
                color: Color(0xFFD95C5C),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
