import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/qr_providers.dart';

/// Keys, for tests.
abstract final class QrPdfPreviewKeys {
  static const view = ValueKey('qrPdf.view');
  static const download = ValueKey('qrPdf.download');
  static const close = ValueKey('qrPdf.close');
}

/// Shows PDF bytes. `printing`'s [PdfPreview] rasterises the pages (pdf.js
/// on web, the platform renderer on Android and iOS); widget tests replace
/// it, since it needs a platform channel.
typedef QrPdfViewBuilder = Widget Function(Uint8List pdf);

final qrPdfViewBuilderProvider = Provider<QrPdfViewBuilder>(
  (ref) =>
      (pdf) => PdfPreview(
        build: (_) async => pdf,
        useActions: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        maxPageWidth: 700,
      ),
);

/// The template preview (FR-054): a full-screen page on compact windows, a
/// dialog on wider ones. "Download PDF" is offered from the preview too.
Future<void> showQrPdfPreview(
  BuildContext context, {
  required QrPdfRequest request,
  required String title,
  required VoidCallback onDownload,
}) {
  final body = _QrPdfPreview(
    request: request,
    title: title,
    onDownload: onDownload,
  );
  if (Breakpoint.of(context).isCompact) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => body),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 900),
        child: body,
      ),
    ),
  );
}

class _QrPdfPreview extends ConsumerWidget {
  const _QrPdfPreview({
    required this.request,
    required this.title,
    required this.onDownload,
  });

  final QrPdfRequest request;
  final String title;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final pdf = ref.watch(qrPdfProvider(request));
    final view = ref.watch(qrPdfViewBuilderProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          key: QrPdfPreviewKeys.close,
          icon: const Icon(Icons.close),
          tooltip: l10n.qrClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextButton.icon(
              key: QrPdfPreviewKeys.download,
              onPressed: pdf.hasValue ? onDownload : null,
              icon: const Icon(Icons.download),
              label: Text(l10n.qrDownloadPdf),
            ),
          ),
        ],
      ),
      body: pdf.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: core.messageForError(e)),
        data: (bytes) =>
            KeyedSubtree(key: QrPdfPreviewKeys.view, child: view(bytes)),
      ),
    );
  }
}
