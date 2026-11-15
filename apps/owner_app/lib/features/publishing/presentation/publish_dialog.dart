import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../menu/application/menu_state.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../data/publishing_repository.dart';
import '../domain/publish_models.dart';
import 'publish_problems.dart';

/// Opens the publish confirmation (FR-063, FR-065, FR-066): a bottom sheet
/// on compact windows, a 560 px dialog otherwise. It runs a dry run, shows
/// the change summary and every problem with a "Fix" link, and publishes
/// when nothing blocks. Returns the new version, or null.
Future<int?> showPublishDialog(BuildContext context) async {
  final _Fix? result;
  if (Breakpoint.of(context) == Breakpoint.compact) {
    result = await showModalBottomSheet<_Fix?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _PublishPanel(sheet: true),
    );
  } else {
    result = await showDialog<_Fix?>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: const _PublishPanel(sheet: false),
        ),
      ),
    );
  }
  if (result == null || !context.mounted) return null;
  if (result.version case final v?) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).publishDone(v))),
    );
    return v;
  }
  if (result.problem case final p?) _openFix(context, p);
  return null;
}

/// What the panel closed with: a published version or a problem to fix.
class _Fix {
  const _Fix.published(int this.version) : problem = null;
  const _Fix.problem(PublishProblem this.problem) : version = null;

  final int? version;
  final PublishProblem? problem;
}

void _openFix(BuildContext context, PublishProblem p) {
  final target = fixRouteFor(p);
  final container = ProviderScope.containerOf(context, listen: false);
  if (target.categoryId != null &&
      Breakpoint.of(context) != Breakpoint.compact) {
    // Wide layouts show the category in the menu manager's panes.
    container.read(selectedCategoryProvider.notifier).set(target.categoryId);
    context.go('/menu');
    return;
  }
  if (target.route.startsWith('/menu/item/')) {
    context.push(target.route);
  } else {
    context.go(target.route);
  }
}

class _PublishPanel extends ConsumerStatefulWidget {
  const _PublishPanel({required this.sheet});

  final bool sheet;

  @override
  ConsumerState<_PublishPanel> createState() => _PublishPanelState();
}

class _PublishPanelState extends ConsumerState<_PublishPanel> {
  PublishCheck? _check;
  Object? _error;
  bool _pricesReviewed = false;
  bool _publishing = false;

