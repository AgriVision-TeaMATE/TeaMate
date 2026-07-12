import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal() {
    _load();
  }

  static const _kgPerWorkerKey = 'kg_per_worker_per_day';

  double _kgPerWorkerPerDay = 30;
  bool _loaded = false;

  double get kgPerWorkerPerDay => _kgPerWorkerPerDay;
  bool get loaded => _loaded;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _kgPerWorkerPerDay = prefs.getDouble(_kgPerWorkerKey) ?? 30;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setKgPerWorkerPerDay(double value) async {
    _kgPerWorkerPerDay = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kgPerWorkerKey, value);
  }
}
