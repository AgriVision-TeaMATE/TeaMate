import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/field_model.dart';
import '../theme.dart';

class FieldAnalysisScreen extends StatefulWidget {
  final String fieldId;
  final String measurementId;

  const FieldAnalysisScreen({
    super.key,
    required this.fieldId,
    required this.measurementId,
  });

  @override
  State<FieldAnalysisScreen> createState() => _FieldAnalysisScreenState();
}

class _FieldAnalysisScreenState extends State<FieldAnalysisScreen> {
  static const int _minimumImages = 3;

  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController(viewportFraction: 0.92);

  late Field _field;
  late FieldMeasurement _measurement;
  final List<_PendingImage> _pendingImages = [];

  int _currentIndex = 0;
  bool _isAnalyzing = false;
  String? _analysisStatus;
  bool _didCleanupDraft = false;

  @override
  void initState() {
    super.initState();
    final manager = FieldManager();
    _field = manager.fields.firstWhere((field) => field.id == widget.fieldId);
    _measurement = _field.measurements.firstWhere(
      (measurement) => measurement.id == widget.measurementId,
    );
    _measurement = manager.hydrateMeasurementSupportData(
      widget.fieldId,
      _measurement,
    );
    manager.saveMeasurement(widget.fieldId, _measurement);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (pickedFile == null) {
      return;
    }

    setState(() {
      _pendingImages.add(
        _PendingImage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          imagePath: pickedFile.path,
          sourceLabel: source == ImageSource.camera ? 'Camera' : 'Upload',
          capturedAt: DateTime.now(),
        ),
      );
      _currentIndex = _galleryItems.length - 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _analyzeBuds() async {
    if (!_canAnalyze) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisStatus = null;
    });

    final analyzedImages = List<AnalysisImageResult>.from(
      _measurement.analyzedImages,
    );
    final pendingCopy = List<_PendingImage>.from(_pendingImages);

    for (var index = 0; index < pendingCopy.length; index++) {
      setState(() {
        _analysisStatus =
            'Analyzing image ${index + 1} of ${pendingCopy.length}';
      });
      await Future<void>.delayed(const Duration(milliseconds: 450));
      analyzedImages.add(
        _mockAnalyzeImage(pendingCopy[index], index + analyzedImages.length),
      );
    }

    final manager = FieldManager();
    _measurement = manager.hydrateMeasurementSupportData(
      widget.fieldId,
      _measurement.copyWith(
        analyzedImages: analyzedImages,
        date: DateTime.now(),
        clearPrediction: true,
      ),
    );
    manager.saveMeasurement(widget.fieldId, _measurement);

    setState(() {
      _pendingImages.clear();
      _currentIndex = 0;
      _isAnalyzing = false;
      _analysisStatus = null;
    });
  }

  Future<void> _showPredictYieldSheet() async {
    final controller = TextEditingController(
      text:
          _measurement.fieldArea?.toStringAsFixed(1) ??
          _field.areaHectares.toStringAsFixed(1),
    );

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Predict yield',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use analyzed bud counts and full field area to estimate harvest output for planning.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Field area (hectares)',
                    hintText: 'Ex: 2.5',
                    filled: true,
                    fillColor: const Color(0xFFF5F7F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final area = double.tryParse(controller.text.trim());
                      if (area == null || area <= 0) {
                        return;
                      }
                      Navigator.pop(context, area);
                    },
                    child: const Text('Confirm Prediction'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) {
      return;
    }

    final predictedYield = _calculatePredictedYield(result);
    final manager = FieldManager();
    setState(() {
      _measurement = manager.hydrateMeasurementSupportData(
        widget.fieldId,
        _measurement.copyWith(
          fieldArea: result,
          predictedYieldKg: predictedYield,
        ),
      );
    });
    manager.saveMeasurement(widget.fieldId, _measurement);
  }

  Future<void> _showActualYieldSheet() async {
    final controller = TextEditingController(
      text: _measurement.actualYieldKg?.toStringAsFixed(1) ?? '',
    );

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Log actual yield',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter the actual scale weight after plucking to compare with the prediction and detect over-plucking.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Actual yield (kg)',
                    hintText: 'Ex: 195.0',
                    filled: true,
                    fillColor: const Color(0xFFF5F7F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final actual = double.tryParse(controller.text.trim());
                      if (actual == null || actual <= 0) {
                        return;
                      }
                      Navigator.pop(context, actual);
                    },
                    child: const Text('Save Actual Yield'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) {
      return;
    }

    final manager = FieldManager();
    setState(() {
      _measurement = _measurement.copyWith(actualYieldKg: result);
    });
    manager.saveMeasurement(widget.fieldId, _measurement);
  }

