import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme.dart';

/// Reusable card displaying capture guidelines for disease scanning
/// Shows instructions before the user opens the camera
class ScanGuidelinesCard extends StatelessWidget {
  const ScanGuidelinesCard({super.key});

  @override
  Widget build(BuildContext context) {
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
                Icons.info_outline_rounded,
                color: AppTheme.brandGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Capture Guidelines',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GuidelineItem(
            icon: Icons.photo_library_outlined,
            text: 'Capture only a single leaf',
          ),
          GuidelineItem(
            icon: Icons.straighten_outlined,
            text: 'Maintain a distance of 10–15 cm',
          ),
          GuidelineItem(
            icon: Icons.blur_off_outlined,
            text: 'Avoid blurry images and heavy shadows',
          ),
          GuidelineItem(
            icon: Icons.wb_sunny_outlined,
            text: 'Use natural lighting',
          ),
          GuidelineItem(
            icon: Icons.visibility_outlined,
            text: 'Ensure the diseased region is clearly visible',
          ),
          GuidelineItem(
            icon: Icons.flip_camera_android_outlined,
            text: 'Capture the upper side of the leaf',
          ),
        ],
      ),
    );
  }
}

/// Reusable guideline item with icon and text
/// Can be used in other screens that need guideline displays
class GuidelineItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const GuidelineItem({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.brandGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable image preview card for captured/selected images
/// Shows preview after image capture with Retake and Scan options
class DiseaseImagePreview extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onRetake;
  final VoidCallback onScan;
  final bool isScanning;

  const DiseaseImagePreview({
    super.key,
    required this.imagePath,
    required this.onRetake,
    required this.onScan,
    this.isScanning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              'Selected image',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
          DiseaseImageDisplay(
            imagePath: imagePath,
            height: 200,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isScanning ? null : onRetake,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryButton,
                      side: const BorderSide(color: AppTheme.primaryButton),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isScanning ? null : onScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB54848),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Scan'),
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

/// Reusable image display widget with error handling
class DiseaseImageDisplay extends StatelessWidget {
  final String? imagePath;
  final double height;

  const DiseaseImageDisplay({
    super.key,
    required this.imagePath,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath == null) {
      return Container(
        height: height,
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    // On web, image_picker returns a blob: object URL (not a real file path),
    // and Image.file is unsupported on web entirely — so route web + any
    // http(s)/blob URL through Image.network.
    final isRemoteOrWeb = kIsWeb ||
        imagePath!.startsWith('http://') ||
        imagePath!.startsWith('https://') ||
        imagePath!.startsWith('blob:');

    if (isRemoteOrWeb) {
      return Image.network(
        imagePath!,
        fit: BoxFit.cover,
        height: height,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder(height);
        },
      );
    }

    // For local file paths (from image picker/cropper) on native platforms
    return Image.file(
      File(imagePath!),
      fit: BoxFit.cover,
      height: height,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorPlaceholder(height);
      },
    );
  }

  Widget _buildErrorPlaceholder(double height) {
    return Container(
      height: height,
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 48,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}