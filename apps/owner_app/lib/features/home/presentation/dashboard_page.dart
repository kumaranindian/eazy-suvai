import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../account/presentation/account_notices_view.dart';
import '../../plan/presentation/subscription_banner.dart';
import '../../qr/domain/qr_link.dart';
import '../../qr/presentation/qr_mini_view.dart';
import '../../restaurant/data/restaurant_repository.dart';
import '../../restaurant/presentation/menu_link_page.dart';

/// Remembers that the first-run wizard was opened automatically in this
/// session, so the dashboard opens it at most once.
class SetupPrompt {
  bool shown = false;
}

final setupPromptProvider = Provider<SetupPrompt>((ref) => SetupPrompt());

/// Keys, for tests.
abstract final class DashboardKeys {
  static const checklist = ValueKey('dashboard.checklist');
  static const status = ValueKey('dashboard.status');
  static const qr = ValueKey('dashboard.qr');
  static ValueKey<String> step(SetupStep s) =>
      ValueKey('dashboard.step.${s.name}');
}

/// Owner dashboard home (M03): setup checklist, menu status and a QR
/// shortcut. One column on compact windows, two on medium, three on
/// expanded. Opens the setup wizard once when it was never finished.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = CoreLocalizations.of(context);
    return ref
        .watch(currentRestaurantProvider)
        .when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(
            message: core.messageForError(e),
            onRetry: () => ref.invalidate(currentRestaurantProvider),
          ),
          data: (r) {
            if (r == null) return ErrorState(message: core.errorNotFound);
            final prompt = ref.read(setupPromptProvider);
            if (r.setupCompletedAt == null && !prompt.shown) {
              prompt.shown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go(Routes.setup);
              });
            }
            return _Dashboard(restaurant: r);
          },
        );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _ChecklistCard(key: DashboardKeys.checklist, restaurant: restaurant),
      _StatusCard(key: DashboardKeys.status, restaurant: restaurant),
      _QrCard(key: DashboardKeys.qr, restaurant: restaurant),
    ];
    final columns = switch (Breakpoint.of(context)) {
      Breakpoint.compact => 1,
      Breakpoint.medium => 2,
      Breakpoint.expanded => 3,
    };
    final padding = columns == 1 ? 16.0 : 24.0;
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plan reminders, grace and hidden content (M10, FR-100, FR-101).
          const AnnouncementBanner(),
          const SubscriptionBanners(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = c; i < cards.length; i += columns)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(bottom: 16),
                          child: cards[i],
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
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
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = SetupChecklist.of(restaurant);
    final green = Theme.of(context).brightness == Brightness.dark
        ? BrandColors.greenOnDark
        : BrandColors.greenText;
    return _DashCard(
      title: list.isComplete ? l10n.checklistDoneTitle : l10n.checklistTitle,
      icon: Icons.checklist,
      children: [
        Text(l10n.checklistProgress(list.doneCount, list.total)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: list.doneCount / list.total,
          semanticsLabel: l10n.checklistProgress(list.doneCount, list.total),
        ),
        const SizedBox(height: 8),
        for (final step in SetupStep.values)
          ListTile(
            key: DashboardKeys.step(step),
            contentPadding: EdgeInsetsDirectional.zero,
            minTileHeight: 48,
            leading: list.isDone(step)
                ? Icon(
                    Icons.check_circle,
                    color: green,
                    semanticLabel: l10n.checklistStepDone,
                  )
                : Icon(
                    Icons.radio_button_unchecked,
                    semanticLabel: l10n.checklistStepTodo,
                  ),
            title: Text(_stepTitle(l10n, step)),
            subtitle: step == list.next ? Text(_stepHint(l10n, step)) : null,
            trailing: list.isDone(step)
                ? null
                : const Icon(Icons.chevron_right),
            onTap: list.isDone(step)
                ? null
                : () => context.go(_stepRoute(step)),
          ),
      ],
    );
  }

  static String _stepTitle(AppLocalizations l10n, SetupStep s) => switch (s) {
    SetupStep.profile => l10n.checklistProfile,
    SetupStep.logo => l10n.checklistLogo,
    SetupStep.categories => l10n.checklistCategories,
    SetupStep.items => l10n.checklistItems,
    SetupStep.theme => l10n.checklistTheme,
    SetupStep.publish => l10n.checklistPublish,
  };

  static String _stepHint(AppLocalizations l10n, SetupStep s) => switch (s) {
    SetupStep.profile => l10n.checklistProfileHint,
    SetupStep.logo => l10n.checklistLogoHint,
    SetupStep.categories => l10n.checklistCategoriesHint,
    SetupStep.items => l10n.checklistItemsHint,
    SetupStep.theme => l10n.checklistThemeHint,
    SetupStep.publish => l10n.checklistPublishHint,
  };

  /// The screen that completes each step. "Publish" opens the preview,
  /// which has the Publish button (M06).
  static String _stepRoute(SetupStep s) => switch (s) {
    SetupStep.profile || SetupStep.logo => Routes.profile,
    SetupStep.categories || SetupStep.items => Routes.menu,
    SetupStep.theme => Routes.theme,
    SetupStep.publish => Routes.preview,
  };
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = restaurant;
    final edited = r.draftUpdatedAt;
    String? editedText;
    if (edited != null) {
      try {
        final local = TimeService().toZone(edited, r.timezone);
        editedText = l10n.statusLastEdit(
          DateFormat.yMMMd().add_Hm().format(local),
        );
      } on Object {
        editedText = null;
      }
    }
    return _DashCard(
      title: l10n.statusTitle,
      icon: Icons.restaurant_menu,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                r.isPublished ? Icons.public : Icons.edit_note,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                r.isPublished
                    ? l10n.statusLive(r.publishedVersion!)
                    : l10n.statusDraft,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(r.isPublished ? l10n.statusLiveHelp : l10n.statusDraftHelp),
        const SizedBox(height: 8),
        Text(
          l10n.statusCounts(r.categoryCount, r.itemCount),
          style: theme.textTheme.bodyMedium,
        ),
        if (editedText != null)
          Text(
            editedText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (r.pricesNeedReview) ...[
          const SizedBox(height: 12),
          FormMessage(l10n.regionalPricesNeedReview),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppSecondaryButton(
              label: l10n.statusOpenMenu,
              icon: Icons.restaurant_menu,
              onPressed: () => context.go(Routes.menu),
            ),
            AppSecondaryButton(
              key: const ValueKey('dashboard.preview'),
              label: l10n.actionPreview,
              icon: Icons.visibility_outlined,
              onPressed: () => context.push(Routes.preview),
            ),
            if (r.isPublished)
              TextButton(
                key: const ValueKey('dashboard.versions'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => context.go(Routes.versions),
                child: Text(l10n.statusActionHistory),
              ),
          ],
        ),
      ],
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final url = menuUrl(restaurant.slug);
    return _DashCard(
      title: l10n.qrTitle,
      icon: Icons.qr_code_2,
      children: [
        Text(l10n.qrHelp),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                url,
                style: theme.textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AppIconButton(
              icon: Icons.copy,
              semanticLabel: l10n.menuLinkCopy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.menuLinkCopied)));
                }
              },
            ),
          ],
        ),
        Text(l10n.qrCode(restaurant.qrCode), style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        // A live preview of the permanent /q/ code (M08); tap for downloads.
        InkWell(
          key: const ValueKey('dashboard.qrPreview'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(Routes.share),
          child: QrMiniView(
            data: qrUrlFor(restaurant.qrCode),
            semanticLabel: l10n.qrImageLabel(qrUrlFor(restaurant.qrCode)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppSecondaryButton(
              label: l10n.qrOpenShare,
              icon: Icons.qr_code_2,
              onPressed: () => context.go(Routes.share),
            ),
            TextButton(
              onPressed: () => context.go(Routes.menuLink),
              child: Text(l10n.qrChangeLink),
            ),
          ],
        ),
      ],
    );
  }
}
