import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/tea_grade_service.dart';

/// One grade's share of a scanned tea sample.
class GradeComposition {
  final String grade;
  final double percentage;

  GradeComposition({required this.grade, required this.percentage});

  factory GradeComposition.fromJson(Map<String, dynamic> json) {
    return GradeComposition(
      grade: json['grade']?.toString() ?? 'Unknown',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A tea quality scan result. All three backend endpoints return this exact
/// shape (`TeaGradeScanResponse`), so one model covers submit, list and detail.
class TeaQualityScan {
  final String id;
  final String scanId;
  final String? fieldId;
  final String? fieldName;
  final String imageUrl; // relative, e.g. /media/tea-quality-scans/<uuid>.png
  final DateTime scanDatetime;
  final List<GradeComposition> gradeComposition; // sorted desc by percentage
  final String dominantGrade;
  final double dominantGradePercentage;
  final int? totalParticlesDetected; // null until the real model is wired in
  final String? modelVersion;
  final double? inferenceTimeMs;
  final bool isMock;

  TeaQualityScan({
    required this.id,
    required this.scanId,
    this.fieldId,
    this.fieldName,
    required this.imageUrl,
    required this.scanDatetime,
    required this.gradeComposition,
    required this.dominantGrade,
    required this.dominantGradePercentage,
    this.totalParticlesDetected,
    this.modelVersion,
    this.inferenceTimeMs,
    this.isMock = false,
  });

  /// Absolute URL for the stored sample image, or null for mock scans.
  String? get resolvedImageUrl {
    if (imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${TeaGradeService.origin}$imageUrl';
  }

  factory TeaQualityScan.fromJson(
    Map<String, dynamic> json, {
    bool isMock = false,
  }) {
    final rawComposition = json['grade_composition'];
    final composition = <GradeComposition>[];
    if (rawComposition is List) {
      for (final entry in rawComposition) {
        if (entry is Map<String, dynamic>) {
          composition.add(GradeComposition.fromJson(entry));
        }
      }
    }
    composition.sort((a, b) => b.percentage.compareTo(a.percentage));

    return TeaQualityScan(
      id: json['id']?.toString() ?? '',
      scanId: json['scan_id']?.toString() ?? '',
      fieldId: json['field_id']?.toString(),
      fieldName: json['field_name']?.toString(),
      imageUrl: json['image_url']?.toString() ?? '',
      scanDatetime:
          DateTime.tryParse(json['scan_datetime']?.toString() ?? '') ??
              DateTime.now(),
      gradeComposition: composition,
      dominantGrade: json['dominant_grade']?.toString() ??
          (composition.isNotEmpty ? composition.first.grade : 'Unknown'),
      dominantGradePercentage:
          (json['dominant_grade_percentage'] as num?)?.toDouble() ??
              (composition.isNotEmpty ? composition.first.percentage : 0),
      totalParticlesDetected: (json['total_particles_detected'] as num?)?.toInt(),
      modelVersion: json['model_version']?.toString(),
      inferenceTimeMs: (json['inference_time_ms'] as num?)?.toDouble(),
      isMock: isMock,
    );
  }
}

/// Display colors for the seven research grades, with a neutral fallback so
/// the UI keeps working if the ML model's grade list evolves.
class TeaGradePalette {
  TeaGradePalette._();

  static const Map<String, Color> _colors = {
    'OP': Color(0xFF2E7D32),
    'OPA': Color(0xFF558B2F),
    'PEKOE': Color(0xFF00695C),
    'BOP': Color(0xFFEF6C00),
    'BOP1': Color(0xFFBF360C),
    'BOPF': Color(0xFF6D4C41),
    'Dust No.1': Color(0xFF546E7A),
  };

  static Color colorFor(String grade) =>
      _colors[grade] ?? const Color(0xFF7A8794);
}

/// Shared store for tea quality scans, mirroring the FieldManager pattern.
class TeaGradeManager extends ChangeNotifier {
  static final TeaGradeManager _instance = TeaGradeManager._internal();
  factory TeaGradeManager() => _instance;
  TeaGradeManager._internal();

  List<TeaQualityScan> scans = [];
  bool isLoading = false;
  bool usingMockData = false;

  Future<TeaQualityScan?> submitImage(XFile image, {String? fieldId}) async {
    final scan = await TeaGradeService().submitScan(image, fieldId: fieldId);
    if (scan != null) {
      scans.insert(0, scan);
      usingMockData = scan.isMock;
      notifyListeners();
    }
    return scan;
  }

  Future<void> refreshHistory() async {
    isLoading = true;
    notifyListeners();

    final fetched = await TeaGradeService().fetchScans();
    scans = fetched;
    usingMockData = fetched.any((scan) => scan.isMock);
    isLoading = false;
    notifyListeners();
  }

  Future<TeaQualityScan?> loadDetail(String scanId) async {
    for (final scan in scans) {
      if (scan.scanId == scanId) return scan;
    }
    return TeaGradeService().fetchScan(scanId);
  }

  void clear() {
    scans = [];
    usingMockData = false;
    isLoading = false;
    notifyListeners();
  }
}