  double _calculatePredictedYield(double fieldArea) {
    final summary = _measurement;
    final budStrength =
        (summary.totalPluckableCount * 0.42) +
        (summary.totalArimbuCount * 0.18);
    final maturityFactor = 0.92 + (summary.averagePluckableRatio * 0.35);
    return budStrength * fieldArea * maturityFactor;
  }

  AnalysisImageResult _mockAnalyzeImage(_PendingImage image, int seed) {
    final random = Random(seed + image.imagePath.length);
    final arimbuCount = 16 + random.nextInt(18);
    final pluckableCount = 24 + random.nextInt(24);
    final total = arimbuCount + pluckableCount;
    return AnalysisImageResult(
      id: image.id,
      imagePath: image.imagePath,
      sourceLabel: image.sourceLabel,
      capturedAt: image.capturedAt,
      arimbuCount: arimbuCount,
      pluckableCount: pluckableCount,
      capturedArea: 6.5 + (random.nextDouble() * 3.5),
      budMarkers: List.generate(
        min(total, 18),
        (_) => Offset(
          0.12 + (random.nextDouble() * 0.76),
          0.16 + (random.nextDouble() * 0.64),
        ),
      ),
    );
  }

  void _cleanupDraftIfNeeded() {
    if (_didCleanupDraft) {
      return;
    }
    if (_measurement.analyzedImages.isEmpty) {
      FieldManager().removeMeasurement(widget.fieldId, widget.measurementId);
      _didCleanupDraft = true;
    }
  }

  List<_GalleryItem> get _galleryItems => [
    ..._measurement.analyzedImages.map(_GalleryItem.analyzed),
    ..._pendingImages.map(_GalleryItem.pending),
  ];

  _GalleryItem? get _selectedItem {
    if (_galleryItems.isEmpty) {
      return null;
    }
    final safeIndex = _currentIndex.clamp(0, _galleryItems.length - 1).toInt();
    return _galleryItems[safeIndex];
  }

