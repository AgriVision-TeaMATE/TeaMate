import 'package:flutter/material.dart';
import '../theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.menu, color: AppTheme.textPrimary),
            SizedBox(width: 16),
            Text('AgriVision'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryDark,
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back, Manager',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Current Plantation Status: ', style: TextStyle(color: AppTheme.textSecondary)),
                Text('Optimal', style: TextStyle(color: AppTheme.accentGreenText, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 32),
            // Mock Chart Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'YIELD INSIGHT • WEEKLY PRODUCTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: AppTheme.primaryGreen),
                          const SizedBox(width: 4),
                          const Text('Current', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 8),
                          Icon(Icons.remove, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          const Text('Benchmark', style: TextStyle(fontSize: 10)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _MockChartPainter(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('MON', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      Text('TUE', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      Text('WED', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      Text('THU', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      Text('FRI', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      Text('SAT', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.map_outlined, size: 20),
                    label: const Text('Define Field', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text('Upload Image', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'SYSTEM MODULES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _buildModuleCard(
              title: 'Harvesting & Yield',
              description: 'Analyze bud counts and predict weekly harvest volumes with 94% precision using localized satellite data.',
              tag1: 'BUD COUNT: HIGH',
              tag1Color: AppTheme.accentGreenText,
              tag1Bg: AppTheme.accentGreen,
              tag2: 'EST. 4.2 TONS',
              tag2Color: Colors.blue.shade700,
              tag2Bg: Colors.blue.shade50,
            ),
            const SizedBox(height: 16),
            _buildModuleCard(
              title: 'Plant Health',
              description: 'Automated disease detection (Blister Blight) and bush vitality tracking using thermal and multispectral imaging.',
              tag1: 'ALERT: SECTOR B',
              tag1Color: AppTheme.alertRedText,
              tag1Bg: AppTheme.alertRedBg,
              tag2: 'HEALTH: 82%',
              tag2Color: Colors.teal.shade700,
              tag2Bg: Colors.teal.shade50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String description,
    required String tag1,
    required Color tag1Color,
    required Color tag1Bg,
    required String tag2,
    required Color tag2Color,
    required Color tag2Bg,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Center(
              child: Icon(Icons.image, color: Colors.white54, size: 40),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.arrow_forward, size: 20, color: AppTheme.textPrimary),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildTag(tag1, tag1Color, tag1Bg),
                    const SizedBox(width: 8),
                    _buildTag(tag2, tag2Color, tag2Bg),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MockChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = AppTheme.primaryGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintDashed = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw dashed benchmark line
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    double startX = 0;
    final benchmarkY = size.height * 0.7;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, benchmarkY), Offset(startX + dashWidth, benchmarkY), paintDashed);
      startX += dashWidth + dashSpace;
    }

    // Draw main production line
    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.2, size.height * 0.6);
    path.lineTo(size.width * 0.4, size.height * 0.65);
    path.lineTo(size.width * 0.6, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.3);
    path.lineTo(size.width, size.height * 0.45);
    canvas.drawPath(path, paintLine);

    // Draw points on the line
    final paintPoint = Paint()
      ..color = AppTheme.primaryGreen
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(Offset(0, size.height * 0.8), 4, paintPoint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.6), 4, paintPoint);
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.65), 4, paintPoint);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.4), 4, paintPoint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 4, paintPoint);
    canvas.drawCircle(Offset(size.width, size.height * 0.45), 4, paintPoint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
