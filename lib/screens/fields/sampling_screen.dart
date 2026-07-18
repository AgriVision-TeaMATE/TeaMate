import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/custom_button.dart';

class SamplingScreen extends StatefulWidget {
  final int fieldNumber;
  const SamplingScreen({super.key, required this.fieldNumber});

  @override
  State<SamplingScreen> createState() => _SamplingScreenState();
}

class _SamplingScreenState extends State<SamplingScreen> {
  final List<Map<String, dynamic>> _samples = [];
  bool _isProcessing = false;

  void _captureSample() async {
    setState(() {
      _isProcessing = true;
    });

    // Mock processing delay
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Add a mocked sample result
    setState(() {
      _samples.add({
        'id': _samples.length + 1,
        'arimbu': 12,
        'pluckable': 85,
        'image': Icons.image,
      });
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalPluckable = _samples.fold(
      0,
      (sum, sample) => sum + (sample['pluckable'] as int),
    );
    double avgDensity = _samples.isEmpty ? 0 : totalPluckable / _samples.length;

    return Scaffold(
      appBar: AppBar(title: Text('Edge-Sampling: Field ${widget.fieldNumber}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Avg. Bud Density',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        Text(
                          '${avgDensity.toStringAsFixed(1)} buds/sqft',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Samples',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        Text(
                          '${_samples.length}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Captured Samples',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _samples.isEmpty
                    ? const Center(
                        child: Text(
                          'No samples yet. Capture a 1x1 sqft top-view image.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: _samples.length,
                        itemBuilder: (context, index) {
                          final sample = _samples[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  sample['image'] as IconData,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              title: Text('Sample #${sample['id']}'),
                              subtitle: Text(
                                'Pluckable: ${sample['pluckable']} | Arimbu: ${sample['arimbu']}',
                              ),
                              trailing: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Capture Sample',
                onPressed: _captureSample,
                isLoading: _isProcessing,
              ),
              const SizedBox(height: 12),
              if (_samples.length >= 3)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, avgDensity);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Complete Sampling',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
