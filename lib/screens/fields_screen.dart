import 'package:flutter/material.dart';

import '../models/field_model.dart';
import '../theme.dart';
import 'field_analysis_screen.dart';

class FieldsScreen extends StatefulWidget {
  const FieldsScreen({super.key});

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  void _showAddFieldDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add new field',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Field name',
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  return;
                }
                FieldManager().addField(name);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _openNewAnalysis(Field field) {
    final draft = FieldManager().createDraftMeasurement(field.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FieldAnalysisScreen(fieldId: field.id, measurementId: draft.id),
      ),
    );
  }

  void _openHistory(Field field, FieldMeasurement measurement) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FieldAnalysisScreen(
          fieldId: field.id,
          measurementId: measurement.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FieldManager(),
      builder: (context, _) {
        final fields = FieldManager().fields;
        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            centerTitle: true,
            title: const Text(
              'Yield Optimization',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: _showAddFieldDialog,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F4EA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Color(0xFF0B4F3F),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: fields.isEmpty
              ? _EmptyFieldState(onTap: _showAddFieldDialog)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  itemCount: fields.length,
                  itemBuilder: (context, index) {
                    final field = fields[index];
                    return _FieldCard(
                      key: ValueKey(field.id),
                      field: field,
                      initiallyExpanded: index == 0,
                      onAnalyze: () => _openNewAnalysis(field),
                      onHistoryTap: (measurement) =>
                          _openHistory(field, measurement),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _EmptyFieldState extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyFieldState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9AA3AF).withValues(alpha: 0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.landscape_outlined,
                size: 54,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No fields added yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by creating a field. Each field can hold multiple bud-analysis history records.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onTap,
              child: const Text('Add First Field'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends StatefulWidget {
  final Field field;
  final bool initiallyExpanded;
  final VoidCallback onAnalyze;
  final ValueChanged<FieldMeasurement> onHistoryTap;

  const _FieldCard({
    super.key,
    required this.field,
    this.initiallyExpanded = false,
    required this.onAnalyze,
    required this.onHistoryTap,
  });

  @override
  State<_FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<_FieldCard> {
  static const double _deletePaneWidth = 92;

  late bool _isExpanded;
  double _slideOffset = 0;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant _FieldCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field.id != widget.field.id) {
      _isExpanded = widget.initiallyExpanded;
      _slideOffset = 0;
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isExpanded) {
      return;
    }
    setState(() {
      _slideOffset = (_slideOffset + details.delta.dx).clamp(
        -_deletePaneWidth,
        0.0,
      );
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_isExpanded) {
      return;
    }
    final shouldOpen = _slideOffset.abs() > (_deletePaneWidth * 0.45);
    setState(() {
      _slideOffset = shouldOpen ? -_deletePaneWidth : 0;
    });
  }

  void _closeDeletePane() {
    if (_slideOffset == 0) {
      return;
    }
    setState(() {
      _slideOffset = 0;
    });
  }

  void _deleteField() {
    FieldManager().deleteField(widget.field.id);
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final latest = field.latestMeasurement;
    final allowSwipeDelete = !_isExpanded;
    final cardSurface = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: latest?.isReadyToPluck == true
                    ? const Color(0xFFE6F2EB)
                    : const Color(0xFFF1F3F5),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Text(
                latest?.readinessLabel ?? 'No analysis yet',
                style: TextStyle(
                  color: latest?.isReadyToPluck == true
                      ? const Color(0xFF2E7655)
                      : const Color(0xFF74817B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                      if (_isExpanded) {
                        _slideOffset = 0;
                      }
                    });
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 118),
                              child: Text(
                                field.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${field.region} • ${field.areaHectares.toStringAsFixed(1)} ha',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F3F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.schedule_rounded,
                                    color: Color(0xFF0B4F3F),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Latest record',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        latest == null
                                            ? 'No records yet'
                                            : '${formatDateTime(latest.date)} • ${latest.laborPriorityLabel}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF4C5E57),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 42),
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.chevron_right_rounded,
                          color: const Color(0xFFB6C2CB),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    child: _isExpanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              children: [
                                if (latest != null) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MetricTile(
                                          title: 'Avg pluckable',
                                          value:
                                              '${(latest.averagePluckableRatio * 100).toStringAsFixed(1)}%',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _MetricTile(
                                          title: 'Est. yield',
                                          value: latest.predictedYieldKg == null
                                              ? '--'
                                              : '${latest.predictedYieldKg!.toStringAsFixed(1)} kg',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: widget.onAnalyze,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0B4F3F),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.auto_awesome_motion_outlined,
                                    ),
                                    label: const Text('New Field Analysis'),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'History',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (field.measurements.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'No history records yet. Start the first analysis from the button above.',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  )
                                else
                                  ...field.measurements.reversed.map(
                                    (measurement) => _HistoryTile(
                                      fieldId: field.id,
                                      measurement: measurement,
                                      onTap: () =>
                                          widget.onHistoryTap(measurement),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9CA3AF).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: !allowSwipeDelete
          ? cardSurface
          : Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: _deletePaneWidth,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD95C5C),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: _deleteField,
                        borderRadius: BorderRadius.circular(16),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(_slideOffset, 0, 0),
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    onTap: _slideOffset != 0 ? _closeDeletePane : null,
                    onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                    onHorizontalDragEnd: _handleHorizontalDragEnd,
                    child: cardSurface,
                  ),
                ),
              ],
            ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;

  const _MetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatefulWidget {
  final String fieldId;
  final FieldMeasurement measurement;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.fieldId,
    required this.measurement,
    required this.onTap,
  });

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  static const double _deletePaneWidth = 88;

  double _slideOffset = 0;

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _slideOffset = (_slideOffset + details.delta.dx).clamp(
        -_deletePaneWidth,
        0.0,
      );
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final shouldOpen = _slideOffset.abs() > (_deletePaneWidth * 0.45);
    setState(() {
      _slideOffset = shouldOpen ? -_deletePaneWidth : 0;
    });
  }

  void _closeDeletePane() {
    if (_slideOffset == 0) {
      return;
    }
    setState(() {
      _slideOffset = 0;
    });
  }

  void _deleteMeasurement() {
    FieldManager().deleteMeasurement(widget.fieldId, widget.measurement.id);
  }

  @override
  Widget build(BuildContext context) {
    final tileSurface = InkWell(
      onTap: _slideOffset == 0 ? widget.onTap : _closeDeletePane,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF3F4F6),
              ),
              child: Center(
                child: Text(
                  widget.measurement.date.day.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Color(0xFF0B4F3F),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(widget.measurement.date),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.measurement.imageCount} images | ${(widget.measurement.averagePluckableRatio * 100).toStringAsFixed(1)}% avg pluckable',
                    style: const TextStyle(
                      color: Color(0xFF4E6259),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: _deletePaneWidth,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD95C5C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: _deleteMeasurement,
                borderRadius: BorderRadius.circular(12),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(_slideOffset, 0, 0),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onHorizontalDragUpdate: _handleHorizontalDragUpdate,
            onHorizontalDragEnd: _handleHorizontalDragEnd,
            child: tileSurface,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year}';
  }
}

String formatDateTime(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year} | ${hour.toString().padLeft(2, '0')}:$minute $period';
}
