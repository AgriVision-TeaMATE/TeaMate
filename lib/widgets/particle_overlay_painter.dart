import 'package:flutter/material.dart';

import '../models/tea_grade_model.dart';

/// Draws particle bounding boxes + labels on top of an image. `destinationRect`
/// must be the exact rect the image is displayed within (e.g. from
/// `applyBoxFit`), so screen-space boxes line up with bbox coordinates that
/// are in the original image's pixel space.
class ParticleOverlayPainter extends CustomPainter {
  ParticleOverlayPainter({
    required this.particles,
    required this.imageNaturalSize,
    required this.destinationRect,
    this.highlightedIndex,
  });

  final List<Particle> particles;
  final Size imageNaturalSize;
  final Rect destinationRect;
  final int? highlightedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageNaturalSize.width <= 0 || imageNaturalSize.height <= 0) return;

    final scaleX = destinationRect.width / imageNaturalSize.width;
    final scaleY = destinationRect.height / imageNaturalSize.height;
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var i = 0; i < particles.length; i++) {
      final particle = particles[i];
      final rect = Rect.fromLTWH(
        destinationRect.left + particle.bbox.left * scaleX,
        destinationRect.top + particle.bbox.top * scaleY,
        particle.bbox.width * scaleX,
        particle.bbox.height * scaleY,
      );
      final highlighted = i == highlightedIndex;
      final color = highlighted
          ? Colors.yellowAccent
          : TeaGradePalette.colorFor(particle.label.toUpperCase());
      boxPaint.color = color;
      boxPaint.strokeWidth = highlighted ? 2.5 : 1.5;
      canvas.drawRect(rect, boxPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: particle.label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            backgroundColor: color.withValues(alpha: 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - textPainter.height));
    }
  }

  @override
  bool shouldRepaint(covariant ParticleOverlayPainter oldDelegate) =>
      oldDelegate.particles != particles ||
      oldDelegate.imageNaturalSize != imageNaturalSize ||
      oldDelegate.destinationRect != destinationRect ||
      oldDelegate.highlightedIndex != highlightedIndex;
}
