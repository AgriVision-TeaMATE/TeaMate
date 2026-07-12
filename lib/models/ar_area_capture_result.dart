import 'dart:ui';

/// Result of a completed AR area-capture session: the perspective-cropped photo, the
/// AR-measured real-world area, and both the 3D world-space and 2D image-space corner
/// points (kept for traceability/audit - see AnalysisImageResult.capturedAreaCorners).
class ArAreaCaptureResult {
  final String imagePath;
  final double areaSqm;
  final List<Offset> cornersImagePx;
  final List<Offset> corners3d;
  final List<String> warnings;

  const ArAreaCaptureResult({
    required this.imagePath,
    required this.areaSqm,
    required this.cornersImagePx,
    required this.corners3d,
    required this.warnings,
  });

  factory ArAreaCaptureResult.fromChannelMap(Map<dynamic, dynamic> map) {
    final cornersPx = (map['cornersImagePx'] as List<dynamic>? ?? const [])
        .map((c) => Offset((c['x'] as num).toDouble(), (c['y'] as num).toDouble()))
        .toList();
    // 3D world points don't map onto a 2D Offset naturally; we only keep (x, z) - the
    // horizontal ground-plane plane axes for the common case of a horizontal sampling
    // plane - purely for lightweight audit display, not for further computation.
    final corners3d = (map['corners3d'] as List<dynamic>? ?? const [])
        .map((c) => Offset((c['x'] as num).toDouble(), (c['z'] as num).toDouble()))
        .toList();
    return ArAreaCaptureResult(
      imagePath: map['imagePath'] as String,
      areaSqm: (map['areaSqm'] as num).toDouble(),
      cornersImagePx: cornersPx,
      corners3d: corners3d,
      warnings: (map['warnings'] as List<dynamic>? ?? const []).map((w) => w.toString()).toList(),
    );
  }
}
