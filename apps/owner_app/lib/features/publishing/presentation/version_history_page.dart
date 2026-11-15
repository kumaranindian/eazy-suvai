import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../data/publishing_repository.dart';
import 'publish_problems.dart';

/// Version history (FR-096, AC-013): the last 10 published versions with
/// date, who published and the change counts; "Restore" publishes one
/// again as a new version. "Discard changes" returns the draft to the live
/// version. A list on phones, a table on wider windows.
class VersionHistoryPage extends ConsumerWidget {
  const VersionHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final restaurant = ref.watch(currentRestaurantProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.versionsTitle)),
      body: restaurant.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: core.messageForError(e),
          onRetry: () => ref.invalidate(currentRestaurantProvider),
        ),
        data: (r) {
          if (r == null) return ErrorState(message: core.errorNotFound);
          if (r.versionHistory.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: l10n.versionsTitle,
              message: l10n.versionsEmpty,
            );
          }
          return _History(restaurant: r);
        },
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final r = restaurant;
    final compact = Breakpoint.of(context) == Breakpoint.compact;
    final versions = r.versionHistory;
    final live = r.publishedVersion;

    final header = <Widget>[
      Text(l10n.versionsHelp),
      if (r.isPublished && r.hasUnpublishedChanges) ...[
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppSecondaryButton(
            key: PublishKeys.discard,
            label: l10n.actionDiscardChanges,
            icon: Icons.undo,
            onPressed: () => _discard(context, ref, live!),
          ),
        ),
      ],
      const SizedBox(height: 16),
    ];

    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: EdgeInsetsDirectional.all(compact ? 16 : 24),
          children: [
            ...header,
            if (compact)
              for (final v in versions)
                _VersionCard(
                  entry: v,
                  restaurant: r,
                  live: v.n == live,
                  onRestore: () => _restore(context, ref, v.n, live ?? v.n),
                )
            else
              _VersionTable(
                versions: versions,
                restaurant: r,
                onRestore: (n) => _restore(context, ref, n, live ?? n),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    int version,
    int live,
  ) async {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final replace = await showDialog<bool>(
      context: context,
      builder: (_) => _RestoreDialog(version: version, next: live + 1),
    );
    if (replace == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await ref
          .read(publishingRepositoryProvider)
          .rollback(restaurant.id, version, replaceDraft: replace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.restoreDone(version, outcome.version))),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(core.messageForError(e))));
    }
  }

  Future<void> _discard(BuildContext context, WidgetRef ref, int live) async {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l10n.discardTitle,
      message: l10n.discardBody(live),
      confirmLabel: l10n.actionDiscardChanges,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final v = await ref
          .read(publishingRepositoryProvider)
          .discardDraft(restaurant.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.discardDone(v))));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(core.messageForError(e))));
    }
  }
}

String _when(DateTime at, String timezone) {
  try {
    return DateFormat.yMMMd().add_Hm().format(
      TimeService().toZone(at, timezone),
    );
  } on Object {
    return DateFormat.yMMMd().add_Hm().format(at.toLocal());
  }
}

String _by(
  AppLocalizations l10n,
  MenuVersionEntry v,
  Restaurant r,
  String? uid,
) => v.publishedBy == uid || v.publishedBy.isEmpty
    ? l10n.versionByYou
    : l10n.versionBySupport;

String _changes(AppLocalizations l10n, MenuVersionEntry v) {
  final parts = <String>[
    if (v.isRollback) l10n.versionRestoredFrom(v.rollbackOf!),
    if (v.added + v.changed + v.removed > 0)
      l10n.versionSummary(v.added, v.changed, v.removed),
    if (v.profileChanged) l10n.publishProfileChanged,
    if (v.themeChanged) l10n.publishThemeChanged,
  ];
  return parts.isEmpty ? l10n.versionNoContentChanges : parts.join(' · ');
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppLocalizations.of(context).versionLive,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class _VersionCard extends ConsumerWidget {
  const _VersionCard({
    required this.entry,
    required this.restaurant,
    required this.live,
    required this.onRestore,
  });

  final MenuVersionEntry entry;
  final Restaurant restaurant;
  final bool live;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final uid = ref.watch(authSessionProvider).value?.uid;
    final v = entry;
    return Card.outlined(
      key: PublishKeys.version(v.n),
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.versionLabel(v.n),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (live) const _LiveChip(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_when(v.publishedAt, restaurant.timezone)} · ${_by(l10n, v, restaurant, uid)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(_changes(l10n, v)),
            if (!live) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AppSecondaryButton(
                  key: PublishKeys.restore(v.n),
                  label: l10n.actionRestore,
                  icon: Icons.restore,
                  onPressed: onRestore,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VersionTable extends ConsumerWidget {
  const _VersionTable({
    required this.versions,
    required this.restaurant,
    required this.onRestore,
  });

  final List<MenuVersionEntry> versions;
  final Restaurant restaurant;
  final ValueChanged<int> onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final uid = ref.watch(authSessionProvider).value?.uid;
    final head = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget cell(Widget child) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 12,
      ),
      child: child,
    );
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
        3: FlexColumnWidth(),
        4: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      children: [
        TableRow(
          children: [
            for (final h in [
              l10n.versionColumnVersion,
              l10n.versionColumnPublished,
              l10n.versionColumnBy,
              l10n.versionColumnChanges,
              '',
            ])
              cell(Semantics(header: true, child: Text(h, style: head))),
          ],
        ),
        for (final v in versions)
          TableRow(
            children: [
              KeyedSubtree(
                key: PublishKeys.version(v.n),
                child: cell(
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.versionLabel(v.n),
                        style: theme.textTheme.titleSmall,
                      ),
                      if (v.n == restaurant.publishedVersion) const _LiveChip(),
                    ],
                  ),
                ),
              ),
              cell(Text(_when(v.publishedAt, restaurant.timezone))),
              cell(Text(_by(l10n, v, restaurant, uid))),
              cell(Text(_changes(l10n, v))),
              cell(
                v.n == restaurant.publishedVersion
                    ? const SizedBox(width: 48, height: 48)
                    : TextButton.icon(
                        key: PublishKeys.restore(v.n),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => onRestore(v.n),
                        icon: const Icon(Icons.restore),
                        label: Text(l10n.actionRestore),
                      ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Confirms a rollback; returns whether to replace the draft (FR-096), or
/// null when cancelled.
class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({required this.version, required this.next});

  final int version;
  final int next;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  bool _replace = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.restoreTitle(widget.version)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.restoreBody(widget.version, widget.next)),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: PublishKeys.restoreReplace,
              contentPadding: EdgeInsetsDirectional.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _replace,
              onChanged: (v) => setState(() => _replace = v ?? false),
              title: Text(l10n.restoreReplaceDraft(widget.version)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(core.actionCancel),
        ),
        FilledButton(
          key: PublishKeys.restoreConfirm,
          onPressed: () => Navigator.of(context).pop(_replace),
          child: Text(l10n.actionRestore),
        ),
      ],
    );
  }
}
