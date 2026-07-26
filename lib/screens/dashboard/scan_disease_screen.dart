import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/environmental_data.dart';
import '../../models/field_model.dart';
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
  static const double _capturedAreaPerImageSqm = 8.0;

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

    final capturedArea = await _promptCapturedArea();
    if (capturedArea == null) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedImage = pickedFile;
    });
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

    final capturedArea = await _promptCapturedArea();
    if (capturedArea == null) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedImage = pickedFile;
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

    // Simulate API call delay
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isScanning = false;
    });

    if (!mounted) return;
    // Navigate to results screen after scan
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiseaseScanResultScreen(
          fieldId: widget.fieldId,
          imagePath: _selectedImage?.path,
        ),
      ),
    );
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
    // Dummy weather data (API not connected yet)
    const temperature = 24.5;
    const humidity = 78;
    const rainChance = 42;
    const windSpeed = 12.0;
    const weatherSummary = 'Partly cloudy';

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
                'Weather Details',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Current conditions for field scanning',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _WeatherMetric(
                  label: 'Temperature',
                  value: '${temperature.toStringAsFixed(1)}°C',
                  icon: Icons.thermostat_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WeatherMetric(
                  label: 'Humidity',
                  value: '$humidity%',
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
                  label: 'Rain chance',
                  value: '$rainChance%',
                  icon: Icons.grain_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WeatherMetric(
                  label: 'Wind speed',
                  value: '${windSpeed.toStringAsFixed(1)} km/h',
                  icon: Icons.air_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              weatherSummary,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
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