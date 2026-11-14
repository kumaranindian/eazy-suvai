import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Placeholder. M01 builds sign-in, registration and email verification.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signInTitle)),
      body: EmptyState(
        icon: Icons.lock_outline,
        title: l10n.signInTitle,
        message: l10n.placeholderMessage,
      ),
    );
  }
}
