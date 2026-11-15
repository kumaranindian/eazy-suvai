import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../restaurant/data/restaurant_repository.dart';
import 'publish_dialog.dart';
import 'publish_problems.dart';

/// The persistent "Unpublished changes · Preview · Publish" bar (M06). The
/// shell shows it above the bottom navigation on phones and at the top of
/// the content area on wider windows. Hidden while the live menu matches
/// the draft (availability does not count, BR-018) and for accounts that
/// are not active (the server refuses them too).
class PublishBar extends ConsumerWidget {
  const PublishBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(currentRestaurantProvider).value;
    if (r == null || r.status != 'active' || !r.hasUnpublishedChanges) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final compact = Breakpoint.of(context) == Breakpoint.compact;
    final label = r.isPublished ? l10n.publishBarChanges : l10n.publishBarDraft;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final icon = ExcludeSemantics(
      child: Icon(
        r.isPublished ? Icons.edit_note : Icons.unpublished_outlined,
        color: scheme.onSecondaryContainer,
      ),
    );
    final text = Expanded(
      child: ExcludeSemantics(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
        ),
      ),
    );
    final preview = TextButton(
      key: PublishKeys.barPreview,
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSecondaryContainer,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
      ),
      onPressed: () => context.push(Routes.preview),
      child: Text(l10n.actionPreview),
    );
    final publish = FilledButton(
      key: PublishKeys.barPublish,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      ),
      onPressed: () => showPublishDialog(context),
      child: Text(l10n.actionPublish),
    );

    return Material(
      key: PublishKeys.bar,
      color: scheme.secondaryContainer,
      child: Semantics(
        container: true,
        label: label,
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: compact ? 12 : 24,
            vertical: 4,
          ),
          // At large text sizes the buttons go under the label (M13, 200 %).
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [icon, const SizedBox(width: 8), text]),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 4,
                      children: [preview, publish],
                    ),
                  ],
                )
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    text,
                    preview,
                    const SizedBox(width: 4),
                    publish,
                  ],
                ),
        ),
      ),
    );
  }
}
