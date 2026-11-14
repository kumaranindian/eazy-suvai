import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../shell/presentation/admin_shell.dart';

/// Placeholder for a section that a later module builds.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.section});

  final AdminSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layout = switch (Breakpoint.of(context)) {
      Breakpoint.compact => l10n.layoutCompact,
      Breakpoint.medium => l10n.layoutMedium,
      Breakpoint.expanded => l10n.layoutExpanded,
    };
    return EmptyState(
      icon: section.destination(l10n).icon,
      title: section.label(l10n),
      message: '${l10n.placeholderMessage}\n${l10n.layoutLabel(layout)}',
    );
  }
}
