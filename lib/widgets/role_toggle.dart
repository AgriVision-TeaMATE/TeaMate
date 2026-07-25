import 'package:flutter/material.dart';

import '../models/user_role.dart';

/// Two-segment Estate Manager / Factory Manager selector used on the
/// welcome screen. Styled to match the welcome action card palette.
class RoleToggle extends StatelessWidget {
  const RoleToggle({
    super.key,
    required this.selectedRole,
    required this.onChanged,
  });

  final String selectedRole;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFDADEDB).withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFBFC9BD).withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          _RoleSegment(
            role: UserRole.estateManager,
            icon: Icons.agriculture_outlined,
            selected: selectedRole == UserRole.estateManager,
            onTap: () => onChanged(UserRole.estateManager),
          ),
          const SizedBox(width: 4),
          _RoleSegment(
            role: UserRole.factoryManager,
            icon: Icons.factory_outlined,
            selected: selectedRole == UserRole.factoryManager,
            onTap: () => onChanged(UserRole.factoryManager),
          ),
        ],
      ),
    );
  }
}

class _RoleSegment extends StatelessWidget {
  const _RoleSegment({
    required this.role,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String role;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFF5C645F);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF00481D) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Text(
                  UserRole.label(role),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
