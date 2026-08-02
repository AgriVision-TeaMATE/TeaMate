import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../theme.dart';

/// Helper service to safely handle Android/iOS/Web image picking,
/// caching, UCrop cropping, and activity lifecycle recovery.
class ImagePickerHelper {
  /// Safely copies an [XFile] (which may originate from Android DocumentsUI
  /// content URIs or temporary picker cursors) into the app's local cache.
  /// This prevents `StaleDataException: Attempted to access a cursor after it has been closed`
  /// when passing the file to native activities like UCrop.
  static Future<XFile?> prepareLocalImageFile(XFile? file) async {
    if (file == null) return null;

    if (kIsWeb) {
      return file; // On Web, blob URIs are handled directly in memory
    }

    try {
      // Read bytes from the picked XFile stream/URI
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      final tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().microsecondsSinceEpoch.toString();
      final String filename = 'picker_cache_$timestamp.jpg';
      final File localFile = File('${tempDir.path}/$filename');

      await localFile.writeAsBytes(bytes, flush: true);
      return XFile(localFile.path);
    } catch (e) {
      debugPrint('ImagePickerHelper prepareLocalImageFile error: $e');
      // Return original file as fallback if local write fails
      return file;
    }
  }

  /// Safe standardized Leaf Image Cropping function.
  /// Converts the file to a local cache copy first, then launches ImageCropper.
  static Future<XFile?> cropLeafImage({
    required XFile imageFile,
    required BuildContext context,
    String title = 'Crop Leaf Image',
  }) async {
    try {
      // Capture web settings before any async gap to avoid
      // use_build_context_synchronously lint.
      final webUiSettings = WebUiSettings(context: context);

      // Step 1: Prepare local file to avoid closed cursor / StaleDataException
      final XFile? safeFile = await prepareLocalImageFile(imageFile);
      final String sourcePath = safeFile?.path ?? imageFile.path;

      // Step 2: Invoke ImageCropper safely
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title,
            toolbarColor: AppTheme.primaryButton,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.white,
            cropGridColor: AppTheme.brandGreen,
            cropFrameColor: AppTheme.brandGreen,
            activeControlsWidgetColor: AppTheme.brandGreen,
            showCropGrid: true,
            lockAspectRatio: true,
            hideBottomControls: true,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: title,
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
            resetButtonHidden: true,
          ),
          webUiSettings,
        ],
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      );

      if (croppedFile == null) return null;
      return XFile(croppedFile.path);
    } catch (e) {
      debugPrint('ImagePickerHelper cropLeafImage error: $e');
      return null;
    }
  }

  /// Recovers picked images lost if Android destroyed the activity
  /// while camera/gallery was active under low memory conditions.
  static Future<List<XFile>> retrieveLostData(ImagePicker picker) async {
    if (kIsWeb || !Platform.isAndroid) return [];

    try {
      final LostDataResponse response = await picker.retrieveLostData();
      if (response.isEmpty) return [];

      final List<XFile> recovered = [];
      if (response.files != null && response.files!.isNotEmpty) {
        for (final f in response.files!) {
          final prepared = await prepareLocalImageFile(f);
          if (prepared != null) recovered.add(prepared);
        }
      } else if (response.file != null) {
        final prepared = await prepareLocalImageFile(response.file);
        if (prepared != null) recovered.add(prepared);
      }
      return recovered;
    } catch (e) {
      debugPrint('ImagePickerHelper retrieveLostData error: $e');
      return [];
    }
  }
}
