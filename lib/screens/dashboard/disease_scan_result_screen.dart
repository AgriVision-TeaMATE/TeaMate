import 'package:flutter/material.dart';

import '../../models/field_model.dart';
import '../../theme.dart';

class DiseaseScanResultScreen extends StatefulWidget {
  final String fieldId;
  final String? imagePath;
  final DiseaseScanResult? scanResult;

  const DiseaseScanResultScreen({
    super.key,
    required this.fieldId,
    this.imagePath,
    this.scanResult,
  });

  @override
  State<DiseaseScanResultScreen> createState() => _DiseaseScanResultScreenState();
}

class _DiseaseScanResultScreenState extends State<DiseaseScanResultScreen> {
  late final DiseaseScanResult _scanResult;

  @override
  void initState() {
    super.initState();
    _scanResult = widget.scanResult ?? _generateDummyResult();
  }

  DiseaseScanResult _generateDummyResult() {
    return DiseaseScanResult(
      fieldId: widget.fieldId,
      imagePath: widget.imagePath,
      detectedAt: DateTime.now(),
      weather: WeatherSnapshot(
        date: DateTime.now(),
        summary: 'Partly cloudy',
        rainChance: 42,
        humidity: 78,
        temperatureC: 24.5,
        stormRisk: false,
      ),
      diseaseResults: [
        DiseaseResult(
          name: 'Blister Blight',
          confidence: 65,
          description:
              'Fungal disease causing small, water-soaked blisters on leaves that later turn brown and necrotic.',
          symptoms:
              'Small brownish blisters on upper leaf surface, yellowing around lesions, premature leaf drop.',
          treatment:
              'Apply copper-based fungicides, ensure proper spacing for air circulation, remove infected debris.',
        ),
        DiseaseResult(
          name: 'Tea Mosquito Bug',
          confidence: 18,
          description:
              'Insect pest that causes leaf curling and stunted growth by feeding on plant sap.',
          symptoms:
              'Leaves curl upward, yellow spots appear, shoots may wither and die.',
          treatment:
              'Use neem oil or insecticidal soap, encourage natural predators like spiders and birds.',
        ),
        DiseaseResult(
          name: 'Red Leaf Spot',
          confidence: 12,
          description:
              'Bacterial infection causing reddish-brown spots on leaves, leading to defoliation.',
          symptoms:
              'Reddish spots with yellow halos, margins appear reddish-brown, leaves drop prematurely.',
          treatment:
              'Prune affected branches, apply copper oxychloride, improve drainage.',
        ),
      ],
    );
  }

