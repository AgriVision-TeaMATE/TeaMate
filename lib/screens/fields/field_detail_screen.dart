import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/alert_banner.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'sampling_screen.dart';

class FieldDetailScreen extends StatefulWidget {
  final int fieldNumber;
  const FieldDetailScreen({super.key, required this.fieldNumber});

  @override
  State<FieldDetailScreen> createState() => _FieldDetailScreenState();
}

class _FieldDetailScreenState extends State<FieldDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double? _avgDensity;
  final TextEditingController _weightController = TextEditingController();
  bool _showDilutionAlert = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _startSampling() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SamplingScreen(fieldNumber: widget.fieldNumber),
      ),
    );
    if (result != null && result is double) {
      setState(() {
        _avgDensity = result;
      });
    }
  }

  void _verifyWeight() {
    final weightStr = _weightController.text;
    if (weightStr.isEmpty) return;

    final weight = double.tryParse(weightStr);
    if (weight != null && weight > 180) {
      // Max predicted was 180
      setState(() {
        _showDilutionAlert = true;
      });
    } else {
      setState(() {
        _showDilutionAlert = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yield matches prediction. Normal status.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Field ${widget.fieldNumber} Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Pre-Harvest'),
            Tab(text: 'Post-Harvest'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPreHarvestTab(), _buildPostHarvestTab()],
      ),
    );
  }

  Widget _buildPreHarvestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRI-Aligned Status',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to Pluck',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Optimal Day: Today',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Smart Edge-Sampling',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_avgDensity != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Average Density: ${_avgDensity!.toStringAsFixed(1)} buds/sqft',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Predicted Yield Range: 150 kg - 180 kg',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          CustomButton(
            text: _avgDensity == null
                ? 'Start Edge-Sampling'
                : 'Re-Sample Field',
            onPressed: _startSampling,
          ),
        ],
      ),
    );
  }

  Widget _buildPostHarvestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Post-Harvest Verification',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Compare actual scale weight against the predicted yield range to detect anomalies.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          CustomTextField(
            label: 'Actual Scale Weight (kg)',
            hint: 'Enter weight (e.g. 195)',
            keyboardType: TextInputType.number,
            controller: _weightController,
          ),
          const SizedBox(height: 24),
          CustomButton(text: 'Verify Weight', onPressed: _verifyWeight),
          const SizedBox(height: 32),
          if (_showDilutionAlert)
            const AlertBanner(
              title: 'Quota Dilution Alert',
              message:
                  'Actual weight is abnormally high compared to prediction. Workers may have included heavy coarse leaves or restricted Arimbu.',
            ),
        ],
      ),
    );
  }
}
