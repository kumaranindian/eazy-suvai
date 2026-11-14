import '../errors/app_error.dart';

/// Client-side copy of the FR-092 slug rules, for instant feedback while the
/// owner types. The `changeSlug` function checks again and also knows the
/// live reserved list (`config/platform.reservedSlugs`) and which slugs are
/// taken. Keep in sync with `functions/src/auth/slug.ts`.
abstract final class SlugRules {
  static const minLength = 3;
  static const maxLength = 60;

  /// The FR-092 starting list.
  static const defaultReserved = {
    'admin', 'api', 'app', 'assets', 'blog', 'dashboard', 'help', 'login', //
    'logout', 'm', 'pricing', 'privacy', 'q', 'robots.txt', 'signup',
    'sitemap.xml', 'static', 'support', 'terms', 'www', 'eazysuvai',
    'avail404',
  };

  static final _format = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  /// Trims and lower-cases, as the server does.
  static String normalize(String value) => value.trim().toLowerCase();

  /// `null` when [slug] passes the format and reserved-word checks, else
  /// [AppErrorCode.slugInvalid] or [AppErrorCode.slugReserved].
  static AppErrorCode? check(String slug) {
    final s = normalize(slug);
    if (s.length < minLength || s.length > maxLength || !_format.hasMatch(s)) {
      return AppErrorCode.slugInvalid;
    }
    if (defaultReserved.contains(s)) return AppErrorCode.slugReserved;
    return null;
  }
}
