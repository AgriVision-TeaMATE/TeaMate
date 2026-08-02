import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/tea_grade_model.dart';
import '../widgets/particle_overlay_painter.dart';

/// Full-screen, pinch-zoomable view of a scan's original image with detected
/// particle bounding boxes drawn on top. Uses the original (not segmented)
/// image because particle bbox coordinates are in the original image's pixel
/// space.
class ParticleDetailScreen extends StatefulWidget {
  const ParticleDetailScreen({super.key, required this.scan, this.localImageBytes});

  final TeaQualityScan scan;
  final Uint8List? localImageBytes;

  @override
  State<ParticleDetailScreen> createState() => _ParticleDetailScreenState();
}

class _ParticleDetailScreenState extends State<ParticleDetailScreen> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _naturalSize;
  bool _loadError = false;

  ImageProvider? get _imageProvider {
    final url = widget.scan.resolvedImageUrl;
    if (url != null) return NetworkImage(url);
    final bytes = widget.localImageBytes;
    if (bytes != null) return MemoryImage(bytes);
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  void _resolveImage() {
    final provider = _imageProvider;
    if (provider == null) {
      setState(() => _loadError = true);
      return;
    }
    final newStream = provider.resolve(createLocalImageConfiguration(context));
    if (newStream.key == _stream?.key) return;

    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() {
          _naturalSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
      onError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _loadError = true);
      },
    );
    _stream = newStream;
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final labels = <String>{for (final p in scan.particles) p.label.toUpperCase()}
        .toList()
      ..sort();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${scan.particles.length} Detected Particles'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildOverlayArea(scan)),
            if (labels.isNotEmpty) _Legend(labels: labels),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayArea(TeaQualityScan scan) {
    final provider = _imageProvider;
    if (provider == null || _loadError) {
      return const Center(
        child: Text(
          'Could not load the sample image.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    if (_naturalSize == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
          final fitted = applyBoxFit(BoxFit.contain, _naturalSize!, widgetSize);
          final destinationRect =
              Alignment.center.inscribe(fitted.destination, Offset.zero & widgetSize);

          return Stack(
            children: [
              Positioned.fill(
                child: Image(image: provider, fit: BoxFit.contain),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: ParticleOverlayPainter(
                    particles: scan.particles,
                    imageNaturalSize: _naturalSize!,
                    destinationRect: destinationRect,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: const Color(0xFF111111),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: [
          for (final label in labels)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: TeaGradePalette.colorFor(label),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
