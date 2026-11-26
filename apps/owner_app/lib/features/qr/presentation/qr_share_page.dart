import 'dart:async';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../../restaurant/presentation/menu_link_page.dart' show menuUrl;
import '../application/qr_pdf.dart';
import '../application/qr_providers.dart';
import '../data/share_actions.dart';
import '../domain/qr_link.dart';
import 'qr_pdf_preview.dart';

/// Keys, for tests.
abstract final class QrKeys {
  static const image = ValueKey('qr.image');
  static const logoSwitch = ValueKey('qr.logoSwitch');
  static const logoMessage = ValueKey('qr.logoMessage');
  static const downloadPng = ValueKey('qr.downloadPng');
  static const template = ValueKey('qr.template');
  static const previewPdf = ValueKey('qr.previewPdf');
  static const downloadPdf = ValueKey('qr.downloadPdf');
  static const copy = ValueKey('qr.copy');
  static const whatsApp = ValueKey('qr.whatsApp');
  static const share = ValueKey('qr.share');
  static const notPublished = ValueKey('qr.notPublished');
  static const previewPane = ValueKey('qr.previewPane');
  static const optionsPane = ValueKey('qr.optionsPane');
}

/// QR code and sharing (M08, FR-047 to FR-054, FR-067 to FR-070).
///
/// - Compact: the preview on top, then the options and actions stacked.
/// - Wider (content ≥ 680 px): the preview on the left at 360 px, options
///   and actions on the right.
///
/// The code encodes `{menuBaseUrl}/q/{qrCode}` (never the slug). The logo
/// version is offered only after it decodes back to that URL; otherwise the
/// plain code is offered and the owner is told why (FR-053). Shared links
/// use the canonical slug URL, which has the rich preview (FR-070).
class QrSharePage extends ConsumerStatefulWidget {
  const QrSharePage({super.key});

  @override
  ConsumerState<QrSharePage> createState() => _QrSharePageState();
}

class _QrSharePageState extends ConsumerState<QrSharePage> {
  bool _savingPng = false;
  bool _savingPdf = false;

  QrShareActions get _actions => ref.read(qrShareActionsProvider);

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  QrPdfRequest _pdfRequest(AppLocalizations l10n, QrTemplate template) => (
    template: template,
    scanToView: l10n.qrPdfScanToView,
    orVisit: l10n.qrPdfOrVisit,
  );

  Future<void> _save(
    Future<Uint8List> Function() bytes,
    String fileName,
    String mimeType,
    void Function(bool) busy,
  ) async {
    final l10n = AppLocalizations.of(context);
    setState(() => busy(true));
    try {
      final outcome = await _actions.saveFile(
        await bytes(),
        fileName: fileName,
        mimeType: mimeType,
      );
      if (!mounted) return;
      if (outcome == ShareOutcome.done) {
        // FRD §13: count it; a failed count never bothers the owner.
        final rid = ref.read(currentRestaurantIdProvider);
        if (rid != null) {
          unawaited(
            ref
                .read(restaurantRepositoryProvider)
                .countQrDownload(rid)
                .catchError((Object _) {}),
          );
        }
        _snack(
          _actions.savesByDownload
              ? l10n.qrDownloadStarted(fileName)
              : l10n.qrFileShared(fileName),
        );
      }
    } on Object {
      if (mounted) _snack(l10n.qrSaveFailed);
    } finally {
      if (mounted) setState(() => busy(false));
    }
  }

  /// Builds the PDF, keeping the auto-dispose provider alive meanwhile.
  Future<Uint8List> _pdfBytes(QrPdfRequest request) async {
    final keep = ref.listenManual(qrPdfProvider(request), (_, _) {});
    try {
      return await ref.read(qrPdfProvider(request).future);
    } finally {
      keep.close();
    }
  }

  Future<void> _copy(String url) async {
    await _actions.copy(url);
    if (mounted) _snack(AppLocalizations.of(context).menuLinkCopied);
  }

