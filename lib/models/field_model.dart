import 'package:flutter/foundation.dart';

class Measurement {
  final DateTime date;
  final int arimbuCount;
  final int pluckableCount;
  
  Measurement({
    required this.date,
    required this.arimbuCount,
    required this.pluckableCount,
  });

  double get ratio => (arimbuCount + pluckableCount) == 0 
      ? 0.0 
      : pluckableCount / (arimbuCount + pluckableCount);

  // Mock data calculations for display
  double get estimatedYield => (pluckableCount * 0.15); // mock 150g per bud cluster
  int get healthScore => 100 - (arimbuCount > pluckableCount ? 20 : 5); // mock health logic
}

class Field {
  final String id;
  String name;
  List<Measurement> measurements;

  Field({
    required this.id,
    required this.name,
    List<Measurement>? measurements,
  }) : measurements = measurements ?? [];

  bool get isReadyToPluck {
    if (measurements.isEmpty) return false;
    // User requested ratio between 60-70% or greater to be ready
    return measurements.last.ratio >= 0.60; 
  }
}

// Simple in-memory manager
class FieldManager extends ChangeNotifier {
  static final FieldManager _instance = FieldManager._internal();
  factory FieldManager() => _instance;
  FieldManager._internal();

  final List<Field> _fields = [
    // Add some mock data to start with
    Field(
      id: '1', 
      name: 'Block A-12',
      measurements: [
        Measurement(date: DateTime.now().subtract(const Duration(days: 7)), arimbuCount: 50, pluckableCount: 20),
        Measurement(date: DateTime.now(), arimbuCount: 30, pluckableCount: 80),
      ]
    ),
    Field(
      id: '2', 
      name: 'North Sector 4',
      measurements: []
    ),
  ];

  List<Field> get fields => _fields;

  void addField(String name) {
    _fields.add(Field(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    ));
    notifyListeners();
  }

  void addMeasurement(String fieldId, Measurement measurement) {
    final field = _fields.firstWhere((f) => f.id == fieldId);
    field.measurements.add(measurement);
    notifyListeners();
  }
}
