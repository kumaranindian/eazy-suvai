import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Where the privacy policy and terms live: static pages on the public
/// menu site (`hosting/menu/privacy.html`, `terms.html`; the slugs are
/// reserved). M13.
Uri legalUri(String page) =>
    Uri.parse('${AppEnv.fromDefines().menuBaseUrl}/$page');

/// Opens a legal page in the browser. Overridden in tests.
final legalLinkOpenerProvider = Provider<Future<void> Function(Uri)>(
  (ref) =>
      (uri) async => launchUrl(uri, mode: LaunchMode.externalApplication),
);

abstract final class LegalKeys {
  static const terms = ValueKey('legal.terms');
  static const privacy = ValueKey('legal.privacy');
}

/// "By creating an account you agree to the Terms of service and the
/// Privacy policy" (sign-up), or just the two links ([agreement] false).
class LegalLinks extends ConsumerWidget {
  const LegalLinks({super.key, this.agreement = true});

  final bool agreement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final open = ref.read(legalLinkOpenerProvider);
    final style = Theme.of(context).textTheme.bodySmall;
    Widget link(Key key, String label, String page) => TextButton(
      key: key,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
      ),
      onPressed: () => open(legalUri(page)),
      child: Text(label),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (agreement) Text(l10n.legalAgreePrefix, style: style),
        link(LegalKeys.terms, l10n.legalTerms, 'terms'),
        Text(agreement ? l10n.legalAnd : '·', style: style),
        link(LegalKeys.privacy, l10n.legalPrivacy, 'privacy'),
      ],
    );
  }
}
