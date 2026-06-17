import 'package:flutter/material.dart';
import '../theme.dart';
import 'field_detail_screen.dart';

class FieldListScreen extends StatelessWidget {
  const FieldListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mocked data for labor routing ranking
    final List<Map<String, dynamic>> fields = [
      {'id': 3, 'name': 'Field 3 (Upper Estate)', 'status': 'Ready to Pluck', 'score': 92, 'color': Colors.green},
      {'id': 1, 'name': 'Field 1 (Main Estate)', 'status': 'Ready to Pluck', 'score': 85, 'color': Colors.green},
      {'id': 5, 'name': 'Field 5 (East Slopes)', 'status': 'Pluck in 2 Days', 'score': 70, 'color': Colors.orange},
      {'id': 2, 'name': 'Field 2 (Lower Estate)', 'status': 'Not Ready', 'score': 45, 'color': AppTheme.errorColor},
      {'id': 4, 'name': 'Field 4 (North Ridge)', 'status': 'Recently Plucked', 'score': 10, 'color': Colors.grey},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Precise Labor Routing'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24.0),
        itemCount: fields.length,
        itemBuilder: (context, index) {
          final field = fields[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FieldDetailScreen(fieldNumber: field['id'] as int),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: field['color'].withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: field['color'].withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.landscape, color: field['color']),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field['name'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: field['color'].withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  field['status'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: field['color'],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Score: ${field['score']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
