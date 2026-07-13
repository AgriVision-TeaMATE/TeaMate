import 'dart:io';

import 'package:flutter/foundation.dart';

class NetworkConfig {
  static const String _apiHostOverride = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get host {
    if (_apiHostOverride.isNotEmpty) {
      return _apiHostOverride;
    }

    if (kIsWeb) {
      return 'localhost';
    }

    if (Platform.isAndroid) {
      return '10.0.2.2';
    }

    return 'localhost';
  }

  static String apiBaseUrl({int port = 8001}) => 'http://$host:$port/api/v1';

  static String authBaseUrl({int port = 8001}) =>
      'http://$host:$port/api/v1/auth';

  static String modelBaseUrl({int port = 8000}) => 'http://$host:$port';
}
