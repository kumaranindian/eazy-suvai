import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/core_localizations.dart';
import '../layout/breakpoint.dart';
import '../widgets/app_buttons.dart';
import 'crop_geometry.dart';

/// Lets the user choose a crop of [image] with a fixed [aspectRatio].
///
/// Full screen on compact windows, a 640 px dialog on medium and expanded
/// (M02 plan). Returns the crop in image pixels, or null if cancelled.
Future<Rect?> showImageCropDialog(
  BuildContext context, {
  required ui.Image image,
  required double aspectRatio,
  Size minCropSize = Size.zero,
}) {
  return showDialog<Rect>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ImageCropDialog(
      image: image,
      aspectRatio: aspectRatio,
      minCropSize: minCropSize,
    ),
  );
}

class ImageCropDialog extends StatefulWidget {
  const ImageCropDialog({
    super.key,
    required this.image,
    required this.aspectRatio,
    this.minCropSize = Size.zero,
  });

  final ui.Image image;
  final double aspectRatio;
  final Size minCropSize;

  /// Width of the dialog on medium and expanded windows.
  static const dialogWidth = 640.0;

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  late CropGeometry _geometry = CropGeometry(
    imageSize: Size(
      widget.image.width.toDouble(),
      widget.image.height.toDouble(),
    ),
    aspectRatio: widget.aspectRatio,
    minCropSize: widget.minCropSize,
  );

  void _update(CropGeometry g) => setState(() => _geometry = g);

  void _done() => Navigator.of(context).pop(_geometry.cropRect);

  @override
  Widget build(BuildContext context) {
    final l10n = CoreLocalizations.of(context);
    final compact = Breakpoint.of(context).isCompact;

    final cropper = _CropArea(
      image: widget.image,
      geometry: _geometry,
      onChanged: _update,
    );
    final zoom = _ZoomSlider(geometry: _geometry, onChanged: _update);

    if (compact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.actionCancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(l10n.imageCropTitle),
            actions: [
              TextButton(onPressed: _done, child: Text(l10n.imageCropDone)),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: cropper),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                  child: Text(
                    l10n.imageCropHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: zoom,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ImageCropDialog.dialogWidth,
          maxHeight: math.max(360, height - 48),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.imageCropTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.imageCropHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: cropper,
                ),
              ),
              const SizedBox(height: 8),
              zoom,
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppSecondaryButton(
                    label: l10n.actionCancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  AppPrimaryButton(label: l10n.imageCropDone, onPressed: _done),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({required this.geometry, required this.onChanged});

  final CropGeometry geometry;
  final ValueChanged<CropGeometry> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = CoreLocalizations.of(context);
    final canZoom = geometry.maxZoom > 1.001;
    return Row(
      children: [
        const Icon(Icons.zoom_out, size: 20),
        Expanded(
          child: Slider(
            value: geometry.zoom,
            min: 1,
            max: canZoom ? geometry.maxZoom : 1.001,
            label: l10n.imageCropZoom,
            semanticFormatterCallback: (v) =>
                '${l10n.imageCropZoom} ${(v * 100).round()}%',
            onChanged: canZoom ? (v) => onChanged(geometry.zoomTo(v)) : null,
          ),
        ),
        const Icon(Icons.zoom_in, size: 20),
      ],
    );
  }
}

/// The image under a fixed crop frame. Drag to pan, pinch or scroll to zoom.
class _CropArea extends StatefulWidget {
  const _CropArea({
    required this.image,
    required this.geometry,
    required this.onChanged,
  });

  final ui.Image image;
  final CropGeometry geometry;
  final ValueChanged<CropGeometry> onChanged;

  @override
  State<_CropArea> createState() => _CropAreaState();
}

class _CropAreaState extends State<_CropArea> {
  double _startZoom = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = CoreLocalizations.of(context);
    final g = widget.geometry;
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        const pad = 16.0;
        final avail = Size(
          math.max(1, area.width - 2 * pad),
          math.max(1, area.height - 2 * pad),
        );
        // The frame keeps the crop's aspect ratio and fills the area.
        final frame = avail.width / avail.height > g.aspectRatio
            ? Size(avail.height * g.aspectRatio, avail.height)
            : Size(avail.width, avail.width / g.aspectRatio);
        final frameRect = Rect.fromCenter(
          center: area.center(Offset.zero),
          width: frame.width,
          height: frame.height,
        );
        // Screen pixels per image pixel.
        final scale = frame.width / g.cropRect.width;
        final crop = g.cropRect;

        return Semantics(
          label: l10n.imageCropArea,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                final factor = math.pow(0.998, event.scrollDelta.dy);
                widget.onChanged(g.zoomTo(g.zoom * factor));
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (_) => _startZoom = widget.geometry.zoom,
              onScaleUpdate: (d) {
                var next = widget.geometry;
                if (d.pointerCount > 1) {
                  next = next.zoomTo(_startZoom * d.scale);
                }
                next = next.panBy(-d.focalPointDelta / scale);
                widget.onChanged(next);
              },
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: frameRect.left - crop.left * scale,
                      top: frameRect.top - crop.top * scale,
                      width: widget.image.width * scale,
                      height: widget.image.height * scale,
                      child: RawImage(
                        image: widget.image,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _FramePainter(
                          frameRect,
                          Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dims everything outside the frame and draws a border with thirds.
class _FramePainter extends CustomPainter {
  _FramePainter(this.frame, this.surface);

  final Rect frame;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(outside, Paint()..color = surface.withValues(alpha: 0.75));

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = frame.left + frame.width * i / 3;
      final y = frame.top + frame.height * i / 3;
      canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), line);
      canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), line);
    }
    canvas.drawRect(
      frame,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.surface != surface;
}
