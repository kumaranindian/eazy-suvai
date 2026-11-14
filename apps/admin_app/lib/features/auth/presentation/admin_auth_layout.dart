import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// The logo at [height], for [AuthLayout.logo].
Widget adminLogo(BuildContext context, double height) => Image.asset(
  Theme.of(context).brightness == Brightness.dark
      ? 'assets/brand/logo_dark.png'
      : 'assets/brand/logo.png',
  height: height,
  fit: BoxFit.contain,
  semanticLabel: AppLocalizations.of(context).appTitle,
);

/// [AuthLayout] with the admin app's logo and tagline.
class AdminAuthLayout extends StatelessWidget {
  const AdminAuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => AuthLayout(
    logo: adminLogo,
    tagline: AppLocalizations.of(context).authTagline,
    title: title,
    subtitle: subtitle,
    child: AutofillGroup(child: child),
  );
}
