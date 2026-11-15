import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// The admin app is read-only below 600 px (M11 plan): screens hide their
/// actions and show [ReadOnlyNotice].
bool adminReadOnly(BuildContext context) => Breakpoint.of(context).isCompact;

class ReadOnlyNotice extends StatelessWidget {
  const ReadOnlyNotice({super.key});

  static const noticeKey = ValueKey('admin.readOnly');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: noticeKey,
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Row(
          children: [
            Icon(Icons.phone_android, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.readOnlyNotice,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
