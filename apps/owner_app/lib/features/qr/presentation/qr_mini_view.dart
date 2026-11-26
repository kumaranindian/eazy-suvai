import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// A small QR code drawn as vectors (the dashboard card). Cheap: no PNG
/// render or decode; the download screen does those.
class QrMiniView extends StatelessWidget {
  const QrMiniView({
    super.key,
    required this.data,
    this.size = 112,
    this.semanticLabel,
  });

  final String data;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      // Always a square, even under a stretching parent (tight constraints
      // would otherwise widen the box while the painter scaled by width).
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsetsDirectional.all(size / 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: CustomPaint(painter: _QrPainter(image)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final side = size.shortestSide;
    final m = side / n;
    // Centre the square in whatever box we were given.
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    final paint = Paint()..color = Colors.black;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (image.isDark(r, c)) {
          canvas.drawRect(Rect.fromLTWH(c * m, r * m, m + 0.3, m + 0.3), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
