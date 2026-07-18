import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/ar_area_capture_result.dart';
import '../../services/ar_capture_service.dart';
import '../../theme.dart';

/// Full-screen AR area-capture flow: hosts the native ARCore AndroidView (camera preview +
/// point/line overlay, all rendered natively - see ArCaptureView.kt) with Flutter chrome for
/// instructions, live status, and Undo/Reset/Confirm/Cancel controls on top.
///
/// Pushed from field_analysis_screen.dart's Camera capture path; pops an [ArAreaCaptureResult]
/// on success, or null if the user cancels/backs out.
class ArAreaCaptureScreen extends StatefulWidget {
  const ArAreaCaptureScreen({super.key});

  @override
  State<ArAreaCaptureScreen> createState() => _ArAreaCaptureScreenState();
}

class _ArAreaCaptureScreenState extends State<ArAreaCaptureScreen> {
  ArCaptureSession? _session;
  StreamSubscription<Map<dynamic, dynamic>>? _eventSub;

  int _pointCount = 0;
  double? _areaPreviewSqm;
  bool _trackingLost = false;
  bool _hasTrackedOnce = false;
  bool _isConfirming = false;
  String? _errorMessage;

  bool get _canConfirm => _pointCount >= 4 && !_trackingLost && !_isConfirming;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(fn);
    });
  }

  void _onPlatformViewCreated(int id) {
    final session = ArCaptureSession(id);
    _safeSetState(() => _session = session);
    _eventSub = session.events.listen(_handleEvent, onError: (_) {});
  }

  void _handleEvent(Map<dynamic, dynamic> event) {
    final type = event['type'] as String?;
    switch (type) {
      case 'pointsChanged':
        _safeSetState(() {
          _pointCount = (event['count'] as num?)?.toInt() ?? _pointCount;
          final area = event['areaPreviewSqm'] as num?;
          _areaPreviewSqm = area?.toDouble();
        });
        break;
      case 'tracking':
        _safeSetState(() {
          final state = event['state'] as String?;
          if (state == 'TRACKING') {
            _hasTrackedOnce = true;
            _trackingLost = false;
          } else {
            _trackingLost = _hasTrackedOnce;
          }
        });
        break;
      case 'error':
        _safeSetState(() => _errorMessage = event['message'] as String?);
        break;
    }
  }

  Future<void> _undo() async {
    final session = _session;
    if (session == null) return;
    final count = await session.undoLastPoint();
    setState(() {
      _pointCount = count;
      if (count < 3) _areaPreviewSqm = null;
    });
  }

  Future<void> _reset() async {
    final session = _session;
    if (session == null) return;
    await session.reset();
    setState(() {
      _pointCount = 0;
      _areaPreviewSqm = null;
    });
  }

  Future<void> _confirm() async {
    final session = _session;
    if (session == null || !_canConfirm) return;
    setState(() => _isConfirming = true);
    try {
      final result = await session.confirmCapture();
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConfirming = false;
        _errorMessage = 'Capture failed: $e';
      });
    }
  }

  Future<void> _cancel() async {
    unawaited(_session?.cancel());
    if (!mounted) return;
    Navigator.pop<ArAreaCaptureResult?>(context, null);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isConfirming,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_session?.cancel());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AndroidViewPlaceholderOrRealView(),
            _buildAndroidView(),
            _buildTopBar(),
            _buildInstructions(),
            if (_errorMessage != null) _buildErrorBanner(),
            _buildBottomControls(),
            if (_isConfirming) _buildConfirmingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidView() {
    return AndroidView(
      viewType: 'com.teamate/ar_capture_view',
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _isConfirming ? null : _cancel,
            ),
            const Spacer(),
            Chip(
              label: Text('$_pointCount / 4 points'),
              backgroundColor: Colors.black54,
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    final text = _trackingLost
        ? 'Tracking lost - point at a flat, textured surface and move slowly.'
        : !_hasTrackedOnce
        ? 'Scanning for a surface. Aim at the desk or floor, not the laptop screen.'
        : _pointCount == 0
        ? 'Move your phone slowly to find a surface, then tap the 4 corners of the sample area.'
        : _pointCount < 4
        ? 'Tap corner ${_pointCount + 1} of 4. Drag a placed point to adjust it.'
        : 'All 4 corners placed. Drag any point to fine-tune, or confirm.';

    return Positioned(
      top: 64,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _trackingLost
                ? Colors.red.withValues(alpha: 0.75)
                : Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Positioned(
      top: 120,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _errorMessage ?? '',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pointCount > 0 && !_isConfirming ? _undo : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Undo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pointCount > 0 && !_isConfirming ? _reset : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _canConfirm ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                  child: Text(
                    _areaPreviewSqm != null && _pointCount >= 4
                        ? 'Confirm (${_areaPreviewSqm!.toStringAsFixed(2)} m²)'
                        : 'Confirm',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Capturing and cropping...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder background shown behind the AndroidView while it initializes (avoids a flash of
/// the Scaffold's black background looking like a crash on slower devices).
class AndroidViewPlaceholderOrRealView extends StatelessWidget {
  const AndroidViewPlaceholderOrRealView({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}
