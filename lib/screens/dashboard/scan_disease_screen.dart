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
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isScanning = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!mounted) return;
    if (kIsWeb && source == ImageSource.camera) {
      // On web, camera may not work, use gallery instead
      source = ImageSource.gallery;
    }
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (pickedFile == null) {
      return;
    }

    // Crop the image to 1:1 aspect ratio
    final XFile? croppedFile = await _cropImage(pickedFile);
    if (croppedFile == null) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedImage = croppedFile;
    });
  }

  /// Crop image to 1:1 aspect ratio for optimal disease detection.
  /// Cropping is mandatory on every platform (including web) — if the user
  /// cancels the cropper, no image is set rather than falling back to the
  /// uncropped original.
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
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Leaf Image',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
            resetButtonHidden: true,
          ),
          WebUiSettings(
            context: context,
            // size: const CropperSize(width: 480, height: 480),
            // viewMode: WebViewMode.viewMode1,
            // dragMode: WebDragMode.crop,
            // cropBoxResizable: false,
            // cropBoxMovable: true,
          ),
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

  /// Camera-capture entry point for disease scanning
  Future<void> _captureWithCamera() async {
    // On web, camera permissions and image picking work differently
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
    if (pickedFile == null) {
      return;
    }

    // Crop the image to 1:1 aspect ratio
    final XFile? croppedFile = await _cropImage(pickedFile);
    if (croppedFile == null) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedImage = croppedFile;
    });
  }

  void _retakeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _proceedToScan() {
    _scanDisease();
  }

  Future<void> _scanDisease() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or capture an image first.')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      // Read image bytes
      final bytes = await _selectedImage!.readAsBytes();

      // Call disease scan API
      final response = await DiseaseScanService.scanDisease(
        imageBytes: bytes,
        fileName: _selectedImage!.name,
        environmentalData: widget.environmentalData ??
            EnvironmentalData(
              date: DateTime.now(),
              time: DateTime.now(),
            ),
        fieldId: widget.fieldId,
      );

      if (!mounted) return;

      // Parse API response into DiseaseScanResult
      final scanResult = _parseApiResponse(response);

      setState(() {
        _isScanning = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiseaseScanResultScreen(
            fieldId: widget.fieldId,
            imagePath: _selectedImage?.path,
            scanResult: scanResult,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: ${e.toString()}')),
      );
    }
  }

  DiseaseScanResult _parseApiResponse(Map<String, dynamic> response) {
    final scanId = response['scan_id'] as String?;
    final timestampStr = response['timestamp'] as String?;
    final confidenceAnalysis = response['confidence_analysis'] as List<dynamic>? ?? [];
    final riskData = response['risk_level'] as Map<String, dynamic>?;
    final scanSummary = response['scan_summary'] as Map<String, dynamic>?;
    final weatherDetails = scanSummary?['weather_details'] as Map<String, dynamic>?;

    // Parse timestamp from API or fall back to current time
    DateTime detectedAt;
    try {
      detectedAt = DateTime.parse(timestampStr ?? DateTime.now().toIso8601String());
    } catch (_) {
      detectedAt = DateTime.now();
    }

    // If no disease results from API, generate placeholder data
    final results = confidenceAnalysis.isNotEmpty
        ? confidenceAnalysis.map((d) => DiseaseResult(
            name: d['disease'] as String? ?? 'Unknown',
            confidence: (((d['probability'] as num?)?.toDouble() ?? 0.0) * 100).toInt(),
            description: d['confidence_label'] as String? ?? '',
            symptoms: d['symptoms'] as String? ?? '',
            treatment: d['treatment'] as String? ?? '',
          )).toList()
        : _getPlaceholderResults();

    return DiseaseScanResult(
      fieldId: widget.fieldId,
      imagePath: _selectedImage?.path,
      detectedAt: detectedAt,
      scanId: scanId,
      weather: weatherDetails != null
          ? WeatherSnapshot(
              date: DateTime.now(),
              summary: _buildWeatherSummary(weatherDetails),
              rainChance: (weatherDetails['rainy_hours_last_7'] as num?)?.toInt() ?? 42,
              humidity: (weatherDetails['avg_humidity_last_7'] as num?)?.toInt() ?? 78,
              temperatureC:
                  (weatherDetails['avg_temperature_last_7'] as num?)?.toDouble() ?? 24.5,
              stormRisk: ((weatherDetails['rainy_hours_last_7'] as num?)?.toInt() ?? 0) > 40,
            )
          : null,
      diseaseResults: results,
      riskLevel: riskData?['level'] as String? ?? '',
      riskReason: riskData?['reason'] as String? ?? '',
    );
  }

  List<DiseaseResult> _getPlaceholderResults() {
    return [
      DiseaseResult(
        name: 'Healthy',
        confidence: 95,
        description: 'The leaf appears healthy with no visible signs of disease or pest infection.',
        symptoms: '',
        treatment: '',
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

    if (conditions.isEmpty) {
      return 'Moderate conditions';
    }
    return 'Conditions: ${conditions.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final FieldManager manager = FieldManager();
    final Field? field = manager.fields
        .where((f) => f.id == widget.fieldId)
        .toList()
        .firstOrNull;

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

            // Show instruction screen or image preview
            if (_selectedImage == null) ...[
              // Instructions screen with guidelines displayed BEFORE opening camera
              ScanGuidelinesCard(),
              const SizedBox(height: 24),
              // Capture button - prominent, opens camera
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _captureWithCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryButton,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 22),
                  label: const Text(
                    'Capture',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Alternative: Upload from gallery
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isScanning ? null : () => _pickImage(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text(
                    'Upload from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else ...[
              // Image preview with retake/scan options using reusable widget
              DiseaseImagePreview(
                imagePath: _selectedImage?.path,
                onRetake: _retakeImage,
                onScan: _proceedToScan,
                isScanning: _isScanning,
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

    // Use environmental data values or defaults
    final avgTemperature = hasEnvironmentalData
        ? widget.environmentalData!.avgTemperatureLast7
        : 24.5;
    final avgHumidity =
        hasEnvironmentalData ? widget.environmentalData!.avgHumidityLast7 : 78;
    final totalRainfall =
        hasEnvironmentalData ? widget.environmentalData!.totalRainfallLast7 : 0.0;
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
              Icon(
                Icons.cloud_outlined,
                color: AppTheme.brandGreen,
                size: 20,
              ),
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
          Icon(
            icon,
            color: const Color(0xFF7ED321),
            size: 18,
          ),
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