  Future<void> _whatsApp(String message, String url) async {
    final l10n = AppLocalizations.of(context);
    var opened = false;
    try {
      opened = await _actions.openWhatsApp(message);
    } on Object {
      opened = false;
    }
    if (opened || !mounted) return;
    await _actions.copy(url);
    if (mounted) _snack(l10n.qrWhatsAppFailed);
  }

  Future<void> _share(String message, String subject, String url) async {
    final l10n = AppLocalizations.of(context);
    var outcome = ShareOutcome.unsupported;
    try {
      outcome = await _actions.shareText(message, subject: subject);
    } on Object {
      outcome = ShareOutcome.unsupported;
    }
    if (outcome != ShareOutcome.unsupported || !mounted) return;
    await _actions.copy(url);
    if (mounted) _snack(l10n.qrShareUnsupported);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final restaurant = ref.watch(currentRestaurantProvider);
    return restaurant.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: core.messageForError(e)),
      data: (r) {
        if (r == null) return ErrorState(message: core.errorNotFound);
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
            final preview = _PreviewCard(restaurant: r);
            final options = _options(context, l10n, r);
            if (!wide) {
              // A short page: built in full (not lazily), so every action exists.
              return SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [preview, const SizedBox(height: 16), ...options],
                ),
              );
            }
            return Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      key: QrKeys.previewPane,
                      width: 360,
                      child: SingleChildScrollView(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          24,
                          24,
                          12,
                          24,
                        ),
                        child: preview,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: QrKeys.optionsPane,
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          12,
                          24,
                          24,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: options,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _options(
    BuildContext context,
    AppLocalizations l10n,
    Restaurant r,
  ) {
    final theme = Theme.of(context);
    final qr = ref.watch(qrStateProvider);
    final ready = qr.value;
    final template = ref.watch(qrTemplateChoiceProvider);
    final hasLogo = r.logo?.isReady ?? false;
    // M10: the logo in the QR code is a plan feature (limits.qrLogo).
    final logoAllowed = r.planFeatures.qrLogo;
    final wantLogo = ref.watch(qrLogoChoiceProvider);
    final link = menuUrl(r.slug);
    final message = l10n.qrShareMessage(r.name, link);
    final base = fileSlug(r.name);
    final templateName = switch (template) {
      QrTemplate.poster => l10n.qrTemplatePoster,
      QrTemplate.tableCard => l10n.qrTemplateCard,
    };

    String? logoMessage;
    if (wantLogo && ready != null) {
      if (ready.logoLoadFailed) {
        logoMessage = l10n.qrLogoLoadFailed;
      } else if (ready.artifact.logoRejected) {
        logoMessage = l10n.qrLogoRejected;
      }
    }

    return [
      if (r.publishedVersion == null) ...[
        Card(
          key: QrKeys.notPublished,
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.qrNotPublishedNote,
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      _Section(
        title: l10n.qrDownloadHeading,
        icon: Icons.download_outlined,
        children: [
          SwitchListTile(
            key: QrKeys.logoSwitch,
            contentPadding: EdgeInsetsDirectional.zero,
            value: wantLogo && hasLogo && logoAllowed,
            onChanged: hasLogo && logoAllowed
                ? (v) => ref.read(qrLogoChoiceProvider.notifier).set(v)
                : null,
            title: Text(l10n.qrLogoToggle),
            subtitle: Text(
              !logoAllowed
                  ? l10n.qrLogoPro
                  : hasLogo
                  ? l10n.qrLogoToggleHelp
                  : l10n.qrLogoNone,
            ),
            secondary: logoAllowed
                ? null
                : const Icon(Icons.workspace_premium_outlined),
          ),
          if (logoMessage != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                key: QrKeys.logoMessage,
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: FormMessage(logoMessage),
              ),
            ),
          AppPrimaryButton(
            key: QrKeys.downloadPng,
            label: l10n.qrDownloadPng,
            icon: Icons.image_outlined,
            expand: true,
            loading: _savingPng,
            onPressed: ready == null
                ? null
                : () => _save(
                    () async => ready.artifact.png,
                    '$base-qr.png',
                    'image/png',
                    (v) => _savingPng = v,
                  ),
          ),
          const SizedBox(height: 16),
          Text(l10n.qrTemplateLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<QrTemplate>(
            key: QrKeys.template,
            segments: [
              ButtonSegment(
                value: QrTemplate.poster,
                label: Text(l10n.qrTemplatePoster),
                icon: const Icon(Icons.crop_portrait),
              ),
              ButtonSegment(
                value: QrTemplate.tableCard,
                label: Text(l10n.qrTemplateCard),
                icon: const Icon(Icons.table_restaurant_outlined),
              ),
            ],
            selected: {template},
            onSelectionChanged: (s) =>
                ref.read(qrTemplateChoiceProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 12),
          // Preview and Download PDF match the full-width PNG button: equal
          // halves of one row, stacked full width on narrow phones.
          LayoutBuilder(
            builder: (context, constraints) {
              final previewButton = AppSecondaryButton(
                key: QrKeys.previewPdf,
                label: l10n.qrPreviewPdf,
                icon: Icons.visibility_outlined,
                expand: true,
                onPressed: ready == null
                    ? null
                    : () => showQrPdfPreview(
                        context,
                        request: _pdfRequest(l10n, template),
                        title: l10n.qrTemplatePreviewTitle(templateName),
                        onDownload: () => _save(
                          () => _pdfBytes(_pdfRequest(l10n, template)),
                          '$base-${template == QrTemplate.poster ? 'poster-a4' : 'table-card-a6'}.pdf',
                          'application/pdf',
                          (v) => _savingPdf = v,
                        ),
                      ),
              );
              final pdfButton = AppPrimaryButton(
                key: QrKeys.downloadPdf,
                label: l10n.qrDownloadPdf,
                icon: Icons.picture_as_pdf_outlined,
                expand: true,
                loading: _savingPdf,
                onPressed: ready == null
                    ? null
                    : () => _save(
                        () => _pdfBytes(_pdfRequest(l10n, template)),
                        '$base-${template == QrTemplate.poster ? 'poster-a4' : 'table-card-a6'}.pdf',
                        'application/pdf',
                        (v) => _savingPdf = v,
                      ),
              );
              if (constraints.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    previewButton,
                    const SizedBox(height: 8),
                    pdfButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: previewButton),
                  const SizedBox(width: 8),
                  Expanded(child: pdfButton),
                ],
              );
            },
          ),
        ],
      ),
      const SizedBox(height: 16),
      _Section(
        title: l10n.qrShareHeading,
        icon: Icons.share_outlined,
        children: [
          SelectableText(link, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppSecondaryButton(
                key: QrKeys.copy,
                label: l10n.qrCopyLink,
                icon: Icons.copy,
                onPressed: () => _copy(link),
              ),
              AppSecondaryButton(
                key: QrKeys.whatsApp,
                label: l10n.qrShareWhatsApp,
                icon: Icons.chat_outlined,
                onPressed: () => _whatsApp(message, link),
              ),
              AppSecondaryButton(
                key: QrKeys.share,
                label: l10n.qrShareMore,
                icon: Icons.ios_share,
                onPressed: () =>
                    _share(message, l10n.qrShareSubject(r.name), link),
              ),
            ],
          ),
        ],
      ),
    ];
  }
}

class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final qr = ref.watch(qrStateProvider);
    final url = ref.watch(qrUrlProvider) ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.qrPreviewHeading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: qr.when(
                    loading: () => Semantics(
                      label: l10n.qrGenerating,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) =>
                        Center(child: FormMessage(core.messageForError(e))),
                    data: (s) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(4),
                        child: Image.memory(
                          key: QrKeys.image,
                          s.artifact.png,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          semanticLabel: l10n.qrImageLabel(url),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (qr.value case final s?)
              Text(
                s.artifact.withLogo
                    ? l10n.qrImageInfoLogo(s.artifact.render.size)
                    : l10n.qrImageInfo(s.artifact.render.size),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(
              l10n.qrPermanentNote(shortUrlText(url)),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
