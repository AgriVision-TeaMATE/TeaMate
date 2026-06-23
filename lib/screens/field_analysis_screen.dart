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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 85);
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

    final analyzedImages = List<AnalysisImageResult>.from(_measurement.analyzedImages);
    final pendingCopy = List<_PendingImage>.from(_pendingImages);

    for (var index = 0; index < pendingCopy.length; index++) {
      setState(() {
        _analysisStatus = 'Analyzing image ${index + 1} of ${pendingCopy.length}';
      });
      await Future<void>.delayed(const Duration(milliseconds: 450));
      analyzedImages.add(_mockAnalyzeImage(pendingCopy[index], index + analyzedImages.length));
    }

    _measurement = _measurement.copyWith(
      analyzedImages: analyzedImages,
      date: DateTime.now(),
      clearPrediction: true,
    );
    FieldManager().saveMeasurement(widget.fieldId, _measurement);

    setState(() {
      _pendingImages.clear();
      _currentIndex = 0;
      _isAnalyzing = false;
      _analysisStatus = null;
    });
  }

  Future<void> _showPredictYieldSheet() async {
    final controller = TextEditingController(
      text: _measurement.fieldArea?.toStringAsFixed(1) ?? '',
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
                  'Enter the full field area. This UI uses a mock calculation for now.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Field area',
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
    setState(() {
      _measurement = _measurement.copyWith(
        fieldArea: result,
        predictedYieldKg: predictedYield,
      );
    });
    FieldManager().saveMeasurement(widget.fieldId, _measurement);
  }

  double _calculatePredictedYield(double fieldArea) {
    final summary = _measurement;
    final budStrength = (summary.totalPluckableCount * 0.42) +
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
                'Field bud analysis',
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showPredictYieldSheet,
                    icon: const Icon(Icons.insights_outlined),
                    label: Text(
                      _measurement.predictedYieldKg == null
                          ? 'Predict Yield'
                          : 'Update Yield Prediction',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
            'Capture or upload field images one by one from different positions across the field.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
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
                ? 'Ready to analyze. New uploads will be sent one by one to the analysis flow.'
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
              'Special notice: take more than 3 images from different areas of the field for the most accurate result.',
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
                            color: const Color(0xFF00B66D).withValues(alpha: 0.18),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.analysis == null ? 'Pending' : item.analysis!.sourceLabel,
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
          colors: [
            Color(0xFF789B79),
            Color(0xFF264535),
          ],
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add at least $minimumImages images to unlock bud analysis and summary results.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBox extends StatelessWidget {
  final String title;
  final String value;

  const _CountBox({
    required this.title,
    required this.value,
  });

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

  const _SummaryStat({
    required this.label,
    required this.value,
  });

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
    final foreground = isReady ? AppTheme.accentGreenText : const Color(0xFFB0601B);

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

  const _GalleryItem._({
    this.analysis,
    this.pending,
  });

  factory _GalleryItem.analyzed(AnalysisImageResult analysis) =>
      _GalleryItem._(analysis: analysis);

  factory _GalleryItem.pending(_PendingImage pending) =>
      _GalleryItem._(pending: pending);

  String? get imagePath => analysis?.imagePath ?? pending?.imagePath;
}
