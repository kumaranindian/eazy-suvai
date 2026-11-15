import 'package:core/core.dart';

/// The permanent QR target for a restaurant (FR-047, BR-006):
/// `{menuBaseUrl}/q/{CODE}`. It never contains the slug, so printed codes
/// keep working after a slug change (the `/q/` route redirects, M07).
String qrUrlFor(String code, {String? menuBaseUrl}) {
  final base = (menuBaseUrl ?? AppEnv.fromDefines().menuBaseUrl).replaceFirst(
    RegExp(r'/+$'),
    '',
  );
  return '$base/q/${code.toUpperCase()}';
}

/// [url] without the scheme, for print (`menu.eazysuvai.com/q/AB3K7MNP`).
String shortUrlText(String url) =>
    url.replaceFirst(RegExp('^https?://'), '').replaceFirst(RegExp(r'/$'), '');

/// A WhatsApp share link with a prefilled [message] (FR-068).
Uri whatsAppShareUri(String message) =>
    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

/// A file-name-safe version of [name] (`spice-garden`), never empty.
String fileSlug(String name) {
  final s = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'menu' : (s.length > 40 ? s.substring(0, 40) : s);
}
