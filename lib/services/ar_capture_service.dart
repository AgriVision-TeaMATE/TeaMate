import 'package:flutter/services.dart';

import '../models/ar_area_capture_result.dart';

/// Values returned by [ArCaptureService.checkAvailability], mirroring ArAvailabilityHelper.kt.
class ArAvailability {
  static const supportedInstalled = 'SUPPORTED_INSTALLED';
  static const supportedApkTooOld = 'SUPPORTED_APK_TOO_OLD';
  static const supportedNotInstalled = 'SUPPORTED_NOT_INSTALLED';
  static const unsupported = 'UNSUPPORTED';
  static const unknownChecking = 'UNKNOWN_CHECKING';
}

/// App-level ARCore availability/install-flow channel - not tied to any particular capture view.
class ArCaptureService {
  static const MethodChannel _appChannel = MethodChannel('com.teamate/ar_capture');

  // Catches both PlatformException (native-side error) and MissingPluginException (no native
  // implementation registered - distinct, unrelated exception types in package:flutter/services)
  // so a broken/stale native side degrades to the manual-entry fallback instead of crashing.
  static Future<String> checkAvailability() async {
    try {
      final result = await _appChannel.invokeMethod<String>('checkAvailability');
      return result ?? ArAvailability.unknownChecking;
    } catch (_) {
      return ArAvailability.unsupported;
    }
  }

  /// Triggers the Play Store install/update flow for ARCore. Returns one of INSTALLED,
  /// INSTALL_REQUESTED, DECLINED, UNSUPPORTED, ERROR.
  static Future<String> requestInstall({bool userRequestedInstall = true}) async {
    try {
      final result = await _appChannel.invokeMethod<String>('requestInstall', {
        'userRequestedInstall': userRequestedInstall,
      });
      return result ?? 'ERROR';
    } catch (_) {
      return 'ERROR';
    }
  }
}

/// Per-view session bound to one AR capture AndroidView instance (its [viewId]). Created after
/// `onPlatformViewCreated` fires so the platform-side view/channels already exist.
class ArCaptureSession {
  final int viewId;
  late final MethodChannel _methodChannel;
  late final EventChannel _eventChannel;
  Stream<Map<dynamic, dynamic>>? _eventStream;

  ArCaptureSession(this.viewId) {
    _methodChannel = MethodChannel('com.teamate/ar_capture/$viewId');
    _eventChannel = EventChannel('com.teamate/ar_capture/$viewId/events');
  }

  /// Cheap state events only (tracking/planeFound/pointsChanged/error) - the point/line overlay
  /// itself is rendered natively, not streamed here.
  Stream<Map<dynamic, dynamic>> get events {
    return _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<dynamic, dynamic>.from(event as Map));
  }

  Future<int> undoLastPoint() async {
    final count = await _methodChannel.invokeMethod<int>('undoLastPoint');
    return count ?? 0;
  }

  Future<void> reset() => _methodChannel.invokeMethod('reset');

  Future<ArAreaCaptureResult> confirmCapture() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('confirmCapture');
    if (result == null) {
      throw StateError('AR capture confirm returned no result');
    }
    return ArAreaCaptureResult.fromChannelMap(result);
  }

  Future<void> cancel() => _methodChannel.invokeMethod('cancel');
}
