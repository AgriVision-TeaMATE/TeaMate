import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/tea_grade_model.dart';
import 'grade_result_screen.dart';

/// Past tea quality scans for the signed-in factory manager, newest first.
class GradeHistoryScreen extends StatefulWidget {
  const GradeHistoryScreen({super.key});

  @override
  State<GradeHistoryScreen> createState() => _GradeHistoryScreenState();
}

class _GradeHistoryScreenState extends State<GradeHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TeaGradeManager().refreshHistory();
    });
  }

  Future<void> _openDetail(TeaQualityScan scan) async {
    final detail = await TeaGradeManager().loadDetail(scan.scanId) ?? scan;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GradeResultScreen(scan: detail)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: TeaGradeManager(),
          builder: (context, _) {
            final manager = TeaGradeManager();

            return RefreshIndicator(
              color: const Color(0xFF335C47),
              onRefresh: () => manager.refreshHistory(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Scan History',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          color: Color(0xFF18212B),
                        ),
                      ),
                    ),
                  ),
                  if (manager.usingMockData)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                      sliver: SliverToBoxAdapter(child: _MockNote()),
                    ),
                  if (manager.isLoading && manager.scans.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF335C47),
                        ),
                      ),
                    )
                  else if (manager.scans.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      sliver: SliverList.separated(
                        itemCount: manager.scans.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final scan = manager.scans[index];
                          return _ScanCard(
                            scan: scan,
                            onTap: () => _openDetail(scan),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MockNote extends StatelessWidget {
  const _MockNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0D9A6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFF9C7412)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sample data — the grading server is unreachable.',
              style: TextStyle(
                fontSize: 12.5,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.grain_rounded, size: 48, color: Color(0xFF8FA99B)),
        SizedBox(height: 12),
        Text(
          'No scans yet',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF425466),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Analyze a tea sample from the Home tab\nto see it here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF9AA6A0)),
        ),
      ],
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.scan, required this.onTap});

  final TeaQualityScan scan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    var dateLabel =
        DateFormat('d MMM yyyy • h:mm a').format(scan.scanDatetime.toLocal());
    if (scan.fieldName != null && scan.fieldName!.isNotEmpty) {
      dateLabel = '$dateLabel • ${scan.fieldName}';
    }
    final color = TeaGradePalette.colorFor(scan.dominantGrade);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E8E5)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.grain_rounded, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            scan.dominantGrade,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${scan.dominantGradePercentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF425466),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF9AA6A0),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB6C0BA),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
