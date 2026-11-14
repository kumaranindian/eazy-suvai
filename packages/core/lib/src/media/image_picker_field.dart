import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/core_localizations.dart';
import '../layout/breakpoint.dart';
import '../widgets/app_buttons.dart';
import '../widgets/confirm_dialog.dart';
import 'image_crop_dialog.dart';
import 'image_messages.dart';
import 'image_object.dart';
import 'image_picker_service.dart';
import 'image_preparer.dart';
import 'image_upload_service.dart';
import 'responsive_image.dart';

/// Pick, crop, preview, replace and remove one image (FR-031, FR-102).
///
/// The widget uploads to `restaurants/{restaurantId}/images/{id}/original.*`
/// with metadata naming [targetPath] and the purpose's field. The
/// `processImage` function then writes the image object (`processing`,
/// then `ready` or `rejected`) to that document. **The parent does not
/// save the uploaded image itself**; it passes the document's current
/// field as [value] (for example from a Firestore stream) and the widget
/// follows it.
///
/// Removing only calls [onRemove]; the parent sets the field to `null`.
/// Without [onRemove] there is no Remove button.
///
/// The preview is 96 px tall on compact windows (or always, with [dense])
/// and 160 px on medium and expanded windows, at [aspectRatio].
class ImagePickerField extends ConsumerStatefulWidget {
  const ImagePickerField({
    super.key,
    required this.purpose,
    required this.restaurantId,
    required this.targetPath,
    required this.label,
    this.value,
    this.aspectRatio,
    this.onUploaded,
    this.onRemove,
    this.dense = false,
    this.enabled = true,
  });

  final ImagePurpose purpose;
  final String restaurantId;

  /// Document that holds the image: `restaurants/{rid}` for logo and cover,
  /// `restaurants/{rid}/categories/{cid}` or `.../items/{iid}`. It must
  /// exist before an upload.
  final String targetPath;

  /// Field label, also the preview's screen-reader label.
  final String label;

  /// The document's current image object.
  final ImageObject? value;

  /// Crop aspect ratio (width / height). Defaults to the purpose's.
  final double? aspectRatio;

  /// Called when an upload has finished, with a `processing` object for the
  /// new path. Informational: `processImage` writes the document.
  final ValueChanged<ImageObject>? onUploaded;

  /// Called after the user confirms removal.
  final VoidCallback? onRemove;

  /// Always use the 96 px preview (compact lists).
  final bool dense;
  final bool enabled;

  static const compactPreviewHeight = 96.0;
  static const formPreviewHeight = 160.0;

  /// How long to wait for `processImage` before showing a "slow" note.
  static const slowAfter = Duration(seconds: 60);

  @override
  ConsumerState<ImagePickerField> createState() => _ImagePickerFieldState();
}

enum _Phase { idle, preparing, uploading, processing }

