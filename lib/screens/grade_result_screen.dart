import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/tea_grade_model.dart';

/// Displays one tea quality scan: sample image, summary and the per-grade
/// composition breakdown. Pure display — reached from both the home screen
/// (fresh scan) and the history screen (fetched scan).
class GradeResultScreen extends StatelessWidget {
  const GradeResultScreen({super.key, required this.scan, this.localImageBytes});

  final TeaQualityScan scan;
  final Uint8List? localImageBytes;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('d MMM yyyy • h:mm a').format(scan.scanDatetime.toLocal());

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9FC),
        elevation: 0,
        foregroundColor: const Color(0xFF18212B),
        title: const Text(
          'Grade Analysis',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (scan.isMock) ...[
                const _MockBanner(),
                const SizedBox(height: 14),
              ],
              _SampleImage(scan: scan, localImageBytes: localImageBytes),
              const SizedBox(height: 18),
              _SummaryCard(scan: scan, dateLabel: dateLabel),
              const SizedBox(height: 18),
              const Text(
                'Grade Composition',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: Color(0xFF18212B),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE3E8E5)),
                ),
                child: Column(
                  children: [
                    for (final entry in scan.gradeComposition)
                      _GradeRow(
                        entry: entry,
                        isDominant: entry.grade == scan.dominantGrade,
                      ),
                  ],
                ),
              ),
              if (scan.modelVersion != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Model: ${scan.modelVersion}'
                  '${scan.inferenceTimeMs != null ? ' • ${scan.inferenceTimeMs!.toStringAsFixed(0)} ms' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA6A0),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MockBanner extends StatelessWidget {
  const _MockBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D9A6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFF9C7412)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sample data — the grading server is unreachable.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9C7412),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleImage extends StatelessWidget {
  const _SampleImage({required this.scan, this.localImageBytes});

  final TeaQualityScan scan;
  final Uint8List? localImageBytes;

  @override
  Widget build(BuildContext context) {
    final remoteUrl = scan.resolvedImageUrl;

    Widget child;
    if (remoteUrl != null) {
      child = Image.network(
        remoteUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => localImageBytes != null
            ? Image.memory(localImageBytes!, fit: BoxFit.cover)
            : const _ImagePlaceholder(),
      );
    } else if (localImageBytes != null) {
      child = Image.memory(localImageBytes!, fit: BoxFit.cover);
    } else {
      child = const _ImagePlaceholder();
    }

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E8E5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.grain_rounded, size: 44, color: Color(0xFF8FA99B)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.scan, required this.dateLabel});

  final TeaQualityScan scan;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF335C47),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dominant Grade',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB9D0C2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scan.dominantGrade,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${scan.dominantGradePercentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Field',
                  value: scan.fieldName ?? '—',
                ),
              ),
              const SizedBox(width: 22),
              _SummaryStat(
                label: 'Particles',
                value: scan.totalParticlesDetected?.toString() ?? '—',
              ),
              const SizedBox(width: 22),
              _SummaryStat(label: 'Grades', value: '${scan.gradeComposition.length}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB9D0C2),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.entry, required this.isDominant});

  final GradeComposition entry;
  final bool isDominant;

  @override
  Widget build(BuildContext context) {
    final color = TeaGradePalette.colorFor(entry.grade);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.grade,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isDominant ? FontWeight.w700 : FontWeight.w600,
                    color: const Color(0xFF18212B),
                  ),
                ),
              ),
              Text(
                '${entry.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isDominant ? FontWeight.w700 : FontWeight.w600,
                  color: const Color(0xFF425466),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (entry.percentage / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFFEDF1EE),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
