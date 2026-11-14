import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Where "Upgrade" leads after a plan limit (M04). M10 replaces it with the
/// plans and upgrade-request screen.
class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.planTitle)),
      body: EmptyState(
        icon: Icons.workspace_premium_outlined,
        title: l10n.planTitle,
        message: l10n.planComingSoon,
      ),
    );
  }
}