  String? get _rid => ref.read(currentRestaurantIdProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _check = null;
      _error = null;
    });
    try {
      final check = await ref.read(publishingRepositoryProvider).check(_rid!);
      if (mounted) setState(() => _check = check);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _publish() async {
    final check = _check!;
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(publishingRepositoryProvider)
          .publish(_rid!, pricesReviewed: _pricesReviewed);
      if (mounted) Navigator.of(context).pop(_Fix.published(outcome.version));
    } on Object catch (e) {
      if (!mounted) return;
      final problems = blockedProblemsOf(e);
      setState(() {
        _publishing = false;
        if (problems != null) {
          // Something changed since the dry run: show the new problems.
          _check = PublishCheck(
            problems: problems,
            summary: check.summary,
            currentVersion: check.currentVersion,
            pricesNeedReview: check.pricesNeedReview,
          );
        } else {
          _error = e;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final check = _check;
    final restaurant = ref.watch(currentRestaurantProvider).value;

    final List<Widget> body;
    if (check == null && _error == null) {
      body = [
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Center(child: Text(l10n.publishChecking)),
        const SizedBox(height: 24),
      ];
    } else if (check == null) {
      body = [
        FormMessage(core.messageForError(_error!)),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(onPressed: _load, child: Text(core.actionRetry)),
        ),
      ];
    } else {
      final blocking = check.blocking;
      final next = (check.currentVersion ?? 0) + 1;
      body = [
        if (blocking.isNotEmpty) ...[
          _Heading(l10n.publishProblemsTitle),
          Column(
            key: PublishKeys.problems,
            children: [
              for (final (i, p) in blocking.indexed)
                _ProblemRow(
                  index: i,
                  message: problemMessage(p, l10n, core),
                  onFix: () => Navigator.of(context).pop(_Fix.problem(p)),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _Heading(l10n.publishChangesTitle),
        KeyedSubtree(
          key: PublishKeys.summary,
          child: _SummaryView(check: check),
        ),
        if (check.pricesNeedReview) ...[
          const SizedBox(height: 12),
          FormMessage(l10n.problemPrices),
          CheckboxListTile(
            key: PublishKeys.pricesReviewed,
            contentPadding: EdgeInsetsDirectional.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _pricesReviewed,
            onChanged: _publishing
                ? null
                : (v) => setState(() => _pricesReviewed = v ?? false),
            title: Text(l10n.publishPricesCheckbox(restaurant?.currency ?? '')),
          ),
        ],
        if (blocking.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.publishNextVersion(next),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          FormMessage(core.messageForError(_error!)),
        ],
      ];
    }

    final canPublish =
        check != null &&
        check.blocking.isEmpty &&
        (!check.pricesNeedReview || _pricesReviewed) &&
        !_publishing;

    return Padding(
      key: PublishKeys.dialog,
      padding: EdgeInsetsDirectional.fromSTEB(
        24,
        widget.sheet ? 0 : 24,
        24,
        16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.publishTitle,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(core.actionCancel),
              ),
              AppPrimaryButton(
                key: PublishKeys.confirm,
                label: l10n.actionPublish,
                icon: Icons.publish,
                loading: _publishing,
                onPressed: canPublish ? _publish : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 8),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({
    required this.index,
    required this.message,
    required this.onFix,
  });

  final int index;
  final String message;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 4),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.error_outline, color: scheme.error),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(
            key: PublishKeys.fix(index),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onFix,
            child: Text(
              l10n.actionFix,
              semanticsLabel: '${l10n.actionFix}: $message',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.check});

  final PublishCheck check;

  static const _shown = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = check.summary;
    if (s.firstPublish) {
      return Text(
        l10n.publishFirstSummary(
          s.categories.added.length,
          s.items.added.length,
        ),
      );
    }
    if (s.isEmpty) {
      return Text(l10n.publishNoChanges(check.currentVersion ?? 0));
    }

    final rows = <(IconData, String, List<ChangeRef>)>[
      if (s.items.added.isNotEmpty)
        (
          Icons.add_circle_outline,
          l10n.publishAddedItems(s.items.added.length),
          s.items.added,
        ),
      if (s.items.changed.isNotEmpty)
        (
          Icons.edit_outlined,
          l10n.publishChangedItems(s.items.changed.length),
          s.items.changed,
        ),
      if (s.items.removed.isNotEmpty)
        (
          Icons.remove_circle_outline,
          l10n.publishRemovedItems(s.items.removed.length),
          s.items.removed,
        ),
      if (s.categories.added.isNotEmpty)
        (
          Icons.add_circle_outline,
          l10n.publishAddedCategories(s.categories.added.length),
          s.categories.added,
        ),
      if (s.categories.changed.isNotEmpty)
        (
          Icons.edit_outlined,
          l10n.publishChangedCategories(s.categories.changed.length),
          s.categories.changed,
        ),
      if (s.categories.removed.isNotEmpty)
        (
          Icons.remove_circle_outline,
          l10n.publishRemovedCategories(s.categories.removed.length),
          s.categories.removed,
        ),
      if (s.profileChanged)
        (Icons.storefront_outlined, l10n.publishProfileChanged, const []),
      if (s.themeChanged)
        (Icons.palette_outlined, l10n.publishThemeChanged, const []),
    ];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (icon, title, refs) in rows)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icon, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title),
                      if (refs.isNotEmpty)
                        Text(
                          [
                            refs.take(_shown).map((r) => r.name).join(', '),
                            if (refs.length > _shown)
                              l10n.publishMoreNames(refs.length - _shown),
                          ].join(' '),
                          style: TextStyle(color: muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