class _ImagePickerFieldState extends ConsumerState<ImagePickerField> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  ImageUpload? _upload;
  String? _uploadedPath;
  Uint8List? _localPreview;
  ImageRejectReason? _localError;
  Timer? _slowTimer;
  bool _slow = false;
  StreamSubscription<double>? _progressSub;

  double get _aspect => widget.aspectRatio ?? widget.purpose.defaultAspectRatio;

  bool get _busy => _phase != _Phase.idle;

  @override
  void didUpdateWidget(ImagePickerField old) {
    super.didUpdateWidget(old);
    _followServer();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }

  /// Leaves the processing state once the document shows the final result
  /// (`ready` or `rejected`) of our upload. Until then the document still
  /// holds the previous image or a `processing` object for our path.
  void _followServer() {
    if (_phase != _Phase.processing) return;
    final v = widget.value;
    if (v != null && v.path == _uploadedPath && !v.isProcessing) _finish();
  }

  void _finish({ImageRejectReason? error}) {
    _slowTimer?.cancel();
    _progressSub?.cancel();
    _phase = _Phase.idle;
    _upload = null;
    _uploadedPath = null;
    _localPreview = null;
    _slow = false;
    _localError = error;
  }

  void _reset({ImageRejectReason? error}) {
    if (!mounted) return;
    setState(() => _finish(error: error));
  }

  Future<void> _pick() async {
    setState(() => _localError = null);

    final PickedImageFile? file;
    try {
      file = await ref.read(imageFilePickerProvider).pick();
    } on Object {
      _reset(error: ImageRejectReason.pickFailed);
      return;
    }
    if (file == null || !mounted) return;

    final preparer = ref.read(imagePreparerProvider);
    setState(() => _phase = _Phase.preparing);
    final SourceImage source;
    try {
      source = await preparer.load(
        file.bytes,
        purpose: widget.purpose,
        aspectRatio: _aspect,
      );
    } on ImageRejectedException catch (e) {
      _reset(error: e.reason);
      return;
    } on Object {
      _reset(error: ImageRejectReason.invalidImage);
      return;
    }
    if (!mounted) {
      source.dispose();
      return;
    }
    setState(() => _phase = _Phase.idle);

    final rect = await showImageCropDialog(
      context,
      image: source.image,
      aspectRatio: _aspect,
      minCropSize: widget.purpose.minSize,
    );
    if (rect == null || !mounted) {
      source.dispose();
      return;
    }

    setState(() => _phase = _Phase.preparing);
    final PreparedImage prepared;
    try {
      prepared = await preparer.crop(source, rect);
    } on Object {
      _reset(error: ImageRejectReason.invalidImage);
      return;
    } finally {
      source.dispose();
    }
    if (!mounted) return;
    await _startUpload(prepared);
  }

  Future<void> _startUpload(PreparedImage prepared) async {
    final upload = ref
        .read(imageUploaderProvider)
        .start(
          ImageUploadRequest(
            restaurantId: widget.restaurantId,
            purpose: widget.purpose,
            targetPath: widget.targetPath,
            bytes: prepared.bytes,
            format: prepared.format,
          ),
        );
    setState(() {
      _phase = _Phase.uploading;
      _upload = upload;
      _uploadedPath = upload.path;
      _progress = 0;
      _localPreview = prepared.bytes;
    });
    _progressSub = upload.progress.listen((v) {
      if (mounted && _phase == _Phase.uploading) {
        setState(() => _progress = v);
      }
    }, onError: (Object _) {});

    try {
      await upload.done;
    } on ImageUploadCanceled {
      _reset();
      return;
    } on Object {
      _reset(error: ImageRejectReason.uploadFailed);
      return;
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.processing;
      _progress = 1;
      _slowTimer = Timer(ImagePickerField.slowAfter, () {
        if (mounted) setState(() => _slow = true);
      });
    });
    widget.onUploaded?.call(ImageObject.processing(upload.path));
    setState(_followServer);
  }

  Future<void> _cancel() async {
    await _upload?.cancel();
  }

  Future<void> _remove() async {
    final l10n = CoreLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l10n.imageRemoveTitle,
      message: l10n.imageRemoveMessage,
      confirmLabel: l10n.imageRemove,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _localError = null);
    widget.onRemove?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final compact = widget.dense || Breakpoint.of(context).isCompact;
    final value = widget.value;

    // A rejected document value is shown as an error once we're idle.
    final error =
        _localError ??
        (!_busy && value != null && value.isRejected ? value.reason : null);
    final showRemove =
        widget.onRemove != null && value != null && !_busy && widget.enabled;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = compact
            ? ImagePickerField.compactPreviewHeight
            : ImagePickerField.formPreviewHeight;
        var width = height * _aspect;
        if (constraints.hasBoundedWidth && width > constraints.maxWidth) {
          width = constraints.maxWidth;
        }

        final preview = SizedBox(
          width: width,
          height: width / _aspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_localPreview != null)
                  Image.memory(
                    _localPreview!,
                    fit: BoxFit.cover,
                    semanticLabel: widget.label,
                    gaplessPlayback: true,
                  )
                else
                  ResponsiveImage(
                    image: value,
                    semanticLabel: widget.label,
                    placeholderIcon: widget.purpose == ImagePurpose.logo
                        ? Icons.storefront_outlined
                        : Icons.add_photo_alternate_outlined,
                  ),
                if (_busy)
                  ColoredBox(
                    color: theme.colorScheme.surface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        );

        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              l10n.imageHint(widget.purpose.minWidth, widget.purpose.minHeight),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_phase == _Phase.uploading)
              _UploadProgress(progress: _progress, onCancel: _cancel)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppSecondaryButton(
                    label: value == null && _localPreview == null
                        ? l10n.imageAdd
                        : l10n.imageReplace,
                    icon: Icons.add_photo_alternate_outlined,
                    loading: _phase == _Phase.preparing,
                    onPressed: widget.enabled && !_busy ? _pick : null,
                  ),
                  if (showRemove)
                    TextButton.icon(
                      onPressed: _remove,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.imageRemove),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                ],
              ),
            if (_phase == _Phase.preparing) ...[
              const SizedBox(height: 8),
              _StatusText(l10n.imagePreparing),
            ],
            if (_phase == _Phase.processing) ...[
              const SizedBox(height: 8),
              _StatusText(l10n.imageProcessing, busy: true),
              if (_slow) ...[
                const SizedBox(height: 4),
                _StatusText(l10n.imageProcessingSlow),
              ],
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              _ErrorText(l10n.imageRejectMessage(error, widget.purpose)),
            ],
          ],
        );

        final sideBySide =
            !constraints.hasBoundedWidth ||
            width + 16 + 220 <= constraints.maxWidth;
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              preview,
              const SizedBox(width: 16),
              Flexible(child: details),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [preview, const SizedBox(height: 12), details],
        );
      },
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.progress, required this.onCancel});

  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = CoreLocalizations.of(context);
    final percent = (progress * 100).clamp(0, 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: LinearProgressIndicator(
            value: progress,
            semanticsLabel: l10n.imageUploading(percent),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(l10n.imageUploading(percent)),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(l10n.imageCancelUpload),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.text, {this.busy = false});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) ...[
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 20, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
