import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/yield_settings_model.dart';
import 'api_service.dart';

class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal() {
    _load();
  }

  static const _kgPerWorkerKey = 'kg_per_worker_per_day';
  static const _defaultTeaVariant = 'TRI 2025';

  double _kgPerWorkerPerDay = 30;
  bool _loaded = false;
  bool _yieldSettingsLoaded = false;
  bool _yieldSettingsLoading = false;
  String _teaVariant = _defaultTeaVariant;
  double? _pluckable100BudWeightG;
  double? _arimbu100BudWeightG;

  double get kgPerWorkerPerDay => _kgPerWorkerPerDay;
  bool get loaded => _loaded;
  bool get yieldSettingsLoaded => _yieldSettingsLoaded;
  bool get yieldSettingsLoading => _yieldSettingsLoading;
  String get teaVariant => _teaVariant;
  double? get pluckable100BudWeightG => _pluckable100BudWeightG;
  double? get arimbu100BudWeightG => _arimbu100BudWeightG;
  bool get hasConfiguredYieldSettings =>
      _pluckable100BudWeightG != null && _arimbu100BudWeightG != null;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _kgPerWorkerPerDay = prefs.getDouble(_kgPerWorkerKey) ?? 30;
    _loaded = true;
    notifyListeners();
  }

  Future<void> loadYieldSettings({bool force = false}) async {
    if (_yieldSettingsLoading) {
      return;
    }
    if (_yieldSettingsLoaded && !force) {
      return;
    }

    _yieldSettingsLoading = true;
    notifyListeners();

    final settings = await ApiService().fetchYieldSettings();
    if (settings != null) {
      _applyYieldSettings(settings);
    }

    _yieldSettingsLoading = false;
    _yieldSettingsLoaded = true;
    notifyListeners();
  }

  Future<void> setKgPerWorkerPerDay(double value) async {
    _kgPerWorkerPerDay = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kgPerWorkerKey, value);
  }

  Future<bool> saveYieldSettings({
    required String teaVariant,
    required double pluckable100BudWeightG,
    required double arimbu100BudWeightG,
  }) async {
    final settings = await ApiService().updateYieldSettings(
      teaVariant: teaVariant,
      pluckable100BudWeightG: pluckable100BudWeightG,
      arimbu100BudWeightG: arimbu100BudWeightG,
    );
    if (settings == null) {
      return false;
    }

    _applyYieldSettings(settings);
    _yieldSettingsLoaded = true;
    notifyListeners();
    return true;
  }

  void _applyYieldSettings(YieldSettingsModel settings) {
    _teaVariant = settings.teaVariant;
    _pluckable100BudWeightG = settings.pluckable100BudWeightG;
    _arimbu100BudWeightG = settings.arimbu100BudWeightG;
  }
}