  void _navigateToRecommendations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiseaseRecommendationScreen(
          diseaseName: _scanResult.diseaseResults.first.name,
          confidence: _scanResult.diseaseResults.first.confidence,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Field? field = FieldManager()
        .fields
        .where((f) => f.id == widget.fieldId)
        .toList()
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Scan Results',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Section
            _ScanSummaryCard(
              field: field,
              scanResult: _scanResult,
            ),
            const SizedBox(height: 20),

            // Most Probable Disease
            _MostProbableDiseaseCard(
              disease: _scanResult.diseaseResults.first,
            ),
            const SizedBox(height: 20),

            // Confidence Analysis
            _ConfidenceAnalysisCard(
              diseaseResults: _scanResult.diseaseResults,
            ),
            const SizedBox(height: 20),

            // AI Explanations
            _AIExplanationSection(
              diseaseResults: _scanResult.diseaseResults,
            ),
            const SizedBox(height: 24),

            // Recommendation Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToRecommendations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.recommend_outlined, size: 18),
                label: const Text(
                  'View Recommendations',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiseaseScanResult {
  final String fieldId;
  final String? imagePath;
  final DateTime detectedAt;
  final WeatherSnapshot? weather;
  final List<DiseaseResult> diseaseResults;

  const DiseaseScanResult({
    required this.fieldId,
    this.imagePath,
    required this.detectedAt,
    this.weather,
    required this.diseaseResults,
  });
}

class DiseaseResult {
  final String name;
  final int confidence;
  final String description;
  final String symptoms;
  final String treatment;

  const DiseaseResult({
    required this.name,
    required this.confidence,
    required this.description,
    required this.symptoms,
    required this.treatment,
  });
}

class _ScanSummaryCard extends StatelessWidget {
  final Field? field;
  final DiseaseScanResult scanResult;

  const _ScanSummaryCard({required this.field, required this.scanResult});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppTheme.brandGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Scan Summary',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (field != null)
            _SummaryRow(
              label: 'Field',
              value: field!.name,
              icon: Icons.agriculture_outlined,
            ),
          if (field != null) const SizedBox(height: 10),
          _SummaryRow(
            label: 'Date',
            value: _formatDate(scanResult.detectedAt),
            icon: Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Time',
            value: _formatTime(scanResult.detectedAt),
            icon: Icons.access_time_outlined,
          ),
          const SizedBox(height: 10),
          if (scanResult.weather != null)
            _SummaryRow(
              label: 'Weather',
              value: _buildWeatherSummary(scanResult.weather!),
              icon: Icons.cloud_outlined,
            ),
          if (scanResult.weather != null) const SizedBox(height: 10),
          _SummaryRow(
            label: 'Image',
            value: scanResult.imagePath != null ? 'Captured' : 'Not available',
            icon: Icons.image_outlined,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _buildWeatherSummary(WeatherSnapshot weather) {
    return '${weather.temperatureC.toStringAsFixed(1)}°C • ${weather.humidity}% humidity';
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        const Text(':', style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MostProbableDiseaseCard extends StatelessWidget {
  final DiseaseResult disease;

  const _MostProbableDiseaseCard({required this.disease});

  @override
  Widget build(BuildContext context) {
    final confidenceColor = _getConfidenceColor(disease.confidence);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: Color(0xFFB54848),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Most Probable Disease',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD5D5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        disease.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF7A2713),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: confidenceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${disease.confidence}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  disease.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF7A2713).withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 60) return const Color(0xFFB54848);
    if (confidence >= 40) return const Color(0xFFE2574C);
    return const Color(0xFFB97922);
  }
}

class _ConfidenceAnalysisCard extends StatelessWidget {
  final List<DiseaseResult> diseaseResults;

  const _ConfidenceAnalysisCard({required this.diseaseResults});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppTheme.brandGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Confidence Analysis',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...diseaseResults.map((disease) => _ConfidenceBar(
                disease: disease,
                isTopResult: disease.confidence == diseaseResults.first.confidence,
              )),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final DiseaseResult disease;
  final bool isTopResult;

  const _ConfidenceBar({required this.disease, required this.isTopResult});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  disease.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isTopResult ? FontWeight.w800 : FontWeight.w600,
                    color:
                        isTopResult
                            ? const Color(0xFFB54848)
                            : AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${disease.confidence}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isTopResult ? FontWeight.w900 : FontWeight.w700,
                  color:
                      isTopResult
                          ? const Color(0xFFB54848)
                          : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              width: MediaQuery.of(context).size.width *
                  0.7 *
                  (disease.confidence / 100),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      isTopResult
                          ? [
                              const Color(0xFFB54848),
                              const Color(0xFFE2574C),
                            ]
                          : [
                              const Color(0xFF6E7E8B).withValues(alpha: 0.5),
                              const Color(0xFF6E7E8B).withValues(alpha: 0.3),
                            ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AIExplanationSection extends StatefulWidget {
  final List<DiseaseResult> diseaseResults;

  const _AIExplanationSection({required this.diseaseResults});

  @override
  State<_AIExplanationSection> createState() => _AIExplanationSectionState();
}

class _AIExplanationSectionState extends State<_AIExplanationSection> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_outlined, color: AppTheme.brandGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'AI Explanation',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.diseaseResults.asMap().entries.map((entry) {
            final index = entry.key;
            final disease = entry.value;
            final isExpanded = _expandedIndex == index;

            return Column(
              children: [
                _AIExplanationTile(
                  disease: disease,
                  isExpanded: isExpanded,
                  onTap: () {
                    setState(() {
                      _expandedIndex = isExpanded ? null : index;
                    });
                  },
                ),
                if (index < widget.diseaseResults.length - 1)
                  const Divider(height: 20, color: Color(0xFFE8ECEF)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _AIExplanationTile extends StatelessWidget {
  final DiseaseResult disease;
  final bool isExpanded;
  final VoidCallback onTap;

  const _AIExplanationTile({
    required this.disease,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    disease.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0),
              secondChild: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ExplanationSection(
                      title: 'Key Symptoms',
                      content: disease.symptoms,
                      icon: Icons.visibility_outlined,
                    ),
                    const SizedBox(height: 12),
                    _ExplanationSection(
                      title: 'Recommended Treatment',
                      content: disease.treatment,
                      icon: Icons.medical_services_outlined,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Why this result?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getAiReasoning(disease.name),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState:
                  isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  String _getAiReasoning(String diseaseName) {
    switch (diseaseName) {
      case 'Blister Blight':
        return 'The AI detected circular necrotic lesions with surrounding yellow halos, typical of blister blight infection. Image analysis showed characteristic brown blisters on upper leaf surface with water-soaked appearance.';
      case 'Tea Mosquito Bug':
        return 'Leaf curling and yellowing patterns were identified, consistent with tea mosquito bug damage. The affected leaf edges showed upward curling with irregular yellow spots.';
      case 'Red Leaf Spot':
        return 'Reddish-brown spots with defined margins detected on leaf surface. The pattern and color distribution match bacterial red leaf spot infection characteristics.';
      default:
        return 'Visual patterns matched known disease profiles in our database.';
    }
  }
}

class _ExplanationSection extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;

  const _ExplanationSection({
    required this.title,
    required this.content,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.brandGreen),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.brandGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// Placeholder recommendation screen
class DiseaseRecommendationScreen extends StatelessWidget {
  final String diseaseName;
  final int confidence;

  const DiseaseRecommendationScreen({
    super.key,
    required this.diseaseName,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Recommendations',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diseaseName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB54848),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Detected with $confidence% confidence',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Recommended Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RecommendationItem(
                    title: 'Apply fungicide',
                    description:
                        'Use copper-based fungicides bi-weekly until symptoms clear.',
                    icon: Icons.eco_outlined,
                  ),
                  const SizedBox(height: 12),
                  _RecommendationItem(
                    title: 'Improve air circulation',
                    description:
                        'Prune surrounding vegetation to reduce humidity around plants.',
                    icon: Icons.cut_outlined,
                  ),
                  const SizedBox(height: 12),
                  _RecommendationItem(
                    title: 'Monitor regularly',
                    description:
                        'Check plants every 3-4 days for spread of infection.',
                    icon: Icons.visibility_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _RecommendationItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.brandGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppTheme.brandGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}