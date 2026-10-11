import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The TIPO app icon: orange rounded square, navy posko tent, white heartbeat.
/// Painted from the logo pack's SVG geometry so it stays crisp at any size.
class TipoLogoMark extends StatelessWidget {
  const TipoLogoMark({super.key, this.size = 40, this.inverse = false});
  final double size;

  /// Draw only the symbol in white/orange, for use on a navy surface.
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'TIPO logo',
      image: true,
      child: SizedBox.square(dimension: size, child: CustomPaint(painter: _LogoPainter(inverse: inverse))),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.inverse});
  final bool inverse;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1024;
    canvas.save();
    canvas.scale(s);
    if (!inverse) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 1024, 1024), const Radius.circular(230)),
        Paint()..color = TipoColors.orange,
      );
    }
    canvas.translate(0, 14);
    final tent = inverse ? TipoColors.white : TipoColors.navy;
    final pulse = inverse ? TipoColors.orange : TipoColors.white;

    final heartbeat = Path()
      ..moveTo(290, 604)
      ..lineTo(416, 604)
      ..lineTo(446, 564)
      ..lineTo(478, 636)
      ..lineTo(512, 452)
      ..lineTo(548, 672)
      ..lineTo(580, 564)
      ..lineTo(608, 604)
      ..lineTo(734, 604);
    canvas.drawPath(
      heartbeat,
      Paint()
        ..color = pulse
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeJoin = StrokeJoin.miter
        ..strokeMiterLimit = 10,
    );

    final fill = Paint()..color = tent;
    canvas.drawRect(const Rect.fromLTWH(495, 168, 34, 70), fill);
    final roof = Path()
      ..moveTo(290, 790)
      ..lineTo(290, 560)
      ..lineTo(512, 250)
      ..lineTo(734, 560)
      ..lineTo(734, 790);
    canvas.drawPath(
      roof,
      Paint()
        ..color = tent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 56
        ..strokeJoin = StrokeJoin.miter
        ..strokeMiterLimit = 4,
    );
    canvas.drawRect(const Rect.fromLTWH(246, 784, 532, 44), fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.inverse != inverse;
}

/// Logo, name, and subtitle. Used in every app bar and the ops top bar.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.light = false, this.compact = false, this.subtitle = 'TIten POsko'});

  /// White text, for navy surfaces.
  final bool light;
  final bool compact;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = light ? TipoColors.white : Theme.of(context).colorScheme.onSurface;
    final sub = light ? TipoColors.muted : context.muted;
    final mark = compact ? 32.0 : 40.0;
    return Semantics(
      container: true,
      label: 'TIPO, TIten POsko',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TipoLogoMark(size: mark),
            const SizedBox(width: Space.sm + 2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('TIPO', style: displayStyle(size: compact ? 18 : 22, color: color, weight: FontWeight.w800).copyWith(height: 1, letterSpacing: 0.6)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontFamily: bodyFont, color: sub, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
