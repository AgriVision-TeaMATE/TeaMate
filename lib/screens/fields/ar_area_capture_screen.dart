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
    setState(fn);
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
            _buildLiveStatus(),
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
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GlassIconButton(
                icon: Icons.close_rounded,
                onPressed: _isConfirming ? null : _cancel,
              ),
              const Spacer(),
              _StatusPill(
                icon: Icons.timeline_rounded,
                label: '$_pointCount / 4 points',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    final text = _trackingLost
        ? 'Tracking lost. Point at a flat, textured surface and move slowly.'
        : !_hasTrackedOnce
        ? 'Scanning for a surface. Aim at the floor or table, not reflective objects.'
        : _pointCount == 0
        ? 'Move your phone slowly, then tap the 4 sample corners.'
        : _pointCount < 4
        ? 'Tap corner ${_pointCount + 1} of 4. Drag any placed point to adjust it.'
        : 'All 4 corners placed. Fine-tune the points, then confirm.';
    final icon = _trackingLost
        ? Icons.warning_amber_rounded
        : !_hasTrackedOnce
        ? Icons.radar_rounded
        : _pointCount < 4
        ? Icons.touch_app_rounded
        : Icons.check_circle_outline_rounded;

    return Positioned(
      top: 72,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _trackingLost
                ? Colors.red.withValues(alpha: 0.78)
                : const Color(0xCC111315),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.35,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Positioned(
      top: 148,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _errorMessage ?? '',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatus() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 112,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_areaPreviewSqm != null && _pointCount >= 3)
              _StatusPill(
                icon: Icons.square_foot_rounded,
                label: '${_areaPreviewSqm!.toStringAsFixed(2)} m²',
                accent: AppTheme.brandGreen,
              )
            else
              _StatusHint(
                label: _hasTrackedOnce
                    ? 'Place 3 points to preview area'
                    : 'Scan a flat surface first',
              ),
            const Spacer(),
            if (_pointCount > 0)
              _StatusHint(
                label: _pointCount < 4
                    ? 'Next: corner ${_pointCount + 1}'
                    : 'Drag points to refine',
              ),
          ],
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: _GhostActionButton(
                  onPressed: _pointCount > 0 && !_isConfirming ? _undo : null,
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GhostActionButton(
                  onPressed: _pointCount > 0 && !_isConfirming ? _reset : null,
                  icon: Icons.restart_alt_rounded,
                  label: 'Reset',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _PrimaryActionButton(
                  onPressed: _canConfirm ? _confirm : null,
                  label: _areaPreviewSqm != null && _pointCount >= 4
                      ? 'Confirm (${_areaPreviewSqm!.toStringAsFixed(2)} m²)'
                      : 'Confirm',
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

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _GlassIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xA6111315),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _StatusPill({required this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xB2111315),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHint extends StatelessWidget {
  final String label;

  const _StatusHint({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x8F111315),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GhostActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  const _GhostActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        backgroundColor: Colors.black.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const _PrimaryActionButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black.withValues(alpha: 0.28),
        disabledForegroundColor: Colors.white54,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
