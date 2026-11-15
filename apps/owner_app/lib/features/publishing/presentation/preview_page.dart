import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/publishing_repository.dart';
import 'menu_html_view.dart';
import 'publish_dialog.dart';
import 'publish_problems.dart';

enum _Frame { phone, desktop }

/// The draft preview (FR-061): the draft rendered by the public menu
/// renderer, exactly as customers will see it once published, marked
/// `noindex` and never served at a public URL.
///
/// * Compact: the page fills the screen (it is already a phone).
/// * Medium: one frame, with a phone / desktop toggle.
/// * Expanded: a 390 px phone frame beside a desktop frame.
class PreviewPage extends ConsumerStatefulWidget {
  const PreviewPage({super.key});

  /// Width the phone frame lays the page out at.
  static const phoneWidth = 390.0;

  /// The desktop frame is laid out at this size and scaled to fit.
  static const desktopSize = Size(1280, 800);

  @override
  ConsumerState<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends ConsumerState<PreviewPage> {
  _Frame _frame = _Frame.phone;

  Future<void> _publish() async {
    final version = await showPublishDialog(context);
    if (version != null) ref.invalidate(menuPreviewProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final breakpoint = Breakpoint.of(context);
    final compact = breakpoint == Breakpoint.compact;
    final preview = ref.watch(menuPreviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.menuPreviewTitle),
        actions: [
          AppIconButton(
            icon: Icons.refresh,
            semanticLabel: l10n.menuPreviewRefresh,
            onPressed: () => ref.invalidate(menuPreviewProvider),
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 16),
              child: FilledButton.icon(
                key: PublishKeys.previewPublish,
                onPressed: _publish,
                icon: const Icon(Icons.publish),
                label: Text(l10n.actionPublish),
              ),
            ),
        ],
      ),
      bottomNavigationBar: compact
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                child: AppPrimaryButton(
                  key: PublishKeys.previewPublish,
                  label: l10n.actionPublish,
                  icon: Icons.publish,
                  expand: true,
                  onPressed: _publish,
                ),
              ),
            )
          : null,
      body: preview.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: core.messageForError(e),
          onRetry: () => ref.invalidate(menuPreviewProvider),
        ),
        data: (p) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Notice(preview: p),
            if (breakpoint == Breakpoint.medium)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Center(
                  child: SegmentedButton<_Frame>(
                    key: PublishKeys.previewToggle,
                    segments: [
                      ButtonSegment(
                        value: _Frame.phone,
                        icon: const Icon(Icons.smartphone),
                        label: Text(l10n.menuPreviewPhone),
                      ),
                      ButtonSegment(
                        value: _Frame.desktop,
                        icon: const Icon(Icons.desktop_windows_outlined),
                        label: Text(l10n.menuPreviewDesktop),
                      ),
                    ],
                    selected: {_frame},
                    onSelectionChanged: (s) => setState(() => _frame = s.first),
                  ),
                ),
              ),
            Expanded(child: _frames(context, p.html, breakpoint)),
          ],
        ),
      ),
    );
  }

  Widget _frames(BuildContext context, String html, Breakpoint breakpoint) {
    final l10n = AppLocalizations.of(context);
    final build = ref.watch(menuHtmlViewBuilderProvider);
    final phone = build(html, l10n.menuPreviewFrame(l10n.menuPreviewPhone));
    final desktop = build(html, l10n.menuPreviewFrame(l10n.menuPreviewDesktop));
    switch (breakpoint) {
      case Breakpoint.compact:
        return KeyedSubtree(key: PublishKeys.previewPhone, child: phone);
      case Breakpoint.medium:
        return Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: _frame == _Frame.phone
              ? _PhoneFrame(child: phone)
              : _DesktopFrame(child: desktop),
        );
      case Breakpoint.expanded:
        return Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PhoneFrame(child: phone),
              const SizedBox(width: 24),
              Expanded(child: _DesktopFrame(child: desktop)),
            ],
          ),
        );
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.preview});

  final MenuPreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final blocking = preview.blocking.length;
    return Material(
      color: blocking > 0 ? scheme.errorContainer : scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        child: Semantics(
          liveRegion: true,
          child: Text(
            blocking > 0
                ? '${l10n.menuPreviewNote} ${l10n.menuPreviewBlocked(blocking)}'
                : l10n.menuPreviewNote,
            style: TextStyle(
              color: blocking > 0
                  ? scheme.onErrorContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      key: PublishKeys.previewPhone,
      child: Container(
        width: PreviewPage.phoneWidth + 16,
        constraints: const BoxConstraints(maxHeight: 860),
        padding: const EdgeInsetsDirectional.all(8),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(32),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
      ),
    );
  }
}

class _DesktopFrame extends StatelessWidget {
  const _DesktopFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = PreviewPage.desktopSize;
    return Align(
      key: PublishKeys.previewDesktop,
      alignment: AlignmentDirectional.topCenter,
      child: AspectRatio(
        aspectRatio: size.width / size.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant, width: 8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            // Laid out at desktop width, then scaled down to fit.
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: AlignmentDirectional.topStart,
              child: SizedBox.fromSize(size: size, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
