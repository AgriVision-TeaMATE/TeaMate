import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/field_model.dart';
import 'field_analysis_screen.dart';

class FieldsScreen extends StatefulWidget {
  const FieldsScreen({super.key});

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  void _showAddFieldDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add New Field', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'e.g., Block B - Highland',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  FieldManager().addField(controller.text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FieldManager(),
      builder: (context, _) {
        final fields = FieldManager().fields;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8), // A very slight off-white for premium feel
          appBar: AppBar(
            title: const Text('My Plantations', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)),
            backgroundColor: Colors.transparent,
            foregroundColor: AppTheme.primaryDark,
            elevation: 0,
            centerTitle: false,
          ),
          body: fields.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 100),
                  itemCount: fields.length,
                  itemBuilder: (context, index) {
                    final field = fields[index];
                    return _buildPremiumFieldCard(field);
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddFieldDialog,
            backgroundColor: AppTheme.primaryDark,
            elevation: 4,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New Field', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        );
      }
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
            ),
            child: const Icon(Icons.eco_outlined, size: 64, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          const Text('No plantations tracked yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildPremiumFieldCard(Field field) {
    final hasData = field.measurements.isNotEmpty;
    final latest = hasData ? field.measurements.last : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          childrenPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          title: Text(
            field.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.textPrimary, letterSpacing: -0.5),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildStatusBadge(field),
          ),
          children: [
            if (hasData) ...[
              const SizedBox(height: 16),
              // Main Stats Row
              Row(
                children: [
                  Expanded(child: _buildStatBox('Bud Ratio', '${(latest!.ratio * 100).toStringAsFixed(1)}%', Icons.pie_chart_outline, Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatBox('Est. Yield', '${latest.estimatedYield.toStringAsFixed(1)}kg', Icons.monitor_weight_outlined, Colors.purple)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatBox('Health', '${latest.healthScore}', Icons.favorite_border, Colors.red)),
                ],
              ),
              const SizedBox(height: 24),
            ],
            
            // Action Grid
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildPrimaryActionButton(context, field),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSecondaryActionButton(
                    icon: Icons.bar_chart_rounded,
                    label: 'Yield',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yield prediction requires more data (Mock Action)'))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSecondaryActionButton(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Health',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bush health tracking starting... (Mock Action)'))),
                  ),
                ),
              ],
            ),
            
            if (field.measurements.length > 1) ...[
              const SizedBox(height: 32),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
              ),
              const SizedBox(height: 16),
              ...field.measurements.reversed.skip(1).map((m) => _buildHistoryRow(m)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Field field) {
    if (field.measurements.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('AWAITING DATA', style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ],
      );
    }

    final isReady = field.isReadyToPluck;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isReady ? AppTheme.accentGreen : AppTheme.alertRedBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isReady ? Icons.check_circle : Icons.timer, size: 12, color: isReady ? AppTheme.accentGreenText : AppTheme.alertRedText),
              const SizedBox(width: 4),
              Text(
                isReady ? 'READY TO PLUCK' : 'GROWING',
                style: TextStyle(
                  color: isReady ? AppTheme.accentGreenText : AppTheme.alertRedText,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color.withOpacity(0.7)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(BuildContext context, Field field) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FieldAnalysisScreen(field: field)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppTheme.primaryDark.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Analyze', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.textPrimary, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow(Measurement m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history, size: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Text(
            '${m.date.day.toString().padLeft(2, '0')} ${_monthString(m.date.month)} ${m.date.year}',
            style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(m.ratio * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _monthString(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
