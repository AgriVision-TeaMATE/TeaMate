import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/ar_area_capture_result.dart';
import '../../models/field_model.dart';
import '../../services/api_service.dart';
import '../../services/app_settings_service.dart';
import '../../services/ar_capture_service.dart';
import '../../theme.dart';
import 'ar_area_capture_screen.dart';

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
  static const double _capturedAreaPerImageSqm = 8.0;

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
    if (_measurement.isCompleted) {
      return;
    }
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (pickedFile == null) {
      return;
    }

    final capturedArea = await _promptCapturedArea();
    if (capturedArea == null) {
      return;
    }

    _appendPendingImage(
      _PendingImage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imagePath: pickedFile.path,
        sourceLabel: source == ImageSource.camera ? 'Camera' : 'Upload',
        capturedAt: DateTime.now(),
        capturedArea: capturedArea,
      ),
    );
  }

  /// Camera-capture entry point: measures area via AR (see ArAreaCaptureScreen) instead of the
  /// manual dialog used by [_pickImage]'s Upload Image path. Falls back to the manual dialog
  /// only when the device has no ARCore support at all, so the Camera button stays usable.
  Future<void> _captureWithAr() async {
    if (_measurement.isCompleted) {
      return;
    }

    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cameraStatus.isPermanentlyDenied
                ? 'Camera permission is blocked. Enable it in Android app settings.'
                : 'Camera permission is required to use AR area capture.',
          ),
          action: cameraStatus.isPermanentlyDenied
              ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
              : null,
        ),
      );
      return;
    }

    final availability = await ArCaptureService.checkAvailability();

    if (availability == ArAvailability.unsupported) {
      await _pickImage(ImageSource.camera);
      return;
    }

    if (availability == ArAvailability.supportedNotInstalled ||
        availability == ArAvailability.supportedApkTooOld) {
      final installResult = await ArCaptureService.requestInstall();
      if (installResult != 'INSTALLED') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Install/update ARCore from the Play Store, then tap Camera again.',
            ),
          ),
        );
        return;
      }
    } else if (availability == ArAvailability.unknownChecking) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Still checking AR support - try again in a moment.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push<ArAreaCaptureResult?>(
      MaterialPageRoute(builder: (_) => const ArAreaCaptureScreen()),
    );
    if (result == null) {
      return;
    }

    _appendPendingImage(
      _PendingImage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imagePath: result.imagePath,
        sourceLabel: 'Camera',
        capturedAt: DateTime.now(),
        capturedArea: result.areaSqm,
        corners: result.cornersImagePx,
      ),
    );
  }

  void _appendPendingImage(_PendingImage image) {
    setState(() {
      _pendingImages.add(image);
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

  Future<double?> _promptCapturedArea() async {
    final controller = TextEditingController(
      text: _capturedAreaPerImageSqm.toStringAsFixed(1),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Captured area',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the sampled area covered by this image in square meters.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Area (sq.m)',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final area = double.tryParse(controller.text.trim());
                if (area == null || area <= 0) {
                  return;
                }
                Navigator.pop(context, area);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    return result;
  }

  Future<void> _analyzeBuds() async {
    if (_measurement.isCompleted || !_canAnalyze) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisStatus = null;
    });

    final pendingCopy = List<_PendingImage>.from(_pendingImages);
    final api = ApiService();

    for (var index = 0; index < pendingCopy.length; index++) {
      setState(() {
        _analysisStatus =
            'Uploading image ${index + 1} of ${pendingCopy.length}...';
      });
      final uploaded = await api.uploadImageToRound(
        roundId: widget.measurementId,
        imagePathOrUrl: pendingCopy[index].imagePath,
        capturedArea: pendingCopy[index].capturedArea,
      );
      if (uploaded == null) {
        if (!mounted) return;
        setState(() {
          _isAnalyzing = false;
          _analysisStatus = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image upload failed. Check backend connection.'),
          ),
        );
        return;
      }
    }

    setState(() {
      _analysisStatus = 'Analyzing uploaded images...';
    });

    final serverRound = await api.analyzeRound(widget.measurementId);
    if (serverRound == null) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisStatus = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bud analysis failed. Check backend and ML service.'),
        ),
      );
      return;
    }

    final manager = FieldManager();
    _measurement = manager.hydrateMeasurementSupportData(
      widget.fieldId,
      serverRound.copyWith(clearPrediction: true),
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
    if (_measurement.isCompleted) {
      return;
    }
    if (_measurement.analyzedImages.length < _minimumImages) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisStatus = 'Calculating predicted yield...';
    });

    final api = ApiService();
    final predictedRound = await api.predictRoundYield(widget.measurementId);
    if (!mounted) {
      return;
    }
    if (predictedRound == null) {
      setState(() {
        _isAnalyzing = false;
        _analysisStatus = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yield prediction failed.')));
      return;
    }

    final plan = await api.planRound(
      roundId: widget.measurementId,
      kgPerWorkerPerDay: AppSettingsService().kgPerWorkerPerDay,
    );
    final manager = FieldManager();
    var nextMeasurement = manager.hydrateMeasurementSupportData(
      widget.fieldId,
      predictedRound,
    );
    if (plan != null) {
      nextMeasurement = _mergeRoundPlan(nextMeasurement, plan);
    }
    setState(() {
      _measurement = nextMeasurement;
      _analysisStatus = null;
      _isAnalyzing = false;
    });
    manager.saveMeasurement(widget.fieldId, _measurement);
  }

  Future<bool> _showActualYieldSheet() async {
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
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
                      borderRadius: BorderRadius.circular(14),
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
      return false;
    }

    final manager = FieldManager();
    setState(() {
      _measurement = _measurement.copyWith(actualYieldKg: result);
    });
    manager.saveMeasurement(widget.fieldId, _measurement);
    if (_measurement.isCompleted) {
      await ApiService().updateActualYield(widget.measurementId, result);
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Actual yield updated.')));
    }
    return true;
  }

  Future<void> _completeRound() async {
    var hasYield = _measurement.hasActualYield;
    if (!hasYield) {
      hasYield = await _showActualYieldSheet();
    }
    if (!mounted || !hasYield) {
      return;
    }

    await ApiService().saveActualYield(
      widget.measurementId,
      _measurement.actualYieldKg!,
    );
    if (!mounted) {
      return;
    }
    final manager = FieldManager();
    _measurement = _measurement.copyWith(isCompleted: true);
    manager.saveMeasurement(widget.fieldId, _measurement);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plucking round completed and actual yield recorded.'),
      ),
    );
  }

  FieldMeasurement _mergeRoundPlan(
    FieldMeasurement baseMeasurement,
    RoundPlanResult plan,
  ) {
    final assignedWorkers = FieldManager()
        .workersForField(widget.fieldId)
        .length;
    final hasSchedule = FieldManager().schedules.any(
      (schedule) => schedule.harvestRoundId == plan.roundId,
    );
    return baseMeasurement.copyWith(
      weather: plan.weather,
      laborPlan: LaborPlan(
        availableWorkers: assignedWorkers,
        recommendedWorkers: plan.laborPlan.recommendedWorkers,
        shiftStart: _formatShiftTime(plan.laborPlan.shiftStart),
        smsScheduled: hasSchedule,
        focusZones: baseMeasurement.analyzedImages
            .take(3)
            .map((image) => image.sourceLabel)
            .toList(growable: false),
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

  String? get _selectedItemId => _selectedItem?.id;

  bool get _canAnalyze =>
      !_isAnalyzing &&
      !_measurement.isCompleted &&
      _pendingImages.isNotEmpty &&
      _galleryItems.length >= _minimumImages;

  bool get _canDeleteSelectedImage {
    final selected = _selectedItem;
    if (selected == null || _measurement.isCompleted || _isAnalyzing) {
      return false;
    }
    if (selected.pending != null) {
      return true;
    }
    final analysis = selected.analysis;
    return analysis != null &&
        analysis.arimbuCount == 0 &&
        analysis.pluckableCount == 0;
  }

  Future<void> _removeSelectedImage() async {
    final selected = _selectedItem;
    if (selected == null || !_canDeleteSelectedImage) {
      return;
    }

    if (selected.pending != null) {
      setState(() {
        _pendingImages.removeWhere((img) => img.id == selected.pending!.id);
        _currentIndex = _galleryItems.isEmpty
            ? 0
            : _currentIndex.clamp(0, _galleryItems.length - 1).toInt();
      });
      return;
    }

    final image = selected.analysis!;
    setState(() {
      _isAnalyzing = true;
      _analysisStatus = 'Removing uploaded image...';
    });

    final deleted = await ApiService().deleteAnalysisImage(image.id);
    if (!mounted) {
      return;
    }
    if (!deleted) {
      setState(() {
        _isAnalyzing = false;
        _analysisStatus = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete image.')));
      return;
    }

    final updatedImages = _measurement.analyzedImages
        .where((item) => item.id != image.id)
        .toList(growable: false);
    final manager = FieldManager();
    final updatedMeasurement = _measurement.copyWith(
      analyzedImages: updatedImages,
      clearPrediction: true,
    );
    manager.saveMeasurement(widget.fieldId, updatedMeasurement);

    setState(() {
      _measurement = updatedMeasurement;
      _isAnalyzing = false;
      _analysisStatus = null;
      _currentIndex = _galleryItems.isEmpty
          ? 0
          : _currentIndex.clamp(0, _galleryItems.length - 1).toInt();
    });
  }

  Future<void> _scheduleCrewAndSendSms() async {
    if (_measurement.isCompleted || _measurement.predictedYieldKg == null) {
      return;
    }

    final assignedWorkers = FieldManager().workersForField(widget.fieldId);
    if (assignedWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign workers to this field before scheduling SMS.'),
        ),
      );
      return;
    }

    final api = ApiService();
    setState(() {
      _isAnalyzing = true;
      _analysisStatus = 'Preparing labour plan...';
    });

    final plan = await api.planRound(
      roundId: widget.measurementId,
      kgPerWorkerPerDay: AppSettingsService().kgPerWorkerPerDay,
    );
    if (!mounted) {
      return;
    }
    if (plan == null) {
      setState(() {
        _isAnalyzing = false;
        _analysisStatus = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create labour plan.')),
      );
      return;
    }

    final workerIds = assignedWorkers
        .take(plan.laborPlan.recommendedWorkers)
        .map((worker) => worker.id)
        .toList();
    final schedule = await api.createSchedule(
      fieldId: widget.fieldId,
      roundId: widget.measurementId,
      scheduledDate: plan.scheduledDate,
      shiftStart: plan.laborPlan.shiftStart,
      shiftEnd: plan.shiftEnd,
      recommendedWorkers: plan.laborPlan.recommendedWorkers,
      assignedWorkerIds: workerIds,
      notes: plan.weather?.stormRisk == true
          ? 'Weather caution: ${plan.weather!.summary}'
          : 'AI plucking schedule',
    );
    if (!mounted) {
      return;
    }
    if (schedule == null) {
      setState(() {
        _isAnalyzing = false;
        _analysisStatus = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save plucking schedule.')),
      );
      return;
    }

    final smsSent = workerIds.isNotEmpty
        ? await api.sendScheduleSms(schedule.id)
        : false;

    await FieldManager().syncFromServer();
    if (!mounted) {
      return;
    }

    final refreshedField = FieldManager().fields.firstWhere(
      (field) => field.id == widget.fieldId,
    );
    final refreshedMeasurement = refreshedField.measurements.firstWhere(
      (measurement) => measurement.id == widget.measurementId,
      orElse: () => _measurement,
    );

    setState(() {
      _field = refreshedField;
      _measurement = _mergeRoundPlan(refreshedMeasurement, plan);
      _isAnalyzing = false;
      _analysisStatus = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          smsSent
              ? 'Schedule saved and SMS sent to ${workerIds.length} workers.'
              : 'Schedule saved. SMS not sent.',
        ),
      ),
    );
  }

  String _formatShiftTime(String raw) {
    final normalized = raw.trim();
    if (!normalized.contains(':')) {
      return normalized;
    }
    final parts = normalized.split(':');
    if (parts.length < 2) {
      return normalized;
    }
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
  }

  ButtonStyle _primaryActionButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primaryButton,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppTheme.primaryButton.withValues(alpha: 0.62),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  ButtonStyle _primaryOutlinedActionButtonStyle() {
    return OutlinedButton.styleFrom(
      backgroundColor: AppTheme.primaryButton,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppTheme.primaryButton.withValues(alpha: 0.62),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
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
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                _field.subtitle,
                style: TextStyle(
                  color: const Color(0xFF6E7E8B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDecisionHero(),
              if (!_measurement.isCompleted) ...[
                const SizedBox(height: 24),
                _buildCapturePanel(),
                const SizedBox(height: 18),
              ] else
                const SizedBox(height: 18),
              if (_galleryItems.isEmpty) ...[
                _EmptyGalleryState(minimumImages: _minimumImages),
                if (!_measurement.isCompleted) ...[
                  const SizedBox(height: 18),
                  _buildAnalyzeSection(),
                ],
              ] else ...[
                _buildImageReviewSection(selected),
                if (!_measurement.isCompleted) ...[
                  const SizedBox(height: 16),
                  _buildAnalyzeSection(),
                ],
                const SizedBox(height: 16),
                _buildSummaryCard(),
              ],
              if (_measurement.analyzedImages.length >= _minimumImages) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _measurement.isCompleted
                            ? null
                            : _showPredictYieldSheet,
                        style: _primaryActionButtonStyle(),
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
                        style: _primaryOutlinedActionButtonStyle(),
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
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _measurement.predictedYieldKg == null ||
                            _measurement.isCompleted
                        ? null
                        : _scheduleCrewAndSendSms,
                    style: _primaryOutlinedActionButtonStyle(),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Plan Labour & Send SMS'),
                  ),
                ),
                const SizedBox(height: 18),
                _buildCompleteRoundButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDecisionHero() {
    final predicted = _measurement.predictedYieldKg;
    final ratio = _measurement.analyzedImages.isEmpty
        ? '--'
        : '${(_measurement.averagePluckableRatio * 100).toStringAsFixed(1)}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_measurement.hasOverPluckingRisk) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: _RiskTag(
                label: 'Over-plucking risk',
                background: Color(0xFFFBE6E6),
                foreground: Color(0xFFC04B4B),
              ),
            ),
            const SizedBox(height: 10),
          ],
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
                child: _HeroMetricTile(label: 'Pluckable ratio', value: ratio),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapturePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
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
                  onPressed: _isAnalyzing || _measurement.isCompleted
                      ? null
                      : _captureWithAr,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.primaryButton,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primaryButton.withValues(
                      alpha: 0.62,
                    ),
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.72,
                    ),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing || _measurement.isCompleted
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.primaryButton,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primaryButton.withValues(
                      alpha: 0.62,
                    ),
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.72,
                    ),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canAnalyze ? _analyzeBuds : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryButton,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.primaryButton.withValues(
                  alpha: 0.62,
                ),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
          if (_analysisStatus != null) ...[
            const SizedBox(height: 12),
            Text(
              _analysisStatus!,
              style: const TextStyle(
                color: Color(0xFF5F6C7B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageReviewSection(_GalleryItem? selected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageCarousel(),
          const SizedBox(height: 12),
          if (_galleryItems.length > 1) ...[
            _buildThumbnailRail(),
            const SizedBox(height: 12),
          ],
          _buildSelectedImageStats(selected),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    return SizedBox(
      height: 340,
      child: PageView.builder(
        controller: _pageController,
        padEnds: false,
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
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: GestureDetector(
                onTap: () => _openFullScreenImage(index),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImageSurface(item),
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
                          borderRadius: BorderRadius.circular(14),
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
                    if (_selectedItemId == item.id && _canDeleteSelectedImage)
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _removeSelectedImage,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFullScreenImage(int initialIndex) {
    final items = List<_GalleryItem>.from(_galleryItems);
    final safeInitialIndex = initialIndex.clamp(0, items.length - 1).toInt();

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          final fullScreenController = PageController(
            initialPage: safeInitialIndex,
          );
          var fullScreenIndex = safeInitialIndex;

          return FadeTransition(
            opacity: animation,
            child: StatefulBuilder(
              builder: (context, setViewerState) {
                return Scaffold(
                  backgroundColor: Colors.black,
                  body: SafeArea(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: PageView.builder(
                            controller: fullScreenController,
                            itemCount: items.length,
                            onPageChanged: (index) {
                              setViewerState(() {
                                fullScreenIndex = index;
                              });
                              setState(() {
                                _currentIndex = index;
                              });
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return InteractiveViewer(
                                minScale: 1,
                                maxScale: 4,
                                child: Center(
                                  child: _buildImageSurface(
                                    item,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (items.length > 1)
                          Positioned(
                            left: 18,
                            bottom: 22,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${fullScreenIndex + 1}/${items.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 16,
                          top: 16,
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.14),
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: Colors.white,
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
        },
      ),
    );
  }

  Widget _buildImageSurface(_GalleryItem item, {BoxFit fit = BoxFit.cover}) {
    if (item.imagePath != null) {
      if (item.imagePath!.startsWith('data:image')) {
        try {
          final base64Data = item.imagePath!.split(',').last;
          return Image.memory(base64Decode(base64Data), fit: fit);
        } catch (_) {}
      }
      if (item.imagePath!.startsWith('http')) {
        return Image.network(item.imagePath!, fit: fit);
      }
      return Image.file(
        File(item.imagePath!),
        fit: fit,
        errorBuilder: (context, _, __) => _buildPlaceholderSurface(item),
      );
    }
    return _buildPlaceholderSurface(item);
  }

  Widget _buildPlaceholderSurface(_GalleryItem item) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFE9EDF1)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_outlined,
              size: 42,
              color: Color(0xFF7B8794),
            ),
            const SizedBox(height: 10),
            Text(
              item.analysis?.sourceLabel ?? item.pending!.sourceLabel,
              style: const TextStyle(
                color: AppTheme.textSecondary,
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
                borderRadius: BorderRadius.circular(14),
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
                borderRadius: BorderRadius.circular(14),
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
    final capturedArea = selected?.capturedArea;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selected image counts',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryButton,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_galleryItems.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CountBox(
                  title: 'Arimbu count',
                  value: analysis?.arimbuCount.toString() ?? '--',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CountBox(
                  title: 'Pluckable count',
                  value: analysis?.pluckableCount.toString() ?? '--',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CountBox(
                  title: 'Image area',
                  value: capturedArea == null
                      ? '--'
                      : '${capturedArea.toStringAsFixed(1)} sq.m',
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.primaryButton,
          image: DecorationImage(
            image: const AssetImage('assets/images/summary_card_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.58),
              BlendMode.darken,
            ),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 126),
                    child: Text(
                      'Average output summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryStatGrid(measurement),
                ],
              ),
            ),
            if (measurement.analyzedImages.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: _ReadinessTag(isReady: measurement.isReadyToPluck),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStatGrid(FieldMeasurement measurement) {
    final stats = [
      (label: 'Total Arimbu count', value: '${measurement.totalArimbuCount}'),
      (
        label: 'Total Pluckable count',
        value: '${measurement.totalPluckableCount}',
      ),
      (
        label: 'Avg pluckable ratio',
        value: measurement.analyzedImages.isEmpty
            ? '--'
            : '${(measurement.averagePluckableRatio * 100).toStringAsFixed(1)}%',
      ),
      (
        label: 'Captured area',
        value: measurement.analyzedImages.isEmpty
            ? '--'
            : '${measurement.totalCapturedArea.toStringAsFixed(1)} sq.m',
      ),
      (label: 'Labor priority', value: measurement.laborPriorityLabel),
      (
        label: 'Predicted yield',
        value: measurement.predictedYieldKg == null
            ? 'Not predicted yet'
            : '${measurement.predictedYieldKg!.toStringAsFixed(1)} kg',
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < stats.length; index += 2) ...[
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: stats[index].label,
                  value: stats[index].value,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStat(
                  label: stats[index + 1].label,
                  value: stats[index + 1].value,
                ),
              ),
            ],
          ),
          if (index < stats.length - 2) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildComparisonCard() {
    final varianceKg = _measurement.yieldVarianceKg;
    final variancePercent = _measurement.yieldVariancePercent;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pre and post plucking comparison',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Compare predicted yield with actual harvested weight to detect quota dilution and over-plucking.',
            style: TextStyle(
              color: Color(0xFF56616B),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
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
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _measurement.hasOverPluckingRisk
                    ? const Color(0xFFC04B4B)
                    : const Color(0xFF2E7655),
                width: 1.2,
              ),
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

  Widget _buildCompleteRoundButton() {
    final isCompleted = _measurement.isCompleted;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isCompleted ? null : _completeRound,
        icon: Icon(
          isCompleted
              ? Icons.check_circle_outline_rounded
              : Icons.task_alt_rounded,
        ),
        style: _primaryActionButtonStyle(),
        label: Text(
          isCompleted ? 'Round Completed' : 'Complete Round',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
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
        borderRadius: BorderRadius.circular(14),
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
      height: 84,
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
          SizedBox(
            height: 22,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w800,
                height: 1.18,
              ),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.brandGreen,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(14),
        ),
      ),
      child: Text(
        isReady ? 'Ready to pluck' : 'Review maturity',
        style: const TextStyle(
          color: Colors.white,
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
        borderRadius: BorderRadius.circular(14),
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
      height: 84,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A4A4A), Color(0xFF2F2F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
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
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.6,
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
      height: 78,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A4A4A), Color(0xFF2F2F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
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
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              height: 1.16,
            ),
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
  final double capturedArea;
  // 4 corner points (image-space pixels) of the AR-measured quad. Null for gallery uploads,
  // which still use manual area entry - see AnalysisImageResult.capturedAreaCorners.
  final List<Offset>? corners;

  const _PendingImage({
    required this.id,
    required this.imagePath,
    required this.sourceLabel,
    required this.capturedAt,
    required this.capturedArea,
    this.corners,
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

  String get id => analysis?.id ?? pending!.id;
  String? get imagePath => analysis?.imagePath ?? pending?.imagePath;
  double? get capturedArea => analysis?.capturedArea ?? pending?.capturedArea;
}
