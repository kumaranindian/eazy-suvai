import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

import '../../restaurant/data/restaurant_repository.dart';
import '../../theme/application/theme_draft.dart';
import '../data/logo_loader.dart';
import '../domain/qr_link.dart';
import 'qr_image.dart';
import 'qr_pdf.dart';

/// Runs [buildQrArtifact] off the UI thread where there are isolates
/// (Android, iOS). Tests replace it with a direct call.
typedef QrArtifactBuilder = Future<QrArtifact> Function(QrJob job);

QrArtifact _buildInIsolate(QrJob job) => buildQrArtifact(job);

final qrArtifactBuilderProvider = Provider<QrArtifactBuilder>(
  (ref) =>
      (job) => compute(_buildInIsolate, job),
);

/// "Add my logo" (FR-053). Off by default. M10 will gate it with
/// `limits.qrLogo`.
class QrLogoChoice extends Notifier<bool> {
  @override
  bool build() => false;

  // A setter would read oddly at the call sites.
  // ignore: use_setters_to_change_properties
  void set(bool value) => state = value;
}

final qrLogoChoiceProvider = NotifierProvider<QrLogoChoice, bool>(
  QrLogoChoice.new,
);

/// The print template chosen on the screen.
class QrTemplateChoice extends Notifier<QrTemplate> {
  @override
  QrTemplate build() => QrTemplate.poster;

  // ignore: use_setters_to_change_properties
  void set(QrTemplate value) => state = value;
}

final qrTemplateChoiceProvider = NotifierProvider<QrTemplateChoice, QrTemplate>(
  QrTemplateChoice.new,
);

/// The QR target of the signed-in owner's restaurant, or null while loading.
final qrUrlProvider = Provider.autoDispose<String?>((ref) {
  final code = ref.watch(currentRestaurantProvider).value?.qrCode;
  return code == null || code.isEmpty ? null : qrUrlFor(code);
});

/// The restaurant's logo bytes, or null without a ready logo.
final qrLogoBytesProvider = FutureProvider.autoDispose<Uint8List?>((ref) async {
  final logo = ref.watch(
    currentRestaurantProvider.select((r) => r.value?.logo),
  );
  if (logo == null || !logo.isReady) return null;
  return ref.watch(qrLogoLoaderProvider).load(logo);
});

/// The QR code offered for download, plus why the logo is missing when the
/// owner asked for it.
class QrState {
  const QrState(this.artifact, {this.logoLoadFailed = false});

  final QrArtifact artifact;

  /// The logo could not be downloaded; the plain code is shown.
  final bool logoLoadFailed;
}

final qrStateProvider = FutureProvider.autoDispose<QrState>((ref) async {
  final url = ref.watch(qrUrlProvider);
  if (url == null) throw StateError('No restaurant');
  final wantLogo = ref.watch(qrLogoChoiceProvider);
  final build = ref.watch(qrArtifactBuilderProvider);
  Uint8List? logo;
  var logoLoadFailed = false;
  if (wantLogo) {
    try {
      logo = await ref.watch(qrLogoBytesProvider.future);
    } on Object {
      logoLoadFailed = true;
    }
  }
  final artifact = await build(QrJob(url, logo));
  return QrState(artifact, logoLoadFailed: logoLoadFailed);
});

/// The words on the PDF and the template, as one family key.
typedef QrPdfRequest = ({
  QrTemplate template,
  String scanToView,
  String orVisit,
});

/// The PDF for a template, built from the current QR code (FR-050, FR-054).
final qrPdfProvider = FutureProvider.autoDispose
    .family<Uint8List, QrPdfRequest>((ref, req) async {
      final state = await ref.watch(qrStateProvider.future);
      final fonts = await ref.watch(qrFontsProvider.future);
      final restaurant = ref.watch(currentRestaurantProvider).value;
      Uint8List? logo;
      try {
        logo = await ref.watch(qrLogoBytesProvider.future);
      } on Object {
        logo = null; // The header simply has no logo.
      }
      final theme = ref.watch(resolvedThemeProvider);
      return buildQrPdf(
        req.template,
        QrPdfInput(
          restaurantName: restaurant?.name ?? '',
          qrPng: state.artifact.png,
          shortUrl: shortUrlText(state.artifact.url),
          text: QrPdfText(scanToView: req.scanToView, orVisit: req.orVisit),
          regularFont: fonts.regular,
          boldFont: fonts.bold,
          logo: logo,
          primary: pdfColorFromHex(
            theme.primary,
            PdfColor.fromInt(BrandColors.orangeText.toARGB32()),
          ),
          onPrimary: pdfColorFromHex(theme.onPrimary, PdfColors.white),
        ),
      );
    });
