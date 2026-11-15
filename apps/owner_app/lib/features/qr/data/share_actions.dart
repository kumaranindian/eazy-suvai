import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/qr_link.dart';
import 'platform_io.dart'
    if (dart.library.js_interop) 'platform_web.dart'
    as platform;

/// What happened to a share or save request.
enum ShareOutcome {
  /// Shared, or the file was handed to the browser or the share sheet.
  done,

  /// The owner closed the share sheet.
  dismissed,

  /// No share sheet here (desktop browsers without Web Share); the caller
  /// copies the link instead.
  unsupported,
}

/// Sharing and saving (FR-067 to FR-069, FR-050), behind an interface so
/// widget tests can record calls.
abstract class QrShareActions {
  /// Whether "Download" saves directly (web) rather than opening the share
  /// sheet (Android, iOS).
  bool get savesByDownload;

  Future<void> copy(String text);

  /// Opens WhatsApp (app or web) with [message]. False if nothing opened.
  Future<bool> openWhatsApp(String message);

  /// The native share sheet / Web Share API with [text].
  Future<ShareOutcome> shareText(String text, {required String subject});

  /// Downloads (web) or shares (mobile) a file.
  Future<ShareOutcome> saveFile(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  });
}

class PlatformQrShareActions implements QrShareActions {
  const PlatformQrShareActions();

  @override
  bool get savesByDownload => platform.platformSavesByDownload;

  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<bool> openWhatsApp(String message) => launchUrl(
    whatsAppShareUri(message),
    mode: LaunchMode.externalApplication,
  );

  @override
  Future<ShareOutcome> shareText(String text, {required String subject}) async {
    if (!platform.platformCanShareText()) return ShareOutcome.unsupported;
    final result = await SharePlus.instance.share(
      ShareParams(text: text, subject: subject, title: subject),
    );
    return switch (result.status) {
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable when savesByDownload =>
        ShareOutcome.unsupported,
      _ => ShareOutcome.done,
    };
  }

  @override
  Future<ShareOutcome> saveFile(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    final ok = await platform.platformSaveFile(
      bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
    return ok ? ShareOutcome.done : ShareOutcome.dismissed;
  }
}

final qrShareActionsProvider = Provider<QrShareActions>(
  (ref) => const PlatformQrShareActions(),
);
