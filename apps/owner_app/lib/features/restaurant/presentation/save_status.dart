import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/draft_autosave.dart';

/// "Saving…" / "Saved" / "Couldn't save" for draft autosave (M03). A live
/// region, so screen readers announce changes.
class SaveStatusIndicator extends ConsumerWidget {
  const SaveStatusIndicator({super.key});

  static const retryKey = ValueKey('save.retry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(draftAutosaveProvider);
    final green = Theme.of(context).brightness == Brightness.dark
        ? BrandColors.greenOnDark
        : BrandColors.greenText;
    final (IconData? icon, Color color, String text) = switch (state.status) {
      SaveStatus.idle => (
        Icons.cloud_done_outlined,
        scheme.onSurfaceVariant,
        l10n.saveAuto,
      ),
      SaveStatus.pending ||
      SaveStatus.saving => (null, scheme.onSurfaceVariant, l10n.saveSaving),
      SaveStatus.saved => (Icons.check_circle_outline, green, l10n.saveSaved),
      SaveStatus.failed => (Icons.error_outline, scheme.error, l10n.saveFailed),
      SaveStatus.invalid => (
        Icons.warning_amber_outlined,
        scheme.error,
        l10n.saveInvalid,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == null)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.status == SaveStatus.failed)
            TextButton(
              key: retryKey,
              onPressed: () => ref.read(draftAutosaveProvider.notifier).flush(),
              child: Text(CoreLocalizations.of(context).actionRetry),
            ),
        ],
      ),
    );
  }
}

/// Sticky bar at the bottom of a compact form: the save status and a
/// "Save now" button.
class SaveBar extends ConsumerWidget {
  const SaveBar({super.key});

  static const saveNowKey = ValueKey('save.now');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(draftAutosaveProvider).status;
    final canSave = status == SaveStatus.pending || status == SaveStatus.failed;
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Row(
            children: [
              const Expanded(child: SaveStatusIndicator()),
              FilledButton.tonal(
                key: saveNowKey,
                onPressed: canSave
                    ? () => ref.read(draftAutosaveProvider.notifier).flush()
                    : null,
                child: Text(l10n.actionSaveNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled card that groups related fields.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsetsDirectional.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...withGaps(children),
          ],
        ),
      ),
    );
  }
}

/// [children] with a 16 px gap between them.
List<Widget> withGaps(List<Widget> children) => [
  for (var i = 0; i < children.length; i++) ...[
    if (i > 0) const SizedBox(height: 16),
    children[i],
  ],
];
