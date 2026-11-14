import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: l10n.notFoundTitle,
        actionLabel: l10n.actionGoHome,
        onAction: () => context.go('/'),
      ),
    );
  }
}
