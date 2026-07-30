import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/environmental_data.dart';
import '../../models/field_model.dart';
import '../../services/disease_scan_service.dart';
import '../../theme.dart';
import '../../widgets/disease_scan_widgets.dart';
import 'disease_scan_result_screen.dart';

class ScanDiseaseScreen extends StatefulWidget {
  final String fieldId;
  final EnvironmentalData? environmentalData;

  const ScanDiseaseScreen({
    super.key,
    required this.fieldId,
    this.environmentalData,
  });

  @override
  State<ScanDiseaseScreen> createState() => _ScanDiseaseScreenState();
}

class _ScanDiseaseScreenState extends State<ScanDiseaseScreen> {
  static const int _maxImages = 5;
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  bool _isScanning = false;

  @override
  void dispose() {
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Image picking / capture
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    if (!mounted) return;
    if (_selectedImages.length >= _maxImages) {
      _showMaxImagesSnackbar();
      return;
    }

    try {
      // Pick multiple at once from gallery
      final remaining = _maxImages - _selectedImages.length;
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
        limit: remaining,
      );
      if (pickedFiles.isEmpty) return;

      for (final file in pickedFiles) {
        if (_selectedImages.length >= _maxImages) break;
        // Crop each picked image
        final cropped = await _cropImage(file);
        if (cropped != null && mounted) {
          setState(() {
            _selectedImages.add(cropped);
          });
        }
      }
    } catch (_) {
      // Fallback to single-pick if multi-pick isn't available
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      final cropped = await _cropImage(picked);
      if (cropped != null && mounted) {
        setState(() {
          _selectedImages.add(cropped);
        });
      }
    }
  }

  Future<void> _captureWithCamera() async {
    if (!mounted) return;
    if (_selectedImages.length >= _maxImages) {
      _showMaxImagesSnackbar();
      return;
    }

    // On web, camera permissions work differently
    if (!kIsWeb) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cameraStatus.isPermanentlyDenied
                  ? 'Camera permission is blocked. Enable it in app settings.'
                  : 'Camera permission is required to capture images.',
            ),
            action: cameraStatus.isPermanentlyDenied
                ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
                : null,
          ),
        );
        return;
      }
    }

    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    final XFile? croppedFile = await _cropImage(pickedFile);
    if (croppedFile == null) return;

    if (!mounted) return;
    setState(() {
      _selectedImages.add(croppedFile);
    });
  }

  Future<XFile?> _cropImage(XFile imageFile) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Leaf Image',
            toolbarColor: AppTheme.primaryButton,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.white,
            cropGridColor: AppTheme.brandGreen,
            cropFrameColor: AppTheme.brandGreen,
            activeControlsWidgetColor: AppTheme.brandGreen,
            showCropGrid: true,
            lockAspectRatio: true,
            hideBottomControls: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Crop Leaf Image',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
            resetButtonHidden: true,
          ),
          WebUiSettings(context: context),
        ],
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      );
      if (croppedFile == null) return null;
      return XFile(croppedFile.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cropping failed. Please try again.')),
        );
      }
      return null;
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _showMaxImagesSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum $_maxImages images allowed per scan.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Scanning
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _scanDisease() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or capture at least one leaf image.'),
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      // Build ScanImage list from all selected files
      final scanImages = <ScanImage>[];
      for (int i = 0; i < _selectedImages.length; i++) {
        final file = _selectedImages[i];
        final bytes = await file.readAsBytes();
        String name = file.name;
        if (name.isEmpty || !name.contains('.')) {
          name = 'leaf_image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        }

        scanImages.add(ScanImage(bytes: bytes, name: name));
      }

      // Call disease scan API with multiple images
      final response = await DiseaseScanService.scanDisease(
        images: scanImages,
        environmentalData:
            widget.environmentalData ??
            EnvironmentalData(date: DateTime.now(), time: DateTime.now()),
        fieldId: widget.fieldId,
      );

      if (!mounted) return;

      // Parse API response
      final scanResult = _parseApiResponse(response);

      setState(() {
        _isScanning = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiseaseScanResultScreen(
            fieldId: widget.fieldId,
            imagePaths: _selectedImages.map((f) => f.path).toList(),
            scanResult: scanResult,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scan failed: ${e.toString()}')));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Response parsing
  // ──────────────────────────────────────────────────────────────────────────

  /// Parses the disease-scan API response into a [DiseaseScanResult].
  ///
  /// New response structure (see `/api/v1/disease/scan`):
  /// {
  ///   "scan_id": "...",
  ///   "scan_summary": { "field_id", "field_name", "weather_details",
  ///                      "image_urls": [...], "scan_datetime", ... },
  ///   "most_probable_disease": { "disease_name", "confidence", "severity",
  ///                               "description", "causes": [...] },
  ///   "confidence_analysis": [ { "disease", "probability",
  ///                              "confidence_label", "category" }, ... ],
  ///   "recommendations": [ "...", "..."],
  ///   "explanation": { "per_image": [...], "aggregated_gradcam": "..." },
  ///   "environmental_summary": "...",
  ///   "environmental_insights": [ { "title", "message", "severity" }, ... ],
  ///   "environmental_technical_summary": { "top_risk_factors": [...], ... },
  ///   "classification": { "level", "label", "confidence", "category", "message" },
  ///   "processed_images": 2,
  ///   "meta": { "timestamp", ... }
  /// }
  DiseaseScanResult _parseApiResponse(Map<String, dynamic> response) {
    final scanId = response['scan_id'] as String?;
    final scanSummary = response['scan_summary'] as Map<String, dynamic>?;
    final weatherDetails =
        scanSummary?['weather_details'] as Map<String, dynamic>?;
    final mostProbableJson =
        response['most_probable_disease'] as Map<String, dynamic>?;
    final confidenceAnalysis =
        response['confidence_analysis'] as List<dynamic>? ?? [];
    final recommendations =
        (response['recommendations'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
    final classificationJson =
        response['classification'] as Map<String, dynamic>?;
    final meta = response['meta'] as Map<String, dynamic>?;

    // Image URLs from the scan summary (multiple images)
    final imageUrls =
        (scanSummary?['image_urls'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

    // Aggregated GradCAM image (single, across all images)
    final explanationJson = response['explanation'] as Map<String, dynamic>?;
    final aggregatedGradcam =
        explanationJson?['aggregated_gradcam'] as String?;

    // Environmental insights (plain-language, one per condition)
    final environmentalInsights =
        (response['environmental_insights'] as List<dynamic>? ?? [])
            .map((e) => EnvironmentalInsight.fromJson(e as Map<String, dynamic>))
            .toList();

    // Environmental technical summary
    final envTechJson = response['environmental_technical_summary']
        as Map<String, dynamic>?;
    final environmentalTechnicalSummary =
        envTechJson != null
            ? EnvironmentalTechnicalSummary.fromJson(envTechJson)
            : null;

    final environmentalSummary =
        response['environmental_summary'] as String?;
    final processedImages =
        (response['processed_images'] as num?)?.toInt() ?? _selectedImages.length;

    // Prefer scan_summary.scan_datetime, then meta.timestamp, then now.
    final timestampStr =
        scanSummary?['scan_datetime'] as String? ??
        meta?['timestamp'] as String?;
    DateTime detectedAt;
    try {
      detectedAt = DateTime.parse(
        timestampStr ?? DateTime.now().toIso8601String(),
      );
    } catch (_) {
      detectedAt = DateTime.now();
    }

    final diseaseResults = confidenceAnalysis.map((d) {
      final map = d as Map<String, dynamic>;
      return DiseaseResult(
        name: map['disease']?.toString() ?? 'Unknown',
        confidence: (((map['probability'] as num?)?.toDouble() ?? 0.0) * 100)
            .round(),
        confidenceLabel: map['confidence_label']?.toString() ?? '',
        category: map['category']?.toString() ?? '',
      );
    }).toList();

    return DiseaseScanResult(
      fieldId: widget.fieldId,
      imagePaths: _selectedImages.map((f) => f.path).toList(),
      detectedAt: detectedAt,
      scanId: scanId,
      fieldName: scanSummary?['field_name']?.toString(),
      remoteImageUrls: imageUrls,
      weather: weatherDetails != null
          ? DiseaseWeatherSnapshot(
              date: DateTime.now(),
              summary: _buildWeatherSummary(weatherDetails),
              humidity:
                  (weatherDetails['avg_humidity_last_7'] as num?)?.toInt() ??
                  78,
              temperatureC:
                  (weatherDetails['avg_temperature_last_7'] as num?)
                      ?.toDouble() ??
                  24.5,
              rainfallMm:
                  (weatherDetails['total_rainfall_last_7'] as num?)
                      ?.toDouble() ??
                  0.0,
              windSpeedKmh:
                  (weatherDetails['avg_wind_speed_last_7'] as num?)
                      ?.toDouble() ??
                  0.0,
              sunshineHours:
                  (weatherDetails['avg_sunshine_hours_last_7'] as num?)
                      ?.toDouble() ??
                  0.0,
            )
          : null,
      classification: classificationJson != null
          ? DiseaseClassification.fromJson(classificationJson)
          : null,
      mostProbableDisease: mostProbableJson != null
          ? MostProbableDisease.fromJson(mostProbableJson)
          : null,
      diseaseResults: diseaseResults.isNotEmpty
          ? diseaseResults
          : _getPlaceholderResults(),
      recommendations: recommendations,
      aggregatedGradcamUrl: aggregatedGradcam,
      environmentalInsights: environmentalInsights,
      environmentalTechnicalSummary: environmentalTechnicalSummary,
      environmentalSummary: environmentalSummary,
      processedImages: processedImages,
    );
  }

  List<DiseaseResult> _getPlaceholderResults() {
    return const [
      DiseaseResult(
        name: 'Healthy',
        confidence: 95,
        confidenceLabel: 'Very High',
        category: 'Healthy',
      ),
    ];
  }

  String _buildWeatherSummary(Map<String, dynamic> weather) {
    final conditions = <String>[];
    final sunshineHours = weather['avg_sunshine_hours_last_7'] as num?;
    if (sunshineHours != null && sunshineHours.toDouble() < 5) {
      conditions.add('cloudy');
    }
    final rainfall = weather['total_rainfall_last_7'] as num?;
    if (rainfall != null && rainfall.toDouble() > 10) {
      conditions.add('wet');
    }
    final humidity = weather['avg_humidity_last_7'] as num?;
    if (humidity != null && humidity.toDouble() > 80) {
      conditions.add('humid');
    }
    if (conditions.isEmpty) return 'Moderate conditions';
    return 'Conditions: ${conditions.join(', ')}';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final FieldManager manager = FieldManager();
    final Field? field =
        manager.fields.where((f) => f.id == widget.fieldId).toList().firstOrNull;
    final hasImages = _selectedImages.isNotEmpty;
    final canAddMore = _selectedImages.length < _maxImages;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Scan Disease',
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
            // Field info header
            if (field != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      field.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6E7E8B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Guidelines (shown when no images yet)
            if (!hasImages) ...[
              ScanGuidelinesCard(),
              const SizedBox(height: 24),
            ],

            // Image grid (shown when images are selected)
            if (hasImages) ...[
              _MultiImageGrid(
                images: _selectedImages,
                onRemove: _removeImage,
                isScanning: _isScanning,
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons row
            if (!_isScanning) ...[
              Row(
                children: [
                  // Camera button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canAddMore ? _captureWithCamera : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryButton,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        disabledBackgroundColor:
                            AppTheme.primaryButton.withValues(alpha: 0.4),
                      ),
                      icon: const Icon(Icons.camera_alt_outlined, size: 20),
                      label: Text(
                        hasImages ? 'Add Photo' : 'Capture',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Gallery button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canAddMore ? _pickFromGallery : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text(
                        'Gallery',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Image counter hint
            if (hasImages && !_isScanning) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '${_selectedImages.length} of $_maxImages images selected',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            // Scan button
            if (hasImages) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanDisease,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB54848),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isScanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.biotech_outlined, size: 20),
                  label: Text(
                    _isScanning
                        ? 'Analysing...'
                        : 'Scan ${_selectedImages.length} Image${_selectedImages.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            _buildWeatherDetails(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetails() {
    final hasEnvironmentalData = widget.environmentalData != null;
    final avgTemperature = hasEnvironmentalData
        ? widget.environmentalData!.avgTemperatureLast7
        : 24.5;
    final avgHumidity = hasEnvironmentalData
        ? widget.environmentalData!.avgHumidityLast7
        : 78;
    final totalRainfall = hasEnvironmentalData
        ? widget.environmentalData!.totalRainfallLast7
        : 0.0;
    final avgWindSpeed = hasEnvironmentalData
        ? widget.environmentalData!.avgWindSpeedLast7
        : 12.0;
    final avgSunshineHours = hasEnvironmentalData
        ? widget.environmentalData!.avgSunshineHoursLast7
        : 8.0;

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
              Icon(Icons.cloud_outlined, color: AppTheme.brandGreen, size: 20),
              SizedBox(width: 8),
              Text(
                '7-Day Environmental Data',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _WeatherMetric(
                  label: 'Avg Temperature (7d)',
                  value: '${avgTemperature.toStringAsFixed(1)}°C',
                  icon: Icons.thermostat_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WeatherMetric(
                  label: 'Avg Humidity (7d)',
                  value: '$avgHumidity%',
                  icon: Icons.water_drop_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WeatherMetric(
                  label: 'Total Rainfall (7d)',
                  value: '${totalRainfall.toStringAsFixed(1)} mm',
                  icon: Icons.grain_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WeatherMetric(
                  label: 'Avg Wind Speed (7d)',
                  value: '${avgWindSpeed.toStringAsFixed(1)} km/h',
                  icon: Icons.air_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WeatherMetric(
                  label: 'Avg Sunshine Hours (7d)',
                  value: '${avgSunshineHours.toStringAsFixed(1)} h',
                  icon: Icons.wb_sunny_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Multi-image grid widget
// ────────────────────────────────────────────────────────────────────────────

class _MultiImageGrid extends StatelessWidget {
  final List<XFile> images;
  final void Function(int index) onRemove;
  final bool isScanning;

  const _MultiImageGrid({
    required this.images,
    required this.onRemove,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_outlined,
                color: AppTheme.brandGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${images.length} Leaf Image${images.length > 1 ? 's' : ''} Selected',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _ImageThumbnail(
                  imagePath: images[index].path,
                  onRemove: isScanning ? null : () => onRemove(index),
                  index: index + 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onRemove;
  final int index;

  const _ImageThumbnail({
    required this.imagePath,
    required this.onRemove,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isRemoteOrWeb = kIsWeb ||
        imagePath.startsWith('http://') ||
        imagePath.startsWith('https://') ||
        imagePath.startsWith('blob:');

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: isRemoteOrWeb
              ? Image.network(
                  imagePath,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : Image.file(
                  File(imagePath),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                ),
        ),
        // Index badge
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        // Remove button
        if (onRemove != null)
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      width: 100,
      height: 100,
      color: const Color(0xFFF3F4F6),
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _WeatherMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF7ED321), size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
          const Spacer(),
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
