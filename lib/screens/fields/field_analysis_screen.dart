import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
import '../settings/settings_screen.dart';

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

class _FieldAnalysisScreenState extends State<FieldAnalysisScreen>
    with SingleTickerProviderStateMixin {
  static const int _minimumImages = 3;
  static const double _capturedAreaPerImageSqm = 8.0;

  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController(viewportFraction: 0.92);

  late Field _field;
  late FieldMeasurement _measurement;
  late String _measurementId;
  final List<_PendingImage> _pendingImages = [];

  int _currentIndex = 0;
  bool _isAnalyzing = false;
  bool _isBudScanAnimating = false;
  String? _analysisStatus;
  bool _didCleanupDraft = false;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    final manager = FieldManager();
    _measurementId = widget.measurementId;
    _field = manager.fields.firstWhere((field) => field.id == widget.fieldId);
    _measurement = _field.measurements.firstWhere(
      (measurement) => measurement.id == _measurementId,
      orElse: () => FieldMeasurement(
        id: _measurementId,
        date: DateTime.now(),
        analyzedImages: [],
        fieldArea: _field.areaHectares,
      ),
    );
    _measurement = manager.hydrateMeasurementSupportData(
      widget.fieldId,
      _measurement,
    );
    manager.saveMeasurement(widget.fieldId, _measurement);
  }

  @override
  void dispose() {
    _scanController.dispose();
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

    final imageBytes = await _readPickedImageBytes(pickedFile);
    if (imageBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to prepare the selected image for upload.'),
        ),
      );
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
        imageBytes: imageBytes,
        filename: _buildUploadFilename(
          source == ImageSource.camera ? 'camera' : 'upload',
          pickedFile.path,
        ),
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

    final imageBytes = await _readFileBytes(result.imagePath);
    if (imageBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to prepare the captured image for upload.'),
        ),
      );
      return;
    }

    _appendPendingImage(
      _PendingImage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imagePath: result.imagePath,
        imageBytes: imageBytes,
        filename: _buildUploadFilename('ar_capture', result.imagePath),
        sourceLabel: 'Camera',
        capturedAt: DateTime.now(),
        capturedArea: result.areaSqm,
        corners: result.cornersImagePx,
      ),
    );
  }

  Future<Uint8List?> _readPickedImageBytes(XFile pickedFile) async {
    try {
      return await pickedFile.readAsBytes();
    } catch (error) {
      debugPrint('Failed to read picked image bytes: $error');
      return null;
    }
  }

  Future<Uint8List?> _readFileBytes(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('Source image missing: $sourcePath');
        return null;
      }
      return await sourceFile.readAsBytes();
    } catch (error) {
      debugPrint('Failed to read source image bytes: $error');
      return null;
    }
  }

  String _buildUploadFilename(String sourcePrefix, String originalPath) {
    final extension = _safeImageExtension(originalPath);
    return '${sourcePrefix}_${DateTime.now().microsecondsSinceEpoch}$extension';
  }

  String _safeImageExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) {
      return '.jpg';
    }
    final extension = path.substring(dotIndex).toLowerCase();
    const allowed = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};
    return allowed.contains(extension) ? extension : '.jpg';
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
      _isBudScanAnimating = true;
      _analysisStatus = null;
    });
    _scanController.repeat();

    final pendingCopy = List<_PendingImage>.from(_pendingImages);
    final api = ApiService();

    final hasServerRound = await _ensureServerRoundForAnalysis(api);
    if (!mounted) {
      return;
    }
    if (!hasServerRound) {
      setState(() {
        _isAnalyzing = false;
        _isBudScanAnimating = false;
        _analysisStatus = null;
      });
      _scanController.stop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create harvest round.')),
      );
      return;
    }

    for (var index = 0; index < pendingCopy.length; index++) {
      setState(() {
        _analysisStatus =
            'Uploading image ${index + 1} of ${pendingCopy.length}...';
      });
      final uploaded = await api.uploadImageToRound(
        roundId: _measurementId,
        imagePathOrUrl: pendingCopy[index].imagePath,
        imageBytes: pendingCopy[index].imageBytes,
        filename: pendingCopy[index].filename,
        capturedArea: pendingCopy[index].capturedArea,
      );
      if (uploaded == null) {
        if (!mounted) return;
        setState(() {
          _isAnalyzing = false;
          _isBudScanAnimating = false;
          _analysisStatus = null;
        });
        _scanController.stop();
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

    final serverRound = await api.analyzeRound(_measurementId);
    if (serverRound == null) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _isBudScanAnimating = false;
        _analysisStatus = null;
      });
      _scanController.stop();
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
      _isBudScanAnimating = false;
      _analysisStatus = null;
    });
    _scanController.stop();
  }

  Future<bool> _ensureServerRoundForAnalysis(ApiService api) async {
    if (!_measurementId.startsWith('draft-')) {
      return true;
    }

    setState(() {
      _analysisStatus = 'Creating harvest round...';
    });

    final serverRound = await api.createDraftRound(widget.fieldId);
    if (serverRound == null) {
      return false;
    }

    final manager = FieldManager();
    final localDraftId = _measurementId;
    _measurementId = serverRound.id;
    _measurement = manager.hydrateMeasurementSupportData(
      widget.fieldId,
      serverRound,
    );
    manager.removeMeasurement(widget.fieldId, localDraftId);
    manager.saveMeasurement(widget.fieldId, _measurement);
    return true;
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
    final predictedRound = await api.predictRoundYield(_measurementId);
    if (!mounted) {
      return;
    }
    if (predictedRound == null) {
      final detail = api.lastPredictYieldErrorDetail;
      setState(() {
        _isAnalyzing = false;
        _analysisStatus = null;
      });
      if (detail != null && detail.contains('Yield settings are incomplete')) {
        await _showYieldSettingsRequiredDialog();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail ?? 'Yield prediction failed.')),
      );
      return;
    }

    final plan = await api.planRound(
      roundId: _measurementId,
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

  Future<void> _showYieldSettingsRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Yield Setup Required',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'TeaMate needs the tea variant, 100 pluckable bud weight, and 100 arimbu bud weight before it can predict yield.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
            SizedBox(
              width: 144,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(this.context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(
                        initialTabIndex: 1,
                        openYieldSettingsOnStart: true,
                      ),
                    ),
                  );
                },
                child: const Text('Open Settings'),
              ),
            ),
          ],
        );
      },
    );
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
    if (!_measurementId.startsWith('draft-')) {
      await ApiService().updateActualYield(_measurementId, result);
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _measurement.isCompleted
                ? 'Actual yield updated.'
                : 'Actual yield saved.',
          ),
        ),
      );
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
      _measurementId,
      _measurement.actualYieldKg!,
    );
    if (!mounted) {
      return;
    }
    final manager = FieldManager();
    await manager.syncFromServer();
    if (!mounted) {
      return;
    }
    final refreshedField = manager.fields.firstWhere(
      (field) => field.id == widget.fieldId,
      orElse: () => _field,
    );
    final refreshedMeasurement = refreshedField.measurements.firstWhere(
      (measurement) => measurement.id == _measurementId,
      orElse: () => _measurement.copyWith(isCompleted: true),
    );
    setState(() {
      _field = refreshedField;
      _measurement = refreshedMeasurement;
    });

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
    if (_measurement.isEmptyDraft) {
      if (_measurementId.startsWith('draft-')) {
        FieldManager().removeMeasurement(widget.fieldId, _measurementId);
      } else {
        FieldManager().deleteMeasurement(widget.fieldId, _measurementId);
      }
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

  PluckingSchedule? get _roundSchedule {
    for (final schedule in FieldManager().schedules) {
      if (schedule.harvestRoundId == _measurementId) {
        return schedule;
      }
    }
    return null;
  }

  List<Worker> _workersForSchedule(PluckingSchedule? schedule) {
    if (schedule == null) {
      return const [];
    }
    final ids = schedule.assignedWorkerIds.toSet();
    return FieldManager().workers
        .where((worker) => ids.contains(worker.id))
        .toList(growable: false);
  }

  Future<void> _scheduleCrewAndSendSms() async {
    if (_measurement.isCompleted || _measurement.predictedYieldKg == null) {
      return;
    }

    final api = ApiService();
    setState(() {
      _isAnalyzing = true;
      _analysisStatus = 'Preparing labour allocation...';
    });

    final plan = await api.planRound(
      roundId: _measurementId,
      kgPerWorkerPerDay: AppSettingsService().kgPerWorkerPerDay,
    );
    if (!mounted) {
      return;
    }
    if (plan == null) {
      final detail = api.lastPlanRoundErrorDetail;
      setState(() {
        _isAnalyzing = false;
        _analysisStatus = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail ?? 'Failed to create labour plan.')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = false;
      _analysisStatus = null;
    });

    final selectedWorkerIds = await _showLabourAllocationSheet(plan);
    if (!mounted || selectedWorkerIds == null) {
      return;
    }
    if (selectedWorkerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one labour.')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisStatus = 'Saving labour allocation...';
    });

    final existingSchedule = _roundSchedule;
    final schedule = existingSchedule == null
        ? await api.createSchedule(
            fieldId: widget.fieldId,
            roundId: _measurementId,
            scheduledDate: plan.scheduledDate,
            shiftStart: plan.laborPlan.shiftStart,
            shiftEnd: plan.shiftEnd,
            recommendedWorkers: plan.laborPlan.recommendedWorkers,
            assignedWorkerIds: selectedWorkerIds,
            notes: plan.weatherAction == null
                ? 'AI plucking schedule'
                : 'Weather: ${plan.weatherAction}',
          )
        : await api.updateScheduleWorkers(
            scheduleId: existingSchedule.id,
            assignedWorkerIds: selectedWorkerIds,
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
        const SnackBar(content: Text('Failed to save labour allocation.')),
      );
      return;
    }

    final smsSent = await api.sendScheduleSms(schedule.id);

    await FieldManager().syncFromServer();
    if (!mounted) {
      return;
    }

    final refreshedField = FieldManager().fields.firstWhere(
      (field) => field.id == widget.fieldId,
    );
    final refreshedMeasurement = refreshedField.measurements.firstWhere(
      (measurement) => measurement.id == _measurementId,
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
              ? 'Allocation saved and SMS sent to ${selectedWorkerIds.length} labourers.'
              : 'Allocation saved. SMS not sent.',
        ),
      ),
    );
  }

  Future<List<String>?> _showLabourAllocationSheet(RoundPlanResult plan) {
    final schedule = _roundSchedule;
    final selectedIds = <String>{...?schedule?.assignedWorkerIds};
    final workers = FieldManager().workers
        .where(
          (worker) =>
              worker.status == WorkerStatus.available ||
              worker.assignedFieldId == widget.fieldId ||
              selectedIds.contains(worker.id),
        )
        .toList(growable: false);

    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Allocate labour',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Suggested labour count: ${plan.laborPlan.recommendedWorkers}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (plan.weather != null || plan.weatherAction != null) ...[
                      const SizedBox(height: 12),
                      _WeatherSmsPreview(plan: plan, fieldName: _field.name),
                    ],
                    const SizedBox(height: 14),
                    if (workers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'No available labourers. Add labourers or mark them available from Settings.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: workers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final worker = workers[index];
                            final selected = selectedIds.contains(worker.id);
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (checked) {
                                setSheetState(() {
                                  if (checked == true) {
                                    selectedIds.add(worker.id);
                                  } else {
                                    selectedIds.remove(worker.id);
                                  }
                                });
                              },
                              title: Text(
                                worker.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(worker.phone),
                              activeColor: AppTheme.primaryButton,
                              checkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(
                                  color: Color(0xFFE8ECEF),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, selectedIds.toList()),
                        style: _primaryActionButtonStyle(),
                        child: Text(
                          selectedIds.isEmpty
                              ? 'Save Allocation'
                              : 'Save & Send SMS (${selectedIds.length})',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
              if (_measurement.analyzedImages.isNotEmpty &&
                  !_measurement.isCompleted) ...[
                _buildDecisionHero(),
              ],
              if (!_measurement.isCompleted) ...[
                _buildCapturePanel(),
                const SizedBox(height: 18),
              ] else
                const SizedBox(height: 4),
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
                if (_roundSchedule != null) ...[
                  _buildLabourAllocationCard(),
                  const SizedBox(height: 18),
                ],
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
                    label: Text(
                      _roundSchedule == null
                          ? 'Allocate Labour & Send SMS'
                          : 'Change Labour Allocation',
                    ),
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

  Widget _buildLabourAllocationCard() {
    final schedule = _roundSchedule;
    if (schedule == null) {
      return const SizedBox.shrink();
    }
    final workers = _workersForSchedule(schedule);
    final hasShortage = workers.length < schedule.recommendedWorkers;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryButton.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Allocated labour',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasShortage
                      ? const Color(0xFFFCEAEA)
                      : const Color(0xFFF4F7F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${workers.length}/${schedule.recommendedWorkers}',
                  style: TextStyle(
                    color: hasShortage
                        ? const Color(0xFFC04B4B)
                        : const Color(0xFF2E7655),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (workers.isEmpty)
            const Text(
              'No labourers allocated yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else
            ...workers.map(
              (worker) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryButton,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          worker.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            worker.phone,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_measurement.isCompleted) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _measurement.predictedYieldKg == null
                    ? null
                    : _scheduleCrewAndSendSms,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryButton,
                  side: const BorderSide(color: Color(0xFFE0E5E9)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Change allocation'),
              ),
            ),
          ],
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
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 2, 2, 10),
            child: Text(
              'Analyzed images',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
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
                    if (_isBudScanAnimating && item.pending != null)
                      _buildImageScanOverlay(),
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
    if (item.imageBytes != null) {
      return Image.memory(item.imageBytes!, fit: fit);
    }
    if (item.imagePath != null) {
      if (item.imagePath!.startsWith('data:image')) {
        try {
          final base64Data = item.imagePath!.split(',').last;
          return Image.memory(base64Decode(base64Data), fit: fit);
        } catch (_) {}
      }
      if (item.imagePath!.startsWith('http')) {
        return Image.network(
          item.imagePath!,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            final total = loadingProgress.expectedTotalBytes;
            return Container(
              decoration: const BoxDecoration(color: Color(0xFFE9EDF1)),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.brandGreen,
                  value: total != null
                      ? loadingProgress.cumulativeBytesLoaded / total
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, _, __) => _buildPlaceholderSurface(item),
        );
      }
      return Image.file(
        File(item.imagePath!),
        fit: fit,
        errorBuilder: (context, _, __) => _buildPlaceholderSurface(item),
      );
    }
    return _buildPlaceholderSurface(item);
  }

  Widget _buildImageScanOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _scanController,
          builder: (context, child) {
            final progress = _scanController.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black.withValues(alpha: 0.18)),
                Positioned(
                  left: 0,
                  right: 0,
                  top: -80 + (420 * progress),
                  child: Container(
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.brandGreen.withValues(alpha: 0.0),
                          AppTheme.brandGreen.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.55),
                          AppTheme.brandGreen.withValues(alpha: 0.18),
                          AppTheme.brandGreen.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.brandGreen.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                        transform: _SlidingGradientTransform(progress),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.48),
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.brandGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Scanning buds...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
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
                        color: AppTheme.textPrimary,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, Color(0xFF1E4A3D)],
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
          const SizedBox(height: 5),
          SizedBox(
            height: 20,
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
          const SizedBox(height: 2),
          SizedBox(
            height: 26,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  strutStyle: const StrutStyle(
                    forceStrutHeight: true,
                    height: 1.0,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    height: 1.0,
                  ),
                ),
              ),
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
        color: const Color(0xFFF4F7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF56616B),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, Color(0xFF1E4A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 4),
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

class _WeatherSmsPreview extends StatelessWidget {
  final RoundPlanResult plan;
  final String fieldName;

  const _WeatherSmsPreview({required this.plan, required this.fieldName});

  @override
  Widget build(BuildContext context) {
    final weather = plan.weather;
    final action = plan.weatherAction ?? 'Follow supervisor instructions.';
    final summary = weather?.summary ?? 'Weather update pending';
    final riskLabel = weather?.stormRisk == true
        ? 'High risk'
        : (weather?.rainChance ?? 0) >= 40
        ? 'Rain watch'
        : 'Good conditions';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E5E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  color: AppTheme.brandGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  riskLabel,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (weather != null)
                Text(
                  '${weather.rainChance}% rain',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$summary. $action',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'SMS preview',
            style: TextStyle(
              color: AppTheme.textPrimary.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'TeaMate: You are assigned to Field $fieldName today.\n'
            'Weather: $action\n'
            'Please report to the field supervisor.',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
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
  final Uint8List imageBytes;
  final String filename;
  final String sourceLabel;
  final DateTime capturedAt;
  final double capturedArea;
  // 4 corner points (image-space pixels) of the AR-measured quad. Null for gallery uploads,
  // which still use manual area entry - see AnalysisImageResult.capturedAreaCorners.
  final List<Offset>? corners;

  const _PendingImage({
    required this.id,
    required this.imagePath,
    required this.imageBytes,
    required this.filename,
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
  Uint8List? get imageBytes => pending?.imageBytes;
  double? get capturedArea => analysis?.capturedArea ?? pending?.capturedArea;
}

class _SlidingGradientTransform extends GradientTransform {
  final double progress;

  const _SlidingGradientTransform(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      0,
      bounds.height * (progress * 1.2 - 0.6),
      0,
    );
  }
}