  bool get _canAnalyze =>
      !_isAnalyzing &&
      _pendingImages.isNotEmpty &&
      _galleryItems.length >= _minimumImages;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItem;
    final alerts = FieldManager().buildInsightsForMeasurement(
      _field,
      _measurement,
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, __) {
        if (didPop) {
          _cleanupDraftIfNeeded();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F3),
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              _cleanupDraftIfNeeded();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _field.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '${_field.region} • ${_field.areaHectares.toStringAsFixed(1)} ha',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDecisionHero(),
              const SizedBox(height: 18),
              _buildAlertsSection(alerts),
              const SizedBox(height: 18),
              _buildPlanningCards(),
              const SizedBox(height: 18),
              _buildCapturePanel(),
              const SizedBox(height: 18),
              _buildAnalyzeSection(),
              const SizedBox(height: 18),
              if (_galleryItems.isEmpty)
                _EmptyGalleryState(minimumImages: _minimumImages)
              else ...[
                _buildImageCarousel(),
                const SizedBox(height: 16),
                if (_galleryItems.length > 1) _buildThumbnailRail(),
                const SizedBox(height: 16),
                _buildSelectedImageStats(selected),
                const SizedBox(height: 16),
                _buildSummaryCard(),
              ],
              if (_measurement.analyzedImages.length >= _minimumImages) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showPredictYieldSheet,
                        icon: const Icon(Icons.insights_outlined),
                        label: Text(
                          _measurement.predictedYieldKg == null
                              ? 'Predict Yield'
                              : 'Update Prediction',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _measurement.predictedYieldKg == null
                            ? null
                            : _showActualYieldSheet,
                        icon: const Icon(Icons.scale_outlined),
                        label: Text(
                          _measurement.actualYieldKg == null
                              ? 'Log Actual Yield'
                              : 'Update Actual Yield',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildComparisonCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDecisionHero() {
    final weather = _measurement.weather;
    final predicted = _measurement.predictedYieldKg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF10231F),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ReadinessTag(isReady: _measurement.isReadyToPluck),
              const Spacer(),
              if (_measurement.hasOverPluckingRisk)
                const _RiskTag(
                  label: 'Over-plucking risk',
                  background: Color(0xFFFBE6E6),
                  foreground: Color(0xFFC04B4B),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Pre-plucking decision status',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _measurement.readinessLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            weather == null
                ? 'Weather-based timing will appear after support data is prepared.'
                : '${weather.summary} • ${weather.temperatureC.toStringAsFixed(1)}°C • ${weather.rainChance}% rain chance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetricTile(
                  label: 'Predicted yield',
                  value: predicted == null
                      ? '--'
                      : '${predicted.toStringAsFixed(1)} kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMetricTile(
                  label: 'Pluckable ratio',
                  value: _measurement.analyzedImages.isEmpty
                      ? '--'
                      : '${(_measurement.averagePluckableRatio * 100).toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(List<InsightAlert> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Insights',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        ...alerts.map((alert) => _InsightTile(alert: alert)),
      ],
    );
  }

  Widget _buildPlanningCards() {
    final weather = _measurement.weather;
    final labor = _measurement.laborPlan;

    return Row(
      children: [
        Expanded(
          child: _PlanningCard(
            icon: Icons.cloud_outlined,
            title: 'Weather Window',
            lines: [
              weather == null ? 'No forecast' : weather.summary,
              weather == null
                  ? ''
                  : '${weather.temperatureC.toStringAsFixed(1)}°C • ${weather.humidity}% humidity',
              weather == null
                  ? ''
                  : weather.stormRisk
                  ? 'Move harvest earlier'
                  : 'Conditions acceptable for planned round',
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanningCard(
            icon: Icons.groups_2_outlined,
            title: 'Labor Allocation',
            lines: [
              labor == null
                  ? 'No crew plan'
                  : '${labor.availableWorkers}/${labor.recommendedWorkers} workers available',
              labor == null ? '' : 'Round starts ${labor.shiftStart}',
              labor == null
                  ? ''
                  : labor.smsScheduled
                  ? 'Auto-SMS ready for labor lead'
                  : 'Send labor reminder needed',
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCapturePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Image capture',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Capture or upload top-view images from multiple representative spots across the field.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Upload Image'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeSection() {
    final totalImages = _galleryItems.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10231F),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canAnalyze ? _analyzeBuds : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryDark,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isAnalyzing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Analyze Buds',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            totalImages >= _minimumImages
                ? 'Ready to analyze. Results will feed yield prediction, labor planning, and plucking alerts.'
                : 'Add at least $_minimumImages images before analysis. Current count: $totalImages',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Sampling note: use more than 3 images from separate rows or corners to stabilize the average maturity result.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          if (_analysisStatus != null) ...[
            const SizedBox(height: 12),
            Text(
              _analysisStatus!,
              style: const TextStyle(
                color: AppTheme.accentGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    return SizedBox(
      height: 286,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _galleryItems.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = _galleryItems[index];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: EdgeInsets.only(
              right: 12,
              left: index == 0 ? 0 : 4,
              top: index == _currentIndex ? 0 : 8,
              bottom: index == _currentIndex ? 0 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImageSurface(item),
                  if (item.analysis != null)
                    ...item.analysis!.budMarkers.map(
                      (marker) => Positioned(
                        left: marker.dx * 260,
                        top: marker.dy * 240,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFF00B66D,
                            ).withValues(alpha: 0.18),
                            border: Border.all(
                              color: const Color(0xFF00B66D),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.analysis == null
                            ? 'Pending'
                            : item.analysis!.sourceLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageSurface(_GalleryItem item) {
    if (item.imagePath != null) {
      return Image.file(
        File(item.imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => _buildPlaceholderSurface(item),
      );
    }
    return _buildPlaceholderSurface(item);
  }

  Widget _buildPlaceholderSurface(_GalleryItem item) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF789B79), Color(0xFF264535)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_outlined, size: 42, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              item.analysis?.sourceLabel ?? item.pending!.sourceLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailRail() {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _galleryItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = _galleryItems[index];
          final isActive = index == _currentIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentIndex = index;
              });
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive ? AppTheme.primaryDark : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryDark.withValues(alpha: 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImageSurface(item),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedImageStats(_GalleryItem? selected) {
    final analysis = selected?.analysis;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selected image counts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                '${_currentIndex + 1}/${_galleryItems.length}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CountBox(
                  title: 'Arimbu count',
                  value: analysis?.arimbuCount.toString() ?? '--',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CountBox(
                  title: 'Pluckable count',
                  value: analysis?.pluckableCount.toString() ?? '--',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CountBox(
                  title: 'Ratio',
                  value: analysis == null
                      ? '--'
                      : '${(analysis.pluckableRatio * 100).toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final measurement = _measurement;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2EC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Average output summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              if (measurement.analyzedImages.isNotEmpty)
                _ReadinessTag(isReady: measurement.isReadyToPluck),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryStat(
                label: 'Total Arimbu count',
                value: '${measurement.totalArimbuCount}',
              ),
              _SummaryStat(
                label: 'Total Pluckable count',
                value: '${measurement.totalPluckableCount}',
              ),
              _SummaryStat(
                label: 'Avg pluckable ratio',
                value: measurement.analyzedImages.isEmpty
                    ? '--'
                    : '${(measurement.averagePluckableRatio * 100).toStringAsFixed(1)}%',
              ),
              _SummaryStat(
                label: 'Captured area',
                value: measurement.analyzedImages.isEmpty
                    ? '--'
                    : '${measurement.totalCapturedArea.toStringAsFixed(1)} sq.m',
              ),
              _SummaryStat(
                label: 'Labor priority',
                value: measurement.laborPriorityLabel,
              ),
              _SummaryStat(
                label: 'Predicted yield',
                value: measurement.predictedYieldKg == null
                    ? 'Not predicted yet'
                    : '${measurement.predictedYieldKg!.toStringAsFixed(1)} kg',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard() {
    final varianceKg = _measurement.yieldVarianceKg;
    final variancePercent = _measurement.yieldVariancePercent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pre and post plucking comparison',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Compare predicted yield with actual harvested weight to detect quota dilution and over-plucking.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ComparisonMetric(
                  label: 'Predicted',
                  value: _measurement.predictedYieldKg == null
                      ? '--'
                      : '${_measurement.predictedYieldKg!.toStringAsFixed(1)} kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ComparisonMetric(
                  label: 'Actual',
                  value: _measurement.actualYieldKg == null
                      ? '--'
                      : '${_measurement.actualYieldKg!.toStringAsFixed(1)} kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ComparisonMetric(
                  label: 'Variance',
                  value: varianceKg == null
                      ? '--'
                      : '${varianceKg.toStringAsFixed(1)} kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _measurement.hasOverPluckingRisk
                  ? const Color(0xFFFCEAEA)
                  : const Color(0xFFF4F7F5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              variancePercent == null
                  ? 'Log the actual post-plucking weight to unlock over-plucking alerts and prediction accuracy review.'
                  : _measurement.hasOverPluckingRisk
                  ? 'Alert: actual yield is ${variancePercent.toStringAsFixed(1)}% above the prediction. Review coarse leaf mixing and picking discipline.'
                  : 'Variance is ${variancePercent.toStringAsFixed(1)}%. Harvest outcome is within an acceptable range.',
              style: TextStyle(
                color: _measurement.hasOverPluckingRisk
                    ? const Color(0xFFC04B4B)
                    : const Color(0xFF2E7655),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGalleryState extends StatelessWidget {
  final int minimumImages;

  const _EmptyGalleryState({required this.minimumImages});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EEEA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_photo_alternate_outlined, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'No images added yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Add at least $minimumImages images to unlock bud analysis, yield planning, and post-plucking verification.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _CountBox extends StatelessWidget {
  final String title;
  final String value;

  const _CountBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessTag extends StatelessWidget {
  final bool isReady;

  const _ReadinessTag({required this.isReady});

  @override
  Widget build(BuildContext context) {
    final background = isReady ? AppTheme.accentGreen : const Color(0xFFFBE7D9);
    final foreground = isReady
        ? AppTheme.accentGreenText
        : const Color(0xFFB0601B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isReady ? 'Ready to pluck' : 'Review maturity',
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RiskTag extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _RiskTag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _HeroMetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final InsightAlert alert;

  const _InsightTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = switch (alert.severity) {
      AlertSeverity.critical => const Color(0xFFC04B4B),
      AlertSeverity.warning => const Color(0xFFB97922),
      AlertSeverity.info => const Color(0xFF2E7655),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.tips_and_updates_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanningCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;

  const _PlanningCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EFEB),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Icon(icon, color: AppTheme.primaryDark),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...lines
              .where((line) => line.isNotEmpty)
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ComparisonMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ComparisonMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PendingImage {
  final String id;
  final String imagePath;
  final String sourceLabel;
  final DateTime capturedAt;

  const _PendingImage({
    required this.id,
    required this.imagePath,
    required this.sourceLabel,
    required this.capturedAt,
  });
}

class _GalleryItem {
  final AnalysisImageResult? analysis;
  final _PendingImage? pending;

  const _GalleryItem._({this.analysis, this.pending});

  factory _GalleryItem.analyzed(AnalysisImageResult analysis) =>
      _GalleryItem._(analysis: analysis);

  factory _GalleryItem.pending(_PendingImage pending) =>
      _GalleryItem._(pending: pending);

  String? get imagePath => analysis?.imagePath ?? pending?.imagePath;
}
