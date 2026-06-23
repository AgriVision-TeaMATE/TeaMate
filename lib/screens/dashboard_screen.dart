import 'package:flutter/material.dart';

import '../theme.dart';
import 'fields_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFDBE8DD),
              child: Icon(Icons.spa_outlined, color: AppTheme.primaryDark, size: 18),
            ),
            SizedBox(width: 12),
            Text('TeaMate'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryDark,
              child: Icon(Icons.person_outline_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 26),
            const Text(
              'Main Modules',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Launch the core plantation workflows from one screen.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            _buildModuleButton(
              title: 'Yield Optimization',
              subtitle: 'Field setup, bud analysis, and yield prediction',
              accent: const Color(0xFFE5F1E4),
              icon: Icons.auto_graph_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FieldsScreen()),
                );
              },
            ),
            const SizedBox(height: 14),
            _buildModuleButton(
              title: 'Plant Health',
              subtitle: 'Disease spotting and crop condition monitoring',
              accent: const Color(0xFFF3E9D9),
              icon: Icons.health_and_safety_outlined,
              onTap: () {},
            ),
            const SizedBox(height: 14),
            _buildModuleButton(
              title: 'Operations Insights',
              subtitle: 'Harvest planning, trends, and crew performance',
              accent: const Color(0xFFE6EEF9),
              icon: Icons.insights_outlined,
              onTap: () {},
            ),
            const SizedBox(height: 28),
            const Text(
              'Today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _snapshotTile(
                    label: 'Fields Tracked',
                    value: '12',
                    note: '3 active today',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _snapshotTile(
                    label: 'Ready Zones',
                    value: '04',
                    note: 'Yield window open',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF173730),
            Color(0xFF0C1D1A),
          ],
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
              'Professional Field Workspace',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Modern plantation intelligence for field teams and estate managers.',
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
            'Start with Yield Optimization to define fields, capture multiple images, analyze buds, and preview harvest output.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleButton({
    required String title,
    required String subtitle,
    required Color accent,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(20),
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
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppTheme.primaryDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }

  Widget _snapshotTile({
    required String label,
    required String value,
    required String note,
  }) {
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
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
