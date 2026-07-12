import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/field_model.dart';
import '../services/api_service.dart';
import '../services/app_settings_service.dart';
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
  bool _didShowEntryAlerts = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showEntryAlerts();
    });
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

    setState(() {
      _pendingImages.add(
        _PendingImage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          imagePath: pickedFile.path,
          sourceLabel: source == ImageSource.camera ? 'Camera' : 'Upload',
          capturedAt: DateTime.now(),
          capturedArea: capturedArea,
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

  Future<double?> _promptCapturedArea() async {
    final controller = TextEditingController(
      text: _capturedAreaPerImageSqm.toStringAsFixed(1),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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

  Future<void> _showEntryAlerts() async {
    if (_didShowEntryAlerts || !mounted) {
      return;
    }

    _didShowEntryAlerts = true;
    final alerts = FieldManager().buildInsightsForMeasurement(
      _field,
      _measurement,
    );

    for (final alert in alerts) {
      if (!mounted) {
        return;
      }
      await _showInsightDialog(alert);
    }
  }

  Future<void> _showInsightDialog(InsightAlert alert) {
    final (accent, background, icon) = switch (alert.severity) {
      AlertSeverity.critical => (
        const Color(0xFFBE4D4D),
        const Color(0xFFFFF2F2),
        Icons.warning_amber_rounded,
      ),
      AlertSeverity.warning => (
        const Color(0xFFAF7328),
        const Color(0xFFFFF6EA),
        Icons.tips_and_updates_outlined,
      ),
      AlertSeverity.info => (
        const Color(0xFF2E7655),
        const Color(0xFFF1F7F3),
        Icons.check_circle_outline_rounded,
      ),
    };

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    alert.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            alert.message,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
              fontSize: 15,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Dismiss'),
              ),
            ),
          ],
        );
      },
    );
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
        backgroundColor: const Color(0xFFF3F4F6),
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
              const SizedBox(height: 24),
              _buildCapturePanel(),
              const SizedBox(height: 18),
              if (_galleryItems.isEmpty) ...[
                _EmptyGalleryState(minimumImages: _minimumImages),
                const SizedBox(height: 18),
                _buildAnalyzeSection(),
              ] else ...[
                _buildImageCarousel(),
                const SizedBox(height: 16),
                if (_galleryItems.length > 1) _buildThumbnailRail(),
                const SizedBox(height: 16),
                _buildSelectedImageStats(selected),
                const SizedBox(height: 16),
                _buildAnalyzeSection(),
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
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _measurement.predictedYieldKg == null ||
                            _measurement.isCompleted
                        ? null
                        : _scheduleCrewAndSendSms,
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
    final weather = _measurement.weather;
    final predicted = _measurement.predictedYieldKg;
    final ratio = _measurement.analyzedImages.isEmpty
        ? '--'
        : '${(_measurement.averagePluckableRatio * 100).toStringAsFixed(1)}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE4E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7F8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7EAEE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: Color(0xFF7B8794),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_field.subtitle} in rotation',
                    style: const TextStyle(
                      color: Color(0xFF6E7E8B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Pre-plucking decision',
            style: const TextStyle(
              color: Color(0xFF7B8794),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _measurement.readinessLabel,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            weather == null
                ? 'Weather-based timing will appear after support data is prepared.'
                : '${weather.summary} • ${weather.temperatureC.toStringAsFixed(1)}°C • ${weather.rainChance}% rain chance',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
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
                  onPressed: _isAnalyzing || _measurement.isCompleted
                      ? null
                      : () => _pickImage(ImageSource.camera),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E7EB)),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canAnalyze ? _analyzeBuds : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F3F5),
                foregroundColor: AppTheme.textPrimary,
                disabledBackgroundColor: const Color(0xFFF1F3F5),
                disabledForegroundColor: const Color(0xFF9AA5B1),
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
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7F8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7EAEE)),
            ),
            child: Text(
              'Sampling note: use more than 3 images from separate rows or corners to stabilize the average maturity result.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
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
                color: Color(0xFF5F6C7B),
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
          );
        },
      ),
    );
  }

  Widget _buildImageSurface(_GalleryItem item) {
    if (item.imagePath != null) {
      if (item.imagePath!.startsWith('data:image')) {
        try {
          final base64Data = item.imagePath!.split(',').last;
          return Image.memory(base64Decode(base64Data), fit: BoxFit.cover);
        } catch (_) {}
      }
      if (item.imagePath!.startsWith('http')) {
        return Image.network(item.imagePath!, fit: BoxFit.cover);
      }
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
        style: ElevatedButton.styleFrom(
          backgroundColor: isCompleted
              ? const Color(0xFFE9EDF1)
              : AppTheme.textPrimary,
          foregroundColor: isCompleted ? const Color(0xFF5F6C7B) : Colors.white,
          disabledBackgroundColor: const Color(0xFFE9EDF1),
          disabledForegroundColor: const Color(0xFF5F6C7B),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
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
    final background = isReady
        ? const Color(0xFFF1F3F5)
        : const Color(0xFFF7EDE5);
    final foreground = isReady
        ? const Color(0xFF52606D)
        : const Color(0xFFB0601B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          letterSpacing: 0.2,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EAEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7B8794),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
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
  final double capturedArea;

  const _PendingImage({
    required this.id,
    required this.imagePath,
    required this.sourceLabel,
    required this.capturedAt,
    required this.capturedArea,
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
}
