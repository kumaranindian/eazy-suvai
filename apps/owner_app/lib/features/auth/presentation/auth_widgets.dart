import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// The EazySuvai logo at [height], for [AuthLayout.logo].
Widget ownerLogo(BuildContext context, double height) => Image.asset(
  Theme.of(context).brightness == Brightness.dark
      ? 'assets/brand/logo_dark.png'
      : 'assets/brand/logo.png',
  height: height,
  fit: BoxFit.contain,
  semanticLabel: AppLocalizations.of(context).appTitle,
);

/// [AuthLayout] with the owner app's logo and tagline.
class OwnerAuthLayout extends StatelessWidget {
  const OwnerAuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.card = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool card;

  @override
  Widget build(BuildContext context) => AuthLayout(
    logo: ownerLogo,
    tagline: AppLocalizations.of(context).authTagline,
    title: title,
    subtitle: subtitle,
    card: card,
    child: AutofillGroup(child: child),
  );
}

/// "Question? [Link]" row, wrapping on narrow screens.
class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({
    super.key,
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(text),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onPressed,
        child: Text(action),
      ),
    ],
  );
}

/// Section heading inside a form.
class FormSectionTitle extends StatelessWidget {
  const FormSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 8, bottom: 12),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

const formGap = SizedBox(height: 16);
