import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/core_localizations.dart';
import 'image_object.dart';
import 'storage_image_resolver.dart';

/// Shows an [ImageObject] using the smallest WebP rendition that covers
/// the widget's width in physical pixels (FR-102, FRD §7.1).
///
/// Shows a placeholder while there is no image, while the server is still
/// processing it, if it was rejected and while the rendition loads.
/// Give it a bounded width (and usually a height or aspect ratio).
class ResponsiveImage extends ConsumerStatefulWidget {
  const ResponsiveImage({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.placeholderIcon = Icons.image_outlined,
  });

  final ImageObject? image;
  final BoxFit fit;

  /// Describes the picture for screen readers. Null marks it decorative.
  final String? semanticLabel;

  /// Icon shown when there is no image.
  final IconData placeholderIcon;

  @override
  ConsumerState<ResponsiveImage> createState() => _ResponsiveImageState();
}

class _ResponsiveImageState extends ConsumerState<ResponsiveImage> {
  String? _path;
  Future<ImageProvider>? _provider;

  Future<ImageProvider> _resolve(String path) {
    if (path != _path || _provider == null) {
      _path = path;
      _provider = ref.read(storageImageResolverProvider).resolve(path);
    }
    return _provider!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = CoreLocalizations.of(context);
    final image = widget.image;

    if (image == null) {
      return _Placeholder(icon: widget.placeholderIcon, label: l10n.imageNone);
    }
    if (image.isProcessing) {
      return _Placeholder(label: l10n.imageProcessing, busy: true);
    }
    if (!image.isReady) {
      return _Placeholder(
        icon: Icons.broken_image_outlined,
        label: l10n.imageRejected,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final logical = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (constraints.hasBoundedHeight ? constraints.maxHeight : 320.0);
        final physical = logical * MediaQuery.devicePixelRatioOf(context);
        final path = image.renditions!.pathFor(physical);

        return FutureBuilder<ImageProvider>(
          future: _resolve(path),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Placeholder(
                icon: Icons.broken_image_outlined,
                label: widget.semanticLabel,
              );
            }
            if (!snapshot.hasData) {
              return _Placeholder(label: widget.semanticLabel);
            }
            return Image(
              image: snapshot.data!,
              fit: widget.fit,
              width: double.infinity,
              height: double.infinity,
              semanticLabel: widget.semanticLabel,
              excludeFromSemantics: widget.semanticLabel == null,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, sync) => sync
                  ? child
                  : AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: child,
                    ),
              errorBuilder: (context, error, stack) => _Placeholder(
                icon: Icons.broken_image_outlined,
                label: widget.semanticLabel,
              ),
            );
          },
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.icon, this.label, this.busy = false});

  final IconData? icon;
  final String? label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      image: true,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: SizedBox.expand(
          child: Center(
            child: busy
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : (icon == null
                      ? null
                      : Icon(icon, color: scheme.onSurfaceVariant)),
          ),
        ),
      ),
    );
  }
}
