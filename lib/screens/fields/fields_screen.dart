import 'package:flutter/material.dart';

import '../../models/field_model.dart';
import '../../theme.dart';
import 'field_analytics_screen.dart';
import 'field_analysis_screen.dart';

class FieldsScreen extends StatefulWidget {
  const FieldsScreen({super.key});

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFields() async {
    await FieldManager().syncFromServer();
  }

  void _showAddFieldDialog() {
    final nameController = TextEditingController();
    final areaController = TextEditingController();
    var isSaving = false;
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleSave() async {
              final name = nameController.text.trim();
              final areaSquareMeters = double.tryParse(
                areaController.text.trim(),
              );
              if (name.isEmpty ||
                  areaSquareMeters == null ||
                  areaSquareMeters <= 0) {
                return;
              }

              setDialogState(() => isSaving = true);
              final created = await FieldManager().addField(
                name: name,
                areaHectares: areaSquareMeters / 10000,
              );
              if (!context.mounted) return;
              setDialogState(() => isSaving = false);

              if (created) {
                Navigator.pop(context);
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Unable to save field. Check login and backend.',
                  ),
                ),
              );
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              contentPadding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Add new field',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.78,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 48,
                      child: TextField(
                        controller: nameController,
                        autofocus: true,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Field name',
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: TextField(
                        controller: areaController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Field area (m²)',
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryButton,
                  ),
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : handleSave,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(64, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openNewAnalysis(Field field) {
    final draftId = 'draft-${DateTime.now().microsecondsSinceEpoch}';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FieldAnalysisScreen(fieldId: field.id, measurementId: draftId),
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

  void _openAnalytics(Field field) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FieldAnalyticsScreen(fieldId: field.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FieldManager(),
      builder: (context, _) {
        final fields = FieldManager().fields;
        final filteredFields = _searchQuery.isEmpty
            ? fields
            : fields
                  .where(
                    (field) => field.name.toLowerCase().contains(_searchQuery),
                  )
                  .toList();
        return Scaffold(
          backgroundColor: AppTheme.backgroundLight,
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
                      color: AppTheme.primaryButton,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primaryButton.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshFields,
            child: fields.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _FieldSearchBar(
                          controller: _searchController,
                          onChanged: _updateSearch,
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: _EmptyFieldState(onTap: _showAddFieldDialog),
                      ),
                    ],
                  )
                : filteredFields.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      _FieldSearchBar(
                        controller: _searchController,
                        onChanged: _updateSearch,
                      ),
                      const SizedBox(height: 28),
                      const Center(
                        child: Text(
                          'No matching fields found',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: filteredFields.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _FieldSearchBar(
                            controller: _searchController,
                            onChanged: _updateSearch,
                          ),
                        );
                      }

                      final field = filteredFields[index - 1];
                      return _FieldCard(
                        key: ValueKey(field.id),
                        field: field,
                        initiallyExpanded: index == 1,
                        onAnalyze: () => _openNewAnalysis(field),
                        onAnalytics: () => _openAnalytics(field),
                        onHistoryTap: (measurement) =>
                            _openHistory(field, measurement),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  void _updateSearch(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
    });
  }
}

class _FieldSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _FieldSearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Search fields',
          hintStyle: const TextStyle(
            color: AppTheme.inputHint,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textSecondary,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE4D8), width: 1.1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppTheme.primaryButton,
              width: 1.2,
            ),
          ),
        ),
      ),
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
  final VoidCallback onAnalytics;
  final ValueChanged<FieldMeasurement> onHistoryTap;

  const _FieldCard({
    super.key,
    required this.field,
    this.initiallyExpanded = false,
    required this.onAnalyze,
    required this.onAnalytics,
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

  Color _priorityColor(FieldMeasurement? latest) {
    if (latest == null) {
      return const Color(0xFFF2F3F0);
    }

    final ratio = latest.averagePluckableRatio;
    if (ratio > 0.70) {
      return const Color(0xFFD94A4A);
    }
    if (ratio >= 0.60) {
      return const Color(0xFFE69A2E);
    }
    if (ratio >= 0.50) {
      return AppTheme.brandGreen;
    }
    return const Color(0xFF87919A);
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final latest = field.latestMeasurement;
    final allowSwipeDelete = !_isExpanded;
    final hasLatestStatus = latest != null;
    final priorityColor = _priorityColor(latest);
    final cardSurface = Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFBFDF8)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9DE)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
              child: Text(
                latest?.laborPriorityLabel ?? 'No analysis yet',
                style: TextStyle(
                  color: hasLatestStatus
                      ? Colors.white
                      : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
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
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              field.subtitle,
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
                                    color: AppTheme.primaryButton.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.schedule_rounded,
                                    color: Colors.black,
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
                                            : formatDateTime(latest.date),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textPrimary,
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
                          color: AppTheme.textSecondary.withValues(alpha: 0.55),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: widget.onAnalyze,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryButton,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.auto_awesome_motion_outlined,
                                          size: 17,
                                        ),
                                        label: const Text(
                                          'New Analysis',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: widget.onAnalytics,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.brandGreen,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.analytics_outlined,
                                          size: 17,
                                        ),
                                        label: const Text(
                                          'Analytics',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
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
                                      color: const Color(0xFFF6F7F5),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Text(
                                      'No history records yet. Start the first analysis from the button above.',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  )
                                else
                                  _HistoryList(
                                    fieldId: field.id,
                                    measurements: field.measurements.reversed
                                        .toList(),
                                    onHistoryTap: widget.onHistoryTap,
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                        color: const Color(0xFFB54848),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        onTap: _deleteField,
                        borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A4A4A), Color(0xFF2F2F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.brandGreen,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.78),
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  static const double _historyTileHeight = 84;

  final String fieldId;
  final List<FieldMeasurement> measurements;
  final ValueChanged<FieldMeasurement> onHistoryTap;

  const _HistoryList({
    required this.fieldId,
    required this.measurements,
    required this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCount = measurements.length > 3 ? 3 : measurements.length;

    return SizedBox(
      height: visibleCount * _historyTileHeight,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        physics: measurements.length > 3
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: measurements.length,
        itemBuilder: (context, index) {
          final measurement = measurements[index];
          return _HistoryTile(
            fieldId: fieldId,
            measurement: measurement,
            roundNumber: index + 1,
            onTap: () => onHistoryTap(measurement),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatefulWidget {
  final String fieldId;
  final FieldMeasurement measurement;
  final int roundNumber;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.fieldId,
    required this.measurement,
    required this.roundNumber,
    required this.onTap,
  });

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  static const double _deletePaneWidth = 88;
  static const double _historyRadius = 14;

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
      borderRadius: BorderRadius.circular(_historyRadius),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFDF9),
          borderRadius: BorderRadius.circular(_historyRadius),
          border: Border.all(color: const Color(0xFFDDE4D8), width: 1.1),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_historyRadius),
                      color: AppTheme.primaryButton.withValues(alpha: 0.10),
                    ),
                    child: Center(
                      child: Text(
                        widget.roundNumber.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 82),
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
                            '${(widget.measurement.averagePluckableRatio * 100).toStringAsFixed(1)}% avg pluckable',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 8,
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary.withValues(alpha: 0.65),
              ),
            ),
            if (widget.measurement.isCompleted)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.brandGreen,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(_historyRadius),
                      bottomLeft: Radius.circular(_historyRadius),
                    ),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
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
                color: const Color(0xFFB54848),
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                onTap: _deleteMeasurement,
                borderRadius: BorderRadius.circular(14),
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
